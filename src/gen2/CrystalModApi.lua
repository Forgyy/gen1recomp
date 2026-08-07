local CrystalModApi = {}

local renderers = {}
local order = {}

local WRAM = {
  mapGroup = { 1, 0xdcb5 },
  mapNumber = { 1, 0xdcb6 },
  mapWidth = { 1, 0xd19f },
  mapHeight = { 1, 0xd19e },
  tileset = { 1, 0xd199 },
  battleMode = { 1, 0xd22d },
  battleType = { 1, 0xd230 },
  timeOfDay = { 1, 0xd269 },
  playerDirection = { 1, 0xd4de },
  playerX = { 1, 0xd4e6 },
  playerY = { 1, 0xd4e7 },
  enemySpecies = { 1, 0xd206 },
  playerSpecies = { 0, 0xc62c },
}

local function readWram(gameboy, spec)
  local bank, address = spec[1], spec[2]
  local memory = gameboy and gameboy.memory
  if not memory then return 0 end
  if bank == 0 then return memory.work_ram_0[address] or 0 end
  return memory.work_ram_1_raw[address + (bank - 1) * 0x1000] or 0
end

local function selected()
  for index = #order, 1, -1 do
    local entry = renderers[order[index]]
    if entry and (not entry.enabled or entry.enabled()) then return entry end
  end
end

function CrystalModApi.register(id, renderer)
  assert(type(id) == "string" and id ~= "", "Crystal renderer id is required")
  assert(type(renderer) == "table", "Crystal renderer must be a table")
  if not renderers[id] then order[#order + 1] = id end
  renderers[id] = renderer
  return renderer
end

function CrystalModApi.unregister(id)
  renderers[id] = nil
end

function CrystalModApi.snapshot(game)
  local core = game and game.core
  local gameboy = core and core.gameboy
  local graphics = gameboy and gameboy.graphics
  local io = gameboy and gameboy.io
  if not graphics then return nil end
  local state = {
    generation = 2,
    game = "crystal",
    image = core:getFrameImage(),
    screenWidth = 160,
    screenHeight = 144,
    scrollX = io and (io.ram[0x43] or 0) or 0,
    scrollY = io and (io.ram[0x42] or 0) or 0,
    windowX = io and (io.ram[0x4b] or 0) or 0,
    windowY = io and (io.ram[0x4a] or 0) or 0,
    lcdc = io and (io.ram[0x40] or 0) or 0,
    vram = graphics.vram,
    oam = graphics.oam_raw,
    frame = graphics.vblank_count or 0,
  }
  for name, spec in pairs(WRAM) do state[name] = readWram(gameboy, spec) end
  state.inBattle = state.battleMode ~= 0
  return state
end

local function invoke(name, ...)
  local entry = selected()
  local callback = entry and entry[name]
  if not callback then return false end
  local ok, handled = pcall(callback, entry, ...)
  if not ok then
    print("Crystal mod renderer error (" .. name .. "): " .. tostring(handled))
    return false
  end
  return handled == true
end

function CrystalModApi.update(game, dt)
  local entry = selected()
  if entry and entry.update then
    local ok, err = pcall(entry.update, entry, game, dt, CrystalModApi.snapshot(game))
    if not ok then print("Crystal mod renderer error (update): " .. tostring(err)) end
  end
end

function CrystalModApi.draw(game, width, height)
  local entry = selected()
  if not entry or not entry.draw then return false end
  local ok, handled = pcall(entry.draw, entry, game, width, height,
    CrystalModApi.snapshot(game))
  if not ok then
    print("Crystal mod renderer error (draw): " .. tostring(handled))
    return false
  end
  return handled == true
end

function CrystalModApi.keypressed(game, key) return invoke("keypressed", game, key) end
function CrystalModApi.keyreleased(game, key) return invoke("keyreleased", game, key) end
function CrystalModApi.gamepadpressed(game, joystick, button)
  return invoke("gamepadpressed", game, joystick, button)
end
function CrystalModApi.gamepadaxis(game, joystick, axis, value)
  return invoke("gamepadaxis", game, joystick, axis, value)
end
function CrystalModApi.touchpressed(game, id, x, y)
  return invoke("touchpressed", game, id, x, y)
end
function CrystalModApi.touchmoved(game, id, x, y)
  return invoke("touchmoved", game, id, x, y)
end
function CrystalModApi.touchreleased(game, id, x, y)
  return invoke("touchreleased", game, id, x, y)
end
function CrystalModApi.mousemoved(game, x, y, dx, dy)
  return invoke("mousemoved", game, x, y, dx, dy)
end
function CrystalModApi.wheelmoved(game, dx, dy)
  return invoke("wheelmoved", game, dx, dy)
end

return CrystalModApi
