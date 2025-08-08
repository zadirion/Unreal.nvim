
-- Configuration constants
local kConfigFileName = "UnrealNvim.json"  -- Name of the configuration file
local kCurrentVersion = "0.0.2"            -- Current version of the configuration format

-- Task state enumeration for tracking build/process states
---@enum TaskState
local TaskState =
{
    scheduled = "scheduled",    -- Task is queued but not yet started
    inprogress = "inprogress",  -- Task is currently running
    completed = "completed"     -- Task has finished successfully
}

-- fix false diagnostic about vim
if not vim then
    vim = {}
end

-- Import utility modules
local file_util = require("unreal.file_util")
local log_util = require("unreal.log_util")

-- Type definitions for better IDE support
---@class TargetConfig
---@field TargetName string
---@field Configuration string
---@field withEditor boolean
---@field UbtExtraFlags string
---@field PlatformName string

---@class UnrealConfig
---@field version string
---@field EngineDir string
---@field Targets TargetConfig[]
---@field withEditor boolean|nil

---@class CurrentGenData
---@field config UnrealConfig|table
---@field target TargetConfig|nil
---@field prjName string|nil
---@field targetNameSuffix string|nil
---@field prjDir string|nil
---@field tasks table<string, string>
---@field currentTask string
---@field ubtPath string
---@field ueBuildBat string
---@field projectPath string
---@field logFile userdata|nil
---@field uprojectPath string|nil
---@field WithEngine boolean|nil
---@field GetTaskAndStatus fun(self): string
---@field GetTaskStatus fun(self, taskName: string): string
---@field SetTaskStatus fun(self, taskName: string, newStatus: string)
---@field ClearTasks fun(self)

-- Creates a function that calls the given function with the specified data
-- Used for creating callback functions with bound data
---@param func function The function to bind
---@param data any The data to pass to the function
---@return function A new function that calls func(data)
local function FuncBind(func, data)
    return function()
        func(data)
    end
end

-- Initialize global state if not already loaded
if not vim.g.unrealnvim_loaded then
    Commands = {}

    -- Global data structure for tracking current generation/build state
    ---@type CurrentGenData
    CurrentGenData =
    {
        config = {},              -- Configuration data from UnrealNvim.json
        target = nil,             -- Currently selected build target
        prjName = nil,            -- Project name
        targetNameSuffix = nil,   -- Suffix for target name (e.g., "Editor")
        prjDir = nil,             -- Project directory path
        tasks = {},               -- Dictionary of task states
        currentTask = "",         -- Currently running task name
        ubtPath = "",             -- Path to UnrealBuildTool.exe
        ueBuildBat = "",          -- Path to UE build batch file
        projectPath = "",         -- Full path to .uproject file
        logFile = nil             -- Log file handle
    }
    -- Initialize and clear the log file
    CurrentGenData.logFile = io.open(vim.fn.stdpath("data") .. '/unrealnvim.log', "w")

    if CurrentGenData.logFile then
        CurrentGenData.logFile:write("")
        CurrentGenData.logFile:close()

        CurrentGenData.logFile = io.open(vim.fn.stdpath("data") .. '/unrealnvim.log', "a")
    end
    vim.g.unrealnvim_loaded = true
end

-- Expose log levels as constants on the Commands object
Commands.LogLevel_Error = log_util.kLogLevel_Error
Commands.LogLevel_Warning = log_util.kLogLevel_Warning
Commands.LogLevel_Log = log_util.kLogLevel_Log
Commands.LogLevel_Verbose = log_util.kLogLevel_Verbose
Commands.LogLevel_VeryVerbose = log_util.kLogLevel_VeryVerbose

-- Logs a message using the error logging function
---@param msg string The message to log
function Commands.Log(msg)
    log_util.PrintAndLogError(msg)
end

-- Callback function for status updates (can be overridden)
Commands.onStatusUpdate = function()
end

-- Inspects an object for debugging purposes using the inspect.lua library
-- Only works when debugging is enabled
---@param objToInspect any The object to inspect
---@return string|nil String representation of the object
function Commands:Inspect(objToInspect)
    if not vim.g.unrealnvim_debug then return end
    if not objToInspect then
        log_util.log(objToInspect)
        return
    end

    if not self._inspect then
        local inspect_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/inspect.lua/inspect.lua"
        self._inspect = loadfile(inspect_path)(Commands._inspect)
        if  self._inspect then
            log_util.log("Inspect loaded.")
        else
            log_util.logError("Inspect failed to load from path" .. inspect_path)
        end
        if self._inspect.inspect then
            log_util.log("inspect method exists")
        else
            log_util.logError("inspect method doesn't exist")
        end
    end
    return self._inspect.inspect(objToInspect)
end



-- Creates a new configuration file with default Unreal Engine build targets
-- Opens the file in a new buffer for user editing
---@param configFilePath string Path where to create the config file
---@param projectName string Name of the Unreal project
function Commands._CreateConfigFile(configFilePath, projectName)
    local configContents = [[
{
    "version" : "0.0.2",
    "_comment": "dont forget to escape backslashes in EnginePath",    
    "EngineDir": "",
    "Targets":  [

        {
            "TargetName" : "]] .. projectName .. [[-Editor",
            "Configuration" : "DebugGame",
            "withEditor" : true,
            "UbtExtraFlags" : "",
            "PlatformName" : "Win64"
        },
        {
            "TargetName" : "]] .. projectName .. [[",
            "Configuration" : "DebugGame",
            "withEditor" : false,
            "UbtExtraFlags" : "",
            "PlatformName" : "Win64"
        },
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
        },
        {
            "TargetName" : "]] .. projectName .. [[-Editor",
            "Configuration" : "Shipping",
            "withEditor" : true,
            "UbtExtraFlags" : "",
            "PlatformName" : "Win64"
        },
        {
            "TargetName" : "]] .. projectName .. [[",
            "Configuration" : "Shipping",
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
    log_util.PrintAndLogMessage("Please populate the configuration for the Unreal project, especially EnginePath, the path to the Unreal Engine")
    -- local buf = vim.api.nvim_create_buf(false, true)
    vim.cmd('new ' .. configFilePath)
    vim.cmd('setlocal buftype=')
    -- vim.api.nvim_buf_set_name(0, configFilePath)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, file_util.SplitString(configContents))
    -- vim.api.nvim_open_win(buf, true, {relative="win", height=20, width=80, row=1, col=0})
end

-- Ensures a configuration file exists and is valid
-- Creates a new config file if it doesn't exist, validates version if it does
---@param projectRootDir string Root directory of the Unreal project
---@param projectName string Name of the Unreal project
---@return UnrealConfig|nil Parsed configuration data or nil if invalid/created
function Commands._EnsureConfigFile(projectRootDir, projectName)
    local configFilePath = projectRootDir.."/".. kConfigFileName
    local configFile = io.open(configFilePath, "r")


    if (not configFile) then
        Commands._CreateConfigFile(configFilePath, projectName)
        log_util.PrintAndLogMessage("created config file")
        return nil
    end

    local content = configFile:read("*all")
    configFile:close()

    local data = vim.fn.json_decode(content)
    Commands:Inspect(data)
    if data and (data.version ~= kCurrentVersion) then
        log_util.PrintAndLogError("Your " .. configFilePath .. " format is incompatible. Please back up this file somewhere and then delete this one, you will be asked to create a new one") 
        data = nil
    end

    if data then
        data.EngineDir = file_util.MakeUnixPath(data.EngineDir)
    end

    return data
end



-- Global variable to store the path of the generated compile_commands.json file
local CurrentCompileCommandsTargetFilePath = ""

-- Returns a string representation of the current task and its status
---@return string String in format "taskName->status" or "[No Task]"
function CurrentGenData:GetTaskAndStatus()
    if not self or not self.currentTask or self.currentTask == "" then
        return "[No Task]"
    end
    local status = self:GetTaskStatus(self.currentTask)
    return self.currentTask.."->".. status
end

-- Gets the status of a specific task
---@param taskName string Name of the task to check
---@return string Task status string or "none" if task doesn't exist
function CurrentGenData:GetTaskStatus(taskName)
    local status = self.tasks[taskName]

    if not status then
       status = "none"
    end
    return status
end

-- Sets the status of a task and manages task transitions
-- Prevents starting new tasks while another is in progress
---@param taskName string Name of the task to update
---@param newStatus string New status for the task
function CurrentGenData:SetTaskStatus(taskName, newStatus)
    if (self.currentTask ~= "" and self.currentTask ~= taskName) and (self:GetTaskStatus(self.currentTask) ~= TaskState.completed) then
        log_util.PrintAndLogMessage("Cannot start a new task. Current task still in progress " .. self.currentTask)
        log_util.PrintAndLogError("Cannot start a new task. Current task still in progress " .. self.currentTask)
        return
    end
    log_util.PrintAndLogMessage("SetTaskStatus: " .. taskName .. "->" .. newStatus)
    self.currentTask = taskName
    self.tasks[taskName] = newStatus
end

-- Clears all task states and resets current task
function CurrentGenData:ClearTasks()
    self.tasks = {}
    self.currentTask = ""
end



-- Extracts and converts MSVC response file format to clang-compatible format
-- Converts MSVC compiler flags to clang flags and adds Unreal Engine specific includes
---@param rsppath string Path to the MSVC response file
---@return string|nil Converted clang-compatible response file content
function ExtractRSP(rsppath)
    local extraFlags = "-std=c++20 -Wno-deprecated-enum-enum-conversion -Wno-deprecated-anon-enum-enum-conversion -ferror-limit=0 -Wno-inconsistent-missing-override"
    local extraIncludes = {
        "Engine/Source/Runtime/CoreUObject/Public/UObject/ObjectMacros.h",
        "Engine/Source/Runtime/Core/Public/Misc/EnumRange.h"
    }

    rsppath = rsppath:gsub("\\\\","/")
    log_util.PrintAndLogMessage(rsppath)

    if not file_util.file_exists(rsppath) then
       log_util.PrintAndLogMessage("rsppath doesn't exists: " .. rsppath)
       return
    end

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

-- Placeholder function for creating command lines (currently unused)
function CreateCommandLine()
end






-- Checks if a window is a quickfix window
---@param winid number Window ID to check
---@return boolean true if window is quickfix, false otherwise
local function IsQuickfixWin(winid)
    if not vim.api.nvim_win_is_valid(winid) then return false end
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

    return buftype == 'quickfix'
end

-- Finds the quickfix window ID
---@return number|nil Window ID of quickfix window or nil if not found
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

-- Global variable to store the quickfix window ID
Commands.QuickfixWinId = 0

-- Scrolls the quickfix window to the bottom to show latest entries
local function ScrollQF()
    if not IsQuickfixWin(Commands.QuickfixWinId) then
        Commands.QuickfixWinId = GetQuickfixWinId()
    end

    local qf_list = vim.fn.getqflist()
    local last_line = #qf_list
    if last_line > 0 then
        vim.api.nvim_win_set_cursor(Commands.QuickfixWinId, {last_line, 0})
    end
end

-- Appends an entry to the quickfix list and scrolls to show it
---@param entry table Quickfix entry to add
local function AppendToQF(entry)
    vim.fn.setqflist({}, 'a', { items = { entry } })
    ScrollQF()
end

-- Safely deletes an autocmd by ID
---@param AutocmdId number ID of the autocmd to delete
local function DeleteAutocmd(AutocmdId)
    local success, _ = pcall(function()
        vim.api.nvim_del_autocmd(AutocmdId)
    end)
end

-- Main stage function for processing UBT-generated compile_commands.json
-- Converts MSVC compiler commands to clang-compatible format and creates response files
-- This is a coroutine that yields to allow UI updates during processing
function Stage_UbtGenCmd()
    coroutine.yield()
    Commands.BeginTask("gencmd")
    log_util.PrintAndLogMessage("callback called!")
    
    if not CurrentGenData.target then
        log_util.PrintAndLogError("CurrentGenData.target is nil")
        return
    end
    
    local outputJsonPath = CurrentGenData.config.EngineDir .. "/compile_commands.json"

    local rspdir = CurrentGenData.prjDir .. "/Intermediate/clangRsp/" .. 
    CurrentGenData.target.PlatformName .. "/" .. 
    CurrentGenData.target.Configuration .. "/"

    -- all these replaces are slow, could be rewritten as a parser
    file_util.EnsureDirPath(rspdir)

    -- replace bad compiler
    local file_path = outputJsonPath

    local old_text = "Llvm\\\\x64\\\\bin\\\\clang%-cl%.exe"
    local new_text = "Llvm/x64/bin/clang++.exe"

    local contentLines = {}
    log_util.PrintAndLogMessage("processing compile_commands.json and writing response files")
    log_util.PrintAndLogMessage(file_path)

    local skipEngineFiles = true
    if CurrentGenData.WithEngine then
        skipEngineFiles = false
    end

    local qflistentry = {text = "Preparing files for parsing." }
    if not skipEngineFiles then
        qflistentry.text = qflistentry.text .. " Engine source files included, process will take longer" 
    end
    AppendToQF(qflistentry)

    local currentFilename = ""
    for line in io.lines(file_path) do
        local i,j = line:find("\"command")
        if i then
            coroutine.yield()

            -- show progress
            log_util.logWithVerbosity(log_util.kLogLevel_Verbose, "Preparing for LSP symbol parsing: " .. currentFilename)
            local isEngineFile = file_util.IsEngineFile(currentFilename, CurrentGenData.config.EngineDir)
            local shouldSkipFile = isEngineFile and skipEngineFiles

            local qflistentry = {filename = "", lnum = 0, col = 0,
                text = currentFilename}
            if not shouldSkipFile then
                AppendToQF(qflistentry)
            end

            line = line:gsub(old_text, new_text)

            -- content = content .. "matched:\n"
            i,j = line:find("%@")

            if i then
                -- The file name might have an optional \" around to shell escape the file name in the command.
                local backslashValue = string.byte("\\", 1)
                if string.byte(line, j+1) == backslashValue then
                    j = j+2 -- \ and "
                end

                local _,endpos = line:find("\"", j+1)

                -- same thing here
                if string.byte(line, endpos-1) == backslashValue then
                    endpos = endpos-1
                end

                local rsppath = line:sub(j+1, endpos-1)
                if rsppath and file_util.file_exists(rsppath) then
                    local newrsppath = rsppath .. ".clang.rsp"

                    -- rewrite rsp contents
                    if not shouldSkipFile then
                        local rspfile = io.open(newrsppath, "w")
                        local rspcontent = ExtractRSP(rsppath)
                        rspfile:write(rspcontent)
                        rspfile:close()
                    end
                    coroutine.yield()

                    table.insert(contentLines, "\t\t\"command\": \"clang++.exe @\\\"" ..newrsppath .."\\\"\",\n")
                end
            else
                -- it's not an rsp command, the flags will be clang compatible
                -- for some reason they're only incompatible flags inside
                -- rsps. keep line as is
                local _, endArgsPos = line:find("%.exe\\\"")
                local args = line:sub(endArgsPos+1, -1)
                local rspfilename = currentFilename:gsub("\\\\","/")
                rspfilename = rspfilename:gsub(":","")
                rspfilename = rspfilename:gsub("\"","")
                rspfilename = rspfilename:gsub(",","")
                rspfilename = rspfilename:gsub("\\","/")
                rspfilename = rspfilename:gsub("/","_")
                rspfilename = rspfilename .. ".rsp"
                local rspfilepath = rspdir .. rspfilename

                if not shouldSkipFile then
                    log_util.PrintAndLogMessage("Writing rsp: " .. rspfilepath)

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
                end
                coroutine.yield()

                table.insert(contentLines, "\t\t\"command\": \"clang++.exe @\\\"" .. file_util.EscapePath(rspfilepath) .."\\\""
                    .. " ".. file_util.EscapePath(currentFilename) .."\",\n")
            end
        else
            local fbegin, fend = line:find("\"file\": ")
            if fbegin then
                currentFilename = line:sub(fend+1, -2)
                log_util.logWithVerbosity(log_util.kLogLevel_Verbose, "currentfile: " .. currentFilename)
            end
            table.insert(contentLines, line .. "\n")
        end
        ::continue::
    end


    local file = io.open(CurrentCompileCommandsTargetFilePath, "w")
    file:write(table.concat(contentLines))
    file:flush()
    file:close()

    log_util.PrintAndLogMessage("finished processing compile_commands.json")
    log_util.PrintAndLogMessage("generating header files with Unreal Header Tool...")
    Commands.EndTask("gencmd")
    DeleteAutocmd(Commands.gencmdAutocmdid)

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

    vim.cmd("compiler msvc")
    vim.cmd("Dispatch " .. cmd)
end

-- Called when Unreal Header Tool has finished generating header files
-- Restarts the LSP to pick up new generated headers and cleans up tasks
function Stage_GenHeadersCompleted()
    log_util.PrintAndLogMessage("Finished generating header files with Unreal Header Tool...")
    vim.api.nvim_command('autocmd! ShellCmdPost * lua DispatchUnrealnvimCb()')
    vim.api.nvim_command('LspRestart')
    Commands.EndTask("headers")
    Commands.EndTask("final")
    Commands:SetCurrentAnimation("kirbyIdle")
    DeleteAutocmd(Commands.headersAutocmdid)
end

Commands.renderedAnim = ""

-- Returns the current status string for display in status bar
-- Shows animation, task progress, and completion status
-- @return: Status string for display
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

-- Callback function for dispatch commands
-- Creates a new coroutine to handle the callback data
---@param data string|nil Data passed from the dispatch command
function DispatchUnrealnvimCb(data)
     log_util.log("DispatchUnrealnvimCb()")
     Commands.taskCoroutine = coroutine.create(FuncBind(DispatchCallbackCoroutine, data))
 end

-- Handles dispatch callbacks and routes to appropriate stage functions
-- Manages task state transitions based on callback data
---@param data string|nil Callback data indicating which stage to execute
function DispatchCallbackCoroutine(data)
    coroutine.yield()
    if not data then
        log_util.log("data was nil")
    end
    log_util.PrintAndLogMessage("DispatchCallbackCoroutine()")
    log_util.PrintAndLogMessage("DispatchCallbackCoroutine() task="..CurrentGenData:GetTaskAndStatus())
    if data == "gencmd" and CurrentGenData:GetTaskStatus("gencmd") == TaskState.scheduled then
        CurrentGenData:SetTaskStatus("gencmd", TaskState.inprogress)
        Commands.taskCoroutine = coroutine.create(Stage_UbtGenCmd)
    elseif data == "headers" and CurrentGenData:GetTaskStatus("headers") == TaskState.inprogress then
        Commands.taskCoroutine = coroutine.create(Stage_GenHeadersCompleted)
    end
end

-- Prompts user to select a build target from the configuration
-- Displays available targets and waits for user input
---@return number|nil Selected target index as number
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

-- Gets the current project name with .uproject extension
---@return string Project name with .uproject extension or empty string if not found
function Commands.GetProjectName()
    local current_file_path = vim.api.nvim_buf_get_name(0)
    local prjDir, uprojectPath = file_util.find_file_with_extension(current_file_path, "uproject")
    if not uprojectPath then
        return "" --"<Unknown.uproject>"
    end

    local projectName = vim.fn.fnamemodify(uprojectPath, ":t:r")
    return projectName .. ".uproject"
end

-- Initializes the global generation data with project and engine information
-- Sets up paths, prompts for target selection, and validates configuration
---@return boolean true if initialization successful, false otherwise
function InitializeCurrentGenData()
    log_util.PrintAndLogMessage("initializing")
    local current_file_path = vim.api.nvim_buf_get_name(0)
    CurrentGenData.prjDir, CurrentGenData.uprojectPath = file_util.find_file_with_extension(current_file_path, "uproject")
    if not CurrentGenData.uprojectPath then
        log_util.PrintAndLogMessage("could not find project. aborting")
        return false
    end
    
    CurrentGenData.prjName = vim.fn.fnamemodify(CurrentGenData.uprojectPath, ":t:r")

    ---@type UnrealConfig|nil
    local config = Commands._EnsureConfigFile(CurrentGenData.prjDir,
        CurrentGenData.prjName)
    CurrentGenData.config = config

    if not CurrentGenData.config then
        log_util.PrintAndLogMessage("no config file. aborting")
        return false
    end

    CurrentGenData.ubtPath = "\"" .. CurrentGenData.config.EngineDir .."/Engine/Binaries/DotNET/UnrealBuildTool/UnrealBuildTool.exe\""
    CurrentGenData.ueBuildBat = "\"" .. CurrentGenData.config.EngineDir .."/Engine/Build/BatchFiles/Build.bat\""
    CurrentGenData.projectPath = "\"" .. CurrentGenData.prjDir .. "/" .. 
        CurrentGenData.prjName .. ".uproject\""

    local desiredTargetIndex = PromptBuildTargetIndex()
    CurrentGenData.target = CurrentGenData.config.Targets[desiredTargetIndex]

    CurrentGenData.targetNameSuffix = ""
    if CurrentGenData.target.withEditor then
        CurrentGenData.targetNameSuffix = "Editor"
    end

    log_util.PrintAndLogMessage("Using engine at:"..CurrentGenData.config.EngineDir)

    return true
end

-- Schedules a task to be executed (sets status to scheduled)
---@param taskName string Name of the task to schedule
function Commands.ScheduleTask(taskName)
    log_util.PrintAndLogMessage("ScheduleTask: " .. taskName)
    CurrentGenData:SetTaskStatus(taskName, TaskState.scheduled)
end

-- Clears all task states and resets current task
function Commands.ClearTasks()
    CurrentGenData:ClearTasks()
end

-- Begins execution of a task (sets status to inprogress)
---@param taskName string Name of the task to begin
function Commands.BeginTask(taskName)
    log_util.PrintAndLogMessage("BeginTask: " .. taskName)
    CurrentGenData:SetTaskStatus(taskName, TaskState.inprogress)
end

-- Marks a task as completed and cleans up coroutine
---@param taskName string Name of the task to complete
function Commands.EndTask(taskName)
    log_util.PrintAndLogMessage("EndTask: " .. taskName)
    CurrentGenData:SetTaskStatus(taskName, TaskState.completed)
    Commands.taskCoroutine = nil
end

-- Callback function called when build process completes
-- Cleans up tasks and sets idle animation
function BuildComplete()
    Commands.EndTask("build")
    Commands.EndTask("final")
    Commands:SetCurrentAnimation("kirbyIdle")
    DeleteAutocmd(Commands.buildAutocmdid)
end

-- Coroutine function that handles the build process
-- Sets up autocmd for completion callback and dispatches build command
function Commands.BuildCoroutine()
    Commands.buildAutocmdid = vim.api.nvim_create_autocmd("ShellCmdPost",
        {
            pattern = "*",
            callback = BuildComplete 
        })

    local cmd = CurrentGenData.ueBuildBat .. " " .. CurrentGenData.prjName .. 
        CurrentGenData.targetNameSuffix .. " " ..
        CurrentGenData.target.PlatformName  .. " " .. 
        CurrentGenData.target.Configuration .. " " .. 
        CurrentGenData.projectPath .. " -waitmutex"

    vim.cmd("compiler msvc")
    vim.cmd("Dispatch " .. cmd)

end

-- Main build command function
-- Initializes project data and starts build process
---@param opts table|nil Build options (currently unused)
function Commands.build(opts)
    CurrentGenData:ClearTasks()
    log_util.PrintAndLogMessage("Building uproject")

    if not InitializeCurrentGenData() then
        return
    end
    Commands.EnsureUpdateStarted();

    Commands.ScheduleTask("build")
    Commands:SetCurrentAnimation("kirbyFlip")
    Commands.taskCoroutine = coroutine.create(Commands.BuildCoroutine)

end

-- Main run command function
-- Determines whether to run editor or game executable and dispatches command
---@param opts table|nil Run options (currently unused)
function Commands.run(opts)
    CurrentGenData:ClearTasks()
    log_util.PrintAndLogMessage("Running uproject")
    
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

    log_util.PrintAndLogMessage(cmd)
    vim.cmd("compiler msvc")
    vim.cmd("Dispatch " .. cmd)
    Commands.EndTask("run")
    Commands.EndTask("final")
end

-- Ensures the update loops are started for UI and logic updates
-- Only starts once to avoid duplicate timers
function Commands.EnsureUpdateStarted()
    if Commands.cbTimer then return end

    Commands.lastUpdateTime = vim.loop.now()
    Commands.updateTimer = 0

    -- UI update loop
    Commands.cbTimer = vim.loop.new_timer()
    Commands.cbTimer:start(1,30, vim.schedule_wrap(Commands.safeUpdateLoop))

    -- coroutine update loop
    vim.schedule(Commands.safeLogicUpdate)
end

-- Main command generation function
-- Sets up autocmd for callback and starts the generation coroutine
---@param opts table|nil Generation options including WithEngine flag
function Commands.generateCommands(opts)
    log_util.log(Commands.Inspect(opts))

    if not InitializeCurrentGenData() then
        log_util.PrintAndLogMessage("init failed")
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

    log_util.PrintAndLogMessage("listening to ShellCmdPost")
    --vim.cmd("compiler msvc")
    log_util.PrintAndLogMessage("compiler set to msvc")

    Commands.taskCoroutine = coroutine.create(Commands.generateCommandsCoroutine)
    Commands.EnsureUpdateStarted()
end


-- Main update loop for UI animations and status updates
-- Calculates elapsed time and updates UI elements
function Commands.updateLoop()
    local elapsedTime = vim.loop.now() - Commands.lastUpdateTime
    Commands:uiUpdate(elapsedTime)
    Commands.lastUpdateTime = vim.loop.now()
end

-- Safe wrapper for the update loop that catches errors
-- Prevents crashes from breaking the update timer
function Commands.safeUpdateLoop()
    local success, errmsg = pcall(Commands.updateLoop)
    if not success then
        vim.api.nvim_err_writeln("Error in update:".. errmsg)
    end
end

local gtimer = 0
local resetCount = 0

-- Updates UI animations based on elapsed time
-- Cycles through animation frames at specified intervals
---@param delta number Elapsed time since last update
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

-- Safe wrapper for logic updates that catches errors
-- Schedules itself to run again after 1ms
function Commands.safeLogicUpdate()
    local success, errmsg = pcall(function() Commands:LogicUpdate() end)

    if not success then
        vim.api.nvim_err_writeln("Error in update:".. errmsg)
    end
    vim.defer_fn(Commands.safeLogicUpdate, 1)
end

-- Main logic update function that manages coroutines
-- Resumes task coroutines and schedules status updates
function Commands:LogicUpdate()
    if self.taskCoroutine then
        if coroutine.status(self.taskCoroutine) ~= "dead"  then
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



-- Sets the current animation from the spinners.json file
---@param animationName string Name of the animation to load
function Commands:SetCurrentAnimation(animationName)
    local jsonPath = file_util.GetInstallDir() .. "lua/spinners.json"
    local file = io.open(jsonPath, "r")
    if file then
        local content = file:read("*all")
        local json = vim.fn.json_decode(content)
        Commands.animData = json[animationName]
    end
end

-- Coroutine function that generates clang-compatible compile commands
-- Sets up animation, schedules tasks, and dispatches UBT command
function Commands.generateCommandsCoroutine()
    log_util.PrintAndLogMessage("Generating clang-compatible compile_commands.json")
    Commands:SetCurrentAnimation("kirbyFlip")
    coroutine.yield()
    Commands.ClearTasks()

    local editorFlag = ""
    if CurrentGenData.config.withEditor then
        log_util.PrintAndLogMessage("Building editor")
        editorFlag = "-Editor"
    end

    Commands.ScheduleTask("gencmd")
    -- local cmd = CurrentGenData.ubtPath .. " -mode=GenerateClangDatabase -StaticAnalyzer=Clang -project=" ..
    local cmd = CurrentGenData.ubtPath .. " -mode=GenerateClangDatabase -project=" ..
    CurrentGenData.projectPath .. " -game -engine " .. CurrentGenData.target.UbtExtraFlags .. " " ..
    editorFlag .. " " ..
    CurrentGenData.prjName .. CurrentGenData.targetNameSuffix .. " " .. CurrentGenData.target.Configuration .. " " ..
    CurrentGenData.target.PlatformName

    log_util.PrintAndLogMessage("Dispatching command:")
    log_util.PrintAndLogMessage(cmd)
    CurrentCompileCommandsTargetFilePath =  CurrentGenData.prjDir .. "/compile_commands.json"
    vim.api.nvim_command("Dispatch " .. cmd)
    log_util.PrintAndLogMessage("Dispatched")
end

-- Changes the current working directory to the Unreal project root
-- Useful for making Telescope and other tools search only in the project directory
function Commands.SetUnrealCD()
    local current_file_path = vim.api.nvim_buf_get_name(0)
    local prjDir, uprojectPath = file_util.find_file_with_extension(current_file_path, "uproject")
    if prjDir then
        vim.cmd("cd " .. prjDir)
    else
        log_util.PrintAndLogMessage("Could not find unreal project root directory, make sure you have the correct buffer selected")
    end
end





return Commands
