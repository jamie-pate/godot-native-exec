#!/usr/bin/bash
TOOL="$(basename $0)"
SCRIPT=$0
set -eu
while [ -h "$SCRIPT" ]; do
    DIR="$(cd "$(dirname $SCRIPT)" && pwd)"
    SCRIPT="$DIR/$(readlink "$SCRIPT")"
done

DIR="$(cd "$(dirname $SCRIPT)" && pwd)"

docker run $([ -t 0 ] && echo '-it') \
    -v ${DIR}:${DIR} -w ${PWD} -u $(id -u):$(id -g) \
    $(cat ${DIR}/obj/godot-gdnative-exec-build.stamp) "$TOOL" "$@"
