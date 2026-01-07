# ジョブ作成・導入手順

## 対象
- 新しいジョブを追加したい人向け。
- `run-defs/jobs/` と `Makefile` への導入までを扱う。

## 前提
- 導入手順は `docs/user/01-setup.md` を参照。

## 依頼内容の整理
最低限、以下を決めます。
- ジョブ名（kebab-case）
- 目的と期待する成果
- 種別（監査・修正・辞書・調査・実装）
- 入力の有無（必要なら input key とファイル）
- 出力物の想定（report など）
- job_type（worktree/PR の扱い）
- 使う skills（必要なら）
- model / thinking（必要なら）

簡易テンプレ:
```text
ジョブ名: example-job
目的: 〜を自動化したい
種別: 調査
入力: あり（input key: foo, ファイル: inputs/foo.md）
出力: report.md に要約
job_type: no_worktree
skills: なし
model: 既定でよい
thinking: 既定でよい
```

job_type の値:
- no_worktree: worktree=false, pr=false, worktree_pr=false
- worktree: worktree=true, pr=false, worktree_pr=false
- worktree_and_pr: worktree=true, pr=true, worktree_pr=false
- pr_worktree: worktree=true, worktree_pr=true, worktree_pr_input=pr, pr=false

## 作成手順
1. 依頼内容を `inputs/job-request.md` にまとめる。
2. 生成ジョブを実行する。

```bash
make create-run-def-job CREATE_RUN_DEF_JOB_REQUEST=inputs/job-request.md
```

- 不足情報がある場合は質問のみ返り、リポジトリ変更は行われません。

## 導入確認
- 生成された `run-defs/jobs/<job-name>.yml` と `Makefile` を確認する。
- 入力が必要なジョブは最小のダミー入力で実行し、`report.md` が出るか確認する。

## 補足
- `prompt_text` と `prompt_file` は同時に使いません。
- 入力が必要な場合、本文に `__INPUT_<KEY>__` を埋めて `--input key=path` で渡す設計にします。
- `worklogs/` 配下は基本的にコミット対象外です。
