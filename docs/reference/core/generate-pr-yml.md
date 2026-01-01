# generate-pr-yml.sh リファレンス

## 概要
- run ディレクトリと Git diff を基に、`pr.yml`（PRタイトル/本文の YAML）を生成します。

根拠: `core/generate-pr-yml.sh`

## CLI
```
usage: generate-pr-yml.sh <run_dir>
```

根拠: `core/generate-pr-yml.sh`

## 入力
- `<run_dir>/worklog.md`（無ければ `<run_dir>/logs/worklog.md` を参照）
- `<run_dir>/worktree`（Git リポジトリであることが必須）

根拠: `core/generate-pr-yml.sh`

## 出力
- `<run_dir>/pr.yml`

根拠: `core/generate-pr-yml.sh`

## 環境変数
- `ONESHOT_PR_MODEL`（任意）: Codex 実行モデル（未指定時は `gpt-5.2`）。
- `ONESHOT_PR_DIFF_MAX_LINES`（任意）: diff の最大行数（未指定時は `2000`）。

根拠: `core/generate-pr-yml.sh`

## 依存/前提
- `codex` CLI が PATH に存在すること。
- `worktree` が Git リポジトリであること。

根拠: `core/generate-pr-yml.sh`

## 処理概要
- job 名を run-oneshot のログ (`logs/run-oneshot.log`) から取得し、無ければ run ディレクトリ名から推定。
- `git diff` から name-status / stat / 本文（最大 N 行）を作成。
- worklog と diff をプロンプトに含め、Codex で `pr.yml` を生成。

根拠: `core/generate-pr-yml.sh`
