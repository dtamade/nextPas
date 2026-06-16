PYTHON ?= python3
CORE_ROOT := ../../..
SCRIPT := check_architecture_source_contracts.py
REGISTRY := architecture_contract_registry.json
FIXTURE_ROOT := fixtures/red

.PHONY: build run module-registry-audit dependency-boundary-audit host-raw-ffi-audit governance-docs red-fixtures test clean

build:
	@true

run: build
	$(PYTHON) $(SCRIPT) --core-root $(CORE_ROOT) --registry $(REGISTRY) --summary-line

module-registry-audit: build
	$(PYTHON) $(SCRIPT) --core-root $(CORE_ROOT) --registry $(REGISTRY) --check module-registry --summary-line

dependency-boundary-audit: build
	$(PYTHON) $(SCRIPT) --core-root $(CORE_ROOT) --registry $(REGISTRY) --check dependency-boundary --summary-line

host-raw-ffi-audit: build
	$(PYTHON) $(SCRIPT) --core-root $(CORE_ROOT) --registry $(REGISTRY) --check host-raw-ffi --summary-line

governance-docs: build
	$(PYTHON) $(SCRIPT) --core-root $(CORE_ROOT) --registry $(REGISTRY) --check governance-docs --summary-line

red-fixtures: build
	@set -e; \
	l0_out=$$(mktemp); \
	raw_out=$$(mktemp); \
	registry_out=$$(mktemp); \
	profile_schema_out=$$(mktemp); \
	profile_out=$$(mktemp); \
	doc_out=$$(mktemp); \
	trap 'rm -f "$$l0_out" "$$raw_out" "$$registry_out" "$$profile_schema_out" "$$profile_out" "$$doc_out"' EXIT HUP INT TERM; \
	if $(PYTHON) $(SCRIPT) --source-root $(FIXTURE_ROOT)/l0_dependency/src --registry $(REGISTRY) --check dependency-boundary >"$$l0_out" 2>&1; then \
		cat "$$l0_out"; \
		echo "[FAIL] l0 dependency RED fixture unexpectedly passed"; \
		exit 1; \
	else \
		cat "$$l0_out"; \
		grep -q "l0-dependency" "$$l0_out"; \
	fi; \
	if $(PYTHON) $(SCRIPT) --source-root $(FIXTURE_ROOT)/raw_ffi/src --registry $(REGISTRY) --check host-raw-ffi >"$$raw_out" 2>&1; then \
		cat "$$raw_out"; \
		echo "[FAIL] raw FFI RED fixture unexpectedly passed"; \
		exit 1; \
	else \
		cat "$$raw_out"; \
		grep -q "raw-ffi-token" "$$raw_out"; \
	fi; \
	if $(PYTHON) $(SCRIPT) --registry $(FIXTURE_ROOT)/invalid_registry/missing_required_key.json --check governance-docs >"$$registry_out" 2>&1; then \
		cat "$$registry_out"; \
		echo "[FAIL] invalid registry RED fixture unexpectedly passed"; \
		exit 1; \
	else \
		cat "$$registry_out"; \
		grep -q "registry missing key" "$$registry_out"; \
	fi; \
	if $(PYTHON) $(SCRIPT) --core-root $(FIXTURE_ROOT)/l0_module_profile --registry $(FIXTURE_ROOT)/invalid_registry/missing_profile_field.json --check module-registry >"$$profile_schema_out" 2>&1; then \
		cat "$$profile_schema_out"; \
		echo "[FAIL] invalid L0 profile schema RED fixture unexpectedly passed"; \
		exit 1; \
	else \
		cat "$$profile_schema_out"; \
		grep -q "l0_module_contracts item missing key" "$$profile_schema_out"; \
	fi; \
	if $(PYTHON) $(SCRIPT) --core-root $(FIXTURE_ROOT)/l0_module_profile --registry $(FIXTURE_ROOT)/l0_module_profile/registry.json --check module-registry >"$$profile_out" 2>&1; then \
		cat "$$profile_out"; \
		echo "[FAIL] L0 profile RED fixture unexpectedly passed"; \
		exit 1; \
	else \
		cat "$$profile_out"; \
		grep -q "module-registry-profile" "$$profile_out"; \
	fi; \
	if $(PYTHON) $(SCRIPT) --core-root $(FIXTURE_ROOT)/governance_docs --registry $(FIXTURE_ROOT)/governance_docs/registry.json --check governance-docs >"$$doc_out" 2>&1; then \
		cat "$$doc_out"; \
		echo "[FAIL] governance doc RED fixture unexpectedly passed"; \
		exit 1; \
	else \
		cat "$$doc_out"; \
		grep -q "governance-doc" "$$doc_out"; \
	fi; \
	echo "[ARCH-SOURCE-CONTRACT] RED fixtures failed as expected"

test: run red-fixtures

clean:
	@true
