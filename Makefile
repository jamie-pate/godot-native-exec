# Usage examples:
# make
# make PLATFORM=windows
# make DEBUG_INFO=1

ifndef TARGET_DIR
  TARGET_DIR=godot/addons/GodotNativeExec
endif


OPT=-O3
DEBUG_LDFLAGS=
DEBUG_CFLAGS=
CPPFLAGS=
LD_STRIP=-s
ifdef DEBUG
ifeq ($(DEBUG),1)
DEBUG_CFLAGS=-g
CPPFLAGS=-DDEBUG
DEBUG_LDFLAGS=-g
OPT=
LD_STRIP=
endif
endif
export PATH := $(PATH):$(CURDIR)/tools

CFLAGS=$(CPPFLAGS) $(DEBUG_CFLAGS) $(OPT) -std=c++17 -D_WIN32_WINNT=0x0600 $(WARNS) $(GODOT_INCLUDES) $(EXTRA_CFLAGS)
# TODO: separate ldflags per platform?
LDFLAGS=$(DEBUG_LDFLAGS) -shared -static $(LD_STRIP) -Wl,--subsystem,windows

OBJ_DIR=obj
SRC_DIR=src
TOOLS_DIR=tools

WARNS = -Wall -Wno-parentheses

LIBNAME=godot-native-exec


# windows (TODO: linux osx?)
# add platforms here
ifndef PLATFORM
PLATFORM=windows
endif

ifndef TOOL_SUFFIX
# could be '.exe' for msys2 toolchain on windows
TOOL_SUFFIX=
endif
ifndef TOOL_PREFIX
TOOL_PREFIX=
ifeq ($(PLATFORM),windows)
ifeq ($(NATIVE_TOOLCHAIN),)
# script that runs tools from inside the docker container against our code
RUN_DOCKERIZED=run-build-tool.sh
BASE_TOOLS_PREFIX=$(TOOLS_DIR)/
TOOL_PREFIX=$(BASE_TOOLS_DIR)x86_64-w64-mingw32-
endif
endif
endif

# build tools
CXX=$(TOOL_PREFIX)g++$(TOOL_SUFFIX)
AR=$(TOOL_PREFIX)ar$(TOOL_SUFFIX)
RANLIB=$(TOOL_PREFIX)ranlib$(TOOL_SUFFIX)
OBJDUMP=$(TOOL_PREFIX)objdump$(TOOL_SUFFIX)
BASH_DOCKERIZED=$(BASE_TOOLS_DIR)bash$(TOOL_SUFFIX)
SCONS=$(BASE_TOOLS_DIR)scons$(TOOL_SUFFIX)

ifneq ($(RUN_DOCKERIZED),)
# docker container. The image id is written to the stamp file
CXX_CONTAINER_TAG=godot-gdnative-exec-build
CXX_CONTAINER_STAMP=$(OBJ_DIR)/$(CXX_CONTAINER_TAG).stamp
CXX_CONTAINER_IMAGE=$(CXX_CONTAINER_STAMP)

BUILD_TOOLS_LINKS=$(CXX) $(AR) $(RANLIB) $(SCONS)
EXTRA_TOOLS_LINKS=$(BASH_DOCKERIZED) $(OBJDUMP)
BUILD_TOOLS=$(CXX_CONTAINER_IMAGE) $(BUILD_TOOLS_LINKS)
endif

GODOT_INCLUDES=$(addprefix -Igodot-cpp/,include/ include/core/ include/gen/ godot-headers/)

GDNS=godot-native-exec.gdns
GDNLIB=godot-native-exec.gdnlib
EXEC_THREAD=ExecThread.gd
ADDON_NAME=GodotNativeExec
GDNLIB_TARGET=$(TARGET_DIR)/$(GDNLIB)
GDNS_TARGET=$(TARGET_DIR)/$(GDNS)
EXEC_THREAD_TARGET=$(TARGET_DIR)/$(EXEC_THREAD)
CP_TARGETS=$(GDNLIB_TARGET) $(GDNS_TARGET) $(EXEC_THREAD_TARGET)

LIBNAME_windows=$(TARGET_DIR)/$(LIBNAME).dll
# TODO?
LIBNAME_osx=$(TARGET_DIR)/$(LIBNAME).dylib
LIBNAME_linux=$(TARGET_DIR)/$(LIBNAME).so

# godot-cpp dependencies
GODOT_CPP_SUBMODULE=godot-cpp/.gitattributes
GODOT_CPP_GEN_DIR=godot-cpp/src/gen

__GODOT_CPP_GEN_CLASSES=__init_method_bindings __register_types
# Scrape generated class names from api.json and add them as dependencies
# TODO: This grep|sed combo is probably super fragile?
GODOT_CPP_API_JSON=godot-cpp/godot-headers/api.json
GODOT_CPP_GEN_CLASSES=$(__GODOT_CPP_GEN_CLASSES) $(shell [ -f "$(GODOT_CPP_API_JSON)" ] && grep -P '^\t\t"name": "' "$(GODOT_CPP_API_JSON)" | sed -E 's/^\t\t"name": "_?([^"]+)",?/\1/g')
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

all: $(PLATFORM) $(CP_TARGETS)
clean:
	rm -rf $(TARGET_DIR)/* $(OBJ_DIR) $(TOOLS_DIR)

distclean: clean
	rm -rf godot-cpp

$(GDNLIB_TARGET): $(GDNLIB)
	cp $^ $@
$(GDNS_TARGET): $(GDNS)
	cp $^ $@
$(EXEC_THREAD_TARGET): $(EXEC_THREAD)
	cp $^ $@

windows: $(LIBNAME_windows)
osx: $(LIBNAME_osx)
linux: $(LIBNAME_linux)

# containerized build tools
build_tools: $(BUILD_TOOLS_LINKS)
# containerized toolchain tools and bash, etc
extra_tools: $(EXTRA_TOOLS_LINKS)

### DIR rules

$(TARGET_DIR) $(OBJ_DIR) $(TOOLS_DIR) $(OBJ_DIR)/$(PLATFORM):
	mkdir -p "$@"

### TOOL rules

ifneq ($(RUN_DOCKERIZED),)
$(BUILD_TOOLS_LINKS) $(EXTRA_TOOLS_LINKS): $(RUN_DOCKERIZED) | $(TOOLS_DIR)
	ln -fs ../$(notdir $(RUN_DOCKERIZED)) $@

$(CXX_CONTAINER_IMAGE): Dockerfile | $(OBJ_DIR)
	docker build . -t $(CXX_CONTAINER_TAG) && docker image ls $(CXX_CONTAINER_TAG) -q > $@
endif


### godot-cpp rules
$(GODOT_CPP_API_JSON): $(GODOT_CPP_SUBMODULE)
$(GODOT_CPP_SUBMODULE):
	git submodule update --init --recursive $(dir $@)

# TODO: can + make scons aware of the job server? using nproc for now.
# Without -j is very slow.
# TODO: multiplatform? mount godot-cpp/src/gen in a
# separate volume inside the docker container for each platform?

# reset -I fixes the terminal which gets bunged up by this step...
$(GODOT_CPP_GEN_CPP) $(GODOT_CPP_OBJS) $(GODOT_CPP_GEN_DIR)&: $(GODOT_CPP_API_JSON) | $(BUILD_TOOLS)
	cd godot-cpp; set -e; \
	$(SCONS) generate_bindings=yes platform=$(PLATFORM) use_mingw=yes -j$$(nproc) ; reset -I

### Compile Rules

$(OBJ_DIR)/%.d: src/%.cpp | $(OBJ_DIR) $(BUILD_TOOLS)
	$(CXX) $(CPPFLAGS) -MM $< > $@ && $(CXX) $(CPPFLAGS) -MM $< -MT $*.d >> $@ || (rm $@; false)

$(OBJ_DIR)/$(PLATFORM)/%.o: src/%.cpp | $(DEPS) $(OBJ_DIR)/$(PLATFORM) $(BUILD_TOOLS) $(GODOT_CPP_GEN_CPP)
	$(CXX) $(CFLAGS) -c "$<" -o "$@"

# save the list of .o files to a file because gnu make on windows may have a
# low limit on how many chars we are allowed. we need like 23888 chars.
# xargs --show-limits: Maximum length of command we could actually use: 19492
# @file is the answer! https://linux.die.net/man/1/ld
$(LIBNAME_$(PLATFORM)): $(OBJS) $(GODOT_CPP_OBJS) | $(DEPS) $(TARGET_DIR) $(BUILD_TOOLS)
	$(file > obj/link_objs,$^)
	$(CXX) @obj/link_objs -o "$@" $(LDFLAGS) && \
	rm obj/link_objs

-include $(DEPS)
