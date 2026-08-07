package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local T = require("tests.harness").suite("Crystal mod options")
local check, eq = T.check, T.eq
local writes, emitted, resets = 0, {}, 0
local game = {
  options = {},
  input = { reset = function() resets = resets + 1 end },
  writeOptions = function() writes = writes + 1 end,
  _setNotice = function(_, message) game.notice = message end,
  mods = {
    modOptions = {},
    optionSchemas = {
      DRAMATIC_SHAPE = {
        { key = "voxel", type = "choice", label = "VOXEL", default = 0,
          choices = { { "OFF", 0 }, { "15", 2 }, { "35", 3 } } },
        { key = "grid", type = "toggle", label = "V-GRID", default = false },
      },
    },
    mods = {
      DRAMATIC_SHAPE = { state = "loaded",
        manifest = { name = "Dramatic Shape Voxel Mod" } },
    },
    events = { emit = function(_, name, payload)
      emitted[#emitted + 1] = { name, payload }
    end },
  },
}

local Menu = require("src.gen2.CrystalOptions").new(game)
eq(#Menu:rows(), 2, "loaded Crystal mod schemas become menu rows")
check(pcall(function() Menu:draw() end), "closed overlay button draws")
check(Menu:keypressed("f3"), "F3 opens the overlay")
check(Menu.active, "overlay is active")
eq(resets, 1, "opening releases held game input")
eq(Menu:valueLabel(Menu:rows()[1]), "OFF", "choice displays its default")
check(Menu:keypressed("right"), "right is consumed by the overlay")
eq(game.options.modOptions.DRAMATIC_SHAPE.voxel, 2,
  "right advances the selected choice")
eq(game.mods.modOptions.DRAMATIC_SHAPE.voxel, 2,
  "live mod options update with persisted options")
eq(writes, 1, "changing a row persists options")
eq(emitted[1][1], "mod.options_changed", "mods receive the change event")
Menu:keypressed("down")
Menu:keypressed("right")
check(game.options.modOptions.DRAMATIC_SHAPE.grid,
  "toggle rows change from the overlay")
check(Menu:keypressed("escape") and not Menu.active, "Escape closes the overlay")
eq(resets, 2, "closing releases overlay input")
check(Menu:pointerPressed(320, 20), "the on-screen button opens the overlay")
check(Menu.active, "touch access opens the same menu")
check(pcall(function() Menu:draw() end), "active overlay draws")

T.finish("Crystal mod options")
