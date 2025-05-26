# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 🚀 Features

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
