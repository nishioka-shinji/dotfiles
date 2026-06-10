# ============================================================
# PATH
# ============================================================
export PATH="$HOME/.local/bin:$PATH"   # claude など

# ============================================================
# 補完（git/kubectl/gcloud などのサブコマンド・オプション補完を有効化）
# ============================================================
autoload -Uz compinit && compinit

# ============================================================
# mise（helm, python, terraform などのバージョン管理）
# ============================================================
eval "$(mise activate zsh)"

# ============================================================
# Prompt (git ステータス表示)
# ============================================================
autoload -Uz vcs_info
setopt prompt_subst
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr "%F{magenta}!"
zstyle ':vcs_info:git:*' unstagedstr "%F{yellow}+"
zstyle ':vcs_info:*' formats "%F{cyan}%c%u[%b]%f"
zstyle ':vcs_info:*' actionformats '[%b|%a]'
# 新規(untracked)ファイルがあれば赤い ? を付ける
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked
+vi-git-untracked() {
  if [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]]; then
    hook_com[unstaged]+='%F{red}?'
  fi
}
precmd () { vcs_info }

PROMPT='
[%B%F{red}%n@%m%f%b:%F{green}%~%f]%F{cyan}$vcs_info_msg_0_%f
%F{yellow}$%f '

# ============================================================
# Plugins
# ============================================================
# zsh-autosuggestions (brew)
if [ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# ============================================================
# マシン固有設定（このPC専用・リポジトリ管理外）
#   秘密情報や社内向けの設定は ~/.zshrc.local に置く
# ============================================================
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
