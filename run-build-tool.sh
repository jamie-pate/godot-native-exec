#!/usr/bin/bash

TOOL="$(basename $0)"
# this may not actually be a symlink on windows bash...
DIR="$(cd "$(dirname $0)/.." && echo $PWD)"
# Mingw needs winpty to run docker with a terminal
TTY=$(which winpty > /dev/null)
IT=$([ -t 0 ] && echo '-it')

set -eu
# prevent mingw from converting them to windows path names
# only works in git bash?
export MSYS_NO_PATHCONV=1
# TODO: might need to write to a file and run the file if the arg list is too long or there are special chars?
docker run ${IT} \
    -v ${DIR}:${DIR} -w ${PWD} -u $(id -u):$(id -g) \
    $(cat ${DIR}/obj/godot-gdnative-exec-build.stamp) "$TOOL" "$@"
