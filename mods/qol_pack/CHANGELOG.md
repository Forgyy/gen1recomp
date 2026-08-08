# Changelog

Format: [keep a changelog](https://keepachangelog.com/en/1.1.0/).
Version headings match `manifest.json`'s `version`.

## 1.0.0

### Added

- EXP RATE option scaling `exp.gain` (1x/1.5x/2x/3x, default 1x).
- CATCH HELP option over `catch.rate` (OFF/EASY/GUARANTEED, default OFF).
- MART DISCOUNT load-time price pass over the merged item view
  (OFF/25%/50%/75%, default 50%).
- Play-stats counters (steps, battles, catches) in the mod save namespace,
  surfaced as a QOL start-menu entry and a `qol` console verb, and exported
  as `stats()`.
