# Nightfall

A Roblox zombie-survival game: gather, craft and build by day, survive by night. 40 nights, bosses on night 20 (Zombie King) and 40 (The Overlord). First-person gunplay with projectile bullets, rarity-based loot, buildable bases with structural collapse, a sky lobby and squads of up to 5.

The whole game is Luau code. The world generates when the game starts, so there are no model or asset dependencies.

## Layout

```
src/
  ReplicatedStorage/        Config.lua (all tuning), Regions.lua, BuildShared.lua
  ServerScriptService/      Main.server.lua (run loop), Modules/ (Zombies, Combat, Build, World, Loot, ...)
  StarterPlayer/StarterPlayerScripts/Client.client.lua   HUD, viewmodel, ADS, flashlight, minimap
tools/                      build_place.py, build_installer.py
builds/                     generated Nightfall.rbxlx and Nightfall-Installer.txt
assets/                     cover image and icons
```

## Build and publish

Needs Python 3 only.

```
python3 tools/build_place.py       # -> builds/Nightfall.rbxlx
python3 tools/build_installer.py   # -> builds/Nightfall-Installer.txt
```

- Open `Nightfall.rbxlx` in Roblox Studio, then File > Publish to Roblox (overwrites the linked game).
- Or open the published game in Studio, paste `Nightfall-Installer.txt` into the Command Bar, press Enter, then publish.

The `src/` folder is the source of truth. Do not edit scripts inside Studio and forget to copy them back.

## Tuning (src/ReplicatedStorage/Config.lua)

| Setting | What it does |
| --- | --- |
| `Pace` | Global game speed: zombie speed, attack rate, spawn rate, day/night length |
| `FallDamagePerStud`, `FallSafeHeight` | Fall damage |
| `GunStructureDamage` | How hard bullets hit player-built structures |
| `Flashlight` | Night flashlight angles, range, brightness |
| `CaveRespawnDelay` | How fast cave zombies respawn |
| `MaxPlayers` | Squad size per run |
| `Weapons`, `Zombies`, `BuildPieces`, `BuildMats` | Stats and costs |

Client-only constants (gun size, recoil) are at the top of `Client.client.lua`: `VM_SCALE`, `RECOIL_SCALE`, `ADS_DROP`.

## Known untested areas

Checked only with the Luau compiler, not in a live Studio session: zombie pathfinding up ramps and skyscrapers, the structural collapse system, flashlight direction on every gun, viewmodel placement and ADS alignment.

## Working together

- Make changes in `src/`, run the two build scripts, test in Studio, commit both.
- Keep one feature per branch. Merge conflicts in `Config.lua` are the likely hot spot, so keep edits there small.
