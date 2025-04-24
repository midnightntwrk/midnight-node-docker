# Midnight Node Docker

This allows for easy orchestration of the Midnight Node service.

## System requirements

- Install [Docker Engine](https://docs.docker.com/engine/install/)
- Install [Docker-Compose](https://docs.docker.com/compose/install/)
- Install [direnv](https://direnv.net/docs/installation.html)

## Usage

1. Clone repo

2. Modify values in `.envrc` file as applicable

3. Run `direnv allow` to load the environment variables

3. Choose which compose files to use:
   - `compose.yml` for Midnight Node
   - `compose-partner-chains.yml` for Cardano DB Sync
   - `proof-server.yml` for Local Proof Server

One can use one or multiple compose files at once.

For example, to run the Midnight Node, you can do:
```shell
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose up -d
```

or to run the Midnight Node and Cardano DB Sync, you can do:
```shell
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose -f ./compose-partner-chains.yml -f ./compose.yml up -d
```

or to run the Midnight Node, Cardano DB Sync and a local Proof Server, you can do:
```shell
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml up -d
```

🚀 That's it.

### LICENSE

Apache 2.0. PRs welcome, please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.
