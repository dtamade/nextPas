# core/benchmarks/bench_common.mk — 基准工程共享构建模板
#
# 复用约定：一个计时基准目录只需要一行 Makefile：
#
#   # 可选覆盖（不写则全部按约定自动推导）：
#   #   BENCH_PROGRAM := <程序名>          缺省 = 目录名
#   #   BENCH_SOURCE  := <入口 .lpr>       缺省 = $(BENCH_PROGRAM).lpr
#   #   FPC_FLAGS     := <完整编译旗标>    缺省 = 计时保真档（-O3 -Xs，无 heaptrc）
#   include ../../bench_common.mk
#
# 推导规则（与既有手写模板逐字等价）：
#   - 模块名/门名取自所在目录：<benchmarks>/<module>/<gate>/
#   - 产物统一落在 core/build/projects/<module>/<gate>/，不污染源码树
#   - 单元搜索路径含 core/src 与 core/build/lib

# 从本文件自身位置反推 core 根（本文件位于 core/benchmarks/），门内无需手写相对深度
BENCH_COMMON_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
CORE_ROOT ?= $(BENCH_COMMON_DIR)/..

BENCH_MODULE := $(notdir $(patsubst %/,%,$(dir $(CURDIR))))
BENCH_GATE := $(notdir $(CURDIR))

FPC ?= fpc
BENCH_PROGRAM ?= $(BENCH_GATE)
BENCH_SOURCE ?= $(BENCH_PROGRAM).lpr
BUILD_DIR ?= $(CORE_ROOT)/build/projects/$(BENCH_MODULE)/$(BENCH_GATE)

# 计时保真：默认无 heaptrc、全量优化；个别基准可自行覆盖 FPC_FLAGS
FPC_FLAGS ?= -MObjFPC -Sh -O3 -Xs
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run test smoke clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(BENCH_SOURCE)

run: build
	$(BUILD_DIR)/$(BENCH_PROGRAM)

test: run

# 快速冒烟：压低迭代数/采样数/最短时长三个耗时项，用于提交前自检
smoke: build
	NEXTPAS_BENCH_MAX_ITERS=$${NEXTPAS_BENCH_MAX_ITERS:-20000} \
	NEXTPAS_BENCH_MIN_SAMPLES=$${NEXTPAS_BENCH_MIN_SAMPLES:-5} \
	NEXTPAS_BENCH_MIN_DURATION=$${NEXTPAS_BENCH_MIN_DURATION:-1000} \
	$(BUILD_DIR)/$(BENCH_PROGRAM)

clean:
	rm -rf $(BUILD_DIR)
