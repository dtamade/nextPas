# nextpas.core.mem — 模块级测试入口
# 用法:
#   make test          — 运行所有测试
#   make test-fast     — 跳过 compile-gate 和慢速测试
#   make clean         — 清理所有构建产物
#   make list          — 列出所有测试项目

FPC ?= fpc
CORE_ROOT := ../..

# 所有测试子目录（按字母序）
ALL_TESTS := $(sort $(wildcard test_*))

# compile-gate 和平台特化测试（无运行时可执行文件）
COMPILE_GATE_TESTS := test_memory_map_compile_gate test_mem_secure_windows_compile_gate test_mem_cross_os_compile_gate
# 需要 NEXTPAS_TESTING 定义的测试
TESTING_FLAG_TESTS := test_oom test_platform_virtual test_shared_memory
# 可能在非特权环境失败的平台测试
PLATFORM_TESTS := test_platform_virtual test_shared_memory test_l0_dependency_boundaries test_allocator_crt

# 快速测试列表（排除 compile-gate 和平台测试）
FAST_TESTS := $(filter-out $(COMPILE_GATE_TESTS) $(PLATFORM_TESTS), $(ALL_TESTS))

.PHONY: test test-fast test-extended clean list help $(ALL_TESTS)

help:
	@echo "nextpas.core.mem test targets:"
	@echo "  make test       — 运行全部测试"
	@echo "  make test-fast  — 跳过 compile-gate 和平台测试"
	@echo "  make test-extended — kernel evidence set (scorecard+soak+cross-os+lane deps)"
	@echo "  make clean      — 清理所有构建产物"
	@echo "  make list       — 列出所有测试项目"

# Kernel evidence (not default lane_gate): Growing/scavenge + long-run + host compile.
test-extended:
	$(MAKE) -C test_usability_guardrails clean test
	$(MAKE) -C test_contract_matrix clean test
	$(MAKE) -C scorecard clean test RELEASE=1
	$(MAKE) -C test_soak clean test
	$(MAKE) -C test_mem_cross_os_compile_gate clean test

list:
	@echo "All test projects ($(words $(ALL_TESTS))):"
	@$(foreach t,$(ALL_TESTS),echo "  $(t)";)

test: $(ALL_TESTS)

test-fast: $(FAST_TESTS)

clean:
	@for d in $(ALL_TESTS); do \
	  $(MAKE) -C "$$d" clean 2>/dev/null || true; \
	done
	@echo "All build artifacts cleaned."

# 每个测试子目录的代理目标
$(ALL_TESTS):
	@$(MAKE) -C $@ test
