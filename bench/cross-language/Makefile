# Cross-Language Sort Benchmark
#
# 对比 nextPas (Pascal)、Go、Rust、C 的排序性能。
# 所有语言使用相同算法、相同数据规模 (N=1000)、相同 PRNG 种子。

.PHONY: all pascal go rust c clean

all: pascal go rust c

# === Pascal (nextpas.core.bench) ===
pascal: build/bench_sort_pascal

build/bench_sort_pascal: bench_sort_comparison.pas | build
	fpc -O2 -gw -gl -Fu../../core/src -Fi../../core/src \
		-FUbuild -FEbuild bench_sort_comparison.pas \
		-obench_sort_pascal

# === Go ===
go: build/bench_sort_go.txt

build/bench_sort_go.txt: bench_sort_comparison.go | build
	cd build && go test -bench=Sort -benchmem -count=6 \
		../bench_sort_comparison.go > bench_sort_go.txt 2>&1 || \
		echo "Go not available — install golang-go"

# === Rust (criterion) ===
rust: build/bench_sort_rust.txt

build/bench_sort_rust.txt: bench_sort_comparison.rs | build
	@echo "Rust criterion requires cargo project setup"
	@echo "Run manually: cargo bench 2>&1 | tee build/bench_sort_rust.txt"

# === C ===
c: build/bench_sort_c

build/bench_sort_c: bench_sort_comparison.c | build
	gcc -O2 -o build/bench_sort_c bench_sort_comparison.c -lm

build:
	mkdir -p build

# === 运行 ===
run-pascal: pascal
	./build/bench_sort_pascal

run-go: go
	@cat build/bench_sort_go.txt

run-c: c
	./build/bench_sort_c

# === 对比 ===
compare: pascal c
	@echo "=== nextPas ==="
	@./build/bench_sort_pascal 2>/dev/null | grep -E 'ns/op'
	@echo ""
	@echo "=== C ==="
	@./build/bench_sort_c 2>/dev/null | grep -E 'ns/op'

clean:
	rm -rf build
