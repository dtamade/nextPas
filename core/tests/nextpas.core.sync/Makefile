# nextpas.core.sync — 模块级测试入口
# 用法:
#   make test    — 运行全部 gate
#   make clean   — 清理子项目构建产物
#   make list    — 列出 gate

ALL_TESTS := test_sync test_sync_pool test_sync_source_contracts \
	test_sync_windows_compile_gate test_sync_darwin_compile_gate \
	test_sync_freebsd_compile_gate test_sync_android_compile_gate

.PHONY: test clean list help $(ALL_TESTS)

help:
	@echo "nextpas.core.sync test targets:"
	@echo "  make test   — 运行全部 gate"
	@echo "  make clean  — 清理构建产物"
	@echo "  make list   — 列出 gate"

list:
	@echo "Gates ($(words $(ALL_TESTS))):"
	@$(foreach t,$(ALL_TESTS),echo "  $(t)";)

test: $(ALL_TESTS)

clean:
	@$(foreach t,$(ALL_TESTS),$(MAKE) -C $(t) clean;)

$(ALL_TESTS):
	$(MAKE) -C $@ test
