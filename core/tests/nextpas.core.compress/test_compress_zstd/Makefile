PROGRAM := test_compress_zstd
include ../../common.mk

# libzstd ships a dev symlink on this host; fall back to soname link if not
LIBZSTD_SONAME := $(shell gcc -print-file-name=libzstd.so.1)
ifneq ($(LIBZSTD_SONAME),libzstd.so.1)
FPC_FLAGS += -Fl$(dir $(LIBZSTD_SONAME))
endif
