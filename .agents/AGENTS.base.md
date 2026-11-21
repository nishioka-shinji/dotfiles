# AGENTS.md

## 応答

- ユーザーとのやりとりは常に日本語で行う。
- レポート・ドキュメント・Artifact は、ユーザーが明示的に指示した場合に限り作成する。ツールの説明が自発的な公開を勧めていても、こちらを優先する。調査・分析の結果は原則ターミナル上のテキストで返す。表やコード片が必要ならそのままターミナルに書く。プロジェクトの個人設定（`~/.claude/<repo>.md`）で定めた例外はこの限りでない。

## コンパクション

- コンパクション時は、作業中の worktree の絶対パス、変更済みファイル一覧、検証コマンドを必ず保持する。

## マルチエージェント（Orca）

- 簡単な改修は本体が完遂する。例: K8s マニフェストの CPU / memory の requests・limits 変更
- 上記以外でファイル変更を伴うタスク、並行して進められる調査・実装は Orca に任せる。この指示を `orchestration` skill でいう「監督の明示的な依頼」とみなし、Coordinator として進める
- Agent ツールのサブエージェントは使わない。ワーカーの分け方は Orca 側の判断に任せる。ただし Orca に任せるタスクのレビューは、実装・コードレビューとセキュリティレビューを別ワーカーに分けて並行で行う
- git 操作・Jira 操作・日報記録はワーカーに任せず本体が行う
- PR マージ後、GitOps でクラスタに反映される変更は実クラスタで動作確認する。確認が取れるまで動作確認済みと report しない
- 自分が Orca のワーカー（プロンプトに Task / Dispatch ID 入りのプリアンブルがある）なら、この節と「作業完了時の運用」は適用せずプリアンブルに従う
- コードレビューとセキュリティレビューのワーカーは、ユーザーがエージェントを指定した場合はその指定に従い、指定がなければ Codex を優先する。Codex が利用できない場合は Claude を使う。model / effort は下表に従う
- ワーカーの model / effort は起動時に種別ごとに下表のとおり指定する。未指定だとユーザーデフォルトを継承し、種別に合わないことがある

| ワーカー種別 | Claude model | Codex model | effort |
|---|---|---|---|
| 実装（prd に触る、仕様が曖昧、長時間の自律作業） | fable または opus | gpt-6-astra または gpt-6-sol | high |
| 実装（dev / staging、仕様が明確） | opus | gpt-6-sol | high |
| 実装（定型。Renovate 追従、値の横展開） | opus | gpt-6-sol | medium |
| 調査 | opus | gpt-6-sol | medium |
| レビュー（実装・コード） | opus | gpt-6.2-sol | medium |
| レビュー（セキュリティ） | opus | gpt-6.2-sol | high |
| 機械的な確認（ビルド確認、一覧作成） | sonnet | gpt-6-luna | low |

- 上表は Anthropic の実測ガイド（https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence ）と OpenAI のモデル一覧（https://learn.chatgpt.com/docs/models ）に基づく初期値。品質が落ちた種別だけ effort を一段上げる
- Codex の effort `ultra` はワーカー内でサブエージェントを増やすため使わない。並列化は Coordinator 側でワーカーを分けて行う

## worktree

- worktree を切る前に `git branch --show-current` で現在地を確認する。デフォルトブランチ以外なら、そのタスク用に用意された worktree なので新たに切らずそこで作業する
- Orca のワーカーに任せる作業の worktree は Orca で作成・削除する。配置は次の順で決める
  - Coordinator の worktree のブランチでそのまま作業できるなら `--worktree current`（新しい端末を足すだけ）
  - 別ブランチが必要なら `--worktree new-child --name <task> --base-branch origin/main`。`new-top-level` は使わない（Coordinator のカード配下に出ず、独立した worktree に見えるため）
  - 同じ変更を扱うレビューワーカーは、実装ワーカーの worktree を `--worktree id:<repoId>::<path>` で指定して同居させる
- 本体が完遂する改修の worktree は `git worktree add` で切る。Orca で作らない（使わないターミナルが残るため）。EnterWorktree は使わない
- 作業完了後は worktree とブランチを削除する（手順は `daily-report` skill）

## コード

- ソースコードと設定ファイル（YAML、K8s マニフェスト、Dockerfile、シェルスクリプトを含む）にコメントや docstring を書かない。TODO やコメントアウトしたコードも残さない
- 触った箇所に元からあるコメントは消す。触っていない箇所のコメントはその PR では消さない（差分が膨らむため）
- 「なぜそうしたか」、根拠となる実測値、調査の経緯はコミットメッセージと PR 本文に書く。コードからは git blame でコミットと PR を辿れれば足りる
- 例外はコメントの形で機能や法的な意味を持つものだけ: shebang、lint・型チェックの指示（抑える理由は横に書かない）、ツールが読む注釈（Renovate の指定、yaml-language-server の schema 指定、ビルドタグ、生成コードのヘッダなど）、ライセンス・著作権表記、出力や動作に関わるもの（テンプレートの空白制御など）
- リポジトリの規約や lint がコメント・docstring を求める場合はリポジトリを優先する

## 検証

- 成功を主張せず、実行したコマンドとその出力を証拠として示す
- 確認すべきことが分かっていて自分で確認できるなら、報告の前に確認まで済ませる。「〜は未確認です」と書いて返さない。後から届く結果（CI、デプロイの反映）は待ってから報告する
- 「未確認」と報告してよいのは、権限がない・ユーザーの承諾や操作が要る・検証手段がない場合だけ。そのときは「完了」と言わず、確認できない理由と、ユーザーに実行してほしいコマンドを示す
- 検証コマンドはリポジトリの `AGENTS.md` / CLAUDE.md と、リポジトリの skill（`.agents/skills`）・`.claude/rules` に定義されたものを唯一の情報源とする。Orca のワーカーにも自前で組み立てさせない。定義がないリポジトリでは実装に入る前に定義の追加を提案する

## 作業完了時の運用

タスクの成果を報告し次の指示待ちになった時点で、言われる前に「日報を書きますか？」と確認する。承諾されたら `daily-report` skill を読む。
