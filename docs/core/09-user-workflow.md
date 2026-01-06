# ハーネス利用者向けワークフロー

## 対象
- ハーネスを使って Issue 作成・作業実行・PR 作成を行う人向け。
- ハーネス自体の開発者向けは別ドキュメントで整理する。

## 導入方法
1. 動作確認 OS は macOS のみ（mac 前提で運用する）。
2. `codex` と `jq` と `gh` を PATH に用意する。
3. `gh auth login` を済ませる。
3. `ONESHOT_AGENT_ROOT` を本リポジトリに設定する。
4. 対象リポジトリが別の場合は `ONESHOT_PROJECT_ROOT` を設定する。

```bash
export ONESHOT_AGENT_ROOT="/path/to/oneshot-agent"
export ONESHOT_PROJECT_ROOT="/path/to/target-repo" # 任意
```

## planning-mode で Issue を作成する
- 主要な使い方は「プロンプトをそのまま渡す」方式。
- 実行例（推奨）:
```bash
make mode-planning "調査してIssue化したい内容"
```
- ファイルで渡す場合:
```bash
make mode-planning PLAN_REQUEST=inputs/plan-request.md
```
- planning モードは「計画と Issue 案の提案 → 承認 → Issue 作成」の順で進行する。
- Issue 作成は `core/create_issue.sh` を使うため、`gh` の設定が必須。

## Issue をもとに作業を行わせ PR を発行する
- Issue 番号を直接使う場合:
```bash
make issue-apply ISSUE=123
```
- ローカルの issue.yml を使う場合:
```bash
make issue-apply ISSUE_FILE=inputs/issue.yml
```
- `issue-apply` ジョブは worktree 上で作業し、差分があれば PR を作成する。
- PR 作成には `gh` と `git push` が必要（認証や権限に注意）。

## PR にレビューコメントをつけて修正させる
- GitHub 上でレビューコメントを付けたあとに実行する。
- 実行例（PR番号またはURL）:
```bash
make pr-review-fix PR=123
```
- `pr-review-fix` は PR 情報とレビューコメントを取得し、PR の head ブランチに対して修正→push まで行う。
- fork PR などで push 権限がない場合は「要確認」として止まる。
- 乖離が大きい場合は Issue 作成からやり直すのを推奨。

## 新しいジョブを作成する
- 依頼内容を `inputs/job-request.md` などに用意する。
- 実行例:
```bash
make create-run-def-job CREATE_RUN_DEF_JOB_REQUEST=inputs/job-request.md
```
- 入力が不足している場合は質問のみを返し、リポジトリ変更は行われない。

## 関連ドキュメント
- docs/core/04-workflow.md
- docs/core/07-issue-workflow.md
- docs/core/08-modes.md
