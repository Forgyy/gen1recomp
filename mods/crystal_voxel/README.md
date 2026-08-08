# Crystal Voxel Diorama

An experimental Generation 2 renderer for Forgyy's Crystal runtime. It turns
the live 160x144 Game Boy Color frame into a tile-height diorama, deriving
stable height changes from Crystal's active VRAM tile map. It changes only the
presentation; emulation, collision, encounters, saves, and scripts remain
untouched.

## Controls

- `3`: toggle the voxel renderer
- `F3` or `Escape`: open **CRYSTAL MOD OPTIONS**
- Mouse wheel: adjust camera depth while voxel mode is active

The options overlay exposes voxel mode, depth, camera angle, grid lines, and
battle presentation. If a GPU cannot create the mesh, the renderer fails safe
and Crystal falls back to its normal 2D frame.

## Scope

This is a playable VRAM-driven compatibility renderer, not a full native Gen 2
map extraction. The official Dramatic Shape mod remains installed separately
for Red, Blue, and Yellow because it depends on Gen 1-specific world objects.
