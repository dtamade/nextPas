# 共享 Makefile 规则 — 用于 bench 测试套件
# 用法: 在测试 Makefile 中设置 PROGRAM 和 SRCS，然后 include 此文件
#
# 示例:
#   PROGRAM = test_bench_foo
#   SRCS = $(PROGRAM).lpr \
#          $(SRC_DIR)/nextpas.core.bench.base.pas \
#          ...
#   include ../bench_test_common.mk

FPC = fpc
FPCFLAGS = -MObjFPC -Sh -O2 -gw -gl -gh
CORE_ROOT = ../../..
SRC_DIR = $(CORE_ROOT)/src

# 测试框架公共源文件
TEST_FRAMEWORK_SRCS = \
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
       $(SRC_DIR)/nextpas.core.test.mock.pas

# 合并所有源文件
ALL_SRCS = $(SRCS) $(TEST_FRAMEWORK_SRCS)

BUILD_DIR = build
BIN_DIR = $(BUILD_DIR)/bin
OBJ_DIR = $(BUILD_DIR)/obj

TARGET = $(BIN_DIR)/$(PROGRAM)

# Leak gate: mirrors tests/common.mk (staged defaulting complete 2026-08-25).
# The build already compiles with -gh; the gate adds the fail-closed exit
# assertion. Opt out per invocation with HEAPTRC_GATE= (empty) or =0;
# "0 must read as off where it is used" - resolve at the consumer via
# HEAPTRC_ENABLED, command-line variables outrank makefile assignments.
HEAPTRC_GATE ?= 1
HEAPTRC_ENABLED := $(HEAPTRC_GATE)
ifeq ($(HEAPTRC_GATE),0)
HEAPTRC_ENABLED :=
endif
HEAPTRC_DUMP ?= $(BIN_DIR)/$(PROGRAM).heaptrc

.PHONY: all clean test run

all: $(TARGET)

$(TARGET): $(ALL_SRCS) | $(BIN_DIR) $(OBJ_DIR)
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
	@if [ -n "$(HEAPTRC_ENABLED)" ]; then \
		rm -f $(HEAPTRC_DUMP); \
		HEAPTRC='haltonnotreleased,log=$(HEAPTRC_DUMP)' $(TARGET); \
		grep -q '^Heap dump by heaptrc unit' $(HEAPTRC_DUMP) || { echo "[HEAPTRC] FAILED: no heap dump written ($(HEAPTRC_DUMP))"; exit 1; }; \
		grep -q '^0 unfreed memory blocks : 0$$' $(HEAPTRC_DUMP) || { echo "[HEAPTRC] FAILED: unfreed blocks reported"; cat $(HEAPTRC_DUMP); exit 1; }; \
		echo "[HEAPTRC] OK"; \
	else \
		$(TARGET); \
	fi

run: test
