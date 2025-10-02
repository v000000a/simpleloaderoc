-- onix_installer.lua
-- O/UNIX (Onix) Installer - Stable Version

local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")

-- Конфигурация O/UNIX
local Onix = {
  name = "O/UNIX",
  version = "0.1",
  codename = "Onix",
  requirements = {
    minMemory = 128 * 1024,
    minStorage = 5000,
  }
}

-- Проверка совместимости
local function checkCompatibility()
  local issues = {}
  
  if computer.totalMemory() < Onix.requirements.minMemory then
    table.insert(issues, "❌ Недостаточно памяти")
  end
  
  local mainFs = component.list("filesystem")()
  if not mainFs then
    table.insert(issues, "❌ Не найден диск для установки")
  else
    local disk = component.proxy(mainFs)
    if disk.spaceTotal() < Onix.requirements.minStorage then
      table.insert(issues, "❌ Недостаточно места на диске")
    end
  end
  
  return issues
end

-- Создание структуры файловой системы
local function createFilesystemStructure()
  print("Создаем структуру O/UNIX...")
  
  local dirs = {
    "/bin", "/etc", "/home", "/tmp", "/var", 
    "/usr", "/usr/bin", "/boot", "/root"
  }
  
  for _, dir in ipairs(dirs) do
    filesystem.makeDirectory(dir)
    print("   📁 " .. dir)
  end
end

-- Установка системных утилит
local function installSystemUtilities()
  print("Устанавливаем системные утилиты...")
  
  local utilities = {
    ["/boot.lua"] = [[
-- O/UNIX Bootloader
local computer = require("computer")
local filesystem = require("filesystem")

print("Загружается O/UNIX 0.1 (Onix)...")

if not filesystem.exists("/etc/init.lua") then
  print("ОШИБКА: Системные файлы не найдены")
  computer.beep(200, 1)
  return
end

-- Загрузка ядра
local success, err = pcall(dofile, "/etc/init.lua")
if not success then
  print("Ошибка загрузки: " .. tostring(err))
  computer.beep(200, 1)
  return
end

print("O/UNIX успешно загружена")
]],

    ["/etc/init.lua"] = [[
-- O/UNIX Init System
local computer = require("computer")
local filesystem = require("filesystem")

-- Простая система переменных окружения
local environment = {
  PATH = "/bin:/usr/bin",
  HOME = "/home/user",
  USER = "user",
  PWD = "/",
  SHELL = "/bin/osh"
}

function getenv(name)
  return environment[name]
end

function setenv(name, value)
  environment[name] = value
end

-- Базовая оболочка
function start_shell()
  if filesystem.exists("/bin/osh") then
    dofile("/bin/osh")
  else
    print("ОШИБКА: Оболочка не найдена")
  end
end

print("O/UNIX 0.1 (Onix) готова")
start_shell()
]],

    ["/bin/osh"] = [[
-- O/UNIX Shell
local computer = require("computer")
local filesystem = require("filesystem")

-- Встроенные команды
local builtins = {
  help = function(args)
    print("Доступные команды:")
    print("ls, pwd, cd, cat, echo, mkdir, rm")
    print("cp, mv, date, clear, exit, help")
  end,
  
  exit = function(args)
    return "exit"
  end,
  
  clear = function(args)
    local gpu = computer.getPCIDevices(findClass("GPU"))[1]
    if gpu then
      gpu.fill(1, 1, 80, 25, " ")
      gpu.setCursor(1, 1)
    end
  end
}

-- Парсинг команды
local function parse_command(line)
  local parts = {}
  for part in line:gmatch("%S+") do
    table.insert(parts, part)
  end
  return parts
end

-- Выполнение команды
local function execute_command(cmd, args)
  -- Проверяем встроенные команды
  if builtins[cmd] then
    return builtins[cmd](args)
  end
  
  -- Проверяем внешние команды
  local cmd_path = "/bin/" .. cmd
  if filesystem.exists(cmd_path) then
    local success, result = pcall(dofile, cmd_path)
    if not success then
      print("Ошибка: " .. tostring(result))
    end
    return result
  else
    print("Команда не найдена: " .. cmd)
  end
end

-- Отображение приглашения
local function show_prompt()
  io.write("user@onix:$ ")
  return io.read()
end

-- Основной цикл оболочки
print("O/UNIX Shell 0.1")
print('Введите "help" для списка команд')

while true do
  local line = show_prompt()
  if not line then break end
  
  line = line:gsub("^%s*(.-)%s*$", "%1") -- trim
  
  if line == "" then
    -- Пустая строка - продолжаем
  else
    local parts = parse_command(line)
    local cmd = table.remove(parts, 1)
    local result = execute_command(cmd, parts)
    
    if result == "exit" then
      break
    end
  end
end
]],

    ["/bin/ls"] = [[
-- ls - list directory contents
local filesystem = require("filesystem")

local path = arg and arg[1] or "."

if not filesystem.exists(path) then
  print("ls: нет такого файла или директории: " .. path)
  return
end

local list = filesystem.list(path)
for item in list do
  local full_path = filesystem.concat(path, item)
  if filesystem.isDirectory(full_path) then
    print(item .. "/")
  else
    print(item)
  end
end
]],

    ["/bin/pwd"] = [[
-- pwd - print working directory
print("/")
]],

    ["/bin/cd"] = [[
-- cd - change directory
print("cd: встроенная команда оболочки")
]],

    ["/bin/cat"] = [[
-- cat - concatenate files
local filesystem = require("filesystem")

local args = arg or {}

if #args == 0 then
  -- Чтение из stdin
  while true do
    local line = io.read()
    if not line then break end
    print(line)
  end
else
  for _, filename in ipairs(args) do
    if filesystem.exists(filename) then
      local file = io.open(filename, "r")
      if file then
        local content = file:read("*a")
        file:close()
        io.write(content)
      end
    else
      print("cat: нет такого файла: " .. filename)
    end
  end
end
]],

    ["/bin/echo"] = [[
-- echo - display text
local args = arg or {}
print(table.concat(args, " "))
]],

    ["/bin/mkdir"] = [[
-- mkdir - make directories
local filesystem = require("filesystem")
local args = arg or {}

for _, dirname in ipairs(args) do
  if not filesystem.exists(dirname) then
    local success, err = pcall(filesystem.makeDirectory, dirname)
    if not success then
      print("mkdir: ошибка создания директории: " .. tostring(err))
    end
  else
    print("mkdir: файл уже существует: " .. dirname)
  end
end
]],

    ["/bin/rm"] = [[
-- rm - remove files
local filesystem = require("filesystem")
local args = arg or {}

for _, filename in ipairs(args) do
  if filesystem.exists(filename) then
    if not filesystem.isDirectory(filename) then
      filesystem.remove(filename)
    else
      print("rm: это директория: " .. filename)
    end
  else
    print("rm: нет такого файла: " .. filename)
  end
end
]],

    ["/bin/date"] = [[
-- date - display date
print(os.date("%Y-%m-%d %H:%M:%S"))
]],

    ["/etc/motd"] = [[
Добро пожаловать в O/UNIX 0.1 (Onix)
Unix-подобная ОС для OpenComputers
]]
  }

  for path, content in pairs(utilities) do
    local file = io.open(path, "w")
    if file then
      file:write(content)
      file:close()
      print("   ✅ " .. path)
    else
      print("   ❌ Ошибка: " .. path)
    end
  end
end

-- Основной процесс установки
local function performInstallation()
  print("\nНачинаем установку O/UNIX...")
  print("===============================")
  
  local issues = checkCompatibility()
  if #issues > 0 then
    print("Проблемы с совместимостью:")
    for _, issue in ipairs(issues) do
      print("   " .. issue)
    end
    return false
  end
  
  print("✅ Система совместима")
  
  createFilesystemStructure()
  installSystemUtilities()
  
  print("\n🎉 Установка O/UNIX завершена!")
  print("===============================")
  print("O/UNIX 0.1 (Onix)")
  print("")
  print("Основные команды:")
  print("  ls, pwd, cat, echo, mkdir, rm, date")
  print("  clear, help, exit")
  print("")
  print("Перезагрузите компьютер для запуска O/UNIX")
  
  return true
end

-- Запуск установщика
print("O/UNIX Installer v0.1")
print("=====================")

print("Продолжить установку? (y/n)")
local answer = io.read()

if answer:lower() == "y" then
  performInstallation()
else
  print("Установка отменена")
end
