# db 基准手动门禁（V3-C4）
# =============================================
# 用法：make -C core/benchmarks/nextpas.core.db bench
#
# 设计约束：
# - 不接入根 Makefile verify/test 链——环境噪声隔离（roadmap C4），
#   基准数字只作防回归参考与口径入册，不作 CI 判据。
# - 编译不带 -gh/-gh heaptrc：插桩会扭曲计时。
# - pg 段由各程序内部按 NEXTPAS_PG_TEST_CONN 自门控，缺席自动 skip。

FPC ?= fpc
CORE_ROOT := ../..
BUILD_DIR ?= $(CORE_ROOT)/build/benchmarks/nextpas.core.db
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

BENCHES := \
	bench_db_adapter_overhead \
	bench_db_translate_complexity \
	bench_db_batch_insert \
	bench_db_bulk_copy \
	bench_db_stmt_cache \
	bench_db_blob_stream \
	bench_db_pool_stress \
	bench_db_async \
	bench_db_listen \
	bench_db_wallet \
	bench_db_dm_adapter \
	bench_db_dm_live

.PHONY: bench $(BENCHES) clean

bench: $(BENCHES)

$(BENCHES):
	@mkdir -p $(BUILD_DIR)
	@$(FPC) $(FPC_FLAGS) $@.lpr 2>&1 | tail -1
	@echo "===== $@ ====="
	@$(BUILD_DIR)/$@

clean:
	rm -rf $(BUILD_DIR)
