# alias-swift-api

## Run
1. First, install vapor. See [Guide](https://docs.vapor.codes/install/macos/)
2. Run:
``` bash
docker compose up db
```
3. Open Package.swift use xcode
4. Build the project
5. Run:
```bash
vapor run migrate
```
6. Run project in Xcode

## Docker
1. Run
```bash
docker compose build
docker compose up
```
2. On the other terminal run:
```bash
docker compose run migrate
```
