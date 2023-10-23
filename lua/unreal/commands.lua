
local kConfigFileName = "UnrealNvim.json"
local kCurrentVersion = "0.0.1"
local TaskState =
{
    scheduled = "scheduled",
    inprogress = "inprogress",
    completed = "completed"
}

-- fix diagnostic about vim
if not vim then
    vim = {}
end


local logFilePath = vim.fn.stdpath("data") .. '/unrealnvim.log'
local function log(message)
    if not vim.g.unrealnvim_debug then return end

    local file = io.open(logFilePath, "a+")
    if file then
        local time = os.date('%m/%d/%y %H:%M:%S');
        file:write(time .. ": " .. message .. '\n')
        file:flush()
        file:close()
    end
end

local function PrintAndLogMessage(a,b)
    if a and b then
        log(tostring(a)..tostring(b))
    elseif a then
        log(tostring(a))
    end
end

local function PrintAndLogError(a,b)
    if a and b then
        log("Error: "..tostring(a)..tostring(b))
    elseif a then
        log("Error: ".. tostring(a))
    end
end

local function FuncBind(func, data)
    log("binding")
    return function()
        log("calling bound with data "..data)
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
    }
    -- clear the log
    local logFile = io.open(logFilePath, "w")
    if logFile then
        logFile:write("")
        logFile:close()
    end
    vim.g.unrealnvim_loaded = true
end

function Commands.Log(msg)
    PrintAndLogError(msg)
end

Commands.onStatusUpdate = function()
end

local function doInspect(objToInspect)
    if not vim.g.unrealnvim_debug then return end

    if not Commands.inspect then
        local inspect_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/inspect.lua/inspect.lua"
        Commands.inspect = loadfile(inspect_path)(Commands.inspect)
    end

    Commands.inspect.inspect(objToInspect)
end

function SplitString(str)
    -- Split a string into lines
    local lines = {}
    for line in string.gmatch(str, "[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

function Commands._CreateConfigFile(configFilePath, projectName)
    local configContents = [[
{
    "version" : "0.0.1",
    "_comment": "dont forget to escape backslashes in EnginePath",    
    "EngineDir": "",
    "Targets":  [
        {
            "TargetName" : "]] .. projectName .. [[-Editor",
            "Configuration" : "Development",
            "withEditor" : true,
            "UbtExtraFlags" : "",
            "PlatformName" : "Win64"
        },
        {
            "TargetName" : "]] .. projectName .. [[",
            "Configuration" : "Development",
            "withEditor" : false,
            "UbtExtraFlags" : "",
            "PlatformName" : "Win64"
        }
    ]
}
    ]]
    -- local file = io.open(configFilePath, "w")
    -- file:write(configContents)
    -- file:close()
    PrintAndLogMessage("Please populate the configuration for the Unreal project, especially EnginePath, the path to the Unreal Engine")
    -- local buf = vim.api.nvim_create_buf(false, true)
    vim.cmd('new ' .. configFilePath)
    vim.cmd('setlocal buftype=')
    -- vim.api.nvim_buf_set_name(0, configFilePath)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, SplitString(configContents))
    -- vim.api.nvim_open_win(buf, true, {relative="win", height=20, width=80, row=1, col=0})
end

function Commands._EnsureConfigFile(projectRootDir, projectName)
    local configFilePath = projectRootDir.."/".. kConfigFileName
    local configFile = io.open(configFilePath, "r")
  

    if (not configFile) then
        Commands._CreateConfigFile(configFilePath, projectName)
        PrintAndLogMessage("created config file")
        return nil
    end

    local content = configFile:read("*all")
    configFile:close()

    local data = vim.fn.json_decode(content)
    doInspect(data)
    if data and (data.version ~= kCurrentVersion) then
        PrintAndLogError("Your " .. configFilePath .. " format is incompatible. Please back up this file somewhere and then delete this one, you will be asked to create a new one") 
        data = nil
    end
    return data;
end

function Commands._GetDefaultProjectNameAndDir(filepath)
    local uprojectPath, projectDir
    projectDir, uprojectPath = Commands._find_file_with_extension(filepath, "uproject")
    if not uprojectPath then
        PrintAndLogMessage("Failed to determine project name, could not find the root of the project that contains the .uproject")
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
    return self.currentTask.."->".. status
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
    local extraFlags = "-std=c++20 -Wno-deprecated-enum-enum-conversion -Wno-deprecated-anon-enum-enum-conversion -fPrintAndLogError-limit=0 -Wno-inconsistent-missing-override"
    local extraIncludes = {
        "Engine/Source/Runtime/CoreUObject/Public/UObject/ObjectMacros.h",
        "Engine/Source/Runtime/Core/Public/Misc/EnumRange.h"
    }

    rsppath = rsppath:gsub("\\\\","/")
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
        lines[lineNb] ="\n" .. "-include \"" .. CurrentGenData.config.EngineDir .. "/" .. incl .. "\""
        lineNb = lineNb + 1
    end
    lines[lineNb] =  "\n" .. extraFlags
    lineNb = lineNb + 1
    --table.insert(lines, "\n\"" .. currentFilename .. "\"")
    return table.concat(lines)
end

function CreateCommandLine()
end

function EscapePath(path)
    -- path = path:gsub("\\", "\\\\")
    path = path:gsub("\\\\", "/")
    path = path:gsub("\\", "/")
    path = path:gsub("\"", "\\\"")
    return path
end
function EnsureDirPath(path)
    PrintAndLogMessage("Ensuring path exists: "..path)
    -- os.execute("mkdir -p " .. path)
    local handle = io.popen("cmd.exe /c mkdir \"" .. path.. "\"")
    handle:flush()
    local result = handle:read("*a")
    handle:close()
end

function Stage_UbtGenCmd()
    coroutine.yield()
    Commands.BeginTask("gencmd")
    PrintAndLogMessage("callback called!")
    local outputJsonPath = CurrentGenData.config.EngineDir .. "/compile_commands.json"

    local rspdir = CurrentGenData.prjDir .. "/Intermediate/clangRsp/" .. 
    CurrentGenData.target.PlatformName .. "/".. 
    CurrentGenData.target.Configuration .. "/"

    -- all these replaces are slow, could be rewritten as a parser
    EnsureDirPath(rspdir)

    -- replace bad compiler
    local file_path = outputJsonPath

    local old_text = "Llvm\\\\x64\\\\bin\\\\clang%-cl%.exe"
    local new_text = "Llvm/x64/bin/clang++.exe"

    local contentLines = {}
    PrintAndLogMessage("processing compile_commands.json and writing response files")
    PrintAndLogMessage(file_path)
    PrintAndLogMessage(type(file_path))
    local currentFilename = ""
    for line in io.lines(file_path) do
        line = line:gsub(old_text, new_text)
        local i,j = line:find("\"command")
        if i then
            PrintAndLogMessage("processing " .. currentFilename)
            coroutine.yield()
            -- content = content .. "matched:\n"
            i,j = line:find("%@")
            if i then
                local _,endpos = line:find("\"", j)
                local rsppath = line:sub(j+1, endpos-1)
                if rsppath then
                    local newrsppath = rsppath .. ".clang.rsp"
                    local rspfile = io.open(newrsppath, "w")
                    local rspcontent = ExtractRSP(rsppath)
                    rspfile:write(rspcontent)
                    rspfile:close()
                    coroutine.yield()
                    table.insert(contentLines, "\t\t\"command\": \"clang++.exe @\\\"" ..newrsppath .."\\\"\",\n")
                end
            else
                -- it's not an rsp command, the flags will be clang compatible
                -- for some reason they're only incompatible flags inside
                -- rsps. keep line as is
                local _, endArgsPos = line:find("%.exe\\\"")
                local args = line:sub(endArgsPos+1, -1)
                coroutine.yield()
                local rspfilename = currentFilename:gsub("\\\\","/")
                rspfilename = rspfilename:gsub(":","")
                rspfilename = rspfilename:gsub("\"","")
                rspfilename = rspfilename:gsub(",","")
                rspfilename = rspfilename:gsub("\\","/")
                rspfilename = rspfilename:gsub("/","_")
                rspfilename = rspfilename .. ".rsp"
                local rspfilepath = rspdir .. rspfilename

                PrintAndLogMessage("Writing rsp: " .. rspfilepath)

                args = args:gsub("-D\\\"", "-D\"")
                args = args:gsub("-I\\\"", "-I\"")
                args = args:gsub("\\\"\\\"\\\"", "__3Q_PLACEHOLDER__")
                args = args:gsub("\\\"\\\"", "\\\"\"")
                args = args:gsub("\\\" ", "\" ")
                args = args:gsub("\\\\", "/")
                args = args:gsub(",%s*$", "") -- remove trailing comma and spaces
                args = args:gsub("\" ", "\"\n") -- one arg per line

                args = args:gsub("__3Q_PLACEHOLDER__", "\\\"\\\"\"")

                args = args:gsub("\n[^\n]*$", "")
                local rspfile = io.open(rspfilepath, "w")
                rspfile:write(args)
                rspfile:close()

                coroutine.yield()

                table.insert(contentLines, "\t\t\"command\": \"clang++.exe @\\\"" .. EscapePath(rspfilepath) .."\\\""
                    .. " ".. EscapePath(currentFilename) .."\",\n")
            end
        else
            local fbegin, fend = line:find("\"file\": ")
            if fbegin then
                currentFilename = line:sub(fend+1, -2)
                PrintAndLogMessage("currentfile: " .. currentFilename)
            end
            table.insert(contentLines, line .. "\n")
        end
    end


    local file = io.open(CurrentCompileCommandsTargetFilePath, "w")
    file:write(table.concat(contentLines))
    file:flush()
    file:close()

    PrintAndLogMessage("finished processing compile_commands.json")
    PrintAndLogMessage("generating header files with Unreal Header Tool...")
    Commands.EndTask("gencmd")
    vim.api.nvim_del_autocmd(Commands.gencmdAutocmdid)

    Commands.ScheduleTask("headers")
    Commands.BeginTask("headers")
    Commands.headersAutocmdid = vim.api.nvim_create_autocmd("ShellCmdPost",{
        pattern = "*",
        callback = FuncBind(DispatchUnrealnvimCb, "headers")
    })

    local cmd = CurrentGenData.ubtPath .. " -project=" ..
        CurrentGenData.projectPath .. " " .. CurrentGenData.target.UbtExtraFlags .. " " ..
        CurrentGenData.prjName .. CurrentGenData.targetNameSuffix .. " " .. CurrentGenData.target.Configuration .. " " ..
        CurrentGenData.target.PlatformName .. " -headers"

    vim.cmd("Dispatch " .. cmd)
end

function Stage_GenHeadersCompleted()
    PrintAndLogMessage("Finished generating header files with Unreal Header Tool...")
    vim.api.nvim_command('autocmd! ShellCmdPost * lua DispatchUnrealnvimCb()')
    vim.api.nvim_command('LspRestart')
    Commands.EndTask("headers")
    Commands.EndTask("final")
    Commands:SetCurrentAnimation("kirbyIdle")
    Commands.nvim_del_autocmd(Commands.headersAutocmdid)
end

Commands.renderedAnim = ""

function Commands.GetStatusBar()
    local status = "unset"
    if CurrentGenData:GetTaskStatus("final") == TaskState.completed then
        status = Commands.renderedAnim .. " Build completed!"
    elseif CurrentGenData.currentTask ~= "" then
        status = Commands.renderedAnim .. " Building... Step: " .. CurrentGenData.currentTask .. "->".. CurrentGenData:GetTaskStatus(CurrentGenData.currentTask)
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
    PrintAndLogMessage("DispatchCallbackCoroutine() task="..CurrentGenData:GetTaskAndStatus())
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
       print(tostring(i) .. ". " .. x.TargetName)
    end
    return tonumber(vim.fn.input "<number> : ")
end

function Commands.GetProjectName()
    local current_file_path = vim.api.nvim_buf_get_name(0)
    local prjName, _ = Commands._GetDefaultProjectNameAndDir(current_file_path)
    if not prjName  then
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

    CurrentGenData.ubtPath = "\"" .. CurrentGenData.config.EngineDir .."/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.exe\""
    CurrentGenData.ueBuildBat = "\"" .. CurrentGenData.config.EngineDir .."/ngine/Build/BatchFiles/Build.bat\""
    CurrentGenData.projectPath = "\"" .. CurrentGenData.prjDir .. "/" .. 
        CurrentGenData.prjName .. ".uproject\""

    local desiredTargetIndex = PromptBuildTargetIndex()

    CurrentGenData.target = CurrentGenData.config.Targets[desiredTargetIndex]

    CurrentGenData.targetNameSuffix = ""
    if CurrentGenData.target.withEditor then
        CurrentGenData.targetNameSuffix = "Editor"
    end

    PrintAndLogMessage("Using engine at:"..CurrentGenData.config.EngineDir)

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

function Commands.build(opts)
    PrintAndLogMessage("Building uproject")

    if not InitializeCurrentGenData() then
        return
    end

    Commands.ScheduleTask("build")

    local cmd = CurrentGenData.ueBuildBat .. " " .. CurrentGenData.prjName .. 
        CurrentGenData.targetNameSuffix .. " " ..
        CurrentGenData.target.PlatformName  .. " " .. 
        CurrentGenData.target.Configuration .. " " .. 
        CurrentGenData.projectPath .. " -waitmutex"

    PrintAndLogMessage(cmd)
    vim.cmd("compiler msvc")
    vim.cmd("Dispatch " .. cmd)
end

function Commands.run(opts)
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

        local executablePath = "\"".. CurrentGenData.config.EngineDir .. "/Engine/Binaries/" ..
        CurrentGenData.target.PlatformName .. "/UnrealEditor" ..  editorSuffix .. ".exe\""

        cmd = executablePath .. " " ..
        CurrentGenData.projectPath .. " -skipcompile"
    else
        local exeSuffix = ""
        if CurrentGenData.target.Configuration ~= "Development" then
            exeSuffix = "-" .. CurrentGenData.target.PlatformName .. "-" .. 
            CurrentGenData.target.Configuration
        end

        local executablePath = "\"".. CurrentGenData.prjDir .. "/Binaries/" ..
        CurrentGenData.target.PlatformName .. "/" .. CurrentGenData.prjName ..  exeSuffix .. ".exe\""

        cmd = executablePath
    end

    PrintAndLogMessage(cmd)
    vim.cmd("compiler msvc")
    vim.cmd("Dispatch " .. cmd)
end

function Commands.generateCommands(opts)
    if not InitializeCurrentGenData() then
        PrintAndLogMessage("init failed")
        return
    end

    -- vim.api.nvim_command('autocmd ShellCmdPost * lua DispatchUnrealnvimCb()')
    Commands.gencmdAutocmdid = vim.api.nvim_create_autocmd("ShellCmdPost",
        {
            pattern = "*",
            callback = FuncBind(DispatchUnrealnvimCb, "gencmd")
        })

    PrintAndLogMessage("listening to ShellCmdPost")
    --vim.cmd("compiler msvc")
    PrintAndLogMessage("compiler set to msvc")

    Commands.lastUpdateTime = vim.loop.now()
    Commands.updateTimer = 0
    Commands.taskCoroutine = coroutine.create(Commands.generateCommandsCoroutine)
    Commands.cbTimer = vim.loop.new_timer()
    Commands.cbTimer:start(4,4, vim.schedule_wrap(Commands.updateLoop))
    --vim.schedule(Commands.updateLoop)
end

function Commands.updateLoop()
    local elapsedTime = vim.loop.now() - Commands.lastUpdateTime
    Commands:update(elapsedTime)
    Commands.lastUpdateTime = vim.loop.now()

    --vim.schedule(Commands.updateLoop)
end

local gtimer = 0
local resetCount = 0
function Commands:update(delta)
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
    self.updateTimer = self.updateTimer + delta
    if self.updateTimer > 4  then
        if self.taskCoroutine then
            coroutine.resume(self.taskCoroutine)
        end
        Commands.onStatusUpdate()
        self.updateTimer = 0
    end

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
    CurrentCompileCommandsTargetFilePath =  CurrentGenData.prjDir .. "/compile_commands.json"
    vim.api.nvim_command("Dispatch " .. cmd)
    PrintAndLogMessage("Dispatched")
end

function Commands.SetUnrealCD()
    local current_file_path = vim.api.nvim_buf_get_name(0)
    local prjName, prjDir = Commands._GetDefaultProjectNameAndDir(current_file_path)
    if prjDir then
        vim.cmd("cd " .. prjDir)
    else
        PrintAndLogMessage("Could not find unreal project root directory, make sure you have the correct buffer selected")
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
        if ( ext == "uproject" ) then
            return directory.."/"..name
        end
    end
    return nil
end

function Commands._find_file_with_extension(filepath, extension)
    local current_dir = vim.fn.fnamemodify(filepath, ":h")
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
