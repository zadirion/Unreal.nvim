-- utils/msvc_env.lua
local M = {}

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function split_semis(s)
  if not s or s == "" then return {} end
  return vim.split(s, ";", { trimempty = true, plain = true })
end

local function find_vswhere()
  local candidates = {
    [[C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe]],
    [[C:\Program Files\Microsoft Visual Studio\Installer\vswhere.exe]],
  }
  for _, p in ipairs(candidates) do
    if vim.uv.fs_access(p, "R") then return p end
  end
  -- Try PATH
  local out = vim.fn.systemlist([[where vswhere.exe]])
  if out and #out > 0 then return trim(out[1]) end
  return nil
end

local function find_dev_cmds()
  local vswhere = find_vswhere()
  if not vswhere then return nil, nil end
  local args = table.concat({
    '"' .. vswhere .. '"',
    "-latest",
    "-products", "*",
    "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "-property", "installationPath",
  }, " ")
  local vsroot = trim(vim.fn.system(args))
  if vsroot == "" then return nil, nil end

  local vsdevcmd = vsroot .. [[\Common7\Tools\VsDevCmd.bat]]
  local vcvarsall = vsroot .. [[\VC\Auxiliary\Build\vcvarsall.bat]]

  local have_vsdev = vim.uv.fs_access(vsdevcmd, "R")
  local have_vcvars = vim.uv.fs_access(vcvarsall, "R")
  return have_vsdev and vsdevcmd or nil, have_vcvars and vcvarsall or nil
end

local function capture_env_from_bat(bat, argline)
  -- IMPORTANT: use `call` so the batch sets env in the current cmd process.
  -- Then `&& set` to dump that env; we capture stdout.
  local cmd = string.format([[cmd /V:ON /E:ON /C "call "%s" %s >nul && set"]], bat, argline or "")
  local lines = vim.fn.systemlist(cmd)
  local env = {}
  for _, line in ipairs(lines or {}) do
    local k, v = line:match("^(.-)=(.*)$")
    if k and v then env[k:upper()] = v end
  end
  return env
end

local function get_env(arch)
  arch = arch or "x64"
  local vsdevcmd, vcvarsall = find_dev_cmds()
  if vsdevcmd then
    -- VsDevCmd supports switches; set host+target arch explicitly.
    return capture_env_from_bat(vsdevcmd, ("-arch=%s -host_arch=%s"):format(arch, arch))
  elseif vcvarsall then
    -- vcvarsall takes target arch as positional (x64/x86/arm64, etc.)
    return capture_env_from_bat(vcvarsall, arch)
  else
    error("Could not locate VsDevCmd.bat or vcvarsall.bat via vswhere.")
  end
end

function M.get_include_paths(opts)
  local env = get_env(opts and opts.arch or "x64")
  return split_semis(env.INCLUDE)
end

function M.get_lib_paths(opts)
  local env = get_env(opts and opts.arch or "x64")
  return split_semis(env.LIB)
end

function M.clang_isystem_flags(opts)
  return vim.tbl_map(function(p) return ('-isystem"%s"'):format(p) end, M.get_include_paths(opts))
end

function M.clang_L_flags(opts)
  return vim.tbl_map(function(p) return ('-L"%s"'):format(p) end, M.get_lib_paths(opts))
end

function M.clang_flag_strings(opts)
  return table.concat(M.clang_isystem_flags(opts), " "),
         table.concat(M.clang_L_flags(opts), " ")
end

-- Add this helper above get_msvc_version()
local function run_in_vs_env(arch, command)
    arch = arch or "x64"
    local vsdevcmd, vcvarsall = find_dev_cmds()
    local bat, args
    if vsdevcmd then
      bat, args = vsdevcmd, ("-arch=%s -host_arch=%s"):format(arch, arch)
    elseif vcvarsall then
      bat, args = vcvarsall, arch
    else
      return nil, "Could not locate VsDevCmd.bat or vcvarsall.bat via vswhere."
    end
    -- Run the command in the SAME cmd after setting env via `call`.
    local cmd = string.format([[cmd /V:ON /E:ON /C "call "%s" %s >nul && %s"]], bat, args, command)
    local res = vim.fn.systemlist(cmd)
    local ok = (vim.v.shell_error == 0) or (res and #res > 0)
    return ok and res or nil, ok and nil or "command failed"
  end
  
  -- Replace your get_msvc_version() with this:
  function M.get_msvc_version(opts)
    opts = opts or {}
    local arch = opts.arch or "x64"
  
    -- 1) Preferred: run `cl` inside a temporary VS dev shell and parse its banner.
    local out, err = run_in_vs_env(arch, "cl")
    if out then
      for _, line in ipairs(out) do
        -- Examples:
        --   Microsoft (R) C/C++ Optimizing Compiler Version 19.39.33523 for x64
        --   Microsoft (R) C/C++ Optimizing Compiler Version 19.41.34120 for x64
        local major, minor = line:match("Version%s+([0-9]+)%.([0-9]+)")
        if major and minor then
          return major .. "." .. minor
        end
      end
    end
  
    -- 2) Fallback: derive from VCToolsVersion captured via env (14.xx → 19.xx)
    --    This avoids depending on `cl` being invocable.
    local env = (function()
      local ok_env
      ok_env = pcall(function() env = get_env(arch) end)
      return env or {}
    end)()
  
    local vc = env.VCTOOLSVERSION -- e.g. "14.39.33519"
    if vc then
      local tmajor, tminor = vc:match("^([0-9]+)%.([0-9]+)")
      if tmajor and tminor then
        -- MSVC compiler major is always 19 when toolset major is 14 (VS 2015+).
        local msvc_major = (tonumber(tmajor) >= 14) and 19 or 18 -- ultra-defensive
        return string.format("%d.%s", msvc_major, tminor)
      end
    end
  
    -- 3) Give up gracefully.
    return nil, err or "Unable to determine MSVC version"
  end
  
return M
