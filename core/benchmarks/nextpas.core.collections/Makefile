# nextpas.core.collections benchmarks
# Artifacts under core/build/projects/nextpas.core.collections/

FPC ?= fpc
CORE_ROOT := ../..
BUILD_ROOT ?= $(CORE_ROOT)/build/projects/nextpas.core.collections
FPC_FLAGS ?= -MObjFPC -Sh -O3 -Xs
FPC_FLAGS += -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src -Fu$(CORE_ROOT)/build/lib

BENCHES := \
	bench_vec \
	bench_vecdeque \
	bench_hashmap \
	bench_set \
	bench_list \
	bench_priorityqueue \
	bench_lrucache \
	bench_btree \
	bench_sort \
	bench_misc

.PHONY: all build clean list help $(BENCHES) bench-set bench-hashmap bench-vec

help:
	@echo "Targets: all | build | clean | list | bench-set | bench-hashmap | bench-vec | $(BENCHES)"
	@echo "Example: make -C core/benchmarks/nextpas.core.collections bench-set"

list:
	@for b in $(BENCHES); do echo $$b; done

# Compile all benches that have a .lpr (skip missing)
all: build

build:
	@set -e; \
	for b in $(BENCHES); do \
	  if [ -f $$b/$$b.lpr ]; then \
	    echo "== build $$b =="; \
	    $(MAKE) $$b; \
	  else \
	    echo "== skip $$b (no $$b.lpr) =="; \
	  fi; \
	done

define BENCH_RULE
$(1):
	@mkdir -p $(BUILD_ROOT)/$(1)
	$(FPC) $(FPC_FLAGS) -FU$(BUILD_ROOT)/$(1) -FE$(BUILD_ROOT)/$(1) $(1)/$(1).lpr
endef

$(foreach b,$(BENCHES),$(eval $(call BENCH_RULE,$(b))))

# Aliases used in docs
bench-set: bench_set
bench-hashmap: bench_hashmap
bench-vec: bench_vec

clean:
	rm -rf $(BUILD_ROOT)/bench_*
