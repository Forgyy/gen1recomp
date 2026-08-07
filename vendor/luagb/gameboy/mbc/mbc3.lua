local bit32 = require("bit")

local Mbc3 = {}

local DAY_SECONDS = 24 * 60 * 60
local COUNTER_SECONDS = 512 * DAY_SECONDS

function Mbc3.new()
  local mbc3 = {
    raw_data = {},
    external_ram = {},
    header = {},
    rom_bank = 1,
    ram_bank = 0,
    ram_enable = false,
    rtc_enable = false,
    rtc_select = 0x08,
    rtc_seconds = 0,
    rtc_last_unix = os.time(),
    rtc_halted = false,
    rtc_carry = false,
    rtc_latched = nil,
    rtc_latch_write = 0,
  }

  local function syncClock()
    local now = os.time()
    if not mbc3.rtc_halted then
      local elapsed = math.max(0, now - mbc3.rtc_last_unix)
      local total = mbc3.rtc_seconds + elapsed
      if total >= COUNTER_SECONDS then mbc3.rtc_carry = true end
      mbc3.rtc_seconds = total % COUNTER_SECONDS
    end
    mbc3.rtc_last_unix = now
  end

  local function registers()
    syncClock()
    local total = mbc3.rtc_seconds
    local days = math.floor(total / DAY_SECONDS)
    total = total % DAY_SECONDS
    local hours = math.floor(total / 3600)
    total = total % 3600
    local minutes = math.floor(total / 60)
    local seconds = total % 60
    return {
      [0x08] = seconds,
      [0x09] = minutes,
      [0x0A] = hours,
      [0x0B] = bit32.band(days, 0xFF),
      [0x0C] = bit32.bor(bit32.rshift(bit32.band(days, 0x100), 8),
        mbc3.rtc_halted and 0x40 or 0,
        mbc3.rtc_carry and 0x80 or 0),
    }
  end

  local function writeRegister(register, value)
    local current = registers()
    current[register] = bit32.band(value, 0xFF)
    local days = current[0x0B] + bit32.lshift(bit32.band(current[0x0C], 1), 8)
    mbc3.rtc_seconds = ((days * 24 + current[0x0A] % 24) * 60
      + current[0x09] % 60) * 60 + current[0x08] % 60
    local wasHalted = mbc3.rtc_halted
    mbc3.rtc_halted = bit32.band(current[0x0C], 0x40) ~= 0
    mbc3.rtc_carry = bit32.band(current[0x0C], 0x80) ~= 0
    if wasHalted ~= mbc3.rtc_halted then mbc3.rtc_last_unix = os.time() end
    mbc3.rtc_latched = nil
    mbc3.external_ram.dirty = true
  end

  mbc3.mt = {}
  mbc3.mt.__index = function(_, address)
    if type(address) ~= "number" then return rawget(mbc3, address) end
    if address <= 0x3FFF then return mbc3.raw_data[address] end
    if address <= 0x7FFF then
      return mbc3.raw_data[mbc3.rom_bank * 0x4000 + address - 0x4000]
    end
    if address >= 0xA000 and address <= 0xBFFF and mbc3.ram_enable then
      if mbc3.rtc_enable then
        local values = mbc3.rtc_latched or registers()
        return values[mbc3.rtc_select] or 0xFF
      end
      return mbc3.external_ram[address - 0xA000 + mbc3.ram_bank * 0x2000]
    end
    return 0xFF
  end

  mbc3.mt.__newindex = function(_, address, value)
    if type(address) ~= "number" then
      rawset(mbc3, address, value)
      return
    end
    value = bit32.band(value, 0xFF)
    if address <= 0x1FFF then
      mbc3.ram_enable = bit32.band(value, 0x0F) == 0x0A
    elseif address <= 0x3FFF then
      mbc3.rom_bank = bit32.band(value, 0x7F)
      if mbc3.rom_bank == 0 then mbc3.rom_bank = 1 end
    elseif address <= 0x5FFF then
      if value <= 0x03 then
        mbc3.ram_bank = value
        mbc3.rtc_enable = false
      elseif value >= 0x08 and value <= 0x0C then
        mbc3.rtc_select = value
        mbc3.rtc_enable = true
      end
    elseif address <= 0x7FFF then
      if mbc3.rtc_latch_write == 0 and value == 1 then
        mbc3.rtc_latched = registers()
      end
      mbc3.rtc_latch_write = value
    elseif address >= 0xA000 and address <= 0xBFFF and mbc3.ram_enable then
      if mbc3.rtc_enable then
        writeRegister(mbc3.rtc_select, value)
      else
        mbc3.external_ram[address - 0xA000 + mbc3.ram_bank * 0x2000] = value
        mbc3.external_ram.dirty = true
      end
    end
  end

  function mbc3:reset()
    self.rom_bank = 1
    self.ram_bank = 0
    self.ram_enable = false
    self.rtc_enable = false
    self.rtc_select = 0x08
    self.rtc_latched = nil
    self.rtc_latch_write = 0
  end

  function mbc3:get_rtc_state()
    syncClock()
    return {
      seconds = self.rtc_seconds,
      lastUnix = self.rtc_last_unix,
      halted = self.rtc_halted,
      carry = self.rtc_carry,
    }
  end

  function mbc3:load_rtc_state(state)
    if type(state) ~= "table" then return false end
    self.rtc_seconds = math.max(0, tonumber(state.seconds) or 0) % COUNTER_SECONDS
    self.rtc_last_unix = tonumber(state.lastUnix) or os.time()
    self.rtc_halted = state.halted == true
    self.rtc_carry = state.carry == true
    syncClock()
    return true
  end

  function mbc3:save_state()
    return {
      rom_bank = self.rom_bank,
      ram_bank = self.ram_bank,
      ram_enable = self.ram_enable,
      rtc_enable = self.rtc_enable,
      rtc_select = self.rtc_select,
      rtc = self:get_rtc_state(),
      rtc_latched = self.rtc_latched,
      rtc_latch_write = self.rtc_latch_write,
    }
  end

  function mbc3:load_state(state)
    self:reset()
    self.rom_bank = state.rom_bank or 1
    self.ram_bank = state.ram_bank or 0
    self.ram_enable = state.ram_enable == true
    self.rtc_enable = state.rtc_enable == true
    self.rtc_select = state.rtc_select or 0x08
    self:load_rtc_state(state.rtc)
    self.rtc_latched = state.rtc_latched
    self.rtc_latch_write = state.rtc_latch_write or 0
  end

  setmetatable(mbc3, mbc3.mt)
  return mbc3
end

return Mbc3
