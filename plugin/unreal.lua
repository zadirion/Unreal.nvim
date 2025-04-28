if 1 ~= vim.fn.has("nvim-0.7.0") then
    vim.api.nvim_err_writeln("Unreal.nvim requires at least nvim-0.7.0")
    return
end

if vim.g.loaded_unrealnvim == 1 then
    return
end
vim.g.loaded_unrealnvim = 1

vim.api.nvim_create_user_command("UnrealGen", function(opts)
    require("unreal.commands").generateCommands(opts)
end, {})

vim.api.nvim_create_user_command("UnrealGenWithEngine", function(opts)
    if not opts then
        opts = {}
    end

    opts.WithEngine = true
    require("unreal.commands").generateCommands(opts)
end, {})

vim.api.nvim_create_user_command("UnrealBuild", function(opts)
    require("unreal.commands").build(opts)
end, {})

vim.api.nvim_create_user_command("UnrealRun", function(opts)
    require("unreal.commands").run(opts)
end, {})

vim.api.nvim_create_user_command("UnrealCD", function(opts)
    require("unreal.commands").SetUnrealCD(opts)
end, {})

function Setup(_)
    -- print("setting up plugin")
end
