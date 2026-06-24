PROJECTS := test_bench_baseline test_bench_stats test_bench_stats_advanced \
            test_bench_runner test_bench_report test_bench_integration \
            test_bench_parallel test_bench_parallel_heaptrc \
            test_bench_parallel_memtrack_heaptrc test_bench_memtrack \
            test_bench_xlang test_bench_invalid_parameters_heaptrc

.PHONY: test clean bench $(PROJECTS)

test:
	@status=0; \
	for project in $(PROJECTS); do \
		echo "=== $$project ==="; \
		if ! $(MAKE) -C $$project clean test; then \
			status=1; \
		fi; \
		echo ""; \
	done; \
	exit $$status

bench:
	@$(MAKE) -C ../../benchmarks/nextpas.core.bench test

clean:
	@for project in $(PROJECTS); do \
		[ ! -d "$$project" ] || $(MAKE) -C $$project clean; \
	done
	@$(MAKE) -C ../../benchmarks/nextpas.core.bench clean 2>/dev/null || true

$(PROJECTS):
	$(MAKE) -C $@ test
