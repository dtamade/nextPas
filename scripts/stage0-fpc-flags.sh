#!/usr/bin/env sh
# Canonical FPC unit-search flags for tools/stage0/nextpas.pas.
#
# Sourced by:
#   scripts/rebuild-compiler.sh
#   build/verify_local.sh
#   tests/run_all_tests.sh
#
# Keep -Fucompiler/lower and -Fucore/src here so CI rebuild/verify cannot drift.
# shellcheck disable=SC2034
STAGE0_FPC_FLAGS="-Fucompiler/src -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema -Fucompiler/lower -Fucompiler/ir -Fucompiler/backend -Fucompiler/toolchain -Futools/stage0 -Furtl/core/base -Furtl/core/text -Fucore/src -Ficore/src"
