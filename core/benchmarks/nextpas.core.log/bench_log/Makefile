SRC := ../../../src
FPC := fpc
FPCFLAGS := -Fu$(SRC) -Fi$(SRC) -O3

.PHONY: all clean run compare

all: bench_log

bench_log: bench_log.lpr
	$(FPC) $< $(FPCFLAGS) -o$@

run: bench_log
	./bench_log 2>/dev/null

compare: bench_log compare_go/main.go
	@echo "--- Pascal ---"
	@./bench_log 2>/dev/null
	@echo ""
	@echo "--- Go (log/slog) ---"
	@cd compare_go && go run main.go

clean:
	rm -f bench_log bench_log.o *.ppu *.s
