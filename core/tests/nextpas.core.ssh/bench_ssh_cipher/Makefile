PROGRAM := bench_ssh_cipher
include ../../common.mk

# 基准程序：关闭 heaptrc（分配检测会扭曲吞吐数据），-O3 优化。
# FPC_FLAGS 是延迟展开变量，include 之后覆盖 BASE_FPC_FLAGS 即可生效。
BASE_FPC_FLAGS := -MObjFPC -Sh -Sg -O3
