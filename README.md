# Midnight Node Docker

This allows for easy orchestration of the Midnight Node service.

## System requirements

- Install [Docker Engine](https://docs.docker.com/engine/install/)
- Install [Docker Compose](https://docs.docker.com/compose/install/)
- Install [direnv](https://direnv.net/docs/installation.html)

## Usage

1. Clone repository

2. In `.envrc` set CFG_PRESET to be the environment you wish to point to. Available options:
   - `qanet` - QA network
   - `testnet-02` - TestNet 02
   - `preview` - Preview network

3. run `direnv allow` to load the environment variables

4. Run `docker-compose up`

The `.envrc` file will automatically create random secrets and save them as `postgres.secret` (database password), `midnight-node.secret` (node private key), and `indexer.secret` (indexer app secret).

All services are defined in a single `compose.yml` file. Use Docker Compose profiles to control which services run:

**Available profiles:**

- (no profile) - Midnight Node only
- `cardano` - Adds Cardano stack (cardano-node, postgres, cardano-db-sync) and Indexer with GraphQL API at `http://localhost:8088`
- `ogmios` - Adds Ogmios service at `http://localhost:1337`
- `proof-server` - Adds local Proof Server at `http://localhost:6300`

**Usage examples:**

Run Midnight Node only:

```shell
docker compose up -d
```

Run Midnight Node + Cardano stack + Indexer:

```shell
docker compose --profile cardano up -d
```

Run with Cardano stack + Ogmios:

```shell
docker compose --profile cardano --profile ogmios up -d
```

Run everything (Cardano + Ogmios + Proof Server):

```shell
docker compose --profile cardano --profile ogmios --profile proof-server up -d
```

🚀 That's it.

### Troubleshooting

### Connecting to Ogmios

If you're using `midnight-node smartcontract` or `midnight-node wizards` that need ogmios, and you're running midnight-node in docker you must pass `-O ws://host.docker.internal:1337` as an argument.
(Once PartnerChains 1.7+ is released OGMIOS_URL env var can be set so that it just works, but for now you have to pass it as an argument.)

### Clean start

To restart from fresh, run:

```sh
docker compose --profile cardano --profile ogmios --profile proof-server down -v
docker compose --profile cardano --profile ogmios --profile proof-server kill
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
