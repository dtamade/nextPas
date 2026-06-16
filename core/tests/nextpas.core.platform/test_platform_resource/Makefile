FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_resource
SIMULATED_WINDOWS_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_resource_windows_simulated
SIMULATED_ANDROID_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_resource_android_simulated
PROGRAM := test_platform_resource
SOURCE := test_platform_resource.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_INPUT_FLAGS := $(FPC_FLAGS) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
NATIVE_FPC_FLAGS := $(FPC_INPUT_FLAGS) -FU$(BUILD_DIR) -FE$(BUILD_DIR)
SIMULATED_WINDOWS_FPC_FLAGS := $(FPC_INPUT_FLAGS) -dNEXTPAS_FORCE_HOST_WINDOWS -FU$(SIMULATED_WINDOWS_BUILD_DIR) -FE$(SIMULATED_WINDOWS_BUILD_DIR)
SIMULATED_ANDROID_FPC_FLAGS := $(FPC_INPUT_FLAGS) -dNEXTPAS_FORCE_HOST_ANDROID -FU$(SIMULATED_ANDROID_BUILD_DIR) -FE$(SIMULATED_ANDROID_BUILD_DIR)

.PHONY: build run build-simulated-windows run-simulated-windows build-simulated-android test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(NATIVE_FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

build-simulated-windows:
	@mkdir -p $(SIMULATED_WINDOWS_BUILD_DIR)
	$(FPC) $(SIMULATED_WINDOWS_FPC_FLAGS) $(SOURCE)

run-simulated-windows: build-simulated-windows
	$(SIMULATED_WINDOWS_BUILD_DIR)/$(PROGRAM)

build-simulated-android:
	@mkdir -p $(SIMULATED_ANDROID_BUILD_DIR)
	$(FPC) $(SIMULATED_ANDROID_FPC_FLAGS) -Cn $(SOURCE)
	@printf 'platform-resource-android-compile=status=pass\n'

test: run run-simulated-windows build-simulated-android

clean:
	rm -rf $(BUILD_DIR) $(SIMULATED_WINDOWS_BUILD_DIR) $(SIMULATED_ANDROID_BUILD_DIR)
