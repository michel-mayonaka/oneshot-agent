# CLI/スクリプト参照

このドキュメントは core/ 配下の実装から抽出した参照です。内容は実装に依存するため、差分がある場合は実装側を正とします。

## 共通前提
- すべてのスクリプトは `bash` + `set -euo pipefail` で動作します。
- 依存コマンドはスクリプトごとに異なります（各セクション参照）。
- 重要な環境変数は各セクションに記載します。

根拠: `core/oneshot-exec.sh`, `core/run-oneshot.sh`, `core/*.sh`

## oneshot-exec.sh
Codex CLI を単発実行し、プロンプト整形・ログ保存・サマリ生成までを行うエントリです。

### 使い方
```
oneshot-exec.sh [-C <target_dir>] [-s skill1,skill2] <prompt.txt or prompt string>
```

### オプション
- `-C <DIR>`: Codex を実行するターゲットディレクトリ。省略時は `worklogs/<run_id>/artifacts/` を作成して使用。
- `-s <NAME,...>`: optional skill 名（カンマ区切り）。`skills/optional/<NAME>.md` を参照。

### 環境変数
- `ONESHOT_AGENT_ROOT` (必須): リポジトリルート。未設定時はエラー。
- `ONESHOT_RUN_ID`: run_id を固定する場合に使用（未指定なら `date +%Y%m%d-%H%M%S-$RANDOM`）。
- `ONESHOT_RUNS_DIR`: run の格納先ルート（未指定なら `worklogs/oneshot-exec`）。
- `ONESHOT_ARCHIVE_HANDLED`: 旧runのアーカイブ処理を抑止（`run-oneshot.sh` 経由で指定）。
- `ONESHOT_SKILLS`: optional skill 名（カンマ区切り）。
- `ONESHOT_DISABLE_GLOBAL_SKILLS=1`: `skills/global/*.md` の自動読み込みを無効化。
- `ONESHOT_MODEL`: Codex 実行モデル（未指定時は `gpt-5.2-codex`）。
- `ONESHOT_THINKING`: Codex CLI の `reasoning.effort` に渡す値（例: low/medium/high）。
- `ONESHOT_AUTO_TRANSLATE_WORKLOG`: 有効時は `translate-worklog-to-ja.sh` を実行。

### 入出力
- 入力: ファイルパス（存在する場合は内容を読み込み）、またはプロンプト文字列。
- 出力（標準出力）: `run_dir=...` と `target_dir=...` を出力。
- 生成物（主要）:
  - `prompts/prompt.raw.txt` / `prompts/prompt.txt`
  - `prompts/skills_used.txt`
  - `logs/events.jsonl`, `logs/stderr_and_time.txt`
  - `logs/worklog.md`, `logs/worklog.commands.md`, `logs/commands.jsonl`
  - `logs/last_message.md`, `logs/usage.json`
  - `report.md`（`summarize_run.sh` により生成）

### 依存コマンド
- `codex`, `jq`, `/usr/bin/time`, `shasum`
  - `jq` は一部集計にのみ使用（無い場合は省略される箇所あり）。

根拠: `core/oneshot-exec.sh`, `core/summarize_run.sh`

## run-oneshot.sh
job spec を読み取り、worktree 作成・prompt 置換・oneshot 実行・PR生成までを統合する実行スクリプトです。

### 使い方
```
run-oneshot.sh --job <job.yml> [--audit-report <file>] [--input <key=path>] [--render-only]
```

### job spec（フラット YAML）
- `name`: job名（未指定時はファイル名から推定）。
- `prompt_file` / `prompt_text`: どちらか片方のみ指定。
- `skills`: optional skill 名の配列。
- `target_dir`: 未指定時は `ONESHOT_PROJECT_ROOT` → `PROJECT_ROOT` → `PWD` の順で決定。
- `worktree`: `true/false`（未指定時は `true`）。
- `pr`: `true` で PR 作成（有効時は `pr-draft` skill を自動追加）。
- `pr_yml`: `true` で `pr.yml` を生成（`worktree: true` が前提）。
- `pr_draft`: `true` で Draft PR。
- `disable_global_skills`: `true` で global skills を無効化。
- `model`: `ONESHOT_MODEL` 相当の指定。
- `thinking` / `thinking_level`: `ONESHOT_THINKING` 相当の指定。

### 入出力
- `--input key=path` と `--audit-report` は `__INPUT_<KEY>__` 形式のプレースホルダをファイル内容で置換。
  - `KEY` は大文字化されます。
  - `--input` の相対パスは `ONESHOT_AGENT_ROOT` 基準で解決されます。
- `--render-only`: 置換後のプロンプトを標準出力に表示して終了。

### 環境変数
- `ONESHOT_AGENT_ROOT` (必須): リポジトリルート。
- `ONESHOT_PROJECT_ROOT` / `PROJECT_ROOT`: `target_dir` 未指定時の参照。
- `ONESHOT_WORKLOGS_ROOT`: `worklogs/` のルート。

### 依存コマンド
- `git`, `python3`

### 主要な出力
- `worklogs/<job>/<run_id>/logs/run-oneshot.log`
- `worklogs/<job>/<run_id>/.running`
- `worktree` 作成時は `worklogs/<job>/<run_id>/worktree` を作成

根拠: `core/run-oneshot.sh`

## create-worktree.sh
指定リポジトリに worktree を作成します。

### 使い方
```
create-worktree.sh --repo <repo_dir> --run-id <id> --job-name <name> [--base <branch>] [--worktree-root <dir>] [--worklogs-root <dir>]
```

### 仕様
- `--base` 未指定時は現在のブランチ（取得不可なら `main`）。
- `--worktree-root` 未指定時は `<repo_dir>/worklogs`。
- worktree は `<worktree-root>/<run_id>/worktree` に作成。
- job名はブランチ名に利用するため、小文字化＋安全文字に正規化。

### 出力
- `worktree_dir=...`
- `branch=...`
- `base_branch=...`

### 依存コマンド
- `git`

根拠: `core/create-worktree.sh`

## remove-worktree.sh
run_id もしくは worktree パスから worktree を削除します。

### 使い方
```
remove-worktree.sh --repo <repo_dir> (--run-id <id> | --path <worktree_dir>) [--worktree-root <dir>] [--worklogs-root <dir>] [--force]
```

### 仕様
- `--run-id` 指定時の worktree 解決先は `<worktree-root>/<run_id>/worktree`。
- `--force` で `git worktree remove --force` を使用。

### 依存コマンド
- `git`

根拠: `core/remove-worktree.sh`

## summarize_run.sh
run_dir から実行結果のサマリ `report.md` を生成します。

### 使い方
```
summarize_run.sh <run_dir>
```

### 出力（概要）
- `report.md` を `run_dir` 直下に作成。
- `logs/events.jsonl`, `logs/stderr_and_time.txt`, `prompts/prompt.txt` などを参照。
- `jq` があればトークン usage を抽出（無い場合は空のまま）。
- `git` リポジトリ内なら `branch/commit/status/diff` を記載。

### 依存コマンド
- `jq`（任意）, `git`, `shasum`

根拠: `core/summarize_run.sh`

## generate-pr-yml.sh
run_dir の差分と worklog から `pr.yml`（title/body）を生成します。

### 使い方
```
generate-pr-yml.sh <run_dir>
```

### 環境変数
- `ONESHOT_PR_MODEL`: Codex 実行モデル（未指定時は `gpt-5.2`）。
- `ONESHOT_PR_DIFF_MAX_LINES`: diff の最大行数（未指定時は `2000`）。

### 入出力
- 入力: `run_dir/worklog.md`（無い場合は `run_dir/logs/worklog.md` を参照）。
- 入力: `run_dir/worktree` が Git repo であること。
- 出力: `run_dir/pr.yml` を生成。

### 依存コマンド
- `codex`, `git`

根拠: `core/generate-pr-yml.sh`

## create-pr.sh
`pr.yml` を読み取り、コミット・push・PR作成までを行います。

### 使い方
```
create-pr.sh --repo <repo_dir> --worktree <dir> --pr-yml <path>
            [--branch <name>] [--base <branch>] [--commit-message <msg>] [--draft]
```

### 仕様
- `--branch` 未指定時は worktree の現在ブランチ。
- `--base` 未指定時は `origin/HEAD` を参照し、無ければ `main`。
- 変更が未コミットなら `git add -A` → `git commit`。
- base と branch の差分が無い場合は `pr_skipped=1` を出力して終了。

### 依存コマンド
- `git`, `gh`, `python3`

根拠: `core/create-pr.sh`

## translate-worklog-to-ja.sh
worklog を日本語に翻訳します。

### 使い方
```
translate-worklog-to-ja.sh <run_dir>
```

### 環境変数
- `ONESHOT_TRANSLATE_MODEL`: Codex 実行モデル（未指定時は `gpt-5.2`）。

### 入出力
- 入力: `run_dir/worklog.md`
- 出力: `run_dir/worklog.ja.md`

### 依存コマンド
- `codex`

根拠: `core/translate-worklog-to-ja.sh`
