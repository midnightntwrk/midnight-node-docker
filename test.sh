#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────
RPC_URL="http://127.0.0.1:9944"     # your node’s JSON-RPC HTTP endpoint
MAX_LAG=0                           # threshold (0 means any block >0 is OK)
MAX_FINALITY_LAG=15
OGMIOS_LAG=20

# Check direnv allow has been run...
if [ -z "$MIDNIGHT_NODE_IMAGE" ]; then
  echo "Error: MIDNIGHT_NODE_IMAGE environment variable is not set - run direnv allow"
  exit 1
fi

# check recent version of docker is running...
docker_version=$(docker --version | awk '{split($3, v, "."); print v[1]}')
if (( docker_version < 26 )); then
    echo "Docker major version $docker_version is not at least v26 - please upgrade docker"
    exit 1
fi

if [ ! -S "$HOME_IPC/node.socket" ]; then
  # cardano socket does not exit...
  cardano_container=$(docker ps --filter "name=cardano-node")
  if [[ -z "$cardano_container" ]]; then
    echo "cardano container not running, please run docker compose -f ./compose-partner-chains.yml -f ./compose.yml -d"
    exit 1
  else
    echo "cardano container running: $cardano_container"
  fi

  echo "Tail cardano-node waiting for it to be ready..."
  echo "(lots of logs: will take a few seconds before you see anything)"
  docker logs cardano-node --since 5s -f &
  CARDANO_LOG_PID=$!

  # Wait for the file to appear
  while [ ! -e "$HOME_IPC/node.socket" ]; do
      sleep 1
  done
  echo Cardano node started....

  # Stop following cardano logs
  kill "$CARDANO_LOG_PID"
else
  # Check if socket is stale...
  if ! lsof "$HOME_IPC/node.socket" > /dev/null; then
    echo "❌ No process is using the Cardano socket file. It may be stale - please delete $HOME_IPC/node.socket and restart cardano components"
    exit 1
  else
    echo "✅ Cardano node appears to be using the socket."
  fi
fi


if tip_json=$(./cardano-cli.sh query tip 2>/dev/null); then
  cardano_tip=$(jq -r '.slot' <<<"$tip_json")
  echo "✅ Cardano Node is responding. Current slot: $cardano_tip"
  sync=$(jq -r '.syncProgress' <<<"$tip_json")
  echo "✅ Cardano sync progress: $sync"
else
  ./cardano-cli.sh query tip
  echo "❌ Cardano Node is not responding! - check 'docker logs cardano-node'"
  exit 1
fi

# Ogmios is typically next to get setup:
OGMIOS_HEALTH=$(curl -sS http://localhost:1337/health)
ogmios_tip=$(echo "$OGMIOS_HEALTH" | jq '.lastKnownTip.slot')

lag=$(( cardano_tip - ogmios_tip ))
if (( lag < OGMIOS_LAG )); then
  echo "✅ Ogmios lag=$OGMIOS_LAG"
else
  echo "$OGMIOS_HEALTH"
  echo "❌ Ogmios lagging by $lag: Cardano: $cardano_tip > "
  echo "                        Ogmios: $ogmios_tip"
  exit 1
fi

# Look for any containers failing or still starting
# (this will ensure postgres is running)
unhealthy=$(docker ps --filter "health=unhealthy" --format '{{.Names}}')
starting=$(docker ps --filter "health=starting"  --format '{{.Names}}')

if [[ -n "$unhealthy" ]]; then
  echo "❌ Unhealthy containers:" 
  echo "$unhealthy"
  exit 1
elif [[ -n "$starting" ]]; then
  echo "⏳ Still starting:" 
  echo "$starting"
  exit 1
else
  echo "✅ All containers are healthy!"
fi

#
# Check db-sync is working:
#
export PGPASSWORD=$POSTGRES_PASSWORD

db_sync_tip=$(psql \
  -h 127.0.0.1 -p 5432 \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -tAc "SELECT COALESCE(MAX(slot_no),0) FROM block;")

echo "   cardano-node tip slot: $cardano_tip"
echo "   db-sync tip slot:      $db_sync_tip"
max_lag=100
lag=$(( cardano_tip - db_sync_tip ))
if (( lag < 0 )); then
  echo "⚠️  db-sync ahead of node? (lag = $lag)"
  exit 1
elif (( lag > max_lag )); then
  echo "❌ db-sync is behind by $lag slots"
  exit 1
else
  echo "✅ db-sync is in sync (lag = $lag slots)"
fi


#
# Check midnight-node has peers:
#


HEALTH=$(curl -s -H "Content-Type:application/json" \
  -d '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
  "$RPC_URL")

PEERS=$(echo "$HEALTH" | jq '.result.peers')
SHOULD_HAVE_PEERS=$(echo "$HEALTH" | jq '.result.shouldHavePeers')
IS_SYNCING=$(echo "$HEALTH" | jq '.result.isSyncing')

if [[ "$SHOULD_HAVE_PEERS" == "true" && "$PEERS" -lt 1 ]]; then
  echo "⚠️  midnight-node has $PEERS peers!"

  echo "$HEALTH"

  docker logs midnight  2>&1 | grep "Genesis mismatch"
  echo "For genesis mismatch, check that CFG_PRESET=$CFG_PRESET is aligned with BOOTNODES=$BOOTNODES"
  echo "If they're aligned then run ./reset-midnight.sh and restart"
  exit 1
fi

if [[ "$IS_SYNCING" == "true" ]]; then
  echo "   Midnight is still syncing with $CFG_PRESET..."
  while :; do
      SYNC=$(curl -s -H "Content-Type:application/json" \
      -d '{"jsonrpc":"2.0","method":"system_syncState","params":[],"id":1}' \
      "$RPC_URL")
      read -r CURRENT TARGET <<< "$(echo "$SYNC" | jq -r '.result | "\(.currentBlock) \(.highestBlock)"')"
      echo "   midnight Syncing: $CURRENT / $TARGET"
      if [ "$CURRENT" == "$TARGET" ]; then
        break
      fi
      sleep 6
  done
fi

#
# Check midnight-node is producing blocks:
#

# ─── 1) Probe the RPC port ────────────────────────────────────────────────────
if ! nc -z localhost 9944; then
  echo "❌ RPC port 9944 is not listening"
  exit 1
fi

# ─── 2) Query the latest header ───────────────────────────────────────────────
resp=$(curl -s -H "Content-Type:application/json" \
  -d '{"jsonrpc":"2.0","method":"chain_getHeader","params":[],"id":1}' \
  "$RPC_URL")

# extract the "number" field (hex string, e.g. "0x1a")
hexnum=$(jq -r '.result.number // ""' <<<"$resp")

if [[ -z "$hexnum" ]]; then
  echo "❌ Failed to get header.number from RPC:"
  echo "$resp"
  exit 1
fi

# ─── 3) Convert hex to decimal ────────────────────────────────────────────────
# strip “0x” then convert
best_block=$((hexnum))

echo "   → Current block number: $best_block"

# ─── 4) Check against your threshold ─────────────────────────────────────────
if (( best_block > MAX_LAG )); then
  echo "✅ Chain is past block 0 (at block $best_block)"
else
  echo "❌ Chain has not progressed past block 0 (still at $best_block)"

  echo "if genesis mismatch check CFG_PREFIX is correct"
  docker logs midnight  2>&1 | grep "Genesis mismatch"
  echo "Also check that CFG_PRESET=$CFG_PRESET is alined with BOOTNODES=$BOOTNODES"

  exit 1
fi

#
# Check midnight finality
#

# ─── 3) Get the hash of the latest _finalized_ block ──────────────────────────
fin_hash=$(curl -s -H "Content-Type:application/json" \
  -d '{"jsonrpc":"2.0","method":"chain_getFinalizedHead","params":[],"id":1}' \
  "$RPC_URL" | jq -r '.result // empty')

if [[ -z "$fin_hash" ]]; then
  echo "❌ Failed to fetch finalized head hash"
  exit 1
fi

# ─── 4) Fetch the header for that finalized hash ───────────────────────────────
fin_resp=$(curl -s -H "Content-Type:application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"chain_getHeader\",\"params\":[\"$fin_hash\"],\"id\":1}" \
  "$RPC_URL")

fin_hex=$(jq -r '.result.number // empty' <<<"$fin_resp")
if [[ -z "$fin_hex" ]]; then
  echo "❌ Failed to fetch header for finalized hash:"
  echo "$fin_resp"
  exit 1
fi
fin_block=$((fin_hex))

# ─── 5) Report and check lag ───────────────────────────────────────────────────
lag=$(( best_block - fin_block ))

echo "   → Best head block:       $best_block"
echo "   → Finalized head block:  $fin_block"
echo "   → Finality lag (best – finalized): $lag blocks"

if (( lag > MAX_FINALITY_LAG )); then
  echo "⚠️  Finality lag is above ${MAX_FINALITY_LAG}! (the chain is producing blocks faster than they finalize)"
  exit 1
else
  echo "✅ Finality is healthy (lag ≤ ${MAX_FINALITY_LAG})."
fi

echo "✅ Any other problems are your own. Have fun!"
echo ""
echo " View Ogmios: http://localhost:1337/"


# ogmios can be queried with json rpc:
# curl -H 'content-type: application/json' http://localhost:1337 -d '{"jsonrpc": "2.0", "method":"queryLedgerState/utxo", "params":{"addresses":["addr_test1vphpcf32drhhznv6rqmrmgpuwq06kug0lkg22ux777rtlqst2er0r"]}}'
