# AGENTS.md

## 応答

- ユーザーとのやりとりは常に日本語で行う。
- レポート・ドキュメント・Artifact は、ユーザーが明示的に指示した場合に限り作成する。調査・分析の結果は原則ターミナル上のテキストで返す。表やコード片が必要ならそのままターミナルに書く。頼まれていないのに成果物ページを作らない。

## コンパクション

- コンパクション時は、作業中の worktree の絶対パス、変更済みファイル一覧、検証コマンドを必ず保持する。

## マルチエージェント（Orca）

- 簡単な改修は本体が完遂する。例: K8s マニフェストの CPU / memory の requests・limits 変更
- 上記以外でファイル変更を伴うタスク、並行して進められる調査・実装は Orca に任せる。この指示を `orchestration` skill でいう「監督の明示的な依頼」とみなし、Coordinator として進める
- Agent ツールのサブエージェントは使わない。ワーカーの分け方（実装とレビューを分けるか等）は Orca 側の判断に任せる
- git 操作・Jira 操作・日報記録はワーカーに任せず本体が行う
- PR マージ後、GitOps でクラスタに反映される変更は実クラスタで動作確認する。確認が取れるまで動作確認済みと report しない
- 自分が Orca のワーカー（プロンプトに Task / Dispatch ID 入りのプリアンブルがある）なら、この節と「作業完了時の運用」は適用せずプリアンブルに従う
- ワーカーの model / effort は `worker-start` の `--model` / `--effort` で種別ごとに下表のとおり指定する。未指定だとユーザーデフォルト（Fable high）を継承し、調査・定型作業には過剰

| ワーカー種別 | Claude model | Codex model | effort |
|---|---|---|---|
| 実装（prd に触る、仕様が曖昧、長時間の自律作業） | fable または opus | gpt-6-astra または gpt-6-sol | high |
| 実装（dev / staging、仕様が明確） | opus | gpt-6-sol | high |
| 実装（定型。Renovate 追従、値の横展開） | opus | gpt-6-sol | medium |
| 調査・レビュー | opus | gpt-6-sol | medium |
| 機械的な確認（ビルド確認、一覧作成） | sonnet | gpt-6-luna | low |

- 上表は Anthropic の実測ガイド（https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence ）と OpenAI のモデル一覧（https://learn.chatgpt.com/docs/models ）に基づく初期値。品質が落ちた種別だけ effort を一段上げる
- Codex の effort `ultra` はワーカー内でサブエージェントを増やすため使わない。並列化は Coordinator 側でワーカーを分けて行う

## worktree

- worktree は Orca で作成・削除する（`git worktree` や EnterWorktree は使わない）
- 作業完了後は worktree とブランチを削除する（手順は `daily-report` skill）

## コード

- ソースコード中のコメントは 3 行以内にまとめる。「なぜそうしたか」だけを書き、実測値・メトリクスの数値・コミットハッシュ・調査の経緯は書かない
- それらの根拠は PR 本文とコミットメッセージに残す。コード側からは PR 番号で辿れれば足りる
- K8s マニフェストの CPU / memory の requests・limits 変更にはコメントを書かない。値の変更だけで差分が自明なため

## 検証

- 成功を主張せず、実行したコマンドとその出力を証拠として示す。検証手段がない場合は「完了」と言わず、何を確認できていないかを明示する
- 検証コマンドはリポジトリの CLAUDE.md / `.claude/rules` に定義されたものを唯一の情報源とする。Orca のワーカーにも自前で組み立てさせない。定義がないリポジトリでは実装に入る前に定義の追加を提案する

## 作業完了時の運用

タスクの成果を報告し次の指示待ちになった時点で、言われる前に「日報を書きますか？」と確認する。承諾されたら `daily-report` skill を読む。
