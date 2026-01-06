# 導入手順

## 対象
- ハーネスを初めて使う人向け。
- 環境準備とセットアップのみを扱う。

## 前提
- 動作確認 OS は macOS のみ（mac 前提で運用する）。
- `codex` と `jq` と `gh` を PATH に用意する。
- `gh auth login` を済ませる。

## 環境変数
- `ONESHOT_AGENT_ROOT` を本リポジトリに設定する。
- 対象リポジトリが別の場合は `ONESHOT_PROJECT_ROOT` を設定する。

```bash
export ONESHOT_AGENT_ROOT="/path/to/oneshot-agent"
export ONESHOT_PROJECT_ROOT="/path/to/target-repo" # 任意
```

## 次に読むもの
- docs/user/02-user-workflow.md
