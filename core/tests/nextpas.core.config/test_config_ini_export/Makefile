ROOT_DIR := ../../..
BIN_DIR := $(ROOT_DIR)/build/projects/nextpas.core.config/test_config_ini_export
SRC_DIR := $(ROOT_DIR)/src
TEST_BIN := $(BIN_DIR)/test_config_ini_export

FPC := fpc
FPCFLAGS := -MObjFPC -Sh -O2 -gl -gh -FU$(BIN_DIR) -FE$(BIN_DIR) -Fu$(SRC_DIR) -Fi$(SRC_DIR)

.PHONY: all test clean run

all: test

$(TEST_BIN): test_config_ini_export.lpr
	@mkdir -p $(BIN_DIR)
	$(FPC) $(FPCFLAGS) $<

run: $(TEST_BIN)
	$(TEST_BIN)

test: run

clean:
	rm -rf $(BIN_DIR)
