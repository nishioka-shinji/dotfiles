# Claude Code / Codex 共有設定

Claude Code と Codex の両方で使う全体規約と skill。`setup.sh` がそれぞれの読み込み先へ symlink する。Claude Code 専用のものは `.claude/`（[README](../.claude/README.md)）に置く。この README は link 対象外。

## 規約と手順

- `AGENTS.base.md`: 本体で済ませるか Orca に任せるかの基準、検証の原則を定める全体規約。`setup.sh` が `~/.claude/CLAUDE.md`・`~/.codex/AGENTS.md` として link する。Claude Code はユーザーレベルの `AGENTS.md` を読まないため、Claude Code 向けは `CLAUDE.md` の名前にする。`AGENTS.md` の名前で置かないのは、この dotfiles ディレクトリを開いたときにプロジェクト指示として二重に読み込まれるのを避けるため
- `skills/daily-report/SKILL.md`: 日報の書式と、記録後の後片付け手順。`~/.claude/skills/`（Claude Code）と `~/.agents/skills/`（Codex）の両方に link する
- `skills/memory-policy/SKILL.md`: 知見をどこに書くかを決める基準。Claude Code と Codex で書き込み先（rules / AGENTS.md / skills）を書き分ける。link 先は daily-report と同じ

Codex の自動メモリは `setup.sh` が `~/.codex/config.toml` に `[features] memories = false` を書き込んで OFF にする。`codex features disable memories` はキーを消して既定値任せにするだけなので使わない。`config.toml` は Codex 自身も書き込むため link しない。

`~/.codex/skills/` は Codex 自身が同梱 skill（`.system/`）やインストーラーで書き込む場所なので使わない。
