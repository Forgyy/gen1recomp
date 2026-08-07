package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local S = require("tests.harness").suite("Crystal save file I/O")
local check, eq = S.check, S.eq

local batteryFiles = {}
package.loaded["src.gen2.CrystalStorage"] = {
  read = function(path) return batteryFiles[path] end,
  write = function(path, bytes) batteryFiles[path] = bytes return true end,
}

local SaveData = require("src.core.SaveData")
local savedPortableFs = SaveData.portableFs
local savedPortableBaseDir = SaveData.portableBaseDir
SaveData.portableFs = function() return nil end
SaveData.portableBaseDir = function() return nil end

local exported = {}
local savedFilesystem = love.filesystem
love.filesystem = {
  write = function(path, bytes) exported[path] = bytes return true end,
  createDirectory = function() return true end,
  getSaveDirectory = function() return "/fake/save" end,
}

local SaveFileIO = require("src.import.SaveFileIO")
local bytes = string.rep("C", 32768)
local ok, slot = SaveFileIO.importToSlot(bytes, "crystal")
eq(ok, true, "Crystal battery import succeeds")
eq(slot, "battery", "Crystal import targets the battery save")
eq(batteryFiles["pokemon_crystal.sav"], bytes,
  "Crystal storage receives an unprefixed battery path")

local oversized = {
  data = bytes .. string.rep("R", 44),
  open = function() return true end,
  getSize = function(self) return #self.data end,
  read = function(self) return self.data end,
  close = function() return true end,
}
local oversizedOk, oversizedError, info = SaveFileIO.importToSlot(
  oversized, "crystal")
eq(oversizedOk, false, "RTC-appended save requests confirmation")
eq(oversizedError, nil, "confirmation is not reported as an error")
check(info and info.needsConfirm and info.size == 32812,
  "confirmation reports the appended save size")

local forcedOk = SaveFileIO.importToSlot(oversized, "crystal", true)
eq(forcedOk, true, "confirmed RTC-appended save imports")
eq(#batteryFiles["pokemon_crystal.sav"], 32768,
  "confirmed import drops the emulator footer")

local exportOk, exportPath = SaveFileIO.exportActiveSlot("crystal")
eq(exportOk, true, "Crystal battery export succeeds")
eq(exportPath, "/fake/save/exports/crystal/gen1recomp-crystal.sav",
  "Crystal export reports its absolute save path")
eq(exported["exports/crystal/gen1recomp-crystal.sav"], bytes,
  "Crystal export preserves all battery bytes")

love.filesystem = savedFilesystem
SaveData.portableFs = savedPortableFs
SaveData.portableBaseDir = savedPortableBaseDir
package.loaded["src.gen2.CrystalStorage"] = nil

S.finish()
