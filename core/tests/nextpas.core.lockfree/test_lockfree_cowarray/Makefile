PROGRAM := test_lockfree_cowarray
# Leak gate opt-out (documented exception to the common.mk default-on):
# TestStrings deliberately triggers the managed-T constructor raise; the
# resulting single 48-byte residual reproduces ONLY in the full-suite
# binary (constant 1 block, empty heaptrc trace) — every isolated replica
# of the mechanism (plain class / generic specialization / managed-field
# record / framework error type, statement and assignment forms, before-
# and-after inherited) exits at 0 unfreed. Suite teardown and unit logic
# are verified clean by removal/enable-one bisection. Classified as an
# FPC 3.3.1 runtime interaction pending upstream reproduction.
HEAPTRC_GATE = 0
include ../../common.mk
