# ハーネス利用者向けワークフロー

## 対象
- planning-mode から PR マージまでのフローを扱う。
- これらの作業は全て make コマンドを通してのみ行う。

## スコープ外
- 導入手順（環境準備・セットアップ）
- 新しいジョブの作成と導入（`docs/user/03-job-setup.md` を参照）

## 運用方法
## 1. planning-mode で Issue を作成する
- まずはエージェントともに作業計画を立てる。
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
- 実際に作成したissueはこちら
  - https://github.com/michel-mayonaka/oneshot-agent/issues/20#issue-3784268365
- issueをもとにエージェントがそのまま作業->PRの発行を行う.
- issueの発行は下記テンプレートの内容をもとにエージェント側が行う。
  - https://github.com/michel-mayonaka/oneshot-agent/blob/main/skills/optional/issue-template.md

## 2. Issue をもとに作業を行わせ PR を発行する
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
- 特に問題がなければ承認を行いマージ。
- 問題がある場合はレビューコメントをつけ、[[3. PR にレビューコメントをつけて修正させる]] を行う。

## 3. PR にレビューコメントをつけて修正させる
- GitHub 上でレビューコメントを付けたあとに実行する。
- 実行例（PR番号またはURL）:
```bash
make pr-review-fix PR=123
```
- `pr-review-fix` は PR 情報とレビューコメントを取得し、PR の head ブランチに対して修正→push まで行う。
- fork PR などで push 権限がない場合は「要確認」として止まる。
- 乖離が大きい場合は Issue 作成からやり直すのを推奨。

## 関連ドキュメント
- docs/core/04-workflow.md
- docs/core/07-issue-workflow.md
- docs/core/08-modes.md
- docs/user/01-setup.md
- docs/user/03-job-setup.md
