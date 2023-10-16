if 1 ~= vim.fn.has "nvim-0.7.0" then
  vim.api.nvim_err_writeln "Unreal.nvim requires at least nvim-0.7.0"
  return
end

if vim.g.loaded_unrealnvim == 1 then
  return
end
vim.g.loaded_unrealnvim = 1


vim.api.nvim_create_user_command("UnrealBuild", function(opts)
    require("unreal.commands").generateCommands(opts)
end, {
})

function setup(args)
    print("setting up plugin")
end
