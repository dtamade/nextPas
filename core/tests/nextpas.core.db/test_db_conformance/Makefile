FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.db/test_db_conformance
PROGRAM := test_db_conformance
SOURCE := $(PROGRAM).lpr
HEAPTRC_LOG ?= $(BUILD_DIR)/heaptrc.log
RUN_LOG ?= $(BUILD_DIR)/run.log
HEAPTRC_ENV ?= HEAPTRC=log=$(HEAPTRC_LOG)
PG_TEST_DB ?= nextpas_pg_test
PG_TEST_USER ?= $(USER)
PG_TEST_CONN ?= host=/var/run/postgresql dbname=$(PG_TEST_DB) user=$(PG_TEST_USER)
PG_ENV ?= NEXTPAS_PG_TEST_CONN='$(PG_TEST_CONN)'
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
.PHONY: build run test heaptrc clean ensure-db
build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)
run: build
	$(BUILD_DIR)/$(PROGRAM)
test: ensure-db run heaptrc
ensure-db:
	@psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$(PG_TEST_DB)'" | grep -q 1 || createdb $(PG_TEST_DB)
heaptrc: build
	@rm -f $(RUN_LOG) $(HEAPTRC_LOG)
	@$(PG_ENV) $(HEAPTRC_ENV) $(BUILD_DIR)/$(PROGRAM) > $(RUN_LOG) 2>&1 || { cat $(RUN_LOG); test ! -f $(HEAPTRC_LOG) || cat $(HEAPTRC_LOG); exit 1; }
	@grep -F '0 unfreed memory blocks' $(HEAPTRC_LOG) >/dev/null || { cat $(RUN_LOG); cat $(HEAPTRC_LOG); exit 1; }
	@cat $(RUN_LOG)
	@cat $(HEAPTRC_LOG)
	@printf '\ntest_db_conformance-heaptrc=pass\n'
clean:
	rm -rf $(BUILD_DIR)
