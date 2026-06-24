MAKEFLAGS += --no-print-directory

# nextpas.core.bench 聚合基准入口
# 用法:
#   make bench          — 运行所有 bench 自身基准
#   make bench-json     — 运行并输出 JSON 基线到 build/baselines/
#   make clean          — 清理所有构建产物

FPC ?= fpc
FPCFLAGS = -MObjFPC -Sh -O2 -gw -gl
SRCDIR := ../src
BASELINE_DIR := build/baselines

# bench 模块自身的基准测试
BENCH_PROJECTS := nextpas.core.bench

.PHONY: bench bench-json clean $(BENCH_PROJECTS)

bench: $(BENCH_PROJECTS)

bench-json: $(BENCH_PROJECTS)
	@echo "JSON baselines saved to $(BASELINE_DIR)/"

$(BENCH_PROJECTS):
	@echo "=== $@ ==="
	@$(MAKE) -C $@ test
	@echo

# 聚合 JSON 基线：从各子项目的 build/baselines/ 收集
collect-baselines:
	@mkdir -p $(BASELINE_DIR)
	@for dir in $(BENCH_PROJECTS); do \
		if [ -d "$$dir/build/baselines" ]; then \
			cp "$$dir/build/baselines/"*.json $(BASELINE_DIR)/ 2>/dev/null || true; \
		fi; \
	done
	@echo "Collected baselines:"
	@ls -la $(BASELINE_DIR)/ 2>/dev/null || echo "  (none)"

clean:
	@for dir in $(BENCH_PROJECTS); do \
		[ ! -d "$$dir" ] || $(MAKE) -C $$dir clean; \
	done
	rm -rf $(BASELINE_DIR)
