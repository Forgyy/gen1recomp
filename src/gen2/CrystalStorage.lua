local CacheFs = require("src.import.CacheFs")

local CrystalStorage = {}
local unpackValues = unpack or table.unpack

local function withPrefix(callback)
  local saved = CacheFs.prefix
  CacheFs.prefix = "crystal/"
  local results = { pcall(callback) }
  CacheFs.prefix = saved
  if not results[1] then error(results[2]) end
  return unpackValues(results, 2)
end

function CrystalStorage.read(path)
  return withPrefix(function() return CacheFs.read(path) end)
end

function CrystalStorage.write(path, data)
  return withPrefix(function() return CacheFs.write(path, data) end)
end

function CrystalStorage.remove(path)
  return withPrefix(function() return CacheFs.remove(path) end)
end

return CrystalStorage
