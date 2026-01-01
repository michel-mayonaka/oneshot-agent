# PR 生成/作成 参照

## generate-pr-yml.sh
### 概要
`run_dir` から差分と worklog を収集し、PR 用の YAML (`pr.yml`) を生成します。

### CLI
```
Usage: generate-pr-yml.sh <run_dir>
```

### 入力/前提
- `<run_dir>/worklog.md` または `<run_dir>/logs/worklog.md` が存在すること
- `<run_dir>/worktree` が存在し、Git リポジトリであること
- `codex` コマンドが利用可能であること

### 環境変数
- `ONESHOT_PR_MODEL`: Codex モデル（未指定時 `gpt-5.2`）
- `ONESHOT_PR_DIFF_MAX_LINES`: diff の最大行数（未指定時 `2000`）

### 出力
- `<run_dir>/pr.yml`

## create-pr.sh
### 概要
`pr.yml` を読み取り、GitHub CLI で PR を作成します。

### CLI
```
Usage: create-pr.sh --repo <repo_dir> --worktree <dir> --pr-yml <path>
                    [--branch <name>] [--base <branch>] [--commit-message <msg>] [--draft]
```

### 入力/前提
- `gh` (GitHub CLI) が利用可能であること
- `--pr-yml` に `title` と `body` が含まれること

### 挙動の要点
- `--branch` 未指定時は worktree の現在ブランチ。
- `--base` 未指定時は `origin/HEAD` から推定し、取得できない場合は `main`。
- 変更が未コミットの場合は `git add -A` → `git commit` を実行。
- ベースブランチとの差分コミットが無い場合は `pr_skipped=1` を出力して終了。
- PR 作成後は `pr_url=<url>` を出力。

## 根拠
- `core/generate-pr-yml.sh`
- `core/create-pr.sh`
