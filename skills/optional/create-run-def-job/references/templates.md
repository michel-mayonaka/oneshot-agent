# Job Templates (YAML)

## Minimal skeleton

```yaml
name: <job-name>
prompt_text: |
  <task instructions>
job_type: no_worktree
# target_dir: /path/to/project
# disable_global_skills: true
```

## Audit (監査)

```yaml
name: <job-name>
prompt_text: |
  ドキュメント監査を実施してください。不整合の洗い出しだけを行い、修正はしないでください。
  必須出力: Markdown レポート（概要 / 調査プロセス / 不整合一覧 / 根拠詳細）。
skills:
  - skills/optional/doc-audit.md
job_type: no_worktree
```

## Fix (修正)

```yaml
name: <job-name>
prompt_text: |
  以下の監査レポートに基づき、不整合を修正してください。
  監査レポート:
  ```
  __INPUT_AUDIT_REPORT__
  ```
job_type: worktree_and_pr
```

## Dictionary (辞書/用語)

```yaml
name: <job-name>
prompt_text: |
  以下の「わからない単語」を調べ、意味・用法をまとめてください。
  入力:
  ```
  __INPUT_WORDS__
  ```
job_type: no_worktree
```

## Research (調査)

```yaml
name: <job-name>
prompt_text: |
  指定テーマについて調査し、要点・根拠・不確実性をまとめてください。
job_type: no_worktree
```

## Implementation (実装)

```yaml
name: <job-name>
prompt_text: |
  目的:
  - <goal>
  要件:
  - <requirements>
  変更対象:
  - <files or areas>
  期待する出力:
  - <summary / tests>
job_type: worktree_and_pr
```

# Makefile Target Template

```make
.PHONY: <target>
<TARGET>_SPEC ?= run-defs/jobs/<job-name>.yml
<TARGET>_INPUT ?=

<target>:
	@if [[ -z "$(<TARGET>_INPUT)" ]]; then echo "<TARGET>_INPUT is required"; exit 1; fi
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" \
		bash core/run_oneshot.sh --job $(<TARGET>_SPEC) --input input=$(<TARGET>_INPUT)
```

# Notes

- `skills:` には **参照したいファイルをすべて列挙** する（本文内で参照があっても省略しない）。
- job_type の値: no_worktree / worktree / worktree_and_pr / pr_worktree
