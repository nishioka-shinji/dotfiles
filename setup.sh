#!/usr/bin/env bash
set -euo pipefail

# このスクリプトが置かれている dotfiles リポジトリのルートを絶対パスで取得
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# シンボリックリンクを張る関数
# $1: リポジトリ内のソース（DOTFILES_DIR からの相対パス）
# $2: リンクを作成する場所（$HOME からの相対パス）
link() {
  local src="$DOTFILES_DIR/$1"
  local dest="$HOME/$2"

  mkdir -p "$(dirname "$dest")"

  # 既存のリンク／ファイルがあれば退避
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$(readlink "$dest" 2>/dev/null)" = "$src" ]; then
      echo "skip : $dest -> $src (already linked)"
      return
    fi
    mv "$dest" "$dest.bak"
    echo "backup: $dest -> $dest.bak"
  fi

  ln -s "$src" "$dest"
  echo "link : $dest -> $src"
}

link .zshrc .zshrc
link .config/mise/config.toml .config/mise/config.toml
link .config/nvim .config/nvim

# Claude Code の settings.json をベースからマージして生成する
# symlink にしない理由: autoMode やプラグイン設定は Claude Code 自身がこのファイルへ
# 書き込むため、symlink だと端末・組織固有の情報が dotfiles に流れ込む。
# ベースにあるキーはベースが勝ち、ベースにないキーは既存の値を残す。
# hooks はイベント・matcher ごとに連結し、同じ command の重複を除く。
# $1: ベース（DOTFILES_DIR からの相対パス）
# $2: 生成先（$HOME からの相対パス）
merge_claude_settings() {
  local base="$DOTFILES_DIR/$1"
  local dest="$HOME/$2"

  if ! command -v jq >/dev/null 2>&1; then
    echo "skip : $dest (jq not found; run again after brew install)"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  local current='{}' was_link=false
  if [ -L "$dest" ]; then
    # 以前の symlink 運用から移行する場合はリンクを外し、実体ファイルに戻す
    current=$(cat "$dest")
    rm "$dest"
    was_link=true
  elif [ -f "$dest" ]; then
    current=$(cat "$dest")
    cp "$dest" "$dest.bak"
  fi

  local merged
  merged=$(jq -n --argjson cur "$current" --slurpfile b "$base" '
    def uniq_by_cmd:
      reduce .[] as $h ([]; if any(.[]; .command == $h.command) then . else . + [$h] end);
    def merge_event(a; b):
      (a + b) | group_by(.matcher) | map({matcher: .[0].matcher, hooks: ([.[].hooks[]] | uniq_by_cmd)}
        | if .matcher == null then del(.matcher) else . end);
    def merge_hooks(a; b):
      reduce ((a | keys) + (b | keys) | unique | .[]) as $ev ({};
        .[$ev] = merge_event(a[$ev] // []; b[$ev] // []));
    ($b[0]) as $base
    | ($cur * $base)
    | if ($cur.hooks // $base.hooks) != null
      then .hooks = merge_hooks($cur.hooks // {}; $base.hooks // {}) else . end
  ') || { echo "error: failed to merge $base into $dest"; return 1; }

  if ! $was_link && [ "$(printf '%s' "$merged" | jq -S .)" = "$(printf '%s' "$current" | jq -S . 2>/dev/null)" ]; then
    rm -f "$dest.bak"
    echo "skip : $dest (already up to date)"
    return
  fi
  printf '%s\n' "$merged" > "$dest"
  echo "merge: $dest <- $base"
}

# Claude Code の設定（実装ループの規約・agent 定義・hook・skill）
# ~/.claude 全体は projects/ や履歴を含むため、ファイル・ディレクトリ単位で link する。
# hooks と skills はディレクトリごと link しない。端末側に組織固有の hook / skill を
# 直接置いて共存させるため。
link .claude/CLAUDE.base.md .claude/CLAUDE.md
merge_claude_settings .claude/settings.base.json .claude/settings.json
link .claude/agents .claude/agents
for hook in protect-branch confirm-destructive-git require-verification; do
  link ".claude/hooks/$hook.sh" ".claude/hooks/$hook.sh"
done
for skill in delegation loop-retro daily-report memory-policy; do
  link ".claude/skills/$skill" ".claude/skills/$skill"
done

# ~/.docker/cli-plugins に残ったリンク切れを掃除する
# （Docker Desktop をアンインストールすると、そこを指すリンクだけが残る）
clean_docker_cli_plugins() {
  local dir="$HOME/.docker/cli-plugins"
  [ -d "$dir" ] || return

  local plugin
  for plugin in "$dir"/*; do
    if [ -L "$plugin" ] && [ ! -e "$plugin" ]; then
      rm "$plugin"
      echo "clean : $plugin (broken symlink)"
    fi
  done
}

clean_docker_cli_plugins

# Docker Desktop が入っている端末では cli-plugins を Desktop が管理するので触らない。
# ラッパー経由の link は colima + mise 構成の端末だけに適用する。
if [ -d /Applications/Docker.app ]; then
  echo "skip : docker cli-plugins (managed by Docker Desktop)"
else
  link .docker/cli-plugins/docker-compose .docker/cli-plugins/docker-compose
  link .docker/cli-plugins/docker-buildx .docker/cli-plugins/docker-buildx
fi

# Homebrew が無ければインストールし、現在のシェルで使えるようにする
ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    echo "skip : brew (already installed)"
  else
    echo "brew : installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # PATH を通す（Apple Silicon は /opt/homebrew, Intel は /usr/local）
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# Homebrew formula でインストールする CLI ツール
# $1: formula 名
install_formula() {
  local formula="$1"

  if ! command -v brew >/dev/null 2>&1; then
    echo "skip : brew not found, cannot install formula '$formula'"
    return
  fi

  if brew list --formula "$formula" >/dev/null 2>&1; then
    echo "skip : formula '$formula' (already installed)"
    return
  fi

  echo "brew : installing formula '$formula'"
  brew install "$formula"
}

# Homebrew cask でインストールする GUI アプリ（macOS のみ）
# $1: cask 名
install_cask() {
  local cask="$1"

  if ! command -v brew >/dev/null 2>&1; then
    echo "skip : brew not found, cannot install cask '$cask'"
    return
  fi

  if brew list --cask "$cask" >/dev/null 2>&1; then
    echo "skip : cask '$cask' (already installed)"
    return
  fi

  echo "cask : installing '$cask'"
  brew install --cask "$cask"
}

if [ "$(uname)" = "Darwin" ]; then
  ensure_brew

  # .zshrc が依存するツール
  install_formula mise              # eval "$(mise activate zsh)"
  install_formula jq                # merge_claude_settings と Claude Code の hook が使う
  install_formula zsh-autosuggestions

  # miseで管理できないツール
  install_cask cmux
  install_cask shottr               # スクリーンショットツール
  install_formula telnet
fi

# mise config（helm, terraform など）のツール導入は手動で:
#   mise install
