-- Standalone: luajit mods/qol_pack/tests/qol_pack_test.lua
-- Loads the pack through the real headless loader and asserts each lever's
-- stated effect: the data patch at its default, and the option-gated hooks
-- and events by toggling their options live (mod code reads them at call
-- time) and driving the loader's own buses.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Data = T.fixtures.fresh()

local ID = "qol_pack"
local run = T.sdk.loadMod("mods/qol_pack", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")

local opts = run.loader.modOptions[ID] or {}
run.loader.modOptions[ID] = opts

-- ---- mart discount: on by default (50%), applied to every priced item
-- The ROM-free fixture potion costs 300; the default discount halves it.
T.eq(Data.items.FIX_POTION.price, 150, "fixture potion discounted 50% at load")

-- ---- EXP rate: parity at 1x, scaled otherwise. vanilla returns a fixed 100.
local function expWith(rate)
  opts.exp_rate = rate
  return Runtime.call("exp.gain", function() return 100 end, {})
end
T.eq(expWith("1"), 100, "exp 1x is a pure passthrough")
T.eq(expWith("2"), 200, "exp 2x doubles the gain")
T.eq(expWith("1.5"), 150, "exp 1.5x scales and floors")

-- ---- catch help: parity off, guaranteed forces a catch. vanilla says false.
local function caughtWith(mode)
  opts.catch = mode
  local caught = Runtime.call("catch.rate",
    function() return false, 0 end, "POKE_BALL", {}, {}, {})
  return caught
end
T.eq(caughtWith("off"), false, "catch OFF defers to the vanilla roll")
T.eq(caughtWith("guaranteed"), true, "catch GUARANTEED always catches")

-- ---- easy raises rateOverride before the vanilla roll runs
opts.catch = "easy"
local seen
Runtime.call("catch.rate", function(_, _, _, o) seen = o.rateOverride; return false, 0 end,
  "POKE_BALL", {}, {}, {})
T.eq(seen, 255, "catch EASY hands the stock math a maxed rateOverride")

-- ---- play-stats tracker: events land in this mod's save namespace
opts.track = true
run.loader.events:emit("world.stepped", {})
run.loader.events:emit("world.stepped", {})
run.loader.events:emit("battle.started", {})
run.loader.events:emit("pokemon.caught", {})
local save = run.loader.modSave[ID] or {}
T.eq(save.steps, 2, "two steps counted")
T.eq(save.battles, 1, "one battle counted")
T.eq(save.catches, 1, "one catch counted")

-- ---- the exported reader mirrors the counters
local exported = run.loader.exports[ID].stats()
T.eq(exported.steps, 2, "exports.stats() reads the step counter")

-- ---- start-menu hook appends a QOL entry
local items = Runtime.call("ui.start_menu.items", function(_, i) return i end, {}, {})
local labels = {}
for _, it in ipairs(items) do labels[it.label] = true end
T.check(labels["QOL"], "a QOL entry is added to the start menu")

-- ---- the console verb resolves and prints the stats block
local verb = run.loader.content.commands:get("qol")
T.check(type(verb) == "function" or (type(verb) == "table" and verb.fn),
  "the qol command is registered")
local fn = type(verb) == "table" and verb.fn or verb
T.check(tostring(fn()):find("PLAY STATS"), "qol prints the stats block")

run.release()
T.finish("qol_pack")
