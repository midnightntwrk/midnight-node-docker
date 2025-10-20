#!/usr/bin/env bash

if [ -z "$MIDNIGHT_CONTAINER_NAME" ]; then
  echo "Error: Env var MIDNIGHT_CONTAINER_NAME is not set or is empty"
  echo "Please install direnv and run 'direnv allow' to activate it."
  exit 1
fi

docker exec -t ${MIDNIGHT_CONTAINER_NAME} /midnight-node "$@"
