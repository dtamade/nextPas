FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.db/test_db_mysql_adapter
PROGRAM := test_db_mysql_adapter
SOURCE := $(PROGRAM).lpr
HEAPTRC_LOG ?= $(BUILD_DIR)/heaptrc.log
RUN_LOG ?= $(BUILD_DIR)/run.log
HEAPTRC_ENV ?= HEAPTRC=log=$(HEAPTRC_LOG)
# A2 门禁 1-6 组全部离线可跑（归一表/DSN/槽位计划/编组/负连接/枚举契约）。
# 第 7 组真机冒烟经 NEXTPAS_MYSQL_TEST_CONN 门控，缺席自动 Skip。
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
.PHONY: build run test heaptrc clean
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)
run: build
	$(BUILD_DIR)/$(PROGRAM)
test: run heaptrc
heaptrc: build
	@rm -f $(RUN_LOG) $(HEAPTRC_LOG)
	@$(HEAPTRC_ENV) $(BUILD_DIR)/$(PROGRAM) > $(RUN_LOG) 2>&1 || { cat $(RUN_LOG); test ! -f $(HEAPTRC_LOG) || cat $(HEAPTRC_LOG); exit 1; }
	@grep -F '0 unfreed memory blocks' $(HEAPTRC_LOG) >/dev/null || { cat $(RUN_LOG); cat $(HEAPTRC_LOG); exit 1; }
	@cat $(RUN_LOG)
	@cat $(HEAPTRC_LOG)
	@printf '\ntest_db_mysql_adapter-heaptrc=pass\n'
clean:
	rm -rf $(BUILD_DIR)
