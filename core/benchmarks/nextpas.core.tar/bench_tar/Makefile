include ../../bench_common.mk

# 数值单源：BASELINE.json 为阈值唯一真源，CONTRACT §6 仅定义公式
.PHONY: baseline regression

baseline: run
	@cp $(CORE_ROOT)/build/bench-tar.json ./BASELINE.json
	@echo "baseline updated from $(CORE_ROOT)/build/bench-tar.json"

regression: run
	@python3 ./check_regression.py
