# LiveEnemySpawner
Interactive enemy spawner script for DMC5 via REFramework. Allows key-bound spawning for live stream interactions. Shared for free as a work-in-progress script for the community to use, test, or build upon.
================================================================================
              LIVE ENEMY SPAWNER v1.0 FOR DEVIL MAY CRY 5
================================================================================
Author: Generated and optimized via REFramework Lua API
Game: Devil May Cry 5 (PC - Steam / DX11 / DX12)
Prerequisite: REFramework installed in the game's main folder.

--------------------------------------------------------------------------------
1. OVERVIEW
--------------------------------------------------------------------------------
"Live Enemy Spawner" is a lightweight, ultra-stable REFramework Lua script 
that allows you to spawn any enemy present in the current level of Devil May Cry 5 
in real-time. 

Designed for maximum performance, zero framerate drops, and easy control via 
an intuitive ImGui menu or global Hotkeys.

--------------------------------------------------------------------------------
2. KEY FEATURES
--------------------------------------------------------------------------------
- [⚡] Automatic Enemy Detection:
  Automatically indexes all loaded enemy prefabs (`emXXXX`) as soon as you enter 
  combat or a mission.

- [🎯] Camera-Facing Spawning:
  Spawns enemies 5 meters in front of the primary camera with random offset and 
  rotation to avoid overlap.

- [🎹] 10 Customizable Slots:
  Configure up to 10 independent spawn slots. Each slot allows you to select any 
  loaded enemy and assign a dedicated hotkey.

- [⌨️] Extensive Hotkey Support:
  Hotkeys work globally at all times (even with the REFramework menu closed). 
  Supports:
    * Function Keys: F1 to F12
    * Number Keys: 0 to 9
    * Numpad Keys: Numpad 0 to Numpad 9
    * Letters: A to Z
    * Disable option ("No Key")

- [🧹] Instant Clear System:
  Includes a "Clear Spawned" button and a customizable Clear Hotkey to 
  instantly delete all entities spawned by the script without affecting native enemies.

- [💾] Automatic Settings Persistence (JSON):
  All selected enemies and hotkey mappings save automatically to 
  `LiveEnemySpawner_Settings.json` and restore when you re-open the game.

--------------------------------------------------------------------------------
3. INSTALLATION
--------------------------------------------------------------------------------
1. Ensure REFramework is installed in your DMC5 main directory.
2. Copy `LiveEnemySpawner.lua` to:
   `Devil May Cry 5/reframework/autorun/`
3. Launch the game.
4. Press [INSERT] to open the REFramework menu.
5. Expand "Live Enemy Spawner".

================================================================================
                             Enjoy the Mod!
================================================================================
