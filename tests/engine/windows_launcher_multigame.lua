package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("Windows multi-game launcher")
local check = S.check

local function read(path)
  local file = assert(io.open(path, "rb"))
  local contents = file:read("*a")
  file:close()
  return contents
end

local batch = read("Play-Windows.bat")
local bootstrap = read("scripts/bootstrap.ps1")
local run = read("scripts/run.ps1")

check(batch:find("Red Blue Yellow Crystal", 1, true) ~= nil,
  "batch title identifies the multi-game launcher")
check(bootstrap:find("scripts\\setup.ps1", 1, true) == nil,
  "bootstrap does not invoke the Red extraction setup")
check(bootstrap:find("Pokemon Red ROM not found", 1, true) == nil,
  "bootstrap has no Red-only ROM requirement")
check(run:find("generated data missing", 1, true) == nil,
  "runner does not require extracted Gen 1 data")
check(bootstrap:find("love-*-win64", 1, true) ~= nil
    and run:find("love-*-win64", 1, true) ~= nil,
  "both wrappers discover a local portable LOVE bundle")
check(bootstrap:find("game selector", 1, true) ~= nil,
  "bootstrap launches the in-app ROM selector")

S.finish()
