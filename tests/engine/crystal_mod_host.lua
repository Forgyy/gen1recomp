package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local T = require("tests.harness").suite("Crystal mod host")
local check, eq = T.check, T.eq
local Json = require("src.link.Json")
local Loader = require("src.mods.Loader")
local Manifest = require("src.mods.Manifest")

local manifest = Manifest.validate(Json.decode([[
  {
    "id": "BOTH_GENS",
    "name": "Both generations",
    "version": "1.0.0",
    "entry": "main.lua",
    "game_generations": [1, 2]
  }
]]), "mods/BOTH_GENS")
eq(#manifest.game_generations, 2, "manifest preserves generation declarations")
eq(manifest.game_generations[2], 2, "Gen 2 can be declared explicitly")

local files = {
  ["mods/GEN1/manifest.json"] = [[
    {"id":"GEN1","name":"Gen 1","version":"1.0.0","entry":"main.lua"}
  ]],
  ["mods/GEN1/main.lua"] = "return function(mod) mod.exports.loaded = true end",
  ["mods/GEN2/manifest.json"] = [[
    {"id":"GEN2","name":"Gen 2","version":"1.0.0","entry":"main.lua",
     "game_generations":[2]}
  ]],
  ["mods/GEN2/main.lua"] = "return function(mod) mod.exports.loaded = true end",
}

local fs = {
  read = function(path) return files[path] end,
  getInfo = function(path)
    if files[path] then return { type = "file" } end
    local prefix = path .. "/"
    for candidate in pairs(files) do
      if candidate:sub(1, #prefix) == prefix then return { type = "directory" } end
    end
  end,
  getDirectoryItems = function(path)
    if path == "mods" then return { "GEN1", "GEN2" } end
    return {}
  end,
  load = function(path)
    local source = files[path]
    if not source then return nil, "missing " .. path end
    return load(source, "@" .. path)
  end,
}

local loader = Loader.new({ fs = fs, generation = 2, skipBuiltins = true,
  game = {} })
loader:load({ generation = 2 })
local byId = {}
for _, status in ipairs(loader:status().available) do byId[status.id] = status end
eq(byId.GEN2.state, "loaded", "a Gen 2 mod loads in Crystal")
eq(byId.GEN1.state, "incompatible", "a legacy Gen 1 mod stays isolated")
eq(#loader.errors, 0, "other-generation mods do not become boot errors")

package.loaded["src.gen2.CrystalModApi"] = nil
local Api = require("src.gen2.CrystalModApi")
local handled = {}
Api.register("TEST", {
  draw = function(_, _, width, height, state)
    handled.draw = { width, height, state.mapGroup, state.inBattle,
      state.mapBlocksPointer, state.readRom(2, 0x4003), state.windowEnabled }
    return true
  end,
  keypressed = function(_, _, key)
    handled.key = key
    return key == "3"
  end,
})

local raw = {}
raw[0xdcb5] = 24
raw[0xd22d] = 1
raw[0xd1a1] = 0x34
raw[0xd1a2] = 0x52
local rom = { [2 * 0x4000 + 3] = 0x9a }
local game = { core = {
  getFrameImage = function() return "frame" end,
  gameboy = {
    memory = { work_ram_0 = {}, work_ram_1_raw = raw },
    io = { ram = { [0x43] = 7, [0x42] = 9 } },
    cartridge = { raw_data = rom },
    graphics = { vram = {}, oam_raw = {}, registers = {
      window_enabled = true,
    } },
  },
} }
check(Api.draw(game, 960, 864), "registered Crystal renderer owns the frame")
eq(handled.draw[1], 960, "renderer receives output width")
eq(handled.draw[3], 24, "snapshot reads banked Crystal WRAM")
check(handled.draw[4], "snapshot exposes battle state")
eq(handled.draw[5], 0x5234, "snapshot reads little-endian Crystal pointers")
eq(handled.draw[6], 0x9a, "snapshot exposes banked ROM reads")
check(handled.draw[7], "snapshot exposes PPU layer state")
check(Api.keypressed(game, "3"), "renderer can claim a Crystal hotkey")
eq(handled.key, "3", "renderer receives the claimed key")

T.finish("Crystal mod host")
