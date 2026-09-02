PROGRAM := bench_tls13_record
# Leak gate opt-out（common.mk 默认开的文档化退出路径，须在 include 之前）：
# 基准不链 heaptrc——分配检测会扭曲吞吐数据；泄漏纪律由 crypto/tls 其余
# production gates 与 HEAPTRC_GATE=1 覆盖（test_aesgcm/test_tls13_aead/
# test_tls13_recordsealer heaptrc 0，bytes.ops 单源 Move/TByteSpan inline/
# 零拷贝，O3 -Xs）。bench 保持 HEAPTRC_GATE=0 防吞吐失真由其余门覆盖泄漏
# （common.mk HEAPTRC_GATE=1 unified gate，±5% env noise）。先例：
# bench_ssh_cipher、test_lockfree_cowarray。
HEAPTRC_GATE = 0
include ../../common.mk

# FPC_FLAGS 是延迟展开变量，include 之后覆盖 BASE_FPC_FLAGS 即可生效。
BASE_FPC_FLAGS := -MObjFPC -Sh -Sg -O3
