-- Alarm Clock 2025 (single-player only)
-- Red screen, flashing front, time from 00:00 to 23:59, no safety

local component = require("component")
local computer  = require("computer")
local event     = require("event")
local gpu       = component.proxy(component.list("gpu", true)())
local w, h      = gpu.maxResolution()
gpu.setResolution(w, h)
gpu.fill(1, 1, w, h, " ")

-- Colours (alarm 2025)
local red     = 0xFF0000
local black   = 0x000000
local white   = 0xFFFFFF

-- Front LED (trevoga)
local front = component.proxy(component.list("redstone", true)())
if not front then
  -- fallback: screen only
  gpu.setBackground(red); gpu.fill(1, 1, w, h, " ")
  gpu.setForeground(white); center("NO FRONT LED - SCREEN ONLY", 10)
  computer.pull(3); return
end

-- Center helper
local function center(text, y)
  local x = math.floor((w - #text) / 2) + 1
  gpu.set(x, y, text)
end

-- Main loop (trevoga + time)
local function alarmLoop()
  local sec = 0 -- 0..86399 (00:00 to 23:59)
  while true do
    local hours = math.floor(sec / 3600)
    local mins  = math.floor((sec % 3600) / 60)
    local time  = string.format("%02d:%02d", hours, mins)

    -- Red screen + time
    gpu.setBackground(red); gpu.fill(1, 1, w, h, " ")
    gpu.setForeground(white); center(time, math.floor(h / 2))

    -- Front LED blink
    front.setOutput(15, sec % 2 == 0) -- on/off every second
    computer.beep(880, 0.05) -- 880 Hz = trevoga
    computer.pull(1) -- wait 1 second
    sec = (sec + 1) % 86400 -- 00:00 → 23:59 → 00:00
  end
end

-- Start (docs: pcall)
local ok, err = pcall(alarmLoop)
if not ok then
  gpu.setForeground(0xFF0000); center("CRASH: " .. tostring(err), 1)
  computer.pull(3); computer.shutdown(true)
end
