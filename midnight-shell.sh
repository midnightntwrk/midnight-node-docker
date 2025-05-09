#!/usr/bin/env bash
#
# This will mount the ./data dir and allow you to run a series of midnight commands
#
# To register an SPO:
#
# ./midnight-node wizards generate-keys
# ./midnight-node wizards register1  USE Ogmios hostname: host.docker.internal
#

if [ -z "$MIDNIGHT_NODE_IMAGE" ]; then
  echo "Error: Env var MIDNIGHT_NODE_IMAGE is not set or is empty"
  echo "Please install direnv and run 'direnv allow' to activate it."
  exit 1
fi

if [[ "$(uname)" == "Darwin" ]]; then
  # For arm mac persuade docker to be more liberal:
  export DOCKER_DEFAULT_PLATFORM=linux/arm64
fi

docker run -it \
  -e CFG_PRESET="${CFG_PRESET}" \
  -e DB_SYNC_POSTGRES_CONNECTION_STRING="${DB_SYNC_POSTGRES_CONNECTION_STRING}" \
  -v ./data:/data \
  -v ./envs/${CFG_PRESET}/pc-chain-config.json:/pc-chain-config.json \
  --entrypoint bash \
  "${MIDNIGHT_NODE_IMAGE}"
