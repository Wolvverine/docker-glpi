#!/usr/bin/env bash

set -ev

## Global settings
# image name
DOCKER_IMAGE="${DOCKER_REPO:-glpi}"
# "production" branch
PRODUCTION_BRANCH=${PRODUCTION_BRANCH:-master}


## Initialization
set -e

if [[ ${DOCKER_IMAGE} =~ ([^/]+)/([^/]+) ]]; then
  username=${BASH_REMATCH[1]}
  repo=${BASH_REMATCH[2]}
  echo "-> set username to '${username}'"
  echo "-> set repository to '${repo}'"
else
  echo 'ERROR: unable to extract username and repo from environment' 1>&2
  exit 1
fi

if [[ -z "$DOCKERHUB_REGISTRY_USERNAME" || -z "$DOCKERHUB_REGISTRY_PASSWORD" ]]; then
  echo 'ERROR: missing one of the registry credential DOCKERHUB_REGISTRY_USERNAME DOCKERHUB_REGISTRY_PASSWORD' 1>&2
  exit 1
fi

image_version="$(xargs < VERSION)"

if [[ -n ${IMAGE_VARIANT} ]]; then
  image_building_name="${DOCKER_IMAGE}:building_${IMAGE_VARIANT}"
  image_tags_prefix="${IMAGE_VARIANT}"
    if [[ "${PHP_XDEBUG}" = "yes" ]]; then
      image_tags_prefix="${IMAGE_VARIANT}-xdebug"
    fi
  echo "-> set image variant '${IMAGE_VARIANT}' for build"
else
  image_building_name="${DOCKER_IMAGE}:building"
fi
echo "-> use image name '${image_building_name}' for publish"

# If empty branch, fetch the current from local git rpo
# shellcheck disable=SC2153
if [[ -n "${SOURCE_BRANCH}" ]]; then
  VCS_BRANCH="${SOURCE_BRANCH}"
elif [[ -n "${CI_BRANCH}" ]]; then
  VCS_BRANCH="${CI_BRANCH}"
else
  VCS_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
fi
test -n "${VCS_BRANCH}"
echo "-> current vcs branch '${VCS_BRANCH}'"

# set the docker publish logic per branch
application_version=$(docker inspect -f '{{ index .Config.Labels "application.glpi.version" }}' "${image_building_name}")
publish=false
if [[ "${VCS_BRANCH}" = "${PRODUCTION_BRANCH}" ]]; then
  image_tags=("${image_tags_prefix}-${application_version}-${image_version}")
  if [[ -z "${GLPI_VERSION}" || -n "${UPDATE_LATEST}" ]]; then
    image_tags+=("${image_tags_prefix}-latest" "${image_tags_prefix}-${application_version}-latest" )
    # TODO "latest"
  fi
  if ! curl -s "https://hub.docker.com/v2/repositories/${username}/${repo}/tags/?page_size=100" \
       | grep --quiet "\"name\": *\"${image_tags_prefix}-${application_version}-${image_version}\""; then
    publish=true
  fi
elif [[ "${VCS_BRANCH}" == "dev" ]]; then
  image_tags=("${image_tags_prefix}-${application_version}-${image_version}-dev")
  if [[ -z "${GLPI_VERSION}" || -n "${UPDATE_LATEST}" ]]; then
    image_tags+=("${image_tags_prefix}-dev")
  fi
  publish=true
fi
echo "-> use image tags '${image_tags[*]}'"

## Publish image
if [[ "${publish}" != "true" ]]; then
  echo "-> No need to Push to Registry - ${image_tags_prefix}-${application_version}-${image_version} exist"
else
  echo "-> Pushing to registry.."

  ## Login to registry
  . "./docker_login.sh"

  ## Push images
  # shellcheck disable=SC2048
  for tag in ${image_tags[*]}; do
    echo "=> tag image '${image_building_name}' as '${DOCKER_IMAGE}:${tag}'"
    docker tag "${image_building_name}" "${DOCKER_IMAGE}:${tag}"
    echo "=> push image '${DOCKER_IMAGE}:${tag}'"
    docker push "${DOCKER_IMAGE}:${tag}"
  done

  ## Logout from registry
  docker logout
fi

## Publish README
# only for production branch
# Personal access token is restricted to registry APIs only (docker login).
# It does not allow accessing all APIs because doing that will bypass 2nd factor when an account is 2FA enabled.
# 403 "access is forbidden with a JWT issued from a personal access token"

if [[ "${VCS_BRANCH}" == "${PRODUCTION_BRANCH}" && -n "${UPDATE_README}" ]]; then
  DOCKER_REPO_URL="https://hub.docker.com/v2/repositories/${username}/${repo}/"
  DOCKER_LOGIN_URL="https://hub.docker.com/v2/users/login"
  
  set -o pipefail
  TOKEN=$(curl --fail --silent -H "Content-Type: application/json" -X POST \
            -d "{\"username\": \"${DOCKERHUB_REGISTRY_USERNAME}\", \"password\":\"${DOCKERHUB_REGISTRY_PASSWORD}\"}" \
            ${DOCKER_LOGIN_URL} \
            | grep --perl-regexp --only-matching '(?<="token":")[^"]+')
  
  RESPONSE_CODE=$(curl --fail --silent --write-out "%{response_code}" -H "Authorization: JWT $TOKEN" \
                    -X PATCH --data-urlencode full_description@./README.md \
                    "${DOCKER_REPO_URL}")
  set +o pipefail
  if [ "${RESPONSE_CODE}" -eq 200 ]; then
        echo "Successfully pushed README.md to ${DOCKER_REPO_URL}"
        exit 0
    else
        echo "Unable to push README.md for ${DOCKER_REPO_URL}"
        exit 1
    fi
fi
