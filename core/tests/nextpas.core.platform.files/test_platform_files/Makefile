PROGRAM := test_platform_files
include ../../common.mk

# Android forced-compile gate
android_compile_flags ?= -dNEXTPAS_FORCE_HOST_ANDROID
.PHONY: android-compile
android-compile:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -Cn $(android_compile_flags) test_platform_files_android_compile.lpr
