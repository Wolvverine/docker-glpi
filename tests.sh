#!/usr/bin/env bash

## Global settings
# image name
DOCKER_IMAGE="${DOCKER_REPO:-glpi}"

## Initialization
set -e -x

if [[ -n ${IMAGE_VARIANT} ]]; then
  image_building_name="${DOCKER_IMAGE}:building_${IMAGE_VARIANT}"
  echo "-> set image variant '${IMAGE_VARIANT}' for build"
else
  image_building_name="${DOCKER_IMAGE}:building"
fi
docker_run_options='--detach'
# string that proove that container is up
container_up_string='GET /fpm-ping'
echo "-> use image name '${image_building_name}' for tests"


## Prepare
if [[ -z $(command -v container-structure-test 2>/dev/null) ]]; then
  echo "Retrieving structure-test binary...."
  if [[ -n "${RUNNER_OS}" && "$RUNNER_OS" == 'Linux' ]]; then
    if curl -LO https://github.com/GoogleContainerTools/container-structure-test/releases/latest/download/container-structure-test-linux-amd64; then
       chmod +x container-structure-test-linux-amd64 \
       && mv container-structure-test-linux-amd64 container-structure-test
    else
       echo "Failed to download or set up container-structure-test for Linux."
       exit 1
    fi
  elif [[ -n "${RUNNER_OS}" && "$RUNNER_OS" == 'macOS' ]]; then
    if curl -LO https://github.com/GoogleContainerTools/container-structure-test/releases/latest/download/container-structure-test-darwin-arm64; then
       chmod +x container-structure-test-darwin-arm64 \
       && mv container-structure-test-darwin-arm64 container-structure-test 
    else
       echo "Failed to download or set up container-structure-test for MacOS."
       exit 1
    fi
  else
    echo "container-structure-test only released for Linux and MacOS at this time."
    echo "See https://github.com/GoogleContainerTools/container-structure-test for more information."
    exit 1
  fi
fi

# Download tools shim.
if [[ ! -f _tools.sh ]]; then
  curl -L -o "${PWD}/_tools.sh" https://gist.github.com/Wolvverine/d6b811105961af0f5ff9edb0693e7ad0/raw
fi
# shellcheck disable=SC1090
source "${PWD}/_tools.sh"

##### FUNCTIONS ####

wait_for_directory_in_container() {
  local container_name="$1"
  local directory="$2"
  local timeout_seconds="${3:-120}"
  local elapsed=0

  until docker exec "${container_name}" test -d "${directory}" >/dev/null 2>&1; do
    sleep 5
    elapsed=$((elapsed + 1))
    if (( elapsed >= timeout_seconds )); then
      echo "timeout waiting for directory '${directory}' in '${container_name}'" >&2
      docker logs "${container_name}" >&2 || true
      false
    fi
  done
  echo "-> directory '${directory}' in container '${container_name}' is present"
  return 0
}

wait_for_string_in_container_log() {
  local container_name="$1"
  local string="$2"
  local timeout_seconds="${3:-120}"
  local elapsed=0
  
  until docker logs "${container_name}" | grep --quiet "${string}"; do
    sleep 5
    echo "-> Waiting for container '${container_name}' to be up ..."
    if (( elapsed >= timeout_seconds )); then
      echo "-> Container ${container_name} is unable to be up until ${timeout_seconds} seconds" >&2
      false
    fi
  done
  echo "-> Container ${container_name} is up"
  return 0
}

# Unique suffix per matrix job to avoid name collisions when jobs run in parallel
job_suffix=$(echo "${GLPI_VERSION}_${IMAGE_VARIANT}_${PHP_XDEBUG}" | tr -c 'a-zA-Z0-9' '_')

cleanup_glpi_containers() {
  docker rm -f glpi_2_"${job_suffix}" glpi_3_"${job_suffix}" glpi_4_"${job_suffix}" glpi_5_"${job_suffix}" glpi_6_"${job_suffix}" 2>/dev/null || true
}
cleanup_glpi_containers
trap cleanup_glpi_containers EXIT

## Test

# shell scripts tests
# shellcheck disable=SC2038
find . -name '*.sh' -print0 | xargs -0 shellcheck
shellcheck docker-entrypoint.d/*

# Image tests
./container-structure-test \
    test --image "${image_building_name}" --config ./tests.yml

## Ensure that required php extensions are installed
extensions=$(docker run --rm "${image_building_name}" php -m)
for ext in apcu \
           ctype \
           curl \
           dom \
           gd \
           json \
           ldap \
           mysqli \
           openssl \
           opcache \
           soap \
           xml \
           xmlreader \
           xmlrpc \
           zlib; do
  if ! echo "${extensions}" | grep -qi $ext; then
    echo "missing PHP extension '$ext'" 1>&2
    exit 1
  fi
done


#2 Test plugins installation with tar.bz2
echo '-> 2 Test plugins installation with tar.bz2'
image_name=glpi_2_${job_suffix}
docker run $docker_run_options --name "${image_name}" --env='GLPI_INSTALL_PLUGINS=datainjection|https://github.com/pluginsGLPI/datainjection/releases/download/2.15.10/glpi-datainjection-2.15.10.tar.bz2' "${image_building_name}"
wait_for_string_in_container_log "${image_name}" "${container_up_string}" 60
wait_for_directory_in_container "${image_name}" "plugins/datainjection" 60
stop_and_remove_container "${image_name}"


#3 Test plugins installation with tar.gz
echo '-> 3 Test plugins installation with tar.gz'
image_name=glpi_3_${job_suffix}
docker run $docker_run_options --name "${image_name}" --env='GLPI_INSTALL_PLUGINS=reports|https://github.com/yllen/reports/releases/download/v1.16.0/glpi-reports-1.16.0.tar.gz' "${image_building_name}"
wait_for_string_in_container_log "${image_name}" "${container_up_string}" 60
wait_for_directory_in_container "${image_name}" "plugins/reports" 60
stop_and_remove_container "${image_name}"


#4 Test timezone setting
echo '-> 4 Test timezone'
image_name=glpi_4_${job_suffix}
docker run $docker_run_options --name "${image_name}" --env='TZ=Europe/Paris' "${image_building_name}"
wait_for_string_in_container_log "${image_name}" "${container_up_string}" 60
# test
if ! [[ $(docker exec "${image_name}" readlink -f /etc/localtime) =~ Europe/Paris$ ]]; then
  docker logs "${image_name}"
  false
fi
stop_and_remove_container "${image_name}"


#5 Test web access
echo '-> 5 Test web access'
image_name=glpi_5_${job_suffix}
docker run $docker_run_options --name "${image_name}" -P "${image_building_name}"
wait_for_string_in_container_log "${image_name}" 'nginx entered RUNNING state' 120

# discover the host port that Docker assigned to container port 80
host_port=$(docker port "${image_name}" 80 | awk -F: '{print $NF}' | head -n1)
if [[ -z "${host_port}" ]]; then
  echo "could not discover mapped host port for ${image_name}" >&2
  docker logs "${image_name}"
  false
fi

if ! curl -v "http://localhost:${host_port}" 2>&1 | grep --quiet 'install/install.php'; then
  docker logs "${image_name}"
  false
fi
stop_and_remove_container "${image_name}"


#6 Test plugins installation with zip
echo '-> 6 Test plugins installation with zip'
image_name=glpi_6_${job_suffix}
docker run $docker_run_options --name "${image_name}" --env='GLPI_INSTALL_PLUGINS=archimap|https://github.com/ericferon/glpi-archimap/releases/download/v3.3.14/archimap-v3.3.14.zip' "${image_building_name}"
wait_for_string_in_container_log "${image_name}" "${container_up_string}" 60
wait_for_directory_in_container "${image_name}" "plugins/archimap" 60
stop_and_remove_container "${image_name}"
