# remove-worktree.sh リファレンス

## 概要
- Git worktree を削除します。

根拠: `core/remove-worktree.sh`

## CLI
```
Usage: remove-worktree.sh --repo <repo_dir> (--run-id <id> | --path <worktree_dir>) [--worktree-root <dir>] [--worklogs-root <dir>] [--force]
```

オプション:
- `--repo`: Git リポジトリのルートパス
- `--run-id`: `worklogs/<run_id>/worktree` を対象に削除
- `--path`: worktree のパスを直接指定
- `--worktree-root`: `run-id` から解決する際のルート（省略時は `<repo_dir>/worklogs`）
- `--worklogs-root`: `--worktree-root` の別名
- `--force`: 未クリーンな worktree も削除

根拠: `core/remove-worktree.sh`

## 出力
- 標準出力に `removed_worktree=<...>` を出力。

根拠: `core/remove-worktree.sh`

## 振る舞い
- `--run-id` と `--path` のいずれかが必須。
- `--force` 指定時は `git worktree remove --force` を使用。

根拠: `core/remove-worktree.sh`
