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

# 构建阶段重试一次：host fpc (trunk) 偶发 "Can't find unit"（见 docs/bench/findings.md F-27）。
# 真编译回归会连挂两次仍红；运行期失败不重试，保持严格。
# 末尾汇总行保证输出被截断（tail/分页）时失败套件与阶段(build/run)仍可取证。
test:
	@status=0; failed=""; \
	for project in $(PROJECTS); do \
		echo "=== $$project ==="; \
		if ! $(MAKE) -C $$project clean all; then \
			echo "[BUILD-FLAKE-RETRY] $$project build failed; retrying once"; \
			if ! $(MAKE) -C $$project clean all; then \
				status=1; failed="$$failed $$project(build)"; \
				echo ""; \
				continue; \
			fi; \
		fi; \
		if ! $(MAKE) -C $$project test; then \
			status=1; failed="$$failed $$project(run)"; \
		fi; \
		echo ""; \
	done; \
	if [ -n "$$failed" ]; then \
		echo "[GATE-FAILED-SUITES]$$failed"; \
	else \
		echo "[GATE-ALL-GREEN] $(words $(PROJECTS)) suites"; \
	fi; \
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
