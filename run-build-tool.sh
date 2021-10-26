#!/usr/bin/bash

# If we are running inside mintty we need to prefix the docker command with winpty.exe
# unfortunately it does not support MSYS_NO_PATHCONV or MSYS2_ARG_CONV_EXCL
# the vscode terminal on windows doesn't have this issue.
winpty_docker() {
    realdocker='docker.exe'
    # prevent mingw from converting paths to windows path names
    TMPFILE=$(mktemp /tmp/argsXXXXX.txt)
    printf "%s\0" "$@" > $TMPFILE
    winpty bash -c "xargs -0a $TMPFILE '$realdocker'"
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

DOCKER=docker
if [[ "$TERM_PROGRAM" == "mintty" ]]; then
    DOCKER=winpty_docker
fi
set -eu

if [ -z "$IMAGE_TIME" ] || [ $IMAGE_TIME -lt $DOCKERFILE_TIME ]; then
    docker build . -t ${CONTAINER_TAG}
fi

export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"

$DOCKER run ${IT} --rm \
    -v ${DIR}:${DIR} -w ${PWD} -u $(id -u):$(id -g) \
    ${CONTAINER_TAG} "$TOOL" "$@"
#$WINPTY docker.exe 
