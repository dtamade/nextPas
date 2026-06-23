PROJECT := bench_new_components
PROJDIR := .
BASEDIR := ../../..
SRCDIR  := $(BASEDIR)/src
BUILDDIR:= $(BASEDIR)/build/projects/nextpas.core.mem/$(PROJECT)

FPC     := fpc
FPCFLAGS:= -MObjFPC -Sh -O2 -gl -Fu$(SRCDIR) -Fi$(SRCDIR) -FE$(BUILDDIR) -FU$(BUILDDIR)

.PHONY: all build run clean

all: build

build:
	@mkdir -p $(BUILDDIR)
	$(FPC) $(FPCFLAGS) $(PROJDIR)/$(PROJECT).lpr

run: build
	$(BUILDDIR)/$(PROJECT)

clean:
	rm -rf $(BUILDDIR)
