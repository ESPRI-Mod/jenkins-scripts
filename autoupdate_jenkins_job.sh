#!/bin/bash

set -e
set -u
set -o pipefail

readonly BASE_URL='http://mirrors.jenkins-ci.org/war-stable/latest'
readonly JENKINS_HASH_URL="${BASE_URL}/jenkins.war.sha256"
readonly JENKINS_WAR_URL="${BASE_URL}/jenkins.war"

readonly WORKSPACE_PATH="${WORKSPACE}" # Set by Jenkins
readonly SCRIPT_DIR_PATH="${WORKSPACE_PATH}/jenkins-scripts"

readonly WEBAPP_DIR_PATH='/usr/share/tomcat/webapps'
readonly JENKINS_WAR_FILENAME='jenkins.war'
readonly JENKINS_WAR_TMP_FILE_PATH="/${WORKSPACE_PATH}/${JENKINS_WAR_FILENAME}"
readonly JENKINS_WAR_FILE_PATH="${WEBAPP_DIR_PATH}/${JENKINS_WAR_FILENAME}"

readonly BACKUP_DIR_PATH="${WORKSPACE_PATH}/jenkins_old_version"

source "${SCRIPT_DIR_PATH}/common"

cd "${WEBAPP_DIR_PATH}"

display 'comparing the latest version of Jenkins with the installed one.' 'info'
set +e
wget -q -O - "${JENKINS_HASH_URL}" | sha256sum -c > /dev/null 2>&1
returned_code=$?
set -e

if [ $returned_code -ne 0 ]; then
  display 'downloading a new version of Jenkins.' 'info'
  wget -q -O "${JENKINS_WAR_TMP_FILE_PATH}" "${JENKINS_WAR_URL}"
  display "backup Jenkins to ${BACKUP_DIR_PATH}." 'info'
  mkdir -p "${BACKUP_DIR_PATH}"
  cp -fp "${JENKINS_WAR_FILE_PATH}" "${BACKUP_DIR_PATH}"
  display 'delete the previous Jenkins installation.' 'info'
  rm -fr "${JENKINS_WAR_FILE_PATH}" "$(basename -s '.war' ${JENKINS_WAR_FILE_PATH})"
  display 'reinstall Jenkins (nohup)'
  date >> "${BACKUP_DIR_PATH}/nohup.log"
  # The BUILD_ID=whatever is the trick that cancel Jenkins to kill the processes spawned by the job.
  BUILD_ID=dontKillMe nohup bash -c "sleep 10 ; mv -f ${JENKINS_WAR_TMP_FILE_PATH} ${JENKINS_WAR_FILE_PATH}" >> "${BACKUP_DIR_PATH}/nohup.log" 2>&1 &
  exit 0
else
  display 'current Jenkins is up to date: nothing to do.' 'info'
  exit 0
fi
