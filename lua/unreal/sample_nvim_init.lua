-- init_vs_vim.lua
-- Generated from VsVim .vsvimrc to Neovim Lua.
-- Now includes packer.nvim bootstrap and plugin list for a turnkey setup.
vim.opt.swapfile = false
vim.opt.numberwidth = 5
vim.opt.signcolumn = "yes"


-- debuging
vim.g.unrealnvim_debug = true
vim.lsp.set_log_level('debug')


-- =============================
-- Packer Bootstrap
-- =============================
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
    vim.cmd('packadd packer.nvim')
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- Auto‑compile whenever this file is written.
vim.cmd([[
  augroup vsvim_packer
    autocmd!
    autocmd BufWritePost <afile> source <afile> | PackerCompile
  augroup END
]])

require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'            -- Packer manages itself
  use 'williamboman/mason.nvim'

  -- Core dependencies
  use 'nvim-lua/plenary.nvim'
  use 'nvim-tree/nvim-web-devicons'

  -- UI / Navigation
  use { 'nvim-telescope/telescope.nvim', tag = '0.1.5' }
  use 'simrat39/symbols-outline.nvim'
  use {'zadirion/Unreal.nvim',
	  requires =
	  {
		  {"tpope/vim-dispatch"},
		  {"neovim/nvim-lspconfig"}
	  }
  }

  -- Dev experience
  use 'numToStr/Comment.nvim'
  use { 'ThePrimeagen/refactoring.nvim', requires = 'nvim-lua/plenary.nvim' }

  -- avante.nvim (cursor integration)

  -- Required plugins
  use 'nvim-lua/plenary.nvim'
  use 'MunifTanjim/nui.nvim'
  use 'MeanderingProgrammer/render-markdown.nvim'

  -- Optional dependencies
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-nvim-lsp'   -- LSP source for cmp
  use 'hrsh7th/cmp-buffer'     -- buffer words
  use 'hrsh7th/cmp-path'       -- filesystem paths

  use 'nvim-tree/nvim-web-devicons' -- or use 'echasnovski/mini.icons'
  use 'HakonHarnes/img-clip.nvim'
  use 'zbirenbaum/copilot.lua'
  use 'stevearc/dressing.nvim' -- for enhanced input UI
  use 'folke/snacks.nvim' -- for modern input UI

  -- Avante.nvim with build process
  use {
    'yetone/avante.nvim',
    branch = 'main',
    run = 'make',
    config = function()
      require('avante').setup()
    end
  }

  
  -- Snippet engine & its cmp source
  use 'L3MON4D3/LuaSnip'
  use 'saadparwaiz1/cmp_luasnip'

  -- Automatically set up configuration after cloning packer
  if packer_bootstrap then
    require('packer').sync()
  end

end)

-- =============================
-- General Options
-- =============================
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- =============================
-- Leader Key
-- =============================
vim.g.mapleader = ' '

-- Convenience mapping wrapper
local map = function(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.noremap = opts.noremap ~= false
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- =============================
-- Basic Keymaps
-- =============================
map('i', 'jk', '<Esc>l') -- Exit insert with jk

-- Move selected text in visual mode
map('v', 'J', 'dpv')
map('v', 'K', 'dkPv')

-- =============================
-- "Visual Assist"‑style Commands (via LSP/Telescope etc.)
-- =============================
local lsp = vim.lsp.buf
map('n', '<leader>rai', lsp.code_action)
map('n', '<leader>raf', lsp.code_action)
map('n', '<leader>rmts', lsp.code_action)
map('n', '<leader>rmth', lsp.code_action)
map('n', '<leader>rr', lsp.rename)
map('n', '<leader>rdm', lsp.code_action)
map('n', '<leader>ref', lsp.code_action)
map('n', '<leader>rii', lsp.code_action)
map('n', '<leader>rba', lsp.code_action)
map('n', '<leader>rbr', lsp.code_action)
map('n', '<leader>rbt', lsp.code_action)

-- init.lua
local on_attach = function(_, bufnr)
  local opts = { buffer = bufnr, silent = true }
  -- plain LSP
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', '<leader>k', vim.diagnostic.open_float, {desc = "Show diagnostics at cursor"})
  vim.keymap.set("n", "<leader>o", "<cmd>ClangdSwitchSourceHeader<CR>", { desc = "Switch header/source (clangd)" })

  -- or with Telescope (nicer picker)
  -- vim.keymap.set('n', 'gd', require('telescope.builtin').lsp_definitions, opts)
end


-- Outline view
map('n', '<leader>oo', '<Cmd>SymbolsOutline<CR>')

-- Hover / quick info
map('n', '<leader>w', lsp.hover)

-- Telescope pickers
map('n', '<leader>pb', '<Cmd>Telescope lsp_references<CR>')
map('n', '<leader>pf', '<Cmd>Telescope lsp_references<CR>')
map('n', '<leader>pd', '<Cmd>Telescope lsp_definitions<CR>')

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })

-- Visual selections
map('v', '<leader>rss', ':sort i<CR>')
map('v', '<leader>cc', '<Plug>(comment_toggle_blockwise_visual)', { noremap = false, silent = true })
map('v', '<leader>rem', '<Cmd>lua require("refactoring").refactor("Extract Function")<CR>')

-- Quickfix navigation
map('n', '<C-n>', '<Cmd>cnext<CR>')
map('n', '<C-p>', '<Cmd>cprevious<CR>')

-- turn off search highlight
vim.keymap.set('n', '<C-;>', '<Cmd>nohlsearch<CR>')

-- mason config
require("mason").setup({
	ui = {
		icons = {
			package_installed = "✓",
			package_pending = "➜",
			package_uninstalled = "✗"
		}
	}
})


local clangd_cmd = {
  [[C:\Program Files\LLVM\bin\clangd.exe]],   -- use this clangd
  "--compile-commands-dir=.",                 -- adjust if your CDB lives elsewhere
  -- Helps clangd discover system includes from this LLVM toolchain
  [[--query-driver=C:\Program Files\LLVM\bin\clang*.exe]],
  -- Optional goodies:
  "--clang-tidy=1",
  "--log=verbose",
  "--pretty",
}

local capabilities = require('cmp_nvim_lsp').default_capabilities()

require('lspconfig').clangd.setup{
	cmd = clangd_cmd,
	root_dir = require('lspconfig.util').root_pattern("compile_commands.json", ".git"),
	on_attach = on_attach,
	capabilities = capabilities
}

-- plugin reload logic
-- Hot-reload a Lua plugin module (and its submodules)
local function reload_module(mod)
  if not mod or mod == "" then return end

  -- Prefer plenary's reloader if you have it
  local ok, reloader = pcall(require, "plenary.reload")
  if ok then
    reloader.reload_module(mod, true)
  else
    -- Manual cache bust: remove the module and its children from package.loaded
    local function escape_pat(s) return s:gsub("([^%w])", "%%%1") end
    local prefix = "^" .. escape_pat(mod) .. "%%."
    for k, _ in pairs(package.loaded) do
      if k == mod or k:match(prefix) then
        package.loaded[k] = nil
      end
    end
  end

  local ok2, result = pcall(require, mod)
  if not ok2 then
    vim.notify("Reload failed for '" .. mod .. "': " .. result, vim.log.levels.ERROR)
    return
  end
  vim.notify("Reloaded '" .. mod .. "'", vim.log.levels.INFO)
  return result
end

-- Prompt + bind to <leader>pr
local function prompt_reload()
  vim.ui.input({ prompt = "Plugin module to reload (e.g. telescope, gitsigns): " }, function(input)
    if input and input ~= "" then
      reload_module(input)
    end
  end)
end

vim.keymap.set("n", "<leader>pr", prompt_reload, { desc = "Reload a plugin module" })

vim.api.nvim_create_user_command("ReloadPlugin", function(opts)
  reload_module(opts.args)
end, { nargs = 1, complete = "lua" })

-- autocompletion and luasnip
cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
  -- This is the most important part for autocompletion
  sources = {
    { name = "nvim_lsp" }, -- This pulls suggestions directly from Clangd
    { name = "luasnip" },  -- Enables snippet completion
    { name = "buffer" },   -- Can also complete words from the current buffer
  },
  -- Define keymaps for interacting with the completion menu
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(), -- Manually trigger completion
    ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept the selected item
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  -- Configure snippet expansion
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
})



-- === End of file ===

