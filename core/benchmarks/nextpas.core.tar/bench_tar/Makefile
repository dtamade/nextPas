include ../../bench_common.mk

# 数值单源：BASELINE.json 为阈值唯一真源，CONTRACT §6 仅定义公式
.PHONY: baseline regression run-compare compare

baseline: run
	@cp $(CORE_ROOT)/build/bench-tar.json ./BASELINE.json
	@echo "baseline updated from $(CORE_ROOT)/build/bench-tar.json"

regression: run run-compare
	@python3 ./check_regression.py --with-compare

# 对照（CONTRACT §6 CI 硬红，缺失即硬红）：Go archive/tar / Rust tar 同口径，GOMAXPROCS=1 降噪
# hygiene：cargo target 重定向至 build/（hygiene 豁免区），不污染源码树
run-compare:
	@echo "=== Go compare (archive/tar, GOMAXPROCS=1) ==="
	@cd compare_go && GOMAXPROCS=1 go run . || echo "go run failed (need go toolchain)"
	@echo "=== Rust compare (tar 0.4) ==="
	@cd compare_rust && CARGO_TARGET_DIR=../build/cargo-target cargo run --release 2>&1 | tail -5 || echo "cargo run failed (need rustc/cargo)"

compare: regression
	@python3 ./check_regression.py --with-compare
