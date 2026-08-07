package.path = "./vendor/luagb/?.lua;./vendor/luagb/?/init.lua;"
  .. "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness").suite("Crystal MBC3 RTC")
local check, eq = T.check, T.eq

local mapper = require("gameboy/mbc/mbc3").new()
mapper.raw_data = setmetatable({}, { __index = function() return 0 end })
mapper.external_ram = setmetatable({ dirty = false }, {
  __index = function() return 0 end,
})

mapper[0x0000] = 0x0A
mapper[0x4000] = 0x08
mapper[0xA000] = 42
mapper[0x6000] = 0
mapper[0x6000] = 1
eq(mapper[0xA000], 42, "latched seconds read back")

mapper[0x4000] = 0x09
mapper[0xA000] = 17
mapper[0x6000] = 0
mapper[0x6000] = 1
eq(mapper[0xA000], 17, "minutes register is writable")

mapper[0x4000] = 0x0C
mapper[0xA000] = 0x40
local halted = mapper:get_rtc_state()
check(halted.halted, "halt bit freezes the clock")

local saved = mapper:save_state()
local restored = require("gameboy/mbc/mbc3").new()
restored.raw_data = mapper.raw_data
restored.external_ram = mapper.external_ram
restored:load_state(saved)
check(restored:get_rtc_state().halted, "save states preserve RTC halt")

restored[0x0000] = 0x0A
restored[0x4000] = 0
restored[0xA000] = 0xAB
eq(restored[0xA000], 0xAB, "MBC3 external RAM remains banked and writable")
check(restored.external_ram.dirty, "RAM and RTC writes mark battery data dirty")

T.finish("Crystal MBC3 RTC")
