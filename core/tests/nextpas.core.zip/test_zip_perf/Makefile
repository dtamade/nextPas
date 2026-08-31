PROGRAM := test_zip_perf
# perf allocs via CountingMemoryManager wrapping heaptrc delegate; HEAPTRC_GATE=1 keeps zero-leak hygiene, budget from BASELINE.json (inline/zero-copy: extra 64B stack, Reserve/DrainStaged zero-copy)
HEAPTRC_GATE = 1
include ../../common.mk
