# Godot Native Exec

A gdnative extension for executing console programs on windows without popping up the cmd.exe window.

## Build Requirements

* Docker
* Gnu Make

## Building

Build with make:
* `make`: normal build using dockerized toolchain
* `make DEBUG=1`: to build with symbols and disable optimizations.
* `make NATIVE_TOOLCHAIN=1`: to avoid the dockerized toolchain and use the native tools in `$PATH`.

## Debugging

Debugging requires gdb since everything is compiled with MingGW64. The easiest way to debug is to use vscode and follow these [configuration steps](https://code.visualstudio.com/docs/cpp/config-mingw).

You should be able to press F5 to debug. You may have to adjust the .vscode/launch.json
