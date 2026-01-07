---
name: create-run-def-job
description: Create or update run-defs job specs and matching Makefile targets in this repository. Use when asked to add a new job, generate run-defs/jobs/*.yml, add a make target to execute a job, or provide templates for audit/fix/dictionary/research/implementation job types.
---

# Purpose

このスキルは、`run-defs/jobs/*.yml` の新規作成と `Makefile` の実行ターゲット追加を素早く・一貫した形で行うための手順をまとめる。

# Workflow

1) 依頼内容から不足情報を洗い出し、必要な分だけ質問する。  
   - 例: ジョブ名 / 種別（監査・修正・辞書・調査・実装） / job_type / 入力の有無 / 期待する出力
2) `run-defs/jobs/<name>.yml` を作る。  
   - `prompt_text` と `prompt_file` は排他的。  
   - 入力が必要なら `__INPUT_<KEY>__` を本文に埋め、`--input key=path` で渡す前提にする（KEYは大文字化）。  
   - worktree/pr 系の指定は `job_type` に集約する。  
   - 既定値の扱いは `core/run_oneshot.sh` の仕様に合わせる。
3) `Makefile` にターゲットを追加する。  
   - `PHONY` と `*_SPEC` 変数を更新する。  
   - 入力が必要なら `make <target> INPUT=...` 形式でエラーガードを入れる。  
4) make コマンドで作成したジョブをテスト実行する。  
   - 入力が必要なら、最小のダミー入力ファイルを作って渡す。  
   - 例: `make <target> INPUT=inputs/sample.txt`
5) 変更後の利用例を短く提示する。

# Conventions / Notes

- ジョブ名は kebab-case を基本にする（例: `doc-audit`, `word-lookup`）。
- job spec はフラット YAML（ネストは `skills:` の配列のみ）。
- job_type の既定は「用途に合わせて明示」。  
- 迷う場合は `references/templates.md` のテンプレートをベースにする。
- `make create-run-def-job <free-text...>` のように引数で依頼文を渡す形式も許可する（空白区切り語を1行テキストとして扱う）。
- `skills:` には skill 名だけでなく、参照したいファイルパス（例: `skills/optional/create-run-def-job/SKILL.md`）を列挙できる。

# References

- ひな形と例: `references/templates.md`
