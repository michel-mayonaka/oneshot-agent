# core/ リファレンス

core/ 配下の実行・補助スクリプトの仕様を、実装に基づいて整理したものです。

## 対象スクリプト一覧
| スクリプト | 役割 | 根拠 |
| --- | --- | --- |
| `core/oneshot-exec.sh` | Codex CLI を単発実行し、ログ/成果物を保存する | `core/oneshot-exec.sh` |
| `core/run-oneshot.sh` | job YAML を解釈して oneshot 実行を束ねる | `core/run-oneshot.sh` |
| `core/create-worktree.sh` | Git worktree を作成する | `core/create-worktree.sh` |
| `core/remove-worktree.sh` | Git worktree を削除する | `core/remove-worktree.sh` |
| `core/summarize_run.sh` | 実行結果を `report.md` に要約する | `core/summarize_run.sh` |
| `core/generate-pr-yml.sh` | PRタイトル/本文の YAML (`pr.yml`) を生成する | `core/generate-pr-yml.sh` |
| `core/create-pr.sh` | `pr.yml` を使って PR 作成を行う | `core/create-pr.sh` |
| `core/translate-worklog-to-ja.sh` | worklog を日本語に翻訳する | `core/translate-worklog-to-ja.sh` |

## 共通事項
- すべて `bash` + `set -euo pipefail` 前提です。
- 出力先やファイル名はスクリプトごとに異なるため、各詳細ページを参照してください。

## 詳細
- `docs/reference/core/oneshot-exec.md`
- `docs/reference/core/run-oneshot.md`
- `docs/reference/core/create-worktree.md`
- `docs/reference/core/remove-worktree.md`
- `docs/reference/core/summarize-run.md`
- `docs/reference/core/generate-pr-yml.md`
- `docs/reference/core/create-pr.md`
- `docs/reference/core/translate-worklog-to-ja.md`
