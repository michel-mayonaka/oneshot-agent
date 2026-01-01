# worktree 管理 参照

## create-worktree.sh
### CLI
```
Usage: create-worktree.sh --repo <repo_dir> --run-id <id> --job-name <name> [--base <branch>] [--worktree-root <dir>] [--worklogs-root <dir>]
```

### オプション
- `--repo`: Git リポジトリのルートパス（必須）
- `--run-id`: run_id（必須）
- `--job-name`: job 名（必須）
- `--base`: ベースブランチ（省略時は現在のブランチ、取得できない場合は `main`）
- `--worktree-root`: worktree 作成先のルート（省略時は `<repo_dir>/worklogs`）
- `--worklogs-root`: `--worktree-root` の別名

### 挙動の要点
- ブランチ名は `job-name` を小文字化し、`[^a-z0-9._-]` を `-` に置換して生成。
- worktree は `<worktree-root>/<run-id>/worktree` に作成。
- 既存ブランチまたは既存 worktree がある場合はエラー。

### 出力
- `worktree_dir=<path>`
- `branch=<name>`
- `base_branch=<name>`

## remove-worktree.sh
### CLI
```
Usage: remove-worktree.sh --repo <repo_dir> (--run-id <id> | --path <worktree_dir>) [--worktree-root <dir>] [--worklogs-root <dir>] [--force]
```

### オプション
- `--repo`: Git リポジトリのルートパス（必須）
- `--run-id`: `worklogs/<run-id>/worktree` を削除対象にする
- `--path`: worktree のパスを直接指定
- `--worktree-root`: run_id から解決する場合のルート（省略時は `<repo_dir>/worklogs`）
- `--worklogs-root`: `--worktree-root` の別名
- `--force`: worktree が未クリーンでも削除

### 出力
- `removed_worktree=<path>`

## 根拠
- `core/create-worktree.sh`
- `core/remove-worktree.sh`
