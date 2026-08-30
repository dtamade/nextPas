BENCH_ROOT := ..
BUILD_DIRS := $(wildcard $(BENCH_ROOT)/bench_*/build)
THRESHOLD ?= 10

.PHONY: check run clean

check:
	@echo "[bench_regression] threshold $(THRESHOLD)% p50 check"
	@python3 $(CURDIR)/check_regression.py --threshold $(THRESHOLD)

run: check

clean:
	@echo "[bench_regression] nothing to clean"
