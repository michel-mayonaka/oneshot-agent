# 導入手順

## 対象
- ハーネスを初めて使う人向け。
- 環境準備とセットアップのみを扱う。

## 前提
- oneshot-agent 自体は OS 非依存ですが、依存コマンド（`codex` / `jq` / `gh`）が必要です。
- GitHub を扱うジョブ（Issue/PR系）を実行する場合は `gh` の認証が必要です（`gh auth login` または `GH_TOKEN`）。

## Codex Web 前提（2026-01 時点の確認結果）
- OS: Ubuntu 24.04（Linux）
- シェル: `bash`
- パッケージマネージャ: `apt`
- ファイル書き込み: ワークスペース（作業ディレクトリ）配下は書き込み可能
- ネットワーク: 制限される場合がある（外部アクセス/インストールが必要な操作は失敗する可能性あり）

※ Codex Web の仕様変更の可能性はあるため、まず `tools/setup_codex_web.sh` で現状を確認してください。

## Codex Web 向け手順（推奨）
1. リポジトリのルートで次を実行して、依存コマンドと環境変数の案内を確認します。
   ```bash
   bash tools/setup_codex_web.sh
   ```
2. `ONESHOT_AGENT_ROOT` が未設定の場合は、次のどちらかで設定します。
   ```bash
   # 例: 自分で設定する
   export ONESHOT_AGENT_ROOT="$(pwd)"

   # 例: セットアップシェルが出す export を反映する
   eval "$(bash tools/setup_codex_web.sh --print-env)"
   ```
3. 最小実行例:
   ```bash
   bash core/run_oneshot.sh --job run-defs/jobs/doc-audit-fix.yml
   ```

## 環境変数
- `ONESHOT_AGENT_ROOT` を本リポジトリに設定する。
- 対象リポジトリが別の場合は `ONESHOT_PROJECT_ROOT` を設定する。

```bash
export ONESHOT_AGENT_ROOT="/path/to/oneshot-agent"
export ONESHOT_PROJECT_ROOT="/path/to/target-repo" # 任意
```

## 次に読むもの
- docs/user/02-user-workflow.md
