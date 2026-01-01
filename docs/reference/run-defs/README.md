# run-defs/ リファレンス

このドキュメントは `run-defs/` 配下の job 定義（YAML）と、その解釈仕様のリファレンスです。記載は実装に基づきます。根拠となるファイルパスを各節に明記しています。

## ディレクトリ構成
- `run-defs/jobs/`: job spec（YAML）。
- `run-defs/modes/`: 現状はプレースホルダ（`.gitkeep` のみ）。用途は要確認。

根拠: `run-defs/jobs/`, `run-defs/modes/.gitkeep`, `core/run-oneshot.sh`

---

## job spec の解釈仕様（run-oneshot.sh）

### 対応キー
- `name`: job 名。
- `prompt_file` または `prompt_text`（排他）。
- `skills`: optional skills の配列。
- `target_dir`: Codex 実行対象ディレクトリ。
- `worktree`: worktree の使用可否（省略時は `true`）。
- `pr`, `pr_yml`, `pr_draft`: PR 作成関連フラグ。
- `disable_global_skills`: グローバル skills 無効化。
- `model`: `ONESHOT_MODEL` に渡すモデル名。
- `thinking` / `thinking_level`: `ONESHOT_THINKING` に渡すレベル。

根拠: `core/run-oneshot.sh`

### skills の扱い
- `skills` の要素が `/` を含む、または `.md` で終わる場合は「skill file」として扱います。
- それ以外は optional skill 名として扱います。
- `pr: true` の場合、`pr-draft` skill が自動追加されます（未指定時のみ）。

根拠: `core/run-oneshot.sh`

### 入力置換
- `--input key=path` の指定で `__INPUT_<KEY>__` を置換します（`KEY` は大文字化）。
- `--audit-report` は `audit_report` として内部的に `set_input` されます。
- `path` は `ONESHOT_AGENT_ROOT/<path>` を優先解決し、見つからない場合は指定パス自体を参照します。

根拠: `core/run-oneshot.sh`

### 既定値/補助挙動
- `worktree` 未指定時は `true`。
- `target_dir` 未指定時は `ONESHOT_PROJECT_ROOT` → `PROJECT_ROOT` → `PWD` の順で解決。
- `prompt_text` は `|` ブロックの簡易パース（フラット YAML 前提）。

根拠: `core/run-oneshot.sh`

---

## 現在の job 定義一覧

### doc-audit
- 目的: ドキュメント監査（修正は行わず、不整合の洗い出しレポート）。
- 主な設定: `worktree: false`, `model: gpt-5.2-codex`, `thinking: medium`。
- skills: `skills/optional/doc-audit.md`。

根拠: `run-defs/jobs/doc-audit.yml`

### doc-fix
- 目的: 監査レポートに基づくドキュメント修正。
- 主な設定: `worktree: true`, `pr: true`, `model: gpt-5.2-codex`, `thinking: medium`。
- 入力: `__INPUT_AUDIT_REPORT__`。

根拠: `run-defs/jobs/doc-fix.yml`

### doc-reference-update
- 目的: 実装に基づく `docs/reference/` の生成・更新。
- 主な設定: `worktree: true`, `pr: true`, `model: gpt-5.2-codex`, `thinking: medium`。

根拠: `run-defs/jobs/doc-reference-update.yml`

### create-run-def-job
- 目的: job 定義と Makefile ターゲットの作成支援。
- 主な設定: `worktree: true`, `pr: true`, `model: gpt-5.2-codex`, `thinking: medium`。
- skills: `skills/optional/create-run-def-job/SKILL.md`, `skills/optional/create-run-def-job/references/templates.md`。
- 入力: `__INPUT_JOB_REQUEST__`。

根拠: `run-defs/jobs/create-run-def-job.yml`

### word-lookup
- 目的: 不明語の意味・用法調査。
- 主な設定: `worktree: false`, `model: gpt-5.2-codex`, `thinking: medium`。
- 入力: `__INPUT_WORDS__`。

根拠: `run-defs/jobs/word-lookup.yml`
