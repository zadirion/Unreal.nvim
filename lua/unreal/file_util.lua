-- File utility functions for Unreal.nvim
-- Contains path manipulation and file system operations

-- Converts Windows path format to Unix path format
-- @param win_path: Windows path with backslashes
-- @return: Unix path with forward slashes
local function MakeUnixPath(win_path)
    if not win_path then
        return nil
    end
    -- Convert backslashes to forward slashes
    local unix_path = win_path:gsub("\\", "/")

    -- Remove duplicate slashes
    unix_path = unix_path:gsub("//+", "/")

    return unix_path
end

-- Escapes a path for use in command line arguments
-- Converts backslashes to forward slashes and escapes quotes
-- @param path: Path to escape
-- @return: Escaped path string
local function EscapePath(path)
    if not path then
        return ""
    end
    -- path = path:gsub("\\", "\\\\")
    path = path:gsub("\\\\", "/")
    path = path:gsub("\\", "/")
    path = path:gsub("\"", "\\\"")
    return path
end

-- Checks if a file exists
-- @param name: Path to the file to check
-- @return: true if file exists, false otherwise
local function file_exists(name)
   if not name then
      return false
   end
   local f = io.open(name, "r")
   if f then
      io.close(f)
      return true
   end

   return false
end

-- Creates a directory path if it doesn't exist
-- Uses Windows mkdir command
-- @param path: Directory path to create
local function EnsureDirPath(path)
    if not path then
        return
    end
    local handle = io.popen("cmd.exe /c mkdir \"" .. path.. "\"")
    if handle then
        handle:flush()
        handle:read("*a")
        handle:close()
    end
end

-- Checks if a file path is within the Unreal Engine directory
-- @param path: File path to check
-- @param start: Engine root path to check against
-- @return: true if file is in engine directory, false otherwise
local function IsEngineFile(path, start)
    if not path or not start then
        return false
    end
    local unixPath = MakeUnixPath(path)
    local unixStart = MakeUnixPath(start)
    if not unixPath or not unixStart then
        return false
    end
    local startIndex, _ = string.find(unixPath, unixStart, 1, true)
    return startIndex ~= nil
end

-- Checks if a file with the specified extension exists in a directory
-- @param directory: Directory to search in
-- @param extension: File extension to look for (e.g., "uproject")
-- @return: Full path to the file if found, nil otherwise
local function check_extension_in_directory(directory, extension)
    if not directory or not extension then
        return nil
    end
    
    local handle = vim.loop.fs_scandir(directory) 
    if not handle then
        return nil
    end

    local name
    while handle do
        name = vim.loop.fs_scandir_next(handle)
        if not name then break end
        local ext = vim.fn.fnamemodify(name, ":e")
        if ext == extension then
            return directory.."/"..name
        end
    end
    return nil
end

-- Recursively searches for a file with the specified extension
-- Searches upward from the given filepath until root directory
-- @param filepath: Starting path to search from
-- @param extension: File extension to look for
-- @return: directory, full_path if found, nil, nil otherwise
local function find_file_with_extension(filepath, extension)
    if not filepath or not extension then
        return nil, nil
    end
    
    local current_dir = vim.fn.fnamemodify(filepath, ":h")
    local parent_dir = vim.fn.fnamemodify(current_dir, ":h")
    -- Check if the file exists in the current directory
    local filename = vim.fn.fnamemodify(filepath, ":t")

    local full_path = check_extension_in_directory(current_dir, extension)
    if full_path then
        return current_dir, full_path
    end

    -- Recursively check parent directories until we find the file or reach the root directory
    if current_dir ~= parent_dir then
        return find_file_with_extension(parent_dir .. "/" .. filename, extension)
    end

    -- File not found
    return nil, nil
end

-- Gets the installation directory of the Unreal.nvim plugin
-- @return: Path to the plugin installation directory
local function GetInstallDir()
    local packer_install_dir = vim.fn.stdpath('data') .. '/site/pack/packer/start/'
    return packer_install_dir .. "Unreal.nvim//"
end

-- Splits a string into an array of lines
-- @param str: The string to split
-- @return: Array of lines
local function SplitString(str)
    if not str then
        return {}
    end
    -- Split a string into lines
    local lines = {}
    for line in string.gmatch(str, "[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

-- Module exports
return {
    MakeUnixPath = MakeUnixPath,
    EscapePath = EscapePath,
    file_exists = file_exists,
    EnsureDirPath = EnsureDirPath,
    IsEngineFile = IsEngineFile,
    check_extension_in_directory = check_extension_in_directory,
    find_file_with_extension = find_file_with_extension,
    GetInstallDir = GetInstallDir,
    SplitString = SplitString
}
