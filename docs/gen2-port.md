# Pokemon Crystal Runtime

## Target Cartridge

The supported Gen 2 cartridge is the canonical US Pokemon Crystal v1.0 ROM:

- size: 2 MiB (2,097,152 bytes)
- SHA-1: `f4cd194bdee0d04ca4eac29e09b8e4e9d818c133`
- development reference: `pret/pokecrystal`

The ROM is always user-supplied. Import verifies its complete SHA-1 before a
private copy is stored under Crystal's per-user cache. Release archives never
contain ROM bytes.

## Runtime Design

Crystal runs through the vendored BSD-licensed LuaGB core. The CPU, PPU, APU,
MBC3 mapper, battery RAM, and real-time clock remain Lua, so the same source
payload works in LÖVE desktop, Android, iOS, and supported handheld builds
without a native emulator DLL.

`src/gen2/CrystalRuntime.lua` bridges the core to the existing product shell:

- keyboard, controller, and touch bindings
- game-speed controls and display hotkeys
- fullscreen, orientation, faithful-resolution, frame-cap, and audio options
- battery/RTC persistence, save import/export, and quick state
- portable storage on desktop and normal app storage on mobile

Crystal intentionally bypasses the Gen 1 ROM extractor and save converter.
Its verified ROM is read only by the Gen 2 runtime.

## Mod Compatibility

Crystal loads normal API v2 mods from the same `mods/` directory used by the
Gen 1 games. Manifests opt in with `"game_generations": [2]` (or `[1, 2]` for
shared mods); manifests without the field remain Gen 1-only. This prevents an
older content mod from mutating Gen 1 data structures while Crystal is active.

Generation 2 render mods can register through
`src/gen2/CrystalModApi.lua`. Each frame supplies the live 160x144 image,
VRAM, OAM, LCD scroll/window registers, map identity, player coordinates and
direction, time of day, battle mode/type, and active battle species. Input
callbacks cover keyboard, controller, mouse, wheel, and touch, so one mod
package works on desktop and mobile.

The Crystal-compatible Dramatic Shape package keeps its full settings schema:
VOXEL, V-GRID, T-SHIFT, V-CURVE, WATER, FOREST FX, 3D-BTL, BACK SPRITES,
DAYTIME, AA, VR, and SMOOTH TURN. Its desktop hotkeys are `3`, `5`, `6`, `7`,
`8`, `9`, `0`, `B`, `V`, and `O`; `Q`/`E`, the mouse wheel, mouse look, right
stick, and the mobile `3D`/`FX` buttons control the camera and effects.

Crystal cannot inject host rows into the cartridge's original `OPTIONS`
screen. Press `F3` or `Escape` during play to open the host-side **CRYSTAL MOD
OPTIONS** overlay. On a controller, hold Select and press Start (the Guide
button also opens it); on touch screens, tap the `MOD OPTIONS` button at the
top center. The overlay pauses emulation, persists changes immediately, and
delivers `mod.options_changed` to the active mod.

## Metadata and Verification

Build the metadata-only manifest from `pret/pokecrystal` and the published v1.0
RGBDS symbols:

```powershell
python tools/make_crystal_manifest.py `
  --pokecrystal ../pokecrystal `
  --symbols ../pokecrystal-symbols/pokecrystal.sym
```

Verify a user ROM and all 388 map pointer chains with:

```powershell
python tools/verify_crystal_rom.py --rom "C:\path\to\Pokemon Crystal.gbc"
```

The generated `tools/gen2/rom_manifest_crystal.json` contains addresses and
metadata only, never copyrighted ROM payload.

## Packaging

All desktop and mobile packagers include `vendor/luagb`, its license, the Gen 2
runtime, and the Crystal manifest. Required-file gates fail the build if any of
those files are missing, and payload verification rejects private ROM files.
