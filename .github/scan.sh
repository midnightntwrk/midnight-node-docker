#!/usr/bin/env bash

source "./.envrc"

docker compose -f ./compose.yml -f ./compose-partner-chains.yml build

scan_image() {
  local image="$1"
  echo "Scanning $image..."
  local SAFE_NAME=$(echo "$image" | sed 's/[\/:]/-/g')
  local SARIF_FILE="${SAFE_NAME}.sarif"

  time docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache:/root/.cache \
    -v "$(pwd):/output" \
    aquasec/trivy:0.67.2 image \
    --format sarif \
    --ignore-unfixed \
    --no-progress \
    --output "/output/$SARIF_FILE" \
    "$image"
  jq --arg image "$image" \
   '.runs[0].automationDetails = {
     id: "trivy/\($image)",
     description: {text: "Trivy scan for \($image)"}
   }' $SARIF_FILE > ./scan_reports/${SARIF_FILE}
  echo "Completed $SARIF_FILE"
}
export -f scan_image

mkdir scan_reports

docker compose -f ./compose.yml -f ./compose-partner-chains.yml config --images | \
  xargs -I {} bash -c 'scan_image "$@"' _ {}
