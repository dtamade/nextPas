FPC_FLAGS  := -O3 -CX -XX -Xs -dRELEASE -Fi../../core/src -Fu../../core/src -Fu/opt/fpcupdeluxe/fpc/units/x86_64-linux/rtl -Fu../../units/linux-x86_64 -Fi../../units/linux-x86_64

.PHONY: all pascal go rust clean

all: pascal

pascal: io_bench
io_bench: io_bench.pas
	fpc $(FPC_FLAGS) -o$@ $<

go:
	go test -bench=Bench -benchtime=3s -count=1 -timeout=120s -v

rust:
	cd benches && CARGO_TARGET_DIR=../build cargo bench --bench io_bench 2>&1 | grep 'time:'

clean:
	rm -f io_bench *.o *.ppu
	rm -rf build/
	cargo clean 2>/dev/null || true
