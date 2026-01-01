# run-oneshot.sh 参照

## 概要
`core/run-oneshot.sh` は、ジョブ定義 (YAML) に従って `oneshot-exec.sh` を実行し、必要に応じて worktree 作成や PR 用 YAML 生成まで行います。

## CLI
```
Usage: run-oneshot.sh --job <job.yml> [--audit-report <file>] [--input <key=path>] [--render-only]
```

### オプション
- `--job`: ジョブ定義 YAML（必須）
- `--audit-report`: `audit_report` 入力として使うファイルパス
- `--input`: `key=path` 形式で追加入力を指定（複数回可）
- `--render-only`: 置換後のプロンプトを標準出力し、実行はしない

## ジョブ定義 (フラット YAML)
```
name: doc-audit
prompt_file: prompts/doc-audit.md
prompt_text: "..."
skills:
  - doc-audit
target_dir: /path/to/project
worktree: true
pr: true
pr_yml: true
pr_draft: true
disable_global_skills: true
model: gpt-5.2-codex
thinking: medium
```

### 注意点
- `prompt_file` と `prompt_text` はどちらか一方のみ指定。
- `target_dir` 未指定時は `ONESHOT_PROJECT_ROOT` -> `PROJECT_ROOT` -> `PWD` の順に解決。
- `skills` は optional skill 名の配列。
- `inputs` は `__INPUT_<KEY>__` を置換対象とし、`--input` は `ONESHOT_AGENT_ROOT` からの相対パスとして解決する。
- `pr_yml` は `worktree: true` が前提。
- `thinking` は Codex CLI の `reasoning.effort` に渡される。
- `ONESHOT_WORKLOGS_ROOT` が指定されている場合、`worklogs` ルートとして使用。

## 挙動の要点
- `worktree` のデフォルトは `true`。
- `pr: true` の場合、自動で `pr-draft` skill を追加。
- run ディレクトリは `worklogs/<job>/<run_id>/` に作成。
- 旧 run を `archive/` に移動（実行中の run は除外）。
- `--render-only` の場合は実行せずプロンプトのみ出力。
- `worktree` 有効時は `create-worktree.sh` で作業用ブランチ/ディレクトリを作成。
- `oneshot-exec.sh` には以下の環境変数を引き渡す:
  - `ONESHOT_RUNS_DIR` / `ONESHOT_RUN_ID` / `ONESHOT_ARCHIVE_HANDLED=1`
  - `ONESHOT_DISABLE_GLOBAL_SKILLS`（`disable_global_skills` に応じて）
  - `ONESHOT_MODEL` / `ONESHOT_THINKING`（指定時）
- 入力置換後の `inputs/inputs.txt` を run ディレクトリに保存。
- `pr_yml: true` の場合は `generate-pr-yml.sh` を実行。
- `pr: true` の場合は `create-pr.sh` を実行。

## 依存コマンド
- `python3`（`__INPUT_<KEY>__` の置換処理）
- `git`（worktree 作成や差分の取得）

## 根拠
- `core/run-oneshot.sh`
- `core/create-worktree.sh`
- `core/oneshot-exec.sh`
- `core/generate-pr-yml.sh`
- `core/create-pr.sh`
