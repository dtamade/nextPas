FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.mmap/test_platform_mmap
ANDROID_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform.mmap/test_platform_mmap_android_compile
PROGRAM := test_platform_mmap
SOURCE := test_platform_mmap.lpr
ANDROID_SOURCE := test_platform_mmap_android_compile.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_INPUT_FLAGS := $(FPC_FLAGS) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
NATIVE_FPC_FLAGS := $(FPC_INPUT_FLAGS) -FU$(BUILD_DIR) -FE$(BUILD_DIR)
ANDROID_FPC_FLAGS := $(FPC_INPUT_FLAGS) -dNEXTPAS_FORCE_HOST_ANDROID -FU$(ANDROID_BUILD_DIR) -FE$(ANDROID_BUILD_DIR)

.PHONY: build run build-android-compile test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(NATIVE_FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

build-android-compile:
	@mkdir -p $(ANDROID_BUILD_DIR)
	$(FPC) $(ANDROID_FPC_FLAGS) -Cn $(ANDROID_SOURCE)
	@printf 'platform-mmap-android-compile=status=pass\n'

test: run build-android-compile

clean:
	rm -rf $(BUILD_DIR) $(ANDROID_BUILD_DIR)
