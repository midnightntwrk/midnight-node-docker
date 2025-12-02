#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source "./.envrc"

docker compose -f ./compose.yml -f ./compose-partner-chains.yml build

scan_image() {
  local image SAFE_NAME SARIF_FILE scan_exit_code
  image="$1"
  echo "=========================================="
  echo "Scanning $image..."
  echo "=========================================="
  SAFE_NAME=$(echo "$image" | sed 's/[\/:]/-/g')
  SARIF_FILE="${SAFE_NAME}.sarif"

  # Run Trivy scan and capture exit code
  scan_exit_code=0
  time docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache:/root/.cache \
    -v "$(pwd):/output" \
    aquasec/trivy:0.67.2 image \
    --format sarif \
    --ignore-unfixed \
    --no-progress \
    --output "/output/$SARIF_FILE" \
    "$image" || scan_exit_code=$?

  # Check if scan succeeded and SARIF file was created
  if [[ $scan_exit_code -ne 0 ]]; then
    echo "::warning::Trivy scan failed for $image (exit code: $scan_exit_code)"
    # Create minimal valid SARIF to avoid breaking the upload
    cat > "$SARIF_FILE" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [{
    "tool": {
      "driver": {
        "name": "Trivy",
        "version": "0.67.2",
        "informationUri": "https://github.com/aquasecurity/trivy"
      }
    },
    "results": [],
    "automationDetails": {
      "id": "trivy/$image",
      "description": {"text": "Trivy scan failed for $image - image may not be accessible"}
    }
  }]
}
EOF
    echo "Created placeholder SARIF for failed scan: $SARIF_FILE"
    # Record failure but continue
    echo "$image" >> /tmp/failed_scans.txt
  fi

  # Validate SARIF file exists and is valid JSON
  if [[ ! -f "$SARIF_FILE" ]]; then
    echo "::error::SARIF file not created for $image"
    return 1
  fi

  if ! jq empty "$SARIF_FILE" 2>/dev/null; then
    echo "::error::Invalid SARIF JSON for $image"
    return 1
  fi

  # Add automation details and move to scan_reports
  jq --arg image "$image" \
   '.runs[0].automationDetails = {
     id: "trivy/\($image)",
     description: {text: "Trivy scan for \($image)"}
   }' "$SARIF_FILE" > "./scan_reports/${SARIF_FILE}"

  echo "Completed $SARIF_FILE"
}
export -f scan_image

mkdir -p scan_reports

# Clear any previous failed scans record
rm -f /tmp/failed_scans.txt

# Scan all images from compose config
docker compose -f ./compose.yml -f ./compose-partner-chains.yml config --images | \
  xargs -I {} bash -c 'scan_image "$@"' _ {}

# Report summary
echo ""
echo "=========================================="
echo "Scan Summary"
echo "=========================================="
if [[ -f /tmp/failed_scans.txt ]]; then
  echo "::warning::The following images failed to scan:"
  cat /tmp/failed_scans.txt
  echo ""
  echo "Placeholder SARIF files were created for failed scans."
else
  echo "All images scanned successfully."
fi
