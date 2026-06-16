CC ?= cc
CORE_ROOT := ../../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.http/bench_h1parser/compare_c
PROGRAM := bench_llhttp_c
SOURCE := bench_llhttp_c.c
LLHTTP_ROOT ?=
EFFECTIVE_LLHTTP_ROOT := $(if $(LLHTTP_ROOT),$(LLHTTP_ROOT),$(NEXTPAS_LLHTTP_ROOT))
EXTRA_CFLAGS ?=
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wno-unused-parameter $(EXTRA_CFLAGS)

ifeq ($(EFFECTIVE_LLHTTP_ROOT),)
LLHTTP_INCLUDE_DIR :=
LLHTTP_SOURCES :=
else ifneq ($(wildcard $(EFFECTIVE_LLHTTP_ROOT)/include/llhttp.h),)
LLHTTP_INCLUDE_DIR := $(EFFECTIVE_LLHTTP_ROOT)/include
LLHTTP_SOURCES := $(EFFECTIVE_LLHTTP_ROOT)/src/api.c $(EFFECTIVE_LLHTTP_ROOT)/src/http.c $(EFFECTIVE_LLHTTP_ROOT)/src/llhttp.c
else ifneq ($(wildcard $(EFFECTIVE_LLHTTP_ROOT)/llhttp.h),)
LLHTTP_INCLUDE_DIR := $(EFFECTIVE_LLHTTP_ROOT)
LLHTTP_SOURCES := $(EFFECTIVE_LLHTTP_ROOT)/api.c $(EFFECTIVE_LLHTTP_ROOT)/http.c $(EFFECTIVE_LLHTTP_ROOT)/llhttp.c
else
LLHTTP_INCLUDE_DIR := $(EFFECTIVE_LLHTTP_ROOT)/build
LLHTTP_SOURCES := $(EFFECTIVE_LLHTTP_ROOT)/src/native/api.c $(EFFECTIVE_LLHTTP_ROOT)/src/native/http.c $(EFFECTIVE_LLHTTP_ROOT)/build/c/llhttp.c
endif

.PHONY: build run clean check-root

check-root:
	@test -n "$(EFFECTIVE_LLHTTP_ROOT)" || { \
	  echo "LLHTTP_ROOT is required. Point it at llhttp 9.4.1 sources."; \
	  echo "NEXTPAS_LLHTTP_ROOT is also accepted as a fallback."; \
	  echo "Supported layouts:"; \
	  echo "  LLHTTP_ROOT/{llhttp.h,api.c,http.c,llhttp.c}"; \
	  echo "  LLHTTP_ROOT/{include/llhttp.h,src/api.c,src/http.c,src/llhttp.c}"; \
	  echo "  LLHTTP_ROOT/{build/llhttp.h,src/native/api.c,src/native/http.c,build/c/llhttp.c}"; \
	  exit 2; \
	}
	@test -f "$(LLHTTP_INCLUDE_DIR)/llhttp.h" || { \
	  echo "llhttp.h not found under LLHTTP_ROOT=$(EFFECTIVE_LLHTTP_ROOT)"; \
	  exit 2; \
	}
	@for src in $(LLHTTP_SOURCES); do \
	  test -f "$$src" || { echo "llhttp source missing: $$src"; exit 2; }; \
	done

build: check-root
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -I$(LLHTTP_INCLUDE_DIR) $(SOURCE) $(LLHTTP_SOURCES) -o $(BUILD_DIR)/$(PROGRAM)

run: build
	$(BUILD_DIR)/$(PROGRAM)

clean:
	rm -rf $(BUILD_DIR)
