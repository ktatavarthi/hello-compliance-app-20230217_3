#!/usr/bin/env bash

#
# prepare data
#

export GHE_TOKEN
GHE_TOKEN="$(get_env git-token)"
export COMMIT_SHA
COMMIT_SHA="$(get_env git-commit)"
export APP_NAME
APP_NAME="$(get_env app-name)"

INVENTORY_REPO="$(get_env inventory-url)"
GHE_ORG=${INVENTORY_REPO%/*}
export GHE_ORG=${GHE_ORG##*/}
GHE_REPO=${INVENTORY_REPO##*/}
export GHE_REPO=${GHE_REPO%.git}

set +e
    REPOSITORY="$(get_env repository)"
    TAG="$(get_env custom-image-tag)"
set -e

export APP_REPO
APP_REPO="$(get_env repository-url)"
APP_REPO_ORG=${APP_REPO%/*}
export APP_REPO_ORG=${APP_REPO_ORG##*/}

if [[ "${REPOSITORY}" ]]; then
    export APP_REPO_NAME
    APP_REPO_NAME=$(basename "$REPOSITORY" .git)
    APP_NAME=$APP_REPO_NAME
else
    APP_REPO_NAME=${APP_REPO##*/}
    export APP_REPO_NAME=${APP_REPO_NAME%.git}
fi

ARTIFACT="https://raw.github.ibm.com/${APP_REPO_ORG}/${APP_REPO_NAME}/${COMMIT_SHA}/deployment.yml"

IMAGE_ARTIFACT="$(get_env artifact)"
SIGNATURE="$(get_env signature)"
if [[ "${TAG}" ]]; then
    APP_ARTIFACTS='{ "signature": "'${SIGNATURE}'", "provenance": "'${IMAGE_ARTIFACT}'", "tag": "'${TAG}'" }'
else
    APP_ARTIFACTS='{ "signature": "'${SIGNATURE}'", "provenance": "'${IMAGE_ARTIFACT}'" }'
fi
#
# add to inventory
#

cocoa inventory add \
    --artifact="${ARTIFACT}" \
    --repository-url="${APP_REPO}" \
    --commit-sha="${COMMIT_SHA}" \
    --build-number="${BUILD_NUMBER}" \
    --pipeline-run-id="${PIPELINE_RUN_ID}" \
    --version="$(get_env version)" \
    --name="${APP_REPO_NAME}_deployment"

cocoa inventory add \
    --artifact="${IMAGE_ARTIFACT}" \
    --repository-url="${APP_REPO}" \
    --commit-sha="${COMMIT_SHA}" \
    --build-number="${BUILD_NUMBER}" \
    --pipeline-run-id="${PIPELINE_RUN_ID}" \
    --version="$(get_env version)" \
    --name="${APP_REPO_NAME}" \
    --app-artifacts="${APP_ARTIFACTS}"
