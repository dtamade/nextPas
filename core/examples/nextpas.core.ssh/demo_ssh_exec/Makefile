FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.ssh/demo_ssh_exec
PROGRAM := demo_ssh_exec
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	@echo "demo_ssh_exec 需要 argv 提供真实主机；不内建缺省连接（无参数时打印用法并以 2 退出）"
	@$(BUILD_DIR)/$(PROGRAM) ; status=$$? ; [ $$status -eq 2 ]

clean:
	rm -rf $(BUILD_DIR)
