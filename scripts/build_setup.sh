#!/usr/bin/env bash

set -euo pipefail

if [[ "${PIPELINE_DEBUG:-0}" == 1 ]]; then
  set -x
  trap env EXIT
fi

get-icr-region() {
  case "$1" in
    ibm:yp:us-south)
      echo us
      ;;
    ibm:yp:eu-de)
      echo de
      ;;
    ibm:yp:eu-gb)
      echo uk
      ;;
    ibm:yp:jp-tok)
      echo jp
      ;;
    ibm:yp:jp-osa)
      echo jp2
      ;;
    ibm:yp:au-syd)
      echo au
      ;;
    *)
      echo "Unknown region: $1" >&2
      exit 1
      ;;
  esac
}

# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
# apt-get update && apt-get install docker-ce-cli

set +e
REPOSITORY="$(get_env repository)"
set -e
if [[ "${REPOSITORY}" ]]; then
  IMAGE_NAME=$(basename "$REPOSITORY" .git)
else
  IMAGE_NAME="$(get_env app-name)"
fi
IMAGE_TAG="$(date +%Y%m%d%H%M%S)-$(get_env git-branch)-$(get_env git-commit)"

BREAK_GLASS=$(get_env break_glass "")

if [[ -n "$BREAK_GLASS" ]]; then
  ARTIFACTORY_URL="$(get_env artifactory | jq -r .parameters.repository_url)"
  ARTIFACTORY_REGISTRY="$(sed -E 's~https://(.*)/?~\1~' <<<"$ARTIFACTORY_URL")"
  ARTIFACTORY_INTEGRATION_ID="$(get_env artifactory | jq -r .instance_id)"
  IMAGE="$ARTIFACTORY_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
  jq -j --arg instance_id "$ARTIFACTORY_INTEGRATION_ID" '.services[] | select(.instance_id == $instance_id) | .parameters.token' /toolchain/toolchain.json | docker login -u "$(get_env artifactory | jq -r '.parameters.user_id')" --password-stdin "$(get_env artifactory | jq -r '.parameters.repository_url')"
else
  ICR_REGISTRY_NAMESPACE="$(get_env registry-namespace)"
  ICR_REGISTRY_REGION="$(get-icr-region "$(get_env registry-region)")"
  IMAGE="$ICR_REGISTRY_REGION.icr.io/$ICR_REGISTRY_NAMESPACE/$IMAGE_NAME:$IMAGE_TAG"
  docker login -u iamapikey --password-stdin "$ICR_REGISTRY_REGION.icr.io" <<< "$(get_env ibmcloud-api-key)"

  # Create the namespace if needed to ensure the push will be can be successfull
  echo "Checking registry namespace: ${ICR_REGISTRY_NAMESPACE}"
  IBM_LOGIN_REGISTRY_REGION=$(get_env registry-region | awk -F: '{print $3}')
  APIKEY=$(get_env ibmcloud-api-key)
  ibmcloud login --apikey "${APIKEY}" -r "$IBM_LOGIN_REGISTRY_REGION"
  NS=$( ibmcloud cr namespaces | sed 's/ *$//' | grep -x "${ICR_REGISTRY_NAMESPACE}" ||: )

  if [ -z "${NS}" ]; then
      echo "Registry namespace ${ICR_REGISTRY_NAMESPACE} not found"
      ibmcloud cr namespace-add "${ICR_REGISTRY_NAMESPACE}"
      echo "Registry namespace ${ICR_REGISTRY_NAMESPACE} created."
  else
      echo "Registry namespace ${ICR_REGISTRY_NAMESPACE} found."
  fi
fi

DOCKER_BUILD_ARGS="-t $IMAGE"
