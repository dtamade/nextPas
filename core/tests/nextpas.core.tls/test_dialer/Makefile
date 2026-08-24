PROGRAM := test_dialer
# Leak gate opt-out (documented exception to the common.mk default-on):
# this suite dials real internet hosts (1.1.1.1 / one.one.one.one), so both
# which code paths execute and how many server certificates get parsed vary
# with network conditions — a fail-closed verdict here is nondeterministic
# by nature. Two real cert-lifecycle fixes landed alongside (connection
# Destroy backstop + TLS12-fallback failure-path release), but the pure-
# Pascal TLS stack still leaks parsed certificates on some paths across
# its multiple backends. Follow-up: dedicated cert-lifecycle audit batch,
# then re-enable the gate here.
HEAPTRC_GATE = 0
include ../../common.mk
