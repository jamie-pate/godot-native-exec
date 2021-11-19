# Godot Native Exec

A gdnative extension for executing console programs on windows without popping up the cmd.exe window.

## Build Requirements

* Docker *or* `mingw` toolchain, `scons`
* bash

## Building

Build with make:
* `make`: Normal build using your native toolchain.
* `make DEBUG=1`: Build with symbols and disable optimizations.
* `make TARGET_DIR=/path/to/addons/GodotNativeExec`: Install plugin into a different directory. (Use caution when using docker as this directory may be inside the container!)
* `./container-make.sh`: Build with dockerized toolchain.

The plugin artifacts will be installed in 

## Debugging

Debugging requires gdb since everything is compiled with MingGW64. The easiest way to debug is to use vscode and follow these [configuration steps](https://code.visualstudio.com/docs/cpp/config-mingw).

You should be able to press F5 to debug. You may have to adjust the .vscode/launch.json
