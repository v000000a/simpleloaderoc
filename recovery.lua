-- Recovery Menu 2025 (4/5) — follows OC 1.8.3 docs
local component = require("component")
local computer  = require("computer")
local event     = require("event")
local gpu       = component.proxy(component.list("gpu", true)())
local w, h      = gpu.maxResolution()
gpu.setResolution(w, h)
gpu.fill(1, 1, w, h, " ")

-- System colours (modern 2025)
local bg    = 0xF2F2F7
local fg    = 0x000000
local accent = 0x007AFF
local red   = 0xFF3B30
local green = 0x34C759

gpu.setBackground(bg)
gpu.setForeground(fg)
gpu.fill(1, 1, w, h, " ")

-- GUI helpers (docs-compliant)
local function center(text, y)
  local x = math.floor((w - #text) / 2) + 1
  gpu.set(x, y, text)
end

local function button(text, x, y, w, h, bgC, fgC)
  gpu.setBackground(bgC); gpu.setForeground(fgC)
  gpu.fill(x, y, w, h, " ")
  gpu.set(math.floor(x + (w - #text) / 2), math.floor(y + h / 2), text)
  return {x = x, y = y, w = w, h = h, text = text}
end

local function inside(px, py, btn)
  return px >= btn.x and px <= btn.x + btn.w - 1 and
         py >= btn.y and py <= btn.y + btn.h - 1
end

-- Disk manager (uses component.invoke per docs)
local function diskManager(addr)
  local path = "/"
  while true do
    gpu.setBackground(0xF2F2F7); gpu.fill(1, 5, w, h - 5, " ")
    center("Disk Manager: " .. path, 5)
    local list = component.invoke(addr, "list", path)
    local y = 7
    for name in list do
      gpu.set(2, y, name); y = y + 1
    end
    -- touch to exit (docs: event.pull)
    local _, _, x, y = event.pull("touch")
    if y > h - 3 then break end
  end
end

-- Wipe disk (docs: remove("/"))
local function wipeDisk(addr)
  center("Wiping " .. addr:sub(1, 8) .. "...", h - 2)
  component.invoke(addr, "remove", "/")
  center("Wiped!", h - 2)
  computer.pull(0.5) -- docs: use computer.pull, not os.sleep
end

-- Boot OpenOS (docs: loadfile + pcall)
local function bootOpenOS()
  local ok, err = pcall(function()
    local boot = loadfile("/lib/core/boot.lua")
    boot(loadfile)
  end)
  if not ok then
    gpu.setForeground(red); center("Boot failed: " .. tostring(err), h - 2)
    computer.pull(2); computer.shutdown(true)
  end
end

-- Main menu (docs: touch + pull)
local function mainMenu()
  while true do
    gpu.setBackground(bg); gpu.fill(1, 1, w, h, " ")
    center("Recovery Menu 2025", 3)

    local btn1 = button("File Manager", 10, 8, 25, 3, accent, 0xFFFFFF)
    local btn2 = button("Wipe Disk", 10, 13, 25, 3, red, 0xFFFFFF)
    local btn3 = button("Boot OpenOS", 10, 18, 25, 3, green, 0xFFFFFF)
    local btn4 = button("Exit", 10, 23, 25, 3, bg, fg)

    while true do
      local _, _, x, y = event.pull("touch")
      if inside(x, y, btn1) then
        local disks = listDisks(); if #disks > 0 then diskManager(disks[1].addr) end; break
      elseif inside(x, y, btn2) then
        local disks = listDisks(); if #disks > 0 then wipeDisk(disks[1].addr) end; break
      elseif inside(x, y, btn3) then
        bootOpenOS(); break
      elseif inside(x, y, btn4) then
        computer.shutdown(true)
      end
    end
  end
end

-- Start + crash guard (docs: pcall)
local ok, err = pcall(mainMenu)
if not ok then
  gpu.setForeground(red); center("CRASH: " .. tostring(err), 1)
  computer.pull(3); computer.shutdown(true)
end
