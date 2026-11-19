#!/usr/bin/env bash
# PreToolUse(Bash): main / staging などの保護ブランチへの commit / push をブロックする。
# CLAUDE.md「Git」節を決定論的に強制するためのフック。
set -uo pipefail

PROTECTED_RE='^(main|master|staging|production|develop)$'
# git と サブコマンドの間に挟まる global option（-C <path> / -c k=v / --no-pager 等）
GITPRE='git([[:space:]]+(-[A-Za-z-]+|--[A-Za-z-]+=[^[:space:]]+)([[:space:]]+[^-][^[:space:]]*)?)*'

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

has_sub() { printf '%s' "$cmd" | grep -Eq "(^|[;&|(])[[:space:]]*${GITPRE}[[:space:]]+$1([[:space:]]|$)"; }

has_commit=false; has_push=false
has_sub commit && has_commit=true
has_sub push   && has_push=true
$has_commit || $has_push || exit 0

cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty')

# クォート除去（'path' / "path" の単純な囲みのみ）
unquote() {
  local s=$1
  case $s in
    \'*\') s=${s#\'}; s=${s%\'} ;;
    \"*\") s=${s#\"}; s=${s%\"} ;;
  esac
  printf '%s' "$s"
}

# 同一コマンド内の単純な代入（VAR=値）を展開する。
# worktree 運用では `W=<path>` を定義して `git -C "$W"` と書くため、
# 変数を解決できないと .cwd（多くは main）を見て誤判定してしまう。
expand_vars() {
  local s=$1 name val
  for _ in 1 2 3; do
    case $s in
      *'$'*) ;;
      *) break ;;
    esac
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      val=$(printf '%s\n' "$cmd" \
        | grep -oE "(^|[[:space:];&|(])${name}=(\"[^\"]*\"|'[^']*'|[^[:space:];&|)]*)" \
        | tail -1 | sed -E "s/^.*${name}=//")
      [ -n "$val" ] || continue
      val=$(unquote "$val")
      s=${s//\$\{$name\}/$val}
      s=${s//\$$name/$val}
    done < <(printf '%s' "$s" | grep -oE '\$\{?[A-Za-z_][A-Za-z0-9_]*\}?' \
             | sed -E 's/^\$\{?//; s/\}$//' | sort -u)
  done
  printf '%s' "$s"
}

# 相対パスは payload の .cwd 起点で解決する
resolve() {
  local p
  p=$(unquote "$1")
  p=$(expand_vars "$p")
  [ -n "$p" ] || return 1
  # 展開しきれなかった変数が残る場合は解決失敗として扱う（.cwd へフォールバック）
  case $p in
    *'$'*) return 1 ;;
  esac
  case $p in
    /*) ;;
    "~"|"~/"*) p="${HOME}${p#\~}" ;;
    *) [ -n "$cwd" ] || return 1; p="$cwd/$p" ;;
  esac
  [ -d "$p" ] || return 1
  printf '%s' "$p"
}

# 判定対象ディレクトリの優先順位:
#   1. commit / push を行う git 呼び出しの -C <path>
#   2. コマンド先頭の `cd <path> && ...`
#   3. payload の .cwd
target=""

# 1. commit / push を行う git 呼び出しを 1 コマンドずつ切り出して -C を拾う
if $has_commit && $has_push; then subs='commit|push'
elif $has_commit; then subs='commit'
else subs='push'; fi
while IFS= read -r seg; do
  printf '%s' "$seg" | grep -Eq "^[[:space:]]*${GITPRE}[[:space:]]+(${subs})([[:space:]]|$)" || continue
  # この git 呼び出しの中の -C <path>（git 上は最後の指定が起点になる）
  cpath=$(printf '%s' "$seg" | grep -oE '(^|[[:space:]])-C[[:space:]]+[^[:space:]]+' | tail -1 \
          | sed -E 's/^.*-C[[:space:]]+//')
  [ -n "$cpath" ] || continue
  if resolved=$(resolve "$cpath"); then target=$resolved; break; fi
done < <(printf '%s\n' "$cmd" | tr ';&|()' '\n')

# 2. コマンド先頭の `cd <path> && ...`
if [ -z "$target" ]; then
  cdpath=$(printf '%s' "$cmd" \
    | grep -oE '^[[:space:]]*cd[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:];&|]+)' \
    | sed -E 's/^[[:space:]]*cd[[:space:]]+//')
  if [ -n "$cdpath" ] && resolved=$(resolve "$cdpath"); then
    target=$resolved
  fi
fi

# 3. payload の .cwd
if [ -z "$target" ] && [ -n "$cwd" ] && [ -d "$cwd" ]; then
  target=$cwd
fi

[ -n "$target" ] && cd "$target" 2>/dev/null

branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || exit 0
[ -n "$branch" ] || exit 0
printf '%s' "$branch" | grep -Eq "$PROTECTED_RE" || exit 0

# 宛先を読み切れない形を個別に塞ぐと抜け道が尽きないため、許可は単独の git push で宛先がすべて読める形に限る。
push_allowed() {
  local c=$1 name='[A-Za-z0-9][A-Za-z0-9._/-]*' tok n lc p remote='' plain=false gcd
  local opt='(-q|--quiet|-u|--set-upstream|-f|--force|--force-with-lease|--no-verify|-d|--delete)'
  local ref="(${name}|HEAD:${name}|:${name})"
  local re="^git( -C [A-Za-z0-9._/~-]+)? push( ${opt})* [A-Za-z0-9._][A-Za-z0-9._-]*( (-d|--delete))? ${ref}( ${ref})*$"
  # シェルは \<改行> で前後の語を連結するので、空白に置き換えて読むと宛先を取り違える
  [[ $c == *\\* ]] && return 1
  c=$(printf '%s' "$c" | tr -s ' ')
  c=${c# }; c=${c% }
  [[ $c =~ $re ]] || return 1
  # config / remotes を見るリポジトリと git が動くリポジトリを一致させる（~- や ~user は resolve が展開しない）
  [ -n "$target" ] || return 1
  if [[ $c =~ ^git\ -C\ ([^ ]+)\ push ]]; then
    p=${BASH_REMATCH[1]}
    case $p in \~|\~/*) [[ ${p#\~} == *\~* ]] && return 1 ;; *\~*) return 1 ;; esac
    [ "$(resolve "$p")" = "$target" ] || return 1
  fi
  local -a toks
  read -ra toks <<< "${c#* push }"
  for tok in "${toks[@]}"; do
    case $tok in -*) continue ;; esac
    if [ -z "$remote" ]; then remote=$tok; continue; fi
    case $tok in
      HEAD:*|:*) n=${tok#*:} ;;
      *) n=$tok; plain=true ;;
    esac
    lc=$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]')
    # DWIM（heads/<b>）や symref（main-worktree/HEAD など）は git 側で保護ブランチに解決されうる。
    # 大文字小文字を区別しない FS では小文字の head も HEAD に解決される
    case /$lc/ in
      /refs/*|/heads/*|/tags/*|/remotes/*|*/main-worktree/*|*/worktrees/*|*/head/*|*_head/*|*..*) return 1 ;;
    esac
    printf '%s' "$lc" | grep -Eq "$PROTECTED_RE" && return 1
  done
  # 宛先省略の refspec は remote.<name>.push・push.default=upstream・.git/remotes/<name> の Push: で宛先が読み替わる
  if $plain; then
    [ -z "$(git config --get-regexp '^remote\..*\.push$' 2>/dev/null)" ] || return 1
    case $(git config --get push.default 2>/dev/null) in upstream|tracking) return 1 ;; esac
    gcd=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
    [ -e "$gcd/remotes/$remote" ] && return 1
  fi
  return 0
}

if $has_push && ! $has_commit && push_allowed "$cmd"; then
  exit 0
fi

jq -n --arg b "$branch" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("保護ブランチ \($b) への commit / push はブロックされました（CLAUDE.md: Git）。作業ブランチを切り、その worktree から実行してください。保護ブランチ上でも、作業ブランチだけを宛先にした単独の push（リダイレクト・連結・クォート・\\ なし）は許可されます。例: git push origin --delete <branch> / git push -u origin <branch> / git push origin HEAD:<branch> / git push origin :<branch>")
  }
}'
