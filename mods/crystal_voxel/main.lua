local mod = ...
local CrystalModApi = require("src.gen2.CrystalModApi")

mod.options:define({
  { key = "enabled", label = "VOXEL", type = "toggle", default = true },
  { key = "depth", label = "V-DEPTH", type = "number", default = 3,
    min = 1, max = 6, step = 1 },
  { key = "angle", label = "V-ANGLE", type = "choice", default = "DIORAMA",
    choices = { "FLAT", "DIORAMA", "STEEP" } },
  { key = "grid", label = "V-GRID", type = "toggle", default = true },
  { key = "battles", label = "3D-BTL", type = "choice", default = "CLASSIC",
    choices = { "CLASSIC", "DIORAMA" } },
})

local renderer = { mesh = nil, vertices = {}, gridLines = {} }

local function option(key, fallback)
  local value = mod.options:get(key)
  if value == nil then return fallback end
  return value
end

local function setOption(game, key, value)
  local id = mod.id
  game.options.modOptions = game.options.modOptions or {}
  game.options.modOptions[id] = game.options.modOptions[id] or {}
  game.options.modOptions[id][key] = value
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions[id] = game.mods.modOptions[id] or {}
  game.mods.modOptions[id][key] = value
  game:writeOptions()
  if game.mods.events then
    game.mods.events:emit("mod.options_changed",
      { mod = id, key = key, value = value })
  end
end

local function bitAnd(value, mask)
  if bit and bit.band then return bit.band(value, mask) end
  local result, place = 0, 1
  while value > 0 and mask > 0 do
    if value % 2 == 1 and mask % 2 == 1 then result = result + place end
    value, mask, place = math.floor(value / 2), math.floor(mask / 2), place * 2
  end
  return result
end

local function addTriangle(vertices, a, b, c, color)
  local r, g, bl, alpha = color[1], color[2], color[3], color[4]
  vertices[#vertices + 1] = { a[1], a[2], a[3], a[4], r, g, bl, alpha }
  vertices[#vertices + 1] = { b[1], b[2], b[3], b[4], r, g, bl, alpha }
  vertices[#vertices + 1] = { c[1], c[2], c[3], c[4], r, g, bl, alpha }
end

local function addQuad(vertices, a, b, c, d, color)
  addTriangle(vertices, a, b, c, color)
  addTriangle(vertices, a, c, d, color)
end

local function tileHeight(state, tx, ty, depth)
  local mapBase = bitAnd(state.lcdc or 0, 0x08) ~= 0 and 0x9c00 or 0x9800
  local mapX = (math.floor((state.scrollX or 0) / 8) + tx) % 32
  local mapY = (math.floor((state.scrollY or 0) / 8) + ty) % 32
  local address = mapBase + mapY * 32 + mapX
  local tile = state.vram and state.vram[address] or 0
  local attr = state.vram and state.vram[address + 0x4000] or 0
  local palette = bitAnd(attr or 0, 0x07)
  if tile == 0 or tile == 0x7f or tile == 0xff then return 0 end
  local material = (tile * 13 + palette * 7 + (state.tileset or 0) * 3) % 11
  if material <= 2 then return 0 end
  if material <= 6 then return math.max(1, math.floor(depth * 0.45)) end
  if material <= 9 then return math.max(1, math.floor(depth * 0.75)) end
  return depth
end

local function projection(width, height, angle)
  local vertical, shear = 0.78, 0.12
  if angle == "FLAT" then vertical, shear = 0.92, 0.04 end
  if angle == "STEEP" then vertical, shear = 0.62, 0.20 end
  local spanW = 160 + 144 * math.abs(shear)
  local spanH = 144 * vertical + 42
  local scale = math.max(1, math.min(width / spanW, height / spanH) * 0.94)
  local cx, cy = width * 0.5, height * 0.5 + 8 * scale
  return function(px, py, lift)
    local dx, dy = px - 80, py - 72
    return cx + (dx + dy * shear) * scale,
      cy + (dy * vertical - (lift or 0) * 2.2) * scale
  end, scale
end

function renderer:rebuild(width, height, state)
  local angle = tostring(option("angle", "DIORAMA")):upper()
  local depth = math.floor(tonumber(option("depth", 3)) or 3)
  local project, scale = projection(width, height, angle)
  local vertices, gridLines = {}, {}
  local topColor = { 1, 1, 1, 1 }
  local frontColor = { 0.40, 0.44, 0.54, 1 }
  local sideColor = { 0.25, 0.29, 0.39, 1 }

  for ty = 0, 17 do
    for tx = 0, 19 do
      local px, py = tx * 8, ty * 8
      local lift = tileHeight(state, tx, ty, depth)
      local x1, y1 = project(px, py, lift)
      local x2, y2 = project(px + 8, py, lift)
      local x3, y3 = project(px + 8, py + 8, lift)
      local x4, y4 = project(px, py + 8, lift)
      local bx2, by2 = project(px + 8, py, 0)
      local bx3, by3 = project(px + 8, py + 8, 0)
      local bx4, by4 = project(px, py + 8, 0)
      local u1, v1, u2, v2 = px / 160, py / 144,
        (px + 8) / 160, math.min(1, (py + 8) / 144)

      if lift > 0 then
        addQuad(vertices,
          { x4, y4, u1, v2 }, { x3, y3, u2, v2 },
          { bx3, by3, u2, v2 }, { bx4, by4, u1, v2 }, frontColor)
        addQuad(vertices,
          { x2, y2, u2, v1 }, { bx2, by2, u2, v1 },
          { bx3, by3, u2, v2 }, { x3, y3, u2, v2 }, sideColor)
      end
      addQuad(vertices,
        { x1, y1, u1, v1 }, { x2, y2, u2, v1 },
        { x3, y3, u2, v2 }, { x4, y4, u1, v2 }, topColor)
      gridLines[#gridLines + 1] = { x1, y1, x2, y2, x3, y3, x4, y4 }
    end
  end

  self.vertices, self.gridLines, self.scale = vertices, gridLines, scale
  self.mesh = love.graphics.newMesh(vertices, "triangles", "stream")
  self.mesh:setTexture(state.image)
end

function renderer:enabled()
  return option("enabled", true) == true
end

function renderer:draw(game, width, height, state)
  if not state or not state.image then return false end
  -- Menus, logos, and the boot sequence use the PPU in ways that are visually
  -- meaningful only as a flat framebuffer.  Crystal does not populate its
  -- overworld map identity until an actual map is active, so leave those
  -- screens in faithful 2D instead of extruding UI glyphs into a white slab.
  if (tonumber(state.mapGroup) or 0) <= 0
      or (tonumber(state.mapNumber) or 0) <= 0 then
    return false
  end
  if state.inBattle and option("battles", "CLASSIC") ~= "DIORAMA" then
    return false
  end
  local ok, err = pcall(self.rebuild, self, width, height, state)
  if not ok then
    mod.log:error("voxel mesh failed: %s", tostring(err))
    return false
  end

  love.graphics.push("all")
  love.graphics.clear(0.025, 0.035, 0.065, 1)
  love.graphics.setColor(0.20, 0.28, 0.48, 0.18)
  love.graphics.ellipse("fill", width * 0.5, height * 0.84,
    math.min(width * 0.42, 520), math.min(height * 0.12, 120))
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.mesh)
  if option("grid", true) then
    love.graphics.setLineWidth(math.max(1, (self.scale or 1) * 0.12))
    love.graphics.setColor(0.72, 0.88, 1, 0.17)
    for _, line in ipairs(self.gridLines) do
      love.graphics.line(line[1], line[2], line[3], line[4],
        line[5], line[6], line[7], line[8], line[1], line[2])
    end
  end
  love.graphics.pop()
  return true
end

function renderer:keypressed(game, key)
  if key ~= "3" then return false end
  local nextValue = not option("enabled", true)
  setOption(game, "enabled", nextValue)
  game:_setNotice("Crystal voxel: " .. (nextValue and "ON" or "OFF"))
  return true
end

function renderer:wheelmoved(game, _, dy)
  if dy == 0 then return false end
  local nextDepth = math.max(1, math.min(6,
    math.floor(tonumber(option("depth", 3)) or 3) + (dy > 0 and 1 or -1)))
  setOption(game, "depth", nextDepth)
  game:_setNotice("Voxel depth: " .. nextDepth)
  return true
end

CrystalModApi.register(mod.id, renderer)
mod.exports.renderer = renderer
