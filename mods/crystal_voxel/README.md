# Crystal Voxel Diorama

An experimental Generation 2 renderer for Forgyy's Crystal runtime. It turns
the live 160x144 Game Boy Color frame into a tile-height diorama. Overworld
height comes from Crystal's native map blocks and collision tables, so floors,
walls, furniture, stairs, ledges, grass, and water keep stable geometry while
the animated frame remains the texture. It changes only the presentation;
emulation, collision, encounters, saves, and scripts remain untouched.

## Controls

- `3`: toggle the voxel renderer
- `F3` or `Escape`: open **CRYSTAL MOD OPTIONS**
- Mouse wheel: adjust camera depth while voxel mode is active

The options overlay exposes voxel mode, depth, camera angle, grid lines, and
battle presentation. If a GPU cannot create the mesh, the renderer fails safe
and Crystal falls back to its normal 2D frame.

## Scope

This is a playable map-aware compatibility renderer, not yet a full native Gen
2 scene extraction. At connected-map edges, it falls back to the live tile
profile until neighboring connection geometry is decoded. The official
Dramatic Shape mod remains installed separately for Red, Blue, and Yellow
because its objects and world hooks are specific to Gen 1.
