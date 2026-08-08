# Crystal Capability Status

This branch combines the latest `bryanthaboi/gen1recomp` `dev` branch with the
three commits from Forgyy's `codex/gen2-crystal-foundation` branch.

## Working foundation

- canonical US Pokemon Crystal v1.0 ROM verification and launcher routing
- LuaGB-backed CPU, PPU, APU, MBC3, battery RAM, and real-time clock
- keyboard, controller, touch, speed, display, fullscreen, and orientation
- battery saves, RTC persistence, import/export hooks, and quick state
- Generation 2-aware mod manifests and loader isolation
- live frame, VRAM, OAM, scroll/window, map, player, battle, and time-of-day
  snapshots for visual mods
- host-side Crystal mod options on F3/Escape
- experimental Crystal Voxel Diorama mod with persisted presentation options

## Important boundary

Crystal currently runs through an emulator core inside the shared product
shell. It does not yet have Gen 1's hand-written Lua world, battle, scripting,
content registries, save editor, native link protocol, or extracted map data.
Therefore it has broad player-facing compatibility, but not complete internal
feature parity with Red, Blue, and Yellow.

The Crystal voxel renderer uses the live framebuffer and VRAM tile map to build
a stable tile-height diorama. A future native-quality port should decode Gen 2
maps, blocks, collision, objects, palettes, and scripts into dedicated runtime
registries, then adapt the official Dramatic Shape scene builders to those
registries.

## Validation performed

- all dedicated Crystal engine tests pass: version routing, metadata manifest,
  saves, RTC, mod host, mod options, and Windows launcher routing
- Crystal Voxel Diorama: 9/9 dedicated checks pass
- Quality of Life Pack: 16/16 checks pass against imported Red data
- canonical Red ROM import smoke test exits successfully under LÖVE 11.5
- no canonical Crystal ROM was found locally, so an end-to-end Crystal boot and
  screenshot remains to be run when the user supplies/imports that ROM

