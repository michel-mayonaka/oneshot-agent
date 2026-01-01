# レポート/翻訳 参照

## summarize_run.sh
### 概要
run ディレクトリ配下のログを集約し、`report.md` を生成します。

### CLI
```
Usage: summarize_run.sh <run_dir>
```

### 収集対象 (主な入力)
- `<run_dir>/logs/events.jsonl`
- `<run_dir>/logs/stderr_and_time.txt`
- `<run_dir>/prompts/prompt.txt`
- `<run_dir>/logs/last_message.md`
- `<run_dir>/prompts/skills_used.txt`

### 出力
- `<run_dir>/report.md`

### 挙動の要点
- `jq` が存在する場合のみ token usage を抽出。
- `git` が利用可能かつ現在ディレクトリが git repo の場合、ブランチ/コミット/差分を記載。
- `shasum -a 256` で `prompt.txt` のハッシュを記録。
- `stderr_and_time.txt` から `real/user/sys` を抽出。

## translate-worklog-to-ja.sh
### 概要
`worklog.md` を日本語へ翻訳し、`worklog.ja.md` を生成します。

### CLI
```
Usage: translate-worklog-to-ja.sh <run_dir>
```

### 前提
- `<run_dir>/worklog.md` が存在すること
- `codex` コマンドが利用可能であること

### 環境変数
- `ONESHOT_TRANSLATE_MODEL`: Codex モデル（未指定時 `gpt-5.2`）

### 出力
- `<run_dir>/worklog.ja.md`

## 根拠
- `core/summarize_run.sh`
- `core/translate-worklog-to-ja.sh`
