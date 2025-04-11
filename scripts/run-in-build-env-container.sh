  #!/bin/bash

# Exit immediately if a pipeline, which may consist of a single simple command,
# a list or a compound command returns a non-zero status.
# https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#The-Set-Builtin
set -e

# Image and version
BUILD_ENV_IMAGE=orbis-u/build-env-u

# Version of build-env-u. Newer versions can be found via git tags or the nexus
# container image registry.
VERSION="84.4300.6" # renovate: datasource=docker registryUrl=https://registry-nexus.orbis.dedalus.com depName=orbis-u/build-env-u
JDK="jdk17"

# Determine the full directory path of the script no matter where it is being
# called from.
# => compare-pdf/scripts
# https://stackoverflow.com/a/246128
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Determine the project directory: ./compare-pdf
PROJECT_DIR=$(dirname ${SCRIPT_DIR})

# Determine src directory: ./compare-pdf/src
SRC_DIR="${PROJECT_DIR}/src"

# Verify if an argument has been passed.
SCRIPT_IN_DOCKER=$1
if [[ -z ${SCRIPT_IN_DOCKER} ]]; then
    echo "usage: sh build-in-docker-wrapper.sh script-name"
    echo "where <script-name> is bash script needed to be run inside docker. This script should be under <proj_root/scripts>"
    exit 1;
fi

# The source command reads and executes commands from the file specified as its
# argument in the current shell environment. It is useful to load functions,
# variables, and configuration files into shell scripts.
#source "${SCRIPT_DIR}/../util/export-environment-variables.sh"

# CONTAINER_RUNTIME, defaults to docker and the docker API socket.
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-"docker"}
CONTAINER_RUNTIME_SOCKET=${CONTAINER_RUNTIME_SOCKET:-"/var/run/docker.sock"}

# CONTAINER_IMAGE_BUILD_ARGS default args.
CONTAINER_IMAGE_BUILD_ARGS="--rm --env APP_NAME=${APP_NAME} --env BUILD_ENV_U=true --env CI_COMMIT_REF_NAME=${CI_COMMIT_REF_NAME} --env PROJECT_BASEDIR=${PROJECT_BASEDIR} --env PROXY_HOST=${PROXY_HOST} --name build-env "

if [[ ! -S "${CONTAINER_RUNTIME_SOCKET}" ]]; then
  echo "ERROR: Docker socket does not exists: ${CONTAINER_RUNTIME_SOCKET}"
  exit 1
fi
export GITHUB_CI=true
# Only for GitHub Actions (CI)
if [[ ${GITHUB_CI} ]]; then
  echo "INFO: Run build on GitHub CI..."

  # Execute
  ${CONTAINER_RUNTIME} run \
    ${CONTAINER_IMAGE_BUILD_ARGS} \
    --env GITHUB_CI=true \
    --env CI_REPOSITORY=${GITHUB_REPOSITORY} \
    --env HOST_USER_ID=$(id --user) \
    --env HOST_USER_GROUP=$(id --group) \
    --env RUNNER_HOSTNAME=${PROXY_HOST} \
    --env REVISION=${REVISION} \
    --workdir ${SRC_DIR} \
    --volume ${CONTAINER_RUNTIME_SOCKET}:${CONTAINER_RUNTIME_SOCKET} \
    --volume ${PROJECT_DIR}:${PROJECT_DIR} \
    --volume "${SCRIPT_DIR}/../github:/ci" \
    --volume "${HOME}/.ssh:/identity" \
    "${BUILD_ENV_IMAGE}:${VERSION}-${JDK}" \
     "${SCRIPT_DIR}/${SCRIPT_IN_DOCKER}"

  exit 0
fi

if [[ ${PLATFORM} == 'WINDOWS' ]]; then
  echo "INFO: Run build on ${PLATFORM}..."

  if [[ ! -d "${PROJECT_BASEDIR}" ]]; then
    echo "ERROR: PROJECT_BASEDIR does not exists: ${PROJECT_BASEDIR}"
    exit 1
  fi

  # Execute
  winpty ${CONTAINER_RUNTIME} run \
    ${CONTAINER_IMAGE_BUILD_ARGS} \
    --env "TERM=xterm-256color" \
    -it \
    --volume "/${CONTAINER_RUNTIME_SOCKET}:${CONTAINER_RUNTIME_SOCKET}" \
    --volume "/${PROJECT_BASEDIR}:/workspace/" \
    "${BUILD_ENV_IMAGE}:${VERSION}-${JDK}" \
      "${SCRIPT_DIR}/../${SCRIPT_IN_DOCKER}"

elif [[ ${PLATFORM} == 'LINUX' || ${PLATFORM} == 'OSX' ]]; then
  echo "INFO: Run build on ${PLATFORM}..."

  # Add platform specific container runtime args.
  CONTAINER_IMAGE_BUILD_ARGS+="--env HOST_USER_ID=$(id --user) --env HOST_USER_GROUP=$(id --group) "
  [[ -f "${HOME}/.npmrc" ]]; CONTAINER_IMAGE_BUILD_ARGS+="--volume ${HOME}/.npmrc:/root/.npmrc:ro "
  [[ -d "${HOME}/.ssh" ]]; CONTAINER_IMAGE_BUILD_ARGS+="--volume ${HOME}/.ssh:/root/.ssh:ro "

  # Execute
  ${CONTAINER_RUNTIME} run \
    ${CONTAINER_IMAGE_BUILD_ARGS} \
    --workdir ${PROJECT_DIR} \
    --volume ${CONTAINER_RUNTIME_SOCKET}:${CONTAINER_RUNTIME_SOCKET} \
    --volume ${PROJECT_DIR}:${PROJECT_DIR} \
    "${BUILD_ENV_IMAGE}:${VERSION}-${JDK}" \
     "${SCRIPTS_DIR}/${SCRIPT_IN_DOCKER}"

  echo "INFO: ran docker"

fi
