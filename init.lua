-- GUI Boot 2025 (modern splash + progress bar)
local gpu = component.proxy(component.list("gpu")())
local w, h = gpu.maxResolution()
gpu.setResolution(w, h)
gpu.fill(1, 1, w, h, " ")

-- Modern 2025 palette
local bg = 0x1A1A1A
local fg = 0x00FF00
local bar = 0x00AA00
local white = 0xFFFFFF

gpu.setBackground(bg)
gpu.setForeground(fg)
gpu.fill(1, 1, w, h, " ")

-- Center text helper
local function center(text, y)
  local x = math.floor((w - #text) / 2) + 1
  gpu.set(x, y, text)
end

-- 2) Show version and boot address
local version = "OC 1.8.3"
local addr = computer.getBootAddress():sub(1, 8) .. "..."
local title = "GUI Boot 2025"
local loading = "Loading core..."

center(title, math.floor(h / 2) - 4)
gpu.setForeground(white)
center("Version: " .. version, math.floor(h / 2) - 2)
center("Boot from: " .. addr, math.floor(h / 2) - 1)
gpu.setForeground(fg)
center(loading, math.floor(h / 2) + 1)


for i = 1, barW do
  gpu.setBackground(bar)
  gpu.set(barX + i - 1, barY, "█")
  gpu.setBackground(bg)
  computer.pull(0.05)   -- sleep's alternative
end

-- Final splash
gpu.setForeground(white)
center("Core loaded. Starting OS...", math.floor(h / 2) + 5)
os.sleep(0.5)

-- Core loader
local function loadfile(file)
  local addr, invoke = computer.getBootAddress(), component.invoke
  local handle = assert(invoke(addr, "open", file))
  local buffer = ""
  repeat
    local data = invoke(addr, "read", handle, math.maxinteger or math.huge)
    buffer = buffer .. (data or "")
  until not data
  invoke(addr, "close", handle)
  return load(buffer, "=" .. file, "bt", _G)
end

-- Start OS
local ok, err = pcall(function()
  loadfile("/lib/core/boot.lua")(loadfile)
end)

if not ok then
  gpu.setForeground(0xFF0000)
  center("CRASH: " .. tostring(err), h)
  os.sleep(3)
  computer.shutdown(true)
end
