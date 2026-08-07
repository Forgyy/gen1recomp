local CrystalOptions = {}
CrystalOptions.__index = CrystalOptions

local ROW_HEIGHT = 38
local PANEL_MARGIN = 24
local BUTTON_WIDTH = 112
local BUTTON_HEIGHT = 32

local function sameValue(left, right)
  return type(left) == type(right) and left == right
end

local function choiceIndex(row, current)
  for index, choice in ipairs(row.choices or {}) do
    if sameValue(choice[2], current) then return index end
  end
  return 1
end

function CrystalOptions.new(game)
  return setmetatable({ game = game, active = false, cursor = 1, scroll = 0 },
    CrystalOptions)
end

function CrystalOptions:_optionValue(entry)
  local loader = self.game.mods
  local stored = loader and loader.modOptions and loader.modOptions[entry.modId]
  local result = stored and stored[entry.row.key]
  if result == nil then result = entry.row.default end
  return result
end

function CrystalOptions:_setOption(entry, newValue)
  local game, loader = self.game, self.game.mods
  game.options.modOptions = game.options.modOptions or {}
  game.options.modOptions[entry.modId] = game.options.modOptions[entry.modId] or {}
  game.options.modOptions[entry.modId][entry.row.key] = newValue
  loader.modOptions = loader.modOptions or {}
  loader.modOptions[entry.modId] = loader.modOptions[entry.modId] or {}
  loader.modOptions[entry.modId][entry.row.key] = newValue
  game:writeOptions()
  if loader.events then
    loader.events:emit("mod.options_changed", {
      mod = entry.modId, key = entry.row.key, value = newValue,
    })
  end
end

function CrystalOptions:rows()
  local loader = self.game.mods
  if not loader then return {} end
  local names = {}
  for modId, schema in pairs(loader.optionSchemas or {}) do
    local loaded = loader.mods and loader.mods[modId]
    if type(schema) == "table" and loaded and loaded.state == "loaded" then
      names[#names + 1] = modId
    end
  end
  table.sort(names, function(left, right)
    local leftMod, rightMod = loader.mods[left], loader.mods[right]
    local leftName = leftMod and leftMod.manifest.name or left
    local rightName = rightMod and rightMod.manifest.name or right
    return leftName < rightName
  end)
  local result = {}
  for _, modId in ipairs(names) do
    local modRecord = loader.mods[modId]
    for _, row in ipairs(loader.optionSchemas[modId]) do
      if type(row) == "table" and type(row.key) == "string"
          and (row.type == "toggle" or row.type == "choice"
            or row.type == "number") then
        result[#result + 1] = {
          modId = modId,
          modName = modRecord.manifest.name or modId,
          row = row,
        }
      end
    end
  end
  return result
end

function CrystalOptions:valueLabel(entry)
  local row, current = entry.row, self:_optionValue(entry)
  if row.type == "toggle" then return current and "ON" or "OFF" end
  if row.type == "choice" then
    local choice = (row.choices or {})[choiceIndex(row, current)]
    return choice and tostring(choice[1]) or "----"
  end
  return tostring(current or 0)
end

function CrystalOptions:step(direction)
  local entry = self:rows()[self.cursor]
  if not entry then return false end
  local row, current = entry.row, self:_optionValue(entry)
  if row.type == "toggle" then
    self:_setOption(entry, not current)
  elseif row.type == "choice" then
    local choices = row.choices or {}
    if #choices == 0 then return false end
    local index = choiceIndex(row, current)
    index = ((index - 1 + direction) % #choices) + 1
    self:_setOption(entry, choices[index][2])
  elseif row.type == "number" then
    local nextValue = (tonumber(current) or tonumber(row.default) or 0)
      + direction * (tonumber(row.step) or 1)
    if row.min then nextValue = math.max(row.min, nextValue) end
    if row.max then nextValue = math.min(row.max, nextValue) end
    self:_setOption(entry, nextValue)
  end
  return true
end

function CrystalOptions:_visibleCount(height)
  return math.max(1, math.floor((height - 164) / ROW_HEIGHT))
end

function CrystalOptions:_keepVisible(height)
  local rows = self:rows()
  self.cursor = math.max(1, math.min(self.cursor, math.max(1, #rows)))
  local visible = self:_visibleCount(height)
  if self.cursor <= self.scroll then self.scroll = self.cursor - 1 end
  if self.cursor > self.scroll + visible then self.scroll = self.cursor - visible end
  self.scroll = math.max(0, math.min(self.scroll, math.max(0, #rows - visible)))
end

function CrystalOptions:open()
  if #self:rows() == 0 then
    self.game:_setNotice("No enabled mods expose Crystal settings")
    return false
  end
  self.active = true
  self.cursor, self.scroll = 1, 0
  if self.game.input then self.game.input:reset() end
  return true
end

function CrystalOptions:close()
  self.active = false
  if self.game.input then self.game.input:reset() end
  return true
end

function CrystalOptions:toggle()
  if self.active then return self:close() end
  return self:open()
end

function CrystalOptions:keypressed(key)
  if not self.active then
    if key == "f3" or key == "escape" then return self:open() end
    return false
  end
  if key == "f3" or key == "escape" or key == "backspace" then
    return self:close()
  elseif key == "up" or key == "w" then
    self.cursor = self.cursor - 1
  elseif key == "down" or key == "s" then
    self.cursor = self.cursor + 1
  elseif key == "left" or key == "a" then
    self:step(-1)
  elseif key == "right" or key == "d" or key == "return" or key == "space" then
    self:step(1)
  end
  self:_keepVisible(select(2, love.graphics.getDimensions()))
  return true
end

function CrystalOptions:gamepadpressed(button)
  if not self.active then
    if button == "guide" then return self:open() end
    return false
  end
  if button == "b" or button == "back" then return self:close() end
  if button == "dpup" then self.cursor = self.cursor - 1
  elseif button == "dpdown" then self.cursor = self.cursor + 1
  elseif button == "dpleft" or button == "leftshoulder" then self:step(-1)
  elseif button == "dpright" or button == "rightshoulder" or button == "a" then
    self:step(1)
  end
  self:_keepVisible(select(2, love.graphics.getDimensions()))
  return true
end

function CrystalOptions:_buttonBounds(width)
  return (width - BUTTON_WIDTH) / 2, 10, BUTTON_WIDTH, BUTTON_HEIGHT
end

local function inside(x, y, left, top, width, height)
  return x >= left and y >= top and x <= left + width and y <= top + height
end

function CrystalOptions:pointerPressed(x, y)
  local width, height = love.graphics.getDimensions()
  if not self.active then
    local left, top, buttonWidth, buttonHeight = self:_buttonBounds(width)
    if inside(x, y, left, top, buttonWidth, buttonHeight) then return self:open() end
    return false
  end
  local panelTop = 72
  local visible = self:_visibleCount(height)
  if y >= panelTop and y < panelTop + visible * ROW_HEIGHT then
    local index = self.scroll + math.floor((y - panelTop) / ROW_HEIGHT) + 1
    if self:rows()[index] then
      self.cursor = index
      self:step(1)
    end
    return true
  end
  if y <= 58 and x >= width - 100 then return self:close() end
  return true
end

function CrystalOptions:wheelmoved(direction)
  if not self.active then return false end
  self.cursor = self.cursor - direction
  self:_keepVisible(select(2, love.graphics.getDimensions()))
  return true
end

function CrystalOptions:drawButton()
  local width = love.graphics.getDimensions()
  local left, top, buttonWidth, buttonHeight = self:_buttonBounds(width)
  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", left, top, buttonWidth, buttonHeight, 6, 6)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf("F3  MOD OPTIONS", left, top + 8, buttonWidth, "center")
  love.graphics.pop()
end

function CrystalOptions:draw()
  local width, height = love.graphics.getDimensions()
  if not self.active then return self:drawButton() end
  self:_keepVisible(height)
  local rows = self:rows()
  local visible = self:_visibleCount(height)
  local panelWidth = math.min(760, width - PANEL_MARGIN * 2)
  local panelLeft = (width - panelWidth) / 2
  local modWidth = math.min(210, math.max(110, panelWidth * 0.31))
  local valueWidth = math.min(220, math.max(100, panelWidth * 0.29))
  local labelLeft = panelLeft + 18 + modWidth
  local valueLeft = panelLeft + panelWidth - valueWidth - 12
  love.graphics.push("all")
  love.graphics.setColor(0.015, 0.025, 0.055, 0.96)
  love.graphics.rectangle("fill", 0, 0, width, height)
  love.graphics.setColor(0.16, 0.35, 0.55, 1)
  love.graphics.rectangle("fill", panelLeft, 14, panelWidth, 44, 8, 8)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("CRYSTAL MOD OPTIONS", panelLeft + 16, 28)
  love.graphics.printf("CLOSE", panelLeft, 28, panelWidth - 16, "right")
  for slot = 1, visible do
    local index = self.scroll + slot
    local entry = rows[index]
    if not entry then break end
    local top = 72 + (slot - 1) * ROW_HEIGHT
    if index == self.cursor then
      love.graphics.setColor(0.12, 0.48, 0.78, 0.9)
      love.graphics.rectangle("fill", panelLeft, top, panelWidth, ROW_HEIGHT - 3,
        5, 5)
    elseif slot % 2 == 0 then
      love.graphics.setColor(1, 1, 1, 0.045)
      love.graphics.rectangle("fill", panelLeft, top, panelWidth, ROW_HEIGHT - 3)
    end
    love.graphics.setColor(0.66, 0.78, 0.9, 1)
    love.graphics.printf(entry.modName, panelLeft + 12, top + 11, modWidth - 8,
      "left")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(entry.row.label or entry.row.key, labelLeft, top + 11,
      math.max(60, valueLeft - labelLeft - 8), "left")
    love.graphics.printf("<  " .. self:valueLabel(entry) .. "  >",
      valueLeft, top + 11, valueWidth, "right")
  end
  local selected = rows[self.cursor]
  love.graphics.setColor(0.72, 0.8, 0.9, 1)
  love.graphics.printf(selected and selected.row.help or
    "Arrow keys/D-pad move. Left/right changes. F3, Escape, or B closes.",
    panelLeft + 8, height - 58, panelWidth - 16, "center")
  love.graphics.pop()
end

return CrystalOptions
