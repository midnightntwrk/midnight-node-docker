#!/usr/bin/env bash

if [ "$CARDANO_NETWORK" = "preview" ]; then
  CARDANO_NODE_NETWORK_ID=2
elif [ "$CARDANO_NETWORK" = "mainnet" ]; then
  CARDANO_NODE_NETWORK_ID=1
elif [ "$CARDANO_NETWORK" = "preprod" ]; then
  CARDANO_NODE_NETWORK_ID=0
else
  echo "Error: Unknown CARDANO_NETWORK: $CARDANO_NETWORK"
  exit 1
fi

DOCKER_DEFAULT_PLATFORM=linux/amd64 docker run --rm \
  --network container:cardano-node \
  -e CARDANO_NODE_SOCKET_PATH="/ipc/node.socket" \
  -e CARDANO_NODE_NETWORK_ID=${CARDANO_NODE_NETWORK_ID} \
  -v ~/ipc:/ipc \
  ${CARDANO_IMAGE} \
  cli $*
