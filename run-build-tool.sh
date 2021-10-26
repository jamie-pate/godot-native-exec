#!/usr/bin/bash

docker() {
    realdocker='docker.exe'
    # prevent mingw from converting paths to windows path names
    export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"
    TMPFILE=$(mktemp /tmp/argsXXXXX.txt)
    printf "%s\0" "$@" > $TMPFILE
    $WINPTY bash -c "xargs -0a $TMPFILE '$realdocker'"
    rm $TMPFILE
}

TOOL="$(basename $0)"
# this may not actually be a symlink on windows bash...
DIR="$(cd "$(dirname $0)/.." && echo $PWD)"
# Mingw needs winpty to run docker with a terminal
TTY=$(which winpty > /dev/null)
IT=$([ -t 0 ] && echo '-it')

CONTAINER_TAG=godot-gdnative-exec-build
# docker and make don't really mix well, just take care of docker in this script
IMAGE_TIME=$(date -d "$(docker image ls ${CONTAINER_TAG} --format "{{.CreatedAt}}" | awk {'print $1 " " $2'})" +%s)
DOCKERFILE_TIME=$(stat ${DIR}/Dockerfile --format %Y)

WINPTY=
if [[ "$TERM_PROGRAM" == "mintty" ]]; then
    WINPTY=winpty
fi
set -eu

if [ -z "$IMAGE_TIME" ] || [ $IMAGE_TIME -lt $DOCKERFILE_TIME ]; then
    docker build . -t ${CONTAINER_TAG}
fi

export MSYS_NO_PATHCONV=1

docker run ${IT} --rm \
    -v ${DIR}:${DIR} -w ${PWD} -u $(id -u):$(id -g) \
    ${CONTAINER_TAG} "$TOOL" "$@"
#$WINPTY docker.exe 
