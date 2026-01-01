# run-defs/ リファレンス

run-defs/ は `run-oneshot.sh` が参照する job 定義（YAML）をまとめたディレクトリです。

## 構成
- `run-defs/jobs/`: job YAML の実体
- `run-defs/modes/`: 現時点ではファイルなし（空ディレクトリ）

根拠: `run-defs/` 配下の構成、`core/run-oneshot.sh`

## job YAML のキー（実装が読む範囲）
- `name`: job 名
- `prompt_file`: プロンプトファイルパス（`prompt_text` と排他）
- `prompt_text`: プロンプト本文（`|` ブロックをサポート）
- `skills`: skill 指定リスト（skill 名 or skill ファイルパス）
- `target_dir`: Codex 実行先ディレクトリ
- `worktree`: worktree 作成の有無（未指定は `true`）
- `pr`: PR 作成の有無
- `pr_yml`: `pr.yml` 生成の有無
- `pr_draft`: Draft PR の有無
- `disable_global_skills`: `true/1` で global skills を無効化
- `model`: Codex 実行モデル
- `thinking` / `thinking_level`: `reasoning.effort` の値

根拠: `core/run-oneshot.sh`

## skills の扱い
- `skills` エントリに `/` または `.md` が含まれる場合は「skill ファイル」として扱い、プロンプト先頭に展開します。
- それ以外は optional skill 名として `oneshot-exec.sh -s` に渡します。

根拠: `core/run-oneshot.sh`

## prompt_text のブロック記法
- `prompt_text: |` のブロックを読み取ります。
- 実装上はインデントを `2` スペース固定で扱っています（それ以外はブロック終了扱い）。

根拠: `core/run-oneshot.sh`

## 入力置換（__INPUT_***__）
- `--input key=path` で指定したファイル内容を `__INPUT_<KEY>__` に置換します（`KEY` は大文字化）。
- `--audit-report` は `audit_report` のショートカットです。

根拠: `core/run-oneshot.sh`

## 関連ドキュメント
- `docs/reference/run-defs/jobs.md`
- `docs/reference/core/run-oneshot.md`
