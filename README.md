# dotfiles

## セットアップ

```sh
./setup.sh    # シンボリックリンクを張り、Homebrew と最低限のツールを入れる
mise install  # .config/mise/config.toml のツールを入れる
```

`setup.sh` は既存ファイルがあれば `.bak` に退避してからリンクを張るので、何度実行してもよい。

## ツールをどこで管理するか

優先度は mise > Homebrew > 配布元から直接。上から順に、入るものはできるだけ上で管理する。

| 管理先 | 対象 | 定義場所 |
|---|---|---|
| mise | CLI ツール全般。Renovate がバージョンを追う | `.config/mise/config.toml` |
| Homebrew | mise のレジストリに無いもの、GUI アプリ | `setup.sh` の `install_formula` / `install_cask` |
| 配布元の zip | どちらにも無いもの | `setup.sh` の `install_app_from_zip` |

`install_app_from_zip` は zip を展開して `/Applications` に置く。配布元が差し替わったことに気づけるよう、署名の Team ID が期待値と一致しなければインストールしない。ダウンロード由来の隔離属性は外すので、初回起動で警告は出ない。バージョンは配布元の最新に追随する（固定していない）ため、上げ直すにはアプリを消してから `./setup.sh` を実行する。

現在の対象は Kanary（メニューバー常駐の録音・ウィンドウ操作ツール）だけ。mise にも Homebrew にも無く、公式サイトが zip を直接配っている。

## Docker

Docker Desktop は使わず、以下の組み合わせで動かしている。Docker Desktop が入っている端末では `~/.docker/cli-plugins` を Desktop が管理するため、`setup.sh` はプラグインの link をスキップする。

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
