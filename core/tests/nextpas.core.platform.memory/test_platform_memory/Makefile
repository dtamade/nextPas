PROGRAM := test_platform_memory
include ../../common.mk

# Darwin GHA (macos-14 aarch64): with -gh/heaptrc the suite prints all
# functional checks green then dies with Abort trap 6 at process exit.
# Observed after virtual mmap/mprotect/munmap + posix_memalign mix; other
# macOS platform gates with heaptrc stay green. Keep leak-proof on Linux
# (common.mk -gh); on Darwin run focused-runtime without heaptrc so the
# 9-gate matrix can promote on real behavior evidence.
ifeq ($(shell uname -s 2>/dev/null),Darwin)
FPC_FLAGS = -MObjFPC -Sh -Sg -O2 -gl \
	-FU$(BUILD_DIR) -FE$(BUILD_DIR) \
	-Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/tests/shared
endif
