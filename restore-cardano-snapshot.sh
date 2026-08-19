#!/usr/bin/env bash
set -euo pipefail

# This file is part of https://github.com/midnightntwrk/midnight-node-docker
# Copyright (C) 2025 Midnight Foundation
# SPDX-License-Identifier: Apache-2.0

# Load environment if direnv is not used
if [ -z "${MITHRIL_IMAGE:-}" ]; then
  if [ -f .envrc ]; then
    echo "Loading environment from .envrc..."
    source .envrc
  fi
fi

# Fallback defaults if still not set
NETWORK=${CARDANO_NETWORK:-preview}
DATA_DIR=${CARDANO_DATA_DIR:-./cardano-data}
MITHRIL_IMAGE=${MITHRIL_IMAGE:-ghcr.io/input-output-hk/mithril-client:latest}

echo "─── Cardano snapshot restoration (Mithril) ───"
echo "Network: $NETWORK"
echo "Data directory: $DATA_DIR"

if [ ! -d "$DATA_DIR" ]; then
    echo "Creating data directory $DATA_DIR..."
    mkdir -p "$DATA_DIR"
fi

# Check if DB is already populated
if [ -d "$DATA_DIR/db" ] && [ "$(ls -A "$DATA_DIR/db" 2>/dev/null)" ]; then
    echo "Error: $DATA_DIR/db is not empty."
    echo "If you want to restore a fresh snapshot, please remove the existing database first:"
    echo "  rm -rf $DATA_DIR/db"
    exit 1
fi

# Ensure we have the necessary Mithril variables
if [ -z "${MITHRIL_AGGREGATOR_ENDPOINT:-}" ] || [ -z "${MITHRIL_GENESIS_VERIFICATION_KEY:-}" ]; then
    echo "Error: MITHRIL_AGGREGATOR_ENDPOINT or MITHRIL_GENESIS_VERIFICATION_KEY not set."
    echo "Please ensure you have run 'direnv allow' or populated these variables in .envrc"
    exit 1
fi

echo "Pulling Mithril client image ($MITHRIL_IMAGE)..."
docker pull "$MITHRIL_IMAGE"

echo "Downloading latest snapshot for $NETWORK..."

# Check for required tools
for tool in jq wget zstd curl; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: $tool is not installed. Please install it first."
        exit 1
    fi
done

# Execute the main restoration
docker run --rm \
  -e AGGREGATOR_ENDPOINT="$MITHRIL_AGGREGATOR_ENDPOINT" \
  -e GENESIS_VERIFICATION_KEY="$MITHRIL_GENESIS_VERIFICATION_KEY" \
  -e ANCILLARY_VERIFICATION_KEY="$MITHRIL_ANCILLARY_VERIFICATION_KEY" \
  -v "$(pwd)/$DATA_DIR:/data" \
  "$MITHRIL_IMAGE" \
  cardano-db download latest --download-dir /data --include-ancillary

echo "─── Post-Restoration Fixes ───"

# Fix 1: Ensure protocolMagicId exists (required by cardano-node to identify the network)
if [ "$NETWORK" == "preview" ]; then MAGIC=2; elif [ "$NETWORK" == "preprod" ]; then MAGIC=1; else MAGIC=764824073; fi
echo -n "$MAGIC" > "$DATA_DIR/db/protocolMagicId"
echo "✅ Created protocolMagicId: $MAGIC"

# Fix 2: Manual Ledger Injection (Mithril often skips these or they fail to extract)
# We detect if ledger is empty or small and inject if necessary.
if [ -d "$DATA_DIR/db/ledger" ] && [ "$(ls -A "$DATA_DIR/db/ledger" 2>/dev/null)" ]; then
    echo "✅ Ledger state found."
else
    echo "⚠️ Ledger state missing. Injecting manual ancillary snapshot to bypass block replay..."
    # We fetch the ancillary URL dynamically from the aggregator for the 'latest' snapshot
    DIGEST=$(docker run --rm -e AGGREGATOR_ENDPOINT="$MITHRIL_AGGREGATOR_ENDPOINT" "$MITHRIL_IMAGE" cardano-db snapshot list --json | jq -r '.[0].hash')
    ANCILLARY_URL=$(curl -s "$MITHRIL_AGGREGATOR_ENDPOINT/artifact/cardano-database/$DIGEST" | jq -r '.ancillary.locations[0].uri')
    
    if [ "$ANCILLARY_URL" != "null" ]; then
        echo "Downloading ancillary files from $ANCILLARY_URL..."
        wget -q -O ancillary.tar.zst "$ANCILLARY_URL"
        zstd -d -q ancillary.tar.zst
        tar -xf ancillary.tar -C "$DATA_DIR/db/"
        rm -f ancillary.tar ancillary.tar.zst
        echo "✅ Ledger injection complete."
    else
        echo "❌ Could not find ancillary URL in aggregator metadata. Node will perform fallback replay."
    fi
fi

# Fix 3: Permissions (ensure Docker can read the files)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # On Linux, we might need to chown to 1000 (standard for cardano-node image)
    sudo chown -R 1000:1000 "$DATA_DIR/db" 2>/dev/null || true
fi
chmod -R 777 "$DATA_DIR/db" 2>/dev/null || true

echo "─── Fast Sync Complete ───"
echo "You can now start your Cardano node:"
echo "  docker compose -f compose-partner-chains.yml up -d cardano-node"
