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

link .config/mise/config.toml .config/mise/config.toml

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
  install_cask cmux
fi
