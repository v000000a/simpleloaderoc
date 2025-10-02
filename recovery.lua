-- Minimal GUI Recovery Loader 2025 (English)
-- Requests system APIs explicitly → no nil crashes

-- 1) Ask the system for APIs
local component = require("component")
local computer  = require("computer")
local gpu       = component.proxy(component.list("gpu")())
local event     = require("event")

-- 2) Screen init
local w, h = gpu.maxResolution()
gpu.setResolution(w, h)
gpu.fill(1, 1, w, h, " ")

-- 3) Colours (2025 minimal)
local bg    = 0x1A1A1A
local fg    = 0xFFFFFF
local bar   = 0x00AA00
local red   = 0xFF3B30
local green = 0x34C759

gpu.setBackground(bg)
gpu.setForeground(fg)
gpu.fill(1, 1, w, h, " ")

-- 4) Helpers
local function center(text, y)
  local x = math.floor((w - #text) / 2) + 1
  gpu.set(x, y, text)
end

local function button(text, x, y, w, h, bgC, fgC)
  gpu.setBackground(bgC)
  gpu.setForeground(fgC)
  gpu.fill(x, y, w, h, " ")
  gpu.set(math.floor(x + (w - #text) / 2), math.floor(y + h / 2), text)
  return {x = x, y = y, w = w, h = h, text = text}
end

local function inside(px, py, btn)
  return px >= btn.x and px <= btn.x + btn.w - 1 and
         py >= btn.y and py <= btn.y + btn.h - 1
end

-- 5) Disk list
local function listDisks()
  local disks = {}
  for addr, _ in component.list("filesystem") do
    table.insert(disks, {
      addr  = addr,
      label = component.invoke(addr, "getLabel") or "Unlabeled"
    })
  end
  return disks
end

-- 6) File manager (simple GUI)
local function fileManager(diskAddr)
  local path = "/"
  while true do
    gpu.setBackground(0x1A1A1A)
    gpu.fill(1, 3, w, h - 3, " ")
    center("File Manager: " .. path, 3)

    local list = component.invoke(diskAddr, "list", path)
    local y = 5
    for name in list do
      gpu.set(2, y, name)
      y = y + 1
    end

    -- touch to exit
    local _, _, x, y = event.pull("touch")
    if y > h - 3 then break end
  end
end

-- 7) Wipe disk
local function wipeDisk(addr)
  center("Wiping disk " .. addr:sub(1, 8) .. "...", h - 2)
  component.invoke(addr, "remove", "/")
  center("Wiped!", h - 2)
  os.sleep(1)
end

-- 8) Boot OpenOS from this disk
local function bootOpenOS()
  local ok, err = pcall(function()
    local boot = loadfile("/lib/core/boot.lua")
    boot(loadfile)
  end)
  if not ok then
    gpu.setForeground(0xFF0000)
    center("Boot failed: " .. tostring(err), h - 2)
    os.sleep(2)
    computer.shutdown(true)
  end
end

-- 9) Main menu (GUI)
local function mainMenu()
  while true do
    gpu.setBackground(0x1A1A1A)
    gpu.fill(1, 1, w, h, " ")
    center("Recovery Menu 2025", 3)

    local btn1 = button("File Manager", 10, 8, 25, 3, 0x007AFF, 0xFFFFFF)
    local btn2 = button("Wipe Disk", 10, 13, 25, 3, 0xFF3B30, 0xFFFFFF)
    local btn3 = button("Boot OpenOS", 10, 18, 25, 3, 0x34C759, 0xFFFFFF)
    local btn4 = button("Exit", 10, 23, 25, 3, 0x2C2C2C, 0xFFFFFF)

    while true do
      local _, _, x, y = event.pull("touch")
      if inside(x, y, btn1) then
        local disks = listDisks()
        if #disks > 0 then fileManager(disks[1].addr) end
        break
      elseif inside(x, y, btn2) then
        local disks = listDisks()
        if #disks > 0 then wipeDisk(disks[1].addr) end
        break
      elseif inside(x, y, btn3) then
        bootOpenOS()
        break
      elseif inside(x, y, btn4) then
        computer.shutdown(true)
      end
    end
  end
end

-- 10) Start + crash guard
local ok, err = pcall(mainMenu)
if not ok then
  gpu.setForeground(0xFF0000)
  center("CRASH: " .. tostring(err), 1)
  os.sleep(3)
  computer.shutdown(true)
end
