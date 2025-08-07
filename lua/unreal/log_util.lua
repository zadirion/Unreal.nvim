-- Logging utility functions for Unreal.nvim
-- Contains logging functionality with different verbosity levels

-- Log level constants for different verbosity levels
local kLogLevel_Error = 1
local kLogLevel_Warning = 2
local kLogLevel_Log = 3
local kLogLevel_Verbose = 4
local kLogLevel_VeryVerbose = 5

-- Path to the log file for debugging
local logFilePath = vim.fn.stdpath("data") .. '/unrealnvim.log'

-- Logs a message with specified verbosity level if debugging is enabled
-- @param verbosity: The log level (1-5)
-- @param message: The message to log
local function logWithVerbosity(verbosity, message)
    if not vim.g.unrealnvim_debug then return end
    local cfgVerbosity = kLogLevel_Log
    if vim.g.unrealnvim_loglevel then
        cfgVerbosity = vim.g.unrealnvim_loglevel
    end
    if verbosity > cfgVerbosity then return end

    local file = nil
    if Commands and Commands.logFile then
        file = Commands.logFile
    else
        file = io.open(logFilePath, "a")
    end

    if file then
        local time = os.date('%m/%d/%y %H:%M:%S');
        file:write("["..time .. "]["..verbosity.."]: " .. message .. '\n')
    end
end

-- Logs a message at the default log level
-- @param message: The message to log
local function log(message)
    if not message then
        logWithVerbosity(kLogLevel_Error, "message was nill")
        return
    end

    logWithVerbosity(kLogLevel_Log, message)
end

-- Logs an error message at error level
-- @param message: The error message to log
local function logError(message)
    logWithVerbosity(kLogLevel_Error, message)
end

-- Prints and logs a message (combines print and log)
-- @param a: First part of the message
-- @param b: Second part of the message (optional)
local function PrintAndLogMessage(a,b)
    if a and b then
        log(tostring(a)..tostring(b))
    elseif a then
        log(tostring(a))
    end
end

-- Prints and logs an error message (combines print and log with error prefix)
-- @param a: First part of the error message
-- @param b: Second part of the error message (optional)
local function PrintAndLogError(a,b)
    if a and b then
        local msg = "Error: "..tostring(a)..tostring(b)
        print(msg)
        log(msg)
    elseif a then
        local msg = "Error: ".. tostring(a)
        print(msg)
        log(msg)
    end
end

-- Module exports
return {
    kLogLevel_Error = kLogLevel_Error,
    kLogLevel_Warning = kLogLevel_Warning,
    kLogLevel_Log = kLogLevel_Log,
    kLogLevel_Verbose = kLogLevel_Verbose,
    kLogLevel_VeryVerbose = kLogLevel_VeryVerbose,
    logWithVerbosity = logWithVerbosity,
    log = log,
    logError = logError,
    PrintAndLogMessage = PrintAndLogMessage,
    PrintAndLogError = PrintAndLogError
}
