# nextpas.core.lockfree module-level verify targets
# ======================================================
# verify-t1:     atomic + lockfree main suite + stress (R6 baseline)
# verify-h3-consumers: H3-3 consumer regression (does NOT replace verify-t1)
# verify-r8:     numa + rtm + formal research axes (opt-in; does NOT replace verify-t1)
#
# Prerequisite:
#   export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$$PATH"
#
# From repo root:
#   make -C core/tests/nextpas.core.lockfree verify-t1
#   make -C core/tests/nextpas.core.lockfree verify-h3-consumers
#   make -C core/tests/nextpas.core.lockfree verify-r8
#
# Default logs (under core/build, hygiene-ignored):
#   core/build/verify-lockfree/verify-t1.log
#   core/build/verify-lockfree/verify-h3-consumers.log
#   core/build/verify-lockfree/verify-r8.log

.PHONY: verify-t1 clean-verify-t1 verify-h3-consumers verify-r8

ATOMIC_TEST_DIR := ../nextpas.core.atomic/test_atomic
LOCKFREE_TEST_DIR := test_lockfree
STRESS_TEST_DIR := test_lockfree_stress
ASYNC_TEST_DIR := ../nextpas.core.async/test_async
BAG_TEST_DIR := test_lockfree_bag
MULTIMAP_TEST_DIR := test_lockfree_multimap
T1_CLOSE_JOIN_FREE_DIR := ../../examples/nextpas.core.lockfree/t1_close_join_free
NUMA_TEST_DIR := test_lockfree_numa
RTM_TEST_DIR := test_lockfree_rtm
FORMAL_TEST_DIR := test_lockfree_formal

VERIFY_LOG_DIR ?= ../../../build/verify-lockfree
VERIFY_T1_LOG ?= $(VERIFY_LOG_DIR)/verify-t1.log
VERIFY_H3_CONSUMERS_LOG ?= $(VERIFY_LOG_DIR)/verify-h3-consumers.log
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

# H3-3: cross-module + H3-2 Guarded subset consumer regression.
# Does not replace verify-t1. Covers:
#   - async.loop Post path uses T1 MPSC (H3-1 source-contract in test_async)
#   - bag / multimap H3-2 production contract pins
#   - H2-6 Close->join->Free example still builds and runs
verify-h3-consumers:
	@mkdir -p $(VERIFY_LOG_DIR)
	@echo "verify-h3-consumers: starting (log -> $(VERIFY_H3_CONSUMERS_LOG))"
	@set -euo pipefail; \
	{ \
	  echo "=== verify-h3-consumers $$(date -Iseconds) ==="; \
	  echo "=== which fpc ==="; \
	  command -v fpc; \
	  fpc -iV; \
	  echo "=== async H3-1 consumer (test_async) ==="; \
	  $(MAKE) -C $(ASYNC_TEST_DIR) clean test; \
	  echo "=== lockfree bag H3-2 ==="; \
	  $(MAKE) -C $(BAG_TEST_DIR) clean test; \
	  echo "=== lockfree multimap H3-2 ==="; \
	  $(MAKE) -C $(MULTIMAP_TEST_DIR) clean test; \
	  echo "=== t1_close_join_free example (H2-6) ==="; \
	  $(MAKE) -C $(T1_CLOSE_JOIN_FREE_DIR) clean test; \
	  echo "verify-h3-consumers-status=pass"; \
	} 2>&1 | tee $(VERIFY_H3_CONSUMERS_LOG)
	@echo "verify-h3-consumers-status=pass log=$(VERIFY_H3_CONSUMERS_LOG)"

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
