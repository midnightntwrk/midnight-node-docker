#!/usr/bin/env bash

# Check if the container already exists
if [ "$(docker ps -a -f name=^${MIDNIGHT_CONTAINER_NAME}$ --format '{{.Names}}' | grep -c -w "${MIDNIGHT_CONTAINER_NAME}")" -eq 0 ]; then
  echo "Container '${MIDNIGHT_CONTAINER_NAME}' does not exist. Creating and starting it..."

  # Run the container with the specified configuration
  docker run -it \
    --name ${MIDNIGHT_CONTAINER_NAME} \
    -e CFG_PRESET="${CFG_PRESET}" \
    -e DB_SYNC_POSTGRES_CONNECTION_STRING="${DB_SYNC_POSTGRES_CONNECTION_STRING}" \
    -v ./data:/data \
    -v "./envs/${CFG_PRESET}/pc-chain-config.json:/pc-chain-config.json" \
    --entrypoint bash \
    "${MIDNIGHT_NODE_IMAGE}"
else
  echo "Container '${MIDNIGHT_CONTAINER_NAME}' already exists. Opening an interactive shell..."

  # Check if the container is running, if not, start it
  if [ "$(docker ps -f name=^${MIDNIGHT_CONTAINER_NAME}$ --format '{{.Names}}' | grep -c -w "${MIDNIGHT_CONTAINER_NAME}")" -eq 0 ]; then
    echo "Starting container '${MIDNIGHT_CONTAINER_NAME}'..."
    docker start ${MIDNIGHT_CONTAINER_NAME}
  fi

  # Open an interactive shell in the container
  docker exec -it ${MIDNIGHT_CONTAINER_NAME} /bin/bash
fi
