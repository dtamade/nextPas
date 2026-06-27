PROGRAM = test_bench_memtrack
FPC = fpc
FPCFLAGS = -MObjFPC -Sh -O2 -gw -gl
CORE_ROOT = ../../..
SRC_DIR = $(CORE_ROOT)/src

SRCS = $(PROGRAM).lpr \
       $(SRC_DIR)/nextpas.core.bench.base.pas \
       $(SRC_DIR)/nextpas.core.bench.baseline.pas \
       $(SRC_DIR)/nextpas.core.bench.intf.pas \
       $(SRC_DIR)/nextpas.core.bench.memtrack.pas \
       $(SRC_DIR)/nextpas.core.bench.parallel.pas \
       $(SRC_DIR)/nextpas.core.bench.pas \
       $(SRC_DIR)/nextpas.core.bench.report.pas \
       $(SRC_DIR)/nextpas.core.bench.runner.pas \
       $(SRC_DIR)/nextpas.core.bench.stats.pas \
       $(SRC_DIR)/nextpas.core.bench.stats.advanced.pas \
       $(SRC_DIR)/nextpas.core.bench.xlang.pas \
       $(SRC_DIR)/nextpas.core.test.pas \
       $(SRC_DIR)/nextpas.core.test.base.pas \
       $(SRC_DIR)/nextpas.core.test.check.pas \
       $(SRC_DIR)/nextpas.core.test.config.pas \
       $(SRC_DIR)/nextpas.core.test.expect.pas \
       $(SRC_DIR)/nextpas.core.test.output.pas \
       $(SRC_DIR)/nextpas.core.test.output.tap.pas \
       $(SRC_DIR)/nextpas.core.test.output.json.pas \
       $(SRC_DIR)/nextpas.core.test.runner.pas \
       $(SRC_DIR)/nextpas.core.test.runner.context.pas \
       $(SRC_DIR)/nextpas.core.test.runner.parallel.pas \
       $(SRC_DIR)/nextpas.core.test.discovery.pas \
       $(SRC_DIR)/nextpas.core.test.mock.pas \
       $(SRC_DIR)/nextpas.core.sync.mutex.pas

BUILD_DIR = build
BIN_DIR = $(BUILD_DIR)/bin
OBJ_DIR = $(BUILD_DIR)/obj

TARGET = $(BIN_DIR)/$(PROGRAM)

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(SRCS) | $(BIN_DIR) $(OBJ_DIR)
	$(FPC) $(FPCFLAGS) \
		-FU$(OBJ_DIR) -FE$(BIN_DIR) \
		-Fu$(SRC_DIR) -Fi$(SRC_DIR) \
		$(PROGRAM).lpr

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

clean:
	rm -rf $(BUILD_DIR)

test: $(TARGET)
	$(TARGET)
