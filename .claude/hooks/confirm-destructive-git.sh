#!/usr/bin/env bash
# PreToolUse(Bash): 破壊的な git 操作を permission prompt に回す。
# 破壊的操作の事前確認を決定論的に強制するためのフック。
# deny ではなく ask を返すため、ユーザーが内容を確認して承諾すれば実行できる。
# 確認手順の指示はこのフックの出力が唯一の情報源（CLAUDE.md には記載しない）。
set -uo pipefail

# git と サブコマンドの間に挟まる global option（-C <path> / -c k=v / --no-pager 等）
GITPRE='git([[:space:]]+(-[A-Za-z-]+|--[A-Za-z-]+=[^[:space:]]+)([[:space:]]+[^-][^[:space:]]*)?)*'

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

# コマンド境界（行頭 / ; / & / | / 括弧）に続く git <sub> を探す
git_sub() { printf '%s' "$cmd" | grep -Eq "(^|[;&|(])[[:space:]]*${GITPRE}[[:space:]]+$1([[:space:]]|$)"; }
has_flag() { printf '%s' "$cmd" | grep -Eq "(^|[[:space:]])$1([[:space:]]|=|$)"; }

reason=""

# --- reset --hard : 未コミットの変更が消える ---
if git_sub reset && has_flag '--hard'; then
  reason="git reset --hard は未コミットの変更を破棄します"

# --- clean -fd : 未追跡ファイルが消える ---
elif git_sub clean && printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])-[A-Za-z]*f'; then
  reason="git clean は未追跡ファイルを削除します"

# --- checkout / restore -- <path> : そのパスの変更が消える ---
elif { git_sub checkout || git_sub restore; } && printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])--([[:space:]]|$)'; then
  reason="指定パスの未コミットの変更を破棄します"

# --- push --force : リモート履歴を上書き（--force-with-lease は CLAUDE.md 推奨だが確認は必要）---
elif git_sub push && { has_flag '--force' || has_flag '--force-with-lease' || printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])-[A-Za-z]*f([[:space:]]|$)'; }; then
  if has_flag '--force-with-lease'; then
    reason="git push --force-with-lease はリモート履歴を上書きします"
  else
    reason="git push --force はリモート履歴を無条件に上書きします（--force-with-lease の使用を推奨）"
  fi

# --- rebase / commit --amend : 履歴の書き換え ---
elif git_sub rebase && ! has_flag '--abort' && ! has_flag '--continue' && ! has_flag '--skip'; then
  reason="git rebase はコミット履歴を書き換えます（push 済みなら force push が必要になります）"
elif git_sub commit && has_flag '--amend'; then
  reason="git commit --amend は直前のコミットを書き換えます（push 済みなら force push が必要になります）"

# --- stash drop / clear : stash が消える ---
elif git_sub stash && printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])stash[[:space:]]+(drop|clear|pop)([[:space:]]|$)'; then
  reason="stash のエントリが失われます"
fi

# 注: git branch -d/-D と git worktree remove は worktree 後片付けで頻用するため
# 確認対象から除外している（ユーザー指示）。

[ -n "$reason" ] || exit 0

# 消える対象の確認に使うコマンドを、検出した操作に応じて案内する
case "$reason" in
  *stash*) probe="git stash list" ;;
  *リモート履歴*|*コミット履歴*|*直前のコミット*) probe="git log --oneline -5 と git status" ;;
  *) probe="git status" ;;
esac

jq -n --arg r "$reason" --arg p "$probe" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: ($r + "。実行前に " + $p + " で消える対象を確認し、何が失われるかを具体的にユーザーへ伝えて承諾を得てください。このコマンドについて承諾済みなら、繰り返し確認しないこと。")
  }
}'
