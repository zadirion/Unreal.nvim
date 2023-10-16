local open = io.open
local kConfigFileName = "UnrealNvim.json"
local commands = {}

function SplitString(str)
    -- Split a string into lines
    local lines = {}
    for line in string.gmatch(str, "[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

function commands._CreateConfigFile(configFilePath, projectName)
    local configContents = [[
{
    "_comment": "dont forget to escape backslashes in EnginePath",    
    "EngineDir": "",
    "Targets":  [
        {
            "TargetName" : "]] .. projectName .. [[-Editor",
            "Configuration" : "Development",
            "UbtExtraFlags" : "-Editor",
            "PlatformName" : "Win64",
        },
        {
            "TargetName" : "]] .. projectName .. [[",
            "Configuration" : "Development",
            "UbtExtraFlags" : "",
            "PlatformName" : "Win64",
        }
    ]
}
    ]]
    -- local file = io.open(configFilePath, "w")
    -- file:write(configContents)
    -- file:close()
    print("Please populate the configuration for the Unreal project, especially EnginePath, the path to the Unreal Engine")
    -- local buf = vim.api.nvim_create_buf(false, true)
    vim.cmd('new ' .. configFilePath)
    vim.cmd('setlocal buftype=')
    -- vim.api.nvim_buf_set_name(0, configFilePath)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, SplitString(configContents))
    -- vim.api.nvim_open_win(buf, true, {relative="win", height=20, width=80, row=1, col=0})
end

function commands._EnsureConfigFile(projectRootDir, projectName)
    local configFilePath = projectRootDir.."/".. kConfigFileName
    local configFile = io.open(configFilePath, "r")
    
    if not configFile then
        commands._CreateConfigFile(configFilePath, projectName)
        return nil
    end

    local content = configFile:read("*all")
    configFile:close()

    local data = vim.fn.json_decode(content)
    return data;
end

function commands._GetDefaultProjectNameAndDir(filepath)
    local uprojectPath, projectDir
    projectDir, uprojectPath = commands._find_file_with_extension(filepath, "uproject")
    if not uprojectPath then
        print("Failed to determine project name, could not find the root of the project that contains the .uproject")
        return nil, nil
    end
    local projectName = vim.fn.fnamemodify(uprojectPath, ":t:r")
    return projectName, projectDir
end

local CurrentCompileCommandsTargetFilePath = ""
local currentGenData =
{
    config = {},
    target = nil,
    prjDir = nil,
    doStage = "none", -- one of "gencmd" or "headers"
    ubtPath = "",
    projectPath = "",
}

function Stage_UbtGenCmd()
    print("callback called!")
    local outputJsonPath = currentGenData.config.EngineDir .. "/compile_commands.json"

    print(commands.inspect.inspect(vim.g.dispatch_waiting_jobs))
    -- replace bad compiler
    local file_path = outputJsonPath
    local old_text = "Llvm\\\\bin\\\\clang%-cl%.exe"
    local new_text = "Llvm\\\\x64\\\\bin\\\\clang++.exe"

    local file = io.open(file_path, "r")
    local content = file:read("*all")
    file:close()

    content = content:gsub(old_text, new_text)

    file = io.open(CurrentCompileCommandsTargetFilePath, "w")
    file:write(content)
    file:close()

    currentGenData.doStage = "headers"

    local cmd = currentGenData.ubtPath .. " -project=" ..
        currentGenData.projectPath .. " " .. currentGenData.target.UbtExtraFlags .. " " ..
        currentGenData.target.TargetName .. " " .. currentGenData.target.Configuration .. " " ..
        currentGenData.target.PlatformName .. " -headers"

    vim.cmd("Dispatch " .. cmd)

end

function Stage_GenHeaders()
    print("Headers generated")
    vim.api.nvim_command('autocmd! ShellCmdPost * lua UnrealBuildToolCallback()')
    vim.api.nvim_command('LspRestart')
    currentGenData.doStage = "none"
end

function UnrealBuildToolCallback()
    if currentGenData.doStage == "gencmd" then
        Stage_UbtGenCmd()
    elseif  currentGenData.doStage == "headers" then
        Stage_GenHeaders()
    end
end

function commands.generateCommands(opts)
    print("Generating clang-compatible compile_commands.json")
    currentGenData.doStage = "gencmd"

    local current_file_path = vim.api.nvim_buf_get_name(0)
    local prjName
    prjName, prjDir = commands._GetDefaultProjectNameAndDir(current_file_path)
    if not prjName then
        print("aborting")
        return false
    end

    currentGenData.config = commands._EnsureConfigFile(prjDir, prjName)
    if not currentGenData.config then
        return false
    end
    print("Using engine at:"..currentGenData.config.EngineDir)
    currentGenData.ubtPath = "\"" .. currentGenData.config.EngineDir .."\\Engine\\Binaries\\DotNET\\UnrealBuildTool\\UnrealBuildTool.exe\""
    currentGenData.projectPath = "\"" .. prjDir .. "/" .. prjName .. ".uproject\""

    -- prompt user, ask which target to build
    print("target to build:")
    for i, x in ipairs(currentGenData.config.Targets) do
       print(tostring(i) .. ". " .. x.TargetName)
    end

    local desiredTargetName = tonumber(vim.fn.input "<number> : ")

    currentGenData.target = currentGenData.config.Targets[desiredTargetName]

    local cmd = currentGenData.ubtPath .. " -mode=GenerateClangDatabase -project=" ..
        currentGenData.projectPath .. " -game -engine " .. currentGenData.target.UbtExtraFlags .. " " ..
        currentGenData.target.TargetName .. " " .. currentGenData.target.Configuration .. " " ..
        currentGenData.target.PlatformName

    vim.api.nvim_command('autocmd ShellCmdPost * lua UnrealBuildToolCallback()')
    CurrentCompileCommandsTargetFilePath =  prjDir .. "/compile_commands.json"
    vim.cmd("compiler msvc")
    vim.cmd("Dispatch " .. cmd)

    return true
end


commands.inspect = {}
local inspect_path = vim.fn.stdpath("data") .. "\\site\\pack\\packer\\start\\inspect.lua\\inspect.lua" 
commands.inspect = loadfile(inspect_path)(commands.inspect)

function commands._check_extension_in_directory(directory, extension)
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
            return directory.."\\"..name
        end
    end
    return nil
end

function commands._find_file_with_extension(filepath, extension)
    local current_dir = vim.fn.fnamemodify(filepath, ":h")
    local parent_dir = vim.fn.fnamemodify(current_dir, ":h")
    -- Check if the file exists in the current directory
    local filename = vim.fn.fnamemodify(filepath, ":t")

    local full_path = commands._check_extension_in_directory(current_dir, extension)
    if full_path then
        return current_dir, full_path
    end

    -- Recursively check parent directories until we find the file or reach the root directory
    if current_dir ~= parent_dir then
        return commands._find_file_with_extension(parent_dir .. "/" .. filename, extension)
    end

    -- File not found
    return nil
end


return commands
