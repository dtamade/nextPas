FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.zip/bench_zip
PROGRAM := bench_zip
SOURCE := bench_zip.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O3 -Xs
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run test clean baseline regression

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

# 将当前 bench 结果固化为回归基线（需人工审查后提交）
baseline: run
	@cp $(CORE_ROOT)/build/bench-zip.json ./BASELINE.json
	@echo "baseline updated from $(CORE_ROOT)/build/bench-zip.json"

# 回归门：allocs 零容忍(+2抖动)，bytes 强一致，ns +50% 仅告警
regression: run
	@python3 ./check_regression.py

clean:
	rm -rf $(BUILD_DIR)
