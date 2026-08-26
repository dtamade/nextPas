# common.mk — shared build rules for nextpas.core test fixtures
# =========================================================
# Usage in your Makefile:
#   PROGRAM := test_base
#   include ../../common.mk
#   FPC_FLAGS += -B           (optional extra flags AFTER include)
#
# Optional Wine smoke (not real Windows runtime evidence):
#   make wine-runtime-smoke
# Requires fpc -Twin64 (ppcrossx64 under FPC units) and wine on PATH.

FPC ?= fpc
WINE ?= wine

CORE_ROOT   := ../../..
MODULE_NAME := $(notdir $(abspath $(CURDIR)/..))
TEST_NAME   := $(notdir $(abspath $(CURDIR)))

PROGRAM ?= test_program
SOURCE  ?= $(PROGRAM).lpr

BUILD_DIR ?= $(CORE_ROOT)/build/projects/$(MODULE_NAME)/$(TEST_NAME)
WINE_BUILD_DIR ?= $(BUILD_DIR)_wine_win64

# -Sg: LABEL/GOTO used by mem/http/json ports; do not rely on host fpc.cfg.
BASE_FPC_FLAGS ?= -MObjFPC -Sh -Sg -O2 -gl -gh -dHEAPTRC_ACTIVE
FPC_FLAGS = $(BASE_FPC_FLAGS) -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/tests/shared
WINE_FPC_FLAGS ?= $(BASE_FPC_FLAGS) -Twin64 -Px86_64
WINE_FPC_FLAGS += -FU$(WINE_BUILD_DIR) -FE$(WINE_BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/tests/shared

.PHONY: build run test clean clean-src wine-build wine-runtime-smoke

clean-src:
	@find $(CORE_ROOT)/src -maxdepth 1 -type f \( -name '*.ppu' -o -name '*.o' \) -delete 2>/dev/null || true

build: clean-src
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

# Leak gate: default-ON for every suite built via this file (staged
# defaulting complete — phase 1 covered the TUI subtree 2026-08-25, phase 2
# extends the default to all modules once the TRegex design debt was
# cleared). Opt out per invocation with HEAPTRC_GATE= (empty) or
# HEAPTRC_GATE=0; opt back in explicitly with HEAPTRC_GATE=1.
# The heaptrc exit dump is not a dependable leak signal on FPC trunk
# 3.3.1: it goes through the StdErr text record, which gets a flush-per-
# write FlushFunc only when the handle is a device (pipe/tty deliver it,
# verified with controlled probes incl. an empty program); redirected to
# a regular file the record is buffered and nothing flushes it at exit —
# small dumps vanish whole, large ones truncate at buffer boundaries.
# Grep-based leak checks therefore fail closed here instead. The env
# channels are reliable: haltonnotreleased turns unfreed blocks into exit
# code 203, log= writes the dump to a file (heaptrc closes its own file).
# The dump pins below also fail closed when heaptrc did not run at all.
HEAPTRC_GATE ?= 1
# Resolve at the consumer, not by reassignment: a command-line HEAPTRC_GATE=0
# outranks any makefile assignment, so "0" must read as off where it is used.
HEAPTRC_ENABLED := $(HEAPTRC_GATE)
ifeq ($(HEAPTRC_GATE),0)
HEAPTRC_ENABLED :=
endif
HEAPTRC_DUMP ?= $(BUILD_DIR)/$(PROGRAM).heaptrc

# Optional extra environment for the test process (P5l): suites that need
# fixture wiring (e.g. NEXTPAS_PG_TEST_CONN for local-postgres db suites)
# set RUN_ENV after the include; empty by default.
RUN_ENV ?=

run: build
	@if [ -n "$(HEAPTRC_ENABLED)" ]; then \
		rm -f $(HEAPTRC_DUMP); \
		HEAPTRC='haltonnotreleased,log=$(HEAPTRC_DUMP)' $(RUN_ENV) $(BUILD_DIR)/$(PROGRAM); \
		grep -q '^Heap dump by heaptrc unit' $(HEAPTRC_DUMP) || { echo "[HEAPTRC] FAILED: no heap dump written ($(HEAPTRC_DUMP))"; exit 1; }; \
		grep -q '^0 unfreed memory blocks : 0$$' $(HEAPTRC_DUMP) || { echo "[HEAPTRC] FAILED: unfreed blocks reported"; cat $(HEAPTRC_DUMP); exit 1; }; \
		echo "[HEAPTRC] OK"; \
	else \
		$(RUN_ENV) $(BUILD_DIR)/$(PROGRAM); \
	fi

# * _wine / Windows-only-symbol 测试：WINE_ONLY_TEST=1 时 test 目标走
#   wine-runtime-smoke（需 wine），无 wine 则 skip，避免 Linux 宿主编译引用
#   Windows-only 符号或平台断言误报。WINE_ONLY_TEST 须在 include 前定义。
ifeq ($(WINE_ONLY_TEST),1)
test:
	@command -v $(WINE) >/dev/null 2>&1 || { echo "wine not available; skip"; exit 0; }
	$(MAKE) wine-runtime-smoke
else
test: run
endif

# Cross-compile to Win64 PE. truth tier remains wine-runtime-smoke when executed under Wine.
wine-build: clean-src
	@mkdir -p $(WINE_BUILD_DIR)
	$(FPC) $(WINE_FPC_FLAGS) $(SOURCE)

wine-runtime-smoke: wine-build
	@command -v $(WINE) >/dev/null 2>&1 || { \
	  echo "wine-runtime-smoke requires Wine; this is not real Windows runtime evidence"; \
	  exit 2; \
	}
	@echo "truth=wine-runtime-smoke; not real Windows runtime ready"
	$(WINE) $(WINE_BUILD_DIR)/$(PROGRAM).exe

clean: clean-src
	rm -rf $(BUILD_DIR) $(WINE_BUILD_DIR)
