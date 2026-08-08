# Quality of Life Pack

A configurable bundle of quality-of-life levers — EXP rate, catch help, a
mart discount, and a play-stats tracker — each behind its own option, with
battle math left byte-for-byte vanilla until you turn a lever.

## Try it

```sh
python3 tools/modkit.py validate mods/qol_pack --base imported
luajit mods/qol_pack/tests/qol_pack_test.lua
```

Then enable it in the F10 mod manager (or add `qol_pack = true` under
`mods` in your `options.lua`) and open its options pane.

## Options

| Option | Values | Default | What it does |
|---|---|---|---|
| EXP RATE | 1x / 1.5x / 2x / 3x | 1x | scales every experience gain |
| CATCH HELP | OFF / EASY / GUARANTEED | OFF | EASY maxes the catch rate (HP roll still runs); GUARANTEED always catches |
| MART DISCOUNT | OFF / 25% / 50% / 75% | 50% | cuts every priced item, discovered from the merged view |
| PLAY STATS | on / off | on | counts steps, battles and catches |

The counters show up as a **QOL** entry on the start menu, and as the
`qol` verb in the developer console.

## What it demonstrates

| Seam | Where |
|---|---|
| `hooks:wrap("exp.gain")` | scale a battle result, passthrough at 1x |
| `hooks:wrap("catch.rate")` | force a result, or rewrite `rateOverride` for the stock math |
| `content.items:each` + `patch` | a load-time economy pass over the merged view |
| `events:on` + `mod.save` | counters in the mod's own save namespace |
| `hooks:wrap("ui.start_menu.items")` + `mod.ui` | a menu entry via the widget toolkit |
| `commands:register` | a developer-console verb |
| `mod.exports` | `stats()` for other mods to read the counters |

## Parity

With the pack installed and every option at its default except the
discount, battles are unchanged: the EXP hook returns `next(ctx)`'s value
untouched at 1x and the catch hook defers to the vanilla roll when OFF.
The discount is the one default-on lever; set MART DISCOUNT to OFF for a
fully vanilla game.

## Credits

Prices, exp yields and catch rates come from the player's own imported
ROM; this mod ships multipliers, not data.
