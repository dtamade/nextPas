FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.log/bench_log
PROGRAM := bench_log
SOURCE := bench_log.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O3 -Xs
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

.PHONY: build run test clean compare

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

compare: run compare_go/main.go
	@echo "--- Pascal ---"
	@$(BUILD_DIR)/$(PROGRAM) 2>/dev/null
	@echo ""
	@echo "--- Go (log/slog) ---"
	@cd compare_go && go run main.go

clean:
	rm -rf $(BUILD_DIR)
	rm -f bench_log bench_log.o *.ppu *.s
