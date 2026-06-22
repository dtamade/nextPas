MAKEFLAGS += --no-print-directory

FPC = fpc
FPCFLAGS = -MObjFPC -Sh -O2 -gw -gl

SRCDIR = ../../src

.PHONY: all clean test

all: build/bin/bench_overhead build/bin/bench_stats build/bin/bench_report

build/bin/bench_overhead: bench_overhead/bench_overhead.lpr
	@mkdir -p build/bin build/obj
	$(FPC) $(FPCFLAGS) -Fubuild/obj -FEbuild/bin -Fu$(SRCDIR) -Fi$(SRCDIR) $<

build/bin/bench_stats: bench_stats/bench_stats.lpr
	@mkdir -p build/bin build/obj
	$(FPC) $(FPCFLAGS) -Fubuild/obj -FEbuild/bin -Fu$(SRCDIR) -Fi$(SRCDIR) $<

build/bin/bench_report: bench_report/bench_report.lpr
	@mkdir -p build/bin build/obj
	$(FPC) $(FPCFLAGS) -Fubuild/obj -FEbuild/bin -Fu$(SRCDIR) -Fi$(SRCDIR) $<

clean:
	rm -rf build

test: all
	@echo "=== Running bench_overhead ==="
	@build/bin/bench_overhead
	@echo
	@echo "=== Running bench_stats ==="
	@build/bin/bench_stats
	@echo
	@echo "=== Running bench_report ==="
	@build/bin/bench_report
