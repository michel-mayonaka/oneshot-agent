# run-defs/jobs 一覧

各 job YAML の設定を、実装に基づいて整理した一覧です。

## doc-audit
- ファイル: `run-defs/jobs/doc-audit.yml`
- name: `doc-audit`
- prompt_text: ドキュメント監査のみを行い、Markdown レポートを出力する指示。
- skills:
  - `skills/optional/doc-audit.md`
- worktree: `false`
- model: `gpt-5.2-codex`
- thinking: `medium`

根拠: `run-defs/jobs/doc-audit.yml`

## doc-fix
- ファイル: `run-defs/jobs/doc-fix.yml`
- name: `doc-fix`
- prompt_text: 監査レポートに基づく修正を指示。`__INPUT_AUDIT_REPORT__` を使用。
- skills:
  - `skills/optional/pr-draft.md`
- worktree: `true`
- pr: `true`
- model: `gpt-5.2-codex`
- thinking: `medium`

根拠: `run-defs/jobs/doc-fix.yml`

## doc-reference-update
- ファイル: `run-defs/jobs/doc-reference-update.yml`
- name: `doc-reference-update`
- prompt_text: `docs/reference/` の生成・更新指示。
- skills:
  - `skills/optional/pr-draft.md`
- worktree: `true`
- pr: `true`
- model: `gpt-5.2-codex`
- thinking: `medium`

根拠: `run-defs/jobs/doc-reference-update.yml`

## word-lookup
- ファイル: `run-defs/jobs/word-lookup.yml`
- name: `word-lookup`
- prompt_text: 単語の意味/用法の調査指示。`__INPUT_WORDS__` を使用。
- worktree: `false`
- model: `gpt-5.2-codex`
- thinking: `medium`

根拠: `run-defs/jobs/word-lookup.yml`

## create-run-def-job
- ファイル: `run-defs/jobs/create-run-def-job.yml`
- name: `create-run-def-job`
- prompt_text: job 定義と Makefile ターゲット作成を指示。`__INPUT_JOB_REQUEST__` を使用。
- skills:
  - `skills/optional/create-run-def-job/SKILL.md`
  - `skills/optional/pr-draft.md`
  - `skills/optional/create-run-def-job/references/templates.md`
- worktree: `true`
- pr: `true`
- model: `gpt-5.2-codex`
- thinking: `medium`

根拠: `run-defs/jobs/create-run-def-job.yml`
