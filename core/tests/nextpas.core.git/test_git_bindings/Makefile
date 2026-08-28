PROGRAM := test_git_bindings
include ../../common.mk

# The host ships libgit2 as versioned soname only (no unversioned dev
# symlink). Link against the soname file directly so DT_NEEDED records
# libgit2.so.1.9, which the loader finds on the default search path.
# Must come AFTER the include: common.mk assigns FPC_FLAGS with "=".
LIBGIT2_SONAME := $(shell gcc -print-file-name=libgit2.so.1.9)

ifneq ($(LIBGIT2_SONAME),libgit2.so.1.9)
FPC_FLAGS += -Fl$(dir $(LIBGIT2_SONAME)) -k-l:libgit2.so.1.9
endif
