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

WARNS = -Wall

LIBNAME=godot-exec
ifndef TARGET_DIR
TARGET_DIR=bin
endif
ifdef PLATFORM
PLATFORMS=$(PLATFORM)
else
PLATFORMS=windows osx linux
endif
ifneq ($(DEBUG_INFO),)
$(info PLATFORMS=$(PLATFORMS))
$(info TARGET_DIR=$(TARGET_DIR))
endif

uid=$(shell id -u)
gid=$(shell id -g)

INCLUDES=godot-headers

CC = gcc
CC_CONTAINER_TAG=godot-gdnative-exec-mingw
CC_CONTAINER_STAMP=$(OBJ_DIR)/$(CC_CONTAINER_TAG).stamp
CC_windows=docker run -v ${PWD}:${PWD} -w ${PWD} -u $(uid):$(gid) $(CC_CONTAINER_TAG) x86_64-w64-mingw32-gcc
CC_CONTAINER_windows=$(CC_CONTAINER_STAMP)
RC = windres

CFLAGS = -O3 -std=c99 ${WARNS} -Iinclude -Igodot-headers
LDFLAGS_windows = -shared -s -Wl,--subsystem,windows,--out-implib,lib/lib$(LIBNAME).a -lmingw32

# TODO: add windows32 and linux32 and osx_native ?
.PHONY: $(PLATFORMS) all clean

default: all

all: $(PLATFORMS)
clean:
	rm -rf $(TARGET_DIR)
	rm -rf $(OBJ_DIR)

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

$(CC_CONTAINER_STAMP): Dockerfile $(OBJ_DIR)
	docker build . -t $(CC_CONTAINER_TAG) && docker image ls $(CC_CONTAINER_TAG) -q > $@

SRCS=$(wildcard src/*.c)

define OBJS
OBJS_$(1) = $$(SRCS:src/%.c=$$(OBJ_DIR)/$(1)/%.o)

$$(if $$(CC_$(1)),,$$(eval CC_$(1)=$(CC)))
$$(if $$(LDFLAGS_$(1)),,$$(eval LDFLAGS_$(1)=$(LDFLAGS)))
$$(if $$(CFLAGS_$(1)),,$$(eval CFLAGS_$(1)=$(CFLAGS)))

ifneq ($(DEBUG_INFO),)
$$(info obj_dir=$$(OBJ_DIR)/$(1))
$$(info LIB_NAME_$(1)=$$(LIB_NAME_$(1)))
$$(info OBJS_$(1)=$$(OBJS_$(1)))
$$(info CC_$(1)=$$(CC_$(1)))
$$(info LDFLAGS_$(1)=$$(LDFLAGS_$(1)))
$$(info CFLAGS_$(1)=$$(CFLAGS_$(1)))
endif

$$(OBJ_DIR)/$(1):
	mkdir -p "$$@"

$$(OBJ_DIR)/$(1)/%.o: src/%.c | $(OBJ_DIR)/$(1) $(CC_CONTAINER_$(1))
	$$(CC_$(1)) $$(CFLAGS_$(1)) -c "$$<" -o "$$@"

$$(LIB_NAME_$(1)): $$(OBJS_$(1)) | $(LIB_DIR) $(TARGET_DIR) $(CC_CONTAINER_$(1))
	$$(CC_$(1)) "$$^" -o "$$@" $$(LDFLAGS_$(1))

endef

$(foreach platform,$(PLATFORMS),$(eval $(call OBJS,$(platform))))
