# nextPas/core — test_font_shaper
.PHONY: all build run test clean

CORE_ROOT := $(abspath ../../..)
SRC_DIR   := $(CORE_ROOT)/src
BUILD_DIR := $(CORE_ROOT)/build
BIN_DIR   := $(BUILD_DIR)/bin
LIB_DIR   := $(BUILD_DIR)/lib
TEST_NAME := test_font_shaper

FPC       := fpc
FPC_FLAGS := -Mobjfpc -Sh -O1 -g -gl -gw2 -Criot -Sa \
             -FE$(BIN_DIR) -FU$(LIB_DIR) \
             -Fi$(SRC_DIR) -Fl$(BUILD_DIR) -Fl$(BUILD_DIR)/lib \
             -Fu$(SRC_DIR)

$(BIN_DIR)/$(TEST_NAME): $(TEST_NAME).lpr $(SRC_DIR)/nextpas.core.font.shaper.pas $(SRC_DIR)/nextpas.core.font.ttface.pas $(SRC_DIR)/nextpas.core.font.base.pas $(SRC_DIR)/nextpas.core.base.pas $(SRC_DIR)/nextpas.core.exception.pas $(SRC_DIR)/nextpas.core.mem.pas
	@mkdir -p $(BIN_DIR) $(LIB_DIR)
	$(FPC) $(FPC_FLAGS) $<

build: $(BIN_DIR)/$(TEST_NAME)

run: build
	$(BIN_DIR)/$(TEST_NAME)

test: run

clean:
	rm -f $(BIN_DIR)/$(TEST_NAME) $(LIB_DIR)/$(TEST_NAME).* $(LIB_DIR)/nextpas.core.font.shaper.*

all: test
