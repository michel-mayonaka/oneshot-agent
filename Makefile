SHELL := /bin/bash

.PHONY: doc-audit-fix issue-create issue-apply doc-reference-update word-lookup create-run-def-job test test-doc test-shellspec

PROJECT_ROOT ?= $(CURDIR)
DOC_AUDIT_FIX_SPEC ?= run-defs/jobs/doc-audit-fix.yml
ISSUE_CREATE_SPEC ?= run-defs/jobs/issue-create.yml
ISSUE_APPLY_SPEC ?= run-defs/jobs/issue-apply.yml
DOC_REFERENCE_UPDATE_SPEC ?= run-defs/jobs/doc-reference-update.yml
WORD_LOOKUP_SPEC ?= run-defs/jobs/word-lookup.yml
CREATE_RUN_DEF_JOB_SPEC ?= run-defs/jobs/create-run-def-job.yml
WORDS ?=
CREATE_RUN_DEF_JOB_REQUEST ?=
ISSUE_REQUEST ?=
ISSUE ?=
ISSUE_FILE ?=
SHELLSPEC ?= tools/shellspec/shellspec

WORD_LOOKUP_WORDS :=
CREATE_RUN_DEF_JOB_TEXT :=

ifneq ($(filter word-lookup,$(MAKECMDGOALS)),)
WORD_LOOKUP_WORDS := $(filter-out word-lookup,$(MAKECMDGOALS))
$(WORD_LOOKUP_WORDS):
	@:
endif

ifneq ($(filter create-run-def-job,$(MAKECMDGOALS)),)
CREATE_RUN_DEF_JOB_TEXT := $(filter-out create-run-def-job,$(MAKECMDGOALS))
$(CREATE_RUN_DEF_JOB_TEXT):
	@:
endif

doc-audit-fix:
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run_oneshot.sh --job $(DOC_AUDIT_FIX_SPEC)

issue-create:
	@if [[ -z "$(ISSUE_REQUEST)" ]]; then echo "ISSUE_REQUEST is required (e.g. make issue-create ISSUE_REQUEST=inputs/issue-request.md)"; exit 1; fi
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run_oneshot.sh --job $(ISSUE_CREATE_SPEC) --input issue_request=$(ISSUE_REQUEST)

issue-apply:
	@TMP_DIR=$$(mktemp -d); \
	ISSUE_PATH="$(ISSUE_FILE)"; \
	if [[ -z "$$ISSUE_PATH" ]]; then \
		if [[ -z "$(ISSUE)" ]]; then \
			echo "ISSUE or ISSUE_FILE is required (e.g. make issue-apply ISSUE=123 or ISSUE_FILE=inputs/issue.yml)"; \
			rm -rf $$TMP_DIR; \
			exit 1; \
		fi; \
		ISSUE_PATH="$$TMP_DIR/issue.yml"; \
		ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/fetch_issue.sh --repo "$(PROJECT_ROOT)" --issue "$(ISSUE)" --out "$$ISSUE_PATH"; \
	fi; \
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run_oneshot.sh --job $(ISSUE_APPLY_SPEC) --input issue=$$ISSUE_PATH; \
	rm -rf $$TMP_DIR

doc-reference-update:
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run_oneshot.sh --job $(DOC_REFERENCE_UPDATE_SPEC)

word-lookup:
	@WORDS_LIST="$(WORDS)"; \
	if [[ -z "$$WORDS_LIST" ]]; then WORDS_LIST="$(WORD_LOOKUP_WORDS)"; fi; \
	if [[ -z "$$WORDS_LIST" ]]; then echo "WORDS is required (e.g. make word-lookup WORDS=inputs/words.txt or make word-lookup word1 word2)"; exit 1; fi; \
	TMP_DIR=$$(mktemp -d); \
	printf '%s\n' $$WORDS_LIST > $$TMP_DIR/words.txt; \
	ONESHOT_PROJECT_ROOT="$(PROJECT_ROOT)" ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run_oneshot.sh --job $(WORD_LOOKUP_SPEC) --input words=$$TMP_DIR/words.txt; \
	rm -rf $$TMP_DIR

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
		bash core/run_oneshot.sh --job $(CREATE_RUN_DEF_JOB_SPEC) --input job_request=$$REQUEST_PATH; \
	rm -rf $$TMP_DIR

test: test-shellspec test-doc

test-shellspec:
	@if [[ ! -x "$(SHELLSPEC)" ]]; then echo "ShellSpec not installed. Run: bash tools/install_shellspec.sh"; exit 1; fi
	@$(SHELLSPEC) --shell bash specs/shells

test-doc:
	@TMP_DIR=$$(mktemp -d); \
	printf '# Dummy Report\n' > $$TMP_DIR/audit_report.md; \
	ONESHOT_AGENT_ROOT="$(PROJECT_ROOT)" bash core/run_oneshot.sh --job $(DOC_AUDIT_FIX_SPEC) --render-only >/dev/null; \
	rm -rf $$TMP_DIR; \
	echo "OK"
