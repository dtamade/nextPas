FPC ?= fpc
CORE_ROOT := ../../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.webview/demo_webview
PROGRAM := demo_webview
SOURCE := $(PROGRAM).lpr
HEAPTRC_LOG ?= $(BUILD_DIR)/heaptrc.log
RUN_LOG ?= $(BUILD_DIR)/run.log
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test heaptrc clean
build:
	mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

# 人工演示形态：真实窗口 + stdout 桥流量日志
run: build
	$(BUILD_DIR)/$(PROGRAM)

# 自检门：事件驱动全矩阵，双跑（plain + heaptrc），0 unfreed 硬门；
# timeout 只作环境灾难兜底，正常毫秒级完成
test: build
	rm -f $(RUN_LOG) $(HEAPTRC_LOG)
	@timeout 120 $(BUILD_DIR)/$(PROGRAM) --selftest > $(RUN_LOG) 2>&1 || { cat $(RUN_LOG); exit 1; }
	@grep -F 'demo-pass all steps' $(RUN_LOG) >/dev/null || { cat $(RUN_LOG); exit 1; }
	@env HEAPTRC=log=$(HEAPTRC_LOG) timeout 120 $(BUILD_DIR)/$(PROGRAM) --selftest >> $(RUN_LOG) 2>&1 || { cat $(RUN_LOG); test ! -f $(HEAPTRC_LOG) || cat $(HEAPTRC_LOG); exit 1; }
	@grep -F '0 unfreed memory blocks' $(HEAPTRC_LOG) >/dev/null || { cat $(RUN_LOG); cat $(HEAPTRC_LOG); exit 1; }
	@cat $(RUN_LOG)
	@printf '\ndemo_webview-selftest=pass\n'

heaptrc: test

clean:
	rm -rf $(BUILD_DIR)
