---
name: memory-policy
description: 会話をまたいで残したい知見・規約・手順をどこに書くかを決めるときに使う。Claude Code・Codex ともに自動メモリは OFF であること、グローバルに置かない方針、エージェントごとの rules / AGENTS.md / skills / 全体規約の使い分け基準を持つ。「これを覚えておいて」「次回以降このルールで」といった依頼を受けたとき、および新しい規約・手順をファイルに残す場面で読み込む。
---

# 知見の蓄積

自動メモリは OFF（Claude Code は `autoMemoryEnabled: false`、Codex は `features.memories = false`）。会話をまたいで残したい知見は対象プロジェクト側に記録する。グローバル（`~/.claude/rules/` など）には置かない。

## 書き分け

書き込み先は、いま動いているエージェントに合わせる。

| 残したいもの | Claude Code | Codex |
|---|---|---|
| 常に効かせたい規約・事実（毎セッション読み込み） | `.claude/rules/<topic>.md` | リポジトリルートの `AGENTS.md` |
| 特定ディレクトリ・ファイル種別に限った規約 | `.claude/rules/` に `paths` frontmatter を付与（該当ファイル操作時のみ読み込み） | 該当ディレクトリの `AGENTS.md`（ファイル種別での絞り込みはできない） |
| タスク固有の手順・チェックリスト（呼び出し時/関連時のみ読み込み） | `.claude/skills/<name>/SKILL.md` | `.agents/skills/<name>/SKILL.md` |
| 全プロジェクト共通のルール | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` |

- 全プロジェクト共通の 2 ファイルは同じ実体（dotfiles の `.agents/AGENTS.base.md`）への link。どちらに書いても両方に効く
- Codex の `rules` はコマンド実行の承認ルールで、規約の置き場ではない
- 両方のエージェントで使うリポジトリで、既に `CLAUDE.md` と `AGENTS.md` が並存している場合は、既存の書き分けに従う

## 書く前の判断

rules・`AGENTS.md`・全体規約は毎セッション読み込まれるため、行を増やすほど他のルールが埋もれる。追加する行ごとに「これを削除したらエージェントが間違えるか」を問い、そうでなければ書かない。発火頻度が低いもの（特定タスクのときだけ必要な手順）は skill に置く。
