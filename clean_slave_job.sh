#!/bin/bash

set -u

readonly WORKSPACE_PATH="${WORKSPACE}" # Set by Jenkins.
readonly SCRIPT_DIR_PATH="${WORKSPACE_PATH}/jenkins-scripts"

source "${SCRIPT_DIR_PATH}/common"

display 'clean docker (do not care about errors)' 'info'

docker ps -aq | xargs docker rm --force
docker volume ls -q | xargs docker volume rm --force
docker image ls -q | xargs docker image rm --force

exit 0
