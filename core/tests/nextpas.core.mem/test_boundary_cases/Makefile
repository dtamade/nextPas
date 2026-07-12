PROGRAM := test_boundary_cases
include ../../common.mk
# heaptrc mis-handles GetMem(High(SizeUInt)): returns a fake non-nil and then
# crashes on free/leak report. Boundary OOM tests need normal heap semantics.
FPC_FLAGS = -MObjFPC -Sh -O2 -gl -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
