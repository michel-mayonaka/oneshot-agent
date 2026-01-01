SHELL := /bin/bash

.PHONY: doc-audit doc-fix doc-reference-update word-lookup create-run-def-job test test-doc test-shellspec

PROJECT_ROOT ?= $(CURDIR)
DOC_AUDIT_SPEC ?= run-defs/jobs/doc-audit.yml
DOC_FIX_SPEC ?= run-defs/jobs/doc-fix.yml
DOC_REFERENCE_UPDATE_SPEC ?= run-defs/jobs/doc-reference-update.yml
WORD_LOOKUP_SPEC ?= run-defs/jobs/word-lookup.yml
CREATE_RUN_DEF_JOB_SPEC ?= run-defs/jobs/create-run-def-job.yml
REPORT ?=
WORDS ?=
CREATE_RUN_DEF_JOB_REQUEST ?=
SHELLSPEC ?= tools/shellspec/shellspec

WORD_LOOKUP_WORDS := $(filter-out word-lookup,$(MAKECMDGOALS))
CREATE_RUN_DEF_JOB_TEXT := $(filter-out create-run-def-job,$(MAKECMDGOALS))

doc-audit:
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --job $(DOC_AUDIT_SPEC)

doc-fix:
	@if [[ -z "$(REPORT)" ]]; then echo "REPORT is required (e.g. make doc-fix REPORT=worklogs/doc-audit/<run_id>/report.md)"; exit 1; fi
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --job $(DOC_FIX_SPEC) --input audit_report=$(REPORT)

doc-reference-update:
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run-oneshot.sh --job $(DOC_REFERENCE_UPDATE_SPEC)

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

create-run-def-job:
	@REQUEST_PATH="$(CREATE_RUN_DEF_JOB_REQUEST)"; \
	REQUEST_TEXT="$(CREATE_RUN_DEF_JOB_TEXT)"; \
	if [[ -z "$$REQUEST_PATH" && -z "$$REQUEST_TEXT" ]]; then \
		echo "CREATE_RUN_DEF_JOB_REQUEST is required (e.g. make create-run-def-job CREATE_RUN_DEF_JOB_REQUEST=inputs/job-request.md or make create-run-def-job <free-text...>)"; \
		exit 1; \
	fi; \
	TMP_DIR=$$(mktemp -d); \
	if [[ -z "$$REQUEST_PATH" ]]; then \
		printf '%s\n' "$$REQUEST_TEXT" > $$TMP_DIR/job-request.txt; \
		REQUEST_PATH="$$TMP_DIR/job-request.txt"; \
	fi; \
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" \
		bash core/run-oneshot.sh --job $(CREATE_RUN_DEF_JOB_SPEC) --input job_request=$$REQUEST_PATH; \
	rm -rf $$TMP_DIR

$(CREATE_RUN_DEF_JOB_TEXT):
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
