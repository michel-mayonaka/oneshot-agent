SHELL := /bin/bash

.PHONY: doc-audit doc-fix test

PROJECT_ROOT ?= $(CURDIR)
DOC_AUDIT_SPEC ?= specs/doc-audit.yml
DOC_FIX_SPEC ?= specs/doc-fix.yml
REPORT ?=

doc-audit:
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --spec $(DOC_AUDIT_SPEC)

doc-fix:
	@if [[ -z "$(REPORT)" ]]; then echo "REPORT is required (e.g. make doc-fix REPORT=worklogs/doc-audit/<run_id>/summary_report.md)"; exit 1; fi
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --spec $(DOC_FIX_SPEC) --audit-report $(REPORT)

test:
	@TMP_DIR=$$(mktemp -d); \
	printf '# Dummy Report\n' > $$TMP_DIR/audit_report.md; \
	bash core/run-oneshot.sh --spec $(DOC_AUDIT_SPEC) --render-only >/dev/null; \
	bash core/run-oneshot.sh --spec $(DOC_FIX_SPEC) --audit-report $$TMP_DIR/audit_report.md --render-only >/dev/null; \
	rm -rf $$TMP_DIR; \
	echo "OK"
