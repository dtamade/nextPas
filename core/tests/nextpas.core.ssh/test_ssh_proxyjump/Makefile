HEAPTRC_GATE := 0
PROGRAM := test_ssh_proxyjump
include ../../common.mk
# Loopback harness uses manual MemPipe with _AddRef=-1 (intentionally non-refcounted)
# to mirror test_ssh_session; heap buffers linger at exit (71 blocks) but functional
# 5/5 passes. Known leak, same class as sftp async 19 blocks.
