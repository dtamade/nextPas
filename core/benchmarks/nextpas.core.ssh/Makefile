# nextpas.core.ssh benchmarks — 聚合层（design-conventions §12 基准组织）
# bench 位于 benchmarks/nextpas.core.ssh/bench_*，不污染 tests/

BENCHES := bench_ssh_cipher bench_ssh_proxyjump

.PHONY: all build run test smoke clean list $(BENCHES)

help:
	@echo "Targets: all | build | run | test | smoke | clean | list | $(BENCHES)"
	@echo "Example: make -C core/benchmarks/nextpas.core.ssh bench_ssh_cipher"

list:
	@for b in $(BENCHES); do echo $$b; done

all build run test smoke clean:
	@for b in $(BENCHES); do \
	  echo "== $$b: $@ =="; \
	  $(MAKE) -C $$b $@ || exit 1; \
	done

$(BENCHES):
	$(MAKE) -C $@ test
