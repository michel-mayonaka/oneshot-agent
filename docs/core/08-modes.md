# モード実行

## 目的
- Codex のセッションを指定プロンプトで起動する。
- 計画 → 承認 → Issue化の一連作業をテンプレ化する。

## 基本コマンド
```bash
bash core/run_mode.sh --mode run-defs/modes/planning.yml --input plan_request=inputs/plan-request.md
```

## Makefile 経由
```bash
make mode-planning PLAN_REQUEST=inputs/plan-request.md
make mode-planning 調査してIssue化したい内容
```

## モードYAML（例）
```yaml
name: issue-planning
prompt_text: |
  ...
skills:
model: gpt-5.2-codex
thinking: medium
```

## 仕様
- `prompt_text` は必須です。
- `skills` は任意（optional skill 名、またはファイルパス）。
- `__INPUT_<KEY>__` を `--input key=path` で置換します。
- セッション内で `ONESHOT_MODE_RUN_DIR` / `ONESHOT_MODE_INPUTS_DIR` が利用できます。
- planning モードは承認後に Issue 作成を行います。
