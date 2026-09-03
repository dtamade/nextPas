PROGRAM := bench_tls13_record
# Throughput fidelity: default HEAPTRC_GATE=0 no -gh (分配检测扭曲吞吐, ±5% noise, inline/零拷贝 bytes.ops Move/TByteSpan, O3 -Xs).
# Leak escape closed via dual-mode: make test BENCH_HEAPTRC=1 forces HEAPTRC_GATE=1 + -gh -dHEAPTRC_ACTIVE (common.mk unified gate).
# Production leak cover: crypto/tls gates (test_aesgcm/test_tls13_aead/test_tls13_recordsealer heaptrc 0) + ssh gates + e2e_ssh_live; whitelist: test_lockfree_cowarray/test_boundary_cases (FPC overflow).
BENCH_HEAPTRC ?= 0
ifeq ($(BENCH_HEAPTRC),1)
HEAPTRC_GATE := 1
else
HEAPTRC_GATE = 0
endif
include ../../common.mk

# FPC_FLAGS 是延迟展开变量，include 之后覆盖 BASE_FPC_FLAGS 即可生效。
ifeq ($(BENCH_HEAPTRC),1)
BASE_FPC_FLAGS := -MObjFPC -Sh -Sg -O3 -gl -gh -dHEAPTRC_ACTIVE
else
BASE_FPC_FLAGS := -MObjFPC -Sh -Sg -O3
endif
