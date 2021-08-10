#!/usr/bin/env bash

set -euo pipefail

#cDOCKER_BUILDKIT=1 docker build $DOCKER_BUILD_ARGS .
docker build $DOCKER_BUILD_ARGS .
docker push "${IMAGE}"

#optional tag
set +e
TAG="$(cat /config/custom-image-tag)"
set -e
if [[ "${TAG}" ]]; then
    #see build_setup script
    IFS=',' read -ra tags <<< "${TAG}"
    for i in "${!tags[@]}"
    do
        TEMP_TAG=${tags[i]}
        TEMP_TAG=$(echo "$TEMP_TAG" | sed -e 's/^[[:space:]]*//')
        echo "adding tag $i $TEMP_TAG"
        ADDITIONAL_IMAGE_TAG="$ICR_REGISTRY_REGION.icr.io"/"$ICR_REGISTRY_NAMESPACE"/"$IMAGE_NAME":"$TEMP_TAG"
        docker tag "$IMAGE" "$ADDITIONAL_IMAGE_TAG"
        docker push "$ADDITIONAL_IMAGE_TAG"
    done
fi

DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" | awk -F@ '{print $2}')"
echo -n "$DIGEST" > ../image-digest
echo -n "$IMAGE_TAG" > ../image-tags
echo -n "$IMAGE" > ../image

IMAGE_TAG_XRAY="eu.artifactory.swg-devops.com/wcp-compliance-automation-team-docker-local/$IMAGE_NAME"
# docker login wcp-compliance-automation-team-docker-local.artifactory.swg-devops.com -u "$(jq -r '.parameters.user_id' /config/artifactory)" --password-stdin "$(jq -r '.parameters.repository_url' /config/artifactory)"

ARTIFACTORY_URL="$(jq -r .parameters.repository_url /config/artifactory)"
ARTIFACTORY_REGISTRY="$(sed -E 's~https://(.*)/?~\1~' <<<"$ARTIFACTORY_URL")"
ARTIFACTORY_INTEGRATION_ID="$(jq -r .instance_id /config/artifactory)"
IMAGEXRAY="$ARTIFACTORY_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
jq -j --arg instance_id "$ARTIFACTORY_INTEGRATION_ID" '.services[] | select(.instance_id == $instance_id) | .parameters.token' /toolchain/toolchain.json | docker login -u "$(jq -r '.parameters.user_id' /config/artifactory)" --password-stdin "$(jq -r '.parameters.repository_url' /config/artifactory)"

docker pull "$IMAGE"
docker tag "$IMAGE" "$IMAGEXRAY"
docker push "$IMAGEXRAY"

if which save_artifact >/dev/null; then
  
  url="$(load_repo app-repo url)"
  sha="$(load_repo app-repo commit)"

  save_artifact app-image \
    type=image \
    "name=${IMAGE}" \
    "digest=${DIGEST}" \
    "source=${url}.git#${sha}"
  save_artifact app-image-icr type=image "name=${IMAGE}" "digest=${DIGEST}"
  save_artifact app-image-xray type=image "name=${IMAGEXRAY}" "digest=${DIGEST}"
fi
