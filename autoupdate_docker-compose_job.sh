#!/bin/bash

set -u
set -e
set -o pipefail

#WORKSPACE_PATH="${WORKSPACE}" # Set by Jenkins.
readonly WORKSPACE_PATH="/home/tomcat/tmp" # DEBUG
readonly SCRIPT_DIR_PATH="${WORKSPACE_PATH}/jenkins-scripts"
readonly DOCKER_COMPOSE_FILE_PATH="${HOME}/local/bin/docker-compose"
readonly DOCKER_COMPOSE_PREVIOUS_FILE_PATH="${DOCKER_COMPOSE_FILE_PATH}.previous"

readonly BASE_URL='https://github.com/docker/compose/releases/latest'
readonly DOCKER_COMPOSE_RELEASE_API_URL='https://api.github.com/repos/docker/compose/releases/latest'

readonly DOCKER_COMPOSE_LATEST_HASH_TEMPLATE_URL='https://github.com/docker/compose/releases/download/XXX/docker-compose-Linux-x86_64.sha256'
readonly DOCKER_COMPOSE_LATEST_RELEASE_TEMPLATE_URL='https://github.com/docker/compose/releases/download/XXX/docker-compose-Linux-x86_64'
readonly MARKER='XXX'

source "${SCRIPT_DIR_PATH}/common"

display 'fetching the latest release version number' 'info'
release_tag="$(wget -q -O - ${DOCKER_COMPOSE_RELEASE_API_URL} | jq -r '.tag_name')"

if [[ -z "${release_tag}" ]]; then
  display 'unable to fetch the latest release version number. abort' 'error'
  exit 1
else
  display "latest release is ${release_tag}" 'info'
fi

hash_url=$(echo "${DOCKER_COMPOSE_LATEST_HASH_TEMPLATE_URL}" | sed "s/${MARKER}/${release_tag}/1")

display 'comparing the hash' 'info'
cd "$(dirname ${DOCKER_COMPOSE_FILE_PATH})"
set +e
wget -q -O - "${hash_url}" | sed 's/docker-compose.*/docker-compose/1' | sha256sum -c > /dev/null 2>&1
returned_code=$?
set -e

if [ $returned_code -ne 0 ]; then
  docker_compose_url=$(echo "${DOCKER_COMPOSE_LATEST_RELEASE_TEMPLATE_URL}" | sed "s/${MARKER}/${release_tag}/1")
  mv "${DOCKER_COMPOSE_FILE_PATH}" "${DOCKER_COMPOSE_PREVIOUS_FILE_PATH}"
  display "downloading a new version of docker-compose (${docker_compose_url})." 'info'
  set +e # Handle errors.
  wget -q -O "${DOCKER_COMPOSE_FILE_PATH}" "${docker_compose_url}" || \
    {
      display 'something went wrong. revert' 'error' ; \
      mv "${DOCKER_COMPOSE_PREVIOUS_FILE_PATH}" "${DOCKER_COMPOSE_FILE_PATH}"
    }
  set -e
  chmod 700 "${DOCKER_COMPOSE_FILE_PATH}"
  exit 0
else
  display 'current docker-compose is up to date: nothing to do.' 'info'
  exit 0
fi
