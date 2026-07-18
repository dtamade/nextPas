# nextpas.core.lockfree module-level verify targets (R6 + R8 opt-in)
# ======================================================
# One-shot T1 gate: atomic + lockfree main suite + stress.
# Optional R8 research gate: numa + rtm + formal (does NOT replace verify-t1).
#
# Prerequisite:
#   export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$$PATH"
#
# From repo root:
#   make -C core/tests/nextpas.core.lockfree verify-t1
#   make -C core/tests/nextpas.core.lockfree verify-r8
#
# Default logs (under core/build, hygiene-ignored):
#   core/build/verify-lockfree/verify-t1.log
#   core/build/verify-lockfree/verify-r8.log

.PHONY: verify-t1 clean-verify-t1 verify-r8

ATOMIC_TEST_DIR := ../nextpas.core.atomic/test_atomic
LOCKFREE_TEST_DIR := test_lockfree
STRESS_TEST_DIR := test_lockfree_stress
NUMA_TEST_DIR := test_lockfree_numa
RTM_TEST_DIR := test_lockfree_rtm
FORMAL_TEST_DIR := test_lockfree_formal

VERIFY_LOG_DIR ?= ../../../build/verify-lockfree
VERIFY_T1_LOG ?= $(VERIFY_LOG_DIR)/verify-t1.log
VERIFY_R8_LOG ?= $(VERIFY_LOG_DIR)/verify-r8.log

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

# R8 research axes only (Experimental). Does not promote to T1 / default facade.
verify-r8:
	@mkdir -p $(VERIFY_LOG_DIR)
	@echo "verify-r8: starting (log -> $(VERIFY_R8_LOG))"
	@set -euo pipefail; \
	{ \
	  echo "=== verify-r8 $$(date -Iseconds) ==="; \
	  echo "=== which fpc ==="; \
	  command -v fpc; \
	  fpc -iV; \
	  echo "=== lockfree numa ==="; \
	  $(MAKE) -C $(NUMA_TEST_DIR) clean test; \
	  echo "=== lockfree rtm ==="; \
	  $(MAKE) -C $(RTM_TEST_DIR) clean test; \
	  echo "=== lockfree formal ==="; \
	  $(MAKE) -C $(FORMAL_TEST_DIR) clean test; \
	  echo "verify-r8-status=pass"; \
	} 2>&1 | tee $(VERIFY_R8_LOG)
	@echo "verify-r8-status=pass log=$(VERIFY_R8_LOG)"

clean-verify-t1:
	rm -rf $(VERIFY_LOG_DIR)
