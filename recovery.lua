-- Recovery Menu
local gpu = component.proxy(component.list("gpu")())
local w, h = gpu.maxResolution()
gpu.setResolution(w, h)
gpu.fill(1, 1, w, h, " ")

-- colours
local bg = 0x2C2C2C
local fg = 0xFFFFFF
local accent = 0x007AFF
local red = 0xFF3B30
local green = 0x34C759

gpu.setBackground(bg)
gpu.setForeground(fg)
gpu.fill(1, 1, w, h, " ")

-- GUI helpers
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
  return px >= btn.x and px <= btn.x + btn.w - 1 and py >= btn.y and py <= btn.y + btn.h - 1
end

-- disks list
local function listDisks()
  local disks = {}
  for addr, _ in component.list("filesystem") do
    table.insert(disks, {addr = addr, label = component.invoke(addr, "getLabel") or "Unlabeled"})
  end
  return disks
end

-- file manager (simple)
local function fileManager(diskAddr)
  local path = "/"
  local function drawPath()
    gpu.setBackground(bg)
    gpu.setForeground(accent)
    gpu.fill(1, 3, w, 1, " ")
    gpu.set(2, 3, "Path: " .. path)
  end
  local function drawFiles()
    gpu.setBackground(bg)
    gpu.fill(1, 5, w, h - 5, " ")
    local list = component.invoke(diskAddr, "list", path)
    local y = 5
    for name in list do
      gpu.set(2, y, name)
      y = y + 1
    end
  end
  drawPath(); drawFiles()
  -- simplified control (Enter = return)
  while true do
    local _, _, char = event.pull("key")
    if char == 13 then break end
  end
end

-- disk wiping
local function wipeDisk(addr)
  gpu.setForeground(red)
  center("Wiping disk " .. addr:sub(1, 8) .. "...", h - 2)
  component.invoke(addr, "remove", "/") -- wiping root
  gpu.setForeground(green)
  center("Wiped!", h - 2)
  os.sleep(1)
end

-- load openos from disk
local function loadOpenOSFromDisk()
  local addr = computer.getBootAddress()
  local ok, err = pcall(function()
    local boot = loadfile("/lib/core/boot.lua")
    boot(loadfile)
  end)
  if not ok then
    gpu.setForeground(red)
    center("Boot failed: " .. tostring(err), h - 2)
    os.sleep(2)
  end
end

-- main menu
local function mainMenu()
  while true do
    gpu.setBackground(bg)
    gpu.fill(1, 1, w, h, " ")
    center("Recovery Menu", 3)

    local btn1 = button("File Manager", 10, 8, 25, 3, accent, white)
    local btn2 = button("Wipe Disk", 10, 13, 25, 3, red, white)
    local btn3 = button("Load OpenOS", 10, 18, 25, 3, green, white)
    local btn4 = button("Exit", 10, 23, 25, 3, bg, white)

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
        loadOpenOSFromDisk()
        break
      elseif inside(x, y, btn4) then
        computer.shutdown(true)
      end
    end
  end
end

-- старт
local ok, err = pcall(mainMenu)
if not ok then
  gpu.setForeground(0xFF0000)
  center("ERROR: " .. tostring(err), 1)
  os.sleep(3)
  computer.shutdown(true)
end
