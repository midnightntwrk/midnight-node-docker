#!/usr/bin/env bash

if [ -z "$MIDNIGHT_NODE_IMAGE" ]; then
  echo "Error: Env var MIDNIGHT_NODE_IMAGE is not set or is empty"
  echo "Please install direnv and run 'direnv allow' to activate it."
  exit 1
fi

docker exec -t midnight /midnight-node "$@"