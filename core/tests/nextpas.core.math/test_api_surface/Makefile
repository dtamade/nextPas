CORE_ROOT := ../../..
REPORT_DIR ?= $(CORE_ROOT)/build/projects/$(notdir $(CURDIR))
PYTHON ?= python3

.PHONY: test clean

test:
	@mkdir -p $(REPORT_DIR)
	$(PYTHON) -B test_api_surface.py --self-test --root $(CORE_ROOT) --json-file $(REPORT_DIR)/api_surface.json --summary-line

clean:
	rm -rf $(REPORT_DIR) __pycache__
