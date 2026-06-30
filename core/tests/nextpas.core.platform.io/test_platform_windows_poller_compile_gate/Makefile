PROGRAM := test_platform_windows_poller_compile_gate
FPC_FLAGS += -Cn -dNEXTPAS_FORCE_HOST_WINDOWS
include ../../common_compile_gate.mk

cross-win64:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) -Twin64 -Px86_64 $(SOURCE)
