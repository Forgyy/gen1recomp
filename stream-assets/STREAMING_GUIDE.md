# Crystal Stream Kit

## Ready-to-use overlays

- `crystal-mobile-1080x1920.png` — portrait 9:16 canvas for Shorts, TikTok,
  Reels, or a vertical stream. Put the game in the large center frame, camera
  in the upper-right frame, and alerts/chat in the bottom panel.
- `crystal-fullscreen-2560x1440.png` — QHD 16:9 canvas. Keep gameplay full
  screen, camera in the lower-right frame, and goal/recent-event text in the
  lower-left bar.

Both final PNGs are RGBA with real transparency. Add them to OBS as an Image
source above Game Capture and webcam sources. Do not apply a chroma-key filter
to the final PNGs.

## Recommended OBS layout

### Portrait 1080x1920

1. Canvas and output: 1080x1920 at 60 fps.
2. Crop Game Capture into the large center frame; preserve aspect ratio and
   use nearest-neighbor or point filtering for pixel art.
3. Crop webcam to the upper-right frame.
4. Put alerts, current objective, or chat text over the bottom blue panel.
5. Keep browser-source text at least 48 px tall for phone readability.

### QHD 2560x1440

1. Canvas and output: 2560x1440 at 60 fps.
2. Fill the canvas with Game Capture, then place the overlay above it.
3. Crop webcam to the lower-right frame.
4. Use the lower-left strip for a recent event, run rule, or current goal.
5. Capture the game directly; avoid Display Capture if notifications could
   reveal personal information.

## Stream title options

Best default:

> LIVE: Pokemon Crystal in 3D Voxels?! Gen 2 PC Port First Look

Alternatives:

1. Pokemon Crystal Gets a Voxel Makeover | Crystal Recomp Mod LIVE
2. Can Pokemon Crystal Become HD-2D? Building a Voxel Gen 2 Mod Live
3. I Added Pokemon Crystal to Gen1Recomp — Voxel Mod Test Stream
4. Pokemon Crystal PC Port + Voxel Diorama | Full Johto Playthrough
5. This Pokemon Crystal Voxel Mod Changes Everything | LIVE Gameplay
6. Pokemon Crystal on PC in 2026 — Mods, Voxels, and Johto LIVE
7. Gen1Recomp Now Runs Pokemon Crystal?! Full Mod Showcase
8. From Game Boy Color to 3D Diorama — Pokemon Crystal LIVE

Suggested description opener:

> We are testing an experimental Pokemon Crystal compatibility runtime inside
> Gen1Recomp, including a live VRAM-driven voxel diorama, modern display
> options, controller support, saves, RTC, and Gen 2-aware mods. This is an
> unofficial fan-made project and requires a legally obtained Crystal ROM.

Suggested tags:

`pokemon crystal`, `pokemon crystal mod`, `gen1recomp`, `voxel mod`, `pokemon
pc port`, `johto`, `retro gaming`, `hd2d pokemon`, `pokemon crystal gameplay`,
`game boy color`, `pokemon mods`, `live stream`

## Mod choices

| Choice | Best for | Current status in this build |
|---|---|---|
| Dramatic Shape Voxel Mod 1.7.2 | The most striking Red/Blue/Yellow stream presentation, 3D battles, and optional VR | Installed for Gen 1; standard voxel mode loads. Advanced VR, Stadium, Horde, and some option-schema tests remain experimental against the newest engine. |
| Crystal Voxel Diorama 0.1.0 | A Crystal-safe 2.5D/voxel presentation | Installed and enabled for Gen 2 only; dedicated renderer test passes. |
| Quality of Life Pack 1.0.0 | Faster progression, catch help, discounts, and stream-visible play stats | Preserved from the previous install; 16/16 checks pass. |
| Nuzlocke 1.0.0 | High-stakes challenge streams with permanent death and encounter rules | Bundled by current upstream for Gen 1; keep disabled unless the stream is explicitly a Nuzlocke. |
| Camera + Skybox fork | Free camera movement, skyboxes, and remappable camera hotkeys | Do not combine by default: it is a full engine fork rather than a normal mod and would replace newer upstream/Forgyy code. Test in a separate copy if desired. |

Crystal ROM hacks such as Polished Crystal or Crystal Legacy are not drop-in
choices here. The current importer intentionally accepts only the canonical US
Crystal v1.0 SHA-1, so patched ROMs need a separate compatibility project.
