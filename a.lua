-- onix_installer.lua
-- O/UNIX (Onix) Installer - Unix-подобная ОС для OpenComputers

local component = require("component")
local computer = require("computer")
local event = require("event")
local gpu = component.gpu
local filesystem = require("filesystem")
local serialization = require("serialization")

-- Конфигурация O/UNIX
local Onix = {
  name = "O/UNIX",
  version = "0.1",
  codename = "Onix",
  requirements = {
    minMemory = 256 * 1024,  -- 256KB
    minStorage = 1000000,    -- 1MB
  },
  structure = {
    "/bin",       -- Исполняемые файлы
    "/etc",       -- Конфигурация
    "/home",      -- Домашние директории
    "/tmp",       -- Временные файлы
    "/var",       -- Переменные данные
    "/usr",       -- Пользовательские программы
    "/usr/bin",   -- Дополнительные программы
    "/usr/lib",   -- Библиотеки
    "/dev",       -- Устройства
    "/proc",      -- Процессы
    "/mnt",       -- Точки монтирования
    "/root",      -- root пользователь
    "/boot",      -- Загрузчик
    "/sys"        -- Системные файлы
  }
}

-- Проверка совместимости
local function checkCompatibility()
  local issues = {}
  
  if computer.totalMemory() < Onix.requirements.minMemory then
    table.insert(issues, "❌ Недостаточно памяти: " .. 
      math.floor(computer.totalMemory()/1024) .. "KB/" .. 
      math.floor(Onix.requirements.minMemory/1024) .. "KB")
  end
  
  local mainFs = component.list("filesystem")()
  if mainFs then
    local disk = component.proxy(mainFs)
    if disk.spaceTotal() < Onix.requirements.minStorage then
      table.insert(issues, "❌ Недостаточно места: " .. 
        disk.spaceTotal() .. "/" .. Onix.requirements.minStorage)
    end
  else
    table.insert(issues, "❌ Не найден диск для установки")
  end
  
  return issues
end

-- Создание структуры файловой системы
local function createFilesystemStructure()
  print("📁 Создаем структуру O/UNIX...")
  
  for _, dir in ipairs(Onix.structure) do
    filesystem.makeDirectory(dir)
    print("   📁 " .. dir)
  end
end

-- Установка системных утилит (Unix-команды)
local function installSystemUtilities()
  print("🔧 Устанавливаем системные утилиты...")
  
  local utilities = {
    -- Системный загрузчик
    ["/boot/onix.boot"] = [[
-- O/UNIX Bootloader
print("Booting O/UNIX " .. _ONIX_VERSION .. "...")

-- Инициализация системы
dofile("/etc/init.lua")
]],

    -- Ядро системы
    ["/etc/init.lua"] = [[
-- O/UNIX Init System
_ONIX_VERSION = "]] .. Onix.version .. [["
_ONIX_CODENAME = "]] .. Onix.codename .. [["

-- Глобальные переменные системы
function os.setenv(name, value)
  _G["ENV_" .. name] = value
end

function os.getenv(name)
  return _G["ENV_" .. name]
end

function os.export(name, value)
  os.setenv(name, value)
end

-- Установка переменных по умолчанию
os.setenv("PATH", "/bin:/usr/bin")
os.setenv("HOME", "/home/user")
os.setenv("USER", "user")
os.setenv("SHELL", "/bin/osh")
os.setenv("PWD", "/")

-- Менеджер процессов
process = {
  running = {},
  next_pid = 1
}

function process.fork(fn)
  local pid = process.next_pid
  process.next_pid = process.next_pid + 1
  process.running[pid] = {
    func = fn,
    status = "running"
  }
  return pid
end

function process.kill(pid)
  if process.running[pid] then
    process.running[pid].status = "killed"
  end
end

-- Запуск оболочки
print("O/UNIX " .. _ONIX_VERSION .. " (" .. _ONIX_CODENAME .. ") ready")
dofile("/bin/osh")
]],

    -- Оболочка O/UNIX Shell (osh)
    ["/bin/osh"] = [[
-- O/UNIX Shell
local function parseCommand(line)
  local parts = {}
  for part in line:gmatch("%S+") do
    table.insert(parts, part)
  end
  return parts
end

local function executeCommand(cmd, args)
  local commandPath = "/bin/" .. cmd
  if filesystem.exists(commandPath) then
    local env = {
      args = args,
      PATH = os.getenv("PATH"),
      USER = os.getenv("USER"),
      HOME = os.getenv("HOME"),
      PWD = os.getenv("PWD")
    }
    
    local old_env = _G.ENV
    _G.ENV = env
    local success, result = pcall(dofile, commandPath)
    _G.ENV = old_env
    
    if not success then
      print("osh: " .. cmd .. ": " .. tostring(result))
    end
  else
    print("osh: " .. cmd .. ": command not found")
  end
end

local function showPrompt()
  local user = os.getenv("USER") or "user"
  local hostname = "onix"
  local cwd = os.getenv("PWD") or "/"
  
  io.write(user .. "@" .. hostname .. ":" .. cwd .. "$ ")
  return io.read()
end

-- Основной цикл оболочки
print("O/UNIX Shell " .. _ONIX_VERSION)
print('Type "help" for available commands')

while true do
  local line = showPrompt()
  if not line then break end
  
  line = line:match("^%s*(.-)%s*$") -- trim
  
  if line == "exit" then
    break
  elseif line ~= "" then
    local parts = parseCommand(line)
    local cmd = table.remove(parts, 1)
    executeCommand(cmd, parts)
  end
end
]],

    -- Команда ls
    ["/bin/ls"] = [[
-- ls - list directory contents
local args = _G.ENV.args or {}
local path = args[1] or _G.ENV.PWD or "."

if not filesystem.exists(path) then
  print("ls: cannot access '" .. path .. "': No such file or directory")
  return
end

local list = filesystem.list(path)
for item in list do
  local fullPath = filesystem.concat(path, item)
  if filesystem.isDirectory(fullPath) then
    print(item .. "/")
  else
    print(item)
  end
end
]],

    -- Команда pwd
    ["/bin/pwd"] = [[
-- pwd - print working directory
print(_G.ENV.PWD or "/")
]],

    -- Команда cd
    ["/bin/cd"] = [[
-- cd - change directory
local args = _G.ENV.args or {}
local path = args[1] or os.getenv("HOME") or "/"

if not filesystem.exists(path) then
  print("cd: " .. path .. ": No such file or directory")
  return
end

if not filesystem.isDirectory(path) then
  print("cd: " .. path .. ": Not a directory")
  return
end

os.setenv("PWD", path)
]],

    -- Команда cat
    ["/bin/cat"] = [[
-- cat - concatenate and print files
local args = _G.ENV.args or {}

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
      print("cat: " .. filename .. ": No such file or directory")
    end
  end
end
]],

    -- Команда echo
    ["/bin/echo"] = [[
-- echo - display a line of text
local args = _G.ENV.args or {}
print(table.concat(args, " "))
]],

    -- Команда mkdir
    ["/bin/mkdir"] = [[
-- mkdir - make directories
local args = _G.ENV.args or {}

for _, dirname in ipairs(args) do
  if filesystem.exists(dirname) then
    print("mkdir: cannot create directory '" .. dirname .. "': File exists")
  else
    local success = pcall(filesystem.makeDirectory, dirname)
    if not success then
      print("mkdir: cannot create directory '" .. dirname .. "'")
    end
  end
end
]],

    -- Команда rm
    ["/bin/rm"] = [[
-- rm - remove files or directories
local args = _G.ENV.args or {}

for _, filename in ipairs(args) do
  if filesystem.exists(filename) then
    if filesystem.isDirectory(filename) then
      -- Рекурсивное удаление для директорий
      local list = filesystem.list(filename)
      for item in list do
        local fullPath = filesystem.concat(filename, item)
        _G.ENV.args = {fullPath}
        dofile("/bin/rm")
      end
    end
    filesystem.remove(filename)
  else
    print("rm: cannot remove '" .. filename .. "': No such file or directory")
  end
end
]],

    -- Команда cp
    ["/bin/cp"] = [[
-- cp - copy files
local args = _G.ENV.args or {}

if #args < 2 then
  print("cp: missing file operands")
  return
end

local sources = {}
local target = args[#args]

for i = 1, #args - 1 do
  table.insert(sources, args[i])
end

for _, source in ipairs(sources) do
  if not filesystem.exists(source) then
    print("cp: cannot stat '" .. source .. "': No such file or directory")
    return
  end
  
  local targetPath = target
  if filesystem.isDirectory(target) then
    targetPath = filesystem.concat(target, source:match("([^/]+)$"))
  end
  
  if filesystem.exists(targetPath) then
    print("cp: cannot create '" .. targetPath .. "': File exists")
    return
  end
  
  local sourceFile = io.open(source, "r")
  local targetFile = io.open(targetPath, "w")
  
  if sourceFile and targetFile then
    local content = sourceFile:read("*a")
    targetFile:write(content)
    sourceFile:close()
    targetFile:close()
  else
    print("cp: error copying '" .. source .. "' to '" .. targetPath .. "'")
  end
end
]],

    -- Команда mv
    ["/bin/mv"] = [[
-- mv - move files
local args = _G.ENV.args or {}

if #args < 2 then
  print("mv: missing file operands")
  return
end

local sources = {}
local target = args[#args]

for i = 1, #args - 1 do
  table.insert(sources, args[i])
end

for _, source in ipairs(sources) do
  if not filesystem.exists(source) then
    print("mv: cannot stat '" .. source .. "': No such file or directory")
    return
  end
  
  local targetPath = target
  if filesystem.isDirectory(target) then
    targetPath = filesystem.concat(target, source:match("([^/]+)$"))
  end
  
  if filesystem.exists(targetPath) then
    filesystem.remove(targetPath)
  end
  
  filesystem.rename(source, targetPath)
end
]],

    -- Команда ps
    ["/bin/ps"] = [[
-- ps - report process status
print("PID\tSTATUS")
for pid, proc in pairs(process.running) do
  print(pid .. "\t" .. proc.status)
end
]],

    -- Команда kill
    ["/bin/kill"] = [[
-- kill - terminate processes
local args = _G.ENV.args or {}

if #args == 0 then
  print("kill: usage: kill <pid>")
  return
end

for _, pid_str in ipairs(args) do
  local pid = tonumber(pid_str)
  if pid and process.running[pid] then
    process.kill(pid)
    print("Killed process " .. pid)
  else
    print("kill: (" .. pid_str .. ") - No such process")
  end
end
]],

    -- Команда whoami
    ["/bin/whoami"] = [[
-- whoami - print effective userid
print(os.getenv("USER") or "user")
]],

    -- Команда date
    ["/bin/date"] = [[
-- date - print or set the system date and time
print(os.date("%c"))
]],

    -- Команда uname
    ["/bin/uname"] = [[
-- uname - print system information
local args = _G.ENV.args or {}

if #args > 0 and args[1] == "-a" then
  print("O/UNIX " .. _ONIX_VERSION .. " " .. _ONIX_CODENAME .. " OpenComputers")
else
  print("O/UNIX")
end
]],

    -- Команда help
    ["/bin/help"] = [[
-- help - display available commands
print("O/UNIX " .. _ONIX_VERSION .. " Available Commands:")
print("ls          - List directory contents")
print("cd          - Change directory")
print("pwd         - Print working directory")
print("cat         - Concatenate and print files")
print("echo        - Display a line of text")
print("mkdir       - Make directories")
print("rm          - Remove files or directories")
print("cp          - Copy files")
print("mv          - Move files")
print("ps          - Report process status")
print("kill        - Terminate processes")
print("whoami      - Print effective userid")
print("date        - Print system date and time")
print("uname       - Print system information")
print("clear       - Clear the terminal screen")
print("exit        - Exit the shell")
print("help        - Display this help")
]],

    -- Команда clear
    ["/bin/clear"] = [[
-- clear - clear the terminal screen
local gpu = component.gpu
if gpu then
  local w, h = gpu.getResolution()
  gpu.fill(1, 1, w, h, " ")
  gpu.set(1, 1, "")
end
]]
  }
  
  for path, content in pairs(utilities) do
    local file = io.open(path, "w")
    if file then
      file:write(content)
      file:close()
      print("   ✅ " .. path)
    else
      print("   ❌ " .. path)
    end
  end
end

-- Создание конфигурационных файлов
local function createConfigFiles()
  print("⚙️  Создаем конфигурационные файлы...")
  
  local configs = {
    ["/etc/motd"] = [[
Welcome to O/UNIX ]] .. Onix.version .. [[ (]] .. Onix.codename .. [[)
A Unix-like operating system for OpenComputers
]],

    ["/etc/passwd"] = [[
root:x:0:0:Root user:/root:/bin/osh
user:x:1000:1000:Default user:/home/user:/bin/osh
]],

    ["/etc/hostname"] = [[
onix
]],

    ["/home/user/.profile"] = [[
echo "Welcome to O/UNIX, $USER!"
]]
  }
  
  for path, content in pairs(configs) do
    local file = io.open(path, "w")
    if file then
      file:write(content)
      file:close()
      print("   ⚙️  " .. path)
    end
  end
end

-- Установка загрузчика
local function installBootloader()
  print("🚀 Устанавливаем загрузчик...")
  
  local bootloader = [[
-- O/UNIX Bootloader
local computer = require("computer")
local filesystem = require("filesystem")

print("Booting O/UNIX ]] .. Onix.version .. [[...")

-- Проверка файловой системы
if not filesystem.exists("/etc/init.lua") then
  print("ERROR: System files not found")
  computer.beep(200, 1)
  return
end

-- Загрузка ядра
local success, err = pcall(dofile, "/etc/init.lua")
if not success then
  print("Boot failed: " .. tostring(err))
  computer.beep(200, 1)
  return
end

print("O/UNIX started successfully")
]]
  
  local bootFile = io.open("/boot.lua", "w")
  if bootFile then
    bootFile:write(bootloader)
    bootFile:close()
    print("   ✅ Загрузчик установлен")
  end
end

-- Основной процесс установки
local function performInstallation()
  print("\n🎯 Начинаем установку O/UNIX...")
  print("========================================")
  
  local issues = checkCompatibility()
  if #issues > 0 then
    print("❌ Проблемы с совместимостью:")
    for _, issue in ipairs(issues) do
      print("   " .. issue)
    end
    return false
  end
  
  print("✅ Система совместима!")
  
  createFilesystemStructure()
  installSystemUtilities()
  createConfigFiles()
  installBootloader()
  
  print("\n🎉 Установка O/UNIX завершена!")
  print("========================================")
  print("O/UNIX " .. Onix.version .. " (" .. Onix.codename .. ")")
  print("")
  print("Доступные команды:")
  print("  ls, cd, pwd, cat, echo, mkdir, rm")
  print("  cp, mv, ps, kill, whoami, date, uname")
  print("  clear, help, exit")
  print("")
  print("Перезагрузите компьютер для запуска O/UNIX")
  print("Используйте 'help' для списка команд")
  
  computer.beep(1000, 0.2)
  computer.beep(1200, 0.2)
  
  return true
end

-- Текстовый установщик
local function showTextInstaller()
  print("O/UNIX (Onix) Installer v" .. Onix.version)
  print("========================================")
  print("Unix-like OS for OpenComputers")
  print("")
  print("Это установит O/UNIX на ваш компьютер.")
  print("Все существующие данные будут удалены!")
  print("")
  print("Продолжить? (y/n)")
  
  local answer = io.read()
  if answer:lower() == "y" or answer:lower() == "yes" then
    performInstallation()
  else
    print("❌ Установка отменена")
  end
end

-- Запуск установщика
showTextInstaller()
