# run-oneshot.sh リファレンス

## 概要
- job YAML を読み込み、プロンプト生成・worktree 作成・oneshot 実行・PR 周辺処理までをまとめて実行します。

根拠: `core/run-oneshot.sh`

## CLI
```
Usage: run-oneshot.sh --job <job.yml> [--audit-report <file>] [--input <key=path>] [--render-only]
```
- `--job`: job spec の YAML パス（必須）
- `--audit-report`: `audit_report` 入力のショートカット
- `--input`: `key=path` 形式で入力差し替え
- `--render-only`: 置換後プロンプトを出力して終了

根拠: `core/run-oneshot.sh`

## job YAML 形式（フラット）
サポートされるキー（実装が読む範囲）:
- `name`
- `prompt_file` / `prompt_text`（どちらか一方のみ）
- `skills`（list）
- `target_dir`
- `worktree`
- `pr`
- `pr_yml`
- `pr_draft`
- `disable_global_skills`
- `model`
- `thinking` または `thinking_level`

補足:
- `skills` は「skill名」または「.md へのパス」を受け付けます。
  - `skills` の各エントリに `/` または `.md` を含む場合は「skill ファイル」として扱い、プロンプト先頭に展開します。
  - それ以外は optional skill 名として `oneshot-exec.sh` の `-s` に渡します。
- `prompt_file` と `prompt_text` は排他です。
- `worktree` のデフォルトは `true`。

根拠: `core/run-oneshot.sh`

## 環境変数
- `ONESHOT_AGENT_ROOT`（必須）: リポジトリルート。
- `ONESHOT_PROJECT_ROOT` / `PROJECT_ROOT`（任意）: `target_dir` 未指定時の探索順。
- `ONESHOT_WORKLOGS_ROOT`（任意）: run 出力ルート（未指定時は `<ONESHOT_AGENT_ROOT>/worklogs`）。
- `ONESHOT_MODEL` / `ONESHOT_THINKING`（任意）: oneshot 実行時に上書きされる。

根拠: `core/run-oneshot.sh`

## 入力の差し替え（__INPUT_***__）
- `--input key=path` で指定したファイル内容を `__INPUT_<KEY>__` に差し替えます（`KEY` は大文字化）。
- `--audit-report` は `audit_report` 入力のショートカットです。
- `--input` のパスは基本的に `ONESHOT_AGENT_ROOT` からの相対パスとして解決し、存在しない場合は指定パスをそのまま確認します。
- 差し替えは Python で実行されます。

根拠: `core/run-oneshot.sh`

## 出力/生成物
- run ディレクトリに `logs/run-oneshot.log` を作成。
- oneshot 実行後、`inputs/inputs.txt` に `key=path` を保存。
- 標準出力に `run_oneshot_log=...` / `run_dir=...` / `worktree_dir=...` などを出力。

根拠: `core/run-oneshot.sh`

## worktree と PR 連携
- `worktree: true` の場合、`create-worktree.sh` で worktree を作成し、`target_dir` を差し替えます。
- `pr_yml: true` は `worktree: true` が前提。`generate-pr-yml.sh` を実行して `pr.yml` を生成します。
- `pr: true` の場合、`create-pr.sh` により PR 作成を行います（`pr_draft: true` で Draft）。
- `pr: true` の場合は `pr-draft` skill が自動で追加されます（既に指定済みなら追加しません）。

根拠: `core/run-oneshot.sh`

## 注意点
- YAML パースは簡易実装であり、ネストや複雑な構文は想定していません。
- `prompt_file`/`prompt_text` の排他違反や入力ファイル不在はエラー終了します。

根拠: `core/run-oneshot.sh`
