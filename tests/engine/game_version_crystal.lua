package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness").suite("Crystal cartridge registry")
local check, eq = T.check, T.eq

love = love or require("tests.love_stub")

local GameVersion = require("src.core.GameVersion")
local LaunchOptions = require("src.core.LaunchOptions")
local RomImporter = require("src.import.RomImporter")
local SaveConvert = require("src.save_convert.SaveConvert")

local crystal = GameVersion.info("crystal")
eq(crystal.generation, 2, "Crystal is routed to the Gen 2 runtime")
eq(crystal.romBytes, 2 * 1024 * 1024, "Crystal records its 2 MiB size")
eq(crystal.sha1, "f4cd194bdee0d04ca4eac29e09b8e4e9d818c133",
  "Crystal v1.0 uses the canonical ROM hash")
check(GameVersion.isImportable("crystal"),
  "Crystal imports through its dedicated Lua runtime")
eq(crystal.runtime, "lua-gbc", "Crystal does not enter the Gen 1 extractor")
eq(GameVersion.forSha1(crystal.sha1), "crystal",
  "the canonical hash is recognized")
eq(GameVersion.forRom(crystal.sha1, crystal.romBytes), "crystal",
  "hash and size resolve the cartridge")
eq(GameVersion.forRom(crystal.sha1, 1024 * 1024), nil,
  "a known hash with the wrong size is rejected")
check(GameVersion.isKnownRomSize(1024 * 1024), "Gen 1 ROM size remains known")
check(GameVersion.isKnownRomSize(2 * 1024 * 1024), "Gen 2 ROM size is known")
check(not GameVersion.isKnownRomSize(3 * 1024 * 1024),
  "unregistered cartridge sizes stay unknown")

local game = LaunchOptions.resolve({ "--game=crystal" })
eq(game, "crystal", "the full Crystal launch option opens its launcher tab")
game = LaunchOptions.resolve({ "--game=c" })
eq(game, "crystal", "the c alias opens the Crystal launcher tab")

love.data = love.data or {}
local oldHash, oldEncode = love.data.hash, love.data.encode
love.data.hash = function(_, data) return { first = data:sub(1, 1) } end
love.data.encode = function(_, _, digest)
  if digest.first == "C" then return crystal.sha1 end
  return "0000000000000000000000000000000000000000"
end

local importer = setmetatable({
  launcher = true,
  tab = "red",
  ready = { red = false, blue = false, yellow = false, crystal = false },
}, RomImporter)
importer:startData(string.rep("C", crystal.romBytes), "crystal.gbc")
eq(importer.tab, "crystal", "a dropped Crystal ROM routes to the Crystal tab")
eq(importer.workState, "working", "the dedicated Crystal import starts")
eq(importer.importing, "crystal", "the import is owned by the Crystal runtime")
check(type(importer.worker) == "thread", "Crystal receives an import worker")

local converted, convertError = SaveConvert.importSav(
  string.rep(string.char(0), SaveConvert.SAVE_SIZE), nil, "crystal")
eq(converted, nil, "Crystal saves cannot enter the Gen 1 codec")
check(tostring(convertError):find("not implemented", 1, true) ~= nil,
  "the Gen 1 structured save codec remains fenced from Crystal")

love.data.hash, love.data.encode = oldHash, oldEncode

T.finish("Crystal cartridge registry")
