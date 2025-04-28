local kConfigFileName = "UnrealNvim.json"
local kCurrentVersion = "0.0.2"

local kLogLevel_Error = 1
local kLogLevel_Warning = 2
local kLogLevel_Log = 3
local kLogLevel_Verbose = 4
local kLogLevel_VeryVerbose = 5

local OS = jit.os
local ARCH = jit.arch

local TaskState =
{
    scheduled = "scheduled",
    inprogress = "inprogress",
    completed = "completed"
}

-- fix false diagnostic about vim
if not vim then
    vim = {}
end

local logFilePath = vim.fn.stdpath("data") .. '/unrealnvim.log'

local function logWithVerbosity(verbosity, message)
    if not vim.g.unrealnvim_debug then return end
    local cfgVerbosity = kLogLevel_Log
    if vim.g.unrealnvim_loglevel then
        cfgVerbosity = vim.g.unrealnvim_loglevel
    end
    if verbosity > cfgVerbosity then return end

    local file = nil
    if Commands.logFile then
        file = Commands.logFile
    else
        file = io.open(logFilePath, "a")
    end

    if file then
        local time = os.date('%m/%d/%y %H:%M:%S');
        file:write("[" .. time .. "][" .. verbosity .. "]: " .. message .. '\n')
    end
end

local function log(message)
    if not message then
        logWithVerbosity(kLogLevel_Error, "message was nill")
        return
    end

    logWithVerbosity(kLogLevel_Log, message)
end

local function logError(message)
    logWithVerbosity(kLogLevel_Error, message)
end

local function PrintAndLogMessage(a, b)
    if a and b then
        log(tostring(a) .. tostring(b))
    elseif a then
        log(tostring(a))
    end
end

local function PrintAndLogError(a, b)
    if a and b then
        local msg = "Error: " .. tostring(a) .. tostring(b)
        print(msg)
        log(msg)
    elseif a then
        local msg = "Error: " .. tostring(a)
        print(msg)
        log(msg)
    end
end

local function MakeUnixPath(win_path)
    if not win_path then
        logError("MakeUnixPath received a nil argument")
        return;
    end
    -- Convert backslashes to forward slashes
    local unix_path = win_path:gsub("\\", "/")

    -- Remove duplicate slashes
    unix_path = unix_path:gsub("//+", "/")

    return unix_path
end

local function FuncBind(func, data)
    return function()
        func(data)
    end
end

if not vim.g.unrealnvim_loaded then
    Commands = {}

    CurrentGenData =
    {
        config = {},
        target = nil,
        prjName = nil,
        targetNameSuffix = nil,
        prjDir = nil,
        tasks = {},
        currentTask = "",
        ubtPath = "",
        ueBuildBat = "",
        projectPath = "",
        logFile = nil
    }
    -- clear the log
    CurrentGenData.logFile = io.open(logFilePath, "w")

    if CurrentGenData.logFile then
        CurrentGenData.logFile:write("")
        CurrentGenData.logFile:close()

        CurrentGenData.logFile = io.open(logFilePath, "a")
    end
    vim.g.unrealnvim_loaded = true
end

Commands.LogLevel_Error = kLogLevel_Error
Commands.LogLevel_Warning = kLogLevel_Warning
Commands.LogLevel_Log = kLogLevel_Log
Commands.LogLevel_Verbose = kLogLevel_Verbose
Commands.LogLevel_VeryVerbose = kLogLevel_VeryVerbose

function Commands.Log(msg)
    PrintAndLogError(msg)
end

Commands.onStatusUpdate = function()
end

function Commands:Inspect(objToInspect)
    if not vim.g.unrealnvim_debug then return end
    if not objToInspect then
        log(objToInspect)
        return
    end

    if not self._inspect then
        local inspect_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/inspect.lua/inspect.lua"
        self._inspect = loadfile(inspect_path)(Commands._inspect)
        if self._inspect then
            log("Inspect loaded.")
        else
            logError("Inspect failed to load from path" .. inspect_path)
        end
        if self._inspect.inspect then
            log("inspect method exists")
        else
            logError("inspect method doesn't exist")
        end
    end
    return self._inspect.inspect(objToInspect)
end

function SplitString(str)
    -- Split a string into lines
    local lines = {}
    for line in string.gmatch(str, "[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

function GetConfigPlatform()
    local os
    if OS == 'Windows' then
        os = 'Win'
    elseif OS == 'OSX' then
        return 'Mac'
    elseif OS == 'Linux' then
        return 'Linux'
    end

    local arch
    if ARCH == 'x86' or ARCH == 'x64' then
        arch = '64'
    elseif ARCH == 'arm' or ARCH == 'arm64' then
        arch = 'Arm64'
    end

    return os .. arch
end

function Commands._CreateConfigFile(configFilePath, projectName)
    local platform = GetConfigPlatform()
    local configContents = [[
{
    "version" : "0.0.2",
    "_comment": "do not forget to escape backslashes in EnginePath",
    "EngineDir": "",
    "Targets":  [

        {
            "TargetName" : "]] .. projectName .. [[-Editor",
            "Configuration" : "DebugGame",
            "withEditor" : true,
            "UbtExtraFlags" : "",
            "PlatformName" : "]] .. platform .. [["
        },
        {
            "TargetName" : "]] .. projectName .. [[",
            "Configuration" : "DebugGame",
            "withEditor" : false,
            "UbtExtraFlags" : "",
            "PlatformName" : "]] .. platform .. [["
        },
        {
            "TargetName" : "]] .. projectName .. [[-Editor",
            "Configuration" : "Development",
            "withEditor" : true,
            "UbtExtraFlags" : "",
            "PlatformName" : "]] .. platform .. [["
        },
        {
            "TargetName" : "]] .. projectName .. [[",
            "Configuration" : "Development",
            "withEditor" : false,
            "UbtExtraFlags" : "",
            "PlatformName" : "]] .. platform .. [["
        },
        {
            "TargetName" : "]] .. projectName .. [[-Editor",
            "Configuration" : "Shipping",
            "withEditor" : true,
            "UbtExtraFlags" : "",
            "PlatformName" : "]] .. platform .. [["
        },
        {
            "TargetName" : "]] .. projectName .. [[",
            "Configuration" : "Shipping",
            "withEditor" : false,
            "UbtExtraFlags" : "",
            "PlatformName" : "]] .. platform .. [["
        }
    ]
}
    ]]
    -- local file = io.open(configFilePath, "w")
    -- file:write(configContents)
    -- file:close()
    PrintAndLogMessage(
        "Please populate the configuration for the Unreal project, especially EnginePath, the path to the Unreal Engine")
    -- local buf = vim.api.nvim_create_buf(false, true)
    vim.cmd('new ' .. configFilePath)
    vim.cmd('setlocal buftype=')
    -- vim.api.nvim_buf_set_name(0, configFilePath)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, SplitString(configContents))
    -- vim.api.nvim_open_win(buf, true, {relative="win", height=20, width=80, row=1, col=0})
end

function Commands._EnsureConfigFile(projectRootDir, projectName)
    local configFilePath = projectRootDir .. "/" .. kConfigFileName
    local configFile = io.open(configFilePath, "r")


    if (not configFile) then
        Commands._CreateConfigFile(configFilePath, projectName)
        PrintAndLogMessage("created config file")
        return nil
    end

    local content = configFile:read("*all")
    configFile:close()

    local data = vim.fn.json_decode(content)
    Commands:Inspect(data)
    if data and (data.version ~= kCurrentVersion) then
        PrintAndLogError("Your " ..
            configFilePath ..
            " format is incompatible. Please back up this file somewhere and then delete this one, you will be asked to create a new one")
        data = nil
    end

    if data then
        data.EngineDir = MakeUnixPath(data.EngineDir)
    end

    return data
end

function Commands._GetDefaultProjectNameAndDir(filepath)
    local uprojectPath, projectDir
    projectDir, uprojectPath = Commands._find_file_with_extension(filepath, "uproject")
    if not uprojectPath then
        PrintAndLogMessage(
            "Failed to determine project name, could not find the root of the project that contains the .uproject")
        return nil, nil
    end
    local projectName = vim.fn.fnamemodify(uprojectPath, ":t:r")
    return projectName, projectDir
end

local CurrentCompileCommandsTargetFilePath = ""
function CurrentGenData:GetTaskAndStatus()
    if not self or not self.currentTask or self.currentTask == "" then
        return "[No Task]"
    end
    local status = self:GetTaskStatus(self.currentTask)
    return self.currentTask .. "->" .. status
end

function CurrentGenData:GetTaskStatus(taskName)
    local status = self.tasks[taskName]

    if not status then
        status = "none"
    end
    return status
end

function CurrentGenData:SetTaskStatus(taskName, newStatus)
    if (self.currentTask ~= "" and self.currentTask ~= taskName) and (self:GetTaskStatus(self.currentTask) ~= TaskState.completed) then
        PrintAndLogMessage("Cannot start a new task. Current task still in progress " .. self.currentTask)
        PrintAndLogError("Cannot start a new task. Current task still in progress " .. self.currentTask)
        return
    end
    PrintAndLogMessage("SetTaskStatus: " .. taskName .. "->" .. newStatus)
    self.currentTask = taskName
    self.tasks[taskName] = newStatus
end

function CurrentGenData:ClearTasks()
    self.tasks = {}
    self.currentTask = ""
end

function ExtractRSP(rsppath)
    local extraFlags =
    "-std=c++20 -Wno-deprecated-enum-enum-conversion -Wno-deprecated-anon-enum-enum-conversion -ferror-limit=0 -Wno-inconsistent-missing-override"
    local extraIncludes = {
        "Engine/Source/Runtime/CoreUObject/Public/UObject/ObjectMacros.h",
        "Engine/Source/Runtime/Core/Public/Misc/EnumRange.h"
    }

    rsppath = rsppath:gsub("\\\\", "/")
    PrintAndLogMessage(rsppath)

    local lines = {}
    local isFirstLine = true
    local lineNb = 0;
    for line in io.lines(rsppath) do
        local discardLine = true

        -- ignored lines
        if line:find("^/FI") then discardLine = false end
        if line:find("^/I") then discardLine = false end
        if line:find("^-W") then discardLine = false end

        line = line:gsub("^/FI", "-include ")
        line = line:gsub("^(/I )(.*)", "-I \"%2\"")

        if isFirstLine then
            discardLine = false
        end

        if not discardLine then
            lines[lineNb] = line .. "\n"
            lineNb = lineNb + 1
        end

        isFirstLine = false
    end

    for _, incl in ipairs(extraIncludes) do
        lines[lineNb] = "\n" .. "-include \"" .. CurrentGenData.config.EngineDir .. "/" .. incl .. "\""
        lineNb = lineNb + 1
    end
    lines[lineNb] = "\n" .. extraFlags
    lineNb = lineNb + 1
    --table.insert(lines, "\n\"" .. currentFilename .. "\"")
    return table.concat(lines)
end

function EscapePath(path)
    -- path = path:gsub("\\", "\\\\")
    path = path:gsub("\\\\", "/")
    path = path:gsub("\\", "/")
    path = path:gsub("\"", "\\\"")
    return path
end

function EnsureDirPath(path)
    PrintAndLogMessage("Ensuring path exists: " .. path)
    if vim.fn.isdirectory(path) == 0 then
        vim.fn.mkdir(path, "p")
    end
end

local function IsEngineFile(path, start)
    local unixPath = MakeUnixPath(path)
    local unixStart = MakeUnixPath(start)
    local startIndex, _ = string.find(unixPath, unixStart, 1, true)
    return startIndex ~= nil
end

local function IsQuickfixWin(winid)
    if not vim.api.nvim_win_is_valid(winid) then return false end
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

    return buftype == 'quickfix'
end

local function GetQuickfixWinId()
    local quickfix_winid = nil

    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if IsQuickfixWin(winid) then
            quickfix_winid = winid
            break
        end
    end
    return quickfix_winid
end

Commands.QuickfixWinId = 0

local function ScrollQF()
    if not IsQuickfixWin(Commands.QuickfixWinId) then
        Commands.QuickfixWinId = GetQuickfixWinId()
    end

    local qf_list = vim.fn.getqflist()
    local last_line = #qf_list
    if last_line > 0 then
        vim.api.nvim_win_set_cursor(Commands.QuickfixWinId, { last_line, 0 })
    end
end

local function AppendToQF(entry)
    vim.fn.setqflist({}, 'a', { items = { entry } })
    ScrollQF()
end

local function DeleteAutocmd(AutocmdId)
    local success, _ = pcall(function()
        vim.api.nvim_del_autocmd(AutocmdId)
    end)
end

function Stage_UbtGenCmd()
    coroutine.yield()
    Commands.BeginTask("gencmd")
    PrintAndLogMessage("callback called!")
    local outputJsonPath = CurrentGenData.config.EngineDir .. "/compile_commands.json"

    local rspdir = CurrentGenData.prjDir .. "/Intermediate/clangRsp/" ..
        CurrentGenData.target.PlatformName .. "/" ..
        CurrentGenData.target.Configuration .. "/"

    -- all these replaces are slow, could be rewritten as a parser
    EnsureDirPath(rspdir)

    -- replace bad compiler
    local file_path = outputJsonPath

    local contentLines = {}
    PrintAndLogMessage("processing compile_commands.json and writing response files")
    PrintAndLogMessage(file_path)

    local skipEngineFiles = true
    if CurrentGenData.WithEngine then
        skipEngineFiles = false
    end

    local qflistentry = { text = "Preparing files for parsing." }
    if not skipEngineFiles then
        qflistentry.text = qflistentry.text .. " Engine source files included, process will take longer"
    end
    AppendToQF(qflistentry)

    local currentFilename = ""
    for line in io.lines(file_path) do
        local i, j = line:find("\"command")
        if i then
            coroutine.yield()

            -- show progress
            logWithVerbosity(kLogLevel_Verbose, "Preparing for LSP symbol parsing: " .. currentFilename)
            local isEngineFile = IsEngineFile(currentFilename, CurrentGenData.config.EngineDir)
            local shouldSkipFile = isEngineFile and skipEngineFiles

            local qflistentry = {
                filename = "",
                lnum = 0,
                col = 0,
                text = currentFilename
            }
            if not shouldSkipFile then
                AppendToQF(qflistentry)
            end

            if OS == 'Windows' then
                local old_text = "Llvm\\\\x64\\\\bin\\\\clang%-cl%.exe"
                local new_text = "Llvm/x64/bin/clang++.exe"
                line = line:gsub(old_text, new_text)
            end

            -- content = content .. "matched:\n"
            i, j = line:find("%@")

            if i then
                -- The file name might have an optional \" around to shell escape the file name in the command.
                local backslashValue = string.byte("\\", 1)
                if string.byte(line, j + 1) == backslashValue then
                    j = j + 2 -- \ and "
                end

                local _, endpos = line:find("\"", j + 1)

                -- same thing here
                if string.byte(line, endpos - 1) == backslashValue then
                    endpos = endpos - 1
                end

                local rsppath = line:sub(j + 1, endpos - 1)
                if rsppath then
                    local newrsppath = rsppath .. ".clang.rsp"

                    -- rewrite rsp contents
                    if not shouldSkipFile then
                        local rspfile = io.open(newrsppath, "w")
                        local rspcontent = ExtractRSP(rsppath)
                        rspfile:write(rspcontent)
                        rspfile:close()
                    end
                    coroutine.yield()

                    if OS == 'Windows' then
                        table.insert(contentLines, "\t\t\"command\": \"clang++.exe @\\\"" .. newrsppath .. "\\\"\",\n")
                    else
                        table.insert(contentLines, "\t\t\"command\": \"clang++ \\\"" .. newrsppath .. "\\\"\",\n")
                    end
                end
            else
                -- it's not an rsp command, the flags will be clang compatible
                -- for some reason they're only incompatible flags inside
                -- rsps. keep line as is
                local _, endArgsPos = line:find("%.exe\\\"")
                local args = line:sub(endArgsPos + 1, -1)
                local rspfilename = currentFilename:gsub("\\\\", "/")
                rspfilename = rspfilename:gsub(":", "")
                rspfilename = rspfilename:gsub("\"", "")
                rspfilename = rspfilename:gsub(",", "")
                rspfilename = rspfilename:gsub("\\", "/")
                rspfilename = rspfilename:gsub("/", "_")
                rspfilename = rspfilename .. ".rsp"
                local rspfilepath = rspdir .. rspfilename

                if not shouldSkipFile then
                    PrintAndLogMessage("Writing rsp: " .. rspfilepath)

                    args = args:gsub("-D\\\"", "-D\"")
                    args = args:gsub("-I\\\"", "-I\"")
                    args = args:gsub("\\\"\\\"\\\"", "__3Q_PLACEHOLDER__")
                    args = args:gsub("\\\"\\\"", "\\\"\"")
                    args = args:gsub("\\\" ", "\" ")
                    args = args:gsub("\\\\", "/")
                    args = args:gsub(",%s*$", "")   -- remove trailing comma and spaces
                    args = args:gsub("\" ", "\"\n") -- one arg per line

                    args = args:gsub("__3Q_PLACEHOLDER__", "\\\"\\\"\"")

                    args = args:gsub("\n[^\n]*$", "")
                    local rspfile = io.open(rspfilepath, "w")
                    rspfile:write(args)
                    rspfile:close()
                end
                coroutine.yield()

                if OS == 'Windows' then
                    table.insert(contentLines,
                        "\t\t\"command\": \"clang++.exe @\\\"" .. EscapePath(rspfilepath) .. "\\\""
                        .. " " .. EscapePath(currentFilename) .. "\",\n")
                else
                    table.insert(contentLines,
                        "\t\t\"command\": \"clang++ \\\"" .. EscapePath(rspfilepath) .. "\\\""
                        .. " " .. EscapePath(currentFilename) .. "\",\n")
                end
            end
        else
            local fbegin, fend = line:find("\"file\": ")
            if fbegin then
                currentFilename = line:sub(fend + 1, -2)
                logWithVerbosity(kLogLevel_Verbose, "currentfile: " .. currentFilename)
            end
            table.insert(contentLines, line .. "\n")
        end
        ::continue::
    end


    local file = io.open(CurrentCompileCommandsTargetFilePath, "w")
    file:write(table.concat(contentLines))
    file:flush()
    file:close()

    PrintAndLogMessage("finished processing compile_commands.json")
    PrintAndLogMessage("generating header files with Unreal Header Tool...")
    Commands.EndTask("gencmd")
    DeleteAutocmd(Commands.gencmdAutocmdid)

    Commands.ScheduleTask("headers")
    Commands.BeginTask("headers")
    Commands.headersAutocmdid = vim.api.nvim_create_autocmd("ShellCmdPost", {
        pattern = "*",
        callback = FuncBind(DispatchUnrealnvimCb, "headers")
    })

    local cmd = CurrentGenData.ubtPath .. " -project=" ..
        CurrentGenData.projectPath .. " " .. CurrentGenData.target.UbtExtraFlags .. " " ..
        CurrentGenData.prjName .. CurrentGenData.targetNameSuffix .. " " .. CurrentGenData.target.Configuration .. " " ..
        CurrentGenData.target.PlatformName .. " -headers"

    if OS == 'Windows' then
        vim.cmd("compiler msvc")
    end
    vim.cmd("Dispatch " .. cmd)
end

function Stage_GenHeadersCompleted()
    PrintAndLogMessage("Finished generating header files with Unreal Header Tool...")
    vim.api.nvim_command('autocmd! ShellCmdPost * lua DispatchUnrealnvimCb()')
    vim.api.nvim_command('LspRestart')
    Commands.EndTask("headers")
    Commands.EndTask("final")
    Commands:SetCurrentAnimation("kirbyIdle")
    DeleteAutocmd(Commands.headersAutocmdid)
end

Commands.renderedAnim = ""

function Commands.GetStatusBar()
    local status = "unset"
    if CurrentGenData:GetTaskStatus("final") == TaskState.completed then
        status = Commands.renderedAnim .. " Build completed!"
    elseif CurrentGenData.currentTask ~= "" then
        status = Commands.renderedAnim ..
            " Building... Step: " ..
            CurrentGenData.currentTask .. "->" .. CurrentGenData:GetTaskStatus(CurrentGenData.currentTask)
    else
        status = Commands.renderedAnim .. " Idle"
    end
    return status
end

function DispatchUnrealnvimCb(data)
    log("DispatchUnrealnvimCb()")
    Commands.taskCoroutine = coroutine.create(FuncBind(DispatchCallbackCoroutine, data))
end

function DispatchCallbackCoroutine(data)
    coroutine.yield()
    if not data then
        log("data was nil")
    end
    PrintAndLogMessage("DispatchCallbackCoroutine()")
    PrintAndLogMessage("DispatchCallbackCoroutine() task=" .. CurrentGenData:GetTaskAndStatus())
    if data == "gencmd" and CurrentGenData:GetTaskStatus("gencmd") == TaskState.scheduled then
        CurrentGenData:SetTaskStatus("gencmd", TaskState.inprogress)
        Commands.taskCoroutine = coroutine.create(Stage_UbtGenCmd)
    elseif data == "headers" and CurrentGenData:GetTaskStatus("headers") == TaskState.inprogress then
        Commands.taskCoroutine = coroutine.create(Stage_GenHeadersCompleted)
    end
end

function PromptBuildTargetIndex()
    print("target to build:")
    for i, x in ipairs(CurrentGenData.config.Targets) do
        local configName = x.Configuration
        if x.withEditor then
            configName = configName .. "-Editor"
        end
        print(tostring(i) .. ". " .. configName)
    end
    return tonumber(vim.fn.input "<number> : ")
end

function Commands.GetProjectName()
    local current_file_path = vim.api.nvim_buf_get_name(0)
    local prjName, _ = Commands._GetDefaultProjectNameAndDir(current_file_path)
    if not prjName then
        return "" --"<Unknown.uproject>"
    end

    return CurrentGenData.prjName .. ".uproject"
end

function InitializeCurrentGenData()
    PrintAndLogMessage("initializing")
    local current_file_path = vim.api.nvim_buf_get_name(0)
    CurrentGenData.prjName, CurrentGenData.prjDir = Commands._GetDefaultProjectNameAndDir(current_file_path)
    if not CurrentGenData.prjName then
        PrintAndLogMessage("could not find project. aborting")
        return false
    end

    CurrentGenData.config = Commands._EnsureConfigFile(CurrentGenData.prjDir,
        CurrentGenData.prjName)

    if not CurrentGenData.config then
        PrintAndLogMessage("no config file. aborting")
        return false
    end

    if OS == 'Windows' then
        CurrentGenData.ubtPath = "\"" ..
            CurrentGenData.config.EngineDir .. "/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.exe\""
        CurrentGenData.ueBuildBat = "\"" .. CurrentGenData.config.EngineDir .. "/Engine/Build/BatchFiles/Build.bat\""
    else
        CurrentGenData.ubtPath = "\"" ..
            CurrentGenData.config.EngineDir .. "/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool\""

        if OS == 'Linux' then
            CurrentGenData.ueBuildBat = "\"" ..
                CurrentGenData.config.EngineDir .. "/Engine/Build/BatchFiles/Linux/Setup.sh\""
        end

        if OS == 'OSX' then
            CurrentGenData.ueBuildBat = "\"" ..
                CurrentGenData.config.EngineDir .. "/Engine/Build/BatchFiles/Mac/Setup.sh\""
        end
    end
    CurrentGenData.projectPath = "\"" .. CurrentGenData.prjDir .. "/" ..
        CurrentGenData.prjName .. ".uproject\""

    local desiredTargetIndex = PromptBuildTargetIndex()
    CurrentGenData.target = CurrentGenData.config.Targets[desiredTargetIndex]

    CurrentGenData.targetNameSuffix = ""
    if CurrentGenData.target.withEditor then
        CurrentGenData.targetNameSuffix = "Editor"
    end

    PrintAndLogMessage("Using engine at:" .. CurrentGenData.config.EngineDir)

    return true
end

function Commands.ScheduleTask(taskName)
    PrintAndLogMessage("ScheduleTask: " .. taskName)
    CurrentGenData:SetTaskStatus(taskName, TaskState.scheduled)
end

function Commands.ClearTasks()
    CurrentGenData:ClearTasks()
end

function Commands.BeginTask(taskName)
    PrintAndLogMessage("BeginTask: " .. taskName)
    CurrentGenData:SetTaskStatus(taskName, TaskState.inprogress)
end

function Commands.EndTask(taskName)
    PrintAndLogMessage("EndTask: " .. taskName)
    CurrentGenData:SetTaskStatus(taskName, TaskState.completed)
    Commands.taskCoroutine = nil
end

function BuildComplete()
    Commands.EndTask("build")
    Commands.EndTask("final")
    Commands:SetCurrentAnimation("kirbyIdle")
    DeleteAutocmd(Commands.buildAutocmdid)
end

function Commands.BuildCoroutine()
    Commands.buildAutocmdid = vim.api.nvim_create_autocmd("ShellCmdPost",
        {
            pattern = "*",
            callback = BuildComplete
        })

    local cmd = CurrentGenData.ueBuildBat .. " " .. CurrentGenData.prjName ..
        CurrentGenData.targetNameSuffix .. " " ..
        CurrentGenData.target.PlatformName .. " " ..
        CurrentGenData.target.Configuration .. " " ..
        CurrentGenData.projectPath .. " -waitmutex"

    if OS == 'Windows' then
        vim.cmd("compiler msvc")
    end
    vim.cmd("Dispatch " .. cmd)
end

function Commands.build(opts)
    CurrentGenData:ClearTasks()
    PrintAndLogMessage("Building uproject")

    if not InitializeCurrentGenData() then
        return
    end
    Commands.EnsureUpdateStarted();

    Commands.ScheduleTask("build")
    Commands:SetCurrentAnimation("kirbyFlip")
    Commands.taskCoroutine = coroutine.create(Commands.BuildCoroutine)
end

function Commands.run(opts)
    CurrentGenData:ClearTasks()
    PrintAndLogMessage("Running uproject")

    if not InitializeCurrentGenData() then
        return
    end

    Commands.ScheduleTask("run")

    local cmd = ""

    if CurrentGenData.target.withEditor then
        local editorSuffix = ""
        if CurrentGenData.target.Configuration ~= "Development" then
            editorSuffix = "-" .. CurrentGenData.target.PlatformName .. "-" ..
                CurrentGenData.target.Configuration
        end

        local executablePath = "\"" .. CurrentGenData.config.EngineDir .. "/Engine/Binaries/" ..
            CurrentGenData.target.PlatformName .. "/UnrealEditor" .. editorSuffix .. ".exe\""

        cmd = executablePath .. " " ..
            CurrentGenData.projectPath .. " -skipcompile"
    else
        local exeSuffix = ""
        if CurrentGenData.target.Configuration ~= "Development" then
            exeSuffix = "-" .. CurrentGenData.target.PlatformName .. "-" ..
                CurrentGenData.target.Configuration
        end

        local executablePath = "\"" .. CurrentGenData.prjDir .. "/Binaries/" ..
            CurrentGenData.target.PlatformName .. "/" .. CurrentGenData.prjName .. exeSuffix .. ".exe\""

        cmd = executablePath
    end

    PrintAndLogMessage(cmd)
    if OS == 'Windows' then
        vim.cmd("compiler msvc")
    end
    vim.cmd("Dispatch " .. cmd)
    Commands.EndTask("run")
    Commands.EndTask("final")
end

function Commands.EnsureUpdateStarted()
    if Commands.cbTimer then return end

    Commands.lastUpdateTime = vim.loop.now()
    Commands.updateTimer = 0

    -- UI update loop
    Commands.cbTimer = vim.loop.new_timer()
    Commands.cbTimer:start(1, 30, vim.schedule_wrap(Commands.safeUpdateLoop))

    -- coroutine update loop
    vim.schedule(Commands.safeLogicUpdate)
end

function Commands.generateCommands(opts)
    log(Commands.Inspect(opts))

    if not InitializeCurrentGenData() then
        PrintAndLogMessage("init failed")
        return
    end

    if opts.WithEngine then
        CurrentGenData.WithEngine = true
    end

    -- vim.api.nvim_command('autocmd ShellCmdPost * lua DispatchUnrealnvimCb()')
    Commands.gencmdAutocmdid = vim.api.nvim_create_autocmd("ShellCmdPost",
        {
            pattern = "*",
            callback = FuncBind(DispatchUnrealnvimCb, "gencmd")
        })

    PrintAndLogMessage("listening to ShellCmdPost")
    -- vim.cmd("compiler msvc")
    -- PrintAndLogMessage("compiler set to msvc")

    Commands.taskCoroutine = coroutine.create(Commands.generateCommandsCoroutine)
    Commands.EnsureUpdateStarted()
end

function Commands.updateLoop()
    local elapsedTime = vim.loop.now() - Commands.lastUpdateTime
    Commands:uiUpdate(elapsedTime)
    Commands.lastUpdateTime = vim.loop.now()
end

function Commands.safeUpdateLoop()
    local success, errmsg = pcall(Commands.updateLoop)
    if not success then
        vim.api.nvim_err_writeln("Error in update:" .. errmsg)
    end
end

local gtimer = 0
local resetCount = 0

function Commands:uiUpdate(delta)
    local animFrameCount = 4
    local animFrameDuration = 200
    local animDuration = animFrameCount * animFrameDuration

    local anim = {
        "▌",
        "▀",
        "▐",
        "▄"
    }
    local anim1 = {
        "1",
        "2",
        "3",
        "4"
    }
    if Commands.animData then
        anim = Commands.animData.frames
        animFrameDuration = Commands.animData.interval
        animFrameCount = #anim
        animDuration = animFrameCount * animFrameDuration
    end

    local index = 1 + (math.floor(math.fmod(vim.loop.now(), animDuration) / animFrameDuration))
    Commands.renderedAnim = (anim[index] or "")
end

function Commands.safeLogicUpdate()
    local success, errmsg = pcall(function() Commands:LogicUpdate() end)

    if not success then
        vim.api.nvim_err_writeln("Error in update:" .. errmsg)
    end
    vim.defer_fn(Commands.safeLogicUpdate, 1)
end

function Commands:LogicUpdate()
    if self.taskCoroutine then
        if coroutine.status(self.taskCoroutine) ~= "dead" then
            local ok, errmsg = coroutine.resume(self.taskCoroutine)
            if not ok then
                self.taskCoroutine = nil
                error(errmsg)
            end
        else
            self.taskCoroutine = nil
        end
    end
    vim.defer_fn(Commands.onStatusUpdate, 1)
end

local function GetInstallDir()
    local packer_install_dir = vim.fn.stdpath('data') .. '/site/pack/packer/start/'
    return packer_install_dir .. "Unreal.nvim//"
end

local mydbg = true
function Commands:SetCurrentAnimation(animationName)
    local jsonPath = GetInstallDir() .. "lua/spinners.json"
    local file = io.open(jsonPath, "r")
    if file then
        local content = file:read("*all")
        local json = vim.fn.json_decode(content)
        Commands.animData = json[animationName]
    end
end

function Commands.generateCommandsCoroutine()
    PrintAndLogMessage("Generating clang-compatible compile_commands.json")
    Commands:SetCurrentAnimation("kirbyFlip")
    coroutine.yield()
    Commands.ClearTasks()

    local editorFlag = ""
    if CurrentGenData.config.withEditor then
        PrintAndLogMessage("Building editor")
        editorFlag = "-Editor"
    end

    Commands.ScheduleTask("gencmd")
    -- local cmd = CurrentGenData.ubtPath .. " -mode=GenerateClangDatabase -StaticAnalyzer=Clang -project=" ..
    local cmd = CurrentGenData.ubtPath .. " -mode=GenerateClangDatabase -project=" ..
        CurrentGenData.projectPath .. " -game -engine " .. CurrentGenData.target.UbtExtraFlags .. " " ..
        editorFlag .. " " ..
        CurrentGenData.prjName .. CurrentGenData.targetNameSuffix .. " " .. CurrentGenData.target.Configuration .. " " ..
        CurrentGenData.target.PlatformName

    PrintAndLogMessage("Dispatching command:")
    PrintAndLogMessage(cmd)
    CurrentCompileCommandsTargetFilePath = CurrentGenData.prjDir .. "/compile_commands.json"
    vim.api.nvim_command("Dispatch " .. cmd)
    PrintAndLogMessage("Dispatched")
end

function Commands.SetUnrealCD()
    local current_file_path = vim.api.nvim_buf_get_name(0)
    local prjName, prjDir = Commands._GetDefaultProjectNameAndDir(current_file_path)
    if prjDir then
        vim.cmd("cd " .. prjDir)
    else
        PrintAndLogMessage(
            "Could not find unreal project root directory, make sure you have the correct buffer selected")
    end
end

function Commands._check_extension_in_directory(directory, extension)
    local dir = vim.loop.fs_opendir(directory)
    if not dir then
        return nil
    end

    handle = vim.loop.fs_scandir(directory)
    local name, typ

    while handle do
        name, typ = vim.loop.fs_scandir_next(handle)
        if not name then break end
        local ext = vim.fn.fnamemodify(name, ":e")
        if (ext == "uproject") then
            return directory .. "/" .. name
        end
    end
    return nil
end

function Commands._find_file_with_extension(filepath, extension)
    local current_dir = vim.fn.fnamemodify(filepath, ":p:h")
    local parent_dir = vim.fn.fnamemodify(current_dir, ":h")
    -- Check if the file exists in the current directory
    local filename = vim.fn.fnamemodify(filepath, ":t")

    local full_path = Commands._check_extension_in_directory(current_dir, extension)
    if full_path then
        return current_dir, full_path
    end

    -- Recursively check parent directories until we find the file or reach the root directory
    if current_dir ~= parent_dir then
        return Commands._find_file_with_extension(parent_dir .. "/" .. filename, extension)
    end

    -- File not found
    return nil
end

return Commands
