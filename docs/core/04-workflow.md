# ワークフロー

## 標準フロー（ハッピーパス）
1. `ONESHOT_AGENT_ROOT` を設定します。
2. prompt か job spec を用意します。
3. 必要なら `ONESHOT_PROJECT_ROOT` を設定します。
4. `core/run_oneshot.sh --job ...` を実行します。
5. 出力された `run_dir` を控えます。
6. `worklogs/` の `report.md` を確認します。

## 例外フロー: AIが間違う
- 症状: 出力が期待と異なります。
- 対応: プロンプトを修正し再実行します。
- 対応: 差分は `worklog.md` で確認します。

## 例外フロー: 必要コンテキスト不足
- 症状: 入力不足の指摘や誤推測が出ます。
- 対応: `--input` で資料を追加します。
- 対応: `-C` で対象リポジトリを指定します。

## 例外フロー: 部分失敗
- 症状: 一部成果物のみ生成されます。
- 対応: `logs/stderr_and_time.txt` を確認します。
- 対応: 必要なら worktree を削除します。

## モードフロー
- `core/run_mode.sh --mode run-defs/modes/<mode>.yml` でセッションを起動します。
- `--input` を使って `__INPUT_<KEY>__` を置換できます。
- モード内で issue 作成などの自動実行を指示できます。

## 手動復旧手順
- `run_dir` と `logs/` を確認します。
- 失敗理由をメモし再実行します。
- worktree 使用時は削除を検討します。
- `core/remove_worktree.sh` を使います。

## Definition of Done
- `report.md` が存在します。
- `logs/events.jsonl` が存在します。
- `prompts/prompt.txt` が存在します。
- `logs/stderr_and_time.txt` を確認済みです。
- worktree 使用時は `run_dir/worktree` が存在します。

## 保証
- 標準フローは `run_oneshot.sh` を基準とします。

## 仮定
- 実行環境と依存コマンドが利用可能です。
