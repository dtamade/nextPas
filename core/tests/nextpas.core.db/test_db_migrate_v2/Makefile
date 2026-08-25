PROGRAM := test_db_migrate_v2
include ../../common.mk

# Preserved from the pre-common.mk homemade gate (P5l unification):
# `make run` stays environment-free - the suite skips its pg section
# gracefully when NEXTPAS_PG_TEST_CONN is absent (same as before).
# `make test` prepares the local fixture database first, then re-enters
# the gated run with the connection string injected via the command line
# (command-line variables outrank makefile assignments).
PG_TEST_DB ?= nextpas_pg_test
PG_TEST_USER ?= $(USER)
PG_TEST_CONN ?= host=/var/run/postgresql dbname=$(PG_TEST_DB) user=$(PG_TEST_USER)

.PHONY: ensure-db test
ensure-db:
	psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$(PG_TEST_DB)'" | grep -q 1 || createdb $(PG_TEST_DB)

test: ensure-db
	$(MAKE) run RUN_ENV=NEXTPAS_PG_TEST_CONN='$(PG_TEST_CONN)'
