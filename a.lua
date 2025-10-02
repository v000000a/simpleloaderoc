-- touchos_installer.lua
-- TouchOS Installer - Полнофункциональная ОС для планшетов

local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local filesystem = require("filesystem")
local serialization = require("serialization")

-- Конфигурация TouchOS
local TouchOS = {
  name = "TouchOS",
  version = "2.0",
  theme = {
    primary = 0x2C3E50,
    secondary = 0x3498DB,
    accent = 0xE74C3C,
    background = 0xECF0F1,
    text = 0x2C3E50,
    success = 0x27AE60,
    warning = 0xF39C12,
    error = 0xE74C3C
  }
}

-- === СИСТЕМНЫЕ ФУНКЦИИ === --

-- Безопасная загрузка файла
local function safeLoad(path)
  if not filesystem.exists(path) then
    return nil, "File not found: " .. path
  end
  
  local file = io.open(path, "r")
  if not file then
    return nil, "Cannot open: " .. path
  end
  
  local content = file:read("*a")
  file:close()
  return content
end

-- Безопасное сохранение файла
local function safeSave(path, content)
  local file = io.open(path, "w")
  if not file then
    return false, "Cannot write: " .. path
  end
  
  file:write(content)
  file:close()
  return true
end

-- Создание директории с проверкой
local function mkdir(path)
  if not filesystem.exists(path) then
    return filesystem.makeDirectory(path)
  end
  return true
end

-- === ПРОВЕРКА СОВМЕСТИМОСТИ === --

local function checkCompatibility()
  local issues = {}
  
  -- Проверка памяти
  if computer.totalMemory() < 524288 then
    table.insert(issues, "❌ Требуется минимум 512KB памяти")
  end
  
  -- Проверка диска
  local mainFs = component.list("filesystem")()
  if not mainFs then
    table.insert(issues, "❌ Не найден загрузочный диск")
  else
    local disk = component.proxy(mainFs)
    if disk.spaceTotal() < 1048576 then
      table.insert(issues, "❌ Требуется минимум 1MB места")
    end
  end
  
  -- Проверка GPU
  if not component.isAvailable("gpu") then
    table.insert(issues, "❌ Требуется видеокарта")
  end
  
  return issues
end

-- === СОЗДАНИЕ СТРУКТУРЫ === --

local function createStructure()
  print("🏗️  Создаем структуру TouchOS...")
  
  local directories = {
    "/system",
    "/system/kernel",
    "/system/ui",
    "/system/apps",
    "/system/lib",
    "/system/config",
    "/user",
    "/user/documents",
    "/user/downloads",
    "/user/pictures",
    "/user/music",
    "/apps",
    "/cache",
    "/tmp"
  }
  
  for _, dir in ipairs(directories) do
    if mkdir(dir) then
      print("   📁 " .. dir)
    else
      print("   ❌ Ошибка: " .. dir)
    end
  end
end

-- === УСТАНОВКА ЯДРА === --

local function installKernel()
  print("🔧 Устанавливаем ядро TouchOS...")
  
  local kernelFiles = {
    ["/boot.lua"] = [[
-- TouchOS Bootloader
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu

-- Инициализация дисплея
if gpu then
  local w, h = gpu.getResolution()
  gpu.setBackground(0x2C3E50)
  gpu.fill(1, 1, w, h, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(math.floor(w/2)-8, math.floor(h/2), "🔄 Загружается TouchOS...")
end

computer.beep(800, 0.1)

-- Проверка системных файлов
local function fileExists(path)
  return pcall(function() return require("filesystem").exists(path) end)
end

if not fileExists("/system/kernel/init.lua") then
  if gpu then
    gpu.setBackground(0xE74C3C)
    gpu.fill(1, 1, 80, 25, " ")
    gpu.set(10, 10, "❌ Ошибка: Системные файлы повреждены")
  end
  computer.beep(200, 2)
  return
end

-- Загрузка ядра
local success, err = pcall(dofile, "/system/kernel/init.lua")
if not success then
  if gpu then
    gpu.setBackground(0xE74C3C)
    gpu.fill(1, 1, 80, 25, " ")
    gpu.set(10, 10, "❌ Ошибка загрузки:")
    gpu.set(10, 11, tostring(err))
  end
  computer.beep(200, 2)
  return
end

computer.beep(1200, 0.2)
print("✅ TouchOS успешно загружена")
]],

    ["/system/kernel/init.lua"] = [[
-- TouchOS Kernel
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local filesystem = require("filesystem")

-- Системные переменные
TouchOS = {
  version = "]] .. TouchOS.version .. [[",
  theme = ]] .. serialization.serialize(TouchOS.theme) .. [[,
  apps = {},
  settings = {
    brightness = 80,
    volume = 70,
    wallpaper = 1,
    language = "ru"
  }
}

-- Менеджер приложений
function TouchOS.installApp(name, path, icon, category)
  TouchOS.apps[name] = {
    path = path,
    icon = icon,
    category = category,
    name = name
  }
end

function TouchOS.launchApp(appName)
  local app = TouchOS.apps[appName]
  if not app then
    return false, "Приложение не найдено: " .. appName
  end
  
  if not filesystem.exists(app.path) then
    return false, "Файл приложения не найден: " .. app.path
  end
  
  print("🚀 Запускаем: " .. appName)
  computer.beep(1000, 0.1)
  
  local success, err = pcall(dofile, app.path)
  if not success then
    computer.beep(400, 0.5)
    return false, "Ошибка: " .. tostring(err)
  end
  
  return true
end

-- Системные функции
function TouchOS.shutdown()
  print("🔄 Выключаем TouchOS...")
  computer.beep(600, 0.3)
  computer.shutdown()
end

function TouchOS.reboot()
  print("🔃 Перезагружаем TouchOS...")
  computer.beep(800, 0.3)
  computer.shutdown(true)
end

-- Загрузка системных приложений
print("⚡ Инициализируем TouchOS " .. TouchOS.version .. "...")

-- Регистрируем системные приложения
TouchOS.installApp("launcher", "/system/ui/launcher.lua", "🏠", "system")
TouchOS.installApp("settings", "/system/apps/settings.lua", "⚙️", "system")
TouchOS.installApp("files", "/system/apps/files.lua", "📁", "tools")
TouchOS.installApp("calculator", "/system/apps/calculator.lua", "🧮", "tools")
TouchOS.installApp("notes", "/system/apps/notes.lua", "📝", "tools")
TouchOS.installApp("camera", "/system/apps/camera.lua", "📷", "media")
TouchOS.installApp("music", "/system/apps/music.lua", "🎵", "media")
TouchOS.installApp("browser", "/system/apps/browser.lua", "🌐", "internet")

-- Запускаем лаунчер
print("🚀 Запускаем лаунчер...")
local success, err = TouchOS.launchApp("launcher")
if not success then
  print("❌ Не удалось запустить лаунчер: " .. tostring(err))
  computer.beep(300, 1)
end
]],

    ["/system/ui/launcher.lua"] = [[
-- TouchOS Launcher
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local filesystem = require("filesystem")

-- Проверка GPU
if not gpu then
  print("❌ Требуется видеокарта для лаунчера")
  return
end

local screenWidth, screenHeight = gpu.getResolution()

-- Класс кнопки
local Button = {}
function Button:new(x, y, width, height, text, icon, color)
  local obj = {
    x = x, y = y, width = width, height = height,
    text = text, icon = icon, color = color or TouchOS.theme.secondary
  }
  setmetatable(obj, {__index = self})
  return obj
end

function Button:draw()
  gpu.setBackground(self.color)
  gpu.fill(self.x, self.y, self.width, self.height, " ")
  
  gpu.setForeground(0xFFFFFF)
  if self.icon then
    gpu.set(self.x + math.floor(self.width/2), self.y + 1, self.icon)
  end
  if self.text then
    gpu.set(self.x + math.floor((self.width - #self.text)/2), self.y + self.height - 1, self.text)
  end
end

function Button:contains(x, y)
  return x >= self.x and x <= self.x + self.width - 1 and
         y >= self.y and y <= self.y + self.height - 1
end

-- Главный экран
local Launcher = {
  running = true,
  pages = {},
  currentPage = 1,
  appsPerPage = 8
}

function Launcher:setupPages()
  local appList = {}
  for name, app in pairs(TouchOS.apps) do
    table.insert(appList, app)
  end
  
  -- Сортируем приложения по категориям
  table.sort(appList, function(a, b) return a.name < b.name end)
  
  -- Разбиваем на страницы
  self.pages = {}
  for i = 1, #appList, self.appsPerPage do
    local page = {}
    for j = i, math.min(i + self.appsPerPage - 1, #appList) do
      table.insert(page, appList[j])
    end
    table.insert(self.pages, page)
  end
end

function Launcher:drawStatusBar()
  gpu.setBackground(TouchOS.theme.primary)
  gpu.fill(1, 1, screenWidth, 1, " ")
  
  gpu.setForeground(0xFFFFFF)
  gpu.set(2, 1, "TouchOS " .. TouchOS.version)
  
  local time = os.date("%H:%M")
  gpu.set(screenWidth - #time - 1, 1, time)
end

function Launcher:drawHomeScreen()
  gpu.setBackground(TouchOS.theme.background)
  gpu.fill(1, 2, screenWidth, screenHeight - 1, " ")
  
  -- Отрисовка приложений текущей страницы
  local page = self.pages[self.currentPage] or {}
  local cols = 4
  local rows = 2
  local buttonWidth = math.floor(screenWidth / cols) - 2
  local buttonHeight = 4
  
  for i, app in ipairs(page) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local x = col * (buttonWidth + 1) + 2
    local y = row * (buttonHeight + 1) + 3
    
    local button = Button:new(x, y, buttonWidth, buttonHeight, app.name, app.icon)
    button:draw()
    app.button = button
  end
  
  -- Индикатор страниц
  if #self.pages > 1 then
    gpu.setBackground(TouchOS.theme.primary)
    local dotsWidth = #self.pages * 2 - 1
    local dotsX = math.floor((screenWidth - dotsWidth) / 2)
    
    for i = 1, #self.pages do
      local dot = i == self.currentPage and "●" or "○"
      gpu.setForeground(i == self.currentPage and 0xFFFFFF or 0xAAAAAA)
      gpu.set(dotsX + (i-1)*2, screenHeight - 1, dot)
    end
  end
end

function Launcher:handleTouch(x, y)
  local page = self.pages[self.currentPage] or {}
  
  for _, app in ipairs(page) do
    if app.button and app.button:contains(x, y) then
      computer.beep(1200, 0.1)
      TouchOS.launchApp(app.name)
      return true
    end
  end
  
  -- Проверка свайпов
  if y == screenHeight - 1 then
    local dotsWidth = #self.pages * 2 - 1
    local dotsX = math.floor((screenWidth - dotsWidth) / 2)
    
    for i = 1, #self.pages do
      if x >= dotsX + (i-1)*2 and x <= dotsX + (i-1)*2 then
        if i ~= self.currentPage then
          self.currentPage = i
          computer.beep(800, 0.1)
        end
        return true
      end
    end
  end
  
  return false
end

function Launcher:run()
  self:setupPages()
  
  while self.running do
    self:drawStatusBar()
    self:drawHomeScreen()
    
    local e, _, x, y, button = event.pull(1, "touch", "key_down")
    
    if e == "touch" then
      self:handleTouch(x, y)
    elseif e == "key_down" then
      if button == 27 then -- ESC
        self.running = false
      elseif button == 114 then -- F3
        TouchOS.launchApp("settings")
      end
    end
  end
  
  print("👋 Возвращаемся в систему...")
end

-- Запуск лаунчера
Launcher:run()
]]
  }
  
  for path, content in pairs(kernelFiles) do
    if safeSave(path, content) then
      print("   ✅ " .. path)
    else
      print("   ❌ " .. path)
    end
  end
end

-- === УСТАНОВКА ПРИЛОЖЕНИЙ === --

local function installApps()
  print("📱 Устанавливаем приложения...")
  
  local apps = {
    ["/system/apps/settings.lua"] = [[
-- Настройки системы
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local serialization = require("serialization")

local Settings = {
  running = true,
  options = {
    {"Яркость", "brightness", 80, 0, 100},
    {"Громкость", "volume", 70, 0, 100},
    {"Обои", "wallpaper", 1, 1, 3},
    {"Язык", "language", "ru", {"ru", "en"}}
  }
}

function Settings:draw()
  local w, h = gpu.getResolution()
  
  -- Фон
  gpu.setBackground(TouchOS.theme.background)
  gpu.fill(1, 1, w, h, " ")
  
  -- Заголовок
  gpu.setBackground(TouchOS.theme.primary)
  gpu.fill(1, 1, w, 1, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(3, 1, "⚙️ Настройки TouchOS")
  
  -- Кнопка назад
  gpu.setBackground(TouchOS.theme.secondary)
  gpu.fill(2, 3, 8, 1, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(3, 3, "← Назад")
  
  -- Список настроек
  for i, option in ipairs(self.options) do
    local y = 5 + i * 2
    gpu.setForeground(TouchOS.theme.text)
    gpu.set(3, y, option[1] .. ":")
    gpu.set(15, y, tostring(TouchOS.settings[option[2]]))
    
    -- Ползунок для числовых настроек
    if option[4] and option[5] then
      local sliderWidth = 20
      local value = (TouchOS.settings[option[2]] - option[4]) / (option[5] - option[4])
      local fillWidth = math.floor(sliderWidth * value)
      
      gpu.setBackground(0xCCCCCC)
      gpu.fill(20, y, sliderWidth, 1, " ")
      gpu.setBackground(TouchOS.theme.success)
      gpu.fill(20, y, fillWidth, 1, " ")
    end
  end
end

function Settings:handleTouch(x, y)
  local w, h = gpu.getResolution()
  
  -- Кнопка назад
  if y == 3 and x >= 2 and x <= 10 then
    self.running = false
    computer.beep(600, 0.1)
    return true
  end
  
  -- Обработка настроек
  for i, option in ipairs(self.options) do
    local settingY = 5 + i * 2
    if y == settingY and x >= 20 and x <= 40 and option[4] and option[5] then
      local value = math.floor(((x - 20) / 20) * (option[5] - option[4]) + option[4])
      TouchOS.settings[option[2]] = math.max(option[4], math.min(option[5], value))
      computer.beep(800 + i * 100, 0.1)
      return true
    end
  end
  
  return false
end

function Settings:run()
  while self.running do
    self:draw()
    local e, _, x, y = event.pull("touch")
    self:handleTouch(x, y)
  end
end

-- Запуск приложения
print("⚙️  Запускаем настройки...")
Settings:run()
]],

    ["/system/apps/files.lua"] = [[
-- Файловый менеджер
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local filesystem = require("filesystem")

local FileManager = {
  running = true,
  currentPath = "/user",
  selectedFile = nil
}

function FileManager:draw()
  local w, h = gpu.getResolution()
  
  gpu.setBackground(TouchOS.theme.background)
  gpu.fill(1, 1, w, h, " ")
  
  -- Заголовок
  gpu.setBackground(TouchOS.theme.primary)
  gpu.fill(1, 1, w, 1, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(3, 1, "📁 Файлы - " .. self.currentPath)
  
  -- Кнопка назад
  gpu.setBackground(TouchOS.theme.secondary)
  gpu.fill(2, 3, 8, 1, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(3, 3, "← Назад")
  
  -- Кнопка домой
  gpu.setBackground(TouchOS.theme.success)
  gpu.fill(12, 3, 6, 1, " ")
  gpu.set(13, 3, "🏠")
  
  -- Список файлов
  local y = 5
  gpu.setForeground(TouchOS.theme.text)
  
  -- Родительская директория
  if self.currentPath ~= "/" then
    gpu.set(3, y, "📂 ..")
    y = y + 1
  end
  
  local list = filesystem.list(self.currentPath)
  for item in list do
    local fullPath = filesystem.concat(self.currentPath, item)
    local icon = filesystem.isDirectory(fullPath) and "📁" or "📄"
    
    if self.selectedFile == fullPath then
      gpu.setBackground(TouchOS.theme.secondary)
      gpu.fill(2, y, w - 2, 1, " ")
    else
      gpu.setBackground(TouchOS.theme.background)
    end
    
    gpu.setForeground(TouchOS.theme.text)
    gpu.set(3, y, icon .. " " .. item)
    y = y + 1
    
    if y >= h - 2 then break end
  end
end

function FileManager:handleTouch(x, y)
  local w, h = gpu.getResolution()
  
  -- Кнопка назад
  if y == 3 and x >= 2 and x <= 10 then
    self.running = false
    computer.beep(600, 0.1)
    return true
  end
  
  -- Кнопка домой
  if y == 3 and x >= 12 and x <= 18 then
    self.currentPath = "/user"
    computer.beep(800, 0.1)
    return true
  end
  
  -- Выбор файла/директории
  if y >= 5 then
    local listY = 5
    local itemIndex = y - 5
    
    -- Родительская директория
    if self.currentPath ~= "/" then
      if itemIndex == 0 then
        self.currentPath = self.currentPath:match("(.+)/[^/]+$") or "/"
        computer.beep(1000, 0.1)
        return true
      end
      itemIndex = itemIndex - 1
    end
    
    local list = filesystem.list(self.currentPath)
    local i = 0
    for item in list do
      if i == itemIndex then
        local fullPath = filesystem.concat(self.currentPath, item)
        if filesystem.isDirectory(fullPath) then
          self.currentPath = fullPath
          computer.beep(1200, 0.1)
        else
          self.selectedFile = fullPath
          computer.beep(900, 0.1)
        end
        return true
      end
      i = i + 1
    end
  end
  
  return false
end

function FileManager:run()
  while self.running do
    self:draw()
    local e, _, x, y = event.pull("touch")
    self:handleTouch(x, y)
  end
end

print("📁 Запускаем файловый менеджер...")
FileManager:run()
]],

    ["/system/apps/calculator.lua"] = [[
-- Калькулятор
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu

local Calculator = {
  running = true,
  display = "0",
  memory = 0,
  operator = nil,
  waiting = false
}

function Calculator:draw()
  local w, h = gpu.getResolution()
  
  gpu.setBackground(0x1a1a1a)
  gpu.fill(1, 1, w, h, " ")
  
  -- Дисплей
  gpu.setBackground(0x2C3E50)
  gpu.fill(2, 2, w - 2, 3, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(w - #self.display - 2, 3, self.display)
  
  -- Кнопки
  local buttons = {
    {"C", "±", "%", "÷"},
    {"7", "8", "9", "×"},
    {"4", "5", "6", "-"},
    {"1", "2", "3", "+"},
    {"0", "", ".", "="}
  }
  
  local buttonWidth = math.floor((w - 6) / 4)
  local buttonHeight = 2
  
  for row, rowButtons in ipairs(buttons) do
    for col, btn in ipairs(rowButtons) do
      if btn ~= "" then
        local x = 2 + (col - 1) * (buttonWidth + 1)
        local y = 6 + (row - 1) * (buttonHeight + 1)
        local width = (btn == "0") and buttonWidth * 2 + 1 or buttonWidth
        
        local color = TouchOS.theme.secondary
        if btn == "=" then color = TouchOS.theme.success
        elseif btn == "C" then color = TouchOS.theme.error
        elseif tonumber(btn) then color = 0x34495E end
        
        gpu.setBackground(color)
        gpu.fill(x, y, width, buttonHeight, " ")
        gpu.setForeground(0xFFFFFF)
        gpu.set(x + math.floor(width/2) - math.floor(#btn/2), y + math.floor(buttonHeight/2), btn)
        
        if btn == "0" then break end
      end
    end
  end
end

function Calculator:handleInput(button)
  if tonumber(button) or button == "." then
    if self.waiting or self.display == "0" then
      self.display = button
      self.waiting = false
    else
      self.display = self.display .. button
    end
  elseif button == "C" then
    self.display = "0"
    self.operator = nil
    self.waiting = false
  elseif button == "=" then
    if self.operator then
      local result = self:calculate(tonumber(self.memory), tonumber(self.display), self.operator)
      self.display = tostring(result)
      self.operator = nil
      self.waiting = true
    end
  else
    -- Операторы
    if self.operator and not self.waiting then
      self:handleInput("=")
    end
    self.memory = self.display
    self.operator = button
    self.waiting = true
  end
end

function Calculator:calculate(a, b, op)
  if op == "+" then return a + b
  elseif op == "-" then return a - b
  elseif op == "×" then return a * b
  elseif op == "÷" then return b ~= 0 and a / b or 0
  elseif op == "%" then return a % b
  end
  return b
end

function Calculator:run()
  while self.running do
    self:draw()
    
    local e, _, x, y = event.pull("touch")
    if e == "touch" then
      local buttons = {
        {"C", "±", "%", "÷"},
        {"7", "8", "9", "×"},
        {"4", "5", "6", "-"},
        {"1", "2", "3", "+"},
        {"0", "", ".", "="}
      }
      
      local buttonWidth = math.floor((gpu.getResolution() - 6) / 4)
      local buttonHeight = 2
      
      for row, rowButtons in ipairs(buttons) do
        for col, btn in ipairs(rowButtons) do
          if btn ~= "" then
            local btnX = 2 + (col - 1) * (buttonWidth + 1)
            local btnY = 6 + (row - 1) * (buttonHeight + 1)
            local width = (btn == "0") and buttonWidth * 2 + 1 or buttonWidth
            
            if x >= btnX and x < btnX + width and y >= btnY and y < btnY + buttonHeight then
              computer.beep(800, 0.05)
              self:handleInput(btn)
              break
            end
          end
        end
      end
    end
  end
end

print("🧮 Запускаем калькулятор...")
Calculator:run()
]],

    ["/system/apps/notes.lua"] = [[
-- Заметки
local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local filesystem = require("filesystem")

local Notes = {
  running = true,
  notes = {},
  currentNote = 1,
  editing = false
}

function Notes:loadNotes()
  if filesystem.exists("/user/notes.dat") then
    local content = safeLoad("/user/notes.dat")
    if content then
      self.notes = serialization.unserialize(content) or {}
    end
  end
  
  if #self.notes == 0 then
    table.insert(self.notes, "Новая заметка")
  end
end

function Notes:saveNotes()
  safeSave("/user/notes.dat", serialization.serialize(self.notes))
end

function Notes:draw()
  local w, h = gpu.getResolution()
  
  gpu.setBackground(TouchOS.theme.background)
  gpu.fill(1, 1, w, h, " ")
  
  -- Заголовок
  gpu.setBackground(TouchOS.theme.primary)
  gpu.fill(1, 1, w, 1, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(3, 1, "📝 Заметки")
  
  -- Кнопка назад
  gpu.setBackground(TouchOS.theme.secondary)
  gpu.fill(2, 3, 8, 1, " ")
  gpu.setForeground(0xFFFFFF)
  gpu.set(3, 3, "← Назад")
  
  -- Кнопка новой заметки
  gpu.setBackground(TouchOS.theme.success)
  gpu.fill(12, 3, 6, 1, " ")
  gpu.set(13, 3, "➕")
  
  if not self.editing then
    -- Список заметок
    gpu.setForeground(TouchOS.theme.text)
    for i, note in ipairs(self.notes) do
      local y = 5 + i
      if i == self.currentNote then
        gpu.setBackground(TouchOS.theme.secondary)
        gpu.fill(2, y, w - 2, 1, " ")
      else
        gpu.setBackground(TouchOS.theme.background)
      end
      gpu.set(3, y, "📄 " .. (note:sub(1, 30) .. (#note > 30 and "..." or "")))
    end
  else
    -- Редактор заметки
    gpu.setForeground(TouchOS.theme.text)
    gpu.set(3, 5, "Редактирование:")
    
    local noteText = self.notes[self.currentNote] or ""
    local lines = {}
    for line in noteText:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    
    for i, line in ipairs(lines) do
      if 7 + i <= h - 2 then
        gpu.set(3, 7 + i, line)
      end
    end
  end
end

function Notes:run()
  self:loadNotes()
  
  while self.running do
    self:draw()
    
    local e, _, x, y, button, char = event.pull("touch", "key_down")
    
    if e == "touch" then
      if y == 3 then
        if x >= 2 and x <= 10 then
          self.running = false
          computer.beep(600, 0.1)
        elseif x >= 12 and x <= 18 then
          table.insert(self.notes, "Новая заметка " .. (#self.notes + 1))
          self.currentNote = #self.notes
          computer.beep(1000, 0.1)
        end
      elseif not self.editing then
        local noteIndex = y - 5
        if noteIndex >= 1 and noteIndex <= #self.notes then
          self.currentNote = noteIndex
          self.editing = true
          computer.beep(800, 0.1)
        end
      end
    elseif e == "key_down" and self.editing then
      if button == 27 then -- ESC
        self.editing = false
        self:saveNotes()
      elseif button == 13 then -- Enter
        self.notes[self.currentNote] = self.notes[self.currentNote] .. "\n"
      elseif button == 8 then -- Backspace
        if #self.notes[self.currentNote] > 0 then
          self.notes[self.currentNote] = self.notes[self.currentNote]:sub(1, -2)
        end
      elseif char then
        self.notes[self.currentNote] = self.notes[self.currentNote] .. char
      end
    end
  end
  
  self:saveNotes()
end

print("📝 Запускаем заметки...")
Notes:run()
]]
  }
  
  for path, content in pairs(apps) do
    if safeSave(path, content) then
      print("   ✅ " .. path)
    else
      print("   ❌ " .. path)
    end
  end
end

-- === УСТАНОВКА КОНФИГОВ === --

local function installConfigs()
  print("⚙️  Устанавливаем конфигурации...")
  
  local configs = {
    ["/system/config/wallpapers.dat"] = serialization.serialize({
      {name = "Градиент синий", color1 = 0x3498DB, color2 = 0x2C3E50},
      {name = "Зеленый лес", color1 = 0x27AE60, color2 = 0x16A085},
      {name = "Фиолетовый", color1 = 0x9B59B6, color2 = 0x8E44AD}
    }),
    
    ["/system/config/default.conf"] = serialization.serialize({
      theme = TouchOS.theme,
      language = "ru",
      animations = true,
      sound = true
    })
  }
  
  for path, content in pairs(configs) do
    if safeSave(path, content) then
      print("   ⚙️  " .. path)
    end
  end
end

-- === ГРАФИЧЕСКИЙ УСТАНОВЩИК === --

local function showGraphicalInstaller()
  local w, h = gpu.getResolution()
  
  local function drawScreen(title, message, progress)
    gpu.setBackground(TouchOS.theme.primary)
    gpu.fill(1, 1, w, h, " ")
    
    -- Заголовок
    gpu.setForeground(0xFFFFFF)
    gpu.set(math.floor(w/2) - math.floor(#title/2), 3, title)
    
    -- Сообщение
    gpu.set(math.floor(w/2) - math.floor(#message/2), 5, message)
    
    -- Прогресс-бар
    if progress then
      local barWidth = math.floor(w * 0.8)
      local barX = math.floor((w - barWidth) / 2)
      local fillWidth = math.floor(barWidth * progress)
      
      gpu.setBackground(0x34495E)
      gpu.fill(barX, 8, barWidth, 2, " ")
      gpu.setBackground(TouchOS.theme.success)
      gpu.fill(barX, 8, fillWidth, 2, " ")
      
      local percent = math.floor(progress * 100)
      gpu.setForeground(0xFFFFFF)
      gpu.set(math.floor(w/2) - 2, 9, percent .. "%")
    end
  end
  
  -- Экран приветствия
  drawScreen("TouchOS Installer", "Установка современной ОС для планшетов")
  computer.beep(1000, 0.2)
  os.sleep(1)
  
  -- Проверка совместимости
  drawScreen("Проверка системы", "Проверяем оборудование...")
  local issues = checkCompatibility()
  
  if #issues > 0 then
    drawScreen("Ошибка", "Система несовместима:")
    for i, issue in ipairs(issues) do
      gpu.set(3, 7 + i, issue)
    end
    gpu.set(3, 12, "Нажмите для выхода...")
    event.pull("touch")
    return false
  end
  
  -- Установка
  local steps = {
    {"Создание структуры", createStructure},
    {"Установка ядра", installKernel},
    {"Установка приложений", installApps},
    {"Настройка системы", installConfigs}
  }
  
  for i, step in ipairs(steps) do
    local progress = (i - 1) / #steps
    drawScreen("Установка TouchOS", step[1], progress)
    computer.beep(800 + i * 100, 0.1)
    
    local success, err = pcall(step[2])
    if not success then
      drawScreen("Ошибка установки", "Ошибка в шаге: " .. step[1])
      gpu.set(3, 8, tostring(err))
      gpu.set(3, 12, "Нажмите для выхода...")
      event.pull("touch")
      return false
    end
    
    os.sleep(0.5)
  end
  
  -- Завершение
  drawScreen("Установка завершена", "TouchOS готова к использованию!", 1)
  computer.beep(1200, 0.3)
  computer.beep(1400, 0.3)
  
  gpu.set(3, 12, "✅ Система установлена успешно!")
  gpu.set(3, 14, "Перезагрузите устройство")
  gpu.set(3, 16, "Нажмите для завершения...")
  
  event.pull("touch")
  return true
end

-- === ОСНОВНАЯ ЛОГИКА === --

print("TouchOS Installer v" .. TouchOS.version)
print("================================")

if component.isAvailable("gpu") then
  local success = showGraphicalInstaller()
  if not success then
    print("❌ Установка прервана из-за ошибки")
  end
else
  print("❌ Требуется видеокарта для установки")
end
