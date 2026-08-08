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
