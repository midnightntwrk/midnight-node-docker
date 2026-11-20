# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 🚀 Features

- Presets for the public networks: `preview` (default), `preprod` and `mainnet`, with midnight-node 2.1.101. Removed `testnet-02`, which no longer exists.
- db-sync's Postgres runs with TLS, which midnight-node 2.1.101 requires. `.envrc` creates a local CA and server certificate, and the node verifies the server (`SSL_ROOT_CERT`).
- cardano-node 11.0.1, cardano-db-sync 13.7.1.0 and PostgreSQL 17, as in the Midnight docs. Needs a fresh db-sync database (see "Upgrading from an older checkout").
- RPC, Prometheus, Postgres and Ogmios ports are published on 127.0.0.1 only. `POSTGRES_HOST_PORT` sets the host port for Postgres.

## 🐛 Fixes

- `midnight-node.sh`, `midnight-shell.sh`, `reset-midnight.sh` and `test.sh` use the `midnight-node` container name from `compose.yml`.
- `cardano-cli.sh` passes the right network magic for Preprod (1) and Mainnet.

- Cardano's ipc socket file is now stored in a docker volume so when stale can be recreated on all OSes.
- `cardano-cli.sh`, `midnight-node.sh` and `midnight-shell.sh` execute within the running container.
- Switch networks by altering CFG_PRESET only
- Added `test.sh` to detect problems and provide solutions.
- Added `reset-midnight.sh` script to clear down midnight's blockchain.
- `--validator` flag not set by default.
- Port from prior repository (#3)
- If direnv isn't working give an appropriate error message.
- /data dir should be .gitignored
- Automatically create a random node key.
- Only randomise the postgres password once.
- Parametise cardano network

## 💼 Other

- *(deps)* Bump checkmarx/ast-github-action from 2.3.18 to 2.3.19 (#9)
- Be explicit about image
