FROM ubuntu:focal
# TODO: is this backward compatible on linux?

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /opt/godot-gdnative-exec

RUN apt update && apt install -y build-essential mingw-w64-tools mingw-w64 gcc-mingw-w64 mingw-w64-common scons git
