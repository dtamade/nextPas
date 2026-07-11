# nextpas.core.test — Unified test runner
# =========================================================
# Usage:
#   make -C core/tests/nextpas.core.test test    # run all suites
#   make -C core/tests/nextpas.core.test clean   # clean all build artifacts
#   make -C core/tests/nextpas.core.test list    # list all suites

SUITES := $(sort $(notdir $(wildcard test_*)))

.PHONY: test clean list

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

clean:
	@for suite in $(SUITES); do \
	  $(MAKE) -C $$suite clean 2>/dev/null; \
	done

list:
	@echo "Test suites in nextpas.core.test:"
	@for suite in $(SUITES); do \
	  echo "  $$suite"; \
	done
