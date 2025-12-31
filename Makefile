SHELL := /bin/bash

.PHONY: doc-audit doc-fix test test-doc test-shellspec

PROJECT_ROOT ?= $(CURDIR)
DOC_AUDIT_SPEC ?= specs/doc-audit.yml
DOC_FIX_SPEC ?= specs/doc-fix.yml
REPORT ?=
SHELLSPEC ?= tools/shellspec/shellspec

doc-audit:
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --spec $(DOC_AUDIT_SPEC)

doc-fix:
	@if [[ -z "$(REPORT)" ]]; then echo "REPORT is required (e.g. make doc-fix REPORT=worklogs/doc-audit/<run_id>/report.md)"; exit 1; fi
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --spec $(DOC_FIX_SPEC) --input audit_report=$(REPORT)

test: test-shellspec test-doc

test-shellspec:
	@if [[ ! -x "$(SHELLSPEC)" ]]; then echo "ShellSpec not installed. Run: bash tools/install-shellspec.sh"; exit 1; fi
	@$(SHELLSPEC) --shell bash spec

test-doc:
	@TMP_DIR=$$(mktemp -d); \
	printf '# Dummy Report\n' > $$TMP_DIR/audit_report.md; \
	ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --spec $(DOC_AUDIT_SPEC) --render-only >/dev/null; \
	ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --spec $(DOC_FIX_SPEC) --input audit_report=$$TMP_DIR/audit_report.md --render-only >/dev/null; \
	rm -rf $$TMP_DIR; \
	echo "OK"
