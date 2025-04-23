# Midnight Node Docker

This allows for easy orchestration of the Midnight Node service.

## System requirements

- Install [Docker-Compose](https://docs.docker.com/compose/install/)
- Install [direnv](https://direnv.net/docs/installation.html)
- Once cloned, run `direnv allow` once to set the environment variables.

## Usage

1. Clone repo

2. run `direnv allow` (only needs to be done when '.envrc` has been modified)

3. Run `docker-compose up`

The `.envrc` file will automatically create a random private key and save it as `midnight-node.privatekey`.

```shell
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose up -d
```

or for both Midnight and Cardano:

```shell
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose -f ./compose-partner-chains.yml -f ./compose.yml up -d
```

or for Midnight, Cardano and a local Proof Server:

```shell
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml up -d
```

🚀 That's it.

### Troubleshooting

If you get warnings like this then likely `direnv` is not setup or `direnv allow` has not been run:
```
WARN[0000] The "HOME_IPC" variable is not set. Defaulting to a blank string.
```

### LICENSE

Apache 2.0. PRs welcome, please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.
