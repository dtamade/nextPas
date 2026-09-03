PROGRAM := test_boundary_cases
# Leak gate opt-out (whitelisted probe, common.mk HEAPTRC_GATE_WHITELIST):
# heaptrc mis-handles GetMem(High(SizeUInt)) — its per-block bookkeeping
# overflows SizeUInt and returns a fake non-nil that crashes on free/leak
# report. This suite's whole purpose is probing RTL boundary sizes, so -gh
# is stripped below; the gate pins would fail closed forever. Re-enable only
# after an upstream heaptrc overflow guard exists.
# Whitelist explicit: HEAPTRC_GATE=0 allowed only via common.mk HEAPTRC_GATE_WHITELIST.
HEAPTRC_GATE = 0
include ../../common.mk
FPC_FLAGS = -MObjFPC -Sh -O2 -gl -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
