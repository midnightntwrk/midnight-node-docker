docker run -it \
  --name midnight \
  -e CFG_PRESET="${CFG_PRESET}" \
  -e DB_SYNC_POSTGRES_CONNECTION_STRING="${DB_SYNC_POSTGRES_CONNECTION_STRING}" \
  -v ./data:/data \
  -v "./envs/${CFG_PRESET}/pc-chain-config.json:/pc-chain-config.json" \
  --entrypoint bash \
  "${MIDNIGHT_NODE_IMAGE}"