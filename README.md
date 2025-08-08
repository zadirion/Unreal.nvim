# Unreal.nvim
Unreal Engine support for Neovim
![image](https://raw.githubusercontent.com/zadirion/Unreal.nvim/main/image.png)

**Requirements**

- make sure you have Visual Studio 2022 installed, and install the clangd component using the VS Installer
- download the latest version of llvm from https://github.com/llvm/llvm-project/releases/ and put it in `C:\Program Files\LLVM`. That's the only path where it detected
- Unreal.nvim has been tested with Unreal Engine 5.1 and 5.2. Unsure what, if any other versions work
- (optional) If you don't already have your own configuration, I recommend you use my neovim configuration specialized for development in Unreal Engine https://github.com/zadirion/UnrealHero.nvim

**Installation**

Install with packer:
```lua
  use {'zadirion/Unreal.nvim',
    requires =
    {
        {"tpope/vim-dispatch"},
		    {"neovim/nvim-lspconfig"}
    }
  }
```

**LSP Configuration**

You will want to configure your neovim LSP client to use the clangd we just downloaded:

```lua
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

require('lspconfig').clangd.setup{
	cmd = clangd_cmd,
	root_dir = require('lspconfig.util').root_pattern("compile_commands.json", ".git"),
	on_attach = on_attach,
}
```
Either source your init.lua or restart neovim, after which open a cpp file in your project and type :LspInfo and confirm you have an active client. And the command path points indeed to the clangd.exe inside program files' LLVM


**Initiall commands**

After installing with packer, open one of your Unreal project's source files, and run `UnrealGenWithEngine`. This will go through all the engine source files and will generate a compatible clang compile-command for each, so that the lsp can properly parse them.
It will take a long time to go through all of them, but you only need to run this command once, for your engine.
After running it for the first time, it will open a configuration file in a new buffer. In this buffer set the value of the `"EngineDir"` key to the path to Unreal Engine on your system. For example,

```jsonc
// UnrealNvim.json
{
  "version": "0.0.2",
  "EngineDir": "C:\\Program Files\\Epic Games\\UE_5.4\\",
  "Targets": [
    // ...
  ]
}
```

After doing that and saving the file, run `:UnrealGenWithEngine` again.

From here onwards, you can use `:UnrealGen` to generate the compile commands for just your project files. Feel free to do so every time you feel like the lsp is not picking up your symbols, such as when you added new source code files to your project or if you updated to latest changelist/commig in your version control. 
`:UnrealGen` will always ask you which target to generate compile_commands.json for. Just input the number corresponding to the desired configuration, and it will generate the json right next to the uproject

This should cause your LSP to start recognizing the Unreal types, including the ones from .generated.h files.

**Commands**
- `:UnrealGenWithEngine` generates the compile_commands.json and the compiler rsp files for the engine source code, so your LSP can properly parse the source code
- `:UnrealGen` generates the compile_commands.json and the compiler rps files for your project, so your LSP can properly parse the source code
- `:UnrealBuild` builds the project with unreal
- `:UnrealRun` runs the project. It does not build it even if the source is out of date
- `:UnrealCD` sets the current directory to the root folder of the unreal project (the one with the .uproject in it). I personally use this so Telescope only searches in the project directory, making it faster, especially for live_grep

**Known Limitations**
- you can't run with a debugger attached at the moment. I plan on adding support for starting the project with WinDbg attached. Currently if you want a debugger, you'll still have to run the project from Visual Studio and debug it there.
- the project is primarily developed for Windows. Unfortunately I do not have the time or motivation to maintain it for Linux, although I wish it worked there too. But since game development is primarily done on Windows in general, this is the primary target for the plugin. If any volunteer maintainers for Linux step forward, I'd be happy to collab with you
- you can only abort a build using `:AbortDispatch` and it will only work for the actual unreal build step, it won't work for the RSP generation build step

**Troubleshooting**
- if you notice that some of the symbols in your project are not recognize/found, it is possible clangd's index cache is broken somehow. You can find clang's cache in the .cache directory that will sit next to your .uproject. It is full of .idx files, each corresponding to a source code file in your project. Close nvim, delete the .cache directory, reopen vim, navigate to one of your project's files. It should trigger clangd to rebuild the index.
-Unreal.Nvim's log can be found in the nvim-data folder, but you need to enable logging first in nvim by setting `vim.g.unrealnvim_debug = true` clangd's LSP log can be found here: %localappdata%/nvim-data\lsp.log  If you are unsure whether clangd 'sees' some of your code, looking at this log helps
