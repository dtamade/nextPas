# Makefile for test_test_bench_integration
.PHONY: all clean test

FPC = fpc
FPCFLAGS = -MObjFPC -Sh -O2 -gw -gl -gh
SRCDIR = ../../../src
BUILDDIR = build
BINDIR = $(BUILDDIR)/bin
OBJDIR = $(BUILDDIR)/obj

all: $(BINDIR)/test_test_bench_integration

$(BINDIR)/test_test_bench_integration: test_test_bench_integration.lpr
	mkdir -p $(BINDIR) $(OBJDIR)
	$(FPC) $(FPCFLAGS) -FU$(OBJDIR) -FE$(BINDIR) -Fu$(SRCDIR) -Fi$(SRCDIR) $<

test: $(BINDIR)/test_test_bench_integration
	$(BINDIR)/test_test_bench_integration

clean:
	rm -rf $(BUILDDIR)
