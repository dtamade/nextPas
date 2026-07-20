# 默认 gate：下列 22 项。test_test_bench_integration/ 为历史孤儿目录，不在此列表。
PROJECTS := test_bench_baseline test_bench_stats test_bench_stats_advanced \
            test_bench_runner test_bench_report test_bench_integration \
            test_bench_results_api \
            test_bench_parallel test_bench_parallel_heaptrc \
            test_bench_parallel_memtrack_heaptrc test_bench_memtrack \
            test_bench_xlang test_bench_invalid_parameters_heaptrc \
            test_bench_matrix test_bench_mannwhitney \
            test_bench_ks \
            test_bench_self_bench \
            test_bench_phase_b \
            test_bench_phase_c \
            test_bench_regression \
            test_bench_run \
            test_bench_adaptive_warmup

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
