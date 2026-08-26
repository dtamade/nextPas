PROGRAM := bench_tls13_record
# 基准不链 heaptrc——分配检测会扭曲吞吐数据；泄漏纪律由 test_aesgcm /
# test_tls13record 等套件覆盖。先例：bench_ssh_cipher、test_lockfree_cowarray。
HEAPTRC_GATE = 0
include ../../common.mk

# FPC_FLAGS 是延迟展开变量，include 之后覆盖 BASE_FPC_FLAGS 即可生效。
BASE_FPC_FLAGS := -MObjFPC -Sh -Sg -O3
