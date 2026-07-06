PROJECT := test_http_websocket_client
FPC := fpc
FPCFLAGS := -MObjFPC -Sh -O2 -gl -gh -dHEAPTRC_ACTIVE
SRCDIR := ../../../src
BUILDDIR := ../../../build/projects/nextpas.core.http/$(PROJECT)

.PHONY: all clean test

all: $(BUILDDIR)/$(PROJECT)

$(BUILDDIR)/$(PROJECT): $(PROJECT).lpr
	@mkdir -p $(BUILDDIR)
	$(FPC) $(FPCFLAGS) -Fu$(SRCDIR) -Fi$(SRCDIR) -FU$(BUILDDIR) -FE$(BUILDDIR) $<

test: $(BUILDDIR)/$(PROJECT)
	$(BUILDDIR)/$(PROJECT)

clean:
	rm -rf $(BUILDDIR)
