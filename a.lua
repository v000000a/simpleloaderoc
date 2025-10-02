-- GParted-style Disk Manager for OpenComputers (exactly as you say)
local component = require("component")
local computer  = require("computer")
local event     = require("event")
local gpu       = component.proxy(component.list("gpu", true)())
local w, h      = gpu.maxResolution()
gpu.setResolution(w, h)
gpu.fill(1, 1, w, h, " ")

-- System colours (minimal 2025)
local bg      = 0xF2F2F7
local fg      = 0x000000
local accent  = 0x007AFF
local green   = 0x34C759
local gray    = 0x8E8E93

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

-- Disk list (docs: component.invoke)
local function listDisks()
  local disks = {}
  for addr, _ in component.list("filesystem") do
    table.insert(disks, {
      addr  = addr,
      label = component.invoke(addr, "getLabel") or "Unlabeled",
      size  = component.invoke(addr, "spaceTotal") or 0
    })
end
  return disks
end

-- GParted-style disk manager (browse + delete + confirm)
local function gpartedManager(diskAddr)
  local path = "/"
  while true do
    gpu.setBackground(bg); gpu.fill(1, 5, w, h - 5, " ")
    center("GParted Manager: " .. path, 5)

    local list = component.invoke(diskAddr, "list", path)
    local y = 7
    local items = {}
    for name in list do table.insert(items, name) end

    -- draw files/folders
    for i, name in ipairs(items) do
      gpu.set(2, y, name); y = y + 1
    end

    -- bottom bar: Delete / Back / Confirm
    local btnDel  = button("Delete", 10, h - 6, 12, 2, accent, 0xFFFFFF)
    local btnBack = button("Back",   24, h - 6, 12, 2, gray, 0xFFFFFF)
    local btnConf = button("Confirm", 38, h - 6, 12, 2, green, 0xFFFFFF)

    while true do
      local _, _, x, y = event.pull("touch")
      if inside(x, y, btnBack) then
        break -- exit manager
      elseif inside(x, y, btnDel) then
        -- delete single file (with confirm)
        center("Tap a file to DELETE (or anywhere to cancel)", h - 4)
        local _, _, x2, y2 = event.pull("touch")
        local idx = y2 - 7
        if idx >= 1 and idx <= #items then
          local name = items[idx]
          local confirm = prompt("Delete " .. name .. " ? (y/n)") or "n"
          if confirm:lower() == "y" then
            component.invoke(diskAddr, "remove", path .. name)
            center("Deleted", h - 2)
            computer.pull(0.3)
          end
        end
        break
      elseif inside(x, y, btnConf) then
        -- Confirm wipe (with confirm)
        local confirm = prompt("Wipe entire disk? (y/n)") or "n"
        if confirm:lower() == "y" then
          wipeDisk(diskAddr)
        end
        break
      end
    end
  end
end

-- Wipe entire disk (with confirm)
local function wipeDisk(addr)
  center("Wiping " .. addr:sub(1, 8) .. "...", h - 2)
  component.invoke(addr, "remove", "/")
  center("Wiped!", h - 2)
  computer.pull(0.5)
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

-- Prompt helper (docs: event.pull + string.char)
local function prompt(question)
  center(question, h - 4)
  local _, _, answer = event.pull("key")
  return string.char(answer)
end

-- Main menu (docs: touch + pull)
local function mainMenu()
  while true do
    gpu.setBackground(bg); gpu.fill(1, 1, w, h, " ")
    center("GParted Manager 2025", 3)

    local btn1 = button("Browse Disks", 10, 8, 25, 3, accent, 0xFFFFFF)
    local btn2 = button("Wipe Disk", 10, 13, 25, 3, red, 0xFFFFFF)
    local btn3 = button("Boot OpenOS", 10, 18, 25, 3, green, 0xFFFFFF)
    local btn4 = button("Exit", 10, 23, 25, 3, bg, fg)

    while true do
      local _, _, x, y = event.pull("touch")
      if inside(x, y, btn1) then
        local disks = listDisks(); if #disks > 0 then gpartedManager(disks[1].addr) end; break
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
