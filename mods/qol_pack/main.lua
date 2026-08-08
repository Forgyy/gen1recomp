-- Quality of Life Pack: one mod, several independent QoL levers, each
-- behind its own option so a player enables only what they want.  It is a
-- deliberate tour of the mod seams:
--
--   * result hooks   exp.gain, catch.rate      (change a battle outcome)
--   * a data patch   content.items:each        (cheaper marts, at load)
--   * events         world.stepped, battle.started, pokemon.caught
--   * per-mod save   mod.save                  (the play-stats counters)
--   * a UI hook      ui.start_menu.items       (a "QOL" start-menu entry)
--   * a console verb commands:register         ("qol" prints the stats)
--
-- Parity note: EXP and CATCH default to their vanilla values, so with the
-- pack installed and untouched every battle is byte-for-byte the original.
-- The mart discount is the one lever on by default -- it is pure economy,
-- never touches battle math, and is the QoL a first-time player feels.
return function(mod)
  ---------------------------------------------------------------------------
  -- options
  ---------------------------------------------------------------------------
  mod.options:define({
    { key = "exp_rate", label = "EXP RATE", type = "choice", default = "1",
      choices = { { "1x", "1" }, { "1.5x", "1.5" }, { "2x", "2" }, { "3x", "3" } } },
    { key = "catch", label = "CATCH HELP", type = "choice", default = "off",
      choices = { { "OFF", "off" }, { "EASY", "easy" }, { "GUARANTEED", "guaranteed" } } },
    { key = "discount", label = "MART DISCOUNT", type = "choice", default = "50",
      choices = { { "OFF", "0" }, { "25%", "25" }, { "50%", "50" }, { "75%", "75" } } },
    { key = "track", label = "PLAY STATS", type = "toggle", default = true },
  })

  ---------------------------------------------------------------------------
  -- EXP rate -- exp.gain hook (result is the exp a mon just earned)
  ---------------------------------------------------------------------------
  mod.hooks:wrap("exp.gain", function(next, ctx)
    local gained = next(ctx)
    local mult = tonumber(mod.options:get("exp_rate")) or 1
    if mult == 1 or type(gained) ~= "number" then return gained end
    return math.floor(gained * mult)
  end)

  ---------------------------------------------------------------------------
  -- Catch help -- catch.rate hook (returns caught, shakes)
  --   EASY       raises the roll ceiling so most throws stick
  --   GUARANTEED any ball catches (a 3-shake success)
  ---------------------------------------------------------------------------
  mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
    local mode = mod.options:get("catch")
    if mode == "guaranteed" then
      return true, 3
    elseif mode == "easy" then
      -- rateOverride replaces the species catch rate inside the stock math;
      -- 255 is the maximum, leaving only the HP roll between here and a catch
      opts.rateOverride = 255
      return next(ball, mon, def, opts)
    end
    return next(ball, mon, def, opts)
  end)

  ---------------------------------------------------------------------------
  -- Mart discount -- a data patch over the merged item view, at load.
  -- Discovered with :each() rather than a hard-coded list, so items a
  -- content mod ahead of this one added are discounted too.  Applied once
  -- at load: change the option and reload (F5 in dev, or restart) to re-fold.
  ---------------------------------------------------------------------------
  local off = tonumber(mod.options:get("discount")) or 0
  if off > 0 and off < 100 then
    local factor = (100 - off) / 100
    local n = 0
    for id, item in mod.content.items:each() do
      if type(item.price) == "number" and item.price > 0 then
        mod.content.items:patch(id, { price = math.floor(item.price * factor) })
        n = n + 1
      end
    end
    mod.log:info("discounted %d item prices by %d%%", n, off)
  end

  ---------------------------------------------------------------------------
  -- Play-stats tracker -- events into this mod's own save namespace
  ---------------------------------------------------------------------------
  local function bump(key)
    if not mod.options:get("track") then return end
    mod.save:set(key, (mod.save:get(key, 0)) + 1)
  end

  mod.events:on("world.stepped", function() bump("steps") end)
  mod.events:on("battle.started", function() bump("battles") end)
  mod.events:on("pokemon.caught", function() bump("catches") end)

  local function statsLines()
    return string.format("PLAY STATS\nSTEPS %d\nBATTLES %d\nCAUGHT %d",
      mod.save:get("steps", 0), mod.save:get("battles", 0),
      mod.save:get("catches", 0))
  end

  -- exported so another mod can read the counters the supported way
  mod.exports.stats = function()
    return {
      steps = mod.save:get("steps", 0),
      battles = mod.save:get("battles", 0),
      catches = mod.save:get("catches", 0),
    }
  end

  ---------------------------------------------------------------------------
  -- Surfaces: a start-menu entry and a dev-console verb, both showing stats
  ---------------------------------------------------------------------------
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    mod.ui.insertBefore(out, "QUIT", {
      label = "QOL",
      onSelect = function()
        game.stack:push(mod.ui.TextBox.new(game, statsLines()))
      end,
    })
    return out
  end)

  mod.commands:register("qol", function()
    return statsLines()
  end)
end
