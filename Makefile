PYTHON ?= python3
EVIDENCE_DIR ?= evidence
PUBLIC_ROOT ?= www
BASE_URL ?=
PROJECT_ROOT ?= .
OPTIMIZATION_AUDIT_OUTPUT ?=
OPTIMIZATION_EVIDENCE_DIR ?= evidence/$$(date +%F)-optimization-audit
OPTIMIZATION_FINDING_COUNT ?= 5

.PHONY: validate release-check evidence-p1 evidence-all preflight optimization-audit optimization-evidence validate-optimization-evidence

validate:
	$(PYTHON) -m py_compile scripts/*.py
	$(PYTHON) scripts/validate_skill.py
	$(PYTHON) scripts/validate_runtime_evidence.py examples/runtime-smoke/blocked-p1 --package P1
	$(PYTHON) scripts/validate_optimization_evidence.py examples/optimization-evidence/sample-candidate
	bash -n install.sh bitrix/*.sh

release-check: validate
	git diff --check
	git status -sb

evidence-p1:
	$(PYTHON) scripts/init_runtime_evidence.py --package P1 --output "$(EVIDENCE_DIR)/$$(date +%F)-p1-shop-path"

evidence-all:
	$(PYTHON) scripts/init_runtime_evidence.py --all --output "$(EVIDENCE_DIR)/$$(date +%F)-runtime-smoke-all"

preflight:
	$(PYTHON) scripts/bitrix_runtime_preflight.py --public-root "$(PUBLIC_ROOT)" --base-url "$(BASE_URL)"

optimization-audit:
	$(PYTHON) scripts/bitrix_static_optimization_audit.py "$(PROJECT_ROOT)" $(if $(OPTIMIZATION_AUDIT_OUTPUT),--output "$(OPTIMIZATION_AUDIT_OUTPUT)",)

optimization-evidence:
	$(PYTHON) scripts/init_optimization_evidence.py --output "$(OPTIMIZATION_EVIDENCE_DIR)" --finding-count "$(OPTIMIZATION_FINDING_COUNT)"

validate-optimization-evidence:
	$(PYTHON) scripts/validate_optimization_evidence.py "$(OPTIMIZATION_EVIDENCE_DIR)"
