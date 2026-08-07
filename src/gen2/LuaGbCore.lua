local SaveSerializer = require("src.core.SaveSerializer")

local LuaGbCore = {}
LuaGbCore.__index = LuaGbCore

local function installRequirePath()
  local fs = love.filesystem
  local prefix = "vendor/luagb/?.lua;vendor/luagb/?/init.lua;"
  if fs.getRequirePath and fs.setRequirePath then
    local current = fs.getRequirePath()
    if not current:find("vendor/luagb", 1, true) then fs.setRequirePath(prefix .. current) end
  else
    package.path = fs.getSource() .. "/vendor/luagb/?.lua;"
      .. fs.getSource() .. "/vendor/luagb/?/init.lua;" .. package.path
  end
end

local function readTable(storage, path)
  local source = storage.read(path)
  if not source then return nil end
  local chunk = loadstring(source, "@" .. path)
  if not chunk then return nil end
  local ok, value = pcall(chunk)
  return ok and type(value) == "table" and value or nil
end

local function ramString(ram, size)
  local chunks = {}
  for base = 0, size - 1, 4096 do
    local bytes = {}
    local last = math.min(size - 1, base + 4095)
    for index = base, last do bytes[#bytes + 1] = string.char(ram[index] or 0) end
    chunks[#chunks + 1] = table.concat(bytes)
  end
  return table.concat(chunks)
end

local function loadRam(ram, data, size)
  if type(data) ~= "string" then return false end
  for index = 0, math.min(size, #data) - 1 do ram[index] = data:byte(index + 1) end
  ram.dirty = false
  return true
end

function LuaGbCore.new(options)
  installRequirePath()
  local self = setmetatable({
    rom = assert(options.rom),
    batteryPath = assert(options.batteryPath),
    rtcPath = assert(options.rtcPath),
    statePath = assert(options.statePath),
    storage = assert(options.storage),
    input = options.input,
    volume = options.volume or 1,
    audioEnabled = true,
    saveElapsed = 0,
    frameDirty = true,
  }, LuaGbCore)
  self:_load()
  return self
end

function LuaGbCore:_load()
  local Gameboy = require("gameboy")
  self.gameboy = Gameboy.new({})
  self.gameboy.cartridge.load(self.rom, #self.rom)
  self.gameboy:reset()
  self.ramSize = self.gameboy.cartridge.header.ram_size or 32768
  self:loadBattery()
  self.gameboy.audio.on_buffer_full(function(buffer) self:_queueAudio(buffer) end)
  self.audioSource = love.audio.newQueueableSource(32768, 16, 2, 8)
  self.audioSource:setVolume(self.volume)
  self:_createFrameImage()
end

function LuaGbCore:_createFrameImage()
  self.imageData = love.image.newImageData(160, 144, "rgba8")
  self.image = love.graphics.newImage(self.imageData)
  self.image:setFilter("nearest", "nearest")
  local ok, ffi = pcall(require, "ffi")
  if ok and self.imageData.getFFIPointer then
    pcall(ffi.cdef, "typedef struct { unsigned char r, g, b, a; } gen2_pixel;")
    local castOk, pointer = pcall(ffi.cast, "gen2_pixel *",
      self.imageData:getFFIPointer())
    if castOk then self.pixelPointer = pointer end
  end
end

function LuaGbCore:_colorShader()
  if self.colorShader ~= nil then return self.colorShader or nil end
  local ok, shader = pcall(love.graphics.newShader, [[
    extern number colorMode;
    vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords) {
      vec4 pixel = Texel(texture, textureCoords);
      vec3 rgb = pixel.rgb;
      float luminance = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
      if (colorMode == 1.0) {
        rgb = vec3(luminance);
      } else if (colorMode == 2.0) {
        rgb = vec3(1.0 - luminance);
      } else if (colorMode == 3.0) {
        rgb = vec3(1.0) - rgb;
      } else if (colorMode == 4.0) {
        rgb = luminance > 0.75 ? vec3(0.608, 0.737, 0.059)
          : (luminance > 0.50 ? vec3(0.545, 0.675, 0.059)
          : (luminance > 0.25 ? vec3(0.188, 0.384, 0.188)
          : vec3(0.059, 0.220, 0.059)));
      }
      return vec4(rgb, pixel.a) * color;
    }
  ]])
  self.colorShader = ok and shader or false
  return self.colorShader or nil
end

local function colorModeNumber(mode)
  if mode == "og" then return 1 end
  if mode == "og_inv" then return 2 end
  if mode == "gbc_inv" then return 3 end
  if mode == "classic" then return 4 end
  return 0
end

function LuaGbCore:_ensurePresentCanvas(width, height)
  if self.presentCanvas and self.presentWidth == width
      and self.presentHeight == height then return end
  self.presentCanvas = love.graphics.newCanvas(width, height)
  self.presentCanvas:setFilter("nearest", "nearest")
  self.presentWidth, self.presentHeight = width, height
end

function LuaGbCore:_queueAudio(buffer)
  if not self.audioEnabled or not self.audioSource
      or self.audioSource:getFreeBufferCount() <= 0 then return end
  local data = love.sound.newSoundData(512, 32768, 16, 2)
  for index = 0, 1023 do data:setSample(index, buffer[index] or 0) end
  self.audioSource:queue(data)
  if not self.audioSource:isPlaying() then self.audioSource:play() end
end

function LuaGbCore:setVolume(volume)
  self.volume = math.max(0, math.min(1, tonumber(volume) or 1))
  if self.audioSource then self.audioSource:setVolume(self.volume) end
end

function LuaGbCore:setAudioEnabled(enabled)
  self.audioEnabled = enabled == true
  if not self.audioEnabled and self.audioSource then self.audioSource:stop() end
end

function LuaGbCore:runFrame()
  if self.input then
    local keys = self.gameboy.input.keys
    for _, name in ipairs({ "Up", "Down", "Left", "Right", "A", "B", "Start", "Select" }) do
      keys[name] = 0
    end
    local names = { up = "Up", down = "Down", left = "Left", right = "Right",
      a = "A", b = "B", start = "Start", select = "Select" }
    for action, name in pairs(names) do
      if self.input:isDown(action) then keys[name] = 1 end
    end
    self.gameboy.input.update()
  end
  local target = self.gameboy.graphics.vblank_count + 1
  local instructions = 0
  while self.gameboy.graphics.vblank_count < target and instructions < 250000 do
    self.gameboy:step()
    instructions = instructions + 1
  end
  self.gameboy.audio.update()
  self.frameDirty = true
  return instructions < 250000
end

function LuaGbCore:update(dt)
  self.saveElapsed = self.saveElapsed + dt
  if self.gameboy.cartridge.external_ram.dirty and self.saveElapsed >= 5 then
    self.saveElapsed = 0
    self:saveBattery()
  end
end

function LuaGbCore:_refreshImage()
  if not self.frameDirty then return end
  local screen = self.gameboy.graphics.game_screen
  if self.pixelPointer then
    for y = 0, 143 do
      for x = 0, 159 do
        local source = screen[y][x]
        local pixel = self.pixelPointer[y * 160 + x]
        pixel.r, pixel.g, pixel.b, pixel.a = source[1], source[2], source[3], 255
      end
    end
  else
    for y = 0, 143 do
      for x = 0, 159 do
        local source = screen[y][x]
        self.imageData:setPixel(x, y, source[1] / 255, source[2] / 255,
          source[3] / 255, 1)
      end
    end
  end
  self.image:replacePixels(self.imageData)
  self.frameDirty = false
end

function LuaGbCore:draw(width, height, options)
  self:_refreshImage()
  local scale = math.min(width / 160, height / 144)
  if (options and options.faithfulRes or 0) > 0 then scale = math.max(1, math.floor(scale)) end
  local zoom = tonumber(options and options.zoom) or 0
  scale = math.max(0.5, scale + zoom)
  local drawWidth, drawHeight = 160 * scale, 144 * scale
  love.graphics.push("all")
  self:_ensurePresentCanvas(width, height)
  love.graphics.setCanvas(self.presentCanvas)
  love.graphics.clear(0.015, 0.02, 0.035, 1)
  love.graphics.setColor(1, 1, 1, 1)
  local colorShader = self:_colorShader()
  if colorShader then
    colorShader:send("colorMode", colorModeNumber(options and options.colors))
    love.graphics.setShader(colorShader)
  end
  love.graphics.translate(width / 2, height / 2)
  local tiltLevel = math.max(0, math.min(3,
    math.floor(tonumber(options and options.tilt) or 0)))
  if tiltLevel > 0 then
    local angles = { 0, 15, 35, 50 }
    local angle = math.rad(angles[tiltLevel + 1])
    love.graphics.scale(1, math.cos(angle))
    love.graphics.shear(0, -math.sin(angle) * 0.12)
  end
  love.graphics.draw(self.image, -drawWidth / 2, -drawHeight / 2, 0, scale, scale)
  love.graphics.setShader()
  love.graphics.setCanvas()
  love.graphics.origin()
  local GBCFX = require("src.render.GBCFX")
  GBCFX.present(self.presentCanvas, math.max(1, math.floor(scale)))
  love.graphics.pop()
end

function LuaGbCore:saveBattery()
  local cartridge = self.gameboy.cartridge
  local ok = self.storage.write(self.batteryPath,
    ramString(cartridge.external_ram, self.ramSize))
  local rtc = cartridge.get_rtc_state()
  if rtc then self.storage.write(self.rtcPath, SaveSerializer.encode(rtc)) end
  cartridge.external_ram.dirty = false
  return ok
end

function LuaGbCore:loadBattery()
  local cartridge = self.gameboy.cartridge
  local loaded = loadRam(cartridge.external_ram,
    self.storage.read(self.batteryPath), self.ramSize)
  local rtc = readTable(self.storage, self.rtcPath)
  if rtc then cartridge.load_rtc_state(rtc) end
  return loaded
end

function LuaGbCore:saveState()
  local binser = require("binser")
  local state = {
    gameboy = self.gameboy:save_state(),
    ram = ramString(self.gameboy.cartridge.external_ram, self.ramSize),
    rtc = self.gameboy.cartridge.get_rtc_state(),
  }
  local encoded = binser.serialize(state)
  return self.storage.write(self.statePath, encoded)
end

function LuaGbCore:loadState()
  local encoded = self.storage.read(self.statePath)
  if not encoded then return false end
  local binser = require("binser")
  local values, count = binser.deserialize(encoded)
  local state = count > 0 and values[1] or nil
  if type(state) ~= "table" or type(state.gameboy) ~= "table" then return false end
  self.gameboy:load_state(state.gameboy)
  loadRam(self.gameboy.cartridge.external_ram, state.ram, self.ramSize)
  self.gameboy.cartridge.load_rtc_state(state.rtc)
  self.frameDirty = true
  return true
end

function LuaGbCore:reset()
  self.gameboy:reset()
end

function LuaGbCore:shutdown()
  if self.closed then return end
  self.closed = true
  self:saveBattery()
  if self.audioSource then self.audioSource:stop() end
end

return LuaGbCore
