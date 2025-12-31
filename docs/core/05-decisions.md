# 意思決定（ADR運用）

## ADR運用ルール
- 重要な設計変更時に ADR を書きます。
- 不変条件に触れる変更は必須です。
- ログ形式の変更も必須です。
- セキュリティ方針の変更も必須です。
- 1件の ADR は1つの決定に絞ります。

## ADRの更新と廃止
- 変更が発生したら新規 ADR を追加します。
- 既存 ADR は「Superseded」にします。
- 置換先の ADR 番号を明記します。

## ADR一覧
- docs/core/adr/0001-record-architecture-decisions.md

## Superseded ルール
- 旧ADRに「Superseded by ADR-XXXX」を追記します。
- 新ADRに「Supersedes ADR-XXXX」を追記します。

## 保証
- ADRは `docs/core/adr/` に保存します。

## 仮定
- ADRの採番ルールはこの文書に従います。
