FPC_FLAGS  := -O3 -CX -XX -Xs -dRELEASE -Fi../../core/src -Fu../../core/src -Fu/opt/fpcupdeluxe/fpc/units/x86_64-linux/rtl -Fu../../units/linux-x86_64 -Fi../../units/linux-x86_64

.PHONY: all pascal go rust clean

all: pascal

pascal: mem_bench
mem_bench: mem_bench.pas
	fpc $(FPC_FLAGS) -o$@ $<

go:
	go test -bench=Bench -benchtime=3s -count=1 -timeout=120s -v

rust:
	cd benches && CARGO_TARGET_DIR=../build cargo bench --bench mem_bench 2>&1 | grep 'time:'

clean:
	rm -f mem_bench *.o *.ppu
	rm -rf build/
	cargo clean 2>/dev/null || true
