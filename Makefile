# Usage examples:
# make
# make PLATFORM=windows
# make DEBUG_INFO=1

ifndef TARGET_DIR
	TARGET_DIR=bin
endif
OBJ_DIR=obj
SRC_DIR=src
LIB_DIR=lib
TOOLS_DIR=tools

WARNS = -Wall -Wno-parentheses

LIBNAME=godot-exec
ifndef TARGET_DIR
TARGET_DIR=bin
endif
# windows (TODO: linux osx?)
ifndef PLATFORM
PLATFORM=windows
endif

uid=$(shell id -u)
gid=$(shell id -g)

INCLUDES=godot-headers

TOOL_PREFIX=

CXX = g++
CXX_CONTAINER_TAG=godot-gdnative-exec-build
CXX_CONTAINER_STAMP=$(OBJ_DIR)/$(CXX_CONTAINER_TAG).stamp
PREFIX=x86_64-w64-mingw32-
CXX=$(TOOL_PREFIX)g++
AR=$(TOOL_PREFIX)ar
RANLIB=$(TOOL_PREFIX)ranlib
CXX_CONTAINER_IMAGE=$(CXX_CONTAINER_STAMP)

RUN_DOCKERIZED=run-build-tool.sh
BASH_DOCKERIZED=$(TOOLS_DIR)/bash
#RC = windres

CPP_BINDINGS_PATH=godot-cpp
GODOT_INCLUDES=$(addprefix -I$(CPP_BINDINGS_PATH)/,include/ include/core/ include/gen/ godot-headers/)
CFLAGS = -O3 -std=c++17 ${WARNS} $(GODOT_INCLUDES)
LDFLAGS = -shared -s -Wl,--subsystem,windows,--out-implib,lib/lib$(LIBNAME).a -lmingw32


ifeq ($(PLATFORM),windows)
TOOL_PREFIX=$(TOOLS_DIR)/x86_64-w64-mingw32-
endif

# TODO: add windows32 and linux32 and osx_native ?
.PHONY: $(PLATFORM) all clean distclean

default: all

all: $(PLATFORM)
clean:
	rm -rf $(TARGET_DIR)
	rm -rf $(OBJ_DIR)

distclean: clean
	rm -rf godot-cpp

# mingw: https://github.com/TransmissionZero/MinGW-DLL-Example/blob/master/Makefile
LIB_NAME_windows=$(TARGET_DIR)/$(LIBNAME).dll

# TODO?
LIB_NAME_osx=$(TARGET_DIR)/$(LIBNAME).dylib
LIB_NAME_linux=$(TARGET_DIR)/$(LIBNAME).so

windows: $(LIB_NAME_windows)
osx: $(LIB_NAME_osx)
linux: $(LIB_NAME_linux)

$(TARGET_DIR) $(OBJ_DIR) $(LIB_DIR) $(TOOLS_DIR):
	mkdir -p "$@"

GODOT_CPP_SUBMODULE=godot-cpp/.gitattributes
GODOT_CPP_GEN=godot-cpp/src/gen

$(GODOT_CPP_SUBMODULE):
	git submodule update --init --recursive $(dir $@)

# TODO: does + make scons aware of the job server? or should we just use nproc.
# without -j is very slow.
# TODO: multiplatform? mount godot-cpp/src/gen in a
# separate volume inside the docker container for each platform?
# TODO: parse api.json and use that to determine if we need to run this?
# TODO: reset to fix the terminal which gets bunged up by this step...
# TODO: This grep|sed combo is probably super fragile?
GODOT_CPP_GEN_CLASSES=$(shell grep -P '^\t\t"name": "[^_]' godot-cpp/godot-headers/api.json  | sed -E 's/^\t\t"name": "([^"]+)",?/\1/g')
GODOT_CPP_GEN_CPP=$(addprefix godot-cpp/src/gen,$(addsuffix .cpp,$(GODOT_CPP_GEN_CLASSES)))
$(GODOT_CPP_GEN_CPP) $(GODOT_CPP_GEN)&: $(GODOT_CPP_SUBMODULE) | $(CXX) $(AR) $(RANLIB)
	export PATH=${PATH}:$(CURDIR)/$(TOOLS_DIR);cd godot-cpp; \
	scons generate_bindings=yes platform=$(PLATFORM) -j$$(nproc)

$(CXX) $(AR) $(RANLIB) $(BASH_DOCKERIZED): $(RUN_DOCKERIZED) | $(TOOLS_DIR)
	ln -fs ../$(notdir $(RUN_DOCKERIZED)) $@

$(CXX_CONTAINER_IMAGE): Dockerfile $(OBJ_DIR)
	docker build . -t $(CXX_CONTAINER_TAG) && docker image ls $(CXX_CONTAINER_TAG) -q > $@

SRCS=$(wildcard src/*.cpp)

TOOLS=$(CXX_CONTAINER_IMAGE) $(CXX) $(AR) $(RANLIB)
OBJS=$(SRCS:src/%.cpp=$(OBJ_DIR)/$(PLATFORM)/%.o)

ifneq ($(DEBUG_INFO),)
$(info GODOT_CPP_GEN_CPP=$(wordlist 1,5,$(GODOT_CPP_GEN_CPP)))
$(info PLATFORMS=$(PLATFORMS))
$(info TARGET_DIR=$(TARGET_DIR))
$(info GODOT_INCLUDES=$(GODOT_INCLUDES))
$(info OBJ_DIR/$(PLATFORM)=$(OBJ_DIR)/$(PLATFORM))
$(info LIB_NAME=$(LIB_NAME))
$(info OBJS=$(OBJS))
$(info CXX=$(CXX))
$(info LDFLAGS=$(LDFLAGS))
$(info CFLAGS=$(CFLAGS))
endif

$(OBJ_DIR)/$(PLATFORM):
	mkdir -p "$@"

$(OBJ_DIR)/$(PLATFORM)/%.o: src/%.cpp | $(OBJ_DIR)/$(PLATFORM) $(TOOLS) $(GODOT_CPP_GEN)
	$(CXX) $(CFLAGS) -c "$<" -o "$@"

$(LIB_NAME_$(PLATFORM)): $(OBJS) | $(LIB_DIR) $(TARGET_DIR) $(TOOLS) $(GODOT_CPP_GEN)
	$(CXX) "$^" -o "$@" $(LDFLAGS)
