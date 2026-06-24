PROGRAM = test_bench_integration
FPC = fpc
FPCFLAGS = -MObjFPC -Sh -O2 -gw -gl
CORE_ROOT = ../../..
SRC_DIR = $(CORE_ROOT)/src

SRCS = $(PROGRAM).lpr \
       $(SRC_DIR)/nextpas.core.bench.base.pas \
       $(SRC_DIR)/nextpas.core.bench.intf.pas \
       $(SRC_DIR)/nextpas.core.bench.stats.pas \
       $(SRC_DIR)/nextpas.core.bench.runner.pas \
       $(SRC_DIR)/nextpas.core.bench.report.pas \
       $(SRC_DIR)/nextpas.core.bench.pas

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
