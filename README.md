# Unreal.nvim
Unreal Engine support for Neovim
![image](https://raw.githubusercontent.com/zadirion/Unreal.nvim/main/image.png)

**Requirements**

- make sure you install  the clangd support component through Visual Studio Setup, and make sure the installed clang++.exe is in your system path env variable. Needs to be added manually to path, the installer does not do that
- has been tested with Unreal Engine 5.1 and 5.2. Unsure what, if any other versions work
- (optional) If you don't already have your own configuration, I recommend you use my neovim configuration specialized for development in Unreal Engine https://github.com/zadirion/UnrealHero.nvim

**Installation**

Install with packer:
```
  use {'zadirion/Unreal.nvim',
    requires =
    {
        {"tpope/vim-dispatch"}
    }
  }
```

While having any unreal engine c++ source file open in Neovim, run the following command:
```
:UnrealGen
```
When you run it for the first time, it will open a configuration file in a new buffer and ask you to set the path to Unreal Engine. After doing that and saving the file, run :UnrealGen again

From here onwards, :UnrealGen will always ask you which target to generate compile_commands.json for. Just input the number corresponding to the desired configuration, and it will generate the json right next to the uproject

This should cause your LSP to start recognizing the Unreal types, including the ones from .generated.h files.

**Commands**

- `:UnrealGen` generates the compile_commands.json file so your LSP can properly parse the source code
- `:UnrealBuild` builds the project with unreal
- `:UnrealRun` runs the project. It does not build it even if the source is out of date
- `:UnrealCD` sets the current directory to the root folder of the unreal project (the one with the .uproject in it). I personally use this so Telescope only searches in the project directory, making it faster, especially for live_grep

**Known Limitations**
- the generated plugin config file that sits next to the uproj (UnrealNvim.json) only contains the Editor and non-Editor Development target configurations. Feel free to add DebugGame, Test, Shipping targets to it, it should work in theory but I have not tested. Let me know if you encounter issues.

**Troubleshooting**
- if you notice that some of the symbols in your project are not recognize/found, it is possible clangd's index cache is broken somehow. You can find clang's cache in the .cache directory that will sit next to your .uproject. It is full of .idx files, each corresponding to a source code file in your project. Close nvim, delete the .cache directory, reopen vim, navigate to one of your project's files. It should trigger clangd to rebuild the index.
- Unreal.Nvim's log can be found in the nvim-data folder, but you need to enable logging first in nvim by setting `vim.g.unrealnvim_debug = true`
- clangd's LSP log can be found here: %localappdata%/nvim-data\lsp.log  If you are unsure whether clangd 'sees' some of your code, looking at this log helps
