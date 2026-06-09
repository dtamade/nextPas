PYTHON ?= python3
CORE_ROOT := ../../..
SCRIPT := check_architecture_source_contracts.py
REGISTRY := architecture_contract_registry.json
FIXTURE_ROOT := fixtures/red

.PHONY: build run module-registry-audit dependency-boundary-audit host-raw-ffi-audit red-fixtures test clean

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

red-fixtures: build
	@set -e; \
	l0_out=$$(mktemp); \
	raw_out=$$(mktemp); \
	trap 'rm -f "$$l0_out" "$$raw_out"' EXIT HUP INT TERM; \
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
	echo "[ARCH-SOURCE-CONTRACT] RED fixtures failed as expected"

test: run red-fixtures

clean:
	@true
