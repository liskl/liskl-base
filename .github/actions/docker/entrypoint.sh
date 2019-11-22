#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

DOCKER_TAG="latest"

echo "GITHUB_REF: ${GITHUB_REF}";
echo "GITHUB_TAGS: $(git describe --tags)";

if [[ "${GITHUB_REF}" == "refs/tags/master" ]]; then
    DOCKER_TAG="$(git describe --tags)"
elif [[ "${GITHUB_REF}" == "refs/heads/master" ]]; then
    DOCKER_TAG="$(echo ${GITHUB_SHA::7})"
elif [[ "${GITHUB_REF}" == "refs/tags"* ]]; then
    DOCKER_TAG="$(echo ${GITHUB_REF} | rev | cut -d/ -f1 | rev)"
elif [[ "${GITHUB_REF}" == "refs/pull"* ]]; then
    DOCKER_TAG="$(echo ${GITHUB_SHA::7})"
else
    DOCKER_TAG="$(echo ${GITHUB_REF} | rev | cut -d/ -f1 | rev)-$(echo ${GITHUB_SHA::7})"
fi


if [[ "${DOCKER_REGISTRY}" == "docker.pkg.github.com" ]]; then
  NEW_NAME="${OWNER}/${DOCKER_IMAGE}/${DOCKER_IMAGE}";
  DOCKER_IMAGE="${NEW_NAME}"
else
  DOCKER_IMAGE="${OWNER}/${DOCKER_IMAGE}"
fi

if [[ "$1" == "build" ]]; then
  docker login ${DOCKER_REGISTRY} -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD} ;
  set +o pipefail ;
  docker pull ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest || true;
  set -o pipefail ;
  docker build --cache-from ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
  --build-arg=COMMIT_SHA=${GITHUB_SHA::7} \
  --build-arg=VERSION=${DOCKER_TAG} -f $2 . ;
  docker tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest ;
  docker tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${GITHUB_SHA::7} ;
  docker tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:$(echo ${GITHUB_REF} | rev | cut -d/ -f1 | rev)-$(echo ${GITHUB_SHA::7}) ;
  echo "Docker image tagged as ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
  echo "";
fi

if [[ "$1" == "push" ]]; then
  docker login ${DOCKER_REGISTRY} -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD} ;
  docker push "${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
  echo "Docker image pushed to ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
  docker push "${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
  echo "Docker image pushed to ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
  docker push "${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${GITHUB_SHA::7}"
  echo "Docker image pushed to ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${GITHUB_SHA::7}"
  docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:$(echo ${GITHUB_REF} | rev | cut -d/ -f1 | rev)-$(echo ${GITHUB_SHA::7}) ;
  echo "Docker image pushed to ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:$(echo ${GITHUB_REF} | rev | cut -d/ -f1 | rev)-$(echo ${GITHUB_SHA::7})"

  echo "";
fi
