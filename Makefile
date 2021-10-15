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
BIN_DIR=bin

WARNS = -Wall -Wno-parentheses

LIBNAME=godot-exec
ifndef TARGET_DIR
TARGET_DIR=bin
endif
ifdef PLATFORM
PLATFORMS=$(PLATFORM)
else
PLATFORMS=windows osx linux
endif

uid=$(shell id -u)
gid=$(shell id -g)

INCLUDES=godot-headers

CXX = g++
CXX_CONTAINER_TAG=godot-gdnative-exec-mingw
CXX_CONTAINER_STAMP=$(OBJ_DIR)/$(CXX_CONTAINER_TAG).stamp
CXX_windows=bin/x86_64-w64-mingw32-g++
AR_windows=bin/x86_64-w64-mingw32-ar
RANLIB_windows=bin/x86_64-w64-mingw32-ranlib
CXX_CONTAINER_windows=$(CXX_CONTAINER_STAMP)

RUN_DOCKERIZED=bin/run-docker-tool
BASH_DOCKERIZED=bin/bash
#RC = windres

CPP_BINDINGS_PATH=godot-cpp
GODOT_INCLUDES=$(addprefix -I$(CPP_BINDINGS_PATH)/,include/ include/core/ include/gen/ godot-headers/)
CFLAGS = -O3 -std=c++17 ${WARNS} $(GODOT_INCLUDES)
LDFLAGS_windows = -shared -s -Wl,--subsystem,windows,--out-implib,lib/lib$(LIBNAME).a -lmingw32

# TODO: add windows32 and linux32 and osx_native ?
.PHONY: $(PLATFORMS) all clean distclean

default: all

all: $(PLATFORMS)
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

$(TARGET_DIR):
	mkdir -p "$@"
$(OBJ_DIR):
	mkdir -p "$@"
$(LIB_DIR):
	mkdir -p "$@"
ifneq ($(BIN_DIR),$(TARGET_DIR))
$(BIN_DIR):
	mkdir -p "$@"
endif

GODOT_CPP_SUBMODULE=godot-cpp/.gitattributes
GODOT_CPP_GEN=godot-cpp/src/gen

$(GODOT_CPP_SUBMODULE):
	git submodule update --init $@

# TODO: does + make scons aware of the job server? or should we just use nproc
# TODO: multiplatform?
$(GODOT_CPP_GEN): $(GODOT_CPP_SUBMODULE) | $(CXX_windows) $(AR_windows) $(RANLIB_windows)
	+export PATH=${PATH}:$(CURDIR)/$(BIN_DIR);cd godot-cpp; set +x; \
	scons generate_bindings=yes platform=windows

$(RUN_DOCKERIZED): $(CXX_CONTAINER_STAMP) | $(BIN_DIR)
	echo "docker run $$([ -t 0 ] && echo '-it') \
		-v $(CURDIR):$(CURDIR) -w \$${PWD} -u $$(id -u):$$(id -g) \
		$(CXX_CONTAINER_TAG) \"\$$(basename \$$0)\" \"\$$@\" " \
		> $@ && chmod +x $@

$(CXX_windows) $(AR_windows) $(RANLIB_windows) $(BASH_DOCKERIZED): $(CXX_CONTAINER_windows) $(RUN_DOCKERIZED)
	ln -fs $(notdir $(RUN_DOCKERIZED)) $@

$(CXX_CONTAINER_STAMP): Dockerfile $(OBJ_DIR)
	docker build . -t $(CXX_CONTAINER_TAG) && docker image ls $(CXX_CONTAINER_TAG) -q > $@

SRCS=$(wildcard src/*.cpp)

define OBJS
OBJS_$(1) = $$(SRCS:src/%.cpp=$$(OBJ_DIR)/$(1)/%.o)

$$(if $$(CXX_$(1)),,$$(eval CXX_$(1)=$(CC)))
$$(if $$(LDFLAGS_$(1)),,$$(eval LDFLAGS_$(1)=$(LDFLAGS)))
$$(if $$(CFLAGS_$(1)),,$$(eval CFLAGS_$(1)=$(CFLAGS)))

ifneq ($(DEBUG_INFO),)
$$(info obj_dir=$$(OBJ_DIR)/$(1))
$$(info LIB_NAME_$(1)=$$(LIB_NAME_$(1)))
$$(info OBJS_$(1)=$$(OBJS_$(1)))
$$(info CXX_$(1)=$$(CXX_$(1)))
$$(info LDFLAGS_$(1)=$$(LDFLAGS_$(1)))
$$(info CFLAGS_$(1)=$$(CFLAGS_$(1)))
endif

$$(OBJ_DIR)/$(1):
	mkdir -p "$$@"

$$(OBJ_DIR)/$(1)/%.o: src/%.cpp | $(OBJ_DIR)/$(1) $(CXX_$(1)) $(GODOT_CPP_GEN)
	$$(CXX_$(1)) $$(CFLAGS_$(1)) -c "$$<" -o "$$@"

$$(LIB_NAME_$(1)): $$(OBJS_$(1)) | $(LIB_DIR) $(TARGET_DIR) $(CXX_$(1)) $(GODOT_CPP_GEN)
	$$(CXX_$(1)) "$$^" -o "$$@" $$(LDFLAGS_$(1))

endef

# DEBUG and platform loop

ifneq ($(DEBUG_INFO),)
$(info PLATFORMS=$(PLATFORMS))
$(info TARGET_DIR=$(TARGET_DIR))
$(info GODOT_INCLUDES=$(GODOT_INCLUDES))
endif

$(foreach platform,$(PLATFORMS),$(eval $(call OBJS,$(platform))))
