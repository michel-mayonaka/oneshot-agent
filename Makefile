SHELL := /bin/bash

.PHONY: doc-audit doc-fix word-lookup test test-doc test-shellspec

PROJECT_ROOT ?= $(CURDIR)
DOC_AUDIT_SPEC ?= run-defs/jobs/doc-audit.yml
DOC_FIX_SPEC ?= run-defs/jobs/doc-fix.yml
WORD_LOOKUP_SPEC ?= run-defs/jobs/word-lookup.yml
REPORT ?=
WORDS ?=
SHELLSPEC ?= tools/shellspec/shellspec

WORD_LOOKUP_WORDS := $(filter-out word-lookup,$(MAKECMDGOALS))

doc-audit:
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --job $(DOC_AUDIT_SPEC)

doc-fix:
	@if [[ -z "$(REPORT)" ]]; then echo "REPORT is required (e.g. make doc-fix REPORT=worklogs/doc-audit/<run_id>/report.md)"; exit 1; fi
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --job $(DOC_FIX_SPEC) --input audit_report=$(REPORT)

word-lookup:
	@WORDS_LIST="$(WORDS)"; \
	if [[ -z "$$WORDS_LIST" ]]; then WORDS_LIST="$(WORD_LOOKUP_WORDS)"; fi; \
	if [[ -z "$$WORDS_LIST" ]]; then echo "WORDS is required (e.g. make word-lookup WORDS=inputs/words.txt or make word-lookup word1 word2)"; exit 1; fi; \
	TMP_DIR=$$(mktemp -d); \
	printf '%s\n' $$WORDS_LIST > $$TMP_DIR/words.txt; \
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --job $(WORD_LOOKUP_SPEC) --input words=$$TMP_DIR/words.txt; \
	rm -rf $$TMP_DIR

$(WORD_LOOKUP_WORDS):
	@:

test: test-shellspec test-doc

test-shellspec:
	@if [[ ! -x "$(SHELLSPEC)" ]]; then echo "ShellSpec not installed. Run: bash tools/install-shellspec.sh"; exit 1; fi
	@$(SHELLSPEC) --shell bash specs/shells

test-doc:
	@TMP_DIR=$$(mktemp -d); \
	printf '# Dummy Report\n' > $$TMP_DIR/audit_report.md; \
	ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --job $(DOC_AUDIT_SPEC) --render-only >/dev/null; \
	ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --job $(DOC_FIX_SPEC) --input audit_report=$$TMP_DIR/audit_report.md --render-only >/dev/null; \
	rm -rf $$TMP_DIR; \
	echo "OK"
