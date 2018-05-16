#!/bin/bash

set -e
set -u
set -o pipefail

BASE_DIR_PATH="$(pwd)"
SCRIPT_DIR_PATH="$(dirname $0)"; cd "${SCRIPT_DIR_PATH}"
readonly SCRIPT_DIR_PATH="$(pwd)" ; cd "${BASE_DIR_PATH}"

readonly COMMON_DIR_PATH="${JENKINS_HOME}/esgf" # Set by Jenkins
readonly SCRIPT_FILE_PATH="${COMMON_DIR_PATH}/jenkins-scripts/autoupdate_plugins_job.sh"

readonly CREDENTIAL_FILE_PATH="${COMMON_DIR_PATH}/.ipslbuild_credentials.secret"
readonly JENKINS_JAR_PATH="${COMMON_DIR_PATH}/jenkins-cli.jar"
readonly JENKINS_SERVER_URL='https://localhost:8443/jenkins'

function execute_cmd
{
  java -jar "${JENKINS_JAR_PATH}" -s "${JENKINS_SERVER_URL}" -noCertificateCheck -noKeyAuth -auth "$(cat ${CREDENTIAL_FILE_PATH})" ${1}
}

function main
{
  echo "> download jenkins-cli.jar"
  # Always download the last version of jenkins-cli.jar .
  #wget --no-check-certificate -q -O "${JENKINS_JAR_PATH}" https://localhost:8443/jenkins/jnlpJars/jenkins-cli.jar
  echo "> fetching the list of plugins."
  set +u
  set +e
  plugin_list=$(execute_cmd 'list-plugins' 2> /dev/null | grep -P '\(.+\)$' | awk '{print $1}' | tr '\n' ' ')
  if [ -z "${plugin_list}" ]; then
    echo "> nothing to update."
    exit 0
  else
    set -u
    set -e
    echo "> upgrading: ${plugin_list[*]}."
    execute_cmd "install-plugin ${plugin_list}"
    nohup sh -c "source \"${SCRIPT_FILE_PATH}\" ; execute_cmd 'safe-restart'" > /dev/null 2>&1 &
    exit $?
  fi
}
