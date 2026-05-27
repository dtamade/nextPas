FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_host_abi_wave10_posix_stat_hosts
PROGRAM := test_platform_host_abi_wave10_posix_stat_hosts
SOURCE := test_platform_host_abi_wave10_posix_stat_hosts.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: test clean

test: $(BUILD_DIR)/$(PROGRAM)
	$(BUILD_DIR)/$(PROGRAM)

$(BUILD_DIR)/$(PROGRAM): $(SOURCE)
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

clean:
	rm -rf $(BUILD_DIR)
