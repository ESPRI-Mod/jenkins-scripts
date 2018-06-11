#!/bin/bash

set -e
set -u
set -o pipefail

readonly WORKSPACE_PATH="${WORKSPACE}" # Set by Jenkins
readonly COMMON_DIR_PATH="${JENKINS_HOME}/esgf" # Set by Jenkins
readonly SCRIPT_DIR_PATH="${WORKSPACE_PATH}/jenkins-scripts"
readonly SCRIPT_FILE_PATH="${SCRIPT_DIR_PATH}/autoupdate_plugins_job.sh"

readonly CREDENTIAL_FILE_PATH="${COMMON_DIR_PATH}/.jenkins_token.secret"
readonly JENKINS_JAR_PATH="${WORKSPACE_PATH}/jenkins-cli.jar"
readonly JENKINS_SERVER_URL='https://localhost:8443/jenkins'

source "${SCRIPT_DIR_PATH}/common"

function execute_cmd
{
  java -jar "${JENKINS_JAR_PATH}" -s "${JENKINS_SERVER_URL}" -noCertificateCheck -noKeyAuth -auth "$(cat ${CREDENTIAL_FILE_PATH})" ${1}
}

function main
{
  display 'downloading jenkins-cli.jar' 'info'
  # Always download the last version of jenkins-cli.jar .
  wget --no-check-certificate -q -O "${JENKINS_JAR_PATH}" https://localhost:8443/jenkins/jnlpJars/jenkins-cli.jar
  display 'fetching the list of plugins.' 'info'
  set +u
  set +e
  plugin_list=$(execute_cmd 'list-plugins' 2> /dev/null | grep -P '\(.+\)$' | awk '{print $1}' | tr '\n' ' ')
  if [ -z "${plugin_list}" ]; then
    display 'nothing to update.' 'info'
    exit 0
  else
    set -u
    set -e
    display "upgrading: ${plugin_list[*]}." 'info'
    execute_cmd "install-plugin ${plugin_list}"
    display 'restarting Jenkins.' 'info'
    # The BUILD_ID=whatever is the trick that cancel Jenkins to kill the processes spawned by the job.
    BUILD_ID=dontKillMe nohup bash -c "source \"${SCRIPT_FILE_PATH}\" ; sleep 10 ; execute_cmd 'safe-restart'" > "${WORKSPACE_PATH}/log" 2>&1 &
    exit 0
  fi
}
