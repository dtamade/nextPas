# nextpas.core.collections examples
EXAMPLES := quickstart deque_queue treeset_compare

.PHONY: all test clean $(EXAMPLES)

all: test

test:
	@set -e; for e in $(EXAMPLES); do \
	  echo "== example $$e =="; \
	  $(MAKE) -C $$e test; \
	done

clean:
	@for e in $(EXAMPLES); do $(MAKE) -C $$e clean; done

$(EXAMPLES):
	$(MAKE) -C $@ test
