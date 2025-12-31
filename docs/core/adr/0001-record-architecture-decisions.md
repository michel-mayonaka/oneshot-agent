# ADR 0001: Architecture Decision Record を採用する

Date: 2025-12-31
Status: Accepted

## Context
- 本リポジトリは運用ハーネスです。
- 仕様分裂が起きやすい前提があります。
- 判断理由を残さないと復旧が難しくなります。

## Decision
- 重要な設計判断は ADR に記録します。
- 形式は Context/Decision/Consequences/Alternatives です。

## Consequences
- 変更理由の追跡が容易になります。
- 文書更新の手間が増えます。

## Alternatives
- README に都度追記する案。
- Issue だけで管理する案。

## ADR を採用する理由
- 運用と設計の境界が曖昧になりやすいです。
- ログ契約と安全策を明文化する必要があります。

## ADR Template
```
# ADR XXXX: <タイトル>

Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded

## Context
- 背景

## Decision
- 決定内容

## Consequences
- 影響

## Alternatives
- 代替案
```
