# oneshot-agent

Codex CLI を1回実行し、ログと成果物を残すハーネスです。
ワークフローの入口に徹し、詳細は docs/ に集約します。

## できること
- 単一プロンプト実行とログ保存。
- job YAML による実行の定型化。
- worktree を使った安全な作業ディレクトリ。
- 実行サマリーレポートの生成。
- PR下書きやPR作成の補助（要 gh）。
- PRレビュー対応の修正支援（要 gh / push 権限）。

## できないこと
- ジョブキューやスケジューラ運用。
- 自動リトライやバックオフ。
- ログの自動マスキング。
- プロンプトサイズの自動制御（未実装）。

## クイックスタート
前提: 動作確認は macOS のみ。
前提: `codex` と `jq` と `gh` が PATH にあります。
前提: `gh auth login` 済み。
前提: `ONESHOT_AGENT_ROOT` に本リポジトリを設定します。
導入手順は `docs/user/01-setup.md` を参照してください。

```bash
export ONESHOT_AGENT_ROOT="$(pwd)"
bash core/oneshot_exec.sh "List files and summarize"
```

job 実行の最小例です。

```bash
export ONESHOT_AGENT_ROOT="$(pwd)"
bash core/run_oneshot.sh --job run-defs/jobs/doc-audit-fix.yml
```

生成物は `worklogs/` 配下に保存されます。

Issue 作成/適用の例です。

```bash
make issue-create ISSUE_REQUEST=inputs/issue-request.md
make issue-apply ISSUE=123
```

PRレビュー対応の例です。

```bash
make pr-review-fix PR=123
```

planning モードの例です。

```bash
make mode-planning PLAN_REQUEST=inputs/plan-request.md
make mode-planning 調査してIssue化したい内容
```

## ClaudeCode (slash command) での利用

ClaudeCode上で対話的にIssue作成を行う場合:

```
/issue-planning

依頼内容: ドキュメントの更新とテストの追加
```

ClaudeCode用のslash commandは `.claude/commands/` に定義されています。
codex CLI版との主な違い:
- モデル: ClaudeCode (Sonnet等) を使用
- 対話的: ユーザーとの対話でIssue内容を調整
- 既存スクリプト: `core/create_issue.sh` を活用

## ドキュメント
- docs/core/01-purpose.md
- docs/core/02-invariants.md
- docs/core/03-architecture.md
- docs/core/04-workflow.md
- docs/core/05-decisions.md
- docs/core/adr/0001-record-architecture-decisions.md
- docs/core/07-issue-workflow.md
- docs/core/08-modes.md
- docs/user/README.md
- docs/user/01-setup.md
- docs/user/02-user-workflow.md
- docs/user/03-job-setup.md

## 問い合わせ / Issue
GitHub Issue を利用してください。

必要情報テンプレ:
- 目的と期待する結果
- 実行コマンド
- `run_dir` のパス
- `logs/stderr_and_time.txt` の抜粋
- OS とシェル
- 秘密情報は伏せること

## 保証
- `worklogs/` に実行ログを残します（現行実装）。

## 仮定
- `codex` と `jq` が動作します。
- ログに秘密情報は含めません。
