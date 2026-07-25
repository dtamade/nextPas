# nextpas.core.test — Unified test runner
# =========================================================
# Usage:
#   make -C core/tests/nextpas.core.test contracts  # DEFAULT lane gate (api+runner+scale)
#   make -C core/tests/nextpas.core.test test       # run all suites (version land)
#   make -C core/tests/nextpas.core.test clean
#   make -C core/tests/nextpas.core.test list
#
# Focused / lane helper (same as contracts):
#   make focused FOCUS=core/tests/nextpas.core.test/lane_gate
#   make lane-focused LANE=test
#
# CI tip (strict goldens): export NEXTPAS_SNAPSHOT_FAIL_ON_CREATE=1
#   (committed goldens must exist; no auto-create of new snapshot files)

SUITES := $(sort $(notdir $(wildcard test_*)))

.PHONY: test clean list contracts

test:
	@echo "=== Running all nextpas.core.test suites ==="
	@failed=0; total=0; \
	for suite in $(SUITES); do \
	  total=$$((total + 1)); \
	  echo ""; \
	  echo "--- $$suite ---"; \
	  $(MAKE) -C $$suite clean test || { echo "FAIL: $$suite"; failed=$$((failed + 1)); }; \
	done; \
	echo ""; \
	echo "=== Results: $$((total - failed))/$$total suites passed ==="; \
	[ $$failed -eq 0 ]

contracts:
	@echo "=== nextpas.core.test contract gates ==="
	$(MAKE) -C test_api_source_contracts test
	$(MAKE) -C test_runner_source_contracts test
	$(MAKE) -C test_scale_report test
	@echo "=== contract gates: PASS ==="

clean:
	@for suite in $(SUITES); do \
	  $(MAKE) -C $$suite clean 2>/dev/null; \
	done

list:
	@echo "Test suites in nextpas.core.test:"
	@for suite in $(SUITES); do \
	  echo "  $$suite"; \
	done
