# summarize_run.sh リファレンス

## 概要
- `logs/events.jsonl` 等を集計し、`report.md` を生成します。

根拠: `core/summarize_run.sh`

## CLI
```
usage: summarize_run.sh <run_dir>
```

根拠: `core/summarize_run.sh`

## 入力
- `<run_dir>/logs/events.jsonl`
- `<run_dir>/logs/stderr_and_time.txt`
- `<run_dir>/prompts/prompt.txt`
- `<run_dir>/logs/last_message.md`（無い場合は `logs/worklog.md` / `logs/worklog.txt` を参照）
- `<run_dir>/prompts/skills_used.txt`

根拠: `core/summarize_run.sh`

## 出力
- `<run_dir>/report.md`

根拠: `core/summarize_run.sh`

## 生成内容（report.md）
- 実行メタデータ（run_dir / prompt_sha256 / 実行時間 / token usage / skills）
- Git コンテキスト（ブランチ / commit / dirty files / diff）
- プロンプト先頭 80 行
- 最終メッセージ or worklog 先頭
- stderr からのエラー・警告抽出
- 生成物一覧

根拠: `core/summarize_run.sh`

## 注意点
- `jq` がある場合のみ usage を抽出します。
- `git` が利用可能な場合のみ Git 情報を収集します。
- `shasum` を使って `prompt.txt` のハッシュを出力します（存在チェックはありません）。

根拠: `core/summarize_run.sh`
