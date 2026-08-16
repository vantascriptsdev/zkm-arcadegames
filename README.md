# zkm-arcadegames

[![Release](https://img.shields.io/badge/Release-v1.0.0-orange?logo=github&logoColor=white)](https://github.com/vantascriptsdev/zkm-arcadegames)
[![Stars](https://img.shields.io/badge/Stars-%E2%98%85-yellow?logo=github&logoColor=white)](https://github.com/vantascriptsdev/zkm-arcadegames)
[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white)](https://discord.gg/t49zykYPKm)

[![Framework](https://img.shields.io/badge/Framework-ESX%20%7C%20QBox-blue)](https://github.com/vantascriptsdev/zkm-arcadegames)

Four casino-style machines. Walk up to a Machine Prop, Select the option to play, and a nice UI renders straight onto its screen while the camera zooms in on it. (Based on base-position of the arcade prop)

## Games

- **Crash** — a multiplier climbs every tick, cash out before it busts
- **Plinko** — drop a ball through a peg board on one of three risk tiers, the slot it lands in sets the payout
- **Higher or Lower** — call whether the next card beats the current one, each correct call raises the multiplier
- **Mines** — clear tiles on a grid while dodging hidden bombs, cash out whenever you want

*Any of them can be turned off in the config if you only want a couple.*

## Preview

### [You can try it right now in your browser →](https://arcadegames.vantascripts.dev/)

[![Watch Now](https://img.shields.io/badge/YouTube-Watch%20Now-red?logo=youtube&logoColor=white)](https://youtu.be/GmSRJ6o59Ho)
[![Live Preview](https://img.shields.io/badge/Live%20Preview-arcadegames.vantascripts.dev-blue?logo=googlechrome&logoColor=white)](https://arcadegames.vantascripts.dev/)


## Features

- One house edge setting (`Config.gameSettings.houseEdge`) that every game's odds get calculated against, so tuning the cut doesn't mean re-balancing four games by hand
- **ADMIN ONLY:** In-game /arcadeadmin placement tool for cabinets: nudge, rotate, and snap to ground with keybinds instead of typing coordinates
- Camera zooms into the cabinet screen when you sit down, angle/zoom are all configurable
- **LIVE SYNC:** Players standing near an occupied machine see the stake and round update live
- Machines lock server-side, so alt-f4ing or relogging mid-round doesn't dodge a loss
- Works on [ESX](https://github.com/esx-framework) and [QBOX](https://github.com/Qbox-project), auto-detects which one is running
- Uses [ox_target](https://github.com/overextended/ox_target) if it's present, falls back to a proximity prompt if not

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. Drop the resource in as `zkm-arcadegames`.
2. `ensure zkm-arcadegames` after ox_lib and oxmysql in your server.cfg.
3. The machine table creates itself from `sql/schema.sql` on first start, nothing to import manually.
4. Grant yourself the `zkm_arcade.admin` ace and run `/arcadeadmin` in-game to place your first cabinet.

## Placement tool

`/arcadeadmin` opens a manager for creating, moving, and deleting cabinets. While placing one: WASD nudges it, Q/R changes height, Z/C rotates, F snaps to the ground, M drags it to wherever you're looking, G cycles the game, X cycles the step size, and Enter/Esc confirm or cancel.

## Configuration

Everything's in `config.lua`, framework, per-game bet limits and multiplier caps, the house edge, camera framing, and the admin placement sensitivity are all there with comments explaining what each value does.

## Status

Ready to use, with more games planned down the line.