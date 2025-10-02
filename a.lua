-- tabletos_installer.lua
-- TabletOS Installer - Установщик для планшетов OpenComputers

local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local term = require("term")
local filesystem = require("filesystem")

-- Конфигурация TabletOS
local TabletOS = {
  name = "TabletOS",
  version = "1.0",
  requirements = {
    minMemory = 512 * 1024,  -- 512KB
    minStorage = 500000,     -- ~500KB
    gpuRequired = true
  },
  structure = {
    "/system",
    "/apps", 
    "/user",
    "/cache",
    "/config",
    "/downloads"
  }
}

-- Проверка сенсорного экрана (через события)
local function hasTouchScreen()
  if not component.isAvailable("gpu") then
    return false
  end
  
  local w, h = gpu.getResolution()
  return w >= 40 and h >= 12
end

-- Проверка совместимости
local function checkCompatibility()
  local issues = {}
  local warnings = {}
  
  if computer.totalMemory() < TabletOS.requirements.minMemory then
    table.insert(issues, "❌ Недостаточно памяти: " .. math.floor(computer.totalMemory()/1024) .. "KB/" .. math.floor(TabletOS.requirements.minMemory/1024) .. "KB")
  end
  
  local mainFs = component.list("filesystem")()
  if mainFs then
    local disk = component.proxy(mainFs)
    if disk.spaceTotal() < TabletOS.requirements.minStorage then
      table.insert(issues, "❌ Недостаточно места: " .. disk.spaceTotal() .. "/" .. TabletOS.requirements.minStorage)
    end
  else
    table.insert(issues, "❌ Не найден диск для установки")
  end
  
  if not component.isAvailable("gpu") then
    table.insert(issues, "❌ Требуется видеокарта")
  end
  
  if not hasTouchScreen() then
    table.insert(warnings, "⚠️  Сенсорный экран не обнаружен - управление клавиатурой")
  end
  
  return issues, warnings
end

-- Создание структуры диска
local function createDirectoryStructure()
  print("📁 Создаем структуру TabletOS...")
  
  for _, dir in ipairs(TabletOS.structure) do
    filesystem.makeDirectory(dir)
    print("   ✅ " .. dir)
  end
  
  local systemDirs = {
    "/system/kernel",
    "/system/lib", 
    "/system/bin",
    "/system/ui",
    "/system/drivers",
    "/apps/system",
    "/apps/user",
    "/user/documents",
    "/user/pictures",
    "/user/music",
    "/config/system",
    "/config/apps"
  }
  
  for _, dir in ipairs(systemDirs) do
    filesystem.makeDirectory(dir)
  end
end

-- Установка ядра системы
local function installKernel()
  print("🔧 Устанавливаем ядро TabletOS...")
  
  local kernelFiles = {
    ["/boot.lua"] = [[
-- TabletOS Bootloader
local component = require("component")
local computer = require("computer")
local event = require("event")

print("📱 TabletOS v1.0 загружается...")

if not component.isAvailable("gpu") then
  print("❌ Ошибка: Требуется видеокарта")
  return
end

local gpu = component.gpu
local w, h = gpu.getResolution()

if require("filesystem").exists("/system/kernel/init.lua") then
  dofile("/system/kernel/init.lua")
else
  print("❌ Ошибка: Ядро системы не найдено")
  computer.beep(1000, 0.5)
  return
end

if tabletOS and tabletOS.boot then
  tabletOS.boot()
else
  print("❌ Ошибка: Не удалось запустить систему")
end
]],

    ["/system/kernel/init.lua"] = [[
-- TabletOS Init System
tabletOS = {
  version = "1.0",
  apps = {},
  settings = {
    brightness = 80,
    volume = 70,
    wallpaper = 1
  }
}

tabletOS.systemApps = {
  launcher = "/system/ui/launcher.lua",
  settings = "/apps/system/settings.lua",
  camera = "/apps/system/camera.lua",
  music = "/apps/system/music.lua",
  browser = "/apps/system/browser.lua",
  calculator = "/apps/system/calculator.lua"
}

function tabletOS.installApp(name, path)
  tabletOS.apps[name] = path
  print("📱 Установлено приложение: " .. name)
end

function tabletOS.launchApp(path)
  if require("filesystem").exists(path) then
    local success, err = pcall(dofile, path)
    if not success then
      print("❌ Ошибка запуска: " .. tostring(err))
      computer.beep(800, 0.3)
    end
    return success
  else
    print("❌ Приложение не найдено: " .. path)
    return false
  end
end

function tabletOS.boot()
  print("🚀 Запускаем TabletOS...")
  
  for name, path in pairs(tabletOS.systemApps) do
    tabletOS.installApp(name, path)
  end
  
  if tabletOS.systemApps.launcher then
    tabletOS.launchApp(tabletOS.systemApps.launcher)
  else
    print("❌ Лаунчер не найден")
  end
end

function tabletOS.shutdown()
  print("🔄 Выключаем TabletOS...")
  computer.shutdown()
end

function tabletOS.reboot()
  print("🔃 Перезагружаем TabletOS...")
  computer.shutdown(true)
end
]],

    ["/system/ui/launcher.lua"] = [[
-- Графический лаунчер для планшета
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu

if not gpu then
  print("❌ Требуется видеокарта для лаунчера")
  return
end

launcher = {
  apps = {
    {"🏠", "Главная", "launcher"},
    {"📷", "Камера", "camera"},
    {"🎵", "Музыка", "music"}, 
    {"🧮", "Калькулятор", "calculator"},
    {"🌐", "Браузер", "browser"},
    {"⚙️", "Настройки", "settings"},
    {"📞", "Звонки", "dialer"},
    {"👤", "Контакты", "contacts"}
  },
  running = true
}

function launcher.drawInterface()
  local w, h = gpu.getResolution()
  
  gpu.setBackground(0x1a1a2e)
  gpu.fill(1, 1, w, h, " ")
  
  gpu.setBackground(0x333333)
  gpu.fill(1, 1, w, 1, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(2, 1, "TabletOS v1.0")
  
  local time = os.date("%H:%M")
  gpu.set(w - #time - 1, 1, time)
  
  local cols = 4
  local rows = 2
  local iconWidth = math.floor(w / cols)
  local iconHeight = 4

  for i, app in ipairs(launcher.apps) do
    if i <= cols * rows then
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      local x = col * iconWidth + 1
      local y = row * iconHeight + 3
      
      gpu.setBackground(0x444444)
      gpu.fill(x, y, iconWidth - 1, iconHeight - 1, " ")
      
      gpu.setForeground(0xFFFFFF)
      gpu.set(x + math.floor(iconWidth/2) - 1, y + 1, app[1])
      
      gpu.set(x + math.floor((iconWidth - #app[2])/2), y + 2, app[2])
    end
  end
  
  gpu.setBackground(0x333333)
  gpu.fill(1, h, w, 1, " ")
  gpu.set(2, h, "🏠 Нажмите ESC для выхода")
end

function launcher.handleInput()
  while launcher.running do
    local e, _, x, y, button = event.pull()
    
    if e == "touch" then
      local cols = 4
      local iconWidth = math.floor(gpu.getResolution() / cols)
      local iconHeight = 4
      
      for i, app in ipairs(launcher.apps) do
        if i <= 8 then
          local col = (i - 1) % cols
          local row = math.floor((i - 1) / cols)
          local iconX = col * iconWidth + 1
          local iconY = row * iconHeight + 3
          
          if x >= iconX and x < iconX + iconWidth - 1 and
             y >= iconY and y < iconY + iconHeight - 1 then
            print("📱 Запускаем: " .. app[2])
            tabletOS.launchApp(tabletOS.systemApps[app[3]] or app[3])
          end
        end
      end
      
    elseif e == "key_down" then
      if button == 27 then
        launcher.running = false
        print("👋 Выход из лаунчера")
        computer.beep(600, 0.2)
      elseif button == 13 then
        tabletOS.launchApp(tabletOS.systemApps.settings)
      end
    end
  end
end

print("🚀 Запускаем лаунчер...")
launcher.drawInterface()
launcher.handleInput()
]]
  }
  
  for path, content in pairs(kernelFiles) do
    local file = io.open(path, "w")
    if file then
      file:write(content)
      file:close()
      print("   ✅ " .. path)
    else
      print("   ❌ Ошибка записи: " .. path)
    end
  end
end

-- Установка системных приложений
local function installSystemApps()
  print("📱 Устанавливаем системные приложения...")
  
  local systemApps = {
    ["/apps/system/settings.lua"] = [[
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu

settingsApp = {
  running = true,
  options = {
    {"Яркость", "brightness", 80},
    {"Громкость", "volume", 70},
    {"Обои", "wallpaper", 1}
  }
}

function settingsApp.show()
  local w, h = gpu.getResolution()
  
  gpu.setBackground(0x222222)
  gpu.fill(1, 1, w, h, " ")
  
  gpu.setBackground(0x444444)
  gpu.fill(1, 1, w, 1, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(3, 1, "⚙️ Настройки TabletOS")
  
  for i, option in ipairs(settingsApp.options) do
    gpu.setForeground(0xCCCCCC)
    gpu.set(3, 3 + i, option[1] .. ":")
    gpu.set(15, 3 + i, tostring(option[3]))
  end
  
  gpu.setBackground(0x666666)
  gpu.fill(2, h - 2, 8, 1, " ")
  gpu.set(3, h - 2, "← Назад")
end

function settingsApp.handleInput()
  while settingsApp.running do
    local e, _, x, y = event.pull()
    
    if e == "touch" then
      local w, h = gpu.getResolution()
      
      if y == h - 2 and x >= 2 and x <= 10 then
        settingsApp.running = false
        computer.beep(500, 0.1)
      end
      
    elseif e == "key_down" then
      if button == 27 then
        settingsApp.running = false
      end
    end
  end
end

print("⚙️  Запускаем настройки...")
settingsApp.show()
settingsApp.handleInput()
print("🔙 Возвращаемся в лаунчер...")
]],

    ["/apps/system/calculator.lua"] = [[
local component = require("component")
local gpu = component.gpu

calculator = {
  display = "0",
  running = true
}

function calculator.draw()
  local w, h = gpu.getResolution()
  
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, w, h, " ")
  
  gpu.setBackground(0x333333)
  gpu.fill(2, 2, w - 2, 3, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(w - #calculator.display - 2, 3, calculator.display)
  
  local buttons = {
    "7", "8", "9", "/",
    "4", "5", "6", "*", 
    "1", "2", "3", "-",
    "0", "C", "=", "+"
  }
  
  for i, btn in ipairs(buttons) do
    local row = math.floor((i-1)/4)
    local col = (i-1)%4
    local x = 2 + col * 5
    local y = 6 + row * 2
    
    gpu.setBackground(0x666666)
    gpu.fill(x, y, 4, 1, " ")
    gpu.setForeground(0xFFFFFF)
    gpu.set(x + 2 - math.floor(#btn/2), y, btn)
  end
end

calculator.draw()
print("🧮 Калькулятор запущен (ESC для выхода)")
]],

    ["/apps/system/browser.lua"] = [[
print("🌐 Браузер запущен")
print("В разработке...")
print("Нажмите ESC для выхода")
]],

    ["/apps/system/music.lua"] = [[
print("🎵 Музыкальный плеер")
print("В разработке...")
print("Нажмите ESC для выхода")
]],

    ["/apps/system/camera.lua"] = [[
print("📷 Камера")
print("В разработке...") 
print("Нажмите ESC для выхода")
]]
  }
  
  for path, content in pairs(systemApps) do
    local file = io.open(path, "w")
    if file then
      file:write(content)
      file:close()
      print("   ✅ " .. path)
    end
  end
end

-- Основной процесс установки
local function performInstallation()
  print("\n🎯 Начинаем установку TabletOS...")
  print("==========================================")
  
  local issues, warnings = checkCompatibility()
  
  if #issues > 0 then
    print("❌ Проблемы с совместимостью:")
    for _, issue in ipairs(issues) do
      print("   " .. issue)
    end
    computer.beep(300, 1)
    return false
  end
  
  if #warnings > 0 then
    print("⚠️  Предупреждения:")
    for _, warning in ipairs(warnings) do
      print("   " .. warning)
    end
  end
  
  print("✅ Система совместима!")
  
  createDirectoryStructure()
  installKernel()
  installSystemApps()
  
  print("\n🎉 Установка завершена!")
  print("==========================================")
  print("TabletOS готова к использованию!")
  print("Перезагрузите устройство для запуска.")
  print("Управление:")
  print("  - Касание: выбор приложений")
  print("  - ESC: выход из приложений")
  print("  - Enter: настройки")
  
  computer.beep(1000, 0.2)
  computer.beep(1200, 0.2)
  computer.beep(1400, 0.3)
  
  return true
end

-- Графический установщик
local function showInstaller()
  local w, h = gpu.getResolution()
  
  gpu.setBackground(0x1a1a2e)
  gpu.fill(1, 1, w, h, " ")
  
  gpu.setBackground(0x333333)
  gpu.fill(1, 1, w, 3, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(math.floor(w/2) - 8, 2, "📱 TabletOS Installer")
  
  gpu.setForeground(0xCCCCCC)
  gpu.set(3, 5, "Версия: " .. TabletOS.version)
  gpu.set(3, 6, "Память: " .. math.floor(computer.totalMemory()/1024) .. " KB")
  
  local mainFs = component.list("filesystem")()
  if mainFs then
    local disk = component.proxy(mainFs)
    gpu.set(3, 7, "Диск: " .. disk.spaceTotal() .. " байт")
  end
  
  gpu.set(3, 8, "Сенсорный: " .. (hasTouchScreen() and "✅" or "❌ (клавиатура)"))
  
  gpu.setForeground(0xFFAA00)
  gpu.set(3, 10, "⚠️  Вся существующая система будет заменена!")
  
  gpu.setBackground(0x00AA00)
  gpu.fill(math.floor(w/2) - 6, 12, 12, 3, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(math.floor(w/2) - 4, 13, "УСТАНОВИТЬ")
  
  gpu.setBackground(0xAA0000)
  gpu.fill(math.floor(w/2) - 6, 16, 12, 3, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(math.floor(w/2) - 3, 17, "ОТМЕНА")
  
  print("\n🖱️  Используйте касание или клавиши для выбора...")
  
  while true do
    local e, _, x, y, button = event.pull()
    
    if e == "touch" then
      if y >= 12 and y <= 14 and x >= math.floor(w/2) - 6 and x <= math.floor(w/2) + 6 then
        computer.beep(800, 0.1)
        performInstallation()
        break
      elseif y >= 16 and y <= 18 and x >= math.floor(w/2) - 6 and x <= math.floor(w/2) + 6 then
        computer.beep(400, 0.2)
        print("❌ Установка отменена")
        break
      end
      
    elseif e == "key_down" then
      if button == 13 then
        computer.beep(800, 0.1)
        performInstallation()
        break
      elseif button == 27 then
        computer.beep(400, 0.2)
        print("❌ Установка отменена")
        break
      end
    end
  end
end

-- Запуск установщика
print("TabletOS Installer v" .. TabletOS.version)
if component.isAvailable("gpu") then
  showInstaller()
else
  performInstallation()
end
