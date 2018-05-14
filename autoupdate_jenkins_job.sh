#!/bin/bash

set -e
set -u
set -o pipefail

readonly BASE_URL='http://mirrors.jenkins-ci.org/war-stable/latest'
readonly JENKINS_HASH_URL="${BASE_URL}/jenkins.war.sha256"
readonly JENKINS_WAR_URL="${BASE_URL}/jenkins.war"

readonly WEBAPP_DIR_PATH='/usr/share/tomcat/webapps'
readonly JENKINS_WAR_FILENAME='jenkins.war'
readonly JENKINS_WAR_TMP_FILE_PATH="/tmp/${JENKINS_WAR_FILENAME}"
readonly JENKINS_WAR_FILE_PATH="${WEBAPP_DIR_PATH}/${JENKINS_WAR_FILENAME}"

readonly BACKUP_DIR_PATH="${HOME}/jenkins_old_version"

cd "${WEBAPP_DIR_PATH}"

echo "> comparing the latest version of Jenkins with the installed one."
set +e
wget -q -O - "${JENKINS_HASH_URL}" | sha256sum -c > /dev/null 2>&1
returned_code=$?
set -e

if [ $returned_code -ne 0 ]; then
  echo "> downloading a new version of Jenkins."
  wget -q -O "${JENKINS_WAR_TMP_FILE_PATH}" "${JENKINS_WAR_URL}"
  echo "> backup Jenkins to ${BACKUP_DIR_PATH}."
  mkdir -p "${BACKUP_DIR_PATH}"
  cp -fp "${JENKINS_WAR_FILE_PATH}" "${BACKUP_DIR_PATH}"
  echo "> delete the previous Jenkins installation."
  rm -fr "${JENKINS_WAR_FILE_PATH}" "$(basename -s '.war' ${JENKINS_WAR_FILE_PATH})"
  echo "> run a nohup sequence of commands."
  date >> "${BACKUP_DIR_PATH}/nohup.log"
  nohup sh -c "sleep 20 ; mv -f ${JENKINS_WAR_TMP_FILE_PATH} ${JENKINS_WAR_FILE_PATH}" >> "${BACKUP_DIR_PATH}/nohup.log" 2>&1 &
else
  echo "> current Jenkins is up to date: nothing to do."
fi
