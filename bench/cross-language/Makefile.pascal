PROGRAM = bench_sort_pascal
FPC = fpc
FPCFLAGS = -MObjFPC -Sh -O2 -gw -gl
CORE_ROOT = ../../core
SRC_DIR = $(CORE_ROOT)/src

SRCS = bench_sort_comparison.pas \
       $(SRC_DIR)/nextpas.core.bench.base.pas \
       $(SRC_DIR)/nextpas.core.bench.intf.pas \
       $(SRC_DIR)/nextpas.core.bench.stats.pas \
       $(SRC_DIR)/nextpas.core.bench.stats.advanced.pas \
       $(SRC_DIR)/nextpas.core.bench.pas \
       $(SRC_DIR)/nextpas.core.bench.baseline.pas \
       $(SRC_DIR)/nextpas.core.bench.memtrack.pas \
       $(SRC_DIR)/nextpas.core.bench.parallel.pas \
       $(SRC_DIR)/nextpas.core.bench.runner.pas \
       $(SRC_DIR)/nextpas.core.bench.report.pas \
       $(SRC_DIR)/nextpas.core.bench.xlang.pas

BUILD_DIR = build
BIN_DIR = $(BUILD_DIR)/bin
OBJ_DIR = $(BUILD_DIR)/obj

TARGET = $(BIN_DIR)/$(PROGRAM)

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(SRCS) | $(BIN_DIR) $(OBJ_DIR)
	$(FPC) $(FPCFLAGS) \
		-FU$(OBJ_DIR) -FE$(BIN_DIR) \
		-Fu$(SRC_DIR) -Fi$(SRC_DIR) \
		bench_sort_comparison.pas \
		-o$(PROGRAM)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

run: $(TARGET)
	$(TARGET)

clean:
	rm -rf $(BUILD_DIR)
