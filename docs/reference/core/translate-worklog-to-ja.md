# translate-worklog-to-ja.sh リファレンス

## 概要
- `worklog.md` を Codex で日本語へ翻訳し、`worklog.ja.md` を生成します。

根拠: `core/translate-worklog-to-ja.sh`

## CLI
```
usage: translate-worklog-to-ja.sh <run_dir>
```

根拠: `core/translate-worklog-to-ja.sh`

## 入力
- `<run_dir>/worklog.md`

根拠: `core/translate-worklog-to-ja.sh`

## 出力
- `<run_dir>/worklog.ja.md`

根拠: `core/translate-worklog-to-ja.sh`

## 環境変数
- `ONESHOT_TRANSLATE_MODEL`（任意）: Codex 実行モデル（未指定時は `gpt-5.2`）。

根拠: `core/translate-worklog-to-ja.sh`

## 依存/前提
- `codex` CLI が PATH に存在すること。

根拠: `core/translate-worklog-to-ja.sh`
