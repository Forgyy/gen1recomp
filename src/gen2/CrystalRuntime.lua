local CacheFs = require("src.import.CacheFs")
local GameSpeed = require("src.core.GameSpeed")
local GamepadMap = require("src.core.GamepadMap")
local Input = require("src.core.Input")
local SaveData = require("src.core.SaveData")
local TouchControls = require("src.core.TouchControls")
local CrystalModApi = require("src.gen2.CrystalModApi")

local CrystalRuntime = {}
local COLOR_MODES = { "ogred", "gbc", "redpp", "og", "og_inv", "gbc_inv", "classic" }
local COLOR_LABELS = {
  ogred = "NATIVE", gbc = "NATIVE", redpp = "NATIVE",
  og = "OG", og_inv = "OG INV", gbc_inv = "GBC INV", classic = "CLASSIC",
}

local function loadRom()
  local saved = CacheFs.prefix
  CacheFs.prefix = "crystal/"
  local data = CacheFs.read("game.gbc")
  CacheFs.prefix = saved
  return data
end

local function applyOptions(options)
  require("src.core.VideoMode").applyOptions(options)
  require("src.core.Orientation").applyOptions(options)
  require("src.core.FaithfulRes").applyOptions(options)
  require("src.core.FrameCap").applyOptions(options)
  require("src.render.GBCFX").applyOptions(options)
end

function CrystalRuntime:load()
  local rom = assert(loadRom(), "Crystal ROM cache is missing; re-import the ROM")
  self.options = SaveData.loadOptions()
  Input:init()
  Input:applyBindings(self.options.bindings)
  TouchControls:init()
  TouchControls:applyOptions(self.options)
  applyOptions(self.options)
  self.core = require("src.gen2.LuaGbCore").new({
    rom = rom,
    batteryPath = "pokemon_crystal.sav",
    rtcPath = "pokemon_crystal.rtc.lua",
    statePath = "states/quick.state",
    storage = require("src.gen2.CrystalStorage"),
    input = Input,
    volume = math.max(self.options.musicVol or 7, self.options.sfxVol or 7) / 7,
  })
  self.input = Input
  self.save = { options = self.options, modData = {} }
  self.data = { generation = 2, game = "crystal" }
  self.overworld = { crystal = true }
  self.stack = { top = function() return self.overworld end }
  _G.POKEPORT_GAME_GENERATION = 2
  local ModLoader = require("src.mods.Loader")
  self.mods = ModLoader.new({ game = self, generation = 2, skipBuiltins = true })
  self.mods:load(self.data)
  self.modStatus = self.mods:status()
  if os.getenv("POKEPORT_CRYSTAL_MOD_TEST") == "1" then
    CrystalModApi.keypressed(self, "3")
  end
  self.accumulator = 0
  self.emulatedFrames = 0
  self.captureTarget = tonumber(os.getenv("POKEPORT_CRYSTAL_CAPTURE_FRAMES") or "")
  self.captureOutput = os.getenv("POKEPORT_CRYSTAL_CAPTURE")
  self.notice = "F1 save  F2 load  F6 reset  1-5 display"
  self.noticeTime = 6
  if love.window and love.window.setTitle then
    love.window.setTitle("Pokemon Crystal (Lua Gen 2 Runtime)")
  end
end

function CrystalRuntime:_setNotice(message)
  self.notice, self.noticeTime = message, 2
end

function CrystalRuntime:writeOptions()
  SaveData.saveOptions(self.options)
end

function CrystalRuntime:_cycleSpeed(direction)
  self.options.speed = GameSpeed.cycle(self.options.speed, direction)
  self:writeOptions()
  self:_setNotice(("Speed: %gx"):format(self.options.speed))
end

function CrystalRuntime:_cycleColors()
  local current = self.options.colors or "gbc"
  local index = 1
  for candidateIndex, mode in ipairs(COLOR_MODES) do
    if mode == current then index = candidateIndex break end
  end
  self.options.colors = COLOR_MODES[index % #COLOR_MODES + 1]
  self:writeOptions()
  self:_setNotice("Colors: " .. (COLOR_LABELS[self.options.colors] or "NATIVE"))
end

function CrystalRuntime:_cycleTilt()
  self.options.tilt = (math.floor(tonumber(self.options.tilt) or 0) + 1) % 4
  self:writeOptions()
  local labels = { "OFF", "15", "35", "50" }
  self:_setNotice("Tilt: " .. labels[self.options.tilt + 1])
end

function CrystalRuntime:_zoomStep(delta)
  local width, height = love.graphics.getDimensions()
  local fit = math.max(1, math.floor(math.min(width / 160, height / 144)))
  local minimum, maximum = 1 - fit, fit
  local zoom = math.floor(tonumber(self.options.zoom) or 0) + delta
  if zoom > maximum then zoom = minimum end
  if zoom < minimum then zoom = maximum end
  self.options.zoom = zoom
  self:writeOptions()
  self:_setNotice(zoom == 0 and "Zoom: FIT"
    or ("Zoom: %s%d"):format(zoom < 0 and "OUT" or "IN", math.abs(zoom)))
end

function CrystalRuntime:_cycleGbcFx()
  local GBCFX = require("src.render.GBCFX")
  if not GBCFX.isSupported() then return end
  self.options.gbcfx = GBCFX.cycle()
  self:writeOptions()
  self:_setNotice("GBC FX: " .. GBCFX.levelLabel())
end

function CrystalRuntime:update(dt)
  local speed = GameSpeed.clamp(self.speedOverride or self.options.speed or 1)
  local frameTime = 1 / 59.7275
  self.accumulator = math.min(self.accumulator + dt * speed, frameTime * 12)
  self.core:setAudioEnabled(speed <= 1)
  while self.accumulator >= frameTime do
    self.accumulator = self.accumulator - frameTime
    if self.captureOutput then
      if self.emulatedFrames == 120 or self.emulatedFrames == 600
          or self.emulatedFrames == 1250 then
        Input:sourcePress("start", "crystal:capture")
      elseif self.emulatedFrames == 130 or self.emulatedFrames == 610
          or self.emulatedFrames == 1260 then
        Input:sourceRelease("start", "crystal:capture")
      end
    end
    self.core:runFrame()
    self.emulatedFrames = self.emulatedFrames + 1
  end
  self.core:update(dt)
  CrystalModApi.update(self, dt)
  self.noticeTime = math.max(0, (self.noticeTime or 0) - dt)
  if self.captureTarget and self.captureOutput
      and self.emulatedFrames >= self.captureTarget then
    self.capturePath = self.captureOutput
    self.captureTarget = nil
    self.captureQuitFrames = 2
  elseif self.captureQuitFrames then
    self.captureQuitFrames = self.captureQuitFrames - 1
    if self.captureQuitFrames <= 0 then love.event.quit() end
  end
end

function CrystalRuntime:draw()
  local width, height = love.graphics.getDimensions()
  love.graphics.clear(0.015, 0.02, 0.035, 1)
  if not CrystalModApi.draw(self, width, height) then
    self.core:draw(width, height, self.options)
  end
  TouchControls:draw()
  if self.noticeTime > 0 then
    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 12, 12, 430, 30, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.notice, 22, 19)
    love.graphics.pop()
  end
end

function CrystalRuntime:keypressed(key)
  if CrystalModApi.keypressed(self, key) then return end
  if key == "f1" then
    self.core:saveBattery()
    self.notice = self.core:saveState() and "Quick-save created" or "Quick-save failed"
    self.noticeTime = 2
  elseif key == "f2" then
    self.notice = self.core:loadState() and "Quick-save loaded" or "No quick-save found"
    self.noticeTime = 2
  elseif key == "f6" then
    self.core:reset()
    self.notice, self.noticeTime = "Crystal reset", 2
  elseif key == "1" then
    self:_cycleSpeed(1)
  elseif key == "2" then
    self:_cycleColors()
  elseif key == "3" then
    self:_cycleTilt()
  elseif key == "4" then
    self:_zoomStep(1)
  elseif key == "5" then
    self:_cycleGbcFx()
  elseif key == "-" then
    self:_zoomStep(-1)
  elseif key == "=" then
    self:_zoomStep(1)
  else
    Input:keypressed(key)
  end
end

function CrystalRuntime:keyreleased(key)
  if not CrystalModApi.keyreleased(self, key) then Input:keyreleased(key) end
end

function CrystalRuntime:gamepadpressed(joystick, button)
  if CrystalModApi.gamepadpressed(self, joystick, button) then return end
  TouchControls:noteGamepad()
  local selectHeld = Input:isDown("select")
  if not selectHeld and joystick and joystick.isGamepadDown then
    local ok, down = pcall(function() return joystick:isGamepadDown("back") end)
    selectHeld = ok and down == true
  end
  if selectHeld then
    local digit = GamepadMap.displayChordDigit(button)
    if digit then self:keypressed(digit) return end
  end
  if not selectHeld and (button == "rightshoulder" or button == "righttrigger") then
    self:_cycleSpeed(1)
  elseif not selectHeld and (button == "leftshoulder" or button == "lefttrigger") then
    self:_cycleSpeed(-1)
  else
    Input:gamepadpressed(joystick, button)
  end
end

function CrystalRuntime:gamepadreleased(joystick, button)
  Input:gamepadreleased(joystick, button)
end

function CrystalRuntime:gamepadaxis(joystick, axis, value)
  if CrystalModApi.gamepadaxis(self, joystick, axis, value) then return end
  if math.abs(value) > 0.5 then TouchControls:noteGamepad() end
  Input:gamepadaxis(joystick, axis, value)
end

function CrystalRuntime:joystickpressed(joystick, button)
  if GamepadMap.ignoreRawForJoystick(joystick) then return end
  TouchControls:noteGamepad()
  Input:joystickpressed(joystick, button)
end

function CrystalRuntime:joystickreleased(joystick, button)
  if GamepadMap.ignoreRawForJoystick(joystick) then return end
  Input:joystickreleased(joystick, button)
end

function CrystalRuntime:joystickaxis(joystick, axis, value)
  if GamepadMap.ignoreRawForJoystick(joystick) then return end
  if math.abs(value) > 0.5 then TouchControls:noteGamepad() end
  Input:joystickaxis(joystick, axis, value)
end

function CrystalRuntime:joystickhat(joystick, hat, direction)
  if GamepadMap.ignoreRawForJoystick(joystick) then return end
  if direction ~= "c" then TouchControls:noteGamepad() end
  Input:joystickhat(joystick, hat, direction)
end

function CrystalRuntime:focus(f)
  Input:reset()
  if f then Input:reconcile() end
  TouchControls:reset()
end

function CrystalRuntime:visible(v)
  if v then self:onResume() else self:focus(false) end
end

function CrystalRuntime:onResume() self:focus(true) end
function CrystalRuntime:joystickadded() self:focus(true) end
function CrystalRuntime:joystickremoved() self:focus(true); TouchControls:joystickremoved() end
function CrystalRuntime:touchpressed(id, x, y)
  if not CrystalModApi.touchpressed(self, id, x, y) then
    TouchControls:touchpressed(id, x, y)
  end
end
function CrystalRuntime:touchmoved(id, x, y)
  if not CrystalModApi.touchmoved(self, id, x, y) then
    TouchControls:touchmoved(id, x, y)
  end
end
function CrystalRuntime:touchreleased(id, x, y)
  if not CrystalModApi.touchreleased(self, id, x, y) then
    TouchControls:touchreleased(id, x, y)
  end
end
function CrystalRuntime:mousepressed() end
function CrystalRuntime:mousemoved(x, y, dx, dy)
  CrystalModApi.mousemoved(self, x, y, dx, dy)
end
function CrystalRuntime:mousereleased() end
function CrystalRuntime:wheelmoved(_, dy)
  if CrystalModApi.wheelmoved(self, 0, dy) then return end
  if dy > 0 then self:_zoomStep(1) elseif dy < 0 then self:_zoomStep(-1) end
end

function CrystalRuntime:shutdown()
  if self.core then self.core:shutdown() end
end

return CrystalRuntime
