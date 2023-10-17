# Unreal.nvim
Unreal Engine support for Neovim

**Requirements**

- make sure you install  the clangd support component through Visual Studio Setup, and make sure the installed clang++.exe is in your system path env variable. Needs to be added manually to path, the installer does not do that
- (optional) If you don't already have your own configuration, I recommend you use my neovim configuration specialized for development in Unreal Engine https://github.com/zadirion/UnrealHero.nvim
- has been tested with Unreal Engine 5.1 and 5.2. Unsure what, if any other versions work

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

![image](https://raw.githubusercontent.com/zadirion/Unreal.nvim/main/image.png)
