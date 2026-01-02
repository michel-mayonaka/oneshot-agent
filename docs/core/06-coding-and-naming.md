# コーディング・命名ルール

## 適用範囲
- 本リポジトリのコード・定義・ドキュメントの新規追加と改名に適用します。
- `tools/shellspec/` はベンダー領域のため適用外です。
- `worklogs/` は生成物の保存先なので手動変更しません。

## 命名規則（必須）
- ディレクトリ名は kebab-case。
- ファイル名は原則 kebab-case。
- Shell スクリプトは snake_case + `.sh`。
- ShellSpec の spec は snake_case + `_spec.sh`。
- `docs/core/` は `NN-title.md`（NN は 2 桁の連番、title は kebab-case）。
- `docs/core/adr/` は既存の ADR ルールに従う。

## 例外と固定名（必須）
- ルートの固定名: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `Makefile`, `AGENTS.md`
- スキル定義: `skills/**/SKILL.md`
- 生成物: `worklogs/`（ディレクトリ名を変えない）

## 具体例
- `core/run_oneshot.sh`
- `specs/shells/core/run_oneshot_spec.sh`
- `run-defs/jobs/doc-audit-fix.yml`
- `docs/core/06-coding-and-naming.md`

## コーディング規約（必須）
- Shell スクリプトは `bash` + `set -euo pipefail`。
- 関数名・変数名は snake_case。
- パス解決は `ONESHOT_AGENT_ROOT` を基準にし、`../` は使わない。
