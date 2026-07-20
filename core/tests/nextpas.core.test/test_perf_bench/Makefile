PROGRAM := test_perf_bench
include ../../common.mk

# Optional regression gate (not part of default `test`):
#   make -C core/tests/nextpas.core.test/test_perf_bench regression
# Default threshold 30% (loose; pass as percent: 30)
.PHONY: regression save-baseline

BENCH_BIN := $(BUILD_DIR)/$(PROGRAM)
BASELINE  := $(CURDIR)/perf-baseline.json
THRESHOLD ?= 30

save-baseline: build
	$(BENCH_BIN) --save-baseline $(BASELINE)

regression: build
	@if [ ! -f "$(BASELINE)" ]; then \
	  echo "No $(BASELINE); generating once..."; \
	  $(BENCH_BIN) --save-baseline $(BASELINE); \
	  echo "Baseline generated — re-run regression to compare."; \
	  exit 0; \
	fi
	$(BENCH_BIN) --baseline $(BASELINE) --threshold $(THRESHOLD)
