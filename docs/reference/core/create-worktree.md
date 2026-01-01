# create-worktree.sh リファレンス

## 概要
- 指定リポジトリに対して Git worktree を作成します。

根拠: `core/create-worktree.sh`

## CLI
```
Usage: create-worktree.sh --repo <repo_dir> --run-id <id> --job-name <name> [--base <branch>] [--worktree-root <dir>] [--worklogs-root <dir>]
```

オプション:
- `--repo`: Git リポジトリのルートパス
- `--run-id`: run_id
- `--job-name`: job 名
- `--base`: ベースブランチ（省略時は現在ブランチ、取得不可なら `main`）
- `--worktree-root`: worktree 作成先ルート（省略時は `<repo_dir>/worklogs`）
- `--worklogs-root`: `--worktree-root` の別名

根拠: `core/create-worktree.sh`

## 出力
- 標準出力に以下を出力。
  - `worktree_dir=<...>`
  - `branch=<...>`
  - `base_branch=<...>`

根拠: `core/create-worktree.sh`

## 振る舞い
- `--base` が無い場合は、現在のブランチを取得し、取得できない場合は `main`。
- `job-name` を小文字化し、英数字/`._-` 以外は `-` に置換したブランチ名を生成。
- `git worktree add -b <branch> <worktree_dir> <base_branch>` を実行。

根拠: `core/create-worktree.sh`
