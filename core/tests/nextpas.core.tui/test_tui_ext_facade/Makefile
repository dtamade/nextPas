FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.tui/test_tui_ext_facade
PROGRAM := test_tui_ext_facade
SOURCE := $(PROGRAM).lpr
NEGATIVE_BUILD_DIR := $(BUILD_DIR)/negative
NEGATIVE_IMAGE_SOURCE := test_tui_ext_facade_rejects_image_protocol.lpr
NEGATIVE_CLIPBOARD_SOURCE := test_tui_ext_facade_rejects_clipboard.lpr
NEGATIVE_GAUGE_SOURCE := test_tui_ext_facade_rejects_gauge.lpr
NEGATIVE_SPARKLINE_SOURCE := test_tui_ext_facade_rejects_sparkline.lpr
NEGATIVE_CANVAS_SOURCE := test_tui_ext_facade_rejects_canvas.lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run negative test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

negative:
	@mkdir -p $(NEGATIVE_BUILD_DIR)
	@if $(FPC) $(FPC_FLAGS) -FU$(NEGATIVE_BUILD_DIR) -FE$(NEGATIVE_BUILD_DIR) \
	  $(NEGATIVE_IMAGE_SOURCE) >$(NEGATIVE_BUILD_DIR)/reject_image_protocol.log 2>&1; then \
	  echo "expected ext facade to reject experimental image protocol symbols"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_image_protocol.log; \
	  exit 1; \
	elif ! grep -Eq 'Identifier not found.*(TImageProtocol|DetectImageProtocol)' \
	  $(NEGATIVE_BUILD_DIR)/reject_image_protocol.log; then \
	  echo "unexpected compiler failure while checking ext facade image protocol leakage"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_image_protocol.log; \
	  exit 1; \
	fi
	@if $(FPC) $(FPC_FLAGS) -FU$(NEGATIVE_BUILD_DIR) -FE$(NEGATIVE_BUILD_DIR) \
	  $(NEGATIVE_CLIPBOARD_SOURCE) >$(NEGATIVE_BUILD_DIR)/reject_clipboard.log 2>&1; then \
	  echo "expected ext facade to reject experimental clipboard symbols"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_clipboard.log; \
	  exit 1; \
	elif ! grep -Eq 'Identifier not found.*(TClipboard|cmOSC52)' \
	  $(NEGATIVE_BUILD_DIR)/reject_clipboard.log; then \
	  echo "unexpected compiler failure while checking ext facade clipboard leakage"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_clipboard.log; \
	  exit 1; \
	fi
	@if $(FPC) $(FPC_FLAGS) -FU$(NEGATIVE_BUILD_DIR) -FE$(NEGATIVE_BUILD_DIR) \
	  $(NEGATIVE_GAUGE_SOURCE) >$(NEGATIVE_BUILD_DIR)/reject_gauge.log 2>&1; then \
	  echo "expected ext facade to reject TGauge from full-only advanced widgets"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_gauge.log; \
	  exit 1; \
	elif ! grep -Eq 'Identifier not found.*(TGauge|IGauge)' \
	  $(NEGATIVE_BUILD_DIR)/reject_gauge.log; then \
	  echo "unexpected compiler failure while checking ext facade TGauge leakage"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_gauge.log; \
	  exit 1; \
	fi
	@if $(FPC) $(FPC_FLAGS) -FU$(NEGATIVE_BUILD_DIR) -FE$(NEGATIVE_BUILD_DIR) \
	  $(NEGATIVE_SPARKLINE_SOURCE) >$(NEGATIVE_BUILD_DIR)/reject_sparkline.log 2>&1; then \
	  echo "expected ext facade to reject TSparkline from full-only advanced widgets"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_sparkline.log; \
	  exit 1; \
	elif ! grep -Eq 'Identifier not found.*(TSparkline|ISparkline)' \
	  $(NEGATIVE_BUILD_DIR)/reject_sparkline.log; then \
	  echo "unexpected compiler failure while checking ext facade TSparkline leakage"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_sparkline.log; \
	  exit 1; \
	fi
	@if $(FPC) $(FPC_FLAGS) -FU$(NEGATIVE_BUILD_DIR) -FE$(NEGATIVE_BUILD_DIR) \
	  $(NEGATIVE_CANVAS_SOURCE) >$(NEGATIVE_BUILD_DIR)/reject_canvas.log 2>&1; then \
	  echo "expected ext facade to reject TCanvas from full-only advanced widgets"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_canvas.log; \
	  exit 1; \
	elif ! grep -Eq 'Identifier not found.*(TCanvas|ICanvas)' \
	  $(NEGATIVE_BUILD_DIR)/reject_canvas.log; then \
	  echo "unexpected compiler failure while checking ext facade TCanvas leakage"; \
	  cat $(NEGATIVE_BUILD_DIR)/reject_canvas.log; \
	  exit 1; \
	fi

test: run negative

clean:
	rm -rf $(BUILD_DIR)
