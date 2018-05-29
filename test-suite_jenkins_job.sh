#!/bin/bash

################################# SETTINGS #####################################

### BASH

set -o pipefail
set -u

### JENKINS

export WORKSPACE_PATH="${WORKSPACE}" # Set by Jenkins
export COMMON_DIR_PATH="${JENKINS_HOME}/esgf" # Set by Jenkins
export SCRIPT_DIR_PATH="${WORKSPACE_PATH}/jenkins-scripts"

### COMMON

source "${SCRIPT_DIR_PATH}/common"

### ESGF DOCKER

export ESGF_VERSION=${1-'devel'}
export ESGF_HUB='esgfhub'
export ESGF_PREFIX=''

export ESGF_HOSTNAME="$(hostname)"
export ESGF_CONFIG="${WORKSPACE_PATH}/config"
export ESGF_DATA="${WORKSPACE_PATH}/data"

export ESGF_DOCKER_REPO_PATH="${WORKSPACE_PATH}/esgf-docker"

### ESGF DOCKER SECRETS

export ROOT_ADMIN_SECRET_FILE_PATH="${ESGF_CONFIG}/secrets/rootadmin-password"

# Amount of time before running the test suite.
export STARTING_TIME=${3-240}

### ESGF TEST SUITE

export TESTS='-a !compute,basic -a cog_root_login -a slcs_django_admin_login'
export CONFIG_FILE_PATH="${COMMON_DIR_PATH}/my_config_docker.ini"
export ESGF_TEST_SUITE_GITHUB_URL='https://github.com/ESGF/esgf-test-suite.git'
export ESGF_TEST_SUITE_REPO_PATH="${WORKSPACE_PATH}/esgf-test-suite"
export TEST_DIR_PATH="${ESGF_TEST_SUITE_REPO_PATH}/esgf-test-suite"

export SINGULARITY_FILENAME='esgf-test-suite_env.singularity.img'
export SINGULARITY_IMG_URL="http://distrib-coffee.ipsl.jussieu.fr/pub/esgf/dist/esgf-test-suite/${SINGULARITY_FILENAME}"
export SINGULARITY_ENV_FILE_PATH="${TEST_DIR_PATH}/${SINGULARITY_FILENAME}"

################################# FUNCTIONS ####################################

function destructor
{
  cd "${ESGF_DOCKER_REPO_PATH}"
  display 'stop & delete the containers' 'info'
  docker-compose down -v
  cd - > /dev/null
}

function usage
{
  echo -e "usage:\n\
  \n$(basename ${0}) [image version] [time before testing]\n"
}

################################### MAIN #######################################

set -e

usage

mkdir -p "${ESGF_CONFIG}"
mkdir -p "${ESGF_DATA}"
cd "${WORKSPACE_PATH}"

# Update the esgf-test-suite repo.
if [ -d "${ESGF_TEST_SUITE_REPO_PATH}" ]; then
  cd "${ESGF_TEST_SUITE_REPO_PATH}"
  display 'update esgf-test-suite repo' 'info'
  git checkout master
  git pull origin master
  cd - > /dev/null
else
  display "clone esgf-test-suite repo" 'info'
  git clone "${ESGF_TEST_SUITE_GITHUB_URL}" "${ESGF_TEST_SUITE_REPO_PATH}"
fi

# Fetch the singularity file if absent.
if [ ! -f "${SINGULARITY_ENV_FILE_PATH}" ]; then
  display 'download the esgf-test-suite singularity image' 'info'
  wget -q -O "${SINGULARITY_ENV_FILE_PATH}" "${SINGULARITY_IMG_URL}"
fi

display "using singularity file: $(date -r ${SINGULARITY_ENV_FILE_PATH})" 'info'

# Fetch the last images.
display "fetch the last docker images from ${ESGF_HUB}/*:${ESGF_VERSION}" 'info'
cd "${ESGF_DOCKER_REPO_PATH}"
docker-compose pull

display 'local images' 'info'
docker images

# Delete the previous esgf docker config files.
display 'delete the previous configuration files of ESGF docker' 'info'
rm -fr "${ESGF_CONFIG}/*"

# Regenerate the esgf docker config files.
display 'generating esgf secrets' 'info'
docker-compose run -u $UID esgf-setup generate-secrets
display 'generating certificates' 'info'
docker-compose run -u $UID esgf-setup generate-test-certificates
display 'creating trust bundle' 'info'
docker-compose run -u $UID esgf-setup create-trust-bundle
chmod +r "${ESGF_CONFIG}/certificates/hostcert/hostcert.key"
chmod +r "${ESGF_CONFIG}/certificates/slcsca/ca.key"

display 'starting the esgf containers' 'info'
set +e # The script manages the failures.
docker-compose up -d || destructor

display "waiting ${STARTING_TIME} seconds for the containers" 'info'
sleep ${STARTING_TIME}

display 'container status' 'info'
docker ps

admin_passwd="$(cat ${ROOT_ADMIN_SECRET_FILE_PATH})"
slcs_secret_conf="slcs.admin_password:${admin_passwd}"
cog_secret_conf="cog.admin_password:${admin_passwd}"

display 'running the tests' 'info'
cd "${TEST_DIR_PATH}"
singularity exec "${SINGULARITY_ENV_FILE_PATH}" python2 esgf-test.py ${TESTS} \
  -v --nocapture --nologcapture \
  --rednose --force-color --hide-skips \
  --tc-file "${CONFIG_FILE_PATH}" \
  --tc="${slcs_secret_conf}" \
  --tc="${cog_secret_conf}"

EXIT_STATUS=$?

if [ ${EXIT_STATUS} -ne 0 ]; then
  display "one or more tests have failed, log of the containers:" "info"
  cd "${ESGF_DOCKER_REPO_PATH}"
  docker-compose logs
  cd - > /dev/null
fi

# Call the desctructor.
destructor

display "exit with ${EXIT_STATUS}" 'info'
exit ${EXIT_STATUS}
