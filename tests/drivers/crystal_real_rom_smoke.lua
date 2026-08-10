-- Real-ROM Crystal smoke driver. The ROM remains user-supplied and untracked.
--
-- POKEPORT_VERSION=crystal POKEPORT_DRIVER=tests/drivers/crystal_real_rom_smoke.lua \
-- POKEPORT_CRYSTAL_SMOKE_SHOT=/tmp/crystal.png POKEPORT_SPEED=10 love .

return function(game)
  local output = assert(os.getenv("POKEPORT_CRYSTAL_SMOKE_SHOT"),
    "POKEPORT_CRYSTAL_SMOKE_SHOT is required")
  local input = assert(game.input, "Crystal input bridge is missing")
  local memory = assert(game.core and game.core.gameboy
    and game.core.gameboy.memory, "Crystal memory bridge is missing")
  local raw = assert(memory.work_ram_1_raw, "Crystal banked WRAM is missing")

  local function releaseButtons()
    input:sourceRelease("a", "crystal:smoke")
    input:sourceRelease("start", "crystal:smoke")
  end

  for frame = 1, 30000 do
    releaseButtons()
    local mapGroup = raw[0xdcb5] or 0
    local mapNumber = raw[0xdcb6] or 0
    if mapGroup > 0 and mapNumber > 0 then
      print(("Crystal overworld reached at driver frame %d (map %d:%d, battle %d)")
        :format(frame, mapGroup, mapNumber, raw[0xd22d] or 0))
      local state = require("src.gen2.CrystalModApi").snapshot(game)
      print(("Crystal world data: %dx%d tileset %d, blocks %02x:%04x, definitions %02x:%04x, collision %02x:%04x")
        :format(state.mapWidth or 0, state.mapHeight or 0, state.tileset or 0,
          state.mapBlocksBank or 0, state.mapBlocksPointer or 0,
          state.tilesetBlocksBank or 0, state.tilesetBlocksAddress or 0,
          state.tilesetCollisionBank or 0,
          state.tilesetCollisionAddress or 0))
      print(("Crystal player data: metatile %d,%d position %d,%d scroll %d,%d anchor %04x")
        :format(state.playerMetatileX or 0, state.playerMetatileY or 0,
          state.playerX or 0, state.playerY or 0, state.scrollX or 0,
          state.scrollY or 0, state.overworldMapAnchor or 0))
      assert(game.core:saveState(), "Crystal quick-save failed")
      assert(game.core:loadState(), "Crystal quick-load failed")
      print("Crystal quick-save round trip passed")
      -- The serialized core resumes in the middle of its restored PPU state;
      -- wait for completed frames before judging presentation.
      for _ = 1, 120 do coroutine.yield() end
      game.capturePath = output
      for _ = 1, 5 do coroutine.yield() end
      return
    end

    -- Start skips the animated boot/title sequence; A advances the default
    -- new-game, time, gender, and name choices without depending on pixels.
    if frame % 240 == 1 then
      input:sourcePress("start", "crystal:smoke")
    elseif frame % 30 == 1 then
      input:sourcePress("a", "crystal:smoke")
    end
    coroutine.yield()
  end

  releaseButtons()
  game.capturePath = output
  for _ = 1, 5 do coroutine.yield() end
  error("Crystal smoke driver timed out before reaching the overworld")
end
