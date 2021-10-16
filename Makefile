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
# add platforms here
ifndef PLATFORM
PLATFORM=windows
endif

TOOL_PREFIX=
ifeq ($(PLATFORM),windows)
TOOL_PREFIX=$(TOOLS_DIR)/x86_64-w64-mingw32-
endif

# build tools
CXX=$(TOOL_PREFIX)g++
AR=$(TOOL_PREFIX)ar
RANLIB=$(TOOL_PREFIX)ranlib
OBJDUMP=$(TOOL_PREFIX)objdump
BASH_DOCKERIZED=$(TOOLS_DIR)/bash

BUILD_TOOLS_LINKS=$(CXX) $(AR) $(RANLIB)
EXTRA_TOOLS_LINKS=$(BASH_DOCKERIZED) $(OBJDUMP)
BUILD_TOOLS=$(CXX_CONTAINER_IMAGE) $(BUILD_TOOLS_ONLY)

# docker container. The image id is written to the stamp file
CXX_CONTAINER_TAG=godot-gdnative-exec-build
CXX_CONTAINER_STAMP=$(OBJ_DIR)/$(CXX_CONTAINER_TAG).stamp
CXX_CONTAINER_IMAGE=$(CXX_CONTAINER_STAMP)

# script that runs tools from inside the docker container against our code
RUN_DOCKERIZED=run-build-tool.sh
#RC = windres

GODOT_INCLUDES=$(addprefix -Igodot-cpp/,include/ include/core/ include/gen/ godot-headers/)

CFLAGS = -O3 -std=c++17 ${WARNS} $(GODOT_INCLUDES)
# TODO: separate ldflags per platform
LDFLAGS = -shared -s -Wl,--subsystem,windows,--out-implib,lib/lib$(LIBNAME).a -lmingw32

LIB_NAME_windows=$(TARGET_DIR)/$(LIBNAME).dll
# TODO?
LIB_NAME_osx=$(TARGET_DIR)/$(LIBNAME).dylib
LIB_NAME_linux=$(TARGET_DIR)/$(LIBNAME).so

# godot-cpp dependencies
GODOT_CPP_SUBMODULE=godot-cpp/.gitattributes
GODOT_CPP_GEN_DIR=godot-cpp/src/gen

__GODOT_CPP_GEN_CLASSES=__init_method_bindings __register_types
# Scrape generated class names from api.json and add them as dependencies
# TODO: This grep|sed combo is probably super fragile?
GODOT_CPP_GEN_CLASSES=$(__GODOT_CPP_GEN_CLASSES) $(shell grep -P '^\t\t"name": "' godot-cpp/godot-headers/api.json | sed -E 's/^\t\t"name": "_?([^"]+)",?/\1/g')
GODOT_CPP_GEN_CPP=$(addprefix godot-cpp/src/gen/,$(addsuffix .cpp,$(GODOT_CPP_GEN_CLASSES)))
GODOT_CPP_GEN_OBJS=$(addprefix godot-cpp/src/gen/,$(addsuffix .o,$(GODOT_CPP_GEN_CLASSES)))
GODOT_CPP_CORE_CPP=$(wildcard godot-cpp/src/core/*.cpp)
GODOT_CPP_CORE_OBJS=$(GODOT_CPP_CORE_CPP:%.cpp=%.o)
GODOT_CPP_OBJS=$(GODOT_CPP_GEN_OBJS) $(GODOT_CPP_CORE_OBJS)

# Project dependencies
SRCS=$(wildcard src/*.cpp)
OBJS=$(SRCS:src/%.cpp=$(OBJ_DIR)/$(PLATFORM)/%.o)
DEPS=$(SRCS:src/%.cpp=$(OBJ_DIR)/%.d)

ifneq ($(DEBUG_INFO),)
$(info GODOT_CPP_GEN_CPP=$(wordlist 1,5,$(GODOT_CPP_GEN_CPP)))
$(info GODOT_CPP_CORE_OBJS=$(GODOT_CPP_CORE_OBJS))
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

### Phony RULES

.PHONY: $(PLATFORM) all clean distclean build_tools extra_tools

default: all

all: $(PLATFORM)
clean:
	rm -rf $(TARGET_DIR)
	rm -rf $(OBJ_DIR)

distclean: clean
	rm -rf godot-cpp

windows: $(LIB_NAME_windows)
osx: $(LIB_NAME_osx)
linux: $(LIB_NAME_linux)

# containerized build tools
build_tools: $(BUILD_TOOLS_ONLY)
# containerized toolchain tools and bash, etc
extra_tools: $(EXTRA_TOOLS_LINKS)

### DIR rules

$(TARGET_DIR) $(OBJ_DIR) $(LIB_DIR) $(TOOLS_DIR) $(OBJ_DIR)/$(PLATFORM):
	mkdir -p "$@"

### TOOL rules

$(BUILD_TOOLS_ONLY) $(EXTRA_TOOLS_LINKS): $(RUN_DOCKERIZED) | $(TOOLS_DIR)
	ln -fs ../$(notdir $(RUN_DOCKERIZED)) $@

$(CXX_CONTAINER_IMAGE): Dockerfile $(OBJ_DIR)
	docker build . -t $(CXX_CONTAINER_TAG) && docker image ls $(CXX_CONTAINER_TAG) -q > $@

### godot-cpp rules

$(GODOT_CPP_SUBMODULE):
	git submodule update --init --recursive $(dir $@)

# TODO: can + make scons aware of the job server? using nproc for now.
# Without -j is very slow.
# TODO: multiplatform? mount godot-cpp/src/gen in a
# separate volume inside the docker container for each platform?

# reset -I fixes the terminal which gets bunged up by this step...
$(GODOT_CPP_GEN_CPP) $(GODOT_CPP_OBJS) $(GODOT_CPP_GEN_DIR)&: $(GODOT_CPP_SUBMODULE) | $(BUILD_TOOLS)
	export PATH=${PATH}:$(CURDIR)/$(TOOLS_DIR);cd godot-cpp; \
	scons generate_bindings=yes platform=$(PLATFORM) -j$$(nproc) ; reset -I

### Compile Rules

$(OBJ_DIR)/%.d: src/%.cpp | $(OBJ_DIR) $(BUILD_TOOLS)
	$(CXX) -MM $< > $@
	@$(CXX) -MM $< -MT $*.d >> $@

$(OBJ_DIR)/$(PLATFORM)/%.o: src/%.cpp | $(OBJ_DIR)/$(PLATFORM) $(BUILD_TOOLS) $(GODOT_CPP_GEN_CPP)
	$(CXX) $(CFLAGS) -c "$<" -o "$@"

$(LIB_NAME_$(PLATFORM)): $(OBJS) $(GODOT_CPP_OBJS) | $(LIB_DIR) $(TARGET_DIR) $(BUILD_TOOLS) $(GODOT_CPP_GEN_DIR)
	$(CXX) $^ -o "$@" $(LDFLAGS)

include $(DEPS)
