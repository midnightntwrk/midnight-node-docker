# Midnight Node Docker

This allows for easy orchestration of the Midnight Node service.

## System requirements

- Install [Docker Engine](https://docs.docker.com/engine/install/)
- Install [Docker Compose](https://docs.docker.com/compose/install/)
- Install [direnv](https://direnv.net/docs/installation.html)

## Usage

1. Clone repository

2. In `.envrc` set CFG_PRESET to be the environment you wish to point to (E.g. testnet-02).

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
