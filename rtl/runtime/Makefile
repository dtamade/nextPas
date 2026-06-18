# rtl/runtime/Makefile — nextPas runtime library (libnprt.a)
#
# Gate 4 Phase 2: 从 LLVM emitter 提取的独立 runtime 模块
#
# 构建流水线: .ll -> .bc (opt) -> .o (llc) -> .a (ar)
# 加上 np_setjmp.o (汇编)
#
# 用法:
#   make              — 构建 libnprt.a
#   make clean        — 清理构建产物
#   make test         — 构建并运行基本验证

SHELL := /bin/bash
.DEFAULT_GOAL := all

# Toolchain
LLVM_AS    ?= llvm-as
LLVM_OPT   ?= opt
LLC        ?= llc
AR         ?= ar
AS         ?= as

# Paths
TARGET     := linux-x86_64
BUILD_DIR  := ../../build/runtime/$(TARGET)
SRC_DIR    := src

# Source files
LL_SOURCES := $(wildcard $(SRC_DIR)/*.ll)
BC_FILES   := $(patsubst $(SRC_DIR)/%.ll,$(BUILD_DIR)/%.bc,$(LL_SOURCES))
O_FILES    := $(patsubst $(SRC_DIR)/%.ll,$(BUILD_DIR)/%.o,$(LL_SOURCES))
SETJMP_O   := $(BUILD_DIR)/np_setjmp.o

.PHONY: all clean test

all: $(BUILD_DIR)/libnprt.a

# .ll -> .bc (LLVM bitcode, via llvm-as)
$(BUILD_DIR)/%.bc: $(SRC_DIR)/%.ll | $(BUILD_DIR)
	$(LLVM_AS) $< -o $@

# .bc -> .o (native object, via llc)
$(BUILD_DIR)/%.o: $(BUILD_DIR)/%.bc
	$(LLC) -filetype=obj $< -o $@

# np_setjmp.s -> np_setjmp.o
$(SETJMP_O): $(SRC_DIR)/../linux-x86_64/np_setjmp.s | $(BUILD_DIR)
	$(AS) --64 -o $@ $<

# Archive into static library
$(BUILD_DIR)/libnprt.a: $(O_FILES) $(SETJMP_O)
	$(AR) rcs $@ $^
	@echo "runtime: libnprt.a built ($(words $(O_FILES)) objects + setjmp)"

$(BUILD_DIR):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR)

# Basic verification: assemble all .ll files without error
test: all
	@echo "runtime: all objects built successfully"
	@ar t $(BUILD_DIR)/libnprt.a | sort
