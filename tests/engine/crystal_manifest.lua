package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness").suite("Crystal metadata manifest")
local check, eq = T.check, T.eq
local Json = require("src.link.Json")

local source = assert(io.open("tools/gen2/rom_manifest_crystal.json", "rb"))
local manifest = Json.decode(source:read("*a"))
source:close()

eq(manifest.format, 3, "Crystal uses the generation-aware manifest format")
eq(manifest.generation, 2, "the manifest identifies Gen 2")
eq(manifest.romSha1, "f4cd194bdee0d04ca4eac29e09b8e4e9d818c133",
  "the manifest is tied to canonical Crystal v1.0")
eq(manifest.romBytes, 2 * 1024 * 1024, "the manifest records the ROM size")
eq(#manifest.constants.species, 251, "all 251 species IDs are present")
eq(#manifest.constants.moves, 252, "NO_MOVE plus all 251 move IDs are present")
eq(#manifest.constants.tilesets, 36, "all Crystal tilesets are present")
eq(#manifest.constants.trainerClasses, 68, "all trainer classes are present")
eq(#manifest.constants.mapGroups, 26, "all map groups are present")
eq(#manifest.maps, 388, "all maps are present")
eq(#manifest.symbols.MapGroupPointers, 2, "core symbols store bank/address pairs")
eq(manifest.symbols.MapGroupPointers[1], 0x25,
  "MapGroupPointers uses the published v1.0 bank")
eq(manifest.symbols.MapGroupPointers[2], 0x4000,
  "MapGroupPointers uses the published v1.0 address")
check(manifest.symbols.NewBarkTown_MapAttributes ~= nil,
  "map attributes are addressable")
check(manifest.symbols.NewBarkTown_MapEvents ~= nil,
  "map events are addressable")

T.finish("Crystal metadata manifest")
