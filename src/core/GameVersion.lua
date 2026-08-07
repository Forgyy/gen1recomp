-- Which game this process is running.  One source of truth for everything
-- that differs by cartridge -- generation, accepted ROM hash and size,
-- import manifest, cache location, save suffix, and launcher presentation.
--
-- Crystal uses a dedicated Lua Game Boy Color runtime. Its verified ROM is
-- stored privately without passing through the Gen 1 data extractor.
--
-- Red keeps the un-suffixed save paths it always used (save.lua) so existing
-- saves are untouched, but its extracted cache lives under red/ like Blue and
-- Yellow (issue #899); a legacy root cache is moved into red/ once by
-- CacheFs.migrateLegacyRedCache.  All three versions can be imported and
-- played side by side.
--
-- Zero requires, so it loads during love.conf and under plain Lua for tools
-- and tests.  The active version is a process-global set once at boot from
-- the launcher's column choice (main.lua); it defaults to Red.

local GameVersion = {}

GameVersion.VERSIONS = {
  red = {
    id = "red",
    label = "Red",
    displayName = "Pokemon Red",
    launcherName = "Red",       -- game-panel header in the launcher
    sha1 = "ea9bcae617fdf159b045185467ae58b2e4a48b9a",
    generation = 1,
    romBytes = 1024 * 1024,
    romExtension = ".gb",
    importable = true,
    launcherLetter = "R",
    launcherColor = "red",
    manifest = "tools/rom_manifest.json",
    cachePrefix = "red/",   -- red/data/generated, red/assets/generated (#899)
    saveSuffix = "",        -- save.lua / save.lua.bak / save.lua.tmp
  },
  blue = {
    id = "blue",
    label = "Blue",
    displayName = "Pokemon Blue",
    launcherName = "Blue",
    sha1 = "d7037c83e1ae5b39bde3c30787637ba1d4c48ce2",
    generation = 1,
    romBytes = 1024 * 1024,
    romExtension = ".gb",
    importable = true,
    launcherLetter = "B",
    launcherColor = "blue",
    manifest = "tools/rom_manifest_blue.json",
    cachePrefix = "blue/",  -- blue/data/generated, blue/assets/generated
    saveSuffix = "_blue",   -- save_blue.lua / .bak / .tmp
  },
  yellow = {
    id = "yellow",
    label = "Yellow",
    displayName = "Pokemon Yellow",
    launcherName = "Yellow",
    sha1 = "cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1",
    generation = 1,
    romBytes = 1024 * 1024,
    romExtension = ".gbc",
    importable = true,
    launcherLetter = "Y",
    launcherColor = "yellow",
    manifest = "tools/rom_manifest_yellow.json",
    cachePrefix = "yellow/",  -- yellow/data/generated, yellow/assets/generated
    saveSuffix = "_yellow",   -- save_yellow.lua / .bak / .tmp
  },
  crystal = {
    id = "crystal",
    label = "Crystal",
    displayName = "Pokemon Crystal",
    launcherName = "Crystal",
    sha1 = "f4cd194bdee0d04ca4eac29e09b8e4e9d818c133",
    generation = 2,
    romBytes = 2 * 1024 * 1024,
    romExtension = ".gbc",
    importable = true,
    launcherLetter = "C",
    launcherColor = "crystal",
    runtime = "lua-gbc",
    manifest = "tools/gen2/rom_manifest_crystal.json",
    cachePrefix = "crystal/",
    saveSuffix = "_crystal",
  },
}

-- Launcher column order.
GameVersion.ORDER = { "red", "blue", "yellow", "crystal" }

GameVersion.IMPORT_ORDER = { "red", "blue", "yellow", "crystal" }

GameVersion.current = "red"

function GameVersion.set(id)
  GameVersion.current = GameVersion.VERSIONS[id] and id or "red"
  return GameVersion.current
end

function GameVersion.get()
  return GameVersion.current
end

function GameVersion.isBlue()
  return GameVersion.current == "blue"
end

function GameVersion.isYellow()
  return GameVersion.current == "yellow"
end

function GameVersion.isCrystal()
  return GameVersion.current == "crystal"
end

-- Metadata for a version id, defaulting to the active one.
function GameVersion.info(id)
  return GameVersion.VERSIONS[id or GameVersion.current]
end

function GameVersion.saveSuffix(id)
  return GameVersion.info(id).saveSuffix
end

function GameVersion.cachePrefix(id)
  return GameVersion.info(id).cachePrefix
end

function GameVersion.isImportable(id)
  local info = GameVersion.VERSIONS[id]
  return info ~= nil and info.importable == true
end

function GameVersion.matchesRomSize(id, byteLength)
  local info = GameVersion.VERSIONS[id]
  return info ~= nil and info.romBytes == byteLength
end

function GameVersion.isKnownRomSize(byteLength)
  for _, info in pairs(GameVersion.VERSIONS) do
    if info.romBytes == byteLength then return true end
  end
  return false
end

-- The version a ROM belongs to, by its SHA-1, or nil for an unknown ROM.
function GameVersion.forSha1(sha1)
  for id, info in pairs(GameVersion.VERSIONS) do
    if info.sha1 == sha1 then return id end
  end
  return nil
end

-- Resolve a ROM only when both its identity and expected cartridge size
-- match.  Hash identity remains authoritative; size prevents a future hash
-- fixture or malformed caller from routing bytes into the wrong decoder.
function GameVersion.forRom(sha1, byteLength)
  local id = GameVersion.forSha1(sha1)
  if id and GameVersion.matchesRomSize(id, byteLength) then return id end
  return nil
end

return GameVersion
