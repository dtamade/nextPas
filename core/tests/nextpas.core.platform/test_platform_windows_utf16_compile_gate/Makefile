PROGRAM := test_platform_windows_utf16_compile_gate
FPC_FLAGS += -Cn
include ../../common_compile_gate.mk

cross-win64:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -Twin64 -Px86_64 $(SOURCE)
