# create-pr.sh リファレンス

## 概要
- `pr.yml` を読み込み、GitHub CLI (`gh`) を使って PR を作成します。

根拠: `core/create-pr.sh`

## CLI
```
Usage: create-pr.sh --repo <repo_dir> --worktree <dir> --pr-yml <path>
                    [--branch <name>] [--base <branch>] [--commit-message <msg>] [--draft]
```

根拠: `core/create-pr.sh`

## 入力
- `--repo`: Git リポジトリルート
- `--worktree`: worktree パス
- `--pr-yml`: PR 情報 YAML（`title` / `body`）

根拠: `core/create-pr.sh`

## 出力
- PR 作成に成功すると標準出力に `pr_url=<...>` を出力。
- 変更が無い場合は `pr_skipped=1` を出力して終了。

根拠: `core/create-pr.sh`

## 振る舞い
- `--branch` 未指定時は worktree の現在ブランチを利用。
- `--base` 未指定時は `origin/HEAD` を参照し、取得できない場合は `main`。
- worktree に未コミット変更があれば `git add -A` してコミット。
  - `--commit-message` 未指定時は `docs: update (<branch>)` を使用。
- `gh pr create` 実行前に `git push -u origin <branch>` を実行。
- `--draft` 指定時は Draft PR を作成。

根拠: `core/create-pr.sh`

## 依存/前提
- `gh` CLI が PATH に存在すること。
- `git` が利用可能であること。

根拠: `core/create-pr.sh`
