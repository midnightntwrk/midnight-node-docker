#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────
# Accept parameters for RPC_URL and all env vars not set within this file.
usage() {
  echo "Usage: $0 [--rpc-url URL] [--postgres-password PASSWORD] [--postgres-port PORT] [--postgres-user USER] [--postgres-db DB] [--cardano-network NETWORK]"
  echo ""
  echo "All parameters are optional. If not provided, the script will use the corresponding environment variable."
  echo "If neither is set, the script will exit with an error."
  exit 1
}

# Default values from environment
RPC_URL="${RPC_URL:-http://127.0.0.1:9933}"     # your node’s JSON-RPC HTTP endpoint
# RPC_URL="https://rpc.qanet.dev.midnight.network/"

POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_PORT="${POSTGRES_PORT:-}"
POSTGRES_USER="${POSTGRES_USER:-}"
POSTGRES_DB="${POSTGRES_DB:-}"
CARDANO_NETWORK="${CARDANO_NETWORK:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rpc-url)
      RPC_URL="$2"
      shift 2
      ;;
    --postgres-password)
      POSTGRES_PASSWORD="$2"
      shift 2
      ;;
    --postgres-port)
      POSTGRES_PORT="$2"
      shift 2
      ;;
    --postgres-user)
      POSTGRES_USER="$2"
      shift 2
      ;;
    --postgres-db)
      POSTGRES_DB="$2"
      shift 2
      ;;
    --cardano-network)
      CARDANO_NETWORK="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

# Validate required variables (report all missing at once)
missing_vars=()
[[ -z "$RPC_URL" ]] && missing_vars+=("RPC_URL")
[[ -z "$POSTGRES_PASSWORD" ]] && missing_vars+=("POSTGRES_PASSWORD")
[[ -z "$POSTGRES_PORT" ]] && missing_vars+=("POSTGRES_PORT")
[[ -z "$POSTGRES_USER" ]] && missing_vars+=("POSTGRES_USER")
[[ -z "$POSTGRES_DB" ]] && missing_vars+=("POSTGRES_DB")
[[ -z "$CARDANO_NETWORK" ]] && missing_vars+=("CARDANO_NETWORK")

if (( ${#missing_vars[@]} )); then
  echo "❌ ERROR: The following required arguments are missing. You can provide them as command-line arguments:"
  for var in "${missing_vars[@]}"; do
    case "$var" in
      RPC_URL) echo "  --rpc-url <value>" ;;
      POSTGRES_PASSWORD) echo "  --postgres-password <value>" ;;
      POSTGRES_PORT) echo "  --postgres-port <value>" ;;
      POSTGRES_USER) echo "  --postgres-user <value>" ;;
      POSTGRES_DB) echo "  --postgres-db <value>" ;;
      CARDANO_NETWORK) echo "  --cardano-network <value>" ;;
      *) echo "  $var" ;;
    esac
  done
  exit 1
fi

echo Get genesis utxo from running midnight node...
GET_PC_PARAMS="curl -s -H \"Content-Type:application/json\" \
  -d '{\"jsonrpc\":\"2.0\",\"method\":\"sidechain_getParams\",\"params\":[],\"id\":1}' \
  \"$RPC_URL\""
GENESIS_UTXO=$(eval "$GET_PC_PARAMS" | jq -r '.result.genesis_utxo')
echo "GENESIS_UTXO=$GENESIS_UTXO"

export GENESIS_TX_HASH="${GENESIS_UTXO%%#*}"
export GENESIS_COIN_INDEX="${GENESIS_UTXO##*#}"
echo Check if coin has been spent according to cardano...
QUERY_UTXO_CMD="./cardano-cli.sh query utxo --tx-in $GENESIS_UTXO --output-json --cardano-network $CARDANO_NETWORK"
genesis_utxo_json=$(eval "$QUERY_UTXO_CMD");

if [ "$genesis_utxo_json" = "{}" ] ; then
    echo "✅ Genesis can't be found in UTXOs."
else
    echo "❌ As part of chain registration process Genesis UTXO should have been spent but $genesis_utxo_json"
fi

# DB-sync should be synced!
tip_json=$(docker exec cardano-node cardano-cli query tip --socket-path /ipc/node.socket --testnet-magic 2)
sync_progress=$(echo "$tip_json" | jq -r '.syncProgress')
if [[ "$sync_progress" != "100.00" ]]; then
    echo "❌ ERROR: DB-sync is not fully synced. syncProgress=$sync_progress"
    exit 1
else
    echo "✅ Cardano-node is at the latest tip, synced."
fi

# Find spent UTXO:
export PGPASSWORD=$POSTGRES_PASSWORD

spent_utxo=$(psql \
  -h 127.0.0.1 -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -tAc "SELECT
  tx_out.tx_id,
  encode(tx.hash, 'hex') AS tx_hash,
  tx_out.index,
  tx_out.value,
  tx_out.address,
  datum.bytes AS inline_datum
FROM tx_out
JOIN tx ON tx.id = tx_out.tx_id
LEFT JOIN datum ON tx_out.inline_datum_id = datum.id
WHERE tx.hash = '\\x${GENESIS_TX_HASH}'
LIMIT 10;
 ;")

if [ "$spent_utxo" = "" ] ; then
    echo "❌ As part of chain registration process Genesis UTXO should have been spent but can't find it in db-sync's spent list: $spent_utxo"
else
    echo "✅ Spent genesis coin found: '$spent_utxo'"

    # can show url to tx hash https://preview.cexplorer.io/tx/1bb8027cb698c4b4c829396ac6eabac2ad46d80744c7a6822298dd76633c4f4f
fi

echo "Querying Cardano chain tip for current epoch..."
EPOCH_CMD="./cardano-cli.sh query tip --cardano-network $CARDANO_NETWORK 2>/dev/null"
tip=$(eval "$EPOCH_CMD");
CURRENT_EPOCH=$(echo "$tip" | jq -r '.epoch')
echo "Current Cardano epoch: $CURRENT_EPOCH"

# curl -s -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"sidechain_getStatus","params":[],"id":1}' https://rpc.qanet.dev.midnight.network/

# {"jsonrpc":"2.0","id":1,"result":{"sidechain":{"epoch":242583,"slot":291100548,"nextEpochTimestamp":1746604800000},"mainchain":{"epoch":925,"slot":79947270,"nextEpochTimestamp":1746662400000}}}%

# sidechain_getEpochCommittee
# sidechain_getRegistrations

EPOCH=$CURRENT_EPOCH
GET_PC_ARIADNE_PARAMS="curl -s -H \"Content-Type:application/json\" \
  -d '{\"jsonrpc\":\"2.0\",\"method\":\"sidechain_getAriadneParameters\",\"params\":[$EPOCH],\"id\":1}' \"$RPC_URL\""
echo "$GET_PC_ARIADNE_PARAMS"
ARIADNE_PARAMS=$(eval "$GET_PC_ARIADNE_PARAMS")
if [[ $ARIADNE_PARAMS == *ExpectedDataNotFound* ]]; then
    echo No current ariadne registration...
    echo Checking for future ariadne registration...
    START_EPOCH=$CURRENT_EPOCH  # Assume EPOCH is already set

    for ((i = 0; i <= 10; i++)); do
        CURRENT_EPOCH=$((START_EPOCH + i))
        echo "Checking epoch $CURRENT_EPOCH"

        # Replace this with your actual command and condition
        RESPONSE=$(curl -s -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"sidechain_getAriadneParameters","params":['"$CURRENT_EPOCH"'], "id":1}' "$RPC_URL")

        if [[ "$RESPONSE" != *"ExpectedDataNotFound"* ]]; then
            ACTIVE_EPOCH=$CURRENT_EPOCH
            ARIADNE_PARAMS=$RESPONSE
            DIFF=$((CURRENT_EPOCH - EPOCH))
            echo "Registration found at epoch $CURRENT_EPOCH (active in $DIFF days time)"
            echo "(SPOs can start registering now)"
            break
        fi
    done
    if [[ -z "$ACTIVE_EPOCH" ]]; then
        echo "No pending registration for the chain. Please register the chain's Genesis UTXO:"
        echo "./midnight-node wizards setup-main-chain-state (but ./midnight-node wizards prepare-configuration will need to have been done first and ./midnight-node wizards generate-keys before that.)"
    fi
else
    ACTIVE_EPOCH=$CURRENT_EPOCH
    echo Found current ariadne registration...
fi

START_EPOCH=$CURRENT_EPOCH  # Assume EPOCH is already set
for ((i = 0; i <= 3; i++)); do
    CURRENT_EPOCH=$((START_EPOCH + i))

    # Replace this with your actual command and condition
    RESPONSE=$(curl -s -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"sidechain_getAriadneParameters","params":['"$CURRENT_EPOCH"'], "id":1}' "$RPC_URL")

    if [[ "$RESPONSE" != *"ExpectedDataNotFound"* ]]; then
        ACTIVE_EPOCH=$CURRENT_EPOCH
        ARIADNE_PARAMS=$RESPONSE
        DIFF=$((CURRENT_EPOCH - EPOCH))

        # given there is a registration, check it's valid.
        PERMISSIONED_CANDIDATES_VALID=$(echo "$ARIADNE_PARAMS" | jq -r '[.result.permissionedCandidates[] | select(.isValid == true)] | length')
        CANDIDATES_VALID=$(echo "$ARIADNE_PARAMS" | jq -r '[.result.candidateRegistrations[][] | select(.isValid == true)] | length')
        INTERNAL_SPO_COUNT=$(echo "$ARIADNE_PARAMS" |jq '.result.permissionedCandidates | length')
        EXTERNAL_SPO_COUNT=$(echo "$ARIADNE_PARAMS" |jq '.result.candidateRegistrations | length')
        if [[ "$PERMISSIONED_CANDIDATES_VALID" == "$INTERNAL_SPO_COUNT" ]]; then
            PERM_MSG="✅ All $INTERNAL_SPO_COUNT permissioned candidates valid"
        else
            PERM_MSG="❌ $PERMISSIONED_CANDIDATES_VALID of $INTERNAL_SPO_COUNT permissioned candidates are valid"
        fi
        if [[ "$CANDIDATES_VALID" == "$EXTERNAL_SPO_COUNT" ]]; then
            CAND_MSG="✅ All $EXTERNAL_SPO_COUNT candidate registrations valid"
        else
            CAND_MSG="❌ $CANDIDATES_VALID of $EXTERNAL_SPO_COUNT candidate registrations valid"
        fi

        echo "✅ Epoch $CURRENT_EPOCH ($DIFF days time) | $CAND_MSG | $PERM_MSG"
    else
        echo "❌ Epoch $CURRENT_EPOCH : ExpectedDataNotFound"
    fi
done

# midnight_apiVersions
# midnight_ledgerVersion

# Registrations status for epoch 929:
# running external command: /midnight-node registration-status --mainchain-pub-key 0x1f4bf447da2b78482b2656f7f504b321c9f0b8712faabbd0de7c47ab13d9cd4a --mc-epoch-number 929 --chain chain-spec.json --base-path /tmp/.tmpii6vGf
# command output: Error: Input("ChainSpec Parse error: Error opening spec file `chain-spec.json`: No such file or directory (os error 2)")
# Running executable failed with status exit status
