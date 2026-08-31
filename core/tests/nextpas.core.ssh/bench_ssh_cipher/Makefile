PROGRAM := bench_ssh_cipher
# Leak gate opt-out（common.mk 默认开的文档化退出路径，须在 include 之前）：
# 基准不链 heaptrc——分配检测会扭曲吞吐数据；泄漏纪律由 ssh 其余 8 门与
# e2e_ssh_live 的 heaptrc 门禁覆盖。先例：test_lockfree_cowarray、
# test_boundary_cases。
HEAPTRC_GATE = 0
include ../../common.mk

# FPC_FLAGS 是延迟展开变量，include 之后覆盖 BASE_FPC_FLAGS 即可生效。
BASE_FPC_FLAGS := -MObjFPC -Sh -Sg -O3
