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

# Opt-in leak gate (HEAPTRC_GATE=1, e.g. as a sub-make argument): FPC trunk
# 3.3.1 never delivers the heaptrc exit dump to the console, so grepping test
# output for leaks is vacuous. The env channels still work: haltonnotreleased
# turns unfreed blocks into exit code 203, log= writes the dump to a file. The
# dump pins below also fail closed when heaptrc did not run at all.
HEAPTRC_GATE ?=
HEAPTRC_DUMP ?= $(BUILD_DIR)/$(PROGRAM).heaptrc

run: build
	@if [ -n "$(HEAPTRC_GATE)" ]; then \
		rm -f $(HEAPTRC_DUMP); \
		HEAPTRC='haltonnotreleased,log=$(HEAPTRC_DUMP)' $(BUILD_DIR)/$(PROGRAM); \
		grep -q '^Heap dump by heaptrc unit' $(HEAPTRC_DUMP) || { echo "[HEAPTRC] FAILED: no heap dump written ($(HEAPTRC_DUMP))"; exit 1; }; \
		grep -q '^0 unfreed memory blocks : 0$$' $(HEAPTRC_DUMP) || { echo "[HEAPTRC] FAILED: unfreed blocks reported"; cat $(HEAPTRC_DUMP); exit 1; }; \
		echo "[HEAPTRC] OK"; \
	else \
		$(BUILD_DIR)/$(PROGRAM); \
	fi

test: run

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
