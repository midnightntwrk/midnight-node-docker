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

# Run in same container as cardano-node.
# docker exec doesn't support `--env` params so wrapped in an `sh`.
docker exec -t cardano-node sh -c "CARDANO_NODE_NETWORK_ID=${CARDANO_NODE_NETWORK_ID} /usr/local/bin/cardano-cli $*"
