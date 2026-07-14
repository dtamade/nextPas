# mem Scorecard SC1–SC5 (STDLIB-QUALITY-PLAN §7)
#
# Default: focused gate with heaptrc (correctness + repro under CI-like flags).
# For publishable numbers (closer to production):
#   make RELEASE=1 test

PROGRAM := scorecard
include ../../common.mk

ifdef RELEASE
FPC_FLAGS = -MObjFPC -Sh -O2 -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
endif

.PHONY: scorecard
scorecard: test
