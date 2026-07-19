# tui Scorecard SC1–SC5 (PARITY-GO-RUST Wave Q1)
#
# Default: focused gate with heaptrc.
# Publishable numbers: make RELEASE=1 test

PROGRAM := scorecard
include ../../common.mk

ifdef RELEASE
FPC_FLAGS = -MObjFPC -Sh -O2 -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
endif

.PHONY: scorecard
scorecard: test
