include ../../bench_common.mk

# 数值单源：BASELINE.json 为阈值唯一真源，CONTRACT §6 仅定义公式
.PHONY: baseline regression run-compare compare

baseline: run
	@cp $(CORE_ROOT)/build/bench-tar.json ./BASELINE.json
	@echo "baseline updated from $(CORE_ROOT)/build/bench-tar.json"

regression: run
	@python3 ./check_regression.py

# 对照（CONTRACT §6）：Go archive/tar / Rust tar 同口径，GOMAXPROCS=1 降噪
run-compare:
	@echo "=== Go compare (archive/tar, GOMAXPROCS=1) ==="
	@GOMAXPROCS=1 go run ./compare_go || echo "go run failed (need go toolchain)"
	@echo "=== Rust compare (tar 0.4) ==="
	@cargo run --manifest-path compare_rust/Cargo.toml --release 2>&1 | tail -20 || rustc -C opt-level=3 compare_rust/main.rs -o /tmp/bench_tar_rust && /tmp/bench_tar_rust || echo "rust run failed (need rustc/cargo)"

compare: regression
	@python3 ./check_regression.py --with-compare
