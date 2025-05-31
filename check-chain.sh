#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────
RPC_URL="http://127.0.0.1:9944"     # your node’s JSON-RPC HTTP endpoint
RPC_URL="https://rpc.qanet.dev.midnight.network/"

echo Get genesis utxo from running midnight node...
GET_PC_PARAMS="curl -s -H \"Content-Type:application/json\" \
  -d '{\"jsonrpc\":\"2.0\",\"method\":\"sidechain_getParams\",\"params\":[],\"id\":1}' \
  \"$RPC_URL\""
GENESIS_UTXO=$(eval "$GET_PC_PARAMS" | jq -r '.result.genesis_utxo')
echo "GENESIS_UTXO=$GENESIS_UTXO"


export GENESIS_TX_HASH="${GENESIS_UTXO%%#*}"
export GENESIS_COIN_INDEX="${GENESIS_UTXO##*#}"
echo Check coin has been spent according to cardano...
QUERY_UTXO_CMD="./cardano-cli.sh query utxo --tx-in $GENESIS_UTXO --output-json 2>/dev/null"
genesis_utxo_json=$(eval "$QUERY_UTXO_CMD");

if [ "$genesis_utxo_json" = "{}" ] ; then
    echo "✅ Genesis can't be found in UTXOs."
else
    echo "❌ As part of chain registration process Genesis UTXO should have been spent but $genesis_utxo_json"
fi

# Assume that db-sync is synced.

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


EPOCH_CMD="./cardano-cli.sh query tip 2>/dev/null"
tip=$(eval "$EPOCH_CMD");
CURRENT_EPOCH=$(echo "$tip" | jq -r '.epoch')
echo "epoc=$CURRENT_EPOCH"


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
