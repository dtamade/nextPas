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

.PHONY: all clean test

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
	$(TARGET)
