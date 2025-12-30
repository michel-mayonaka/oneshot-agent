# Refactor Safety Guidelines

- Prefer small, incremental changes with clear diffs.
- Keep public APIs backwards compatible unless explicitly allowed to break them.
- Preserve existing behaviour; add tests or checks before large refactors when可能なら。
- Avoid large, cross-cutting renames in a single run; focus on one concern.
- Clearly document any behaviour changes in comments or README updates.

