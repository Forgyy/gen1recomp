package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local T = require("tests.harness").suite("Crystal voxel mod")
local check, eq = T.check, T.eq

local values, schema = {}, nil
local fakeMod = {
  id = "CRYSTAL_VOXEL",
  exports = {},
  options = {
    define = function(_, rows)
      schema = rows
      for _, row in ipairs(rows) do values[row.key] = row.default end
    end,
    get = function(_, key) return values[key] end,
  },
  log = { error = function() end },
}

package.loaded["src.gen2.CrystalModApi"] = nil
local Api = require("src.gen2.CrystalModApi")
local chunk = assert(loadfile("mods/crystal_voxel/main.lua"))
chunk(fakeMod)

eq(#schema, 5, "the Crystal options overlay receives every voxel setting")
check(fakeMod.exports.renderer, "the mod exports its renderer for diagnostics")
local renderer = fakeMod.exports.renderer

local rom = {}
local blockBase, collisionBase = 0x5000, 0x6000
rom[blockBase] = 2
rom[blockBase + 1] = 5
rom[collisionBase + 2 * 4] = 0x07
rom[collisionBase + 2 * 4 + 1] = 0x00
rom[collisionBase + 2 * 4 + 2] = 0x7a
rom[collisionBase + 2 * 4 + 3] = 0x90
rom[collisionBase + 5 * 4] = 0x29
local mapState = {
  mapWidth = 2, mapHeight = 1, mapBlocksBank = 1,
  mapBlocksPointer = blockBase, tilesetCollisionBank = 1,
  tilesetCollisionAddress = collisionBase,
  readRom = function(_, address) return rom[address] or 0 end,
}
eq(renderer.mapCollisionAt(mapState, 0, 0), 0x07,
  "block collision exposes solid walls")
eq(renderer.mapCollisionAt(mapState, 1, 0), 0x00,
  "block collision exposes walkable floors")
eq(renderer.mapCollisionAt(mapState, 0, 1), 0x7a,
  "block collision selects the lower metatile quadrant")
eq(renderer.mapCollisionAt(mapState, 2, 0), 0x29,
  "block collision advances through map blocks")
eq(renderer.mapCollisionAt(mapState, -1, 0), nil,
  "connected-map edges can fall back until their border data is available")
eq(renderer.heightForCollision(0x00, 6), 0,
  "floors remain on the walk plane")
eq(renderer.heightForCollision(0x07, 6), 6,
  "walls use full voxel depth")
eq(renderer.heightForCollision(0x90, 6), 6,
  "counters and furniture use full voxel depth")
eq(renderer.heightForCollision(0x7a, 6), 2,
  "stairs receive a shallow rise")
eq(renderer.heightForCollision(0xa0, 6), 3,
  "ledges receive a half-height curb")
eq(renderer.heightForCollision(0x29, 6), 0,
  "water remains on a low plane")

mapState.playerX, mapState.playerY = 4, 4
eq(renderer.visibleCollisionAt(mapState, 9, 8), 0x07,
  "the player-centered screen cell maps to Crystal's padded coordinates")

local meshTexture
love.graphics.newMesh = function(vertices)
  check(#vertices > 2000, "the live frame is split into a full tile mesh")
  return { setTexture = function(_, texture) meshTexture = texture end }
end
love.graphics.push = function() end
love.graphics.pop = function() end
love.graphics.clear = function() end
love.graphics.setColor = function() end
love.graphics.ellipse = function() end
love.graphics.draw = function() end
love.graphics.setLineWidth = function() end
love.graphics.line = function() end

local vram = {}
for address = 0x9800, 0x9fff do vram[address] = address % 251 end
for address = 0xd800, 0xdfff do vram[address] = address % 7 end
local writes, notices = 0, {}
local game = {
  options = {},
  mods = { modOptions = {}, events = { emit = function() end } },
  writeOptions = function() writes = writes + 1 end,
  _setNotice = function(_, message) notices[#notices + 1] = message end,
  core = {
    getFrameImage = function() return "crystal-frame" end,
    gameboy = {
      memory = { work_ram_0 = {}, work_ram_1_raw = {} },
      io = { ram = { [0x40] = 0x08, [0x42] = 3, [0x43] = 5 } },
      graphics = { vram = vram, oam_raw = {}, vblank_count = 10 },
    },
  },
}

check(not Api.draw(game, 960, 864),
  "title and menu frames stay in faithful 2D")
game.core.gameboy.memory.work_ram_1_raw[0xdcb5] = 1
game.core.gameboy.memory.work_ram_1_raw[0xdcb6] = 1
check(Api.draw(game, 960, 864), "the voxel renderer owns a Crystal frame")
eq(meshTexture, "crystal-frame", "the mesh uses the live emulator image")
check(Api.keypressed(game, "3"), "the renderer claims its voxel hotkey")
eq(game.options.modOptions.CRYSTAL_VOXEL.enabled, false,
  "the voxel hotkey persists the disabled state")
eq(writes, 1, "the voxel hotkey saves options")
check(notices[1]:find("OFF", 1, true) ~= nil, "the hotkey reports its state")

T.finish("Crystal voxel mod")
