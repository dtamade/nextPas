HEAPTRC_GATE := 1
PROGRAM := test_ssh_proxyjump
include ../../common.mk
# Loopback harness uses manual MemPipe with _AddRef=-1 + BeginThread + explicit Free
# (mirrors test_ssh_session zero-leak pattern, owner boundary: io.intf/bytes.ops single source);
# 5/5 heaptrc 0 (71→0 blocks converged via DoneEvent + Finalize + Free, inline/Move zero-copy).
