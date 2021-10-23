#!/usr/bin/bash

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
set -eu

if [ -z "$IMAGE_TIME" ] || [ $IMAGE_TIME -lt $DOCKERFILE_TIME ]; then
    docker build . -t ${CONTAINER_TAG}
fi

# prevent mingw from converting them to windows path names
# only works in git bash?
export MSYS_NO_PATHCONV=1
# TODO: might need to write to a file and run the file if the arg list is too long or there are special chars?
docker run ${IT} --rm \
    -v ${DIR}:${DIR} -w ${PWD} -u $(id -u):$(id -g) \
    ${CONTAINER_TAG} "$TOOL" "$@"
