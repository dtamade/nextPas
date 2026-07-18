PROGRAM := test_platform_windows_signal_compile_gate
include ../../common_compile_gate.mk

# Force Windows host branch (SetConsoleCtrlHandler path). Must follow
# common_compile_gate.mk because that file assigns FPC_FLAGS with '='.
FPC_FLAGS += -Cn -dNEXTPAS_FORCE_HOST_WINDOWS
