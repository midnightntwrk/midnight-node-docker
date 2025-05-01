#!/usr/bin/env bash
#
# This script will reset the midnight node's data back to nothing.
#

docker rm -f midnight
rm -R ./data
docker volume rm midnight-node-docker_midnight-data-testnet
