# core/ リファレンス

このドキュメントは `core/` 配下のスクリプトの仕様リファレンスです。記載は実装に基づきます。根拠となるファイルパスを各節に明記しています。

## oneshot-exec.sh

### 概要
- 単一プロンプトを Codex CLI に渡して実行し、run ディレクトリにログや生成物を保存します。
- ターゲットディレクトリを指定しない場合は `worklogs/<run_id>/artifacts/` を作成して使用します。
- グローバル/optional skills を読み込み、最終プロンプトを生成します。

根拠: `core/oneshot-exec.sh`

### CLI
- `-C <dir>`: Codex の実行ディレクトリ（省略時は run の `artifacts/`）。
- `-s <name1,name2>`: optional skill 名（`skills/optional/<NAME>.md` または `skills/optional/<NAME>/SKILL.md`）。
- `-h`: usage 表示。

根拠: `core/oneshot-exec.sh`

### 環境変数
- `ONESHOT_AGENT_ROOT`（必須）: リポジトリルート。
- `ONESHOT_RUN_ID`: run_id を指定（未指定なら日時+乱数）。
- `ONESHOT_RUNS_DIR`: run ディレクトリのルート（省略時は `worklogs/oneshot-exec`）。
- `ONESHOT_ARCHIVE_HANDLED`: 旧 run のアーカイブ処理を抑止。
- `ONESHOT_SKILLS`: optional skill 名（カンマ区切り）。
- `ONESHOT_DISABLE_GLOBAL_SKILLS`: グローバル skills の無効化フラグ。
- `ONESHOT_MODEL`: Codex 実行モデル（既定 `gpt-5.2-codex`）。
- `ONESHOT_THINKING`: reasoning.effort に渡すレベル。
- `ONESHOT_AUTO_TRANSLATE_WORKLOG`: worklog を日本語化する場合に設定。

根拠: `core/oneshot-exec.sh`

### 出力/副作用
- run ディレクトリ: `${RUNS_DIR}/${RUN_ID}` を作成。
- 生成物（例）:
  - `logs/events.jsonl` / `logs/stderr_and_time.txt`
  - `logs/worklog.md` / `logs/worklog.commands.md` / `logs/commands.jsonl`
  - `logs/last_message.md` / `logs/usage.json`
  - `prompts/prompt.raw.txt` / `prompts/prompt.txt` / `prompts/skills_used.txt`
  - `logs/target_dir.txt`
- `core/summarize_run.sh` を実行して `report.md` を生成。
- `ONESHOT_AUTO_TRANSLATE_WORKLOG` が有効なら `core/translate-worklog-to-ja.sh` を実行。

根拠: `core/oneshot-exec.sh`

### 注意点
- `jq` を使用してログを生成するため、未インストール時の挙動は要確認。
- Codex CLI の詳細挙動や `codex exec` の仕様は外部ツールのため要確認。

根拠: `core/oneshot-exec.sh`

---

## run-oneshot.sh

### 概要
- job spec（YAML）を読み取り、prompt のレンダリング・worktree 作成・oneshot 実行・PR 生成までを統合します。
- `worktree: true` の場合、`core/create-worktree.sh` を使って worktree を作成します。

根拠: `core/run-oneshot.sh`

### CLI
- `--job <job.yml>`: job spec（必須）。
- `--audit-report <file>`: `__INPUT_AUDIT_REPORT__` 置換用入力。
- `--input <key=path>`: 任意の `__INPUT_<KEY>__` 置換用入力。
- `--render-only`: 置換後の prompt を出力して終了。
- `-h|--help`: usage 表示。

根拠: `core/run-oneshot.sh`

### job spec で解釈されるキー
- `name`: job 名。
- `prompt_file` または `prompt_text`（排他）。
- `skills`: optional skills の配列。`/` を含む・`.md` 拡張子のエントリはファイル扱い。
- `target_dir`: Codex 実行対象ディレクトリ。
- `worktree`: worktree 使用可否（省略時は `true`）。
- `pr`, `pr_yml`, `pr_draft`: PR 作成関連フラグ。
- `disable_global_skills`: グローバル skills 無効化。
- `model`: `ONESHOT_MODEL` に渡すモデル名。
- `thinking` / `thinking_level`: `ONESHOT_THINKING` に渡すレベル。

根拠: `core/run-oneshot.sh`

### 入力置換
- `--input key=path` で `__INPUT_<KEY>__` を置換（`KEY` は大文字化）。
- `--audit-report` は `audit_report` として内部的に `set_input`。
- `path` は `ONESHOT_AGENT_ROOT/<path>` を優先解決し、見つからなければ指定パス自体を参照します。

根拠: `core/run-oneshot.sh`

### 環境変数
- `ONESHOT_AGENT_ROOT`（必須）。
- `ONESHOT_PROJECT_ROOT` / `PROJECT_ROOT`: `target_dir` 未指定時の解決順。
- `ONESHOT_WORKLOGS_ROOT`: worklogs ルート。
- `ONESHOT_RUNS_DIR`, `ONESHOT_RUN_ID`, `ONESHOT_ARCHIVE_HANDLED`: oneshot 実行時に引き渡し。

根拠: `core/run-oneshot.sh`

### PR/Worktree 連携
- `pr: true` の場合、`pr-draft` skill を自動追加（未指定時）。
- `pr_yml: true` なら `core/generate-pr-yml.sh` を実行（worktree 必須）。
- `pr: true` なら `core/create-pr.sh` を実行（worktree 必須）。

根拠: `core/run-oneshot.sh`

---

## create-worktree.sh

### 概要
- 指定リポジトリに worktree を作成し、専用ブランチを切ります。

根拠: `core/create-worktree.sh`

### CLI
- `--repo <repo_dir>`: Git リポジトリ。
- `--run-id <id>`: run_id。
- `--job-name <name>`: job 名。
- `--base <branch>`: ベースブランチ（省略時は現在のブランチ → `main`）。
- `--worktree-root <dir>` / `--worklogs-root <dir>`: worktree ルート。

根拠: `core/create-worktree.sh`

### 出力
- `worktree_dir=<path>` / `branch=<name>` / `base_branch=<name>` を標準出力に出力。
- worktree は `<worktree_root>/<run_id>/worktree` に作成。

根拠: `core/create-worktree.sh`

---

## remove-worktree.sh

### 概要
- 指定の worktree を削除します。

根拠: `core/remove-worktree.sh`

### CLI
- `--repo <repo_dir>`: Git リポジトリ。
- `--run-id <id>` または `--path <worktree_dir>`。
- `--worktree-root <dir>` / `--worklogs-root <dir>`: run_id 解決用ルート。
- `--force`: `git worktree remove --force` を使用。

根拠: `core/remove-worktree.sh`

### 出力
- `removed_worktree=<path>` を標準出力に出力。

根拠: `core/remove-worktree.sh`

---

## summarize_run.sh

### 概要
- run ディレクトリからレポート `report.md` を生成します。
- `events.jsonl` / `stderr_and_time.txt` / `prompt.txt` / `last_message.md` を参照します。

根拠: `core/summarize_run.sh`

### CLI
- `summarize_run.sh <run_dir>`

根拠: `core/summarize_run.sh`

### 出力
- `<run_dir>/report.md` を生成。
- `jq` がある場合のみ token usage を抽出。
- Git リポジトリ内であれば `git status` / `git diff` 情報を含めます。

根拠: `core/summarize_run.sh`

### 注意点
- `jq` 未インストール時の token usage 抽出は要確認。

根拠: `core/summarize_run.sh`

---

## generate-pr-yml.sh

### 概要
- worktree の `git diff` と worklog から PR 情報（title/body）を生成し `pr.yml` を作成します。

根拠: `core/generate-pr-yml.sh`

### CLI
- `generate-pr-yml.sh <run_dir>`

根拠: `core/generate-pr-yml.sh`

### 環境変数
- `ONESHOT_PR_MODEL`: PR 生成に使うモデル（既定 `gpt-5.2`）。
- `ONESHOT_PR_DIFF_MAX_LINES`: diff の最大行数（既定 2000）。

根拠: `core/generate-pr-yml.sh`

### 出力/前提
- 出力: `<run_dir>/pr.yml`。
- 前提: `codex` CLI と git repo、`<run_dir>/worktree` が必要。
- worklog は `<run_dir>/worklog.md` を優先し、無ければ `<run_dir>/logs/worklog.md`。

根拠: `core/generate-pr-yml.sh`

---

## create-pr.sh

### 概要
- `pr.yml` から PR を作成します。未コミット変更があればコミットします。

根拠: `core/create-pr.sh`

### CLI
- `create-pr.sh --repo <repo_dir> --worktree <dir> --pr-yml <path>`
- `--branch <name>` / `--base <branch>` / `--commit-message <msg>` / `--draft`

根拠: `core/create-pr.sh`

### 出力/前提
- `gh` CLI が必要。
- 出力: `pr_url=<url>` または `pr_skipped=1`（差分無し時）。
- base ブランチは `origin/HEAD` → `main` の順で推定。

根拠: `core/create-pr.sh`

---

## translate-worklog-to-ja.sh

### 概要
- `worklog.md` を日本語に翻訳して `worklog.ja.md` を生成します。

根拠: `core/translate-worklog-to-ja.sh`

### CLI
- `translate-worklog-to-ja.sh <run_dir>`

根拠: `core/translate-worklog-to-ja.sh`

### 環境変数
- `ONESHOT_TRANSLATE_MODEL`: 翻訳に使うモデル（既定 `gpt-5.2`）。

根拠: `core/translate-worklog-to-ja.sh`

### 出力/前提
- 出力: `<run_dir>/worklog.ja.md`。
- 前提: `codex` CLI が必要。

根拠: `core/translate-worklog-to-ja.sh`
