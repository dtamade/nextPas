PROGRAM := test_platform_memory
include ../../common.mk

# Darwin GHA (macos-14 aarch64): prior Abort trap 6 under -gh/heaptrc at
# process exit was isolated to mixed posix_memalign/free + mmap/mprotect/
# munmap interaction. Fixed via Darwin SysGetMem fallback (no posix_memalign),
# mprotect-only commit/decommit, MAP_ANON isolation, 16MiB align cap and
# madvise skip on Darwin. Keep zero-leak verification congruent on Linux and
# Darwin via common.mk -gh + HEAPTRC env-channel (haltonnotreleased/log);
# focused-runtime and heaptrc gates are now one matrix, no heaptrc gap.
