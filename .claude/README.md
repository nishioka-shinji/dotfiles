# Claude Code 設定

Claude Code の実装ループ（ループエンジニアリング）を構成するファイル群。`setup.sh` が `~/.claude/` 配下へファイル・ディレクトリ単位で symlink する（`settings.base.json` のみマージ）。この README は link 対象外。

ループの構造は `実行 → 観測 → 判定 → 修正` の反復。生成者（implementer）と判定者（reviewer / integrator / verifier）を分け、判定器の実行を hook で強制し、ループの失敗を loop-retro でルールに還元する。

## ループの設計と手順

- `CLAUDE.md`: ループへの入口条件（委譲するか本体で済ませるか）、検証の原則、loop-retro のトリガーを定める全体規約
- `skills/delegation/SKILL.md`: investigator → planner → implementer → reviewer → integrator → verifier の 12 ステップと、差し戻し上限・分岐先を定めるループ本体の手順書
- `skills/loop-retro/SKILL.md`: ループが収束しなかったときに原因を分類し、ルール・agent 定義に還元するメタループの手順書
- `skills/daily-report/SKILL.md`: 各タスクの `ループ:` 行を記録し、再発判定のデータ源となる日報の書式
- `skills/memory-policy/SKILL.md`: loop-retro で見つけた欠けを rules / skills / CLAUDE.md のどこに書くかを決める基準

## ループを回す agent（生成者と判定者）

- `agents/investigator.md`: 実装前に現状を事実として固める読み取り専用の調査役
- `agents/planner.md`: タスク分解と各タスクの検証手段を計画に紐づける読み取り専用の設計役
- `agents/implementer.md`: 変更を行い、検証を実行して構造化報告を返す唯一の生成者
- `agents/reviewer.md`: タスク単位で差分を検査し、検証を再実行して PASS / CHANGES_REQUESTED を返す第 1 判定者
- `agents/integrator.md`: epic 統合後にタスク境界の不整合と計画充足を検査する第 2 判定者
- `agents/verifier.md`: マージ後に実クラスタの状態を観測して OK / NG / 未反映を返す最終判定者

## ハーネス側の強制（プロンプトに頼らないガードレール）

- `settings.base.json`: PreToolUse / SubagentStop の hook 登録を持つループの実行環境定義。symlink ではなく `setup.sh` が `~/.claude/settings.json` へマージする。端末・組織ごとに生成される autoMode やプラグイン設定は既存の値が残る
- `hooks/require-verification.sh`: implementer / reviewer / integrator が検証を実行せずに終了するのをブロックし、判定器の実行を強制する SubagentStop hook
- `hooks/protect-branch.sh`: 保護ブランチへの commit / push を拒否し、ループの出口を必ず PR に通す PreToolUse hook
- `hooks/confirm-destructive-git.sh`: reset --hard や force push を permission prompt に回し、ループ途中の状態破壊を人の確認に委ねる PreToolUse hook

## settings.base.json の内容

`setup.sh` の `merge_claude_settings` が `~/.claude/settings.json` へマージする。ここにあるキーはベースの値で上書きされ、ここにないキー（autoMode、enabledPlugins 等）は端末側の値が残る。hooks はイベント・matcher ごとに連結し、同じ command は重複除去する。

| キー | 値 | 意味 |
|---|---|---|
| `permissions.defaultMode` | `auto` | auto mode で起動する。ツール実行の許可判定を分類器に委ね、危険な操作だけ確認を挟む |
| `model` | `opus` | 本体のデフォルトモデル。エイリアスなので最新の Opus に解決される。端末ごとに変えたい場合は `/model` で上書きする（ただし `setup.sh` 再実行でベースに戻る） |
| `hooks.PreToolUse[Bash]` | `protect-branch.sh` | 保護ブランチ（main / master / staging / production / develop）への commit / push を deny |
| `hooks.PreToolUse[Bash]` | `confirm-destructive-git.sh` | `reset --hard`、`clean -f`、`checkout -- <path>`、`push --force` を permission prompt に回す |
| `hooks.SubagentStop[implementer\|reviewer\|integrator]` | `require-verification.sh` | 検証コマンドを実行せずに終了、または検証なしで PASS を出そうとしたサブエージェントをブロックして続行させる |
| `outputStyle` | `Concise` | 結果を先に短く返す出力スタイル |
| `alwaysThinkingEnabled` | `false` | 常時 extended thinking を使わない |
| `effortLevel` | `high` | 推論の投入量。ループの判定精度を優先する |
| `fastMode` | `true` | 対応モデルで高速出力を使う |
| `tui` | `fullscreen` | ターミナル UI を全画面モードにする |
| `autoMemoryEnabled` | `false` | 自動メモリを使わない。知見は `memory-policy` に従いリポジトリ側の rules / skills に書く |
| `skipWorkflowUsageWarning` | `true` | Workflow ツール利用時の使用量警告を出さない |

hook の `command` は `$HOME/.claude/hooks/<name>.sh`。絶対パスにしないのはユーザー名が異なる端末で動かすため。

## 判定器の定義元

検証コマンド（terraform validate、kustomize build 等）は各リポジトリの `CLAUDE.md` / `.claude/rules` に定義する。planner / implementer / reviewer / integrator はそこを唯一の情報源とし、自前で組み立てない。

## 含めていないもの

- 組織固有の skill（Jira 操作、kubectl の接続設定など）と hook（CI ツール固有のガード等）。`~/.claude/skills/` / `~/.claude/hooks/` に直接置き、hook は `~/.claude/settings.json` 側で追加登録する
- `settings.json` の autoMode・プラグイン設定。端末ごとに生成され、組織の内部情報を含むため
- `~/.claude/projects/` などのセッション履歴
