# nextpas.core.io.buffer benchmarks
# 聚合层不做构建复刻——逐门转发到各自 Makefile(bench_common.mk 提供目标)

BENCHES := bench_readbyte

.PHONY: all build run test smoke clean list $(BENCHES)

help:
	@echo "Targets: all | build | run | test | smoke | clean | list | $(BENCHES)"
	@echo "Example: make -C core/benchmarks/nextpas.core.io.buffer bench_readbyte"

list:
	@for b in $(BENCHES); do echo $$b; done

all build run test smoke clean:
	@for b in $(BENCHES); do \
	  echo "== $$b: $@ =="; \
	  $(MAKE) -C $$b $@ || exit 1; \
	done

$(BENCHES):
	$(MAKE) -C $@ test
