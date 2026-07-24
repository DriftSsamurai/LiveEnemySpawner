-- ============================================================
-- Live Enemy Spawner for Devil May Cry 5
-- Version: 1.0 (Public English Release)
-- Features:
--   - Auto-detection & loading of enemy prefabs (emXXXX)
--   - 10 customizable slots with global hotkeys (F1-F12, Numpad, Letters, Numbers)
--   - Customizable hotkey to clear all spawned entities
--   - Auto-saving & loading of user settings (JSON)
--   - Smooth camera-facing spawning with random position offset
--   - Clean UI integrated directly into REFramework
-- ============================================================

-- ------------------------------------------------------------
-- AVAILABLE KEY MAPPING
-- ------------------------------------------------------------
local key_map = {
    {"No Key", nil},
    {"F1", 112}, {"F2", 113}, {"F3", 114}, {"F4", 115}, {"F5", 116},
    {"F6", 117}, {"F7", 118}, {"F8", 119}, {"F9", 120}, {"F10", 121}, {"F11", 122}, {"F12", 123},
    {"0", 48}, {"1", 49}, {"2", 50}, {"3", 51}, {"4", 52}, {"5", 53}, {"6", 54}, {"7", 55}, {"8", 56}, {"9", 57},
    {"A", 65}, {"B", 66}, {"C", 67}, {"D", 68}, {"E", 69}, {"F", 70}, {"G", 71}, {"H", 72}, {"I", 73}, {"J", 74}, {"K", 75}, {"L", 76}, {"M", 77}, {"N", 78}, {"O", 79}, {"P", 80}, {"Q", 81}, {"R", 82}, {"S", 83}, {"T", 84}, {"U", 85}, {"V", 86}, {"W", 87}, {"X", 88}, {"Y", 89}, {"Z", 90},
    {"Numpad 0", 96}, {"Numpad 1", 97}, {"Numpad 2", 98}, {"Numpad 3", 99}, {"Numpad 4", 100}, {"Numpad 5", 101}, {"Numpad 6", 102}, {"Numpad 7", 103}, {"Numpad 8", 104}, {"Numpad 9", 105}
}

local key_names = {}
for _, v in ipairs(key_map) do
    table.insert(key_names, v[1])
end

local function get_key_id(idx)
    if not idx or idx < 1 or idx > #key_map then return nil end
    return key_map[idx][2]
end

-- ------------------------------------------------------------
-- GLOBAL STATE & CONFIGURATION
-- ------------------------------------------------------------
local loaded_names   = {}
local loaded_prefabs = {}
local loaded_infos   = {}

local num_slots = 10
local slots     = {}

local clear_key_idx  = 1
local clear_was_down = false

local saved_settings = {}
local settings_file  = "LiveEnemySpawner_Settings.json"

local function load_settings()
    local ok, data = pcall(json.load_file, settings_file)
    if ok and type(data) == "table" then
        saved_settings = data
    end
end
load_settings()

for i = 1, num_slots do
    slots[i] = {
        selected = 1,
        key_idx  = 1,
        was_down = false,
    }
    if key_map[i + 1] then
        slots[i].key_idx = i + 1
    end
end

if saved_settings["clear_key_idx"] then
    clear_key_idx = saved_settings["clear_key_idx"]
end

for i = 1, num_slots do
    if saved_settings["slot_" .. i .. "_key_idx"] then
        slots[i].key_idx = saved_settings["slot_" .. i .. "_key_idx"]
    end
end

local function save_settings()
    local data = {
        clear_key_idx = clear_key_idx,
    }
    for i = 1, num_slots do
        data["slot_" .. i .. "_key_idx"] = slots[i].key_idx
        if #loaded_names > 0 and slots[i].selected > 0 and loaded_names[slots[i].selected] then
            data[tostring(i)] = loaded_names[slots[i].selected]
        elseif saved_settings[tostring(i)] then
            data[tostring(i)] = saved_settings[tostring(i)]
        end
    end
    pcall(json.dump_file, settings_file, data)
    saved_settings = data
end

local status_msg      = "Enter a mission and click LOAD ENEMIES."
local deferred_calls  = {}
local spawned_enemies = {}

-- ------------------------------------------------------------
-- NATIVE RE ENGINE KEYBOARD HANDLING
-- ------------------------------------------------------------
local _kb_dev = nil
local function ensure_keyboard()
    if _kb_dev then return true end
    local ok1, s  = pcall(sdk.get_native_singleton, "via.hid.Keyboard")
    local ok2, td = pcall(sdk.find_type_definition, "via.hid.Keyboard")
    if not (ok1 and s and ok2 and td) then return false end
    local ok3, dev = pcall(sdk.call_native_func, s, td, "get_Device")
    if not ok3 or not dev then return false end
    _kb_dev = dev
    return true
end

local function kb_is_down(key_id)
    if not key_id then return false end
    if not ensure_keyboard() or not _kb_dev then return false end
    local ok, v = pcall(function() return _kb_dev:call("isDown", key_id) end)
    return ok and (v == true)
end

-- ------------------------------------------------------------
-- SCENE & SPAWN FOLDER MANAGEMENT
-- ------------------------------------------------------------
local scene_mgr_s  = sdk.get_native_singleton("via.SceneManager")
local scene_mgr_td = sdk.find_type_definition("via.SceneManager")
local spawn_folder = nil

local function get_scene()
    if not scene_mgr_s or not scene_mgr_td then return nil end
    return sdk.call_native_func(scene_mgr_s, scene_mgr_td, "get_CurrentScene")
end

local function get_folder()
    if spawn_folder then
        local ok = pcall(function() spawn_folder:call("get_Active") end)
        if ok then return spawn_folder end
    end
    local sc = get_scene()
    if not sc then return nil end
    local ok, f = pcall(sc.call, sc, "findFolder", "SpawnedEnemies_Custom")
    if ok and f then spawn_folder = f end
    return spawn_folder
end

-- ------------------------------------------------------------
-- ENEMY PREFAB LOADING
-- ------------------------------------------------------------
local function load_enemy_prefabs()
    local ok_em, em = pcall(sdk.get_managed_singleton, sdk.game_namespace("EnemyManager"))
    if not ok_em or not em then return "ERROR: EnemyManager does not exist." end

    local pm = em:get_field("PrefabManager")
    if not pm then return "ERROR: PrefabManager is nil." end

    local lst = pm:get_field("EnemyPrefabInfoList")
    if not lst then return "ERROR: EnemyPrefabInfoList is nil." end

    local mi = lst:get_field("mItems")
    if not mi then return "ERROR: mItems is nil." end

    local items = mi:get_elements()
    if not items then return "ERROR: get_elements is nil." end

    loaded_names, loaded_prefabs, loaded_infos = {}, {}, {}
    local count = 0

    for _, info in ipairs(items) do
        local ok_p, pfb = pcall(info.get_field, info, "EnemyPrefab")
        if ok_p and pfb then
            local ok_path, path = pcall(pfb.call, pfb, "get_Path")
            if ok_path and path and path ~= "" then
                local name = path:match("^.+/(.+)%.pfb") or path
                if name:match("em%d%d%d%d") then
                    loaded_prefabs[name] = pfb
                    loaded_infos[name]   = info
                    table.insert(loaded_names, name)
                    count = count + 1
                end
            end
        end
    end

    if count == 0 then return "0 enemies found. Enter a combat scene first." end
    table.sort(loaded_names)

    for i = 1, num_slots do
        local saved_name = saved_settings[tostring(i)]
        if saved_name then
            for idx, name in ipairs(loaded_names) do
                if name == saved_name then
                    slots[i].selected = idx
                    break
                end
            end
        end
    end

    return "OK: " .. count .. " enemies loaded."
end

-- ------------------------------------------------------------
-- WORLD POSITIONING (CAMERA FACING)
-- ------------------------------------------------------------
local function get_spawn_pos()
    local cam = sdk.get_primary_camera()
    if not cam then return nil, nil end
    local mat = cam:call("get_WorldMatrix")
    local pos, fwd = mat[3], mat[2]
    local sp = Vector3f.new(
        pos.x - fwd.x * 5.0,
        pos.y - fwd.y * 5.0,
        pos.z - fwd.z * 5.0
    )
    local rot = Vector4f.new(
        math.random(-100,100) * 0.01, 0.0,
        math.random(-100,100) * 0.01, math.random(-100,100) * 0.01
    ):normalized():to_quat()
    return sp, rot
end

-- ------------------------------------------------------------
-- CLEAR SPAWNED ENEMIES
-- ------------------------------------------------------------
local function clear_spawned_enemies()
    local count = 0
    for _, data in ipairs(spawned_enemies) do
        pcall(function()
            if data.go then data.go:call("destroy", data.go) end
        end)
        count = count + 1
    end
    spawned_enemies = {}
    status_msg = count .. " entities deleted."
end

-- ------------------------------------------------------------
-- SPAWN QUEUE MANAGEMENT
-- ------------------------------------------------------------
local function enqueue_spawn(slot_idx)
    if #loaded_names == 0 then
        status_msg = "Load enemies first."
        return
    end

    local sel  = math.max(1, math.min(slots[slot_idx].selected, #loaded_names))
    local name = loaded_names[sel]

    local pfb  = loaded_prefabs[name]
    local info = loaded_infos[name]

    if not pfb then
        status_msg = "Prefab nil: " .. name
        return
    end

    if info then
        pcall(info.call, info, "requestLoad", false)
        pcall(info.call, info, "update")
    end

    local sp, rot = get_spawn_pos()
    if not sp then
        status_msg = "Camera unavailable."
        return
    end

    deferred_calls[name .. "_" .. os.clock()] = {
        pfb     = pfb,
        info    = info,
        name    = name,
        sp      = sp,
        rot     = rot,
        retries = 0
    }
    status_msg = "Loading: " .. name .. "..."
end

-- ------------------------------------------------------------
-- INSTANTIATION TICK (UpdateMotion)
-- ------------------------------------------------------------
re.on_application_entry("UpdateMotion", function()
    if not next(deferred_calls) then return end
    local folder = get_folder()

    for key, cd in pairs(deferred_calls) do
        local ok_r, is_ready = pcall(cd.info.call, cd.info, "get_isReady")
        if not (ok_r and is_ready) then
            pcall(cd.info.call, cd.info, "update")
            cd.retries = cd.retries + 1
            if cd.retries > 300 then
                deferred_calls[key] = nil
                status_msg = "Timeout waiting for: " .. cd.name
            end
        else
            deferred_calls[key] = nil
            cd.pfb:call("set_Standby", true)

            local result = nil
            if folder then
                local ok, r = pcall(cd.pfb.call, cd.pfb, "instantiate(via.vec3, via.Quaternion, via.Folder)", cd.sp, cd.rot, folder)
                if ok and r then result = r end
            end
            if not result then
                local ok, r = pcall(cd.pfb.call, cd.pfb, "instantiate(via.vec3, via.Quaternion)", cd.sp, cd.rot)
                if ok and r then result = r end
            end
            if not result then
                local ok, r = pcall(cd.pfb.call, cd.pfb, "instantiate(via.vec3)", cd.sp)
                if ok and r then result = r end
            end

            if result then
                local ec = nil
                pcall(function() ec = result:get_component("app.EnemyController") end)
                table.insert(spawned_enemies, { go = result, ec = ec, name = cd.name })

                if ec then
                    local em = sdk.get_managed_singleton(sdk.game_namespace("EnemyManager"))
                    if em then
                        pcall(em.call, em, "requestAddObject", ec)
                    end
                end
                status_msg = "Spawned: " .. cd.name
            else
                status_msg = "FAILED to instantiate: " .. cd.name
            end
        end
    end
end)

-- ------------------------------------------------------------
-- FRAME TICK (KEY DETECTION & SCENE CHANGE)
-- ------------------------------------------------------------
local last_scene = nil
local auto_timer = 0

re.on_frame(function()
    auto_timer = auto_timer + 1
    if auto_timer >= 60 then
        auto_timer = 0
        local sc = get_scene()
        if sc ~= last_scene then
            last_scene = sc
            loaded_names    = {}
            spawned_enemies = {}
            status_msg = "Scene changed. Searching for enemies..."
        end

        if #loaded_names == 0 then
            local msg = load_enemy_prefabs()
            if type(msg) == "string" and msg:match("OK") then
                status_msg = msg .. " (Auto-loaded)"
            end
        end
    end

    -- Clear Hotkey
    local c_key_id = get_key_id(clear_key_idx)
    if c_key_id then
        local down = kb_is_down(c_key_id)
        if down and not clear_was_down then
            clear_spawned_enemies()
        end
        clear_was_down = down
    end

    -- Spawning Hotkeys (Slots 1 to 10)
    if #loaded_names == 0 then return end
    for i = 1, num_slots do
        local key_id = get_key_id(slots[i].key_idx)
        if key_id then
            local down = kb_is_down(key_id)
            if down and not slots[i].was_down then
                enqueue_spawn(i)
            end
            slots[i].was_down = down
        end
    end
end)

-- ------------------------------------------------------------
-- USER INTERFACE (ImGui)
-- ------------------------------------------------------------
re.on_draw_ui(function()
    if imgui.tree_node("Live Enemy Spawner") then
        imgui.text_colored("Status: " .. status_msg, 0xFF00FFAA)
        imgui.spacing()

        if imgui.button("LOAD ENEMIES") then
            status_msg = load_enemy_prefabs()
        end
        imgui.same_line()
        imgui.text("(" .. #loaded_names .. " ready)")

        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        -- Clear Button & Hotkey
        if imgui.button("Clear Spawned", 150, 30) then
            clear_spawned_enemies()
        end
        imgui.same_line()
        imgui.set_next_item_width(100)
        local chC, nsC = imgui.combo("##clearKey", clear_key_idx, key_names)
        if chC then
            clear_key_idx = nsC
            save_settings()
        end
        imgui.same_line()
        imgui.text(" Clear Key")

        imgui.spacing()

        if #loaded_names == 0 then
            imgui.text("Click LOAD ENEMIES while in combat.")
        else
            for i = 1, num_slots do
                imgui.push_id(i)

                imgui.set_next_item_width(100)
                local chK, nsK = imgui.combo("##k" .. i, slots[i].key_idx, key_names)
                if chK then
                    slots[i].key_idx = nsK
                    save_settings()
                end

                imgui.same_line()

                imgui.set_next_item_width(200)
                local ch1, ns = imgui.combo("##e" .. i, slots[i].selected, loaded_names)
                if ch1 then
                    slots[i].selected = ns
                    save_settings()
                end

                imgui.same_line()
                if imgui.button("Spawn!##" .. i) then
                    enqueue_spawn(i)
                end

                imgui.pop_id()
            end

            imgui.spacing()
            imgui.separator()
            imgui.text_colored("Hotkeys work at all times (even with the menu closed).", 0xFFAAFF88)
        end

        imgui.tree_pop()
    end
end)
