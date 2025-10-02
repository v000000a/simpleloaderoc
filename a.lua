-- coded_door.lua
-- Настраиваемый кодовый замок для двери

local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local serialization = require("serialization")

-- Проверяем необходимые компоненты
if not component.isAvailable("redstone") then
  print("❌ Требуется компонент redstone")
  return
end

local gpu = component.gpu
local redstone = component.redstone

-- Конфигурация по умолчанию
local config = {
  code = "1234",           -- Код по умолчанию
  doorSide = 0,            -- Сторона двери (0-5)
  openTime = 5,            -- Время открытия в секундах
  maxAttempts = 3,         -- Максимальное количество попыток
  lockoutTime = 30,        -- Время блокировки при превышении попыток
  beepOnKeypress = true,   -- Звук при нажатии клавиш
  showStars = true         -- Показывать звездочки вместо цифр
}

-- Переменные состояния
local currentInput = ""
local failedAttempts = 0
local lockedUntil = 0
local doorOpen = false

-- Названия сторон для отображения
local sideNames = {
  [0] = "низ", [1] = "верх", [2] = "север", 
  [3] = "юг", [4] = "запад", [5] = "восток"
}

-- Загрузка конфигурации
local function loadConfig()
  if not component.isAvailable("filesystem") then
    print("⚠️  Файловая система недоступна, используем настройки по умолчанию")
    return
  end
  
  local success, fs = pcall(component.list, "filesystem")
  if success and fs then
    local addr = next(fs)
    if addr and component.proxy(addr).exists("/door_config.cfg") then
      local file = io.open("/door_config.cfg", "r")
      if file then
        local content = file:read("*a")
        file:close()
        local loaded = serialization.unserialize(content)
        if loaded then
          for k, v in pairs(loaded) do
            config[k] = v
          end
          print("✅ Конфигурация загружена")
        end
      end
    end
  end
end

-- Сохранение конфигурации
local function saveConfig()
  if not component.isAvailable("filesystem") then
    return false
  end
  
  local file = io.open("/door_config.cfg", "w")
  if file then
    file:write(serialization.serialize(config))
    file:close()
    return true
  end
  return false
end

-- Очистка экрана
local function clearScreen()
  if gpu then
    local w, h = gpu.getResolution()
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, w, h, " ")
    gpu.set(1, 1, "")
  else
    term.clear()
  end
end

-- Отображение интерфейса
local function displayInterface()
  clearScreen()
  
  local timeLeft = math.max(0, lockedUntil - computer.uptime())
  local isLocked = timeLeft > 0
  
  if gpu then
    local w, h = gpu.getResolution()
    
    -- Заголовок
    gpu.setBackground(0x2C3E50)
    gpu.fill(1, 1, w, 1, " ")
    gpu.setForeground(0xFFFFFF)
    gpu.set(math.floor(w/2)-6, 1, "🔒 КОДОВЫЙ ЗАМОК")
    
    -- Основная область
    gpu.setBackground(0x1a1a1a)
    gpu.fill(1, 2, w, h-1, " ")
    
    -- Статус
    local doorStatus = doorOpen and "ОТКРЫТА" or "ЗАКРЫТА"
    gpu.setForeground(doorOpen and 0x00FF00 or 0xFFFFFF)
    gpu.set(3, 3, "Дверь: " .. doorStatus)
    
    gpu.setForeground(0xFFFFFF)
    gpu.set(3, 4, "Попытки: " .. failedAttempts .. "/" .. config.maxAttempts)
    
    if isLocked then
      gpu.setForeground(0xFF0000)
      gpu.set(3, 5, "🔒 ЗАБЛОКИРОВАНО: " .. math.ceil(timeLeft) .. "с")
    else
      gpu.setForeground(0x00FF00)
      gpu.set(3, 5, "✅ ГОТОВ К РАБОТЕ")
    end
    
    -- Отображение ввода
    gpu.setForeground(0xFFFFFF)
    gpu.set(3, 7, "Ввод: ")
    
    local displayText = ""
    if config.showStars then
      displayText = string.rep("•", #currentInput)
    else
      displayText = currentInput
    end
    
    gpu.setForeground(0xFFFF00)
    gpu.set(9, 7, displayText .. string.rep("_", 6 - #currentInput))
    
    -- Подсказки
    gpu.setForeground(0x888888)
    gpu.set(3, 9, "Enter - Проверить код")
    gpu.set(3, 10, "C - Очистить ввод")
    gpu.set(3, 11, "* - Настройки")
    gpu.set(3, 12, "# - Переключить дверь")
    
  else
    -- Текстовый интерфейс
    print("=== КОДОВЫЙ ЗАМОК ===")
    local doorStatus = doorOpen and "ОТКРЫТА" or "ЗАКРЫТА"
    print("Дверь: " .. doorStatus)
    print("Попытки: " .. failedAttempts .. "/" .. config.maxAttempts)
    
    if isLocked then
      print("🔒 ЗАБЛОКИРОВАНО: " .. math.ceil(timeLeft) .. "с")
    else
      print("✅ ГОТОВ К РАБОТЕ")
    end
    
    local displayText = config.showStars and string.rep("*", #currentInput) or currentInput
    print("Ввод: " .. displayText .. string.rep("_", 6 - #currentInput))
    print("\nEnter - Проверить | C - Очистить | * - Настройки | # - Переключить")
  end
end

-- Управление дверью
local function setDoorState(open)
  if open then
    redstone.setOutput(config.doorSide, 15)  -- Сигнал для открытия
    doorOpen = true
    print("🚪 Дверь открыта на " .. config.openTime .. " секунд")
  else
    redstone.setOutput(config.doorSide, 0)   -- Сигнал для закрытия
    doorOpen = false
    print("🔒 Дверь закрыта")
  end
end

-- Открытие двери на время
local function openDoorTemporarily()
  setDoorState(true)
  
  -- Запускаем таймер закрытия
  computer.beep(800, 0.2)
  event.timer(config.openTime, function()
    setDoorState(false)
    computer.beep(600, 0.2)
  end)
end

-- Проверка кода
local function checkCode()
  if currentInput == config.code then
    print("✅ Код верный!")
    failedAttempts = 0
    openDoorTemporarily()
    return true
  else
    print("❌ Неверный код!")
    failedAttempts = failedAttempts + 1
    
    if failedAttempts >= config.maxAttempts then
      lockedUntil = computer.uptime() + config.lockoutTime
      print("🚫 Система заблокирована на " .. config.lockoutTime .. " секунд")
      computer.beep(300, 1)
    else
      computer.beep(400, 0.5)
    end
    
    return false
  end
end

-- Меню настроек
local function showSettings()
  clearScreen()
  
  if gpu then
    local w, h = gpu.getResolution()
    gpu.setBackground(0x2C3E50)
    gpu.fill(1, 1, w, 1, " ")
    gpu.setForeground(0xFFFFFF)
    gpu.set(math.floor(w/2)-4, 1, "⚙️ НАСТРОЙКИ")
    
    gpu.setBackground(0x1a1a1a)
    gpu.fill(1, 2, w, h-1, " ")
    
    local beepStatus = config.beepOnKeypress and "ВКЛ" or "ВЫКЛ"
    local starsStatus = config.showStars and "ВКЛ" or "ВЫКЛ"
    
    gpu.setForeground(0xFFFFFF)
    gpu.set(3, 3, "1. Изменить код (текущий: " .. config.code .. ")")
    gpu.set(3, 4, "2. Время открытия: " .. config.openTime .. "с")
    gpu.set(3, 5, "3. Макс. попыток: " .. config.maxAttempts)
    gpu.set(3, 6, "4. Время блокировки: " .. config.lockoutTime .. "с")
    gpu.set(3, 7, "5. Сторона двери: " .. sideNames[config.doorSide] .. " (" .. config.doorSide .. ")")
    gpu.set(3, 8, "6. Звук клавиш: " .. beepStatus)
    gpu.set(3, 9, "7. Звездочки: " .. starsStatus)
    gpu.set(3, 10, "0. Сохранить и выйти")
    
  else
    local beepStatus = config.beepOnKeypress and "ВКЛ" or "ВЫКЛ"
    local starsStatus = config.showStars and "ВКЛ" or "ВЫКЛ"
    
    print("=== НАСТРОЙКИ ===")
    print("1. Изменить код (текущий: " .. config.code .. ")")
    print("2. Время открытия: " .. config.openTime .. "с")
    print("3. Макс. попыток: " .. config.maxAttempts)
    print("4. Время блокировки: " .. config.lockoutTime .. "с")
    print("5. Сторона двери: " .. sideNames[config.doorSide] .. " (" .. config.doorSide .. ")")
    print("6. Звук клавиш: " .. beepStatus)
    print("7. Звездочки: " .. starsStatus)
    print("0. Сохранить и выйти")
  end
  
  print("\nВыберите опцию: ")
  local choice = io.read()
  
  if choice == "1" then
    print("Введите новый код (только цифры): ")
    local newCode = io.read()
    if newCode and #newCode >= 1 then
      config.code = newCode
      print("✅ Код изменен на: " .. newCode)
    else
      print("❌ Код не может быть пустым")
    end
    
  elseif choice == "2" then
    print("Введите время открытия в секундах: ")
    local time = tonumber(io.read())
    if time and time > 0 then
      config.openTime = time
      print("✅ Время установлено: " .. time .. "с")
    else
      print("❌ Неверное время")
    end
    
  elseif choice == "3" then
    print("Введите максимальное количество попыток: ")
    local attempts = tonumber(io.read())
    if attempts and attempts > 0 then
      config.maxAttempts = attempts
      print("✅ Попытки установлены: " .. attempts)
    else
      print("❌ Неверное количество")
    end
    
  elseif choice == "4" then
    print("Введите время блокировки в секундах: ")
    local lockTime = tonumber(io.read())
    if lockTime and lockTime > 0 then
      config.lockoutTime = lockTime
      print("✅ Время блокировки установлено: " .. lockTime .. "с")
    else
      print("❌ Неверное время")
    end
    
  elseif choice == "5" then
    print("Доступные стороны:")
    for i = 0, 5 do
      print("  " .. i .. " - " .. sideNames[i])
    end
    print("Введите номер стороны (0-5): ")
    local side = tonumber(io.read())
    if side and side >= 0 and side <= 5 then
      config.doorSide = side
      print("✅ Сторона установлена: " .. sideNames[side] .. " (" .. side .. ")")
    else
      print("❌ Неверная сторона")
    end
    
  elseif choice == "6" then
    config.beepOnKeypress = not config.beepOnKeypress
    local newStatus = config.beepOnKeypress and "ВКЛ" or "ВЫКЛ"
    print("✅ Звук клавиш: " .. newStatus)
    
  elseif choice == "7" then
    config.showStars = not config.showStars
    local newStatus = config.showStars and "ВКЛ" or "ВЫКЛ"
    print("✅ Звездочки: " .. newStatus)
    
  elseif choice == "0" then
    if saveConfig() then
      print("✅ Настройки сохранены")
    else
      print("⚠️  Не удалось сохранить настройки")
    end
    return
  end
  
  -- Рекурсивно показываем меню, пока не выберут выход
  showSettings()
end

-- Основной цикл
local function mainLoop()
  loadConfig()
  
  print("🚪 Кодовый замок активирован")
  print("Код по умолчанию: " .. config.code)
  print("Сторона redstone: " .. sideNames[config.doorSide] .. " (" .. config.doorSide .. ")")
  print("Используйте * для входа в настройки")
  
  while true do
    displayInterface()
    
    local e, _, keyCode, char = event.pull()
    
    if e == "key_down" then
      local timeLeft = math.max(0, lockedUntil - computer.uptime())
      local isLocked = timeLeft > 0
      
      if not isLocked then
        if keyCode == 13 then -- Enter
          if #currentInput > 0 then
            checkCode()
            currentInput = ""
          end
          
        elseif keyCode == 8 then -- Backspace
          if #currentInput > 0 then
            currentInput = currentInput:sub(1, -2)
            if config.beepOnKeypress then computer.beep(500, 0.1) end
          end
          
        elseif char == "c" or char == "C" or char == "с" or char == "С" then
          currentInput = ""
          if config.beepOnKeypress then computer.beep(600, 0.1) end
          
        elseif char == "*" then
          showSettings()
          currentInput = ""
          
        elseif char == "#" then
          -- Переключение состояния двери (для тестирования)
          setDoorState(not doorOpen)
          
        elseif char and tonumber(char) then
          -- Цифровая клавиша
          if #currentInput < 10 then -- Ограничение длины кода
            currentInput = currentInput .. char
            if config.beepOnKeypress then computer.beep(800, 0.05) end
          else
            computer.beep(300, 0.2)
          end
        end
      else
        -- Система заблокирована
        computer.beep(200, 0.3)
      end
    end
    
    -- Проверяем, не истекла ли блокировка
    if lockedUntil > 0 and computer.uptime() >= lockedUntil then
      lockedUntil = 0
      failedAttempts = 0
      print("🔓 Система разблокирована")
    end
  end
end

-- Запуск с обработкой ошибок
local success, err = pcall(mainLoop)
if not success then
  print("❌ Критическая ошибка: " .. tostring(err))
  print("Перезапустите программу")
end
