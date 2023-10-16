# Unreal.nvim
Unreal Engine support for Neovim

Requirements:
- make sure you install  the clangd support component through Visual Studio Setup, and make sure the installed clang++.exe is in your system path env variable
- (optional) If you don't already have your own configuration, I recommend you use my neovim configuration specialized for development in Unreal Engine https://github.com/zadirion/UnrealHero.nvim
  
Install with packer:
```
{'zadirion/Unreal.nvim'}
```

While having any unreal engine c++ source file open in Neovim, run the following command:
```
:UnrealBuild
```
When you run it for the first time, it will open a configuration file in a new buffer and ask you to set the path to Unreal Engine. After doing that and saving the file, run :UnrealBuild again

From here onwards, :UnrealBuild will always ask you which target to generate compile_commands.json for. Just input the number corresponding to the desired configuration, and it will generate the json right next to the uproject

This should cause your LSP to start recognizing the Unreal types, including the ones from .generated.h files.
