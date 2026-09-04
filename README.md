# dotfiles

## セットアップ

```sh
./setup.sh    # シンボリックリンクを張り、Homebrew と最低限のツールを入れる
mise install  # .config/mise/config.toml のツールを入れる
```

`setup.sh` は既存ファイルがあれば `.bak` に退避してからリンクを張るので、何度実行してもよい。

## Docker

Docker Desktop は使わず、以下の組み合わせで動かしている。

- **colima** — Linux VM と Docker デーモン
- **docker-cli / docker-compose / buildx** — すべて mise 管理

### 使う前に colima を起動する

Docker Desktop と違って常駐しないので、起動する手間がかかる。

```sh
colima start  # Mac を再起動するたびに必要
docker ps     # 起動していないと "failed to connect to the docker API" になる
colima stop   # 止める
```

VM のスペックは `colima start --cpu 4 --memory 8` のように指定する。一度指定すれば次回以降も引き継がれる。

### compose と buildx はラッパー経由

`docker compose` / `docker buildx` は docker CLI プラグインで、`~/.docker/cli-plugins/docker-<名前>` という名前で置く必要がある。ところが mise (aqua) が入れるバイナリ名は `docker-cli-plugin-docker-<名前>` で一致しない。かといって mise の shim を別名でリンクすると、shim が `argv[0]` でツールを判別する都合で `not a valid shim` になる。

そこで `.docker/cli-plugins/` にラッパースクリプトを置き、`setup.sh` がそれをリンクしている。ラッパーは実行のたびに `mise where` で実体のパスを解決するため、バージョンを上げても `mise install` だけで追従する。

buildx は mise のレジストリに短縮名が無いので、`config.toml` ではバックエンド (`aqua:docker/buildx`) を明示している。

### うまくいかないとき

| 症状 | 原因と対処 |
|---|---|
| `docker: unknown command: docker compose` | プラグインがリンクされていない → `./setup.sh` |
| `failed to connect to the docker API` | デーモンが動いていない → `colima start` |
| `docker --help` に `failed to fetch metadata` | リンク先が壊れている → `mise install` してから `./setup.sh` |
| `DEPRECATED: The legacy builder is deprecated` | buildx が無い → `mise install` してから `./setup.sh` |

ビルドの最後に出る `View build details: docker-desktop://...` は buildx が出す案内で、Docker Desktop が無いので開けない。無視してよい。
