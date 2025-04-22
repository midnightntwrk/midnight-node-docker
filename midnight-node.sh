#!/usr/bin/env bash

docker run -it \
  -e CFG_PRESET=${CFG_PRESET} \
  -e DB_SYNC_POSTGRES_CONNECTION_STRING=${DB_SYNC_POSTGRES_CONNECTION_STRING} \
  -v ./data:/data ${MIDNIGHT_NODE_IMAGE} \
  $*
