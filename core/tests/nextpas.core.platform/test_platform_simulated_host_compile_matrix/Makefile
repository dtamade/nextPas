FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_simulated_host_compile_matrix
SOURCE := test_platform_simulated_host_compile_matrix.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -Cn
FPC_FLAGS += -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: darwin android freebsd unix test clean

darwin:
	@mkdir -p $(BUILD_DIR)/darwin
	$(FPC) $(FPC_FLAGS) -dNEXTPAS_FORCE_HOST_DARWIN -dSIM_EXPECT_DARWIN -FU$(BUILD_DIR)/darwin -FE$(BUILD_DIR)/darwin $(SOURCE)
	@printf 'simulated-host-compile-target=darwin status=pass\n'

android:
	@mkdir -p $(BUILD_DIR)/android
	$(FPC) $(FPC_FLAGS) -dNEXTPAS_FORCE_HOST_ANDROID -dSIM_EXPECT_ANDROID -FU$(BUILD_DIR)/android -FE$(BUILD_DIR)/android $(SOURCE)
	@printf 'simulated-host-compile-target=android status=pass\n'

freebsd:
	@mkdir -p $(BUILD_DIR)/freebsd
	$(FPC) $(FPC_FLAGS) -dNEXTPAS_FORCE_HOST_FREEBSD -dSIM_EXPECT_FREEBSD -FU$(BUILD_DIR)/freebsd -FE$(BUILD_DIR)/freebsd $(SOURCE)
	@printf 'simulated-host-compile-target=freebsd status=pass\n'

unix:
	@mkdir -p $(BUILD_DIR)/unix
	$(FPC) $(FPC_FLAGS) -dNEXTPAS_FORCE_HOST_UNIX -dSIM_EXPECT_UNIX -FU$(BUILD_DIR)/unix -FE$(BUILD_DIR)/unix $(SOURCE)
	@printf 'simulated-host-compile-target=unix status=pass\n'

test: darwin android freebsd unix
	@printf 'simulated-host-compile-matrix-status=pass\n'

clean:
	rm -rf $(BUILD_DIR)
