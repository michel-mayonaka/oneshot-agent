# Create Run-Def Job Skill

目的:
- `run-defs/jobs/*.yml` の新規作成と `Makefile` の実行ターゲット追加を行う。

進め方:
1) 依頼内容から不足情報を洗い出し、必要な分だけ質問する。
2) `run-defs/jobs/<name>.yml` を作る（`prompt_text` と `prompt_file` は排他）。
3) `Makefile` にターゲットを追加する（PHONY / 変数 / 入力ガード）。
4) 変更後の利用例を短く提示する。

参照:
- `skills/optional/create-run-def-job/references/templates.md`

実行メモ:
- `make create-run-def-job CREATE_RUN_DEF_JOB_REQUEST=inputs/job-request.md`
- `make create-run-def-job <free-text...>` の形式も許可し、空白区切りの語を1行テキストとして扱う
