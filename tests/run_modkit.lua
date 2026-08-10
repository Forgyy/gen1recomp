-- T4 mod-SDK tier: the public mod API exercised headlessly against the
-- fixture dataset, plus any tests a shipped mod carries in its own
-- tests/ directory.  No ROM, no display.
--   luajit tests/run_modkit.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local Runner = require("tests.tier_runner")

local dirs = { "tests/modkit/cases" }

-- mods ship their own tests (21-testing-and-ci "how mods ship their own
-- tests"); pick up every mods/<id>/tests directory that exists.
-- Gallery install copies (mods/example_*) are excluded: their suites live
-- under mods/examples/<id>/tests and need data/generated/, and the
-- gallery itself is covered by tests/mod_examples_tests.lua.  Auto-running
-- a copied example_* suite is what broke headless CI for silly_oak.
local FsIo = require("tests.fs_io")
local Json = require("src.link.Json")

local function isExperimental(name)
  local handle = io.open("mods/" .. name .. "/manifest.json", "rb")
  if not handle then return false end
  local source = handle:read("*a")
  handle:close()
  local ok, manifest = pcall(Json.decode, source)
  return ok and type(manifest) == "table" and manifest.experimental == true
end

for _, name in ipairs(FsIo.listDir("mods")) do
  if not name:find(".", 1, true) and not name:match("^example_")
      and not isExperimental(name) then
    local dir = "mods/" .. name .. "/tests"
    if FsIo.isDir(dir) then dirs[#dirs + 1] = dir end
  end
end

Runner.main(dirs, "modkit")
