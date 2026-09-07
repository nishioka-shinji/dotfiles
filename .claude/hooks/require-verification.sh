#!/usr/bin/env bash
# SubagentStop: implementer / reviewer / integrator が検証コマンドを 1 つも実行せずに
# 終了しようとしたら停止をブロックし、実行するか「実行できない」と明記させる。
# CLAUDE.md「検証」節と各 agent 定義の検証必須ルールを決定論的に強制するためのフック。
set -uo pipefail

payload=$(cat)
jf() { printf '%s' "$payload" | jq -r "$1 // empty"; }

# 再入防止: このフックのブロックを受けて再度停止した場合は通す
[ "$(jf '.stop_hook_active')" = "true" ] && exit 0

agent_type=$(jf '.agent_type')
case $agent_type in
  implementer|reviewer|integrator) ;;
  *) exit 0 ;;
esac

# サブエージェント自身のトランスクリプトを特定する。
# 優先順: agent_transcript_path → <session>/subagents/agent-<id>.jsonl → transcript_path
agent_id=$(jf '.agent_id')
session_id=$(jf '.session_id')
transcript=$(jf '.agent_transcript_path')
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  main=$(jf '.transcript_path')
  cand=""
  if [ -n "$main" ] && [ -n "$session_id" ] && [ -n "$agent_id" ]; then
    cand="$(dirname "$main")/$session_id/subagents/agent-$agent_id.jsonl"
  fi
  if [ -n "$cand" ] && [ -f "$cand" ]; then transcript=$cand
  elif [ -n "$main" ] && [ -f "$main" ]; then transcript=$main
  else exit 0; fi   # 判定材料がないときは止めない（誤ブロックより見逃しを選ぶ）
fi

# agentId でこのサブエージェントの行に絞る（メイン transcript にフォールバックした場合の混入防止）
lines() {
  if [ -n "$agent_id" ]; then
    jq -c --arg a "$agent_id" 'select((.agentId // $a) == $a)' "$transcript" 2>/dev/null
  else
    cat "$transcript"
  fi
}

# 実行された Bash コマンド一覧
cmds=$(lines | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash") | .input.command // empty' 2>/dev/null)

# 検証コマンドとみなすパターン。リポジトリで実際に使う検証手段に合わせて追記する。
VERIFY_RE='terraform[[:space:]]+(validate|fmt|plan|init|test)|kustomize|flux[[:space:]]+(diff|build)|helm[[:space:]]+(template|lint)|kubeconform|kube-linter|conftest|tflint|yamllint|shellcheck|(npm|yarn|pnpm|bun)[[:space:]]+(test|run[[:space:]]+(test|lint|typecheck|check|build))|pytest|python3?[[:space:]]+-m[[:space:]]+(pytest|unittest)|go[[:space:]]+(test|vet|build)|golangci-lint|cargo[[:space:]]+(test|check|clippy)|make[[:space:]]+(test|lint|check|verify)|(bundle[[:space:]]+exec[[:space:]]+)?(rspec|rubocop|rake[[:space:]]+test)|mix[[:space:]]+test|tsc([[:space:]]|$)|eslint|ruff|mypy|sops[[:space:]]+(-d|--decrypt)|check-sops'
verified=false
[ -n "$cmds" ] && printf '%s\n' "$cmds" | grep -Eq "$VERIFY_RE" && verified=true

# 最終報告テキスト
final=$(lines | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null | tail -c 6000)

# 「実行できなかった」と明記していれば通す。強制したいのは実行そのものより「実行したふり」の排除。
acknowledged=false
printf '%s' "$final" | grep -Eq '実行できな|検証手段が(ない|未定義)|検証(コマンド|手段)が(存在しない|見つから)' && acknowledged=true

block() {
  jq -n --arg r "$1" '{decision:"block", reason:$r}'
  exit 0
}

case $agent_type in
  implementer)
    $verified || $acknowledged || block "検証コマンド（terraform validate / kustomize build / テスト等）の実行がトランスクリプトに記録されていません。リポジトリの CLAUDE.md / .claude/rules に定義された検証コマンドを実行して『検証結果』に結果を書くか、実行できない場合はその理由を『検証結果』に明記してから終了してください。"
    ;;
  reviewer|integrator)
    # PASS を出すなら検証の実行が必須。CHANGES_REQUESTED は検証なしでも出せる
    if printf '%s' "$final" | grep -Eq '^##[[:space:]]*判定[[:space:]]*$' \
       && printf '%s' "$final" | grep -A2 -E '^##[[:space:]]*判定' | grep -Eq '^PASS'; then
      $verified || block "検証コマンドを 1 つも実行せずに PASS を出そうとしています。agent 定義の判定ルールどおり、検証コマンドを自分で実行して結果を『確認したこと』に書くか、実行できない場合は CHANGES_REQUESTED として『判定理由』に検証手段がない旨を書いてください。"
    fi
    ;;
esac
exit 0
