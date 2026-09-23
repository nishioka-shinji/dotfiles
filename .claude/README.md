# Claude Code 設定

Claude Code 専用の hook・skill・設定を構成するファイル群。Codex と共有する全体規約と skill は `.agents/`（[README](../.agents/README.md)）に置く。`setup.sh` が `~/.claude/` 配下へ symlink する（`settings.base.json` のみマージ）。hooks と skills はディレクトリごとではなくファイル・skill 単位で link し、端末側に置いた組織固有の hook / skill と共存させる。`.base` 付きのファイルは Claude Code がこのディレクトリで自動読み込みしないようにした名前で、link 先で本来の名前になる。この README は link 対象外。

マルチエージェントでの作業は Orca に任せる（`orchestration` / `orca-cli` skill は Orca が `~/.claude/skills/` に配置する）。Agent ツールのサブエージェント定義は持たない。

## 規約と手順

- `skills/memory-policy/SKILL.md`: 知見を rules / skills / CLAUDE.md のどこに書くかを決める基準

## ハーネス側の強制（プロンプトに頼らないガードレール）

- `settings.base.json`: PreToolUse の hook 登録を持つ実行環境定義。symlink ではなく `setup.sh` が `~/.claude/settings.json` へマージする。端末・組織ごとに生成される autoMode やプラグイン設定は既存の値が残る
- `hooks/protect-branch.sh`: 保護ブランチへの commit / push を拒否し、変更を必ず PR に通す PreToolUse hook
- `hooks/confirm-destructive-git.sh`: reset --hard や force push を permission prompt に回し、作業途中の状態破壊を人の確認に委ねる PreToolUse hook

## settings.base.json の内容

`setup.sh` の `merge_claude_settings` が `~/.claude/settings.json` へマージする。ここにあるキーはベースの値で上書きされ、ここにないキー（autoMode、enabledPlugins 等）は端末側の値が残る。hooks はイベント・matcher ごとに連結し、同じ command は重複除去する。

| キー | 値 | 意味 |
|---|---|---|
| `permissions.defaultMode` | `auto` | auto mode で起動する。ツール実行の許可判定を分類器に委ね、危険な操作だけ確認を挟む |
| `model` | `opus` | 本体のデフォルトモデル。エイリアスなので最新の Opus に解決される。端末ごとに変えたい場合は `/model` で上書きする（ただし `setup.sh` 再実行でベースに戻る） |
| `hooks.PreToolUse[Bash]` | `protect-branch.sh` | 保護ブランチ（main / master / staging / production / develop）への commit / push を deny |
| `hooks.PreToolUse[Bash]` | `confirm-destructive-git.sh` | `reset --hard`、`clean -f`、`checkout -- <path>`、`push --force` を permission prompt に回す |
| `outputStyle` | `Concise` | 結果を先に短く返す出力スタイル |
| `alwaysThinkingEnabled` | `false` | 常時 extended thinking を使わない |
| `effortLevel` | `high` | 推論の投入量。判定精度を優先する |
| `fastMode` | `true` | 対応モデルで高速出力を使う |
| `tui` | `fullscreen` | ターミナル UI を全画面モードにする |
| `autoMemoryEnabled` | `false` | 自動メモリを使わない。知見は `memory-policy` に従いリポジトリ側の rules / skills に書く |
| `skipWorkflowUsageWarning` | `true` | Workflow ツール利用時の使用量警告を出さない |

hook の `command` は `$HOME/.claude/hooks/<name>.sh`。絶対パスにしないのはユーザー名が異なる端末で動かすため。

## 判定器の定義元

検証コマンド（terraform validate、kustomize build 等）は各リポジトリの `CLAUDE.md` / `.claude/rules` に定義する。本体・Orca のワーカーともにそこを唯一の情報源とし、自前で組み立てない。

## 含めていないもの

- 組織固有の skill（Jira 操作、kubectl の接続設定など）と hook（CI ツール固有のガード等）。`~/.claude/skills/` / `~/.claude/hooks/` に直接置き、hook は `~/.claude/settings.json` 側で追加登録する
- `settings.json` の autoMode・プラグイン設定。端末ごとに生成され、組織の内部情報を含むため
- `~/.claude/projects/` などのセッション履歴
