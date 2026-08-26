#!/usr/bin/env bash

# Parse --cardano-network argument if present, otherwise use env var
NETWORK_ARG=""
NEW_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cardano-network)
      NETWORK_ARG="$2"
      shift 2
      ;;
    *)
      NEW_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ -n "$NETWORK_ARG" ]; then
  CARDANO_NETWORK="$NETWORK_ARG"
fi

if [ -z "$CARDANO_NETWORK" ]; then
  echo "Error: CARDANO_NETWORK not set. Please provide --cardano-network <network> or set the CARDANO_NETWORK environment variable."
  exit 1
fi

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
docker exec -t cardano-node sh -c "CARDANO_NODE_NETWORK_ID=${CARDANO_NODE_NETWORK_ID} /usr/local/bin/cardano-cli ${NEW_ARGS[*]}"
