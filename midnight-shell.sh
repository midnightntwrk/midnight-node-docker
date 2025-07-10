#!/usr/bin/env bash

# Define container name
CONTAINER_NAME="midnight"

# Check if the container already exists
if [ "$(docker ps -a -f name=^${CONTAINER_NAME}$ --format '{{.Names}}' | grep -c -w "${CONTAINER_NAME}")" -eq 0 ]; then
  echo "Container '${CONTAINER_NAME}' does not exist. Creating and starting it..."

  # Run the container with the specified configuration
  docker run -it \
    --name ${CONTAINER_NAME} \
    -e CFG_PRESET="${CFG_PRESET}" \
    -e DB_SYNC_POSTGRES_CONNECTION_STRING="${DB_SYNC_POSTGRES_CONNECTION_STRING}" \
    -v ./data:/data \
    -v "./envs/${CFG_PRESET}/pc-chain-config.json:/pc-chain-config.json" \
    --entrypoint bash \
    "${MIDNIGHT_NODE_IMAGE}"
else
  echo "Container '${CONTAINER_NAME}' already exists. Opening an interactive shell..."

  # Check if the container is running, if not, start it
  if [ "$(docker ps -f name=^${CONTAINER_NAME}$ --format '{{.Names}}' | grep -c -w "${CONTAINER_NAME}")" -eq 0 ]; then
    echo "Starting container '${CONTAINER_NAME}'..."
    docker start ${CONTAINER_NAME}
  fi

  # Open an interactive shell in the container
  docker exec -it ${CONTAINER_NAME} /bin/bash
fi
