# nextpas.core.lockfree module-level verify targets
# ======================================================
# verify-t1:     atomic + lockfree main suite + stress (R6 baseline)
# verify-h3-consumers: H3-3 consumer regression (does NOT replace verify-t1)
# verify-t2-smoke: curated T2 gates + test RTL isolation (F-006; does NOT replace t1)
# verify-r8:     numa + rtm + formal research axes (opt-in; does NOT replace verify-t1)
#
# Prerequisite:
#   export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$$PATH"
#
# From repo root:
#   make -C core/tests/nextpas.core.lockfree verify-t1
#   make -C core/tests/nextpas.core.lockfree verify-h3-consumers
#   make -C core/tests/nextpas.core.lockfree verify-t2-smoke
#   make -C core/tests/nextpas.core.lockfree verify-r8
#
# Default logs (under core/build, hygiene-ignored):
#   core/build/verify-lockfree/verify-t1.log
#   core/build/verify-lockfree/verify-h3-consumers.log
#   core/build/verify-lockfree/verify-t2-smoke.log
#   core/build/verify-lockfree/verify-r8.log

.PHONY: verify-t1 clean-verify-t1 verify-h3-consumers verify-t2-smoke verify-r8 test-rtl-isolation

ATOMIC_TEST_DIR := ../nextpas.core.atomic/test_atomic
LOCKFREE_TEST_DIR := test_lockfree
STRESS_TEST_DIR := test_lockfree_stress
ASYNC_TEST_DIR := ../nextpas.core.async/test_async
BAG_TEST_DIR := test_lockfree_bag
MULTIMAP_TEST_DIR := test_lockfree_multimap
T1_CLOSE_JOIN_FREE_DIR := ../../examples/nextpas.core.lockfree/t1_close_join_free
T1_SEGQUEUE_WORKERS_DIR := ../../examples/nextpas.core.lockfree/t1_segqueue_workers
T2_BAG_CLOSE_JOIN_FREE_DIR := ../../examples/nextpas.core.lockfree/t2_bag_close_join_free
T2_MULTIMAP_CLOSE_JOIN_FREE_DIR := ../../examples/nextpas.core.lockfree/t2_multimap_close_join_free
T1_MSQUEUE_CLOSE_JOIN_FREE_DIR := ../../examples/nextpas.core.lockfree/t1_msqueue_close_join_free
T2_HASHMAP_JOIN_FREE_DIR := ../../examples/nextpas.core.lockfree/t2_hashmap_join_free
THREAD_TEST_DIR := ../nextpas.core.thread/test_thread
WORKSTEAL_TEST_DIR := ../nextpas.core.thread/test_worksteal
NET_SERVER_TEST_DIR := ../nextpas.core.net.server/test_net_server
NUMA_TEST_DIR := test_lockfree_numa
RTM_TEST_DIR := test_lockfree_rtm
FORMAL_TEST_DIR := test_lockfree_formal
# F-006 curated T2 smoke (not full T2 inventory)
T2_SMOKE_TDIGEST := test_lockfree_tdigest
T2_SMOKE_CRDT := test_lockfree_crdt
T2_SMOKE_COWARRAY := test_lockfree_cowarray
T2_SMOKE_SORTEDSET := test_lockfree_sortedset
T2_SMOKE_COUNTER := test_lockfree_counter
T2_SMOKE_BLOOM := test_lockfree_bloom
T2_SMOKE_RINGBUFFER := test_lockfree_ringbuffer
T2_SMOKE_MUTEX := test_lockfree_mutex

VERIFY_LOG_DIR ?= ../../../build/verify-lockfree
VERIFY_T1_LOG ?= $(VERIFY_LOG_DIR)/verify-t1.log
VERIFY_H3_CONSUMERS_LOG ?= $(VERIFY_LOG_DIR)/verify-h3-consumers.log
VERIFY_T2_SMOKE_LOG ?= $(VERIFY_LOG_DIR)/verify-t2-smoke.log
VERIFY_R8_LOG ?= $(VERIFY_LOG_DIR)/verify-r8.log

test-rtl-isolation:
	@bash ./check_test_rtl_isolation.sh

verify-t1:
	@mkdir -p $(VERIFY_LOG_DIR)
	@echo "verify-t1: starting (log -> $(VERIFY_T1_LOG))"
	@set -euo pipefail; \
	{ \
	  echo "=== verify-t1 $$(date -Iseconds) ==="; \
	  echo "=== which fpc ==="; \
	  command -v fpc; \
	  fpc -iV; \
	  echo "=== test/example RTL isolation (F-001) ==="; \
	  bash ./check_test_rtl_isolation.sh; \
	  echo "=== atomic ==="; \
	  $(MAKE) -C $(ATOMIC_TEST_DIR) clean test; \
	  echo "=== lockfree main ==="; \
	  $(MAKE) -C $(LOCKFREE_TEST_DIR) clean test; \
	  echo "=== lockfree stress ==="; \
	  $(MAKE) -C $(STRESS_TEST_DIR) clean test; \
	  echo "verify-t1-status=pass"; \
	} 2>&1 | tee $(VERIFY_T1_LOG)
	@echo "verify-t1-status=pass log=$(VERIFY_T1_LOG)"

# Curated T2 smoke + RTL isolation. Does not run all ~90 T2 dirs.
verify-t2-smoke:
	@mkdir -p $(VERIFY_LOG_DIR)
	@echo "verify-t2-smoke: starting (log -> $(VERIFY_T2_SMOKE_LOG))"
	@set -euo pipefail; \
	{ \
	  echo "=== verify-t2-smoke $$(date -Iseconds) ==="; \
	  echo "=== which fpc ==="; \
	  command -v fpc; \
	  fpc -iV; \
	  echo "=== test RTL isolation ==="; \
	  bash ./check_test_rtl_isolation.sh; \
	  echo "=== T2 tdigest ==="; \
	  $(MAKE) -C $(T2_SMOKE_TDIGEST) clean test; \
	  echo "=== T2 crdt ==="; \
	  $(MAKE) -C $(T2_SMOKE_CRDT) clean test; \
	  echo "=== T2 cowarray ==="; \
	  $(MAKE) -C $(T2_SMOKE_COWARRAY) clean test; \
	  echo "=== T2 sortedset ==="; \
	  $(MAKE) -C $(T2_SMOKE_SORTEDSET) clean test; \
	  echo "=== T2 counter ==="; \
	  $(MAKE) -C $(T2_SMOKE_COUNTER) clean test; \
	  echo "=== T2 bloom ==="; \
	  $(MAKE) -C $(T2_SMOKE_BLOOM) clean test; \
	  echo "=== T2 ringbuffer ==="; \
	  $(MAKE) -C $(T2_SMOKE_RINGBUFFER) clean test; \
	  echo "=== T2 mutex ==="; \
	  $(MAKE) -C $(T2_SMOKE_MUTEX) clean test; \
	  echo "verify-t2-smoke-status=pass"; \
	} 2>&1 | tee $(VERIFY_T2_SMOKE_LOG)
	@echo "verify-t2-smoke-status=pass log=$(VERIFY_T2_SMOKE_LOG)"

# H3-3 (+ H4/H3-5 widen): cross-module + H3-2 Guarded subset consumer regression.
# Does not replace verify-t1. Covers:
#   - async.loop Post path uses T1 MPSC (H3-1 source-contract in test_async)
#   - bag / multimap H3-2 production contract pins
#   - H2-6 Close->join->Free examples (Channel + SegQueue + Bag + MSQueue)
#   - HashMap Close → join → Free (Charter C; T1 facade)
#   - H4-1 thread.pool → T1 SegQueue (test_thread source-contract)
#   - H3-5 thread.pool.worksteal → T1 deque (test_worksteal)
#   - H5-1 net poll completion → T1 MPSC (test_net_server source-contract)
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
	  echo "=== t1_close_join_free example (H2-6 Channel) ==="; \
	  $(MAKE) -C $(T1_CLOSE_JOIN_FREE_DIR) clean test; \
	  echo "=== t1_segqueue_workers example (SegQueue N-worker lifecycle) ==="; \
	  $(MAKE) -C $(T1_SEGQUEUE_WORKERS_DIR) clean test; \
	  echo "=== t1_msqueue_close_join_free example (T1 MSQueue lifecycle) ==="; \
	  $(MAKE) -C $(T1_MSQUEUE_CLOSE_JOIN_FREE_DIR) clean test; \
	  echo "=== t2_bag_close_join_free example (H3-2 Bag lifecycle) ==="; \
	  $(MAKE) -C $(T2_BAG_CLOSE_JOIN_FREE_DIR) clean test; \
	  echo "=== t2_multimap_close_join_free example (H3-2 MultiMap lifecycle) ==="; \
	  $(MAKE) -C $(T2_MULTIMAP_CLOSE_JOIN_FREE_DIR) clean test; \
	  echo "=== t2_hashmap_join_free example (HashMap Close→join→Free, Charter C) ==="; \
	  $(MAKE) -C $(T2_HASHMAP_JOIN_FREE_DIR) clean test; \
	  echo "=== H4-1 thread.pool SegQueue consumer (test_thread) ==="; \
	  $(MAKE) -C $(THREAD_TEST_DIR) clean test; \
	  echo "=== H3-5 worksteal deque consumer (test_worksteal) ==="; \
	  $(MAKE) -C $(WORKSTEAL_TEST_DIR) clean test; \
	  echo "=== H5-1 net completion MPSC consumer (test_net_server) ==="; \
	  $(MAKE) -C $(NET_SERVER_TEST_DIR) clean test; \
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
