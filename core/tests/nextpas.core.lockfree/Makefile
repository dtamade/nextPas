# nextpas.core.lockfree module-level verify targets (R6)
# ======================================================
# One-shot T1 gate: atomic + lockfree main suite + stress.
#
# Prerequisite:
#   export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$$PATH"
#
# From repo root:
#   make -C core/tests/nextpas.core.lockfree verify-t1
#
# Default log (under core/build, hygiene-ignored):
#   core/build/verify-lockfree/verify-t1.log

.PHONY: verify-t1 clean-verify-t1

ATOMIC_TEST_DIR := ../nextpas.core.atomic/test_atomic
LOCKFREE_TEST_DIR := test_lockfree
STRESS_TEST_DIR := test_lockfree_stress

VERIFY_LOG_DIR ?= ../../../build/verify-lockfree
VERIFY_T1_LOG ?= $(VERIFY_LOG_DIR)/verify-t1.log

verify-t1:
	@mkdir -p $(VERIFY_LOG_DIR)
	@echo "verify-t1: starting (log -> $(VERIFY_T1_LOG))"
	@set -euo pipefail; \
	{ \
	  echo "=== verify-t1 $$(date -Iseconds) ==="; \
	  echo "=== which fpc ==="; \
	  command -v fpc; \
	  fpc -iV; \
	  echo "=== atomic ==="; \
	  $(MAKE) -C $(ATOMIC_TEST_DIR) clean test; \
	  echo "=== lockfree main ==="; \
	  $(MAKE) -C $(LOCKFREE_TEST_DIR) clean test; \
	  echo "=== lockfree stress ==="; \
	  $(MAKE) -C $(STRESS_TEST_DIR) clean test; \
	  echo "verify-t1-status=pass"; \
	} 2>&1 | tee $(VERIFY_T1_LOG)
	@echo "verify-t1-status=pass log=$(VERIFY_T1_LOG)"

clean-verify-t1:
	rm -rf $(VERIFY_LOG_DIR)
