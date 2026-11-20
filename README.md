# Midnight Node Docker

This allows for easy orchestration of the Midnight Node service.

## System requirements

- Install [Docker Engine](https://docs.docker.com/engine/install/)
- Install [Docker Compose](https://docs.docker.com/compose/install/)
- Install [direnv](https://direnv.net/docs/installation.html)
- `openssl` (creates the local TLS certificate for Postgres)

## Usage

1. Clone repository

2. In `.envrc` set CFG_PRESET to the network you want to join: `preview` (default), `preprod` or `mainnet`.
   Each preset in `.envrc.<preset>` sets the node image, the boot nodes and the matching Cardano network.

3. run `direnv allow` to load the environment variables

4. Run `docker-compose up`

The `.envrc` file will automatically create a random private key and save it as `midnight-node.privatekey`.

Choose which compose files to use:

- `compose.yml` for Midnight Node
- `compose-partner-chains.yml` for Cardano + DB Sync
- `proof-server.yml` for Local Proof Server

One can use one or multiple compose files at once.

For example, to run the Midnight Node, you can do:

```shell
docker compose up -d
```

or to run the Midnight Node and Cardano DB Sync, you can do:

```shell
docker compose -f ./compose-partner-chains.yml -f ./compose.yml up -d
```

or to run the Midnight Node, Cardano DB Sync and a local Proof Server, you can do:

```shell
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml up -d
```

🚀 That's it.

### Versions

| Component      | Version  | Source                                                                                  |
| -------------- | -------- | --------------------------------------------------------------------------------------- |
| midnight-node  | 2.1.101  | [support matrix](https://docs.midnight.network/relnotes/support-matrix)                 |
| cardano-node   | 11.0.1   | [Set up Cardano-db-sync](https://docs.midnight.network/nodes/cardano-db-sync)           |
| cardano-db-sync | 13.7.1.0 | [Set up Cardano-db-sync](https://docs.midnight.network/nodes/cardano-db-sync)          |
| PostgreSQL     | 17       | [Set up Cardano-db-sync](https://docs.midnight.network/nodes/cardano-db-sync)           |

### Postgres TLS

From node 2.1.101 the Midnight node connects to db-sync's Postgres only over TLS and refuses a
server that does not offer it (`server does not support TLS`). The `postgres` service in
`compose-partner-chains.yml` therefore runs with TLS on:

- `.envrc` creates a local CA and a server certificate in `./postgres-tls/` the first time it runs.
- The node checks the server certificate against `postgres-tls/ca.crt` (`SSL_ROOT_CERT`), and logs
  `Database connection SSL mode: VerifyFull` when it does.

If you use your own Postgres, turn on TLS there, and set `SSL_ROOT_CERT` to its CA certificate.

### Ports

Only the peer-to-peer ports (Midnight 30333, Cardano 3001) are published on all interfaces.
RPC (9944), Prometheus metrics (9615), Postgres and Ogmios (1337) are published on 127.0.0.1 only.
Set `POSTGRES_HOST_PORT` if port 5432 is already taken on the host.

### Upgrading from an older checkout

cardano-db-sync 13.7.1.0 needs its database replayed, and Postgres 17 cannot open a Postgres 15
data directory, so start db-sync's database from scratch:

```shell
docker compose -f ./compose-partner-chains.yml -f ./compose.yml down
docker volume rm midnight-node-docker_postgres-data midnight-node-docker_db-sync-data
```

Node 2.1.101 cannot be downgraded after it opens a data directory. See the
[node release notes](https://github.com/midnightntwrk/midnight-node/releases/tag/node-2.1.101).

### Troubleshooting

### Connecting to Ogmios

If you're using `midnight-node smartcontract` or `midnight-node wizards` that need ogmios, and you're running midnight-node in docker you must pass `-O ws://host.docker.internal:1337` as an argument.
(Once PartnerChains 1.7+ is released OGMIOS_URL env var can be set so that it just works, but for now you have to pass it as an argument.)

### Clean start

To restart from fresh, run:

```sh
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml down -v
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml kill
rm -R ./cardano-data
docker volume rm midnight-node-docker_midnight-data-testnet
```

#### Env vars not setup

If you get warnings like this then likely `direnv` is not setup or `direnv allow` has not been run:

```text
WARN[0000] The "HOME_IPC" variable is not set. Defaulting to a blank string.
```

#### IPC Errors

If you get IPC errors with Cardano node then delete the stale
socket file: `rm ~/ipc/node.socket` and restart.

#### Midnight node Errors

If you encounter this message on the midnight node it's likely that the
cardano-node is still syncing and it will go away once it's fully synced:

```text
Unable to author block in slot. Failure creating inherent data provider:
'No latest block on chain.' not found.
Possible causes: main chain follower configuration error, db-sync not synced fully,
or data not set on the main chain.
```

### LICENSE

Apache 2.0. PRs welcome, please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.
