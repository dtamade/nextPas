#!/usr/bin/env sh

set -eu

case "$0" in
  */*)
    SCRIPT_PATH="$0"
    ;;
  *)
    SCRIPT_PATH="./$0"
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TARGET_ID="linux-x86_64"
VERIFY_SELECTOR="verify-local"
STAGE0_FPC_FLAGS="-Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Fucompiler/backend -Fucompiler/toolchain -Futools/stage0 -Furtl/core/base -Furtl/core/text"
LEX_SNAPSHOT_FPC_FLAGS="-Fucompiler/syntax -Furtl/core/base -Furtl/core/text"
STAGE0_BUILD_DIR="$REPO_ROOT/.sisyphus/tmp/stage0-bootstrap"
LEX_SNAPSHOT_BUILD_DIR="$REPO_ROOT/.sisyphus/tmp/lex_snapshot"
LEX_SNAPSHOT_BINARY="$LEX_SNAPSHOT_BUILD_DIR/lex_snapshot"
STAGE0_BINARY="$STAGE0_BUILD_DIR/nextpas"
WORKSPACE_ARTIFACT_ROOT="$REPO_ROOT/.nextpas"
HOST_FPC_CACHE_ROOT="$WORKSPACE_ARTIFACT_ROOT/cache/host-fpc/$TARGET_ID"
PACKAGE_MANIFEST_FIXTURE_ROOT="$REPO_ROOT/tests/fixtures/package_manifest_source_root"
PACKAGE_MANIFEST_ARTIFACT_ROOT="$PACKAGE_MANIFEST_FIXTURE_ROOT/.nextpas"
WORKSPACE_MEMBER_FIXTURE_ROOT="$REPO_ROOT/tests/fixtures/workspace_member_source_root"
WORKSPACE_MEMBER_ARTIFACT_ROOT="$WORKSPACE_MEMBER_FIXTURE_ROOT/.nextpas"
STAGE0_SMOKE_OUTPUT=$(mktemp)
STAGE0_SMOKE_REPEAT_OUTPUT=$(mktemp)
LLVM_BINDING_SMOKE_OUTPUT=$(mktemp)
LLVM_EMPTY_PROGRAM_OUTPUT=$(mktemp)
LLVM_EMPTY_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_HALT_EXPR_PROGRAM_OUTPUT=$(mktemp)
LLVM_HALT_EXPR_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_HALT_CONST_PROGRAM_OUTPUT=$(mktemp)
LLVM_HALT_CONST_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_WRITELN_PROGRAM_OUTPUT=$(mktemp)
LLVM_WRITELN_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_WRITELN_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_WRITELN_INT_PROGRAM_OUTPUT=$(mktemp)
LLVM_WRITELN_INT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_WRITELN_INT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_WRITELN_MULTI_PROGRAM_OUTPUT=$(mktemp)
LLVM_WRITELN_MULTI_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_WRITELN_MULTI_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_WRITELN_MIXED_PROGRAM_OUTPUT=$(mktemp)
LLVM_WRITELN_MIXED_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_WRITELN_MIXED_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_HELLO_THEN_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_HELLO_THEN_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_HELLO_THEN_HALT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_VAR_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_VAR_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_VAR_HALT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_NO_FOLD_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_IF_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_IF_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_IF_ELSE_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_IF_ELSE_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_IF_VAR_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_IF_VAR_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_REPEAT_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_REPEAT_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_WHILE_SUM_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_WHILE_SUM_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_FOR_SUM_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_FOR_SUM_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_OUTPUT=$(mktemp)
LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_VAR_WRITELN_PROGRAM_OUTPUT=$(mktemp)
LLVM_VAR_WRITELN_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_VAR_WRITELN_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_VAR_CHAIN_PROGRAM_OUTPUT=$(mktemp)
LLVM_VAR_CHAIN_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_VAR_CHAIN_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_IF_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_IF_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_IF_HALT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_IF_ELSE_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_IF_ELSE_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_IF_ELSE_HALT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_IF_VAR_PROGRAM_OUTPUT=$(mktemp)
LLVM_IF_VAR_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_IF_VAR_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_FOR_WRITELN_PROGRAM_OUTPUT=$(mktemp)
LLVM_FOR_WRITELN_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_FOR_WRITELN_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_FOR_SUM_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_FOR_SUM_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_FOR_SUM_HALT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_FOR_DOWNTO_PROGRAM_OUTPUT=$(mktemp)
LLVM_FOR_DOWNTO_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_FOR_DOWNTO_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_IF_NOT_PROGRAM_OUTPUT=$(mktemp)
LLVM_IF_NOT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_IF_TRUE_PROGRAM_OUTPUT=$(mktemp)
LLVM_IF_TRUE_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_WHILE_COUNT_PROGRAM_OUTPUT=$(mktemp)
LLVM_WHILE_COUNT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_WHILE_COUNT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_WHILE_SUM_PROGRAM_OUTPUT=$(mktemp)
LLVM_WHILE_SUM_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_WHILE_SUM_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_REPEAT_COUNT_PROGRAM_OUTPUT=$(mktemp)
LLVM_REPEAT_COUNT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_REPEAT_COUNT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_REPEAT_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_REPEAT_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_CONST_STRING_PROGRAM_OUTPUT=$(mktemp)
LLVM_CONST_STRING_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_CONST_STRING_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_STRING_CONCAT_PROGRAM_OUTPUT=$(mktemp)
LLVM_STRING_CONCAT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_STRING_CONCAT_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_PROC_GREET_PROGRAM_OUTPUT=$(mktemp)
LLVM_PROC_GREET_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_PROC_GREET_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_PROC_TWO_PROGRAM_OUTPUT=$(mktemp)
LLVM_PROC_TWO_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_PROC_TWO_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_FN_CONST_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_FN_CONST_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_FN_COMPOSE_PROGRAM_OUTPUT=$(mktemp)
LLVM_FN_COMPOSE_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_FN_CALL_HALT_PROGRAM_OUTPUT=$(mktemp)
LLVM_FN_CALL_HALT_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_FN_CALL_CHAIN_PROGRAM_OUTPUT=$(mktemp)
LLVM_FN_CALL_CHAIN_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_PROC_ARG_PROGRAM_OUTPUT=$(mktemp)
LLVM_PROC_ARG_PROGRAM_OUT_DIR=$(mktemp -d)
LLVM_PROC_ARG_PROGRAM_RUN_OUTPUT=$(mktemp)
LLVM_FN_SQUARE_PROGRAM_OUTPUT=$(mktemp)
LLVM_FN_SQUARE_PROGRAM_OUT_DIR=$(mktemp -d)
SEMANTIC_SMOKE_OUTPUT=$(mktemp)
FOREIGN_CDECL_SMOKE_OUTPUT=$(mktemp)
HARNESS_SMOKE_OUTPUT=$(mktemp)
HARNESS_COMPILER_PASS_OUTPUT=$(mktemp)
STAGE0_TEST_LIST_GROUPS_OUTPUT=$(mktemp)
STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT=$(mktemp)
STAGE0_TEST_UNKNOWN_GROUP_OUTPUT=$(mktemp)
STAGE0_TEST_COMPILER_PASS_OUTPUT=$(mktemp)
STAGE0_TEST_SMOKE_OUTPUT=$(mktemp)
STAGE0_ENV_STATUS_OUTPUT=$(mktemp)
STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT=$(mktemp)
STAGE0_DOCTOR_OUTPUT=$(mktemp)
STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT=$(mktemp)
STAGE0_QUERY_SYMBOLS_OUTPUT=$(mktemp)
STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT=$(mktemp)
STAGE0_PKG_INSPECT_OUTPUT=$(mktemp)
STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT=$(mktemp)
CORE_TEXT_SMOKE_OUTPUT=$(mktemp)
TOOLCHAIN_CONTRACT_OUTPUT=$(mktemp)
TOOLCHAIN_CONTRACT_BUILD_DIR=$(mktemp -d)
TOOLCHAIN_CONTRACT_BINARY="$TOOLCHAIN_CONTRACT_BUILD_DIR/toolchain_contract_smoke"
LLVM_BINDING_SMOKE_BIN_DIR=$(mktemp -d)
TOOLCHAIN_FAILURE_OUTPUT=$(mktemp)
TOOLCHAIN_FAILURE_BIN_DIR=$(mktemp -d)
ASSEMBLER_FAILURE_OUTPUT=$(mktemp)
ASSEMBLER_FAILURE_BIN_DIR=$(mktemp -d)
LINKER_FAILURE_OUTPUT=$(mktemp)
LINKER_FAILURE_BIN_DIR=$(mktemp -d)
HARNESS_BOOTSTRAP_FAILURE_OUTPUT=$(mktemp)
HARNESS_BOOTSTRAP_FAKE_FPC_DIR=$(mktemp -d)
SYNTAX_FAILURE_OUTPUT=$(mktemp)
MISSING_UNIT_OUTPUT=$(mktemp)
AMBIGUOUS_UNIT_OUTPUT=$(mktemp)
MULTIPLE_MISSING_OUTPUT=$(mktemp)
UNIT_CYCLE_OUTPUT=$(mktemp)
DUPLICATE_IMPORT_OUTPUT=$(mktemp)
MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT=$(mktemp)
ROOT_IMPLEMENTATION_OUTPUT=$(mktemp)
REQUESTED_NAME_MISMATCH_OUTPUT=$(mktemp)
EXPLICIT_SYSTEM_OUTPUT=$(mktemp)
EXPLICIT_UNIT_ROOT_OUTPUT=$(mktemp)
PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT=$(mktemp)
WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT=$(mktemp)
PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT=$(mktemp)
SOURCE_DIRECTORY_FALLBACK_OUTPUT=$(mktemp)
OUT_DIR_OVERRIDE_OUTPUT=$(mktemp)
ROOT_SOURCE_PRECEDENCE_OUTPUT=$(mktemp)
UNIT_ROOT_PRECEDENCE_OUTPUT=$(mktemp)
INVALID_UNIT_ROOT_OUTPUT=$(mktemp)
INVALID_OUT_DIR_OUTPUT=$(mktemp)
INVALID_ARTIFACT_ROOT_OUTPUT=$(mktemp)
SOURCE_DIRECTORY_FALLBACK_WORKSPACE=$(mktemp -d)
OUT_DIR_OVERRIDE_DIR=$(mktemp -d)
ROOT_SOURCE_PRECEDENCE_DIR=$(mktemp -d)
UNIT_ROOT_PRECEDENCE_DIR=$(mktemp -d)
INVALID_OUT_DIR_PATH=$(mktemp)
INVALID_ARTIFACT_ROOT_WORKSPACE=$(mktemp -d)
EXPLICIT_UNIT_ROOT_RUN_OUTPUT=$(mktemp)
PACKAGE_MANIFEST_SOURCE_ROOT_RUN_OUTPUT=$(mktemp)
WORKSPACE_MEMBER_SOURCE_ROOT_RUN_OUTPUT=$(mktemp)
PACKAGE_MANIFEST_SOURCE_PRECEDENCE_RUN_OUTPUT=$(mktemp)
SOURCE_DIRECTORY_FALLBACK_RUN_OUTPUT=$(mktemp)
OUT_DIR_OVERRIDE_RUN_OUTPUT=$(mktemp)
ROOT_SOURCE_PRECEDENCE_RUN_OUTPUT=$(mktemp)
UNIT_ROOT_PRECEDENCE_RUN_OUTPUT=$(mktemp)

cleanup() {
  rm -f "$STAGE0_SMOKE_OUTPUT"
  rm -f "$STAGE0_SMOKE_REPEAT_OUTPUT"
  rm -f "$LLVM_BINDING_SMOKE_OUTPUT"
  rm -f "$LLVM_EMPTY_PROGRAM_OUTPUT"
  rm -rf "$LLVM_EMPTY_PROGRAM_OUT_DIR"
  rm -f "$LLVM_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_HALT_EXPR_PROGRAM_OUTPUT"
  rm -rf "$LLVM_HALT_EXPR_PROGRAM_OUT_DIR"
  rm -f "$LLVM_HALT_CONST_PROGRAM_OUTPUT"
  rm -rf "$LLVM_HALT_CONST_PROGRAM_OUT_DIR"
  rm -f "$LLVM_WRITELN_PROGRAM_OUTPUT"
  rm -rf "$LLVM_WRITELN_PROGRAM_OUT_DIR"
  rm -f "$LLVM_WRITELN_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_WRITELN_INT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_WRITELN_INT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_WRITELN_INT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_WRITELN_MULTI_PROGRAM_OUTPUT"
  rm -rf "$LLVM_WRITELN_MULTI_PROGRAM_OUT_DIR"
  rm -f "$LLVM_WRITELN_MULTI_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_WRITELN_MIXED_PROGRAM_OUTPUT"
  rm -rf "$LLVM_WRITELN_MIXED_PROGRAM_OUT_DIR"
  rm -f "$LLVM_WRITELN_MIXED_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_HELLO_THEN_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_HELLO_THEN_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_HELLO_THEN_HALT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_VAR_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_VAR_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_VAR_HALT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_NO_FOLD_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_IF_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_IF_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_IF_ELSE_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_IF_ELSE_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_IF_VAR_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_IF_VAR_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_REPEAT_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_REPEAT_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_WHILE_SUM_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_WHILE_SUM_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_FOR_SUM_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_FOR_SUM_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_VAR_WRITELN_PROGRAM_OUTPUT"
  rm -rf "$LLVM_VAR_WRITELN_PROGRAM_OUT_DIR"
  rm -f "$LLVM_VAR_WRITELN_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_VAR_CHAIN_PROGRAM_OUTPUT"
  rm -rf "$LLVM_VAR_CHAIN_PROGRAM_OUT_DIR"
  rm -f "$LLVM_VAR_CHAIN_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_IF_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_IF_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_IF_HALT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_IF_ELSE_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_IF_ELSE_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_IF_ELSE_HALT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_IF_VAR_PROGRAM_OUTPUT"
  rm -rf "$LLVM_IF_VAR_PROGRAM_OUT_DIR"
  rm -f "$LLVM_IF_VAR_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_FOR_WRITELN_PROGRAM_OUTPUT"
  rm -rf "$LLVM_FOR_WRITELN_PROGRAM_OUT_DIR"
  rm -f "$LLVM_FOR_WRITELN_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_FOR_SUM_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_FOR_SUM_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_FOR_SUM_HALT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_FOR_DOWNTO_PROGRAM_OUTPUT"
  rm -rf "$LLVM_FOR_DOWNTO_PROGRAM_OUT_DIR"
  rm -f "$LLVM_FOR_DOWNTO_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_IF_NOT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_IF_NOT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_IF_TRUE_PROGRAM_OUTPUT"
  rm -rf "$LLVM_IF_TRUE_PROGRAM_OUT_DIR"
  rm -f "$LLVM_WHILE_COUNT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_WHILE_COUNT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_WHILE_COUNT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_WHILE_SUM_PROGRAM_OUTPUT"
  rm -rf "$LLVM_WHILE_SUM_PROGRAM_OUT_DIR"
  rm -f "$LLVM_WHILE_SUM_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_REPEAT_COUNT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_REPEAT_COUNT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_REPEAT_COUNT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_REPEAT_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_REPEAT_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_CONST_STRING_PROGRAM_OUTPUT"
  rm -rf "$LLVM_CONST_STRING_PROGRAM_OUT_DIR"
  rm -f "$LLVM_CONST_STRING_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_STRING_CONCAT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_STRING_CONCAT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_STRING_CONCAT_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_PROC_GREET_PROGRAM_OUTPUT"
  rm -rf "$LLVM_PROC_GREET_PROGRAM_OUT_DIR"
  rm -f "$LLVM_PROC_GREET_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_PROC_TWO_PROGRAM_OUTPUT"
  rm -rf "$LLVM_PROC_TWO_PROGRAM_OUT_DIR"
  rm -f "$LLVM_PROC_TWO_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_FN_CONST_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_FN_CONST_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_FN_COMPOSE_PROGRAM_OUTPUT"
  rm -rf "$LLVM_FN_COMPOSE_PROGRAM_OUT_DIR"
  rm -f "$LLVM_FN_CALL_HALT_PROGRAM_OUTPUT"
  rm -rf "$LLVM_FN_CALL_HALT_PROGRAM_OUT_DIR"
  rm -f "$LLVM_FN_CALL_CHAIN_PROGRAM_OUTPUT"
  rm -rf "$LLVM_FN_CALL_CHAIN_PROGRAM_OUT_DIR"
  rm -f "$LLVM_PROC_ARG_PROGRAM_OUTPUT"
  rm -rf "$LLVM_PROC_ARG_PROGRAM_OUT_DIR"
  rm -f "$LLVM_PROC_ARG_PROGRAM_RUN_OUTPUT"
  rm -f "$LLVM_FN_SQUARE_PROGRAM_OUTPUT"
  rm -rf "$LLVM_FN_SQUARE_PROGRAM_OUT_DIR"
  rm -f "$SEMANTIC_SMOKE_OUTPUT"
  rm -f "$FOREIGN_CDECL_SMOKE_OUTPUT"
  rm -f "$HARNESS_SMOKE_OUTPUT"
  rm -f "$HARNESS_COMPILER_PASS_OUTPUT"
  rm -f "$STAGE0_TEST_LIST_GROUPS_OUTPUT"
  rm -f "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT"
  rm -f "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT"
  rm -f "$STAGE0_TEST_COMPILER_PASS_OUTPUT"
  rm -f "$STAGE0_TEST_SMOKE_OUTPUT"
  rm -f "$STAGE0_ENV_STATUS_OUTPUT"
  rm -f "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT"
  rm -f "$STAGE0_DOCTOR_OUTPUT"
  rm -f "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT"
  rm -f "$STAGE0_QUERY_SYMBOLS_OUTPUT"
  rm -f "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT"
  rm -f "$STAGE0_PKG_INSPECT_OUTPUT"
  rm -f "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT"
  rm -f "$CORE_TEXT_SMOKE_OUTPUT"
  rm -f "$TOOLCHAIN_CONTRACT_OUTPUT"
  rm -rf "$TOOLCHAIN_CONTRACT_BUILD_DIR"
  rm -f "$TOOLCHAIN_FAILURE_OUTPUT"
  rm -f "$ASSEMBLER_FAILURE_OUTPUT"
  rm -f "$LINKER_FAILURE_OUTPUT"
  rm -f "$HARNESS_BOOTSTRAP_FAILURE_OUTPUT"
  rm -rf "$HARNESS_BOOTSTRAP_FAKE_FPC_DIR"
  rm -f "$SYNTAX_FAILURE_OUTPUT"
  rm -f "$MISSING_UNIT_OUTPUT"
  rm -f "$AMBIGUOUS_UNIT_OUTPUT"
  rm -f "$MULTIPLE_MISSING_OUTPUT"
  rm -f "$UNIT_CYCLE_OUTPUT"
  rm -f "$DUPLICATE_IMPORT_OUTPUT"
  rm -f "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT"
  rm -f "$ROOT_IMPLEMENTATION_OUTPUT"
  rm -f "$REQUESTED_NAME_MISMATCH_OUTPUT"
  rm -f "$EXPLICIT_SYSTEM_OUTPUT"
  rm -f "$EXPLICIT_UNIT_ROOT_OUTPUT"
  rm -f "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT"
  rm -f "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT"
  rm -f "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT"
  rm -f "$SOURCE_DIRECTORY_FALLBACK_OUTPUT"
  rm -f "$OUT_DIR_OVERRIDE_OUTPUT"
  rm -f "$ROOT_SOURCE_PRECEDENCE_OUTPUT"
  rm -f "$UNIT_ROOT_PRECEDENCE_OUTPUT"
  rm -f "$INVALID_UNIT_ROOT_OUTPUT"
  rm -f "$INVALID_OUT_DIR_OUTPUT"
  rm -f "$INVALID_ARTIFACT_ROOT_OUTPUT"
  rm -f "$EXPLICIT_UNIT_ROOT_RUN_OUTPUT"
  rm -f "$PACKAGE_MANIFEST_SOURCE_ROOT_RUN_OUTPUT"
  rm -f "$WORKSPACE_MEMBER_SOURCE_ROOT_RUN_OUTPUT"
  rm -f "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_RUN_OUTPUT"
  rm -f "$SOURCE_DIRECTORY_FALLBACK_RUN_OUTPUT"
  rm -f "$OUT_DIR_OVERRIDE_RUN_OUTPUT"
  rm -f "$ROOT_SOURCE_PRECEDENCE_RUN_OUTPUT"
  rm -f "$UNIT_ROOT_PRECEDENCE_RUN_OUTPUT"
  rm -f "$INVALID_OUT_DIR_PATH"
  rm -rf "$LLVM_BINDING_SMOKE_BIN_DIR"
  rm -rf "$TOOLCHAIN_FAILURE_BIN_DIR"
  rm -rf "$ASSEMBLER_FAILURE_BIN_DIR"
  rm -rf "$LINKER_FAILURE_BIN_DIR"
  rm -rf "$SOURCE_DIRECTORY_FALLBACK_WORKSPACE"
  rm -rf "$OUT_DIR_OVERRIDE_DIR"
  rm -rf "$ROOT_SOURCE_PRECEDENCE_DIR"
  rm -rf "$UNIT_ROOT_PRECEDENCE_DIR"
  rm -rf "$INVALID_ARTIFACT_ROOT_WORKSPACE"
  rm -rf "$WORKSPACE_ARTIFACT_ROOT"
  rm -rf "$PACKAGE_MANIFEST_ARTIFACT_ROOT"
  rm -rf "$WORKSPACE_MEMBER_ARTIFACT_ROOT"
  rm -rf "$STAGE0_BUILD_DIR"
  rm -rf "$LEX_SNAPSHOT_BUILD_DIR"
}

trap cleanup EXIT HUP INT TERM

fail() {
  human_summary="$1"
  failure_kind=${human_summary%%:*}

  printf 'selector=%s\n' "$VERIFY_SELECTOR" >&2
  printf 'target=%s\n' "$TARGET_ID" >&2
  printf 'status=failure\n' >&2
  printf 'result=failure\n' >&2
  printf 'failure-kind=%s\n' "$failure_kind" >&2
  printf 'command-outcome=failure\n' >&2
  printf 'command-envelope={"command":"verify-local","exitCode":1,"result":{"selector":"%s","target":"%s","status":"failure","result":"failure","failureKind":"%s"},"diagnostics":[],"buildTraceRef":null,"humanSummary":"%s"}\n' "$VERIFY_SELECTOR" "$TARGET_ID" "$failure_kind" "$human_summary" >&2
  printf 'human-summary=%s\n' "$human_summary" >&2
  printf '%s\n' "$human_summary" >&2
  exit 1
}

require_path() {
  path="$1"
  if [ ! -e "$path" ]; then
    fail "missing-required-path: $path"
  fi

  printf 'verified-path=%s\n' "$path"
}

require_executable() {
  path="$1"
  if [ ! -x "$path" ]; then
    fail "missing-executable-path: $path"
  fi

  printf 'verified-executable=%s\n' "$path"
}

require_absent_path() {
  path="$1"
  if [ -e "$path" ]; then
    fail "unexpected-generated-path: $path"
  fi
}

require_output_pattern() {
  pattern="$1"
  file_path="$2"
  failure_kind="$3"

  if ! grep -Eq "$pattern" "$file_path"; then
    fail "$failure_kind"
  fi
}

require_output_literal() {
  literal="$1"
  file_path="$2"
  failure_kind="$3"

  if ! grep -Fq "$literal" "$file_path"; then
    fail "$failure_kind"
  fi
}

extract_output_value() {
  key="$1"
  file_path="$2"

  sed -n "s/^$key=//p" "$file_path" | head -n 1
}

run_stage0_build_capture() {
  output_file="$1"
  shift

  NEXTPAS_REPO_ROOT="$REPO_ROOT" \
    "$STAGE0_BINARY" build "$@" --fold --target "$TARGET_ID" --workspace "$REPO_ROOT" \
    >"$output_file" 2>&1
}

require_linux_x86_64() {
  host_os=$(uname -s | tr '[:upper:]' '[:lower:]')
  host_cpu=$(uname -m)

  printf 'host-os=%s\n' "$host_os"
  printf 'host-cpu=%s\n' "$host_cpu"

  if [ "$host_os" != "linux" ]; then
    fail "unsupported-host-os: $host_os"
  fi

  if [ "$host_cpu" != "x86_64" ]; then
    fail "unsupported-host-cpu: $host_cpu"
  fi
}

cd "$REPO_ROOT"

printf 'mode=verify-local\n'
printf 'command=verify-local\n'
printf 'selector=%s\n' "$VERIFY_SELECTOR"
printf 'target=%s\n' "$TARGET_ID"

require_linux_x86_64

printf 'docs-check=running\n'
for path in \
  docs/adr/0001-fpc-reference-baseline.md \
  docs/architecture/overview.md \
  docs/architecture/compatibility-matrix.md \
  docs/architecture/directory-structure-specification.md \
  docs/architecture/bootstrap-roadmap.md \
  docs/architecture/compiler-specification.md \
  docs/architecture/compiler-pipeline-specification.md \
  docs/architecture/lexer-specification.md \
  docs/architecture/diagnostics-specification.md \
  docs/architecture/fpc-source-grounding-specification.md \
  docs/architecture/test-harness-specification.md \
  docs/architecture/stage0-driver-specification.md \
  docs/architecture/target-platform-specification.md \
  docs/architecture/rtl-specification.md \
  docs/architecture/crt-specification.md \
  docs/architecture/distribution-layout-specification.md
do
  require_path "$path"
done
printf 'docs-check=pass\n'

printf 'inputs-check=running\n'
require_path build/targets/linux-x86_64.toml
require_path build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml
require_path tools/stage0/nextpas.pas
require_path compiler/frontend/np_source_database.pas
require_path compiler/frontend/np_compilation_session.pas
require_path compiler/frontend/np_unit_graph.pas
require_path compiler/frontend/np_unit_resolver.pas
require_path compiler/diagnostics/np_diagnostics_sink.pas
require_path compiler/targets/np_target_facts.pas
require_path compiler/syntax/np_lexer.pas
require_path compiler/syntax/np_green_tree.pas
require_path compiler/syntax/np_ast_facade.pas
require_path compiler/sema/np_semantic_model.pas
require_path compiler/sema/np_semantic_analyzer.pas
require_path compiler/ir/np_mir_model.pas
require_path compiler/backend/np_backend_plan.pas
require_path compiler/toolchain/np_toolchain_runner.pas
require_path tests/toolchain/toolchain_contract_smoke.pas
require_path rtl/core/base/np_base_types.pas
require_path rtl/core/mem/np_allocator.pas
require_path rtl/core/text/np_text_primitives.pas
require_path examples/smoke/hello_with_units.pas
require_path examples/smoke/external_cdecl_smoke.pas
require_path tests/rtl/core_text_smoke.pas
require_path tests/compiler/fail/missing_unit_fail.pas
require_path tests/compiler/fail/ambiguous_unit_fail.pas
require_path tests/compiler/fail/multiple_missing_units_fail.pas
require_path tests/compiler/fail/unit_cycle_fail.pas
require_path tests/compiler/fail/duplicate_unit_import_fail.pas
require_path tests/compiler/fail/missing_external_symbol_name_fail.pas
require_path tests/compiler/fail/root_implementation_missing_unit_fail.pas
require_path tests/compiler/fail/requested_name_mismatch_fail.pas
require_path tests/compiler/fail/WrongNameHelper.pas
require_path tests/compiler/fail/explicit_system_missing_unit_fail.pas
require_path tests/compiler/fail/System.pas
require_path tests/fixtures/explicit_unit_root_smoke.pas
require_path tests/fixtures/unit_roots/UnitRootGreeter.pas
require_path tests/fixtures/workspace_member_source_root/nextpas.workspace.toml
require_path tests/fixtures/workspace_member_source_root/app/nextpas.package.toml
require_path tests/fixtures/workspace_member_source_root/app/app/workspace_member_source_root_smoke.pas
require_path tests/fixtures/workspace_member_source_root/shared/nextpas.package.toml
require_path tests/fixtures/workspace_member_source_root/shared/src/WorkspaceMemberGreeter.pas
require_path tests/fixtures/root_source_precedence/root_source_precedence_smoke.pas
require_path tests/fixtures/root_source_precedence/PriorityGreeter.pas
require_path tests/fixtures/root_source_precedence/explicit/PriorityGreeter.pas
require_path tests/fixtures/unit_root_precedence/unit_root_precedence_smoke.pas
require_path tests/fixtures/unit_root_precedence/explicit/Stage0Greeter.pas
require_path tests/snapshots/compiler-fail-missing_unit.stderr.txt
require_path tests/snapshots/compiler-fail-ambiguous_unit.stderr.txt
require_path tests/snapshots/compiler-fail-unit_cycle.stderr.txt
require_path tests/snapshots/compiler-fail-duplicate_unit_import.stderr.txt
require_path tests/snapshots/compiler-fail-missing_external_symbol_name.stderr.txt
require_path tests/snapshots/compiler-fail-root_implementation_missing_unit.stderr.txt
require_path tests/snapshots/compiler-fail-requested_name_mismatch.stderr.txt
require_path tests/snapshots/compiler-fail-explicit_system_missing_unit.stderr.txt
require_path units/linux-x86_64/Stage0Greeter.pas
require_path units/linux-x86_64/Stage0GreeterImpl.pas
require_path units/linux-x86_64/CycleA.pas
require_path units/linux-x86_64/CycleB.pas
require_path units/linux-x86_64/AmbiguousHelper.pas
require_path units/linux-x86_64/AMBIGUOUSHELPER.pas
require_executable tests/run_all_tests.sh
printf 'inputs-check=pass\n'

if ! command -v fpc >/dev/null 2>&1; then
  fail 'missing-compiler: fpc'
fi

printf 'stage0-build=running\n'
printf 'stage0-compiler=fpc\n'
mkdir -p "$STAGE0_BUILD_DIR"
printf 'stage0-command=fpc %s -FE%s -FU%s tools/stage0/nextpas.pas\n' "$STAGE0_FPC_FLAGS" "$STAGE0_BUILD_DIR" "$STAGE0_BUILD_DIR"
fpc $STAGE0_FPC_FLAGS -FE"$STAGE0_BUILD_DIR" -FU"$STAGE0_BUILD_DIR" tools/stage0/nextpas.pas
printf 'stage0-build=pass\n'

printf 'lexer-conformance=running\n'
mkdir -p "$LEX_SNAPSHOT_BUILD_DIR"
printf 'lex-snapshot-command=fpc %s -FE%s -FU%s tools/lexer_snapshot/lex_snapshot.pas\n' "$LEX_SNAPSHOT_FPC_FLAGS" "$LEX_SNAPSHOT_BUILD_DIR" "$LEX_SNAPSHOT_BUILD_DIR"
if ! fpc $LEX_SNAPSHOT_FPC_FLAGS -FE"$LEX_SNAPSHOT_BUILD_DIR" -FU"$LEX_SNAPSHOT_BUILD_DIR" tools/lexer_snapshot/lex_snapshot.pas >/dev/null 2>&1; then
  fpc $LEX_SNAPSHOT_FPC_FLAGS -FE"$LEX_SNAPSHOT_BUILD_DIR" -FU"$LEX_SNAPSHOT_BUILD_DIR" tools/lexer_snapshot/lex_snapshot.pas
  fail 'lexer-snapshot-build-failed'
fi
if [ ! -x "$LEX_SNAPSHOT_BINARY" ]; then
  fail 'missing-lexer-snapshot-binary'
fi
LEX_FIXTURES_PASS=0
LEX_FIXTURES_FAIL=0
for fixture in tests/lexer/*.pas; do
  golden="${fixture%.pas}.tokens"
  if [ ! -f "$golden" ]; then
    printf 'lexer-conformance-missing-golden=%s\n' "$golden"
    LEX_FIXTURES_FAIL=$((LEX_FIXTURES_FAIL + 1))
    continue
  fi
  actual=$(mktemp)
  if ! "$LEX_SNAPSHOT_BINARY" "$fixture" >"$actual" 2>&1; then
    cat "$actual"
    rm -f "$actual"
    printf 'lexer-conformance-snapshot-failed=%s\n' "$fixture"
    LEX_FIXTURES_FAIL=$((LEX_FIXTURES_FAIL + 1))
    continue
  fi
  if ! diff -u "$golden" "$actual" >/dev/null 2>&1; then
    printf 'lexer-conformance-diff=%s\n' "$fixture"
    diff -u "$golden" "$actual" || true
    rm -f "$actual"
    LEX_FIXTURES_FAIL=$((LEX_FIXTURES_FAIL + 1))
    continue
  fi
  rm -f "$actual"
  trivia_golden="${fixture%.pas}.tokens.trivia"
  if [ -f "$trivia_golden" ]; then
    actual_trivia=$(mktemp)
    if ! "$LEX_SNAPSHOT_BINARY" --trivia "$fixture" >"$actual_trivia" 2>&1; then
      cat "$actual_trivia"
      rm -f "$actual_trivia"
      printf 'lexer-conformance-trivia-snapshot-failed=%s\n' "$fixture"
      LEX_FIXTURES_FAIL=$((LEX_FIXTURES_FAIL + 1))
      continue
    fi
    if ! diff -u "$trivia_golden" "$actual_trivia" >/dev/null 2>&1; then
      printf 'lexer-conformance-trivia-diff=%s\n' "$fixture"
      diff -u "$trivia_golden" "$actual_trivia" || true
      rm -f "$actual_trivia"
      LEX_FIXTURES_FAIL=$((LEX_FIXTURES_FAIL + 1))
      continue
    fi
    rm -f "$actual_trivia"
  fi
  LEX_FIXTURES_PASS=$((LEX_FIXTURES_PASS + 1))
done
printf 'lexer-conformance-fixtures-pass=%s\n' "$LEX_FIXTURES_PASS"
printf 'lexer-conformance-fixtures-fail=%s\n' "$LEX_FIXTURES_FAIL"
if [ "$LEX_FIXTURES_FAIL" -ne 0 ]; then
  fail 'lexer-conformance-fixtures-failed'
fi
printf 'lexer-conformance=pass\n'

printf 'stage0-smoke=running\n'
printf 'stage0-smoke-command=%s build examples/smoke/hello.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if ! run_stage0_build_capture "$STAGE0_SMOKE_OUTPUT" examples/smoke/hello.pas; then
  cat "$STAGE0_SMOKE_OUTPUT"
  fail 'stage0-smoke-build-failed'
fi
cat "$STAGE0_SMOKE_OUTPUT"
if ! grep -q '^command-envelope=' "$STAGE0_SMOKE_OUTPUT"; then
  fail 'missing-stage0-command-envelope'
fi
require_output_pattern '^session-id=' "$STAGE0_SMOKE_OUTPUT" 'missing-compilation-session-id'
require_output_pattern '^source-db-file-count=1$' "$STAGE0_SMOKE_OUTPUT" 'missing-source-database-count'
require_output_pattern '^diagnostics-count=0$' "$STAGE0_SMOKE_OUTPUT" 'missing-diagnostics-sink-count'
require_output_pattern '^diagnostics-error-count=0$' "$STAGE0_SMOKE_OUTPUT" 'missing-diagnostics-error-count'
require_output_pattern '^diagnostics-warning-count=0$' "$STAGE0_SMOKE_OUTPUT" 'missing-diagnostics-warning-count'
require_output_pattern '^lifecycle-session=' "$STAGE0_SMOKE_OUTPUT" 'missing-session-lifecycle-summary'
require_output_pattern '"sessionId"' "$STAGE0_SMOKE_OUTPUT" 'missing-session-envelope-field'
require_output_pattern '^syntax-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-syntax-ready-status'
require_output_pattern '^lexer-token-count=' "$STAGE0_SMOKE_OUTPUT" 'missing-lexer-token-count'
require_output_pattern '^green-node-count=' "$STAGE0_SMOKE_OUTPUT" 'missing-green-node-count'
require_output_pattern '^ast-root-kind=program$' "$STAGE0_SMOKE_OUTPUT" 'missing-ast-root-kind'
require_output_pattern '^resolution-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-resolution-ready-status'
require_output_pattern '^semantic-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-semantic-ready-status'
require_output_pattern '^search-index-status=deferred$' "$STAGE0_SMOKE_OUTPUT" 'missing-search-index-status'
require_output_pattern '^indexed-search-root-count=0$' "$STAGE0_SMOKE_OUTPUT" 'missing-indexed-search-root-count'
require_output_pattern '^search-index-scan-count=0$' "$STAGE0_SMOKE_OUTPUT" 'missing-search-index-scan-count'
require_output_pattern '^symbol-graph-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-symbol-graph-ready-status'
require_output_pattern '^type-graph-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-type-graph-ready-status'
require_output_pattern '^typed-hir-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-typed-hir-ready-status'
require_output_pattern '^mir-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-mir-ready-status'
require_output_pattern '^backend-plan-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-backend-plan-ready-status'
require_output_pattern '^backend-artifact-count=3$' "$STAGE0_SMOKE_OUTPUT" 'missing-backend-artifact-count'
require_output_pattern '^backend-artifacts=.*"kind":"assembly-text".*"kind":"object-file".*"kind":"executable"' "$STAGE0_SMOKE_OUTPUT" 'missing-backend-artifacts'
require_output_pattern '^host-id=linux-x86_64$' "$STAGE0_SMOKE_OUTPUT" 'missing-host-id'
require_output_pattern '^toolchain-binding-id=linux-x86_64-to-linux-x86_64-gnu$' "$STAGE0_SMOKE_OUTPUT" 'missing-toolchain-binding-id'
require_output_pattern '^target-runtime-layout-key=target-sdk-split$' "$STAGE0_SMOKE_OUTPUT" 'missing-target-runtime-layout-key'
require_output_pattern '^target-c-symbol-prefix=$' "$STAGE0_SMOKE_OUTPUT" 'missing-target-c-symbol-prefix'
require_output_pattern '^target-c-library-naming=lib-prefix-so-a$' "$STAGE0_SMOKE_OUTPUT" 'missing-target-c-library-naming'
require_output_pattern '^target-llvm-triple=x86_64-unknown-linux-gnu$' "$STAGE0_SMOKE_OUTPUT" 'missing-target-llvm-triple'
require_output_pattern '^target-llvm-data-layout=e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128$' "$STAGE0_SMOKE_OUTPUT" 'missing-target-llvm-data-layout'
require_output_pattern '^sysroot-mode=runtime-sdk$' "$STAGE0_SMOKE_OUTPUT" 'missing-sysroot-mode'
require_output_pattern '^runtime-sdk-id=linux-x86_64$' "$STAGE0_SMOKE_OUTPUT" 'missing-runtime-sdk-id'
require_output_pattern '^allow-host-fallback=false$' "$STAGE0_SMOKE_OUTPUT" 'missing-allow-host-fallback'
require_output_pattern '^assembler-profile-id=gnu-as$' "$STAGE0_SMOKE_OUTPUT" 'missing-assembler-profile-id'
require_output_pattern '^linker-profile-id=gnu-ld$' "$STAGE0_SMOKE_OUTPUT" 'missing-linker-profile-id'
require_output_pattern '^archiver-profile-id=gnu-ar$' "$STAGE0_SMOKE_OUTPUT" 'missing-archiver-profile-id'
require_output_pattern '^resource-tool-profile-id=none$' "$STAGE0_SMOKE_OUTPUT" 'missing-resource-tool-profile-id'
require_output_pattern '^tool-root-kind=distribution-helper-root$' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-root-kind'
require_output_pattern '^runtime-root-kind=distribution-runtime-root$' "$STAGE0_SMOKE_OUTPUT" 'missing-runtime-root-kind'
require_output_pattern '^response-file-policy=auto$' "$STAGE0_SMOKE_OUTPUT" 'missing-response-file-policy'
require_output_pattern '^link-script-policy=when-required$' "$STAGE0_SMOKE_OUTPUT" 'missing-link-script-policy'
require_output_pattern '^toolchain-plan-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-toolchain-plan-status'
require_output_pattern '^toolchain-plan-family=bootstrap-native-assemble-link$' "$STAGE0_SMOKE_OUTPUT" 'missing-toolchain-plan-family'
require_output_pattern '^tool-profile-root=.*/build/tool-profiles$' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-profile-root'
require_output_pattern '^logical-link-request-status=ready$' "$STAGE0_SMOKE_OUTPUT" 'missing-logical-link-request-status'
require_output_pattern '^logical-link-request-output-kind=executable$' "$STAGE0_SMOKE_OUTPUT" 'missing-logical-link-request-output-kind'
require_output_pattern '^logical-link-request-library-count=0$' "$STAGE0_SMOKE_OUTPUT" 'missing-logical-link-request-library-count'
require_output_pattern '^logical-link-request=.*"objectInputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\]' "$STAGE0_SMOKE_OUTPUT" 'missing-logical-link-request-object-input'
require_output_pattern '^llvm-toolchain-status=disabled$' "$STAGE0_SMOKE_OUTPUT" 'missing-llvm-toolchain-status'
require_output_pattern '^llvm-executable-set-id=llvm-stable$' "$STAGE0_SMOKE_OUTPUT" 'missing-llvm-executable-set-id'
require_output_pattern '^tool-invocation-count=3$' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-count'
require_output_pattern '^tool-run-status=success$' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-run-status'
require_output_pattern '^tool-run-step-count=3$' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-run-step-count'
require_output_pattern '^primary-tool-run-status=success$' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-run-status'
require_output_pattern '^primary-tool-role=host-compiler$' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-role'
require_output_pattern '^primary-tool-profile-id=fpc-stage0-host$' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-profile-id'
require_output_pattern '^primary-tool-step-id=host-fpc-emit-asm$' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-step-id'
require_output_pattern '^primary-tool-logical-executable=fpc$' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-logical-executable'
require_output_pattern '^primary-tool-sysroot-ref=runtime-sdk:linux-x86_64$' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-sysroot-ref'
require_output_pattern '^primary-tool-failure-mapping=toolchain.host-compiler-exec-failed$' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-failure-mapping'
require_output_pattern '^tool-invocation-plan-ref=plan-build-linux-x86_64-.*-primary-tool$' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan-ref'
require_output_pattern '^tool-invocation-plan=.*"planKind":"tool-invocation"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan'
require_output_pattern '^tool-invocation-plan=.*"planFamily":"bootstrap-native-assemble-link"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan-family'
require_output_pattern '^tool-invocation-plan=.*"stepId":"host-fpc-emit-asm".*"stepId":"native-assemble".*"stepId":"native-link"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan-step-id'
require_output_pattern '^workspace-root=.*/nextPas$' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-workspace-root'
require_output_pattern '^workspace-discovery-kind=explicit-workspace-override$' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-workspace-discovery-kind'
require_output_pattern '^artifact-root=.*/nextPas/\.nextpas$' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-artifact-root'
require_output_pattern '^output-dir=.*/nextPas/\.nextpas/out/linux-x86_64$' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-output-dir'
require_output_pattern '^artifact=.*/\.nextpas/out/linux-x86_64/hello$' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-artifact-path'
require_output_pattern '^backend-primary-artifact-path=.*/\.nextpas/out/linux-x86_64/hello$' "$STAGE0_SMOKE_OUTPUT" 'missing-backend-primary-artifact-path'
require_output_pattern '^backend-artifacts=.*"path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.s".*"path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o".*"path":".*/\.nextpas/out/linux-x86_64/hello"' "$STAGE0_SMOKE_OUTPUT" 'missing-backend-artifact-paths'
require_output_pattern '^tool-invocation-plan=.*"-st".*"-Aas".*"-FE.*/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/examples/smoke".*"-Fu.*/units/linux-x86_64".*".*/examples/smoke/hello\.pas"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan-argv'
require_output_pattern '^tool-invocation-plan=.*"inputs":\[\{"kind":"pascal-source","path":".*/examples/smoke/hello\.pas"\}\]' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan-inputs'
require_output_pattern '^tool-invocation-plan=.*"workingDirectory":".*/\.nextpas/cache/backend/linux-x86_64"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-working-directory'
require_output_pattern '^tool-invocation-plan=.*"outputs":\[\{"kind":"assembly-text","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.s"\},\{"kind":"linker-script","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_link\.res"\}\].*"outputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\].*"outputs":\[\{"kind":"executable","path":".*/\.nextpas/out/linux-x86_64/hello"\}\]' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan-outputs'
require_output_pattern '^command-envelope=.*"workspaceRoot":".*/nextPas".*"workspaceDiscoveryKind":"explicit-workspace-override".*"artifactRoot":".*/nextPas/\.nextpas".*"outputDir":".*/nextPas/\.nextpas/out/linux-x86_64"' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-workspace-envelope'
require_output_pattern '^command-envelope=.*"diagnosticErrorCount":0.*"diagnosticWarningCount":0' "$STAGE0_SMOKE_OUTPUT" 'missing-diagnostics-count-envelope-fields'
require_output_pattern '^command-envelope=.*"searchIndexStatus":"deferred".*"indexedSearchRootCount":0.*"searchIndexScanCount":0' "$STAGE0_SMOKE_OUTPUT" 'missing-search-index-envelope-fields'
if grep -Eq '^workspace-descriptor-path=' "$STAGE0_SMOKE_OUTPUT"; then
  fail 'unexpected-stage0-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$STAGE0_SMOKE_OUTPUT"; then
  fail 'unexpected-stage0-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$STAGE0_SMOKE_OUTPUT"; then
  fail 'unexpected-stage0-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$STAGE0_SMOKE_OUTPUT"; then
  fail 'unexpected-stage0-package-manifest-envelope-field'
fi
require_output_pattern '^tool-status-event-count=10$' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-status-event-count'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"host-fpc-emit-asm"' "$STAGE0_SMOKE_OUTPUT" 'missing-host-tool-selected-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started".*"stepId":"host-fpc-emit-asm"' "$STAGE0_SMOKE_OUTPUT" 'missing-host-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"host-fpc-emit-asm".*"status":"success"' "$STAGE0_SMOKE_OUTPUT" 'missing-host-step-finished-success-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"native-assemble"' "$STAGE0_SMOKE_OUTPUT" 'missing-assemble-tool-selected-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started".*"stepId":"native-assemble"' "$STAGE0_SMOKE_OUTPUT" 'missing-assemble-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"native-assemble".*"status":"success"' "$STAGE0_SMOKE_OUTPUT" 'missing-assemble-step-finished-success-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"native-link"' "$STAGE0_SMOKE_OUTPUT" 'missing-link-tool-selected-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started".*"stepId":"native-link"' "$STAGE0_SMOKE_OUTPUT" 'missing-link-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"native-link".*"status":"success"' "$STAGE0_SMOKE_OUTPUT" 'missing-link-step-finished-success-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.plan-finished".*"stepId":"native-link".*"result":"success"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-plan-finished-success-event'
require_output_pattern '^build-trace-ref=trace-build-linux-x86_64-.*-toolchain-plan$' "$STAGE0_SMOKE_OUTPUT" 'missing-success-build-trace-ref'
require_output_pattern '^build-trace=.*"traceKind":"toolchain-build-trace"' "$STAGE0_SMOKE_OUTPUT" 'missing-success-build-trace'
require_output_pattern '^build-trace=.*"result":"success"' "$STAGE0_SMOKE_OUTPUT" 'missing-success-build-trace-result'
require_output_pattern '^build-trace=.*"steps":\[\{"stepId":"host-fpc-emit-asm".*"status":"success".*"primaryOutputs":\[\{"kind":"assembly-text","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.s"\},\{"kind":"linker-script","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_link\.res"\}\].*\{"stepId":"native-assemble".*"status":"success".*"primaryOutputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\].*\{"stepId":"native-link".*"status":"success".*"primaryOutputs":\[\{"kind":"executable","path":".*/\.nextpas/out/linux-x86_64/hello"\}\]' "$STAGE0_SMOKE_OUTPUT" 'missing-success-build-trace-transcript'
require_output_pattern '^diagnostics-summary=none$' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-smoke-diagnostics-summary'
require_output_pattern '^human-summary=build succeeded$' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-smoke-human-summary'
require_output_pattern '"hostId":"linux-x86_64"' "$STAGE0_SMOKE_OUTPUT" 'missing-host-id-envelope-field'
require_output_pattern '"targetRuntimeLayoutKey":"target-sdk-split"' "$STAGE0_SMOKE_OUTPUT" 'missing-runtime-layout-envelope-field'
require_output_pattern '"targetCSymbolPrefix":""' "$STAGE0_SMOKE_OUTPUT" 'missing-c-symbol-prefix-envelope-field'
require_output_pattern '"targetCLibraryNaming":"lib-prefix-so-a"' "$STAGE0_SMOKE_OUTPUT" 'missing-c-library-naming-envelope-field'
require_output_pattern '"targetLlvmTriple":"x86_64-unknown-linux-gnu"' "$STAGE0_SMOKE_OUTPUT" 'missing-target-llvm-triple-envelope-field'
require_output_pattern '"sysrootMode":"runtime-sdk"' "$STAGE0_SMOKE_OUTPUT" 'missing-sysroot-envelope-field'
require_output_pattern '"runtimeSdkId":"linux-x86_64"' "$STAGE0_SMOKE_OUTPUT" 'missing-runtime-sdk-envelope-field'
require_output_pattern '"allowHostFallback":false' "$STAGE0_SMOKE_OUTPUT" 'missing-allow-host-fallback-envelope-field'
require_output_pattern '"assemblerProfileId":"gnu-as"' "$STAGE0_SMOKE_OUTPUT" 'missing-assembler-profile-envelope-field'
require_output_pattern '"linkerProfileId":"gnu-ld"' "$STAGE0_SMOKE_OUTPUT" 'missing-linker-profile-envelope-field'
require_output_pattern '"archiverProfileId":"gnu-ar"' "$STAGE0_SMOKE_OUTPUT" 'missing-archiver-profile-envelope-field'
require_output_pattern '"resourceToolProfileId":"none"' "$STAGE0_SMOKE_OUTPUT" 'missing-resource-profile-envelope-field'
require_output_pattern '"toolRootKind":"distribution-helper-root"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-root-envelope-field'
require_output_pattern '"runtimeRootKind":"distribution-runtime-root"' "$STAGE0_SMOKE_OUTPUT" 'missing-runtime-root-envelope-field'
require_output_pattern '"responseFilePolicy":"auto"' "$STAGE0_SMOKE_OUTPUT" 'missing-response-file-envelope-field'
require_output_pattern '"linkScriptPolicy":"when-required"' "$STAGE0_SMOKE_OUTPUT" 'missing-link-script-envelope-field'
require_output_pattern '"toolchainPlanStatus":"ready"' "$STAGE0_SMOKE_OUTPUT" 'missing-toolchain-plan-envelope-field'
require_output_pattern '"backendArtifactCount":3' "$STAGE0_SMOKE_OUTPUT" 'missing-backend-artifact-count-envelope-field'
require_output_pattern '"backendArtifacts":\[\{"artifactId":1,"kind":"assembly-text","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello\.s"\},\{"artifactId":2,"kind":"object-file","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello\.o"\},\{"artifactId":3,"kind":"executable","path":"[^"]+/\.nextpas/out/linux-x86_64/hello"\}\]' "$STAGE0_SMOKE_OUTPUT" 'missing-backend-artifacts-envelope-field'
require_output_pattern '"toolRunStatus":"success"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-run-status-envelope-field'
require_output_pattern '"toolRunStepCount":3' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-run-step-count-envelope-field'
require_output_pattern '"primaryToolRunStatus":"success"' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-run-status-envelope-field'
require_output_pattern '"toolchainPlanFamily":"bootstrap-native-assemble-link"' "$STAGE0_SMOKE_OUTPUT" 'missing-toolchain-plan-family-envelope-field'
require_output_pattern '"toolProfileRoot":"[^"]+/build/tool-profiles"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-profile-root-envelope-field'
require_output_pattern '"logicalLinkRequest":\{"requestKind":"logical-link-request"' "$STAGE0_SMOKE_OUTPUT" 'missing-logical-link-request-envelope-field'
require_output_pattern '"logicalLinkRequest":\{.*"objectInputs":\[\{"kind":"object-file","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\]' "$STAGE0_SMOKE_OUTPUT" 'missing-logical-link-request-object-input-envelope-field'
require_output_pattern '"llvmExecutableSet":\{"contractKind":"llvm-executable-set"' "$STAGE0_SMOKE_OUTPUT" 'missing-llvm-executable-set-envelope-field'
require_output_pattern '"primaryToolProfileId":"fpc-stage0-host"' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-profile-envelope-field'
require_output_pattern '"primaryToolStepId":"host-fpc-emit-asm"' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-step-envelope-field'
require_output_pattern '"primaryToolLogicalExecutable":"fpc"' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-logical-executable-envelope-field'
require_output_pattern '"primaryToolSysrootRef":"runtime-sdk:linux-x86_64"' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-sysroot-ref-envelope-field'
require_output_pattern '"primaryToolFailureMapping":"toolchain.host-compiler-exec-failed"' "$STAGE0_SMOKE_OUTPUT" 'missing-primary-tool-failure-mapping-envelope-field'
require_output_pattern '"toolInvocationPlanRef":"plan-build-linux-x86_64-[^"]+-primary-tool"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan-ref-envelope-field'
require_output_pattern '"toolInvocationPlan":\{"planKind":"tool-invocation"' "$STAGE0_SMOKE_OUTPUT" 'missing-tool-invocation-plan-envelope-field'
require_output_pattern '"diagnosticsSummary":"none"' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-smoke-diagnostics-summary-envelope-field'
require_output_pattern '"buildTraceRef":"trace-build-linux-x86_64-[^"]+-toolchain-plan"' "$STAGE0_SMOKE_OUTPUT" 'missing-success-envelope-build-trace-ref'
require_output_pattern '"buildTrace":\{"traceKind":"toolchain-build-trace"' "$STAGE0_SMOKE_OUTPUT" 'missing-success-envelope-build-trace'
require_output_pattern '"toolStatusEvents":\[\{"eventKind":"toolchain.tool-selected"' "$STAGE0_SMOKE_OUTPUT" 'missing-success-envelope-tool-status-events'
require_output_pattern '"humanSummary":"build succeeded"' "$STAGE0_SMOKE_OUTPUT" 'missing-stage0-smoke-human-summary-envelope-field'

FIRST_STAGE0_SESSION_ID=$(extract_output_value 'session-id' "$STAGE0_SMOKE_OUTPUT")
FIRST_STAGE0_PLAN_REF=$(extract_output_value 'tool-invocation-plan-ref' "$STAGE0_SMOKE_OUTPUT")
FIRST_STAGE0_TRACE_REF=$(extract_output_value 'build-trace-ref' "$STAGE0_SMOKE_OUTPUT")
if [ -z "$FIRST_STAGE0_SESSION_ID" ] || [ -z "$FIRST_STAGE0_PLAN_REF" ] || [ -z "$FIRST_STAGE0_TRACE_REF" ]; then
  fail 'missing-stage0-derived-identifiers'
fi
require_output_literal "\"sessionId\":\"$FIRST_STAGE0_SESSION_ID\"" "$STAGE0_SMOKE_OUTPUT" 'missing-session-envelope-identifier'
require_output_literal "\"toolInvocationPlanRef\":\"$FIRST_STAGE0_PLAN_REF\"" "$STAGE0_SMOKE_OUTPUT" 'missing-plan-envelope-identifier'
require_output_literal "\"buildTraceRef\":\"$FIRST_STAGE0_TRACE_REF\"" "$STAGE0_SMOKE_OUTPUT" 'missing-trace-envelope-identifier'
require_output_literal "\"sessionId\":\"$FIRST_STAGE0_SESSION_ID\"" "$STAGE0_SMOKE_OUTPUT" 'missing-build-trace-session-identifier'
require_output_literal "\"planId\":\"$FIRST_STAGE0_PLAN_REF\"" "$STAGE0_SMOKE_OUTPUT" 'missing-build-trace-plan-identifier'

printf 'stage0-smoke-repeat=running\n'
printf 'stage0-smoke-repeat-command=%s build examples/smoke/hello.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if ! run_stage0_build_capture "$STAGE0_SMOKE_REPEAT_OUTPUT" examples/smoke/hello.pas; then
  cat "$STAGE0_SMOKE_REPEAT_OUTPUT"
  fail 'stage0-smoke-repeat-build-failed'
fi
cat "$STAGE0_SMOKE_REPEAT_OUTPUT"
SECOND_STAGE0_SESSION_ID=$(extract_output_value 'session-id' "$STAGE0_SMOKE_REPEAT_OUTPUT")
SECOND_STAGE0_PLAN_REF=$(extract_output_value 'tool-invocation-plan-ref' "$STAGE0_SMOKE_REPEAT_OUTPUT")
SECOND_STAGE0_TRACE_REF=$(extract_output_value 'build-trace-ref' "$STAGE0_SMOKE_REPEAT_OUTPUT")
if [ -z "$SECOND_STAGE0_SESSION_ID" ] || [ -z "$SECOND_STAGE0_PLAN_REF" ] || [ -z "$SECOND_STAGE0_TRACE_REF" ]; then
  fail 'missing-stage0-repeat-derived-identifiers'
fi
if [ "$FIRST_STAGE0_SESSION_ID" = "$SECOND_STAGE0_SESSION_ID" ]; then
  fail 'non-unique-compilation-session-id'
fi
if [ "$FIRST_STAGE0_PLAN_REF" = "$SECOND_STAGE0_PLAN_REF" ]; then
  fail 'non-unique-tool-invocation-plan-ref'
fi
if [ "$FIRST_STAGE0_TRACE_REF" = "$SECOND_STAGE0_TRACE_REF" ]; then
  fail 'non-unique-build-trace-ref'
fi
printf 'stage0-smoke-repeat=pass\n'
require_absent_path "$REPO_ROOT/examples/smoke/hello"
require_absent_path "$REPO_ROOT/examples/smoke/hello.o"
printf 'stage0-smoke=pass\n'

printf 'llvm-binding-smoke=running\n'
cat >"$LLVM_BINDING_SMOKE_BIN_DIR/opt" <<'EOF'
#!/bin/sh
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    out="$2"
    shift 2
    continue
  fi
  shift
done
printf "fake-bitcode\n" > "$out"
EOF
chmod +x "$LLVM_BINDING_SMOKE_BIN_DIR/opt"
cat >"$LLVM_BINDING_SMOKE_BIN_DIR/llc" <<'EOF'
#!/bin/sh
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    out="$2"
    shift 2
    continue
  fi
  shift
done
printf "fake-object\n" > "$out"
EOF
chmod +x "$LLVM_BINDING_SMOKE_BIN_DIR/llc"
cat >"$LLVM_BINDING_SMOKE_BIN_DIR/ld" <<'EOF'
#!/bin/sh
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    out="$2"
    shift 2
    continue
  fi
  shift
done
printf "fake-linked\n" > "$out"
EOF
chmod +x "$LLVM_BINDING_SMOKE_BIN_DIR/ld"
printf 'llvm-binding-smoke-command=PATH=%s %s build examples/smoke/hello.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s\n' "$LLVM_BINDING_SMOKE_BIN_DIR" "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT"
if ! PATH="$LLVM_BINDING_SMOKE_BIN_DIR" NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" build examples/smoke/hello.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" >"$LLVM_BINDING_SMOKE_OUTPUT" 2>&1; then
  cat "$LLVM_BINDING_SMOKE_OUTPUT"
  fail 'llvm-binding-smoke-build-failed'
fi
cat "$LLVM_BINDING_SMOKE_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-smoke-success-status'
require_output_pattern '^result=success$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-smoke-success-result'
require_output_pattern '^compiler=opt$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-smoke-compiler'
require_output_pattern '^toolchain-binding-id=linux-x86_64-to-linux-x86_64-llvm$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-id'
require_output_pattern '^backend-family=llvm$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-backend-family'
require_output_pattern '^linker-profile-id=gnu-ld$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-linker-profile'
require_output_pattern '^backend-artifact-count=4$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-backend-artifact-count'
require_output_pattern '^backend-artifacts=.*"kind":"llvm-ir".*"kind":"llvm-bitcode".*"kind":"object-file".*"kind":"executable"' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-backend-artifacts'
require_output_pattern '^toolchain-plan-family=llvm-ir-opt-llc-link$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-plan-family'
require_output_pattern '^llvm-toolchain-status=ready$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-toolchain-status'
require_output_pattern '^tool-invocation-count=3$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-tool-invocation-count'
require_output_pattern '^tool-run-status=success$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-tool-run-status'
require_output_pattern '^tool-run-step-count=3$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-tool-run-step-count'
require_output_pattern '^primary-tool-profile-id=llvm-stable$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-primary-tool-profile'
require_output_pattern '^primary-tool-step-id=llvm-opt-bitcode$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-primary-tool-step'
require_output_pattern '^primary-tool-logical-executable=opt$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-primary-tool-logical-executable'
require_output_pattern '^tool-invocation-plan=.*"planFamily":"llvm-ir-opt-llc-link"' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-tool-invocation-plan-family'
require_output_pattern '^tool-invocation-plan=.*"stepId":"llvm-opt-bitcode".*"stepId":"llvm-llc-object".*"stepId":"llvm-link"' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-tool-invocation-plan-steps'
require_output_pattern '^logical-link-request=.*"objectInputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\]' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-logical-link-request-object-input'
require_output_pattern '^build-trace=.*"steps":\[\{"stepId":"llvm-opt-bitcode".*"status":"success".*\{"stepId":"llvm-llc-object".*"status":"success".*\{"stepId":"llvm-link".*"status":"success"' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-build-trace-steps'
require_output_pattern '^human-summary=build succeeded$' "$LLVM_BINDING_SMOKE_OUTPUT" 'missing-llvm-binding-human-summary'
printf 'llvm-binding-smoke=pass\n'

printf 'llvm-empty-program=running\n'
printf 'llvm-empty-program-command=%s build examples/smoke/hello.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_EMPTY_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/hello.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_EMPTY_PROGRAM_OUT_DIR" >"$LLVM_EMPTY_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_EMPTY_PROGRAM_OUTPUT"
  fail 'llvm-empty-program-build-failed'
fi
cat "$LLVM_EMPTY_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_EMPTY_PROGRAM_OUTPUT" 'missing-llvm-empty-program-success-status'
require_output_pattern '^toolchain-plan-family=llvm-ir-opt-llc-link$' "$LLVM_EMPTY_PROGRAM_OUTPUT" 'missing-llvm-empty-program-plan-family'
require_output_pattern '^backend-artifact-count=4$' "$LLVM_EMPTY_PROGRAM_OUTPUT" 'missing-llvm-empty-program-backend-artifact-count'
LLVM_EMPTY_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/hello.ll"
if [ ! -f "$LLVM_EMPTY_PROGRAM_IR_PATH" ]; then
  fail 'missing-llvm-empty-program-ir-artifact'
fi
if ! grep -q '@_start' "$LLVM_EMPTY_PROGRAM_IR_PATH"; then
  cat "$LLVM_EMPTY_PROGRAM_IR_PATH"
  fail 'missing-llvm-empty-program-ir-start-symbol'
fi
LLVM_EMPTY_PROGRAM_BIN="$LLVM_EMPTY_PROGRAM_OUT_DIR/hello"
if [ ! -x "$LLVM_EMPTY_PROGRAM_BIN" ]; then
  fail 'missing-llvm-empty-program-executable'
fi
"$LLVM_EMPTY_PROGRAM_BIN"
LLVM_EMPTY_PROGRAM_EXIT=$?
if [ "$LLVM_EMPTY_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-empty-program-exit=%s\n' "$LLVM_EMPTY_PROGRAM_EXIT"
  fail 'llvm-empty-program-nonzero-exit'
fi
printf 'llvm-empty-program-exit=0\n'
printf 'llvm-empty-program=pass\n'

printf 'llvm-halt-program=running\n'
printf 'llvm-halt-program-command=%s build examples/smoke/halt_42.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/halt_42.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_HALT_PROGRAM_OUT_DIR" >"$LLVM_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_HALT_PROGRAM_OUTPUT"
  fail 'llvm-halt-program-build-failed'
fi
cat "$LLVM_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_HALT_PROGRAM_OUTPUT" 'missing-llvm-halt-program-success-status'
require_output_pattern '^toolchain-plan-family=llvm-ir-opt-llc-link$' "$LLVM_HALT_PROGRAM_OUTPUT" 'missing-llvm-halt-program-plan-family'
LLVM_HALT_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/halt_42.ll"
if [ ! -f "$LLVM_HALT_PROGRAM_IR_PATH" ]; then
  fail 'missing-llvm-halt-program-ir-artifact'
fi
if ! grep -q 'movq \$\$60, %rax; syscall' "$LLVM_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-halt-program-ir-exit-syscall-shape'
fi
if ! grep -q '(i64 42)' "$LLVM_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-halt-program-ir-exit-code-arg'
fi
LLVM_HALT_PROGRAM_BIN="$LLVM_HALT_PROGRAM_OUT_DIR/halt_42"
if [ ! -x "$LLVM_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-halt-program-executable'
fi
set +e
"$LLVM_HALT_PROGRAM_BIN"
LLVM_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_HALT_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-halt-program-exit=%s\n' "$LLVM_HALT_PROGRAM_EXIT"
  fail 'llvm-halt-program-unexpected-exit'
fi
printf 'llvm-halt-program-exit=42\n'
printf 'llvm-halt-program=pass\n'

printf 'llvm-halt-expr-program=running\n'
printf 'llvm-halt-expr-program-command=%s build examples/smoke/halt_expr.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_HALT_EXPR_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/halt_expr.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_HALT_EXPR_PROGRAM_OUT_DIR" >"$LLVM_HALT_EXPR_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_HALT_EXPR_PROGRAM_OUTPUT"
  fail 'llvm-halt-expr-program-build-failed'
fi
cat "$LLVM_HALT_EXPR_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_HALT_EXPR_PROGRAM_OUTPUT" 'missing-llvm-halt-expr-program-success-status'
require_output_pattern '^toolchain-plan-family=llvm-ir-opt-llc-link$' "$LLVM_HALT_EXPR_PROGRAM_OUTPUT" 'missing-llvm-halt-expr-program-plan-family'
LLVM_HALT_EXPR_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/halt_expr.ll"
if [ ! -f "$LLVM_HALT_EXPR_PROGRAM_IR_PATH" ]; then
  fail 'missing-llvm-halt-expr-program-ir-artifact'
fi
if ! grep -q 'movq \$\$60, %rax; syscall' "$LLVM_HALT_EXPR_PROGRAM_IR_PATH"; then
  cat "$LLVM_HALT_EXPR_PROGRAM_IR_PATH"
  fail 'missing-llvm-halt-expr-program-ir-exit-syscall-shape'
fi
if ! grep -q '(i64 42)' "$LLVM_HALT_EXPR_PROGRAM_IR_PATH"; then
  cat "$LLVM_HALT_EXPR_PROGRAM_IR_PATH"
  fail 'missing-llvm-halt-expr-program-ir-folded-exit-arg'
fi
LLVM_HALT_EXPR_PROGRAM_BIN="$LLVM_HALT_EXPR_PROGRAM_OUT_DIR/halt_expr"
if [ ! -x "$LLVM_HALT_EXPR_PROGRAM_BIN" ]; then
  fail 'missing-llvm-halt-expr-program-executable'
fi
set +e
"$LLVM_HALT_EXPR_PROGRAM_BIN"
LLVM_HALT_EXPR_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_HALT_EXPR_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-halt-expr-program-exit=%s\n' "$LLVM_HALT_EXPR_PROGRAM_EXIT"
  fail 'llvm-halt-expr-program-unexpected-exit'
fi
printf 'llvm-halt-expr-program-exit=42\n'
printf 'llvm-halt-expr-program=pass\n'

printf 'llvm-halt-const-program=running\n'
printf 'llvm-halt-const-program-command=%s build examples/smoke/halt_const.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_HALT_CONST_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/halt_const.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_HALT_CONST_PROGRAM_OUT_DIR" >"$LLVM_HALT_CONST_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_HALT_CONST_PROGRAM_OUTPUT"
  fail 'llvm-halt-const-program-build-failed'
fi
cat "$LLVM_HALT_CONST_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_HALT_CONST_PROGRAM_OUTPUT" 'missing-llvm-halt-const-program-success-status'
require_output_pattern '^toolchain-plan-family=llvm-ir-opt-llc-link$' "$LLVM_HALT_CONST_PROGRAM_OUTPUT" 'missing-llvm-halt-const-program-plan-family'
LLVM_HALT_CONST_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/halt_const.ll"
if [ ! -f "$LLVM_HALT_CONST_PROGRAM_IR_PATH" ]; then
  fail 'missing-llvm-halt-const-program-ir-artifact'
fi
if ! grep -q 'movq \$\$60, %rax; syscall' "$LLVM_HALT_CONST_PROGRAM_IR_PATH"; then
  cat "$LLVM_HALT_CONST_PROGRAM_IR_PATH"
  fail 'missing-llvm-halt-const-program-ir-exit-syscall-shape'
fi
if ! grep -q '(i64 42)' "$LLVM_HALT_CONST_PROGRAM_IR_PATH"; then
  cat "$LLVM_HALT_CONST_PROGRAM_IR_PATH"
  fail 'missing-llvm-halt-const-program-ir-folded-exit-arg'
fi
LLVM_HALT_CONST_PROGRAM_BIN="$LLVM_HALT_CONST_PROGRAM_OUT_DIR/halt_const"
if [ ! -x "$LLVM_HALT_CONST_PROGRAM_BIN" ]; then
  fail 'missing-llvm-halt-const-program-executable'
fi
set +e
"$LLVM_HALT_CONST_PROGRAM_BIN"
LLVM_HALT_CONST_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_HALT_CONST_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-halt-const-program-exit=%s\n' "$LLVM_HALT_CONST_PROGRAM_EXIT"
  fail 'llvm-halt-const-program-unexpected-exit'
fi
printf 'llvm-halt-const-program-exit=42\n'
printf 'llvm-halt-const-program=pass\n'

printf 'llvm-writeln-program=running\n'
printf 'llvm-writeln-program-command=%s build examples/smoke/writeln_hello.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_WRITELN_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/writeln_hello.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_WRITELN_PROGRAM_OUT_DIR" >"$LLVM_WRITELN_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_WRITELN_PROGRAM_OUTPUT"
  fail 'llvm-writeln-program-build-failed'
fi
cat "$LLVM_WRITELN_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_WRITELN_PROGRAM_OUTPUT" 'missing-llvm-writeln-program-success-status'
require_output_pattern '^toolchain-plan-family=llvm-ir-opt-llc-link$' "$LLVM_WRITELN_PROGRAM_OUTPUT" 'missing-llvm-writeln-program-plan-family'
LLVM_WRITELN_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/writeln_hello.ll"
if [ ! -f "$LLVM_WRITELN_PROGRAM_IR_PATH" ]; then
  fail 'missing-llvm-writeln-program-ir-artifact'
fi
if ! grep -q '@\.str\.0 = private constant' "$LLVM_WRITELN_PROGRAM_IR_PATH"; then
  cat "$LLVM_WRITELN_PROGRAM_IR_PATH"
  fail 'missing-llvm-writeln-program-ir-string-constant'
fi
if ! grep -q 'movq \$\$1, %rax; syscall' "$LLVM_WRITELN_PROGRAM_IR_PATH"; then
  cat "$LLVM_WRITELN_PROGRAM_IR_PATH"
  fail 'missing-llvm-writeln-program-ir-write-syscall-shape'
fi
if ! grep -q 'ptr @\.str\.0' "$LLVM_WRITELN_PROGRAM_IR_PATH"; then
  cat "$LLVM_WRITELN_PROGRAM_IR_PATH"
  fail 'missing-llvm-writeln-program-ir-write-syscall-arg'
fi
LLVM_WRITELN_PROGRAM_BIN="$LLVM_WRITELN_PROGRAM_OUT_DIR/writeln_hello"
if [ ! -x "$LLVM_WRITELN_PROGRAM_BIN" ]; then
  fail 'missing-llvm-writeln-program-executable'
fi
set +e
"$LLVM_WRITELN_PROGRAM_BIN" >"$LLVM_WRITELN_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_WRITELN_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_WRITELN_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-writeln-program-exit=%s\n' "$LLVM_WRITELN_PROGRAM_EXIT"
  cat "$LLVM_WRITELN_PROGRAM_RUN_OUTPUT"
  fail 'llvm-writeln-program-unexpected-exit'
fi
if ! grep -q '^hello from nextpas llvm$' "$LLVM_WRITELN_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_WRITELN_PROGRAM_RUN_OUTPUT"
  fail 'llvm-writeln-program-missing-stdout'
fi
printf 'llvm-writeln-program-exit=0\n'
printf 'llvm-writeln-program-stdout=hello from nextpas llvm\n'
printf 'llvm-writeln-program=pass\n'

printf 'llvm-writeln-int-program=running\n'
printf 'llvm-writeln-int-program-command=%s build examples/smoke/writeln_int.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_WRITELN_INT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/writeln_int.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_WRITELN_INT_PROGRAM_OUT_DIR" >"$LLVM_WRITELN_INT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_WRITELN_INT_PROGRAM_OUTPUT"
  fail 'llvm-writeln-int-program-build-failed'
fi
cat "$LLVM_WRITELN_INT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_WRITELN_INT_PROGRAM_OUTPUT" 'missing-llvm-writeln-int-program-success-status'
LLVM_WRITELN_INT_PROGRAM_BIN="$LLVM_WRITELN_INT_PROGRAM_OUT_DIR/writeln_int"
if [ ! -x "$LLVM_WRITELN_INT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-writeln-int-program-executable'
fi
set +e
"$LLVM_WRITELN_INT_PROGRAM_BIN" >"$LLVM_WRITELN_INT_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_WRITELN_INT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_WRITELN_INT_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-writeln-int-program-exit=%s\n' "$LLVM_WRITELN_INT_PROGRAM_EXIT"
  cat "$LLVM_WRITELN_INT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-writeln-int-program-unexpected-exit'
fi
if ! grep -q '^42$' "$LLVM_WRITELN_INT_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_WRITELN_INT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-writeln-int-program-missing-stdout'
fi
printf 'llvm-writeln-int-program-stdout=42\n'
printf 'llvm-writeln-int-program=pass\n'

printf 'llvm-writeln-multi-program=running\n'
printf 'llvm-writeln-multi-program-command=%s build examples/smoke/writeln_multi.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_WRITELN_MULTI_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/writeln_multi.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_WRITELN_MULTI_PROGRAM_OUT_DIR" >"$LLVM_WRITELN_MULTI_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_WRITELN_MULTI_PROGRAM_OUTPUT"
  fail 'llvm-writeln-multi-program-build-failed'
fi
cat "$LLVM_WRITELN_MULTI_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_WRITELN_MULTI_PROGRAM_OUTPUT" 'missing-llvm-writeln-multi-program-success-status'
LLVM_WRITELN_MULTI_PROGRAM_BIN="$LLVM_WRITELN_MULTI_PROGRAM_OUT_DIR/writeln_multi"
if [ ! -x "$LLVM_WRITELN_MULTI_PROGRAM_BIN" ]; then
  fail 'missing-llvm-writeln-multi-program-executable'
fi
set +e
"$LLVM_WRITELN_MULTI_PROGRAM_BIN" >"$LLVM_WRITELN_MULTI_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_WRITELN_MULTI_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_WRITELN_MULTI_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-writeln-multi-program-exit=%s\n' "$LLVM_WRITELN_MULTI_PROGRAM_EXIT"
  cat "$LLVM_WRITELN_MULTI_PROGRAM_RUN_OUTPUT"
  fail 'llvm-writeln-multi-program-unexpected-exit'
fi
if ! grep -q '^hello world$' "$LLVM_WRITELN_MULTI_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_WRITELN_MULTI_PROGRAM_RUN_OUTPUT"
  fail 'llvm-writeln-multi-program-missing-stdout'
fi
printf 'llvm-writeln-multi-program-stdout=hello world\n'
printf 'llvm-writeln-multi-program=pass\n'

printf 'llvm-writeln-mixed-program=running\n'
printf 'llvm-writeln-mixed-program-command=%s build examples/smoke/writeln_mixed.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_WRITELN_MIXED_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/writeln_mixed.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_WRITELN_MIXED_PROGRAM_OUT_DIR" >"$LLVM_WRITELN_MIXED_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_WRITELN_MIXED_PROGRAM_OUTPUT"
  fail 'llvm-writeln-mixed-program-build-failed'
fi
cat "$LLVM_WRITELN_MIXED_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_WRITELN_MIXED_PROGRAM_OUTPUT" 'missing-llvm-writeln-mixed-program-success-status'
LLVM_WRITELN_MIXED_PROGRAM_BIN="$LLVM_WRITELN_MIXED_PROGRAM_OUT_DIR/writeln_mixed"
if [ ! -x "$LLVM_WRITELN_MIXED_PROGRAM_BIN" ]; then
  fail 'missing-llvm-writeln-mixed-program-executable'
fi
set +e
"$LLVM_WRITELN_MIXED_PROGRAM_BIN" >"$LLVM_WRITELN_MIXED_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_WRITELN_MIXED_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_WRITELN_MIXED_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-writeln-mixed-program-exit=%s\n' "$LLVM_WRITELN_MIXED_PROGRAM_EXIT"
  cat "$LLVM_WRITELN_MIXED_PROGRAM_RUN_OUTPUT"
  fail 'llvm-writeln-mixed-program-unexpected-exit'
fi
if ! grep -q '^answer: 42$' "$LLVM_WRITELN_MIXED_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_WRITELN_MIXED_PROGRAM_RUN_OUTPUT"
  fail 'llvm-writeln-mixed-program-missing-stdout'
fi
printf 'llvm-writeln-mixed-program-stdout=answer: 42\n'
printf 'llvm-writeln-mixed-program=pass\n'

printf 'llvm-hello-then-halt-program=running\n'
printf 'llvm-hello-then-halt-program-command=%s build examples/smoke/hello_then_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_HELLO_THEN_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/hello_then_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_HELLO_THEN_HALT_PROGRAM_OUT_DIR" >"$LLVM_HELLO_THEN_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_HELLO_THEN_HALT_PROGRAM_OUTPUT"
  fail 'llvm-hello-then-halt-program-build-failed'
fi
cat "$LLVM_HELLO_THEN_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_HELLO_THEN_HALT_PROGRAM_OUTPUT" 'missing-llvm-hello-then-halt-program-success-status'
LLVM_HELLO_THEN_HALT_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/hello_then_halt.ll"
if ! grep -q '@\.str\.0 = private constant' "$LLVM_HELLO_THEN_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_HELLO_THEN_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-hello-then-halt-program-ir-string-zero'
fi
if ! grep -q '@\.str\.1 = private constant' "$LLVM_HELLO_THEN_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_HELLO_THEN_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-hello-then-halt-program-ir-string-one'
fi
LLVM_HELLO_THEN_HALT_PROGRAM_BIN="$LLVM_HELLO_THEN_HALT_PROGRAM_OUT_DIR/hello_then_halt"
if [ ! -x "$LLVM_HELLO_THEN_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-hello-then-halt-program-executable'
fi
set +e
"$LLVM_HELLO_THEN_HALT_PROGRAM_BIN" >"$LLVM_HELLO_THEN_HALT_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_HELLO_THEN_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_HELLO_THEN_HALT_PROGRAM_EXIT" -ne 7 ]; then
  printf 'llvm-hello-then-halt-program-exit=%s\n' "$LLVM_HELLO_THEN_HALT_PROGRAM_EXIT"
  cat "$LLVM_HELLO_THEN_HALT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-hello-then-halt-program-unexpected-exit'
fi
if ! grep -q '^starting$' "$LLVM_HELLO_THEN_HALT_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_HELLO_THEN_HALT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-hello-then-halt-program-missing-first-stdout'
fi
if ! grep -q '^done$' "$LLVM_HELLO_THEN_HALT_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_HELLO_THEN_HALT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-hello-then-halt-program-missing-second-stdout'
fi
printf 'llvm-hello-then-halt-program-exit=7\n'
printf 'llvm-hello-then-halt-program=pass\n'

printf 'llvm-var-halt-program=running\n'
printf 'llvm-var-halt-program-command=%s build examples/smoke/var_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_VAR_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/var_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_VAR_HALT_PROGRAM_OUT_DIR" >"$LLVM_VAR_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_VAR_HALT_PROGRAM_OUTPUT"
  fail 'llvm-var-halt-program-build-failed'
fi
cat "$LLVM_VAR_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_VAR_HALT_PROGRAM_OUTPUT" 'missing-llvm-var-halt-program-success-status'
LLVM_VAR_HALT_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/var_halt.ll"
if ! grep -q '(i64 42)' "$LLVM_VAR_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_VAR_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-var-halt-program-ir-folded-exit-arg'
fi
LLVM_VAR_HALT_PROGRAM_BIN="$LLVM_VAR_HALT_PROGRAM_OUT_DIR/var_halt"
if [ ! -x "$LLVM_VAR_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-var-halt-program-executable'
fi
set +e
"$LLVM_VAR_HALT_PROGRAM_BIN"
LLVM_VAR_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_VAR_HALT_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-var-halt-program-exit=%s\n' "$LLVM_VAR_HALT_PROGRAM_EXIT"
  fail 'llvm-var-halt-program-unexpected-exit'
fi
printf 'llvm-var-halt-program-exit=42\n'
printf 'llvm-var-halt-program=pass\n'

printf 'llvm-no-fold-halt-program=running\n'
printf 'llvm-no-fold-halt-program-command=%s build examples/smoke/halt_42.pas --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_NO_FOLD_HALT_PROGRAM_OUT_DIR"
rm -rf "$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/halt_42.ll"
if ! "$STAGE0_BINARY" build examples/smoke/halt_42.pas --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_NO_FOLD_HALT_PROGRAM_OUT_DIR" >"$LLVM_NO_FOLD_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_NO_FOLD_HALT_PROGRAM_OUTPUT"
  fail 'llvm-no-fold-halt-program-build-failed'
fi
require_output_pattern '^status=success$' "$LLVM_NO_FOLD_HALT_PROGRAM_OUTPUT" 'missing-llvm-no-fold-halt-program-success-status'
LLVM_NO_FOLD_HALT_PROGRAM_BIN="$LLVM_NO_FOLD_HALT_PROGRAM_OUT_DIR/halt_42"
if [ ! -x "$LLVM_NO_FOLD_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-no-fold-halt-program-executable'
fi
set +e
"$LLVM_NO_FOLD_HALT_PROGRAM_BIN"
LLVM_NO_FOLD_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_NO_FOLD_HALT_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-no-fold-halt-program-exit=%s\n' "$LLVM_NO_FOLD_HALT_PROGRAM_EXIT"
  fail 'llvm-no-fold-halt-program-unexpected-exit'
fi
printf 'llvm-no-fold-halt-program-exit=42\n'
printf 'llvm-no-fold-halt-program=pass\n'

printf 'llvm-no-fold-halt-expr-program=running\n'
printf 'llvm-no-fold-halt-expr-program-command=%s build examples/smoke/halt_expr.pas --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUT_DIR"
rm -rf "$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/halt_expr.ll"
if ! "$STAGE0_BINARY" build examples/smoke/halt_expr.pas --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUT_DIR" >"$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUTPUT"
  fail 'llvm-no-fold-halt-expr-program-build-failed'
fi
require_output_pattern '^status=success$' "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUTPUT" 'missing-llvm-no-fold-halt-expr-program-success-status'
LLVM_NO_FOLD_HALT_EXPR_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/halt_expr.ll"
if ! grep -q ' = add i64 ' "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_IR_PATH"; then
  cat "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_IR_PATH"
  fail 'missing-llvm-no-fold-halt-expr-program-ir-runtime-add'
fi
LLVM_NO_FOLD_HALT_EXPR_PROGRAM_BIN="$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_OUT_DIR/halt_expr"
if [ ! -x "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_BIN" ]; then
  fail 'missing-llvm-no-fold-halt-expr-program-executable'
fi
set +e
"$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_BIN"
LLVM_NO_FOLD_HALT_EXPR_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-no-fold-halt-expr-program-exit=%s\n' "$LLVM_NO_FOLD_HALT_EXPR_PROGRAM_EXIT"
  fail 'llvm-no-fold-halt-expr-program-unexpected-exit'
fi
printf 'llvm-no-fold-halt-expr-program-exit=42\n'
printf 'llvm-no-fold-halt-expr-program=pass\n'

printf 'llvm-no-fold-var-halt-program=running\n'
printf 'llvm-no-fold-var-halt-program-command=%s build examples/smoke/var_halt.pas --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUT_DIR"
rm -rf "$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/var_halt.ll"
if ! "$STAGE0_BINARY" build examples/smoke/var_halt.pas --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUT_DIR" >"$LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUTPUT"
  fail 'llvm-no-fold-var-halt-program-build-failed'
fi
require_output_pattern '^status=success$' "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUTPUT" 'missing-llvm-no-fold-var-halt-program-success-status'
LLVM_NO_FOLD_VAR_HALT_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/var_halt.ll"
if ! grep -q ' = alloca i64' "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-no-fold-var-halt-program-ir-runtime-alloca'
fi
LLVM_NO_FOLD_VAR_HALT_PROGRAM_BIN="$LLVM_NO_FOLD_VAR_HALT_PROGRAM_OUT_DIR/var_halt"
if [ ! -x "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-no-fold-var-halt-program-executable'
fi
set +e
"$LLVM_NO_FOLD_VAR_HALT_PROGRAM_BIN"
LLVM_NO_FOLD_VAR_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-no-fold-var-halt-program-exit=%s\n' "$LLVM_NO_FOLD_VAR_HALT_PROGRAM_EXIT"
  fail 'llvm-no-fold-var-halt-program-unexpected-exit'
fi
printf 'llvm-no-fold-var-halt-program-exit=42\n'
printf 'llvm-no-fold-var-halt-program=pass\n'

printf 'llvm-no-fold-var-chain-program=running\n'
printf 'llvm-no-fold-var-chain-program-command=%s build examples/smoke/var_chain.pas --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUT_DIR"
rm -rf "$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/var_chain.ll"
if ! "$STAGE0_BINARY" build examples/smoke/var_chain.pas --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUT_DIR" >"$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUTPUT"
  fail 'llvm-no-fold-var-chain-program-build-failed'
fi
require_output_pattern '^status=success$' "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUTPUT" 'missing-llvm-no-fold-var-chain-program-success-status'
LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/var_chain.ll"
if ! grep -cE '= alloca i64' "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_IR_PATH" | grep -q '^2$'; then
  cat "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_IR_PATH"
  fail 'missing-llvm-no-fold-var-chain-program-ir-runtime-two-allocas'
fi
LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_BIN="$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_OUT_DIR/var_chain"
if [ ! -x "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_BIN" ]; then
  fail 'missing-llvm-no-fold-var-chain-program-executable'
fi
set +e
"$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_BIN"
LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_EXIT" -ne 15 ]; then
  printf 'llvm-no-fold-var-chain-program-exit=%s\n' "$LLVM_NO_FOLD_VAR_CHAIN_PROGRAM_EXIT"
  fail 'llvm-no-fold-var-chain-program-unexpected-exit'
fi
printf 'llvm-no-fold-var-chain-program-exit=15\n'
printf 'llvm-no-fold-var-chain-program=pass\n'

run_no_fold_program() {
  PROG_NAME="$1"
  EXPECTED_EXIT="$2"
  OUT_FILE="$3"
  OUT_DIR="$4"
  rm -rf "$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/${PROG_NAME}.ll"
  printf 'llvm-no-fold-%s-program=running\n' "$PROG_NAME"
  if ! "$STAGE0_BINARY" build "examples/smoke/${PROG_NAME}.pas" --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$OUT_DIR" >"$OUT_FILE" 2>&1; then
    cat "$OUT_FILE"
    fail "llvm-no-fold-${PROG_NAME}-program-build-failed"
  fi
  require_output_pattern '^status=success$' "$OUT_FILE" "missing-llvm-no-fold-${PROG_NAME}-program-success-status"
  IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/${PROG_NAME}.ll"
  if ! grep -q ' br i1 ' "$IR_PATH"; then
    cat "$IR_PATH"
    fail "missing-llvm-no-fold-${PROG_NAME}-program-ir-cond-br"
  fi
  BIN="$OUT_DIR/${PROG_NAME}"
  if [ ! -x "$BIN" ]; then
    fail "missing-llvm-no-fold-${PROG_NAME}-program-executable"
  fi
  set +e
  "$BIN"
  EXIT=$?
  set -e
  if [ "$EXIT" -ne "$EXPECTED_EXIT" ]; then
    printf 'llvm-no-fold-%s-program-exit=%s\n' "$PROG_NAME" "$EXIT"
    fail "llvm-no-fold-${PROG_NAME}-program-unexpected-exit"
  fi
  printf 'llvm-no-fold-%s-program-exit=%s\n' "$PROG_NAME" "$EXPECTED_EXIT"
  printf 'llvm-no-fold-%s-program=pass\n' "$PROG_NAME"
}

run_no_fold_program if_halt 11 "$LLVM_NO_FOLD_IF_HALT_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_IF_HALT_PROGRAM_OUT_DIR"
run_no_fold_program if_else_halt 22 "$LLVM_NO_FOLD_IF_ELSE_HALT_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_IF_ELSE_HALT_PROGRAM_OUT_DIR"
run_no_fold_program if_var 7 "$LLVM_NO_FOLD_IF_VAR_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_IF_VAR_PROGRAM_OUT_DIR"
run_no_fold_program repeat_halt 20 "$LLVM_NO_FOLD_REPEAT_HALT_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_REPEAT_HALT_PROGRAM_OUT_DIR"
run_no_fold_program while_sum 15 "$LLVM_NO_FOLD_WHILE_SUM_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_WHILE_SUM_PROGRAM_OUT_DIR"
run_no_fold_program for_sum_halt 15 "$LLVM_NO_FOLD_FOR_SUM_HALT_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_FOR_SUM_HALT_PROGRAM_OUT_DIR"

run_no_fold_program_with_stdout() {
  PROG_NAME="$1"
  EXPECTED_STDOUT="$2"
  OUT_FILE="$3"
  OUT_DIR="$4"
  RUN_FILE="$5"
  rm -rf "$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/${PROG_NAME}.ll"
  printf 'llvm-no-fold-%s-program=running\n' "$PROG_NAME"
  if ! "$STAGE0_BINARY" build "examples/smoke/${PROG_NAME}.pas" --no-fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$OUT_DIR" >"$OUT_FILE" 2>&1; then
    cat "$OUT_FILE"
    fail "llvm-no-fold-${PROG_NAME}-program-build-failed"
  fi
  require_output_pattern '^status=success$' "$OUT_FILE" "missing-llvm-no-fold-${PROG_NAME}-program-success-status"
  IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/${PROG_NAME}.ll"
  if ! grep -q '@write_i64_decimal' "$IR_PATH"; then
    cat "$IR_PATH"
    fail "missing-llvm-no-fold-${PROG_NAME}-program-ir-itoa-helper"
  fi
  BIN="$OUT_DIR/${PROG_NAME}"
  if [ ! -x "$BIN" ]; then
    fail "missing-llvm-no-fold-${PROG_NAME}-program-executable"
  fi
  set +e
  "$BIN" >"$RUN_FILE" 2>&1
  EXIT=$?
  set -e
  if [ "$EXIT" -ne 0 ]; then
    printf 'llvm-no-fold-%s-program-exit=%s\n' "$PROG_NAME" "$EXIT"
    cat "$RUN_FILE"
    fail "llvm-no-fold-${PROG_NAME}-program-unexpected-exit"
  fi
  if [ "$(cat "$RUN_FILE")" != "$EXPECTED_STDOUT" ]; then
    cat "$RUN_FILE"
    fail "llvm-no-fold-${PROG_NAME}-program-missing-stdout"
  fi
  printf 'llvm-no-fold-%s-program=pass\n' "$PROG_NAME"
}

LLVM_NO_FOLD_COUNT_UP='1
2
3'
LLVM_NO_FOLD_COUNT_DOWN='3
2
1'
run_no_fold_program_with_stdout for_writeln "$LLVM_NO_FOLD_COUNT_UP" "$LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_OUT_DIR" "$LLVM_NO_FOLD_FOR_WRITELN_PROGRAM_RUN_OUTPUT"
run_no_fold_program_with_stdout while_count "$LLVM_NO_FOLD_COUNT_DOWN" "$LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_OUT_DIR" "$LLVM_NO_FOLD_WHILE_COUNT_PROGRAM_RUN_OUTPUT"
run_no_fold_program_with_stdout for_downto "$LLVM_NO_FOLD_COUNT_DOWN" "$LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_OUT_DIR" "$LLVM_NO_FOLD_FOR_DOWNTO_PROGRAM_RUN_OUTPUT"
run_no_fold_program_with_stdout repeat_count "$LLVM_NO_FOLD_COUNT_UP" "$LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_OUTPUT" "$LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_OUT_DIR" "$LLVM_NO_FOLD_REPEAT_COUNT_PROGRAM_RUN_OUTPUT"

printf 'llvm-var-writeln-program=running\n'
printf 'llvm-var-writeln-program-command=%s build examples/smoke/var_writeln.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_VAR_WRITELN_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/var_writeln.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_VAR_WRITELN_PROGRAM_OUT_DIR" >"$LLVM_VAR_WRITELN_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_VAR_WRITELN_PROGRAM_OUTPUT"
  fail 'llvm-var-writeln-program-build-failed'
fi
cat "$LLVM_VAR_WRITELN_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_VAR_WRITELN_PROGRAM_OUTPUT" 'missing-llvm-var-writeln-program-success-status'
LLVM_VAR_WRITELN_PROGRAM_BIN="$LLVM_VAR_WRITELN_PROGRAM_OUT_DIR/var_writeln"
if [ ! -x "$LLVM_VAR_WRITELN_PROGRAM_BIN" ]; then
  fail 'missing-llvm-var-writeln-program-executable'
fi
set +e
"$LLVM_VAR_WRITELN_PROGRAM_BIN" >"$LLVM_VAR_WRITELN_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_VAR_WRITELN_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_VAR_WRITELN_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-var-writeln-program-exit=%s\n' "$LLVM_VAR_WRITELN_PROGRAM_EXIT"
  cat "$LLVM_VAR_WRITELN_PROGRAM_RUN_OUTPUT"
  fail 'llvm-var-writeln-program-unexpected-exit'
fi
if ! grep -q '^7$' "$LLVM_VAR_WRITELN_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_VAR_WRITELN_PROGRAM_RUN_OUTPUT"
  fail 'llvm-var-writeln-program-missing-stdout'
fi
printf 'llvm-var-writeln-program-stdout=7\n'
printf 'llvm-var-writeln-program=pass\n'

printf 'llvm-var-chain-program=running\n'
printf 'llvm-var-chain-program-command=%s build examples/smoke/var_chain.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_VAR_CHAIN_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/var_chain.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_VAR_CHAIN_PROGRAM_OUT_DIR" >"$LLVM_VAR_CHAIN_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_VAR_CHAIN_PROGRAM_OUTPUT"
  fail 'llvm-var-chain-program-build-failed'
fi
cat "$LLVM_VAR_CHAIN_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_VAR_CHAIN_PROGRAM_OUTPUT" 'missing-llvm-var-chain-program-success-status'
LLVM_VAR_CHAIN_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/var_chain.ll"
if ! grep -q '(i64 15)' "$LLVM_VAR_CHAIN_PROGRAM_IR_PATH"; then
  cat "$LLVM_VAR_CHAIN_PROGRAM_IR_PATH"
  fail 'missing-llvm-var-chain-program-ir-folded-chain-arg'
fi
LLVM_VAR_CHAIN_PROGRAM_BIN="$LLVM_VAR_CHAIN_PROGRAM_OUT_DIR/var_chain"
if [ ! -x "$LLVM_VAR_CHAIN_PROGRAM_BIN" ]; then
  fail 'missing-llvm-var-chain-program-executable'
fi
set +e
"$LLVM_VAR_CHAIN_PROGRAM_BIN"
LLVM_VAR_CHAIN_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_VAR_CHAIN_PROGRAM_EXIT" -ne 15 ]; then
  printf 'llvm-var-chain-program-exit=%s\n' "$LLVM_VAR_CHAIN_PROGRAM_EXIT"
  fail 'llvm-var-chain-program-unexpected-exit'
fi
printf 'llvm-var-chain-program-exit=15\n'
printf 'llvm-var-chain-program=pass\n'

printf 'llvm-if-halt-program=running\n'
printf 'llvm-if-halt-program-command=%s build examples/smoke/if_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_IF_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/if_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_IF_HALT_PROGRAM_OUT_DIR" >"$LLVM_IF_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_IF_HALT_PROGRAM_OUTPUT"
  fail 'llvm-if-halt-program-build-failed'
fi
cat "$LLVM_IF_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_IF_HALT_PROGRAM_OUTPUT" 'missing-llvm-if-halt-program-success-status'
LLVM_IF_HALT_PROGRAM_BIN="$LLVM_IF_HALT_PROGRAM_OUT_DIR/if_halt"
if [ ! -x "$LLVM_IF_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-if-halt-program-executable'
fi
set +e
"$LLVM_IF_HALT_PROGRAM_BIN"
LLVM_IF_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_IF_HALT_PROGRAM_EXIT" -ne 11 ]; then
  printf 'llvm-if-halt-program-exit=%s\n' "$LLVM_IF_HALT_PROGRAM_EXIT"
  fail 'llvm-if-halt-program-unexpected-exit'
fi
printf 'llvm-if-halt-program-exit=11\n'
printf 'llvm-if-halt-program=pass\n'

printf 'llvm-if-else-halt-program=running\n'
printf 'llvm-if-else-halt-program-command=%s build examples/smoke/if_else_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_IF_ELSE_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/if_else_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_IF_ELSE_HALT_PROGRAM_OUT_DIR" >"$LLVM_IF_ELSE_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_IF_ELSE_HALT_PROGRAM_OUTPUT"
  fail 'llvm-if-else-halt-program-build-failed'
fi
cat "$LLVM_IF_ELSE_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_IF_ELSE_HALT_PROGRAM_OUTPUT" 'missing-llvm-if-else-halt-program-success-status'
LLVM_IF_ELSE_HALT_PROGRAM_BIN="$LLVM_IF_ELSE_HALT_PROGRAM_OUT_DIR/if_else_halt"
if [ ! -x "$LLVM_IF_ELSE_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-if-else-halt-program-executable'
fi
set +e
"$LLVM_IF_ELSE_HALT_PROGRAM_BIN"
LLVM_IF_ELSE_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_IF_ELSE_HALT_PROGRAM_EXIT" -ne 22 ]; then
  printf 'llvm-if-else-halt-program-exit=%s\n' "$LLVM_IF_ELSE_HALT_PROGRAM_EXIT"
  fail 'llvm-if-else-halt-program-unexpected-exit'
fi
printf 'llvm-if-else-halt-program-exit=22\n'
printf 'llvm-if-else-halt-program=pass\n'

printf 'llvm-if-var-program=running\n'
printf 'llvm-if-var-program-command=%s build examples/smoke/if_var.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_IF_VAR_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/if_var.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_IF_VAR_PROGRAM_OUT_DIR" >"$LLVM_IF_VAR_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_IF_VAR_PROGRAM_OUTPUT"
  fail 'llvm-if-var-program-build-failed'
fi
cat "$LLVM_IF_VAR_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_IF_VAR_PROGRAM_OUTPUT" 'missing-llvm-if-var-program-success-status'
LLVM_IF_VAR_PROGRAM_BIN="$LLVM_IF_VAR_PROGRAM_OUT_DIR/if_var"
if [ ! -x "$LLVM_IF_VAR_PROGRAM_BIN" ]; then
  fail 'missing-llvm-if-var-program-executable'
fi
set +e
"$LLVM_IF_VAR_PROGRAM_BIN"
LLVM_IF_VAR_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_IF_VAR_PROGRAM_EXIT" -ne 7 ]; then
  printf 'llvm-if-var-program-exit=%s\n' "$LLVM_IF_VAR_PROGRAM_EXIT"
  fail 'llvm-if-var-program-unexpected-exit'
fi
printf 'llvm-if-var-program-exit=7\n'
printf 'llvm-if-var-program=pass\n'

printf 'llvm-for-writeln-program=running\n'
printf 'llvm-for-writeln-program-command=%s build examples/smoke/for_writeln.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_FOR_WRITELN_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/for_writeln.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_FOR_WRITELN_PROGRAM_OUT_DIR" >"$LLVM_FOR_WRITELN_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_FOR_WRITELN_PROGRAM_OUTPUT"
  fail 'llvm-for-writeln-program-build-failed'
fi
cat "$LLVM_FOR_WRITELN_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_FOR_WRITELN_PROGRAM_OUTPUT" 'missing-llvm-for-writeln-program-success-status'
LLVM_FOR_WRITELN_PROGRAM_BIN="$LLVM_FOR_WRITELN_PROGRAM_OUT_DIR/for_writeln"
if [ ! -x "$LLVM_FOR_WRITELN_PROGRAM_BIN" ]; then
  fail 'missing-llvm-for-writeln-program-executable'
fi
set +e
"$LLVM_FOR_WRITELN_PROGRAM_BIN" >"$LLVM_FOR_WRITELN_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_FOR_WRITELN_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_FOR_WRITELN_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-for-writeln-program-exit=%s\n' "$LLVM_FOR_WRITELN_PROGRAM_EXIT"
  cat "$LLVM_FOR_WRITELN_PROGRAM_RUN_OUTPUT"
  fail 'llvm-for-writeln-program-unexpected-exit'
fi
LLVM_FOR_WRITELN_EXPECTED='1
2
3'
if [ "$(cat "$LLVM_FOR_WRITELN_PROGRAM_RUN_OUTPUT")" != "$LLVM_FOR_WRITELN_EXPECTED" ]; then
  cat "$LLVM_FOR_WRITELN_PROGRAM_RUN_OUTPUT"
  fail 'llvm-for-writeln-program-missing-stdout'
fi
printf 'llvm-for-writeln-program-stdout=1,2,3\n'
printf 'llvm-for-writeln-program=pass\n'

printf 'llvm-for-sum-halt-program=running\n'
printf 'llvm-for-sum-halt-program-command=%s build examples/smoke/for_sum_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_FOR_SUM_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/for_sum_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_FOR_SUM_HALT_PROGRAM_OUT_DIR" >"$LLVM_FOR_SUM_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_FOR_SUM_HALT_PROGRAM_OUTPUT"
  fail 'llvm-for-sum-halt-program-build-failed'
fi
cat "$LLVM_FOR_SUM_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_FOR_SUM_HALT_PROGRAM_OUTPUT" 'missing-llvm-for-sum-halt-program-success-status'
LLVM_FOR_SUM_HALT_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/for_sum_halt.ll"
if ! grep -q '(i64 15)' "$LLVM_FOR_SUM_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_FOR_SUM_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-for-sum-halt-program-ir-folded-sum-arg'
fi
LLVM_FOR_SUM_HALT_PROGRAM_BIN="$LLVM_FOR_SUM_HALT_PROGRAM_OUT_DIR/for_sum_halt"
if [ ! -x "$LLVM_FOR_SUM_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-for-sum-halt-program-executable'
fi
set +e
"$LLVM_FOR_SUM_HALT_PROGRAM_BIN"
LLVM_FOR_SUM_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_FOR_SUM_HALT_PROGRAM_EXIT" -ne 15 ]; then
  printf 'llvm-for-sum-halt-program-exit=%s\n' "$LLVM_FOR_SUM_HALT_PROGRAM_EXIT"
  fail 'llvm-for-sum-halt-program-unexpected-exit'
fi
printf 'llvm-for-sum-halt-program-exit=15\n'
printf 'llvm-for-sum-halt-program=pass\n'

printf 'llvm-for-downto-program=running\n'
printf 'llvm-for-downto-program-command=%s build examples/smoke/for_downto.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_FOR_DOWNTO_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/for_downto.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_FOR_DOWNTO_PROGRAM_OUT_DIR" >"$LLVM_FOR_DOWNTO_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_FOR_DOWNTO_PROGRAM_OUTPUT"
  fail 'llvm-for-downto-program-build-failed'
fi
cat "$LLVM_FOR_DOWNTO_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_FOR_DOWNTO_PROGRAM_OUTPUT" 'missing-llvm-for-downto-program-success-status'
LLVM_FOR_DOWNTO_PROGRAM_BIN="$LLVM_FOR_DOWNTO_PROGRAM_OUT_DIR/for_downto"
if [ ! -x "$LLVM_FOR_DOWNTO_PROGRAM_BIN" ]; then
  fail 'missing-llvm-for-downto-program-executable'
fi
set +e
"$LLVM_FOR_DOWNTO_PROGRAM_BIN" >"$LLVM_FOR_DOWNTO_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_FOR_DOWNTO_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_FOR_DOWNTO_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-for-downto-program-exit=%s\n' "$LLVM_FOR_DOWNTO_PROGRAM_EXIT"
  cat "$LLVM_FOR_DOWNTO_PROGRAM_RUN_OUTPUT"
  fail 'llvm-for-downto-program-unexpected-exit'
fi
LLVM_FOR_DOWNTO_EXPECTED='3
2
1'
if [ "$(cat "$LLVM_FOR_DOWNTO_PROGRAM_RUN_OUTPUT")" != "$LLVM_FOR_DOWNTO_EXPECTED" ]; then
  cat "$LLVM_FOR_DOWNTO_PROGRAM_RUN_OUTPUT"
  fail 'llvm-for-downto-program-missing-stdout'
fi
printf 'llvm-for-downto-program-stdout=3,2,1\n'
printf 'llvm-for-downto-program=pass\n'

printf 'llvm-if-not-program=running\n'
printf 'llvm-if-not-program-command=%s build examples/smoke/if_not.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_IF_NOT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/if_not.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_IF_NOT_PROGRAM_OUT_DIR" >"$LLVM_IF_NOT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_IF_NOT_PROGRAM_OUTPUT"
  fail 'llvm-if-not-program-build-failed'
fi
cat "$LLVM_IF_NOT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_IF_NOT_PROGRAM_OUTPUT" 'missing-llvm-if-not-program-success-status'
LLVM_IF_NOT_PROGRAM_BIN="$LLVM_IF_NOT_PROGRAM_OUT_DIR/if_not"
if [ ! -x "$LLVM_IF_NOT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-if-not-program-executable'
fi
set +e
"$LLVM_IF_NOT_PROGRAM_BIN"
LLVM_IF_NOT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_IF_NOT_PROGRAM_EXIT" -ne 11 ]; then
  printf 'llvm-if-not-program-exit=%s\n' "$LLVM_IF_NOT_PROGRAM_EXIT"
  fail 'llvm-if-not-program-unexpected-exit'
fi
printf 'llvm-if-not-program-exit=11\n'
printf 'llvm-if-not-program=pass\n'

printf 'llvm-if-true-program=running\n'
printf 'llvm-if-true-program-command=%s build examples/smoke/if_true.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_IF_TRUE_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/if_true.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_IF_TRUE_PROGRAM_OUT_DIR" >"$LLVM_IF_TRUE_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_IF_TRUE_PROGRAM_OUTPUT"
  fail 'llvm-if-true-program-build-failed'
fi
cat "$LLVM_IF_TRUE_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_IF_TRUE_PROGRAM_OUTPUT" 'missing-llvm-if-true-program-success-status'
LLVM_IF_TRUE_PROGRAM_BIN="$LLVM_IF_TRUE_PROGRAM_OUT_DIR/if_true"
if [ ! -x "$LLVM_IF_TRUE_PROGRAM_BIN" ]; then
  fail 'missing-llvm-if-true-program-executable'
fi
set +e
"$LLVM_IF_TRUE_PROGRAM_BIN"
LLVM_IF_TRUE_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_IF_TRUE_PROGRAM_EXIT" -ne 22 ]; then
  printf 'llvm-if-true-program-exit=%s\n' "$LLVM_IF_TRUE_PROGRAM_EXIT"
  fail 'llvm-if-true-program-unexpected-exit'
fi
printf 'llvm-if-true-program-exit=22\n'
printf 'llvm-if-true-program=pass\n'

printf 'llvm-while-count-program=running\n'
printf 'llvm-while-count-program-command=%s build examples/smoke/while_count.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_WHILE_COUNT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/while_count.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_WHILE_COUNT_PROGRAM_OUT_DIR" >"$LLVM_WHILE_COUNT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_WHILE_COUNT_PROGRAM_OUTPUT"
  fail 'llvm-while-count-program-build-failed'
fi
cat "$LLVM_WHILE_COUNT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_WHILE_COUNT_PROGRAM_OUTPUT" 'missing-llvm-while-count-program-success-status'
LLVM_WHILE_COUNT_PROGRAM_BIN="$LLVM_WHILE_COUNT_PROGRAM_OUT_DIR/while_count"
if [ ! -x "$LLVM_WHILE_COUNT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-while-count-program-executable'
fi
set +e
"$LLVM_WHILE_COUNT_PROGRAM_BIN" >"$LLVM_WHILE_COUNT_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_WHILE_COUNT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_WHILE_COUNT_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-while-count-program-exit=%s\n' "$LLVM_WHILE_COUNT_PROGRAM_EXIT"
  cat "$LLVM_WHILE_COUNT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-while-count-program-unexpected-exit'
fi
LLVM_WHILE_COUNT_EXPECTED='3
2
1'
if [ "$(cat "$LLVM_WHILE_COUNT_PROGRAM_RUN_OUTPUT")" != "$LLVM_WHILE_COUNT_EXPECTED" ]; then
  cat "$LLVM_WHILE_COUNT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-while-count-program-missing-stdout'
fi
printf 'llvm-while-count-program-stdout=3,2,1\n'
printf 'llvm-while-count-program=pass\n'

printf 'llvm-while-sum-program=running\n'
printf 'llvm-while-sum-program-command=%s build examples/smoke/while_sum.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_WHILE_SUM_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/while_sum.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_WHILE_SUM_PROGRAM_OUT_DIR" >"$LLVM_WHILE_SUM_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_WHILE_SUM_PROGRAM_OUTPUT"
  fail 'llvm-while-sum-program-build-failed'
fi
cat "$LLVM_WHILE_SUM_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_WHILE_SUM_PROGRAM_OUTPUT" 'missing-llvm-while-sum-program-success-status'
LLVM_WHILE_SUM_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/while_sum.ll"
if ! grep -q '(i64 15)' "$LLVM_WHILE_SUM_PROGRAM_IR_PATH"; then
  cat "$LLVM_WHILE_SUM_PROGRAM_IR_PATH"
  fail 'missing-llvm-while-sum-program-ir-folded-sum-arg'
fi
LLVM_WHILE_SUM_PROGRAM_BIN="$LLVM_WHILE_SUM_PROGRAM_OUT_DIR/while_sum"
if [ ! -x "$LLVM_WHILE_SUM_PROGRAM_BIN" ]; then
  fail 'missing-llvm-while-sum-program-executable'
fi
set +e
"$LLVM_WHILE_SUM_PROGRAM_BIN"
LLVM_WHILE_SUM_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_WHILE_SUM_PROGRAM_EXIT" -ne 15 ]; then
  printf 'llvm-while-sum-program-exit=%s\n' "$LLVM_WHILE_SUM_PROGRAM_EXIT"
  fail 'llvm-while-sum-program-unexpected-exit'
fi
printf 'llvm-while-sum-program-exit=15\n'
printf 'llvm-while-sum-program=pass\n'

printf 'llvm-repeat-count-program=running\n'
printf 'llvm-repeat-count-program-command=%s build examples/smoke/repeat_count.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_REPEAT_COUNT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/repeat_count.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_REPEAT_COUNT_PROGRAM_OUT_DIR" >"$LLVM_REPEAT_COUNT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_REPEAT_COUNT_PROGRAM_OUTPUT"
  fail 'llvm-repeat-count-program-build-failed'
fi
cat "$LLVM_REPEAT_COUNT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_REPEAT_COUNT_PROGRAM_OUTPUT" 'missing-llvm-repeat-count-program-success-status'
LLVM_REPEAT_COUNT_PROGRAM_BIN="$LLVM_REPEAT_COUNT_PROGRAM_OUT_DIR/repeat_count"
if [ ! -x "$LLVM_REPEAT_COUNT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-repeat-count-program-executable'
fi
set +e
"$LLVM_REPEAT_COUNT_PROGRAM_BIN" >"$LLVM_REPEAT_COUNT_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_REPEAT_COUNT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_REPEAT_COUNT_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-repeat-count-program-exit=%s\n' "$LLVM_REPEAT_COUNT_PROGRAM_EXIT"
  cat "$LLVM_REPEAT_COUNT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-repeat-count-program-unexpected-exit'
fi
LLVM_REPEAT_COUNT_EXPECTED='1
2
3'
if [ "$(cat "$LLVM_REPEAT_COUNT_PROGRAM_RUN_OUTPUT")" != "$LLVM_REPEAT_COUNT_EXPECTED" ]; then
  cat "$LLVM_REPEAT_COUNT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-repeat-count-program-missing-stdout'
fi
printf 'llvm-repeat-count-program-stdout=1,2,3\n'
printf 'llvm-repeat-count-program=pass\n'

printf 'llvm-repeat-halt-program=running\n'
printf 'llvm-repeat-halt-program-command=%s build examples/smoke/repeat_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_REPEAT_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/repeat_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_REPEAT_HALT_PROGRAM_OUT_DIR" >"$LLVM_REPEAT_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_REPEAT_HALT_PROGRAM_OUTPUT"
  fail 'llvm-repeat-halt-program-build-failed'
fi
cat "$LLVM_REPEAT_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_REPEAT_HALT_PROGRAM_OUTPUT" 'missing-llvm-repeat-halt-program-success-status'
LLVM_REPEAT_HALT_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/repeat_halt.ll"
if ! grep -q '(i64 20)' "$LLVM_REPEAT_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_REPEAT_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-repeat-halt-program-ir-folded-x-arg'
fi
LLVM_REPEAT_HALT_PROGRAM_BIN="$LLVM_REPEAT_HALT_PROGRAM_OUT_DIR/repeat_halt"
if [ ! -x "$LLVM_REPEAT_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-repeat-halt-program-executable'
fi
set +e
"$LLVM_REPEAT_HALT_PROGRAM_BIN"
LLVM_REPEAT_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_REPEAT_HALT_PROGRAM_EXIT" -ne 20 ]; then
  printf 'llvm-repeat-halt-program-exit=%s\n' "$LLVM_REPEAT_HALT_PROGRAM_EXIT"
  fail 'llvm-repeat-halt-program-unexpected-exit'
fi
printf 'llvm-repeat-halt-program-exit=20\n'
printf 'llvm-repeat-halt-program=pass\n'

printf 'llvm-const-string-program=running\n'
printf 'llvm-const-string-program-command=%s build examples/smoke/const_string.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_CONST_STRING_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/const_string.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_CONST_STRING_PROGRAM_OUT_DIR" >"$LLVM_CONST_STRING_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_CONST_STRING_PROGRAM_OUTPUT"
  fail 'llvm-const-string-program-build-failed'
fi
cat "$LLVM_CONST_STRING_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_CONST_STRING_PROGRAM_OUTPUT" 'missing-llvm-const-string-program-success-status'
LLVM_CONST_STRING_PROGRAM_BIN="$LLVM_CONST_STRING_PROGRAM_OUT_DIR/const_string"
if [ ! -x "$LLVM_CONST_STRING_PROGRAM_BIN" ]; then
  fail 'missing-llvm-const-string-program-executable'
fi
set +e
"$LLVM_CONST_STRING_PROGRAM_BIN" >"$LLVM_CONST_STRING_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_CONST_STRING_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_CONST_STRING_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-const-string-program-exit=%s\n' "$LLVM_CONST_STRING_PROGRAM_EXIT"
  cat "$LLVM_CONST_STRING_PROGRAM_RUN_OUTPUT"
  fail 'llvm-const-string-program-unexpected-exit'
fi
if ! grep -q '^hello$' "$LLVM_CONST_STRING_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_CONST_STRING_PROGRAM_RUN_OUTPUT"
  fail 'llvm-const-string-program-missing-stdout'
fi
printf 'llvm-const-string-program-stdout=hello\n'
printf 'llvm-const-string-program=pass\n'

printf 'llvm-string-concat-program=running\n'
printf 'llvm-string-concat-program-command=%s build examples/smoke/string_concat.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_STRING_CONCAT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/string_concat.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_STRING_CONCAT_PROGRAM_OUT_DIR" >"$LLVM_STRING_CONCAT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_STRING_CONCAT_PROGRAM_OUTPUT"
  fail 'llvm-string-concat-program-build-failed'
fi
cat "$LLVM_STRING_CONCAT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_STRING_CONCAT_PROGRAM_OUTPUT" 'missing-llvm-string-concat-program-success-status'
LLVM_STRING_CONCAT_PROGRAM_BIN="$LLVM_STRING_CONCAT_PROGRAM_OUT_DIR/string_concat"
if [ ! -x "$LLVM_STRING_CONCAT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-string-concat-program-executable'
fi
set +e
"$LLVM_STRING_CONCAT_PROGRAM_BIN" >"$LLVM_STRING_CONCAT_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_STRING_CONCAT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_STRING_CONCAT_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-string-concat-program-exit=%s\n' "$LLVM_STRING_CONCAT_PROGRAM_EXIT"
  cat "$LLVM_STRING_CONCAT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-string-concat-program-unexpected-exit'
fi
if ! grep -q '^hello, world$' "$LLVM_STRING_CONCAT_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_STRING_CONCAT_PROGRAM_RUN_OUTPUT"
  fail 'llvm-string-concat-program-missing-stdout'
fi
printf 'llvm-string-concat-program-stdout=hello, world\n'
printf 'llvm-string-concat-program=pass\n'

printf 'llvm-proc-greet-program=running\n'
printf 'llvm-proc-greet-program-command=%s build examples/smoke/proc_greet.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_PROC_GREET_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/proc_greet.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_PROC_GREET_PROGRAM_OUT_DIR" >"$LLVM_PROC_GREET_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_PROC_GREET_PROGRAM_OUTPUT"
  fail 'llvm-proc-greet-program-build-failed'
fi
cat "$LLVM_PROC_GREET_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_PROC_GREET_PROGRAM_OUTPUT" 'missing-llvm-proc-greet-program-success-status'
LLVM_PROC_GREET_PROGRAM_BIN="$LLVM_PROC_GREET_PROGRAM_OUT_DIR/proc_greet"
if [ ! -x "$LLVM_PROC_GREET_PROGRAM_BIN" ]; then
  fail 'missing-llvm-proc-greet-program-executable'
fi
set +e
"$LLVM_PROC_GREET_PROGRAM_BIN" >"$LLVM_PROC_GREET_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_PROC_GREET_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_PROC_GREET_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-proc-greet-program-exit=%s\n' "$LLVM_PROC_GREET_PROGRAM_EXIT"
  cat "$LLVM_PROC_GREET_PROGRAM_RUN_OUTPUT"
  fail 'llvm-proc-greet-program-unexpected-exit'
fi
if ! grep -q '^hi$' "$LLVM_PROC_GREET_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_PROC_GREET_PROGRAM_RUN_OUTPUT"
  fail 'llvm-proc-greet-program-missing-stdout'
fi
printf 'llvm-proc-greet-program-stdout=hi\n'
printf 'llvm-proc-greet-program=pass\n'

printf 'llvm-proc-two-program=running\n'
printf 'llvm-proc-two-program-command=%s build examples/smoke/proc_two.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_PROC_TWO_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/proc_two.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_PROC_TWO_PROGRAM_OUT_DIR" >"$LLVM_PROC_TWO_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_PROC_TWO_PROGRAM_OUTPUT"
  fail 'llvm-proc-two-program-build-failed'
fi
cat "$LLVM_PROC_TWO_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_PROC_TWO_PROGRAM_OUTPUT" 'missing-llvm-proc-two-program-success-status'
LLVM_PROC_TWO_PROGRAM_BIN="$LLVM_PROC_TWO_PROGRAM_OUT_DIR/proc_two"
if [ ! -x "$LLVM_PROC_TWO_PROGRAM_BIN" ]; then
  fail 'missing-llvm-proc-two-program-executable'
fi
set +e
"$LLVM_PROC_TWO_PROGRAM_BIN" >"$LLVM_PROC_TWO_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_PROC_TWO_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_PROC_TWO_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-proc-two-program-exit=%s\n' "$LLVM_PROC_TWO_PROGRAM_EXIT"
  cat "$LLVM_PROC_TWO_PROGRAM_RUN_OUTPUT"
  fail 'llvm-proc-two-program-unexpected-exit'
fi
LLVM_PROC_TWO_EXPECTED='a
b'
if [ "$(cat "$LLVM_PROC_TWO_PROGRAM_RUN_OUTPUT")" != "$LLVM_PROC_TWO_EXPECTED" ]; then
  cat "$LLVM_PROC_TWO_PROGRAM_RUN_OUTPUT"
  fail 'llvm-proc-two-program-missing-stdout'
fi
printf 'llvm-proc-two-program-stdout=a,b\n'
printf 'llvm-proc-two-program=pass\n'

printf 'llvm-fn-const-halt-program=running\n'
printf 'llvm-fn-const-halt-program-command=%s build examples/smoke/fn_const_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_FN_CONST_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/fn_const_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_FN_CONST_HALT_PROGRAM_OUT_DIR" >"$LLVM_FN_CONST_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_FN_CONST_HALT_PROGRAM_OUTPUT"
  fail 'llvm-fn-const-halt-program-build-failed'
fi
cat "$LLVM_FN_CONST_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_FN_CONST_HALT_PROGRAM_OUTPUT" 'missing-llvm-fn-const-halt-program-success-status'
LLVM_FN_CONST_HALT_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/fn_const_halt.ll"
if ! grep -q '(i64 42)' "$LLVM_FN_CONST_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_FN_CONST_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-fn-const-halt-program-ir-folded-fn-arg'
fi
LLVM_FN_CONST_HALT_PROGRAM_BIN="$LLVM_FN_CONST_HALT_PROGRAM_OUT_DIR/fn_const_halt"
if [ ! -x "$LLVM_FN_CONST_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-fn-const-halt-program-executable'
fi
set +e
"$LLVM_FN_CONST_HALT_PROGRAM_BIN"
LLVM_FN_CONST_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_FN_CONST_HALT_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-fn-const-halt-program-exit=%s\n' "$LLVM_FN_CONST_HALT_PROGRAM_EXIT"
  fail 'llvm-fn-const-halt-program-unexpected-exit'
fi
printf 'llvm-fn-const-halt-program-exit=42\n'
printf 'llvm-fn-const-halt-program=pass\n'

printf 'llvm-fn-compose-program=running\n'
printf 'llvm-fn-compose-program-command=%s build examples/smoke/fn_compose.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_FN_COMPOSE_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/fn_compose.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_FN_COMPOSE_PROGRAM_OUT_DIR" >"$LLVM_FN_COMPOSE_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_FN_COMPOSE_PROGRAM_OUTPUT"
  fail 'llvm-fn-compose-program-build-failed'
fi
cat "$LLVM_FN_COMPOSE_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_FN_COMPOSE_PROGRAM_OUTPUT" 'missing-llvm-fn-compose-program-success-status'
LLVM_FN_COMPOSE_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/fn_compose.ll"
if ! grep -q '(i64 14)' "$LLVM_FN_COMPOSE_PROGRAM_IR_PATH"; then
  cat "$LLVM_FN_COMPOSE_PROGRAM_IR_PATH"
  fail 'missing-llvm-fn-compose-program-ir-folded-fn-arg'
fi
LLVM_FN_COMPOSE_PROGRAM_BIN="$LLVM_FN_COMPOSE_PROGRAM_OUT_DIR/fn_compose"
if [ ! -x "$LLVM_FN_COMPOSE_PROGRAM_BIN" ]; then
  fail 'missing-llvm-fn-compose-program-executable'
fi
set +e
"$LLVM_FN_COMPOSE_PROGRAM_BIN"
LLVM_FN_COMPOSE_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_FN_COMPOSE_PROGRAM_EXIT" -ne 14 ]; then
  printf 'llvm-fn-compose-program-exit=%s\n' "$LLVM_FN_COMPOSE_PROGRAM_EXIT"
  fail 'llvm-fn-compose-program-unexpected-exit'
fi
printf 'llvm-fn-compose-program-exit=14\n'
printf 'llvm-fn-compose-program=pass\n'

printf 'llvm-fn-call-halt-program=running\n'
printf 'llvm-fn-call-halt-program-command=%s build examples/smoke/fn_call_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_FN_CALL_HALT_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/fn_call_halt.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_FN_CALL_HALT_PROGRAM_OUT_DIR" >"$LLVM_FN_CALL_HALT_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_FN_CALL_HALT_PROGRAM_OUTPUT"
  fail 'llvm-fn-call-halt-program-build-failed'
fi
cat "$LLVM_FN_CALL_HALT_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_FN_CALL_HALT_PROGRAM_OUTPUT" 'missing-llvm-fn-call-halt-program-success-status'
LLVM_FN_CALL_HALT_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/fn_call_halt.ll"
if ! grep -q '(i64 42)' "$LLVM_FN_CALL_HALT_PROGRAM_IR_PATH"; then
  cat "$LLVM_FN_CALL_HALT_PROGRAM_IR_PATH"
  fail 'missing-llvm-fn-call-halt-program-ir-folded-fn-arg'
fi
LLVM_FN_CALL_HALT_PROGRAM_BIN="$LLVM_FN_CALL_HALT_PROGRAM_OUT_DIR/fn_call_halt"
if [ ! -x "$LLVM_FN_CALL_HALT_PROGRAM_BIN" ]; then
  fail 'missing-llvm-fn-call-halt-program-executable'
fi
set +e
"$LLVM_FN_CALL_HALT_PROGRAM_BIN"
LLVM_FN_CALL_HALT_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_FN_CALL_HALT_PROGRAM_EXIT" -ne 42 ]; then
  printf 'llvm-fn-call-halt-program-exit=%s\n' "$LLVM_FN_CALL_HALT_PROGRAM_EXIT"
  fail 'llvm-fn-call-halt-program-unexpected-exit'
fi
printf 'llvm-fn-call-halt-program-exit=42\n'
printf 'llvm-fn-call-halt-program=pass\n'

printf 'llvm-fn-call-chain-program=running\n'
printf 'llvm-fn-call-chain-program-command=%s build examples/smoke/fn_call_chain.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_FN_CALL_CHAIN_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/fn_call_chain.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_FN_CALL_CHAIN_PROGRAM_OUT_DIR" >"$LLVM_FN_CALL_CHAIN_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_FN_CALL_CHAIN_PROGRAM_OUTPUT"
  fail 'llvm-fn-call-chain-program-build-failed'
fi
cat "$LLVM_FN_CALL_CHAIN_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_FN_CALL_CHAIN_PROGRAM_OUTPUT" 'missing-llvm-fn-call-chain-program-success-status'
LLVM_FN_CALL_CHAIN_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/fn_call_chain.ll"
if ! grep -q '(i64 15)' "$LLVM_FN_CALL_CHAIN_PROGRAM_IR_PATH"; then
  cat "$LLVM_FN_CALL_CHAIN_PROGRAM_IR_PATH"
  fail 'missing-llvm-fn-call-chain-program-ir-folded-fn-arg'
fi
LLVM_FN_CALL_CHAIN_PROGRAM_BIN="$LLVM_FN_CALL_CHAIN_PROGRAM_OUT_DIR/fn_call_chain"
if [ ! -x "$LLVM_FN_CALL_CHAIN_PROGRAM_BIN" ]; then
  fail 'missing-llvm-fn-call-chain-program-executable'
fi
set +e
"$LLVM_FN_CALL_CHAIN_PROGRAM_BIN"
LLVM_FN_CALL_CHAIN_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_FN_CALL_CHAIN_PROGRAM_EXIT" -ne 15 ]; then
  printf 'llvm-fn-call-chain-program-exit=%s\n' "$LLVM_FN_CALL_CHAIN_PROGRAM_EXIT"
  fail 'llvm-fn-call-chain-program-unexpected-exit'
fi
printf 'llvm-fn-call-chain-program-exit=15\n'
printf 'llvm-fn-call-chain-program=pass\n'

printf 'llvm-proc-arg-program=running\n'
printf 'llvm-proc-arg-program-command=%s build examples/smoke/proc_arg.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_PROC_ARG_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/proc_arg.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_PROC_ARG_PROGRAM_OUT_DIR" >"$LLVM_PROC_ARG_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_PROC_ARG_PROGRAM_OUTPUT"
  fail 'llvm-proc-arg-program-build-failed'
fi
cat "$LLVM_PROC_ARG_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_PROC_ARG_PROGRAM_OUTPUT" 'missing-llvm-proc-arg-program-success-status'
LLVM_PROC_ARG_PROGRAM_BIN="$LLVM_PROC_ARG_PROGRAM_OUT_DIR/proc_arg"
if [ ! -x "$LLVM_PROC_ARG_PROGRAM_BIN" ]; then
  fail 'missing-llvm-proc-arg-program-executable'
fi
set +e
"$LLVM_PROC_ARG_PROGRAM_BIN" >"$LLVM_PROC_ARG_PROGRAM_RUN_OUTPUT" 2>&1
LLVM_PROC_ARG_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_PROC_ARG_PROGRAM_EXIT" -ne 0 ]; then
  printf 'llvm-proc-arg-program-exit=%s\n' "$LLVM_PROC_ARG_PROGRAM_EXIT"
  cat "$LLVM_PROC_ARG_PROGRAM_RUN_OUTPUT"
  fail 'llvm-proc-arg-program-unexpected-exit'
fi
if ! grep -q '^42$' "$LLVM_PROC_ARG_PROGRAM_RUN_OUTPUT"; then
  cat "$LLVM_PROC_ARG_PROGRAM_RUN_OUTPUT"
  fail 'llvm-proc-arg-program-missing-stdout'
fi
printf 'llvm-proc-arg-program-stdout=42\n'
printf 'llvm-proc-arg-program=pass\n'

printf 'llvm-fn-square-program=running\n'
printf 'llvm-fn-square-program-command=%s build examples/smoke/fn_square.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target %s --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT" "$LLVM_FN_SQUARE_PROGRAM_OUT_DIR"
if ! "$STAGE0_BINARY" build examples/smoke/fn_square.pas --fold --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --target "$TARGET_ID" --workspace "$REPO_ROOT" --out-dir "$LLVM_FN_SQUARE_PROGRAM_OUT_DIR" >"$LLVM_FN_SQUARE_PROGRAM_OUTPUT" 2>&1; then
  cat "$LLVM_FN_SQUARE_PROGRAM_OUTPUT"
  fail 'llvm-fn-square-program-build-failed'
fi
cat "$LLVM_FN_SQUARE_PROGRAM_OUTPUT"
require_output_pattern '^status=success$' "$LLVM_FN_SQUARE_PROGRAM_OUTPUT" 'missing-llvm-fn-square-program-success-status'
LLVM_FN_SQUARE_PROGRAM_IR_PATH="$WORKSPACE_ARTIFACT_ROOT/cache/backend/$TARGET_ID/fn_square.ll"
if ! grep -q '(i64 49)' "$LLVM_FN_SQUARE_PROGRAM_IR_PATH"; then
  cat "$LLVM_FN_SQUARE_PROGRAM_IR_PATH"
  fail 'missing-llvm-fn-square-program-ir-folded-fn-arg'
fi
LLVM_FN_SQUARE_PROGRAM_BIN="$LLVM_FN_SQUARE_PROGRAM_OUT_DIR/fn_square"
if [ ! -x "$LLVM_FN_SQUARE_PROGRAM_BIN" ]; then
  fail 'missing-llvm-fn-square-program-executable'
fi
set +e
"$LLVM_FN_SQUARE_PROGRAM_BIN"
LLVM_FN_SQUARE_PROGRAM_EXIT=$?
set -e
if [ "$LLVM_FN_SQUARE_PROGRAM_EXIT" -ne 49 ]; then
  printf 'llvm-fn-square-program-exit=%s\n' "$LLVM_FN_SQUARE_PROGRAM_EXIT"
  fail 'llvm-fn-square-program-unexpected-exit'
fi
printf 'llvm-fn-square-program-exit=49\n'
printf 'llvm-fn-square-program=pass\n'

printf 'semantic-smoke-check=running\n'
printf 'semantic-smoke-command=%s build examples/smoke/hello_with_units.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if ! run_stage0_build_capture "$SEMANTIC_SMOKE_OUTPUT" examples/smoke/hello_with_units.pas; then
  cat "$SEMANTIC_SMOKE_OUTPUT"
  fail 'semantic-smoke-build-failed'
fi
cat "$SEMANTIC_SMOKE_OUTPUT"
require_output_pattern '^resolution-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-resolution-status'
require_output_pattern '^unit-graph-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-unit-graph-status'
require_output_pattern '^search-path-count=2$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-search-path-count'
require_output_pattern '^diagnostics-error-count=0$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-diagnostics-error-count'
require_output_pattern '^diagnostics-warning-count=0$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-diagnostics-warning-count'
require_output_pattern '^search-index-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-search-index-status'
require_output_pattern '^indexed-search-root-count=2$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-indexed-search-root-count'
require_output_pattern '^search-index-scan-count=2$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-search-index-scan-count'
require_output_pattern '^resolved-unit-count=4$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-resolved-unit-count'
require_output_pattern '^unit-graph-edge-count=4$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-unit-graph-edge-count'
require_output_pattern '^unit-graph-root-name=HelloWithUnits$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-unit-graph-root-name'
require_output_pattern '^semantic-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-status'
require_output_pattern '^symbol-graph-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-symbol-graph-status'
require_output_pattern '^type-graph-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-type-graph-status'
require_output_pattern '^typed-hir-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-typed-hir-status'
require_output_pattern '^symbol-count=4$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-symbol-count'
require_output_pattern '^type-count=18$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-type-count'
require_output_pattern '^typed-hir-node-count=7$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-typed-hir-node-count'
require_output_pattern '^runtime-contract-count=2$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-runtime-contract-count'
require_output_pattern '^typed-hir-root-name=HelloWithUnits$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-typed-hir-root-name'
require_output_pattern '^mir-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-mir-status'
require_output_pattern '^mir-block-count=1$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-mir-block-count'
require_output_pattern '^mir-operation-count=8$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-mir-operation-count'
require_output_pattern '^mir-entry-block=entry$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-mir-entry-block'
require_output_pattern '^mir-root-name=HelloWithUnits$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-mir-root-name'
require_output_pattern '^backend-plan-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-plan-status'
require_output_pattern '^backend-artifact-count=3$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-artifact-count'
require_output_pattern '^backend-artifacts=.*"kind":"assembly-text".*"kind":"object-file".*"kind":"executable"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-artifacts'
require_output_pattern '^backend-output-kind=executable$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-output-kind'
require_output_pattern '^backend-primary-artifact-kind=executable$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-primary-artifact-kind'
require_output_pattern '^backend-primary-artifact-path=.*/\.nextpas/out/linux-x86_64/hello_with_units$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-primary-artifact-path'
require_output_pattern '^backend-artifacts=.*"path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.s".*"path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.o".*"path":".*/\.nextpas/out/linux-x86_64/hello_with_units"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-artifact-paths'
require_output_pattern '^host-id=linux-x86_64$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-host-id'
require_output_pattern '^toolchain-binding-id=linux-x86_64-to-linux-x86_64-gnu$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-toolchain-binding'
require_output_pattern '^backend-family=native$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-family'
require_output_pattern '^target-object-format=elf$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-object-format'
require_output_pattern '^target-assembler-flavor=gnu-as$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-assembler-flavor'
require_output_pattern '^target-linker-flavor=gnu-ld$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-linker-flavor'
require_output_pattern '^target-runtime-layout-key=target-sdk-split$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-runtime-layout-key'
require_output_pattern '^target-c-symbol-prefix=$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-c-symbol-prefix'
require_output_pattern '^target-c-library-naming=lib-prefix-so-a$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-c-library-naming'
require_output_pattern '^target-llvm-triple=x86_64-unknown-linux-gnu$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-llvm-triple'
require_output_pattern '^target-llvm-data-layout=e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-llvm-data-layout'
require_output_pattern '^sysroot-mode=runtime-sdk$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-sysroot-mode'
require_output_pattern '^runtime-sdk-id=linux-x86_64$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-runtime-sdk-id'
require_output_pattern '^allow-host-fallback=false$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-allow-host-fallback'
require_output_pattern '^assembler-profile-id=gnu-as$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-assembler-profile-id'
require_output_pattern '^linker-profile-id=gnu-ld$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-linker-profile-id'
require_output_pattern '^archiver-profile-id=gnu-ar$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-archiver-profile-id'
require_output_pattern '^resource-tool-profile-id=none$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-resource-tool-profile-id'
require_output_pattern '^tool-root-kind=distribution-helper-root$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-root-kind'
require_output_pattern '^runtime-root-kind=distribution-runtime-root$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-runtime-root-kind'
require_output_pattern '^response-file-policy=auto$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-response-file-policy'
require_output_pattern '^link-script-policy=when-required$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-link-script-policy'
require_output_pattern '^toolchain-plan-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-toolchain-plan-status'
require_output_pattern '^toolchain-plan-family=bootstrap-native-assemble-link$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-toolchain-plan-family'
require_output_pattern '^tool-profile-root=.*/build/tool-profiles$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-profile-root'
require_output_pattern '^logical-link-request-status=ready$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-logical-link-request-status'
require_output_pattern '^logical-link-request-output-kind=executable$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-logical-link-request-output-kind'
require_output_pattern '^logical-link-request-library-count=0$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-logical-link-request-library-count'
require_output_pattern '^logical-link-request=.*"objectInputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.o"\}\]' "$SEMANTIC_SMOKE_OUTPUT" 'missing-logical-link-request-object-input'
require_output_pattern '^llvm-toolchain-status=disabled$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-llvm-toolchain-status'
require_output_pattern '^llvm-executable-set-id=llvm-stable$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-llvm-executable-set-id'
require_output_pattern '^tool-invocation-count=3$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-count'
require_output_pattern '^tool-run-status=success$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-run-status'
require_output_pattern '^tool-run-step-count=3$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-run-step-count'
require_output_pattern '^primary-tool-run-status=success$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-run-status'
require_output_pattern '^primary-tool-role=host-compiler$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-role'
require_output_pattern '^primary-tool-profile-id=fpc-stage0-host$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-profile-id'
require_output_pattern '^primary-tool-step-id=host-fpc-emit-asm$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-step-id'
require_output_pattern '^primary-tool-logical-executable=fpc$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-logical-executable'
require_output_pattern '^primary-tool-sysroot-ref=runtime-sdk:linux-x86_64$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-sysroot-ref'
require_output_pattern '^primary-tool-failure-mapping=toolchain.host-compiler-exec-failed$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-failure-mapping'
require_output_pattern '^tool-invocation-plan-ref=plan-build-linux-x86_64-.*-primary-tool$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan-ref'
require_output_pattern '^tool-invocation-plan=.*"planKind":"tool-invocation"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan'
require_output_pattern '^tool-invocation-plan=.*"planFamily":"bootstrap-native-assemble-link"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan-family'
require_output_pattern '^tool-invocation-plan=.*"stepId":"host-fpc-emit-asm".*"stepId":"native-assemble".*"stepId":"native-link"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan-step-id'
require_output_pattern '^tool-invocation-plan=.*"-st".*"-Aas".*"-FE.*/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/examples/smoke".*"-Fu.*/units/linux-x86_64".*".*/examples/smoke/hello_with_units\.pas"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan-argv'
require_output_pattern '^tool-invocation-plan=.*"inputs":\[\{"kind":"pascal-source","path":".*/examples/smoke/hello_with_units\.pas"\}\]' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan-inputs'
require_output_pattern '^tool-invocation-plan=.*"outputs":\[\{"kind":"assembly-text","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.s"\},\{"kind":"linker-script","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units_link\.res"\}\].*"outputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.o"\}\].*"outputs":\[\{"kind":"executable","path":".*/\.nextpas/out/linux-x86_64/hello_with_units"\}\]' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan-outputs'
require_output_pattern '^tool-status-event-count=10$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-status-event-count'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"host-fpc-emit-asm"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-host-tool-selected-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started".*"stepId":"host-fpc-emit-asm"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-host-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"host-fpc-emit-asm".*"status":"success"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-host-step-finished-success-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"native-assemble"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-assemble-tool-selected-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started".*"stepId":"native-assemble"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-assemble-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"native-assemble".*"status":"success"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-assemble-step-finished-success-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"native-link"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-link-tool-selected-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started".*"stepId":"native-link"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-link-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"native-link".*"status":"success"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-link-step-finished-success-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.plan-finished".*"stepId":"native-link".*"result":"success"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-plan-finished-success-event'
require_output_pattern '^build-trace-ref=trace-build-linux-x86_64-.*-toolchain-plan$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-success-build-trace-ref'
require_output_pattern '^build-trace=.*"traceKind":"toolchain-build-trace"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-success-build-trace'
require_output_pattern '^build-trace=.*"result":"success"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-success-build-trace-result'
require_output_pattern '^build-trace=.*"steps":\[\{"stepId":"host-fpc-emit-asm".*"status":"success".*"primaryOutputs":\[\{"kind":"assembly-text","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.s"\},\{"kind":"linker-script","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units_link\.res"\}\].*\{"stepId":"native-assemble".*"status":"success".*"primaryOutputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.o"\}\].*\{"stepId":"native-link".*"status":"success".*"primaryOutputs":\[\{"kind":"executable","path":".*/\.nextpas/out/linux-x86_64/hello_with_units"\}\]' "$SEMANTIC_SMOKE_OUTPUT" 'missing-success-build-trace-transcript'
require_output_pattern '^diagnostics-summary=none$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-diagnostics-summary'
require_output_pattern '^human-summary=build succeeded$' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-human-summary'
require_output_pattern '"resolvedUnitCount":4' "$SEMANTIC_SMOKE_OUTPUT" 'missing-resolution-envelope-field'
require_output_pattern '"semanticStatus":"ready"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-envelope-field'
require_output_pattern '"typedHirNodeCount":7' "$SEMANTIC_SMOKE_OUTPUT" 'missing-typed-hir-envelope-field'
require_output_pattern '"mirOperationCount":8' "$SEMANTIC_SMOKE_OUTPUT" 'missing-mir-envelope-field'
require_output_pattern '"backendPlanStatus":"ready"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-envelope-field'
require_output_pattern '"backendArtifactCount":3' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-artifact-count-envelope-field'
require_output_pattern '"backendArtifacts":\[\{"artifactId":1,"kind":"assembly-text","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.s"\},\{"artifactId":2,"kind":"object-file","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.o"\},\{"artifactId":3,"kind":"executable","path":"[^"]+/\.nextpas/out/linux-x86_64/hello_with_units"\}\]' "$SEMANTIC_SMOKE_OUTPUT" 'missing-backend-artifacts-envelope-field'
require_output_pattern '"hostId":"linux-x86_64"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-host-id-envelope-field'
require_output_pattern '"targetRuntimeLayoutKey":"target-sdk-split"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-runtime-layout-envelope-field'
require_output_pattern '"targetCSymbolPrefix":""' "$SEMANTIC_SMOKE_OUTPUT" 'missing-c-symbol-prefix-envelope-field'
require_output_pattern '"targetCLibraryNaming":"lib-prefix-so-a"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-c-library-naming-envelope-field'
require_output_pattern '"targetLlvmTriple":"x86_64-unknown-linux-gnu"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-target-llvm-triple-envelope-field'
require_output_pattern '"sysrootMode":"runtime-sdk"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-sysroot-envelope-field'
require_output_pattern '"runtimeSdkId":"linux-x86_64"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-runtime-sdk-envelope-field'
require_output_pattern '"allowHostFallback":false' "$SEMANTIC_SMOKE_OUTPUT" 'missing-allow-host-fallback-envelope-field'
require_output_pattern '"assemblerProfileId":"gnu-as"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-assembler-profile-envelope-field'
require_output_pattern '"linkerProfileId":"gnu-ld"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-linker-profile-envelope-field'
require_output_pattern '"archiverProfileId":"gnu-ar"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-archiver-profile-envelope-field'
require_output_pattern '"resourceToolProfileId":"none"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-resource-profile-envelope-field'
require_output_pattern '"toolRootKind":"distribution-helper-root"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-root-envelope-field'
require_output_pattern '"runtimeRootKind":"distribution-runtime-root"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-runtime-root-envelope-field'
require_output_pattern '"responseFilePolicy":"auto"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-response-file-envelope-field'
require_output_pattern '"linkScriptPolicy":"when-required"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-link-script-envelope-field'
require_output_pattern '"toolchainPlanStatus":"ready"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-toolchain-plan-envelope-field'
require_output_pattern '"toolRunStatus":"success"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-run-status-envelope-field'
require_output_pattern '"toolRunStepCount":3' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-run-step-count-envelope-field'
require_output_pattern '"primaryToolRunStatus":"success"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-run-status-envelope-field'
require_output_pattern '"toolchainPlanFamily":"bootstrap-native-assemble-link"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-toolchain-plan-family-envelope-field'
require_output_pattern '"toolProfileRoot":"[^"]+/build/tool-profiles"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-profile-root-envelope-field'
require_output_pattern '"logicalLinkRequest":\{"requestKind":"logical-link-request"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-logical-link-request-envelope-field'
require_output_pattern '"logicalLinkRequest":\{.*"objectInputs":\[\{"kind":"object-file","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello_with_units\.o"\}\]' "$SEMANTIC_SMOKE_OUTPUT" 'missing-logical-link-request-object-input-envelope-field'
require_output_pattern '"llvmExecutableSet":\{"contractKind":"llvm-executable-set"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-llvm-executable-set-envelope-field'
require_output_pattern '"primaryToolProfileId":"fpc-stage0-host"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-profile-envelope-field'
require_output_pattern '"primaryToolStepId":"host-fpc-emit-asm"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-step-envelope-field'
require_output_pattern '"primaryToolLogicalExecutable":"fpc"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-logical-executable-envelope-field'
require_output_pattern '"primaryToolSysrootRef":"runtime-sdk:linux-x86_64"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-sysroot-ref-envelope-field'
require_output_pattern '"primaryToolFailureMapping":"toolchain.host-compiler-exec-failed"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-primary-tool-failure-mapping-envelope-field'
require_output_pattern '"toolInvocationPlanRef":"plan-build-linux-x86_64-[^"]+-primary-tool"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan-ref-envelope-field'
require_output_pattern '"toolInvocationPlan":\{"planKind":"tool-invocation"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-tool-invocation-plan-envelope-field'
require_output_pattern '"diagnosticErrorCount":0' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-diagnostic-error-count-envelope-field'
require_output_pattern '"diagnosticWarningCount":0' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-diagnostic-warning-count-envelope-field'
require_output_pattern '"searchIndexStatus":"ready"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-search-index-status-envelope-field'
require_output_pattern '"indexedSearchRootCount":2' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-indexed-search-root-count-envelope-field'
require_output_pattern '"searchIndexScanCount":2' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-search-index-scan-count-envelope-field'
require_output_pattern '"diagnosticsSummary":"none"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-diagnostics-summary-envelope-field'
require_output_pattern '"buildTraceRef":"trace-build-linux-x86_64-[^"]+-toolchain-plan"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-success-envelope-build-trace-ref'
require_output_pattern '"buildTrace":\{"traceKind":"toolchain-build-trace"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-success-envelope-build-trace'
require_output_pattern '"toolStatusEvents":\[\{"eventKind":"toolchain.tool-selected"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-success-envelope-tool-status-events'
require_output_pattern '"humanSummary":"build succeeded"' "$SEMANTIC_SMOKE_OUTPUT" 'missing-semantic-smoke-human-summary-envelope-field'
if grep -Eq '^workspace-descriptor-path=' "$SEMANTIC_SMOKE_OUTPUT"; then
  fail 'unexpected-semantic-smoke-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$SEMANTIC_SMOKE_OUTPUT"; then
  fail 'unexpected-semantic-smoke-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$SEMANTIC_SMOKE_OUTPUT"; then
  fail 'unexpected-semantic-smoke-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$SEMANTIC_SMOKE_OUTPUT"; then
  fail 'unexpected-semantic-smoke-package-manifest-envelope-field'
fi
require_absent_path "$REPO_ROOT/examples/smoke/hello_with_units"
require_absent_path "$REPO_ROOT/examples/smoke/hello_with_units.o"
printf 'semantic-smoke-check=pass\n'

printf 'foreign-cdecl-smoke-check=running\n'
printf 'foreign-cdecl-smoke-command=%s build examples/smoke/external_cdecl_smoke.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if ! run_stage0_build_capture "$FOREIGN_CDECL_SMOKE_OUTPUT" examples/smoke/external_cdecl_smoke.pas; then
  cat "$FOREIGN_CDECL_SMOKE_OUTPUT"
  fail 'foreign-cdecl-smoke-build-failed'
fi
cat "$FOREIGN_CDECL_SMOKE_OUTPUT"
require_output_pattern '^semantic-status=ready$' "$FOREIGN_CDECL_SMOKE_OUTPUT" 'missing-foreign-cdecl-semantic-status'
require_output_pattern '^logical-link-request-library-count=1$' "$FOREIGN_CDECL_SMOKE_OUTPUT" 'missing-foreign-cdecl-library-count'
require_output_pattern '^logical-link-request=.*"libraryRequests":\[\{"logicalId":"c","linkageKind":"shared","strength":"strong"\}\]' "$FOREIGN_CDECL_SMOKE_OUTPUT" 'missing-foreign-cdecl-library-request'
require_output_pattern '"logicalLinkRequest":\{.*"libraryRequests":\[\{"logicalId":"c","linkageKind":"shared","strength":"strong"\}\]' "$FOREIGN_CDECL_SMOKE_OUTPUT" 'missing-foreign-cdecl-library-request-envelope-field'
require_output_pattern '^human-summary=build succeeded$' "$FOREIGN_CDECL_SMOKE_OUTPUT" 'missing-foreign-cdecl-human-summary'
printf 'foreign-cdecl-smoke-check=pass\n'

printf 'toolchain-contract-check=running\n'
rm -f "$REPO_ROOT/tests/toolchain/toolchain_contract_smoke"
rm -f "$REPO_ROOT/tests/toolchain/toolchain_contract_smoke.o"
printf 'toolchain-contract-command=fpc %s -FE%s -FU%s tests/toolchain/toolchain_contract_smoke.pas && %s\n' "$STAGE0_FPC_FLAGS" "$TOOLCHAIN_CONTRACT_BUILD_DIR" "$TOOLCHAIN_CONTRACT_BUILD_DIR" "$TOOLCHAIN_CONTRACT_BINARY"
if ! fpc $STAGE0_FPC_FLAGS -FE"$TOOLCHAIN_CONTRACT_BUILD_DIR" -FU"$TOOLCHAIN_CONTRACT_BUILD_DIR" tests/toolchain/toolchain_contract_smoke.pas >"$TOOLCHAIN_CONTRACT_OUTPUT" 2>&1; then
  cat "$TOOLCHAIN_CONTRACT_OUTPUT"
  fail 'toolchain-contract-build-failed'
fi
cat "$TOOLCHAIN_CONTRACT_OUTPUT"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$TOOLCHAIN_CONTRACT_BINARY" >>"$TOOLCHAIN_CONTRACT_OUTPUT" 2>&1; then
  cat "$TOOLCHAIN_CONTRACT_OUTPUT"
  fail 'toolchain-contract-run-failed'
fi
cat "$TOOLCHAIN_CONTRACT_OUTPUT"
require_absent_path "$REPO_ROOT/tests/toolchain/toolchain_contract_smoke"
require_absent_path "$REPO_ROOT/tests/toolchain/toolchain_contract_smoke.o"
require_output_pattern '^native-plan-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-plan-status'
require_output_pattern '^native-plan-family=native-assemble-link$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-plan-family'
require_output_pattern '^native-tool-invocation-count=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-tool-invocation-count'
require_output_pattern '^native-logical-library-request-count=1$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-logical-library-request-count'
require_output_pattern '^native-tool-profile-root=.*/build/tool-profiles$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-tool-profile-root'
require_output_pattern '^native-tool-invocation-plan=.*"stepId":"native-assemble"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-assemble-step'
require_output_pattern '^native-tool-invocation-plan=.*"stepId":"native-link"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-link-step'
require_output_pattern '^native-tool-invocation-plan=.*"kind":"response-file"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-response-file-sidecar'
require_output_pattern '^native-logical-link-request=.*"requestKind":"logical-link-request"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-logical-link-request'
require_output_pattern '^native-logical-link-request=.*"logicalId":"c"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-logical-library-request'
require_output_pattern '^resource-plan-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resource-plan-status'
require_output_pattern '^resource-plan-family=resource-compile$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resource-plan-family'
require_output_pattern '^resource-tool-invocation-count=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resource-tool-invocation-count'
require_output_pattern '^resource-tool-invocation-plan=.*"stepId":"rc-to-res"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resource-rc-step'
require_output_pattern '^resource-tool-invocation-plan=.*"stepId":"res-to-obj"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resource-res-step'
require_output_pattern '^resource-tool-invocation-plan=.*"kind":"resource-list-script"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resource-list-sidecar'
require_output_pattern '^archive-plan-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-archive-plan-status'
require_output_pattern '^archive-plan-family=archive-build$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-archive-plan-family'
require_output_pattern '^archive-tool-invocation-count=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-archive-tool-invocation-count'
require_output_pattern '^archive-tool-invocation-plan=.*"stepId":"archive-create"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-archive-create-step'
require_output_pattern '^archive-tool-invocation-plan=.*"stepId":"archive-index"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-archive-index-step'
require_output_pattern '^archive-tool-invocation-plan=.*"kind":"archive-command-script"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-archive-command-sidecar'
require_output_pattern '^llvm-enabled-plan-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-enabled-plan-status'
require_output_pattern '^llvm-enabled-toolchain-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-enabled-toolchain-status'
require_output_pattern '^llvm-enabled-set-id=llvm-stable$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-enabled-set-id'
require_output_pattern '^llvm-enabled-set=.*"contractKind":"llvm-executable-set"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-enabled-contract'
require_output_pattern '^llvm-missing-plan-status=failure$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-missing-plan-status'
require_output_pattern '^llvm-missing-toolchain-status=failure$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-missing-toolchain-status'
require_output_pattern '^llvm-missing-failure-code=backend\.llvm-toolchain-missing$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-missing-failure-code'
require_output_pattern '^llvm-exec-backend-plan-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-backend-plan-status'
require_output_pattern '^llvm-exec-backend-artifact-count=4$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-backend-artifact-count'
require_output_pattern '^llvm-exec-backend-artifacts=.*"kind":"llvm-ir".*"kind":"llvm-bitcode".*"kind":"object-file".*"kind":"executable"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-backend-artifacts'
require_output_pattern '^llvm-exec-plan-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-plan-status'
require_output_pattern '^llvm-exec-plan-family=llvm-ir-opt-llc-link$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-plan-family'
require_output_pattern '^llvm-exec-toolchain-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-toolchain-status'
require_output_pattern '^llvm-exec-tool-invocation-count=3$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-tool-invocation-count'
require_output_pattern '^llvm-exec-tool-invocation-plan=.*"stepId":"llvm-opt-bitcode"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-opt-step'
require_output_pattern '^llvm-exec-tool-invocation-plan=.*"stepId":"llvm-llc-object"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-llc-step'
require_output_pattern '^llvm-exec-tool-invocation-plan=.*"stepId":"llvm-link"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-link-step'
require_output_pattern '^llvm-exec-run-status=success$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-run-status'
require_output_pattern '^llvm-exec-run-step-count=3$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-run-step-count'
require_output_pattern '^llvm-exec-bitcode-exists=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-bitcode-exists'
require_output_pattern '^llvm-exec-object-exists=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-object-exists'
require_output_pattern '^llvm-exec-output-exists=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-output-exists'
require_output_pattern '^llvm-exec-link-contains-runtime-root=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-link-runtime-root'
require_output_pattern '^llvm-exec-link-contains-libc=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-link-libc'
require_output_pattern '^llvm-exec-run-transcript=.*"stepId":"llvm-opt-bitcode".*"status":"success"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-run-transcript-opt-step'
require_output_pattern '^llvm-exec-run-transcript=.*"stepId":"llvm-llc-object".*"status":"success"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-run-transcript-llc-step'
require_output_pattern '^llvm-exec-run-transcript=.*"stepId":"llvm-link".*"status":"success"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-llvm-exec-run-transcript-link-step'
require_output_pattern '^native-run-status=success$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-status'
require_output_pattern '^native-run-step-count=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-step-count'
require_output_pattern '^native-run-assemble-step-status=success$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-assemble-step-status'
require_output_pattern '^native-run-link-step-status=success$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-link-step-status'
require_output_pattern '^native-run-object-exists=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-object-exists'
require_output_pattern '^native-run-output-exists=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-output-exists'
require_output_pattern '^native-run-response-sidecar-cleaned=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-response-sidecar-cleaned'
require_output_pattern '^native-run-response-captured=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-response-captured'
require_output_pattern '^native-run-response-contains-object=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-response-contains-object'
require_output_pattern '^native-run-link-contains-runtime-root=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-link-runtime-root'
require_output_pattern '^native-run-link-contains-libc=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-link-libc'
require_output_pattern '^native-run-transcript=.*"stepId":"native-assemble".*"status":"success".*"sidecars":\[\]' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-transcript-assemble-step'
require_output_pattern '^native-run-transcript=.*"stepId":"native-link".*"status":"success".*"sidecars":\[\{"kind":"response-file","path":".*/toolchain-runner-fixture/artifacts/hello\.rsp","ownerStepId":"native-link","materializationTiming":"before-step-exec","cleanupPolicy":"delete-on-success","materialized":true,"cleanupStatus":"deleted"\}\]' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-native-run-transcript-link-sidecar'
require_output_pattern '^direct-link-missing-libc-plan-status=failure$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-direct-link-missing-libc-status'
require_output_pattern '^direct-link-missing-libc-failure-code=toolchain\.c-library-not-found$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-direct-link-missing-libc-failure-code'
require_output_pattern '^direct-link-missing-libc-failure-message=.*logicalId=c.*runtimeSdkId=linux-x86_64' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-direct-link-missing-libc-failure-message'
require_output_pattern '^diagnostics-error-count=0$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-toolchain-contract-error-count'
require_output_pattern '^diagnostics-warning-count=1$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-toolchain-contract-warning-count'
require_output_pattern '^diagnostics-warning-summary=driver\.synthetic-warning$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-toolchain-contract-warning-summary'
require_output_pattern '^diagnostics-warning-json=.*"severity":"warning"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-toolchain-contract-warning-json'
require_output_pattern '^diagnostics-warning-as-error-count=0$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-toolchain-contract-warning-as-error-count'
require_output_pattern '^diagnostics-warning-as-error-error-count=1$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-toolchain-contract-warning-as-error-error-count'
require_output_pattern '^diagnostics-warning-as-error-has-errors=true$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-toolchain-contract-warning-as-error-state'
require_output_pattern '^diagnostics-warning-as-error-json=.*"severity":"error"' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-toolchain-contract-warning-as-error-json'
require_output_pattern '^resolver-search-index-status-before=deferred$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resolver-search-index-status-before'
require_output_pattern '^resolver-indexed-root-count-before=0$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resolver-indexed-root-count-before'
require_output_pattern '^resolver-candidate-count=1$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resolver-candidate-count'
require_output_pattern '^resolver-search-index-scan-count=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resolver-search-index-scan-count'
require_output_pattern '^resolver-candidate-count-repeat=1$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resolver-candidate-count-repeat'
require_output_pattern '^resolver-search-index-status-after=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resolver-search-index-status-after'
require_output_pattern '^resolver-indexed-root-count-after=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resolver-indexed-root-count-after'
require_output_pattern '^resolver-search-index-scan-count-after-repeat=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-resolver-search-index-scan-count-after-repeat'
require_output_pattern '^workspace-model-explicit-root=.*/nextPas$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-root'
require_output_pattern '^workspace-model-explicit-discovery-kind=explicit-workspace-override$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-discovery-kind'
require_output_pattern '^workspace-model-explicit-descriptor-path=$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-descriptor-path'
require_output_pattern '^workspace-model-explicit-package-manifest-path=$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-package-manifest-path'
require_output_pattern '^workspace-model-explicit-package-ref-count=0$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-package-ref-count'
require_output_pattern '^workspace-model-explicit-source-root-count=0$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-source-root-count'
require_output_pattern '^workspace-model-explicit-artifact-root=.*/nextPas/\.nextpas$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-artifact-root'
require_output_pattern '^workspace-model-explicit-output-dir=.*/nextPas/\.nextpas/out/linux-x86_64$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-output-dir'
require_output_pattern '^workspace-model-explicit-host-cache-root=.*/nextPas/\.nextpas/cache/host-fpc/linux-x86_64$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-explicit-host-cache-root'
require_output_pattern '^workspace-model-package-root=.*/tests/fixtures/package_manifest_source_root$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-package-root'
require_output_pattern '^workspace-model-package-discovery-kind=nearest-package-manifest$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-package-discovery-kind'
require_output_pattern '^workspace-model-package-package-manifest-path=.*/tests/fixtures/package_manifest_source_root/nextpas\.package\.toml$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-package-manifest-path'
require_output_pattern '^workspace-model-package-package-ref-count=1$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-package-ref-count'
require_output_pattern '^workspace-model-package-source-root-count=1$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-package-source-root-count'
require_output_pattern '^workspace-model-package-artifact-root=.*/tests/fixtures/package_manifest_source_root/\.nextpas$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-package-artifact-root'
require_output_pattern '^workspace-model-package-output-dir=.*/tests/fixtures/package_manifest_source_root/\.nextpas/out/linux-x86_64$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-package-output-dir'
require_output_pattern '^workspace-model-member-root=.*/tests/fixtures/workspace_member_source_root$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-root'
require_output_pattern '^workspace-model-member-discovery-kind=nearest-workspace-descriptor$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-discovery-kind'
require_output_pattern '^workspace-model-member-descriptor-path=.*/tests/fixtures/workspace_member_source_root/nextpas\.workspace\.toml$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-descriptor-path'
require_output_pattern '^workspace-model-member-package-manifest-path=.*/tests/fixtures/workspace_member_source_root/app/nextpas\.package\.toml$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-package-manifest-path'
require_output_pattern '^workspace-model-member-package-ref-count=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-package-ref-count'
require_output_pattern '^workspace-model-member-source-root-count=2$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-source-root-count'
require_output_pattern '^workspace-model-member-artifact-root=.*/tests/fixtures/workspace_member_source_root/\.nextpas$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-artifact-root'
require_output_pattern '^workspace-model-member-output-dir=.*/tests/fixtures/workspace_member_source_root/\.nextpas/out/linux-x86_64$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-output-dir'
require_output_pattern '^workspace-model-member-host-cache-root=.*/tests/fixtures/workspace_member_source_root/\.nextpas/cache/host-fpc/linux-x86_64$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-workspace-model-member-host-cache-root'
require_output_pattern '^package-workflow-manifest-status=ready$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-package-workflow-manifest-status'
require_output_pattern '^package-workflow-lock-status=deferred$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-package-workflow-lock-status'
require_output_pattern '^package-install-plan-status=deferred$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-package-install-plan-status'
require_output_pattern '^package-workflow-source-root-count=[1-9][0-9]*$' "$TOOLCHAIN_CONTRACT_OUTPUT" 'missing-package-workflow-source-root-count'
printf 'toolchain-contract-check=pass\n'

printf 'toolchain-failure-check=running\n'
printf 'toolchain-failure-command=PATH=<fake-fpc>:$PATH %s build examples/smoke/hello.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
cat >"$TOOLCHAIN_FAILURE_BIN_DIR/fpc" <<'EOF'
#!/usr/bin/env sh
exit 23
EOF
chmod +x "$TOOLCHAIN_FAILURE_BIN_DIR/fpc"
if PATH="$TOOLCHAIN_FAILURE_BIN_DIR:$PATH" NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" build examples/smoke/hello.pas --target linux-x86_64 --workspace "$REPO_ROOT" >"$TOOLCHAIN_FAILURE_OUTPUT" 2>&1; then
  cat "$TOOLCHAIN_FAILURE_OUTPUT"
  fail 'expected-toolchain-failure-did-not-fail'
fi
cat "$TOOLCHAIN_FAILURE_OUTPUT"
require_output_pattern '^failure-kind=toolchain\.host-compiler-exec-failed$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-failure-kind'
require_output_pattern '^diagnostics-count=1$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-count'
require_output_pattern '^diagnostics-summary=toolchain\.host-compiler-exec-failed$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostics-summary'
require_output_pattern '^human-summary=toolchain\.host-compiler-exec-failed: compiler exit code 23$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-human-summary'
require_output_pattern '^diagnostic-code=toolchain\.host-compiler-exec-failed$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-code'
require_output_pattern '^diagnostic-phase=toolchain$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-phase'
require_output_pattern '^diagnostic-binding-id=linux-x86_64-to-linux-x86_64-gnu$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-binding-id'
require_output_pattern '^diagnostic-profile-id=fpc-stage0-host$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-profile-id'
require_output_pattern '^diagnostic-step-id=host-fpc-emit-asm$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-step-id'
require_output_pattern '^diagnostic-logical-executable=fpc$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-logical-executable'
require_output_pattern '^diagnostic-sysroot-ref=runtime-sdk:linux-x86_64$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-sysroot-ref'
require_output_pattern '^diagnostic-resolved-path=.*/fpc$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-resolved-path'
require_output_pattern '^diagnostic-primary-artifact-kind=executable$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-primary-artifact-kind'
require_output_pattern '^diagnostic-primary-artifact-path=.*/\.nextpas/out/linux-x86_64/hello$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-primary-artifact-path'
require_output_pattern '^diagnostic-exit-code=23$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-exit-code'
require_output_pattern '^diagnostic-id=diag-0001$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-id'
require_output_pattern '^assembler-profile-id=gnu-as$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-assembler-profile-id'
require_output_pattern '^linker-profile-id=gnu-ld$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-linker-profile-id'
require_output_pattern '^archiver-profile-id=gnu-ar$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-archiver-profile-id'
require_output_pattern '^resource-tool-profile-id=none$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-resource-tool-profile-id'
require_output_pattern '^tool-root-kind=distribution-helper-root$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-root-kind'
require_output_pattern '^runtime-root-kind=distribution-runtime-root$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-runtime-root-kind'
require_output_pattern '^response-file-policy=auto$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-response-file-policy'
require_output_pattern '^link-script-policy=when-required$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-link-script-policy'
require_output_pattern '^toolchain-plan-status=ready$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-plan-status'
require_output_pattern '^toolchain-plan-family=bootstrap-native-assemble-link$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-plan-family'
require_output_pattern '^tool-profile-root=.*/build/tool-profiles$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-profile-root'
require_output_pattern '^backend-artifact-count=3$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-backend-artifact-count'
require_output_pattern '^backend-artifacts=.*"kind":"assembly-text".*"kind":"object-file".*"kind":"executable"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-backend-artifacts'
require_output_pattern '^logical-link-request-status=ready$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-logical-link-request-status'
require_output_pattern '^logical-link-request-output-kind=executable$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-logical-link-request-output-kind'
require_output_pattern '^logical-link-request-library-count=0$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-logical-link-request-library-count'
require_output_pattern '^logical-link-request=.*"objectInputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\]' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-logical-link-request-object-input'
require_output_pattern '^llvm-toolchain-status=disabled$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-llvm-toolchain-status'
require_output_pattern '^llvm-executable-set-id=llvm-stable$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-llvm-executable-set-id'
require_output_pattern '^tool-run-status=failure$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-run-status'
require_output_pattern '^tool-run-step-count=1$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-run-step-count'
require_output_pattern '^primary-tool-run-status=failed$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-primary-tool-run-status'
require_output_pattern '^tool-invocation-plan-ref=plan-build-linux-x86_64-.*-primary-tool$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan-ref'
require_output_pattern '^tool-invocation-plan=.*"planKind":"tool-invocation"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan'
require_output_pattern '^tool-invocation-plan=.*"planFamily":"bootstrap-native-assemble-link"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan-family'
require_output_pattern '^tool-invocation-plan=.*"stepId":"host-fpc-emit-asm".*"stepId":"native-assemble".*"stepId":"native-link"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan-step-id'
require_output_pattern '^tool-invocation-plan=.*"-st".*"-Aas".*"-FE.*/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/examples/smoke".*"-Fu.*/units/linux-x86_64".*".*/examples/smoke/hello\.pas"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan-argv'
require_output_pattern '^tool-invocation-plan=.*"inputs":\[\{"kind":"pascal-source","path":".*/examples/smoke/hello\.pas"\}\]' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan-inputs'
require_output_pattern '^tool-invocation-plan=.*"outputs":\[\{"kind":"assembly-text","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.s"\},\{"kind":"linker-script","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_link\.res"\}\].*"outputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\].*"outputs":\[\{"kind":"executable","path":".*/\.nextpas/out/linux-x86_64/hello"\}\]' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan-outputs'
require_output_pattern '^backend-artifacts=.*"path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.s".*"path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o".*"path":".*/\.nextpas/out/linux-x86_64/hello"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-backend-artifact-paths'
require_output_pattern '^tool-status-event-count=4$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-status-event-count'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-selected-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"status":"failed"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-step-finished-failed-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.plan-finished".*"result":"failed"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-plan-finished-failed-event'
require_output_pattern '^build-trace-ref=trace-build-linux-x86_64-.*-toolchain-plan$' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-ref'
require_output_pattern '^build-trace=\{' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace'
require_output_pattern '"code":"toolchain.host-compiler-exec-failed"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-code'
require_output_pattern '"id":"diag-0001"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-id'
require_output_pattern '"phase":"toolchain"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-phase'
require_output_pattern '"bindingId":"linux-x86_64-to-linux-x86_64-gnu"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-binding-id'
require_output_pattern '"profileId":"fpc-stage0-host"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-profile-id'
require_output_pattern '"stepId":"host-fpc-emit-asm"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-step-id'
require_output_pattern '"logicalExecutable":"fpc"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-logical-executable'
require_output_pattern '"sysrootRef":"runtime-sdk:linux-x86_64"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-sysroot-ref'
require_output_pattern '"resolvedPath":"[^"]+/fpc"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-resolved-path'
require_output_pattern '"primaryArtifact":\{' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-primary-artifact'
require_output_pattern '"kind":"executable","path":"[^"]+/\.nextpas/out/linux-x86_64/hello"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-primary-artifact-fields'
require_output_pattern '"exitCode":23' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostic-envelope-exit-code'
require_output_pattern '"buildTraceRef":"trace-build-linux-x86_64-[^"]+-toolchain-plan"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-envelope-build-trace-ref'
require_output_pattern '"traceKind":"toolchain-build-trace"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-kind'
require_output_pattern '"bindingId":"linux-x86_64-to-linux-x86_64-gnu"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-binding-id'
require_output_pattern '"hostId":"linux-x86_64"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-host-id'
require_output_pattern '"targetId":"linux-x86_64"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-target-id'
require_output_pattern '"result":"failed"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-result'
require_output_pattern '"steps":\[\{"stepId":"host-fpc-emit-asm".*"status":"failed"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-step-status'
require_output_pattern '"primaryOutputs":\[\{"kind":"assembly-text","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello\.s"\},\{"kind":"linker-script","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello_link\.res"\}\]' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-primary-output'
require_output_pattern '"diagnosticRefs":\["diag-0001"\]' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-diagnostic-refs'
require_output_pattern '"assemblerProfileId":"gnu-as"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-assembler-profile-envelope-field'
require_output_pattern '"linkerProfileId":"gnu-ld"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-linker-profile-envelope-field'
require_output_pattern '"archiverProfileId":"gnu-ar"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-archiver-profile-envelope-field'
require_output_pattern '"resourceToolProfileId":"none"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-resource-profile-envelope-field'
require_output_pattern '"toolRootKind":"distribution-helper-root"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-root-envelope-field'
require_output_pattern '"runtimeRootKind":"distribution-runtime-root"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-runtime-root-envelope-field'
require_output_pattern '"responseFilePolicy":"auto"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-response-file-envelope-field'
require_output_pattern '"linkScriptPolicy":"when-required"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-link-script-envelope-field'
require_output_pattern '"toolchainPlanStatus":"ready"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-plan-envelope-field'
require_output_pattern '"backendArtifactCount":3' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-backend-artifact-count-envelope-field'
require_output_pattern '"backendArtifacts":\[\{"artifactId":1,"kind":"assembly-text","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello\.s"\},\{"artifactId":2,"kind":"object-file","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello\.o"\},\{"artifactId":3,"kind":"executable","path":"[^"]+/\.nextpas/out/linux-x86_64/hello"\}\]' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-backend-artifacts-envelope-field'
require_output_pattern '"toolRunStatus":"failure"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-run-status-envelope-field'
require_output_pattern '"toolRunStepCount":1' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-run-step-count-envelope-field'
require_output_pattern '"primaryToolRunStatus":"failed"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-primary-tool-run-status-envelope-field'
require_output_pattern '"toolchainPlanFamily":"bootstrap-native-assemble-link"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-plan-family-envelope-field'
require_output_pattern '"toolProfileRoot":"[^"]+/build/tool-profiles"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-profile-root-envelope-field'
require_output_pattern '"logicalLinkRequest":\{"requestKind":"logical-link-request"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-logical-link-request-envelope-field'
require_output_pattern '"logicalLinkRequest":\{.*"objectInputs":\[\{"kind":"object-file","path":"[^"]+/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\]' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-logical-link-request-object-input-envelope-field'
require_output_pattern '"llvmExecutableSet":\{"contractKind":"llvm-executable-set"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-llvm-executable-set-envelope-field'
require_output_pattern '"toolInvocationPlanRef":"plan-build-linux-x86_64-[^"]+-primary-tool"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan-ref-envelope-field'
require_output_pattern '"toolInvocationPlan":\{"planKind":"tool-invocation"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-tool-invocation-plan-envelope-field'
require_output_pattern '"toolStatusEvents":\[\{"eventKind":"toolchain.tool-selected"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-envelope-tool-status-events'
require_output_pattern '"diagnosticsSummary":"toolchain.host-compiler-exec-failed"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-diagnostics-summary-envelope-field'
require_output_pattern '"humanSummary":"toolchain.host-compiler-exec-failed: compiler exit code 23"' "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-human-summary-envelope-field'
TOOLCHAIN_FAILURE_SESSION_ID=$(extract_output_value 'session-id' "$TOOLCHAIN_FAILURE_OUTPUT")
TOOLCHAIN_FAILURE_PLAN_REF=$(extract_output_value 'tool-invocation-plan-ref' "$TOOLCHAIN_FAILURE_OUTPUT")
TOOLCHAIN_FAILURE_TRACE_REF=$(extract_output_value 'build-trace-ref' "$TOOLCHAIN_FAILURE_OUTPUT")
if [ -z "$TOOLCHAIN_FAILURE_SESSION_ID" ] || [ -z "$TOOLCHAIN_FAILURE_PLAN_REF" ] || [ -z "$TOOLCHAIN_FAILURE_TRACE_REF" ]; then
  fail 'missing-toolchain-failure-derived-identifiers'
fi
require_output_literal "\"sessionId\":\"$TOOLCHAIN_FAILURE_SESSION_ID\"" "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-session-id'
require_output_literal "\"planId\":\"$TOOLCHAIN_FAILURE_PLAN_REF\"" "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-build-trace-plan-id'
require_output_literal "\"buildTraceRef\":\"$TOOLCHAIN_FAILURE_TRACE_REF\"" "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-envelope-derived-build-trace-ref'
require_output_literal "\"toolInvocationPlanRef\":\"$TOOLCHAIN_FAILURE_PLAN_REF\"" "$TOOLCHAIN_FAILURE_OUTPUT" 'missing-toolchain-envelope-derived-plan-ref'
if grep -Eq '^workspace-descriptor-path=' "$TOOLCHAIN_FAILURE_OUTPUT"; then
  fail 'unexpected-toolchain-failure-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$TOOLCHAIN_FAILURE_OUTPUT"; then
  fail 'unexpected-toolchain-failure-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$TOOLCHAIN_FAILURE_OUTPUT"; then
  fail 'unexpected-toolchain-failure-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$TOOLCHAIN_FAILURE_OUTPUT"; then
  fail 'unexpected-toolchain-failure-package-manifest-envelope-field'
fi
printf 'toolchain-failure-check=pass\n'

printf 'assembler-failure-attribution-check=running\n'
printf 'assembler-failure-attribution-command=PATH=<fake-as>:$PATH %s build examples/smoke/hello.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
cat >"$ASSEMBLER_FAILURE_BIN_DIR/as" <<'EOF'
#!/usr/bin/env sh
exit 17
EOF
chmod +x "$ASSEMBLER_FAILURE_BIN_DIR/as"
if PATH="$ASSEMBLER_FAILURE_BIN_DIR:$PATH" NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" build examples/smoke/hello.pas --target linux-x86_64 --workspace "$REPO_ROOT" >"$ASSEMBLER_FAILURE_OUTPUT" 2>&1; then
  cat "$ASSEMBLER_FAILURE_OUTPUT"
  fail 'expected-assembler-failure-did-not-fail'
fi
cat "$ASSEMBLER_FAILURE_OUTPUT"
require_output_pattern '^failure-kind=toolchain\.assembler-exec-failed$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-failure-kind'
require_output_pattern '^diagnostic-code=toolchain\.assembler-exec-failed$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-diagnostic-code'
require_output_pattern '^diagnostic-profile-id=gnu-as$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-diagnostic-profile-id'
require_output_pattern '^diagnostic-step-id=native-assemble$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-diagnostic-step-id'
require_output_pattern '^diagnostic-logical-executable=as$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-diagnostic-logical-executable'
require_output_pattern '^diagnostic-resolved-path=.*/as$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-diagnostic-resolved-path'
require_output_pattern '^diagnostic-exit-code=17$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-diagnostic-exit-code'
require_output_pattern '^human-summary=toolchain\.assembler-exec-failed: compiler exit code 17$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-human-summary'
require_output_pattern '^tool-run-status=failure$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-tool-run-status'
require_output_pattern '^tool-run-step-count=2$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-tool-run-step-count'
require_output_pattern '^primary-tool-run-status=success$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-primary-tool-run-status'
require_output_pattern '^tool-status-event-count=7$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-tool-status-event-count'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"host-fpc-emit-asm"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-host-tool-selected-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"host-fpc-emit-asm".*"status":"success"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-host-step-finished-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"native-assemble".*"logicalExecutable":"as"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-tool-status-events-step'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started".*"stepId":"native-assemble".*"logicalExecutable":"as"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"native-assemble".*"logicalExecutable":"as".*"status":"failed"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-step-finished-failed-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.plan-finished".*"stepId":"native-assemble".*"result":"failed"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-plan-finished-event'
require_output_pattern '^build-trace-ref=trace-build-linux-x86_64-.*-toolchain-plan$' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-build-trace-ref'
require_output_pattern '^build-trace=.*"stepId":"host-fpc-emit-asm".*"status":"success".*"primaryOutputs":\[\{"kind":"assembly-text","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.s"\},\{"kind":"linker-script","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_link\.res"\}\]' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-build-trace-host-step'
require_output_pattern '^build-trace=.*"stepId":"native-assemble".*"profileId":"gnu-as".*"toolRole":"assembler".*"status":"failed".*"logicalExecutable":"as".*"resolvedPath":"[^"]+/as".*"primaryOutputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\].*"diagnosticRefs":\["diag-0001"\]' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-build-trace-transcript'
require_output_pattern '"failureKind":"toolchain.assembler-exec-failed"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-failure-kind'
require_output_pattern '"profileId":"gnu-as"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-profile-id'
require_output_pattern '"stepId":"native-assemble"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-step-id'
require_output_pattern '"logicalExecutable":"as"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-logical-executable'
require_output_pattern '"resolvedPath":"[^"]+/as"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-resolved-path'
require_output_pattern '"exitCode":17' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-exit-code'
require_output_pattern '"buildTraceRef":"trace-build-linux-x86_64-[^"]+-toolchain-plan"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-build-trace-ref'
require_output_pattern '"toolRunStatus":"failure"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-tool-run-status'
require_output_pattern '"toolRunStepCount":2' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-tool-run-step-count'
require_output_pattern '"primaryToolRunStatus":"success"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-primary-tool-run-status'
require_output_pattern '"humanSummary":"toolchain.assembler-exec-failed: compiler exit code 17"' "$ASSEMBLER_FAILURE_OUTPUT" 'missing-assembler-envelope-human-summary'
printf 'assembler-failure-attribution-check=pass\n'

printf 'linker-failure-attribution-check=running\n'
printf 'linker-failure-attribution-command=PATH=<fake-ld>:$PATH %s build examples/smoke/hello.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
cat >"$LINKER_FAILURE_BIN_DIR/ld.bfd" <<'EOF'
#!/usr/bin/env sh
exit 29
EOF
chmod +x "$LINKER_FAILURE_BIN_DIR/ld.bfd"
if PATH="$LINKER_FAILURE_BIN_DIR:$PATH" NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" build examples/smoke/hello.pas --target linux-x86_64 --workspace "$REPO_ROOT" >"$LINKER_FAILURE_OUTPUT" 2>&1; then
  cat "$LINKER_FAILURE_OUTPUT"
  fail 'expected-linker-failure-did-not-fail'
fi
cat "$LINKER_FAILURE_OUTPUT"
require_output_pattern '^failure-kind=toolchain\.linker-exec-failed$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-failure-kind'
require_output_pattern '^diagnostic-code=toolchain\.linker-exec-failed$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-diagnostic-code'
require_output_pattern '^diagnostic-profile-id=gnu-ld$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-diagnostic-profile-id'
require_output_pattern '^diagnostic-step-id=native-link$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-diagnostic-step-id'
require_output_pattern '^diagnostic-logical-executable=ld\.bfd$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-diagnostic-logical-executable'
require_output_pattern '^diagnostic-resolved-path=.*/ld\.bfd$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-diagnostic-resolved-path'
require_output_pattern '^diagnostic-exit-code=29$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-diagnostic-exit-code'
require_output_pattern '^human-summary=toolchain\.linker-exec-failed: compiler exit code 29$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-human-summary'
require_output_pattern '^tool-run-status=failure$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-tool-run-status'
require_output_pattern '^tool-run-step-count=3$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-tool-run-step-count'
require_output_pattern '^primary-tool-run-status=success$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-primary-tool-run-status'
require_output_pattern '^tool-status-event-count=10$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-tool-status-event-count'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"host-fpc-emit-asm".*"status":"success"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-host-step-finished-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"native-assemble".*"status":"success"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-assemble-step-finished-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.tool-selected".*"stepId":"native-link".*"logicalExecutable":"ld\.bfd"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-tool-status-events-step'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-started".*"stepId":"native-link".*"logicalExecutable":"ld\.bfd"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-step-started-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.step-finished".*"stepId":"native-link".*"logicalExecutable":"ld\.bfd".*"status":"failed"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-step-finished-failed-event'
require_output_pattern '^tool-status-events=.*"eventKind":"toolchain.plan-finished".*"stepId":"native-link".*"result":"failed"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-plan-finished-event'
require_output_pattern '^build-trace-ref=trace-build-linux-x86_64-.*-toolchain-plan$' "$LINKER_FAILURE_OUTPUT" 'missing-linker-build-trace-ref'
require_output_pattern '^build-trace=.*"stepId":"host-fpc-emit-asm".*"status":"success".*"primaryOutputs":\[\{"kind":"assembly-text","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.s"\},\{"kind":"linker-script","path":".*/\.nextpas/cache/backend/linux-x86_64/hello_link\.res"\}\]' "$LINKER_FAILURE_OUTPUT" 'missing-linker-build-trace-host-step'
require_output_pattern '^build-trace=.*"stepId":"native-assemble".*"status":"success".*"primaryOutputs":\[\{"kind":"object-file","path":".*/\.nextpas/cache/backend/linux-x86_64/hello\.o"\}\]' "$LINKER_FAILURE_OUTPUT" 'missing-linker-build-trace-assemble-step'
require_output_pattern '^build-trace=.*"stepId":"native-link".*"profileId":"gnu-ld".*"toolRole":"linker".*"status":"failed".*"logicalExecutable":"ld\.bfd".*"resolvedPath":"[^"]+/ld\.bfd".*"primaryOutputs":\[\{"kind":"executable","path":".*/\.nextpas/out/linux-x86_64/hello"\}\].*"diagnosticRefs":\["diag-0001"\]' "$LINKER_FAILURE_OUTPUT" 'missing-linker-build-trace-transcript'
require_output_pattern '"failureKind":"toolchain.linker-exec-failed"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-failure-kind'
require_output_pattern '"profileId":"gnu-ld"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-profile-id'
require_output_pattern '"stepId":"native-link"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-step-id'
require_output_pattern '"logicalExecutable":"ld.bfd"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-logical-executable'
require_output_pattern '"resolvedPath":"[^"]+/ld\.bfd"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-resolved-path'
require_output_pattern '"exitCode":29' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-exit-code'
require_output_pattern '"buildTraceRef":"trace-build-linux-x86_64-[^"]+-toolchain-plan"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-build-trace-ref'
require_output_pattern '"toolRunStatus":"failure"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-tool-run-status'
require_output_pattern '"toolRunStepCount":3' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-tool-run-step-count'
require_output_pattern '"primaryToolRunStatus":"success"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-primary-tool-run-status'
require_output_pattern '"humanSummary":"toolchain.linker-exec-failed: compiler exit code 29"' "$LINKER_FAILURE_OUTPUT" 'missing-linker-envelope-human-summary'
printf 'linker-failure-attribution-check=pass\n'

printf 'core-text-smoke-check=running\n'
printf 'core-text-smoke-command=fpc -Fu/home/dtamade/projects/nextPas/rtl/core/base -Fu/home/dtamade/projects/nextPas/rtl/core/text tests/rtl/core_text_smoke.pas\n'
mkdir -p /home/dtamade/projects/nextPas/.sisyphus/tmp
mkdir -p /home/dtamade/projects/nextPas/.sisyphus/tmp/rtl-core-text-green
rm -f .sisyphus/tmp/core_text_smoke
if ! fpc \
  -Fu/home/dtamade/projects/nextPas/rtl/core/base \
  -Fu/home/dtamade/projects/nextPas/rtl/core/text \
  -FU/home/dtamade/projects/nextPas/.sisyphus/tmp/rtl-core-text-green \
  -FE/home/dtamade/projects/nextPas/.sisyphus/tmp \
  tests/rtl/core_text_smoke.pas >"$CORE_TEXT_SMOKE_OUTPUT" 2>&1; then
  cat "$CORE_TEXT_SMOKE_OUTPUT"
  fail 'core-text-smoke-build-failed'
fi
cat "$CORE_TEXT_SMOKE_OUTPUT"
if ! /home/dtamade/projects/nextPas/.sisyphus/tmp/core_text_smoke >>"$CORE_TEXT_SMOKE_OUTPUT" 2>&1; then
  cat "$CORE_TEXT_SMOKE_OUTPUT"
  fail 'core-text-smoke-run-failed'
fi
cat "$CORE_TEXT_SMOKE_OUTPUT"
require_output_pattern '^identity=stage0greeter$' "$CORE_TEXT_SMOKE_OUTPUT" 'missing-core-text-identity-output'
require_output_pattern '^canonical-path=' "$CORE_TEXT_SMOKE_OUTPUT" 'missing-core-text-path-output'
require_output_pattern '^text-length=' "$CORE_TEXT_SMOKE_OUTPUT" 'missing-core-text-length-output'
printf 'core-text-smoke-check=pass\n'

printf 'rtl-sysutils-check=running\n'
RTL_SYSUTILS_OUTPUT=$(mktemp)
RTL_SYSUTILS_BIN=$(mktemp)
printf 'rtl-sysutils-command=fpc -Fu%s/rtl/core/sysutils %s/rtl/core/sysutils/np_sysutils_test.pas\n' "$REPO_ROOT" "$REPO_ROOT"
if ! fpc \
  -Fu"$REPO_ROOT/rtl/core/sysutils" \
  -o"$RTL_SYSUTILS_BIN" \
  "$REPO_ROOT/rtl/core/sysutils/np_sysutils_test.pas" \
  >"$RTL_SYSUTILS_OUTPUT" 2>&1; then
  cat "$RTL_SYSUTILS_OUTPUT"
  fail 'rtl-sysutils-build-failed'
fi
if ! "$RTL_SYSUTILS_BIN" >"$RTL_SYSUTILS_OUTPUT" 2>&1; then
  cat "$RTL_SYSUTILS_OUTPUT"
  fail 'rtl-sysutils-run-failed'
fi
cat "$RTL_SYSUTILS_OUTPUT"
require_output_pattern '^Tests passed: 64$' "$RTL_SYSUTILS_OUTPUT" 'missing-rtl-sysutils-pass-count'
require_output_pattern '^Tests failed: 0$' "$RTL_SYSUTILS_OUTPUT" 'missing-rtl-sysutils-zero-failures'
printf 'rtl-sysutils-check=pass\n'

printf 'syntax-failure-check=running\n'
printf 'syntax-failure-command=%s build tests/compiler/fail/missing_semicolon_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$SYNTAX_FAILURE_OUTPUT" tests/compiler/fail/missing_semicolon_fail.pas; then
  cat "$SYNTAX_FAILURE_OUTPUT"
  fail 'expected-syntax-failure-did-not-fail'
fi
cat "$SYNTAX_FAILURE_OUTPUT"
require_output_pattern '^failure-kind=syntax-analysis-failed$' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-failure-kind'
require_output_pattern '^diagnostics-count=1$' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-diagnostic-count'
require_output_pattern '^diagnostics-summary=parser\.syntax-error$' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-diagnostics-summary'
require_output_pattern '^diagnostic-code=parser.syntax-error$' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-diagnostic-code'
require_output_pattern '^diagnostic-phase=syntax$' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-diagnostic-phase'
require_output_pattern '^human-summary=syntax-analysis-failed$' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-human-summary'
require_output_pattern '"code":"parser.syntax-error"' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-diagnostic-envelope'
require_output_pattern '"diagnosticsSummary":"parser.syntax-error"' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-diagnostics-summary-envelope-field'
require_output_pattern '"humanSummary":"syntax-analysis-failed"' "$SYNTAX_FAILURE_OUTPUT" 'missing-syntax-human-summary-envelope-field'
printf 'syntax-failure-check=pass\n'

printf 'missing-unit-check=running\n'
printf 'missing-unit-command=%s build tests/compiler/fail/missing_unit_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$MISSING_UNIT_OUTPUT" tests/compiler/fail/missing_unit_fail.pas; then
  cat "$MISSING_UNIT_OUTPUT"
  fail 'expected-missing-unit-failure-did-not-fail'
fi
cat "$MISSING_UNIT_OUTPUT"
require_output_pattern '^failure-kind=unit-resolution-failed$' "$MISSING_UNIT_OUTPUT" 'missing-unit-failure-kind'
require_output_pattern '^diagnostics-summary=resolver\.unit-not-found$' "$MISSING_UNIT_OUTPUT" 'missing-unit-diagnostics-summary'
require_output_pattern '^diagnostic-code=resolver.unit-not-found$' "$MISSING_UNIT_OUTPUT" 'missing-unit-diagnostic-code'
require_output_pattern '^diagnostic-phase=resolution$' "$MISSING_UNIT_OUTPUT" 'missing-unit-diagnostic-phase'
require_output_pattern '^diagnostic-message=unit "MissingUnit" not found; searched roots: .*scope=root-source .*root=.*/tests/compiler/fail.*scope=target-installed .*root=.*/units/linux-x86_64.*$' "$MISSING_UNIT_OUTPUT" 'missing-unit-diagnostic-provenance'
require_output_pattern '"code":"resolver.unit-not-found"' "$MISSING_UNIT_OUTPUT" 'missing-unit-diagnostic-envelope'
require_output_pattern '^human-summary=unit-resolution-failed$' "$MISSING_UNIT_OUTPUT" 'missing-unit-human-summary'
require_output_pattern '"diagnosticsSummary":"resolver.unit-not-found"' "$MISSING_UNIT_OUTPUT" 'missing-unit-diagnostics-summary-envelope-field'
require_output_pattern '"humanSummary":"unit-resolution-failed"' "$MISSING_UNIT_OUTPUT" 'missing-unit-human-summary-envelope-field'
printf 'missing-unit-check=pass\n'

printf 'ambiguous-unit-check=running\n'
printf 'ambiguous-unit-command=%s build tests/compiler/fail/ambiguous_unit_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$AMBIGUOUS_UNIT_OUTPUT" tests/compiler/fail/ambiguous_unit_fail.pas; then
  cat "$AMBIGUOUS_UNIT_OUTPUT"
  fail 'expected-ambiguous-unit-failure-did-not-fail'
fi
cat "$AMBIGUOUS_UNIT_OUTPUT"
require_output_pattern '^failure-kind=unit-resolution-failed$' "$AMBIGUOUS_UNIT_OUTPUT" 'missing-ambiguous-unit-failure-kind'
require_output_pattern '^diagnostic-code=resolver.ambiguous-unit-source$' "$AMBIGUOUS_UNIT_OUTPUT" 'missing-ambiguous-unit-diagnostic-code'
require_output_pattern '^diagnostic-phase=resolution$' "$AMBIGUOUS_UNIT_OUTPUT" 'missing-ambiguous-unit-diagnostic-phase'
require_output_pattern '^diagnostic-message=unit "AmbiguousHelper" resolved to multiple sources: .*path=.*/units/linux-x86_64/AmbiguousHelper\.pas .*scope=target-installed .*root=.*/units/linux-x86_64.*path=.*/units/linux-x86_64/AMBIGUOUSHELPER\.pas .*scope=target-installed .*root=.*/units/linux-x86_64.*$' "$AMBIGUOUS_UNIT_OUTPUT" 'missing-ambiguous-unit-diagnostic-provenance'
require_output_pattern '"code":"resolver.ambiguous-unit-source"' "$AMBIGUOUS_UNIT_OUTPUT" 'missing-ambiguous-unit-diagnostic-envelope'
printf 'ambiguous-unit-check=pass\n'

printf 'multiple-missing-units-check=running\n'
printf 'multiple-missing-units-command=%s build tests/compiler/fail/multiple_missing_units_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$MULTIPLE_MISSING_OUTPUT" tests/compiler/fail/multiple_missing_units_fail.pas; then
  cat "$MULTIPLE_MISSING_OUTPUT"
  fail 'expected-multiple-missing-units-failure-did-not-fail'
fi
cat "$MULTIPLE_MISSING_OUTPUT"
require_output_pattern '^failure-kind=unit-resolution-failed$' "$MULTIPLE_MISSING_OUTPUT" 'missing-multiple-missing-units-failure-kind'
require_output_pattern '^diagnostics-count=2$' "$MULTIPLE_MISSING_OUTPUT" 'missing-multiple-diagnostics-count'
require_output_pattern 'MissingUnitA.*not found' "$MULTIPLE_MISSING_OUTPUT" 'missing-first-unit-diagnostic'
require_output_pattern 'MissingUnitB.*not found' "$MULTIPLE_MISSING_OUTPUT" 'missing-second-unit-diagnostic'
printf 'multiple-missing-units-check=pass\n'

printf 'unit-cycle-check=running\n'
printf 'unit-cycle-command=%s build tests/compiler/fail/unit_cycle_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$UNIT_CYCLE_OUTPUT" tests/compiler/fail/unit_cycle_fail.pas; then
  cat "$UNIT_CYCLE_OUTPUT"
  fail 'expected-unit-cycle-failure-did-not-fail'
fi
cat "$UNIT_CYCLE_OUTPUT"
require_output_pattern '^failure-kind=unit-resolution-failed$' "$UNIT_CYCLE_OUTPUT" 'missing-unit-cycle-failure-kind'
require_output_pattern '^diagnostic-code=resolver.unit-cycle-detected$' "$UNIT_CYCLE_OUTPUT" 'missing-unit-cycle-diagnostic-code'
require_output_pattern '^diagnostic-phase=resolution$' "$UNIT_CYCLE_OUTPUT" 'missing-unit-cycle-diagnostic-phase'
require_output_pattern '"code":"resolver.unit-cycle-detected"' "$UNIT_CYCLE_OUTPUT" 'missing-unit-cycle-diagnostic-envelope'
printf 'unit-cycle-check=pass\n'

printf 'duplicate-import-check=running\n'
printf 'duplicate-import-command=%s build tests/compiler/fail/duplicate_unit_import_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$DUPLICATE_IMPORT_OUTPUT" tests/compiler/fail/duplicate_unit_import_fail.pas; then
  cat "$DUPLICATE_IMPORT_OUTPUT"
  fail 'expected-duplicate-import-failure-did-not-fail'
fi
cat "$DUPLICATE_IMPORT_OUTPUT"
require_output_pattern '^failure-kind=semantic-analysis-failed$' "$DUPLICATE_IMPORT_OUTPUT" 'missing-duplicate-import-failure-kind'
require_output_pattern '^diagnostics-summary=sema\.duplicate-declaration$' "$DUPLICATE_IMPORT_OUTPUT" 'missing-duplicate-import-diagnostics-summary'
require_output_pattern '^diagnostic-code=sema.duplicate-declaration$' "$DUPLICATE_IMPORT_OUTPUT" 'missing-duplicate-import-diagnostic-code'
require_output_pattern '^diagnostic-phase=sema$' "$DUPLICATE_IMPORT_OUTPUT" 'missing-duplicate-import-diagnostic-phase'
require_output_pattern '"code":"sema.duplicate-declaration"' "$DUPLICATE_IMPORT_OUTPUT" 'missing-duplicate-import-diagnostic-envelope'
require_output_pattern '^human-summary=semantic-analysis-failed$' "$DUPLICATE_IMPORT_OUTPUT" 'missing-duplicate-import-human-summary'
require_output_pattern '"diagnosticsSummary":"sema.duplicate-declaration"' "$DUPLICATE_IMPORT_OUTPUT" 'missing-duplicate-import-diagnostics-summary-envelope-field'
require_output_pattern '"humanSummary":"semantic-analysis-failed"' "$DUPLICATE_IMPORT_OUTPUT" 'missing-duplicate-import-human-summary-envelope-field'
printf 'duplicate-import-check=pass\n'

printf 'missing-external-symbol-name-check=running\n'
printf 'missing-external-symbol-name-command=%s build tests/compiler/fail/missing_external_symbol_name_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" tests/compiler/fail/missing_external_symbol_name_fail.pas; then
  cat "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT"
  fail 'expected-missing-external-symbol-name-failure-did-not-fail'
fi
cat "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT"
require_output_pattern '^failure-kind=semantic-analysis-failed$' "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" 'missing-external-symbol-name-failure-kind'
require_output_pattern '^diagnostics-summary=sema\.missing-external-symbol-name$' "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" 'missing-external-symbol-name-diagnostics-summary'
require_output_pattern '^diagnostic-code=sema.missing-external-symbol-name$' "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" 'missing-external-symbol-name-diagnostic-code'
require_output_pattern '^diagnostic-phase=sema$' "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" 'missing-external-symbol-name-diagnostic-phase'
require_output_pattern '"code":"sema.missing-external-symbol-name"' "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" 'missing-external-symbol-name-diagnostic-envelope'
require_output_pattern '^human-summary=semantic-analysis-failed$' "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" 'missing-external-symbol-name-human-summary'
require_output_pattern '"diagnosticsSummary":"sema.missing-external-symbol-name"' "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" 'missing-external-symbol-name-diagnostics-summary-envelope-field'
require_output_pattern '"humanSummary":"semantic-analysis-failed"' "$MISSING_EXTERNAL_SYMBOL_NAME_OUTPUT" 'missing-external-symbol-name-human-summary-envelope-field'
printf 'missing-external-symbol-name-check=pass\n'

printf 'root-implementation-check=running\n'
printf 'root-implementation-command=%s build tests/compiler/fail/root_implementation_missing_unit_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$ROOT_IMPLEMENTATION_OUTPUT" tests/compiler/fail/root_implementation_missing_unit_fail.pas; then
  cat "$ROOT_IMPLEMENTATION_OUTPUT"
  fail 'expected-root-implementation-use-failure-did-not-fail'
fi
cat "$ROOT_IMPLEMENTATION_OUTPUT"
require_output_pattern '^failure-kind=unit-resolution-failed$' "$ROOT_IMPLEMENTATION_OUTPUT" 'missing-root-implementation-failure-kind'
require_output_pattern '^diagnostic-code=resolver.unit-not-found$' "$ROOT_IMPLEMENTATION_OUTPUT" 'missing-root-implementation-diagnostic-code'
require_output_pattern '^diagnostic-phase=resolution$' "$ROOT_IMPLEMENTATION_OUTPUT" 'missing-root-implementation-diagnostic-phase'
require_output_pattern '"code":"resolver.unit-not-found"' "$ROOT_IMPLEMENTATION_OUTPUT" 'missing-root-implementation-diagnostic-envelope'
printf 'root-implementation-check=pass\n'

printf 'requested-name-mismatch-check=running\n'
printf 'requested-name-mismatch-command=%s build tests/compiler/fail/requested_name_mismatch_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$REQUESTED_NAME_MISMATCH_OUTPUT" tests/compiler/fail/requested_name_mismatch_fail.pas; then
  cat "$REQUESTED_NAME_MISMATCH_OUTPUT"
  fail 'expected-requested-name-mismatch-failure-did-not-fail'
fi
cat "$REQUESTED_NAME_MISMATCH_OUTPUT"
require_output_pattern '^failure-kind=unit-resolution-failed$' "$REQUESTED_NAME_MISMATCH_OUTPUT" 'missing-requested-name-mismatch-failure-kind'
require_output_pattern '^diagnostic-code=resolver.unit-name-mismatch$' "$REQUESTED_NAME_MISMATCH_OUTPUT" 'missing-requested-name-mismatch-diagnostic-code'
require_output_pattern '^diagnostic-phase=resolution$' "$REQUESTED_NAME_MISMATCH_OUTPUT" 'missing-requested-name-mismatch-diagnostic-phase'
require_output_pattern '"code":"resolver.unit-name-mismatch"' "$REQUESTED_NAME_MISMATCH_OUTPUT" 'missing-requested-name-mismatch-diagnostic-envelope'
printf 'requested-name-mismatch-check=pass\n'

printf 'explicit-system-check=running\n'
printf 'explicit-system-command=%s build tests/compiler/fail/explicit_system_missing_unit_fail.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$EXPLICIT_SYSTEM_OUTPUT" tests/compiler/fail/explicit_system_missing_unit_fail.pas; then
  cat "$EXPLICIT_SYSTEM_OUTPUT"
  fail 'expected-explicit-system-resolution-failure-did-not-fail'
fi
cat "$EXPLICIT_SYSTEM_OUTPUT"
require_output_pattern '^failure-kind=unit-resolution-failed$' "$EXPLICIT_SYSTEM_OUTPUT" 'missing-explicit-system-failure-kind'
require_output_pattern '^diagnostic-code=resolver.unit-not-found$' "$EXPLICIT_SYSTEM_OUTPUT" 'missing-explicit-system-diagnostic-code'
require_output_pattern '^diagnostic-phase=resolution$' "$EXPLICIT_SYSTEM_OUTPUT" 'missing-explicit-system-diagnostic-phase'
require_output_pattern '"code":"resolver.unit-not-found"' "$EXPLICIT_SYSTEM_OUTPUT" 'missing-explicit-system-diagnostic-envelope'
printf 'explicit-system-check=pass\n'

printf 'explicit-unit-root-check=running\n'
printf 'explicit-unit-root-command=%s build tests/fixtures/explicit_unit_root_smoke.pas --target linux-x86_64 --workspace %s --unit-root tests/fixtures/unit_roots\n' "$STAGE0_BINARY" "$REPO_ROOT"
if ! run_stage0_build_capture "$EXPLICIT_UNIT_ROOT_OUTPUT" tests/fixtures/explicit_unit_root_smoke.pas --unit-root tests/fixtures/unit_roots; then
  cat "$EXPLICIT_UNIT_ROOT_OUTPUT"
  fail 'explicit-unit-root-check-failed'
fi
cat "$EXPLICIT_UNIT_ROOT_OUTPUT"
require_output_pattern '^search-path-count=3$' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-search-path-count'
require_output_pattern '^search-index-status=partial$' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-search-index-status'
require_output_pattern '^indexed-search-root-count=2$' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-indexed-search-root-count'
require_output_pattern '^search-index-scan-count=2$' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-search-index-scan-count'
require_output_pattern '^artifact=.*/\.nextpas/out/linux-x86_64/explicit_unit_root_smoke$' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-artifact-path'
require_output_pattern '^output-dir=.*/\.nextpas/out/linux-x86_64$' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-output-dir'
require_output_pattern '^backend-primary-artifact-path=.*/\.nextpas/out/linux-x86_64/explicit_unit_root_smoke$' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-backend-artifact-path'
require_output_pattern '^tool-invocation-plan=.*"-FE.*/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/tests/fixtures".*"-Fu.*/tests/fixtures/unit_roots".*"-Fu.*/units/linux-x86_64".*".*/tests/fixtures/explicit_unit_root_smoke\.pas"' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-argv'
require_output_pattern '^command-envelope=.*"workspaceRoot":".*/nextPas".*"workspaceDiscoveryKind":"explicit-workspace-override".*"artifactRoot":".*/nextPas/\.nextpas".*"outputDir":".*/nextPas/\.nextpas/out/linux-x86_64".*"artifact":".*/nextPas/\.nextpas/out/linux-x86_64/explicit_unit_root_smoke".*"searchPathCount":3' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-envelope'
require_output_pattern '^command-envelope=.*"searchIndexStatus":"partial".*"indexedSearchRootCount":2.*"searchIndexScanCount":2' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-envelope-search-index'
require_output_pattern '^command-envelope=.*"searchPaths":\[\{"scopeName":"root-source".*"rootPath":".*/tests/fixtures"\},\{"scopeName":"explicit-unit-root".*"provenanceKind":"explicit-unit-root".*"rootPath":".*/tests/fixtures/unit_roots"\},\{"scopeName":"target-installed".*"rootPath":".*/units/linux-x86_64"\}\]' "$EXPLICIT_UNIT_ROOT_OUTPUT" 'missing-explicit-unit-root-envelope-search-paths'
if grep -Eq '^workspace-descriptor-path=' "$EXPLICIT_UNIT_ROOT_OUTPUT"; then
  fail 'unexpected-explicit-unit-root-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$EXPLICIT_UNIT_ROOT_OUTPUT"; then
  fail 'unexpected-explicit-unit-root-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$EXPLICIT_UNIT_ROOT_OUTPUT"; then
  fail 'unexpected-explicit-unit-root-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$EXPLICIT_UNIT_ROOT_OUTPUT"; then
  fail 'unexpected-explicit-unit-root-package-manifest-envelope-field'
fi
if ! "$WORKSPACE_ARTIFACT_ROOT/out/$TARGET_ID/explicit_unit_root_smoke" >"$EXPLICIT_UNIT_ROOT_RUN_OUTPUT" 2>&1; then
  cat "$EXPLICIT_UNIT_ROOT_RUN_OUTPUT"
  fail 'explicit-unit-root-run-failed'
fi
cat "$EXPLICIT_UNIT_ROOT_RUN_OUTPUT"
require_output_pattern '^hello from explicit unit root$' "$EXPLICIT_UNIT_ROOT_RUN_OUTPUT" 'missing-explicit-unit-root-run-output'
require_absent_path "$REPO_ROOT/tests/fixtures/explicit_unit_root_smoke"
require_absent_path "$REPO_ROOT/tests/fixtures/unit_roots/UnitRootGreeter.ppu"
printf 'explicit-unit-root-check=pass\n'

printf 'package-manifest-source-root-check=running\n'
printf 'package-manifest-source-root-command=%s build tests/fixtures/package_manifest_source_root/app/package_manifest_source_root_smoke.pas --target linux-x86_64\n' "$STAGE0_BINARY"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" build tests/fixtures/package_manifest_source_root/app/package_manifest_source_root_smoke.pas --target "$TARGET_ID" >"$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 2>&1; then
  cat "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT"
  fail 'package-manifest-source-root-check-failed'
fi
cat "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT"
require_output_pattern '^search-path-count=3$' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-search-path-count'
require_output_pattern '^search-path-json=.*"scopeName":"root-source".*"rootPath":".*/tests/fixtures/package_manifest_source_root/app".*"scopeName":"package-source-root".*"provenanceKind":"nearest-package-manifest-source-root".*"packageName":"tests\.package-manifest-source-root".*"manifestPath":".*/tests/fixtures/package_manifest_source_root/nextpas\.package\.toml".*"rootPath":".*/tests/fixtures/package_manifest_source_root/src".*"scopeName":"target-installed"' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-search-path-json'
require_output_pattern '^workspace-root=.*/tests/fixtures/package_manifest_source_root$' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-workspace-root'
require_output_pattern '^workspace-discovery-kind=nearest-package-manifest$' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-workspace-discovery-kind'
require_output_pattern '^package-manifest-path=.*/tests/fixtures/package_manifest_source_root/nextpas\.package\.toml$' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-package-manifest-path'
require_output_pattern '^artifact-root=.*/tests/fixtures/package_manifest_source_root/\.nextpas$' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-artifact-root'
require_output_pattern '^output-dir=.*/tests/fixtures/package_manifest_source_root/\.nextpas/out/linux-x86_64$' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-output-dir'
require_output_pattern '^artifact=.*/tests/fixtures/package_manifest_source_root/\.nextpas/out/linux-x86_64/package_manifest_source_root_smoke$' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-artifact-path'
require_output_pattern '^backend-primary-artifact-path=.*/tests/fixtures/package_manifest_source_root/\.nextpas/out/linux-x86_64/package_manifest_source_root_smoke$' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-backend-artifact-path'
require_output_pattern '^tool-invocation-plan=.*"-FE.*/tests/fixtures/package_manifest_source_root/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/tests/fixtures/package_manifest_source_root/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/tests/fixtures/package_manifest_source_root/app".*"-Fu.*/tests/fixtures/package_manifest_source_root/src".*"-Fu.*/units/linux-x86_64".*".*/tests/fixtures/package_manifest_source_root/app/package_manifest_source_root_smoke\.pas"' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-argv'
require_output_pattern '^command-envelope=.*"workspaceRoot":".*/tests/fixtures/package_manifest_source_root".*"workspaceDiscoveryKind":"nearest-package-manifest".*"packageManifestPath":".*/tests/fixtures/package_manifest_source_root/nextpas\.package\.toml".*"artifactRoot":".*/tests/fixtures/package_manifest_source_root/\.nextpas".*"outputDir":".*/tests/fixtures/package_manifest_source_root/\.nextpas/out/linux-x86_64"' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT" 'missing-package-manifest-source-root-envelope'
if grep -Eq '^workspace-descriptor-path=' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT"; then
  fail 'unexpected-package-manifest-source-root-workspace-descriptor-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$PACKAGE_MANIFEST_SOURCE_ROOT_OUTPUT"; then
  fail 'unexpected-package-manifest-source-root-workspace-descriptor-envelope-field'
fi
if ! "$PACKAGE_MANIFEST_ARTIFACT_ROOT/out/$TARGET_ID/package_manifest_source_root_smoke" >"$PACKAGE_MANIFEST_SOURCE_ROOT_RUN_OUTPUT" 2>&1; then
  cat "$PACKAGE_MANIFEST_SOURCE_ROOT_RUN_OUTPUT"
  fail 'package-manifest-source-root-run-failed'
fi
cat "$PACKAGE_MANIFEST_SOURCE_ROOT_RUN_OUTPUT"
require_output_pattern '^hello from package manifest source root$' "$PACKAGE_MANIFEST_SOURCE_ROOT_RUN_OUTPUT" 'missing-package-manifest-source-root-run-output'
require_absent_path "$REPO_ROOT/tests/fixtures/package_manifest_source_root/app/package_manifest_source_root_smoke"
printf 'package-manifest-source-root-check=pass\n'

printf 'workspace-member-source-root-check=running\n'
printf 'workspace-member-source-root-command=%s build tests/fixtures/workspace_member_source_root/app/app/workspace_member_source_root_smoke.pas --target linux-x86_64\n' "$STAGE0_BINARY"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" build tests/fixtures/workspace_member_source_root/app/app/workspace_member_source_root_smoke.pas --target "$TARGET_ID" >"$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 2>&1; then
  cat "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT"
  fail 'workspace-member-source-root-check-failed'
fi
cat "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT"
require_output_pattern '^search-path-count=3$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-search-path-count'
require_output_pattern '^search-path-json=.*"scopeName":"root-source".*"rootPath":".*/tests/fixtures/workspace_member_source_root/app/app".*"scopeName":"package-source-root".*"provenanceKind":"workspace-member-package-source-root".*"packageName":"tests\.workspace-member-source-root\.shared".*"manifestPath":".*/tests/fixtures/workspace_member_source_root/shared/nextpas\.package\.toml".*"workspaceMemberPath":".*/tests/fixtures/workspace_member_source_root/shared".*"rootPath":".*/tests/fixtures/workspace_member_source_root/shared/src".*"scopeName":"target-installed"' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-search-path-json'
require_output_pattern '^workspace-root=.*/tests/fixtures/workspace_member_source_root$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-workspace-root'
require_output_pattern '^workspace-discovery-kind=nearest-workspace-descriptor$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-workspace-discovery-kind'
require_output_pattern '^workspace-descriptor-path=.*/tests/fixtures/workspace_member_source_root/nextpas\.workspace\.toml$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-workspace-descriptor-path'
require_output_pattern '^package-manifest-path=.*/tests/fixtures/workspace_member_source_root/app/nextpas\.package\.toml$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-package-manifest-path'
require_output_pattern '^artifact-root=.*/tests/fixtures/workspace_member_source_root/\.nextpas$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-artifact-root'
require_output_pattern '^output-dir=.*/tests/fixtures/workspace_member_source_root/\.nextpas/out/linux-x86_64$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-output-dir'
require_output_pattern '^artifact=.*/tests/fixtures/workspace_member_source_root/\.nextpas/out/linux-x86_64/workspace_member_source_root_smoke$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-artifact-path'
require_output_pattern '^backend-primary-artifact-path=.*/tests/fixtures/workspace_member_source_root/\.nextpas/out/linux-x86_64/workspace_member_source_root_smoke$' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-backend-artifact-path'
require_output_pattern '^tool-invocation-plan=.*"-FE.*/tests/fixtures/workspace_member_source_root/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/tests/fixtures/workspace_member_source_root/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/tests/fixtures/workspace_member_source_root/app/app".*"-Fu.*/tests/fixtures/workspace_member_source_root/shared/src".*"-Fu.*/units/linux-x86_64".*".*/tests/fixtures/workspace_member_source_root/app/app/workspace_member_source_root_smoke\.pas"' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-argv'
require_output_pattern '^command-envelope=.*"workspaceRoot":".*/tests/fixtures/workspace_member_source_root".*"workspaceDiscoveryKind":"nearest-workspace-descriptor".*"workspaceDescriptorPath":".*/tests/fixtures/workspace_member_source_root/nextpas\.workspace\.toml".*"packageManifestPath":".*/tests/fixtures/workspace_member_source_root/app/nextpas\.package\.toml".*"artifactRoot":".*/tests/fixtures/workspace_member_source_root/\.nextpas".*"outputDir":".*/tests/fixtures/workspace_member_source_root/\.nextpas/out/linux-x86_64"' "$WORKSPACE_MEMBER_SOURCE_ROOT_OUTPUT" 'missing-workspace-member-source-root-envelope'
if ! "$WORKSPACE_MEMBER_ARTIFACT_ROOT/out/$TARGET_ID/workspace_member_source_root_smoke" >"$WORKSPACE_MEMBER_SOURCE_ROOT_RUN_OUTPUT" 2>&1; then
  cat "$WORKSPACE_MEMBER_SOURCE_ROOT_RUN_OUTPUT"
  fail 'workspace-member-source-root-run-failed'
fi
cat "$WORKSPACE_MEMBER_SOURCE_ROOT_RUN_OUTPUT"
require_output_pattern '^hello from workspace member source root$' "$WORKSPACE_MEMBER_SOURCE_ROOT_RUN_OUTPUT" 'missing-workspace-member-source-root-run-output'
require_absent_path "$REPO_ROOT/tests/fixtures/workspace_member_source_root/app/app/workspace_member_source_root_smoke"
printf 'workspace-member-source-root-check=pass\n'

printf 'source-directory-fallback-check=running\n'
cp examples/smoke/hello.pas "$SOURCE_DIRECTORY_FALLBACK_WORKSPACE/hello.pas"
printf 'source-directory-fallback-command=%s build %s/hello.pas --target linux-x86_64\n' "$STAGE0_BINARY" "$SOURCE_DIRECTORY_FALLBACK_WORKSPACE"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" build "$SOURCE_DIRECTORY_FALLBACK_WORKSPACE/hello.pas" --target "$TARGET_ID" >"$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 2>&1; then
  cat "$SOURCE_DIRECTORY_FALLBACK_OUTPUT"
  fail 'source-directory-fallback-check-failed'
fi
cat "$SOURCE_DIRECTORY_FALLBACK_OUTPUT"
require_output_pattern '^search-path-count=2$' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-search-path-count'
require_output_pattern '^search-path-json=.*"scopeName":"root-source".*"rootPath":"/tmp/.*".*"scopeName":"target-installed".*"rootPath":".*/units/linux-x86_64"' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-search-path-json'
require_output_pattern '^workspace-root=/tmp/.+$' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-workspace-root'
require_output_pattern '^workspace-discovery-kind=source-directory-fallback$' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-workspace-discovery-kind'
require_output_pattern '^artifact-root=/tmp/.*/\.nextpas$' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-artifact-root'
require_output_pattern '^output-dir=/tmp/.*/\.nextpas/out/linux-x86_64$' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-output-dir'
require_output_pattern '^artifact=/tmp/.*/\.nextpas/out/linux-x86_64/hello$' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-artifact-path'
require_output_pattern '^backend-primary-artifact-path=/tmp/.*/\.nextpas/out/linux-x86_64/hello$' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-backend-artifact-path'
require_output_pattern '^tool-invocation-plan=.*"-FE/tmp/.*/\.nextpas/cache/backend/linux-x86_64".*"-FU/tmp/.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu/tmp/.*".*"-Fu.*/units/linux-x86_64".*"/tmp/.*/hello\.pas"' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-argv'
require_output_pattern '^command-envelope=.*"workspaceRoot":"/tmp/.+".*"workspaceDiscoveryKind":"source-directory-fallback".*"artifactRoot":"/tmp/.*/\.nextpas".*"outputDir":"/tmp/.*/\.nextpas/out/linux-x86_64"' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT" 'missing-source-directory-fallback-envelope'
if grep -Eq '^workspace-descriptor-path=' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT"; then
  fail 'unexpected-source-directory-fallback-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT"; then
  fail 'unexpected-source-directory-fallback-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT"; then
  fail 'unexpected-source-directory-fallback-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$SOURCE_DIRECTORY_FALLBACK_OUTPUT"; then
  fail 'unexpected-source-directory-fallback-package-manifest-envelope-field'
fi
if ! "$SOURCE_DIRECTORY_FALLBACK_WORKSPACE/.nextpas/out/$TARGET_ID/hello" >"$SOURCE_DIRECTORY_FALLBACK_RUN_OUTPUT" 2>&1; then
  cat "$SOURCE_DIRECTORY_FALLBACK_RUN_OUTPUT"
  fail 'source-directory-fallback-run-failed'
fi
cat "$SOURCE_DIRECTORY_FALLBACK_RUN_OUTPUT"
require_output_pattern '^hello from nextpas stage0 smoke$' "$SOURCE_DIRECTORY_FALLBACK_RUN_OUTPUT" 'missing-source-directory-fallback-run-output'
require_absent_path "$SOURCE_DIRECTORY_FALLBACK_WORKSPACE/hello"
printf 'source-directory-fallback-check=pass\n'

printf 'package-manifest-source-precedence-check=running\n'
printf 'package-manifest-source-precedence-command=%s build tests/fixtures/package_manifest_source_precedence/app/package_manifest_source_precedence_smoke.pas --target linux-x86_64 --workspace %s --unit-root tests/fixtures/package_manifest_source_precedence/explicit\n' "$STAGE0_BINARY" "$REPO_ROOT"
if ! run_stage0_build_capture "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" tests/fixtures/package_manifest_source_precedence/app/package_manifest_source_precedence_smoke.pas --unit-root tests/fixtures/package_manifest_source_precedence/explicit; then
  cat "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT"
  fail 'package-manifest-source-precedence-check-failed'
fi
cat "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT"
require_output_pattern '^search-path-count=4$' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-search-path-count'
require_output_pattern '^search-index-status=partial$' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-search-index-status'
require_output_pattern '^indexed-search-root-count=2$' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-indexed-search-root-count'
require_output_pattern '^search-index-scan-count=2$' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-search-index-scan-count'
require_output_pattern '^package-manifest-path=.*/tests/fixtures/package_manifest_source_precedence/nextpas\.package\.toml$' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-package-manifest-path'
require_output_pattern '^output-dir=.*/\.nextpas/out/linux-x86_64$' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-output-dir'
require_output_pattern '^artifact=.*/\.nextpas/out/linux-x86_64/package_manifest_source_precedence_smoke$' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-artifact-path'
require_output_pattern '^tool-invocation-plan=.*"-FE.*/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/tests/fixtures/package_manifest_source_precedence/app".*"-Fu.*/tests/fixtures/package_manifest_source_precedence/src".*"-Fu.*/tests/fixtures/package_manifest_source_precedence/explicit".*"-Fu.*/units/linux-x86_64".*".*/tests/fixtures/package_manifest_source_precedence/app/package_manifest_source_precedence_smoke\.pas"' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-argv'
require_output_pattern '^command-envelope=.*"workspaceRoot":".*/nextPas".*"workspaceDiscoveryKind":"explicit-workspace-override".*"packageManifestPath":".*/tests/fixtures/package_manifest_source_precedence/nextpas\.package\.toml".*"artifactRoot":".*/nextPas/\.nextpas".*"outputDir":".*/nextPas/\.nextpas/out/linux-x86_64".*"artifact":".*/nextPas/\.nextpas/out/linux-x86_64/package_manifest_source_precedence_smoke".*"searchPathCount":4' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-envelope'
require_output_pattern '^command-envelope=.*"searchIndexStatus":"partial".*"indexedSearchRootCount":2.*"searchIndexScanCount":2' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-envelope-search-index'
require_output_pattern '^command-envelope=.*"searchPaths":\[\{"scopeName":"root-source".*"rootPath":".*/tests/fixtures/package_manifest_source_precedence/app"\},\{"scopeName":"package-source-root".*"provenanceKind":"nearest-package-manifest-source-root".*"packageName":"tests\.package-manifest-source-precedence".*"manifestPath":".*/tests/fixtures/package_manifest_source_precedence/nextpas\.package\.toml".*"rootPath":".*/tests/fixtures/package_manifest_source_precedence/src"\},\{"scopeName":"explicit-unit-root".*"rootPath":".*/tests/fixtures/package_manifest_source_precedence/explicit"\},\{"scopeName":"target-installed".*"rootPath":".*/units/linux-x86_64"\}\]' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT" 'missing-package-manifest-source-precedence-envelope-search-paths'
if grep -Eq '^workspace-descriptor-path=' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-package-manifest-source-precedence-workspace-descriptor-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-package-manifest-source-precedence-workspace-descriptor-envelope-field'
fi
if ! "$WORKSPACE_ARTIFACT_ROOT/out/$TARGET_ID/package_manifest_source_precedence_smoke" >"$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_RUN_OUTPUT" 2>&1; then
  cat "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_RUN_OUTPUT"
  fail 'package-manifest-source-precedence-run-failed'
fi
cat "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_RUN_OUTPUT"
require_output_pattern '^hello from package source root precedence$' "$PACKAGE_MANIFEST_SOURCE_PRECEDENCE_RUN_OUTPUT" 'missing-package-manifest-source-precedence-run-output'
require_absent_path "$REPO_ROOT/tests/fixtures/package_manifest_source_precedence/app/package_manifest_source_precedence_smoke"
printf 'package-manifest-source-precedence-check=pass\n'

printf 'out-dir-override-check=running\n'
printf 'out-dir-override-command=%s build examples/smoke/hello.pas --target linux-x86_64 --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$REPO_ROOT" "$OUT_DIR_OVERRIDE_DIR"
if ! run_stage0_build_capture "$OUT_DIR_OVERRIDE_OUTPUT" examples/smoke/hello.pas --out-dir "$OUT_DIR_OVERRIDE_DIR"; then
  cat "$OUT_DIR_OVERRIDE_OUTPUT"
  fail 'out-dir-override-check-failed'
fi
cat "$OUT_DIR_OVERRIDE_OUTPUT"
require_output_pattern '^artifact='"$OUT_DIR_OVERRIDE_DIR"'/hello$' "$OUT_DIR_OVERRIDE_OUTPUT" 'missing-out-dir-override-artifact-path'
require_output_pattern '^output-dir='"$OUT_DIR_OVERRIDE_DIR"'$' "$OUT_DIR_OVERRIDE_OUTPUT" 'missing-out-dir-override-output-dir'
require_output_pattern '^backend-primary-artifact-path='"$OUT_DIR_OVERRIDE_DIR"'/hello$' "$OUT_DIR_OVERRIDE_OUTPUT" 'missing-out-dir-override-backend-artifact-path'
require_output_pattern '^tool-invocation-plan=.*"-FE.*/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/examples/smoke".*"-Fu.*/units/linux-x86_64".*".*/examples/smoke/hello\.pas"' "$OUT_DIR_OVERRIDE_OUTPUT" 'missing-out-dir-override-argv'
require_output_pattern '^command-envelope=.*"workspaceRoot":".*/nextPas".*"workspaceDiscoveryKind":"explicit-workspace-override".*"artifactRoot":".*/nextPas/\.nextpas".*"outputDir":"'"$OUT_DIR_OVERRIDE_DIR"'".*"artifact":"'"$OUT_DIR_OVERRIDE_DIR"'/hello".*"searchPathCount":2' "$OUT_DIR_OVERRIDE_OUTPUT" 'missing-out-dir-override-envelope'
require_output_pattern '^command-envelope=.*"searchPaths":\[\{"scopeName":"root-source".*"rootPath":".*/examples/smoke"\},\{"scopeName":"target-installed".*"rootPath":".*/units/linux-x86_64"\}\]' "$OUT_DIR_OVERRIDE_OUTPUT" 'missing-out-dir-override-envelope-search-paths'
if grep -Eq '^workspace-descriptor-path=' "$OUT_DIR_OVERRIDE_OUTPUT"; then
  fail 'unexpected-out-dir-override-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$OUT_DIR_OVERRIDE_OUTPUT"; then
  fail 'unexpected-out-dir-override-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$OUT_DIR_OVERRIDE_OUTPUT"; then
  fail 'unexpected-out-dir-override-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$OUT_DIR_OVERRIDE_OUTPUT"; then
  fail 'unexpected-out-dir-override-package-manifest-envelope-field'
fi
if ! "$OUT_DIR_OVERRIDE_DIR/hello" >"$OUT_DIR_OVERRIDE_RUN_OUTPUT" 2>&1; then
  cat "$OUT_DIR_OVERRIDE_RUN_OUTPUT"
  fail 'out-dir-override-run-failed'
fi
cat "$OUT_DIR_OVERRIDE_RUN_OUTPUT"
require_output_pattern '^hello from nextpas stage0 smoke$' "$OUT_DIR_OVERRIDE_RUN_OUTPUT" 'missing-out-dir-override-run-output'
printf 'out-dir-override-check=pass\n'

printf 'root-source-precedence-check=running\n'
printf 'root-source-precedence-command=%s build tests/fixtures/root_source_precedence/root_source_precedence_smoke.pas --target linux-x86_64 --workspace %s --unit-root tests/fixtures/root_source_precedence/explicit --out-dir %s\n' "$STAGE0_BINARY" "$REPO_ROOT" "$ROOT_SOURCE_PRECEDENCE_DIR"
if ! run_stage0_build_capture "$ROOT_SOURCE_PRECEDENCE_OUTPUT" tests/fixtures/root_source_precedence/root_source_precedence_smoke.pas --unit-root tests/fixtures/root_source_precedence/explicit --out-dir "$ROOT_SOURCE_PRECEDENCE_DIR"; then
  cat "$ROOT_SOURCE_PRECEDENCE_OUTPUT"
  fail 'root-source-precedence-check-failed'
fi
cat "$ROOT_SOURCE_PRECEDENCE_OUTPUT"
require_output_pattern '^search-path-count=3$' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-search-path-count'
require_output_pattern '^search-index-status=partial$' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-search-index-status'
require_output_pattern '^indexed-search-root-count=1$' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-indexed-search-root-count'
require_output_pattern '^search-index-scan-count=1$' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-search-index-scan-count'
require_output_pattern '^artifact='"$ROOT_SOURCE_PRECEDENCE_DIR"'/root_source_precedence_smoke$' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-artifact-path'
require_output_pattern '^output-dir='"$ROOT_SOURCE_PRECEDENCE_DIR"'$' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-output-dir'
require_output_pattern '^tool-invocation-plan=.*"-FE.*/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/tests/fixtures/root_source_precedence".*"-Fu.*/tests/fixtures/root_source_precedence/explicit".*"-Fu.*/units/linux-x86_64".*".*/tests/fixtures/root_source_precedence/root_source_precedence_smoke\.pas"' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-argv'
require_output_pattern '^command-envelope=.*"workspaceRoot":".*/nextPas".*"workspaceDiscoveryKind":"explicit-workspace-override".*"artifactRoot":".*/nextPas/\.nextpas".*"outputDir":"'"$ROOT_SOURCE_PRECEDENCE_DIR"'".*"artifact":"'"$ROOT_SOURCE_PRECEDENCE_DIR"'/root_source_precedence_smoke".*"searchPathCount":3' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-envelope'
require_output_pattern '^command-envelope=.*"searchIndexStatus":"partial".*"indexedSearchRootCount":1.*"searchIndexScanCount":1' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-envelope-search-index'
require_output_pattern '^command-envelope=.*"searchPaths":\[\{"scopeName":"root-source".*"rootPath":".*/tests/fixtures/root_source_precedence"\},\{"scopeName":"explicit-unit-root".*"provenanceKind":"explicit-unit-root".*"rootPath":".*/tests/fixtures/root_source_precedence/explicit"\},\{"scopeName":"target-installed".*"rootPath":".*/units/linux-x86_64"\}\]' "$ROOT_SOURCE_PRECEDENCE_OUTPUT" 'missing-root-source-precedence-envelope-search-paths'
if grep -Eq '^workspace-descriptor-path=' "$ROOT_SOURCE_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-root-source-precedence-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$ROOT_SOURCE_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-root-source-precedence-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$ROOT_SOURCE_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-root-source-precedence-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$ROOT_SOURCE_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-root-source-precedence-package-manifest-envelope-field'
fi
if ! "$ROOT_SOURCE_PRECEDENCE_DIR/root_source_precedence_smoke" >"$ROOT_SOURCE_PRECEDENCE_RUN_OUTPUT" 2>&1; then
  cat "$ROOT_SOURCE_PRECEDENCE_RUN_OUTPUT"
  fail 'root-source-precedence-run-failed'
fi
cat "$ROOT_SOURCE_PRECEDENCE_RUN_OUTPUT"
require_output_pattern '^hello from root source$' "$ROOT_SOURCE_PRECEDENCE_RUN_OUTPUT" 'missing-root-source-precedence-run-output'
require_absent_path "$REPO_ROOT/tests/fixtures/root_source_precedence/root_source_precedence_smoke"
printf 'root-source-precedence-check=pass\n'

printf 'unit-root-precedence-check=running\n'
printf 'unit-root-precedence-command=%s build tests/fixtures/unit_root_precedence/unit_root_precedence_smoke.pas --target linux-x86_64 --workspace %s --unit-root tests/fixtures/unit_root_precedence/explicit --out-dir %s\n' "$STAGE0_BINARY" "$REPO_ROOT" "$UNIT_ROOT_PRECEDENCE_DIR"
if ! run_stage0_build_capture "$UNIT_ROOT_PRECEDENCE_OUTPUT" tests/fixtures/unit_root_precedence/unit_root_precedence_smoke.pas --unit-root tests/fixtures/unit_root_precedence/explicit --out-dir "$UNIT_ROOT_PRECEDENCE_DIR"; then
  cat "$UNIT_ROOT_PRECEDENCE_OUTPUT"
  fail 'unit-root-precedence-check-failed'
fi
cat "$UNIT_ROOT_PRECEDENCE_OUTPUT"
require_output_pattern '^search-path-count=3$' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-search-path-count'
require_output_pattern '^search-index-status=partial$' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-search-index-status'
require_output_pattern '^indexed-search-root-count=2$' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-indexed-search-root-count'
require_output_pattern '^search-index-scan-count=2$' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-search-index-scan-count'
require_output_pattern '^artifact='"$UNIT_ROOT_PRECEDENCE_DIR"'/unit_root_precedence_smoke$' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-artifact-path'
require_output_pattern '^output-dir='"$UNIT_ROOT_PRECEDENCE_DIR"'$' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-output-dir'
require_output_pattern '^tool-invocation-plan=.*"-FE.*/\.nextpas/cache/backend/linux-x86_64".*"-FU.*/\.nextpas/cache/backend/linux-x86_64".*"-Fu.*/tests/fixtures/unit_root_precedence".*"-Fu.*/tests/fixtures/unit_root_precedence/explicit".*"-Fu.*/units/linux-x86_64".*".*/tests/fixtures/unit_root_precedence/unit_root_precedence_smoke\.pas"' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-argv'
require_output_pattern '^command-envelope=.*"workspaceRoot":".*/nextPas".*"workspaceDiscoveryKind":"explicit-workspace-override".*"artifactRoot":".*/nextPas/\.nextpas".*"outputDir":"'"$UNIT_ROOT_PRECEDENCE_DIR"'".*"artifact":"'"$UNIT_ROOT_PRECEDENCE_DIR"'/unit_root_precedence_smoke".*"searchPathCount":3' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-envelope'
require_output_pattern '^command-envelope=.*"searchIndexStatus":"partial".*"indexedSearchRootCount":2.*"searchIndexScanCount":2' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-envelope-search-index'
require_output_pattern '^command-envelope=.*"searchPaths":\[\{"scopeName":"root-source".*"rootPath":".*/tests/fixtures/unit_root_precedence"\},\{"scopeName":"explicit-unit-root".*"provenanceKind":"explicit-unit-root".*"rootPath":".*/tests/fixtures/unit_root_precedence/explicit"\},\{"scopeName":"target-installed".*"rootPath":".*/units/linux-x86_64"\}\]' "$UNIT_ROOT_PRECEDENCE_OUTPUT" 'missing-unit-root-precedence-envelope-search-paths'
if grep -Eq '^workspace-descriptor-path=' "$UNIT_ROOT_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-unit-root-precedence-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$UNIT_ROOT_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-unit-root-precedence-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$UNIT_ROOT_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-unit-root-precedence-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$UNIT_ROOT_PRECEDENCE_OUTPUT"; then
  fail 'unexpected-unit-root-precedence-package-manifest-envelope-field'
fi
if ! "$UNIT_ROOT_PRECEDENCE_DIR/unit_root_precedence_smoke" >"$UNIT_ROOT_PRECEDENCE_RUN_OUTPUT" 2>&1; then
  cat "$UNIT_ROOT_PRECEDENCE_RUN_OUTPUT"
  fail 'unit-root-precedence-run-failed'
fi
cat "$UNIT_ROOT_PRECEDENCE_RUN_OUTPUT"
require_output_pattern '^hello from explicit unit root override$' "$UNIT_ROOT_PRECEDENCE_RUN_OUTPUT" 'missing-unit-root-precedence-run-output'
require_absent_path "$REPO_ROOT/tests/fixtures/unit_root_precedence/unit_root_precedence_smoke"
printf 'unit-root-precedence-check=pass\n'

printf 'invalid-unit-root-check=running\n'
printf 'invalid-unit-root-command=%s build examples/smoke/hello.pas --target linux-x86_64 --workspace %s --unit-root tests/fixtures/does-not-exist\n' "$STAGE0_BINARY" "$REPO_ROOT"
if run_stage0_build_capture "$INVALID_UNIT_ROOT_OUTPUT" examples/smoke/hello.pas --unit-root tests/fixtures/does-not-exist; then
  cat "$INVALID_UNIT_ROOT_OUTPUT"
  fail 'expected-invalid-unit-root-failure-did-not-fail'
fi
cat "$INVALID_UNIT_ROOT_OUTPUT"
require_output_pattern '^failure-kind=invalid-unit-root$' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-failure-kind'
require_output_pattern '^human-summary=invalid-unit-root: tests/fixtures/does-not-exist$' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-human-summary'
require_output_pattern '^workspace-root=.*/nextPas$' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-workspace-root'
require_output_pattern '^workspace-discovery-kind=explicit-workspace-override$' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-workspace-discovery-kind'
require_output_pattern '^artifact-root=.*/nextPas/\.nextpas$' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-artifact-root'
require_output_pattern '^output-dir=.*/nextPas/\.nextpas/out/linux-x86_64$' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-output-dir'
require_output_pattern '"failureKind":"invalid-unit-root"' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-envelope-field'
require_output_pattern '"workspaceRoot":".*/nextPas"' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-workspace-root-envelope-field'
require_output_pattern '"workspaceDiscoveryKind":"explicit-workspace-override"' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-workspace-discovery-envelope-field'
require_output_pattern '"artifactRoot":".*/nextPas/\.nextpas"' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-artifact-root-envelope-field'
require_output_pattern '"outputDir":".*/nextPas/\.nextpas/out/linux-x86_64"' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-output-dir-envelope-field'
require_output_pattern '"humanSummary":"invalid-unit-root: tests/fixtures/does-not-exist"' "$INVALID_UNIT_ROOT_OUTPUT" 'missing-invalid-unit-root-human-summary-envelope-field'
if grep -Eq '^workspace-descriptor-path=' "$INVALID_UNIT_ROOT_OUTPUT"; then
  fail 'unexpected-invalid-unit-root-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$INVALID_UNIT_ROOT_OUTPUT"; then
  fail 'unexpected-invalid-unit-root-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$INVALID_UNIT_ROOT_OUTPUT"; then
  fail 'unexpected-invalid-unit-root-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$INVALID_UNIT_ROOT_OUTPUT"; then
  fail 'unexpected-invalid-unit-root-package-manifest-envelope-field'
fi
printf 'invalid-unit-root-check=pass\n'

printf 'invalid-out-dir-check=running\n'
printf 'invalid-out-dir-command=%s build examples/smoke/hello.pas --target linux-x86_64 --workspace %s --out-dir %s\n' "$STAGE0_BINARY" "$REPO_ROOT" "$INVALID_OUT_DIR_PATH"
if run_stage0_build_capture "$INVALID_OUT_DIR_OUTPUT" examples/smoke/hello.pas --out-dir "$INVALID_OUT_DIR_PATH"; then
  cat "$INVALID_OUT_DIR_OUTPUT"
  fail 'expected-invalid-out-dir-failure-did-not-fail'
fi
cat "$INVALID_OUT_DIR_OUTPUT"
require_output_pattern '^failure-kind=invalid-out-dir$' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-failure-kind'
require_output_pattern '^human-summary=invalid-out-dir: /tmp/' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-human-summary'
require_output_pattern '^workspace-root=.*/nextPas$' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-workspace-root'
require_output_pattern '^workspace-discovery-kind=explicit-workspace-override$' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-workspace-discovery-kind'
require_output_pattern '^artifact-root=.*/nextPas/\.nextpas$' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-artifact-root'
require_output_pattern '^output-dir=/tmp/' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-output-dir'
require_output_pattern '"failureKind":"invalid-out-dir"' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-envelope-field'
require_output_pattern '"workspaceRoot":".*/nextPas"' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-workspace-root-envelope-field'
require_output_pattern '"workspaceDiscoveryKind":"explicit-workspace-override"' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-workspace-discovery-envelope-field'
require_output_pattern '"artifactRoot":".*/nextPas/\.nextpas"' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-artifact-root-envelope-field'
require_output_pattern '"outputDir":"/tmp/' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-output-dir-envelope-field'
require_output_pattern '"humanSummary":"invalid-out-dir: /tmp/[^"]+"' "$INVALID_OUT_DIR_OUTPUT" 'missing-invalid-out-dir-human-summary-envelope-field'
if grep -Eq '^workspace-descriptor-path=' "$INVALID_OUT_DIR_OUTPUT"; then
  fail 'unexpected-invalid-out-dir-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$INVALID_OUT_DIR_OUTPUT"; then
  fail 'unexpected-invalid-out-dir-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$INVALID_OUT_DIR_OUTPUT"; then
  fail 'unexpected-invalid-out-dir-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$INVALID_OUT_DIR_OUTPUT"; then
  fail 'unexpected-invalid-out-dir-package-manifest-envelope-field'
fi
printf 'invalid-out-dir-check=pass\n'

printf 'invalid-artifact-root-check=running\n'
cp examples/smoke/hello.pas "$INVALID_ARTIFACT_ROOT_WORKSPACE/hello.pas"
printf 'occupied' > "$INVALID_ARTIFACT_ROOT_WORKSPACE/.nextpas"
printf 'invalid-artifact-root-command=%s build %s/hello.pas --target linux-x86_64 --workspace %s\n' "$STAGE0_BINARY" "$INVALID_ARTIFACT_ROOT_WORKSPACE" "$INVALID_ARTIFACT_ROOT_WORKSPACE"
if "$STAGE0_BINARY" build "$INVALID_ARTIFACT_ROOT_WORKSPACE/hello.pas" --target "$TARGET_ID" --workspace "$INVALID_ARTIFACT_ROOT_WORKSPACE" >"$INVALID_ARTIFACT_ROOT_OUTPUT" 2>&1; then
  cat "$INVALID_ARTIFACT_ROOT_OUTPUT"
  fail 'expected-invalid-artifact-root-failure-did-not-fail'
fi
cat "$INVALID_ARTIFACT_ROOT_OUTPUT"
require_output_pattern '^failure-kind=invalid-artifact-root$' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-failure-kind'
require_output_pattern '^human-summary=invalid-artifact-root: /tmp/.*/\.nextpas$' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-human-summary'
require_output_pattern '^workspace-root=/tmp/.+$' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-workspace-root'
require_output_pattern '^workspace-discovery-kind=explicit-workspace-override$' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-workspace-discovery-kind'
require_output_pattern '^artifact-root=/tmp/.*/\.nextpas$' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-artifact-root'
require_output_pattern '^output-dir=/tmp/.*/\.nextpas/out/linux-x86_64$' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-output-dir'
require_output_pattern '"failureKind":"invalid-artifact-root"' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-envelope-field'
require_output_pattern '"workspaceRoot":"/tmp/.+"' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-workspace-root-envelope-field'
require_output_pattern '"workspaceDiscoveryKind":"explicit-workspace-override"' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-workspace-discovery-envelope-field'
require_output_pattern '"artifactRoot":"/tmp/.*/\.nextpas"' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-artifact-root-envelope-field'
require_output_pattern '"outputDir":"/tmp/.*/\.nextpas/out/linux-x86_64"' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-output-dir-envelope-field'
require_output_pattern '"humanSummary":"invalid-artifact-root: /tmp/.*/\.nextpas"' "$INVALID_ARTIFACT_ROOT_OUTPUT" 'missing-invalid-artifact-root-human-summary-envelope-field'
if grep -Eq '^workspace-descriptor-path=' "$INVALID_ARTIFACT_ROOT_OUTPUT"; then
  fail 'unexpected-invalid-artifact-root-workspace-descriptor-path'
fi
if grep -Eq '^package-manifest-path=' "$INVALID_ARTIFACT_ROOT_OUTPUT"; then
  fail 'unexpected-invalid-artifact-root-package-manifest-path'
fi
if grep -Eq '"workspaceDescriptorPath"' "$INVALID_ARTIFACT_ROOT_OUTPUT"; then
  fail 'unexpected-invalid-artifact-root-workspace-descriptor-envelope-field'
fi
if grep -Eq '"packageManifestPath"' "$INVALID_ARTIFACT_ROOT_OUTPUT"; then
  fail 'unexpected-invalid-artifact-root-package-manifest-envelope-field'
fi
printf 'invalid-artifact-root-check=pass\n'

printf 'harness-bootstrap-diagnostics-check=running\n'
cat <<'EOF' > "$HARNESS_BOOTSTRAP_FAKE_FPC_DIR/fpc"
#!/usr/bin/env sh
printf '%s\n' 'fake-fpc-sentinel: stage0 bootstrap failed' >&2
exit 1
EOF
chmod +x "$HARNESS_BOOTSTRAP_FAKE_FPC_DIR/fpc"
printf 'harness-bootstrap-diagnostics-command=PATH=<fake-fpc>:$PATH ./tests/run_all_tests.sh --filter smoke\n'
if PATH="$HARNESS_BOOTSTRAP_FAKE_FPC_DIR:$PATH" ./tests/run_all_tests.sh --filter smoke >"$HARNESS_BOOTSTRAP_FAILURE_OUTPUT" 2>&1; then
  cat "$HARNESS_BOOTSTRAP_FAILURE_OUTPUT"
  fail 'expected-harness-bootstrap-diagnostics-failure-did-not-fail'
fi
cat "$HARNESS_BOOTSTRAP_FAILURE_OUTPUT"
require_output_pattern '^failure-kind=stage0-build-failed$' "$HARNESS_BOOTSTRAP_FAILURE_OUTPUT" 'missing-harness-bootstrap-failure-kind'
require_output_pattern '^bootstrap-step=stage0-build$' "$HARNESS_BOOTSTRAP_FAILURE_OUTPUT" 'missing-harness-bootstrap-step'
require_output_pattern '^bootstrap-command=fpc .*-FE.*/stage0-bootstrap -FU.*/stage0-bootstrap tools/stage0/nextpas\.pas$' "$HARNESS_BOOTSTRAP_FAILURE_OUTPUT" 'missing-harness-bootstrap-command'
require_output_pattern '^bootstrap-stderr-file=.*/stage0-build\.stderr\.txt$' "$HARNESS_BOOTSTRAP_FAILURE_OUTPUT" 'missing-harness-bootstrap-stderr-file'
require_output_pattern 'fake-fpc-sentinel: stage0 bootstrap failed' "$HARNESS_BOOTSTRAP_FAILURE_OUTPUT" 'missing-harness-bootstrap-stderr-evidence'
printf 'harness-bootstrap-diagnostics-check=pass\n'

printf 'stage0-test-list-groups-check=running\n'
printf 'stage0-test-list-groups-command=%s test --list-groups --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" test --list-groups --workspace "$REPO_ROOT" >"$STAGE0_TEST_LIST_GROUPS_OUTPUT" 2>&1; then
  cat "$STAGE0_TEST_LIST_GROUPS_OUTPUT"
  fail 'stage0-test-list-groups-check-failed'
fi
cat "$STAGE0_TEST_LIST_GROUPS_OUTPUT"
require_output_pattern '^compiler-pass$' "$STAGE0_TEST_LIST_GROUPS_OUTPUT" 'missing-stage0-test-list-groups-compiler-pass'
require_output_pattern '^compiler-fail$' "$STAGE0_TEST_LIST_GROUPS_OUTPUT" 'missing-stage0-test-list-groups-compiler-fail'
require_output_pattern '^diagnostics$' "$STAGE0_TEST_LIST_GROUPS_OUTPUT" 'missing-stage0-test-list-groups-diagnostics'
require_output_pattern '^rtl$' "$STAGE0_TEST_LIST_GROUPS_OUTPUT" 'missing-stage0-test-list-groups-rtl'
require_output_pattern '^crt$' "$STAGE0_TEST_LIST_GROUPS_OUTPUT" 'missing-stage0-test-list-groups-crt'
require_output_pattern '^regression$' "$STAGE0_TEST_LIST_GROUPS_OUTPUT" 'missing-stage0-test-list-groups-regression'
printf 'stage0-test-list-groups-check=pass\n'

printf 'stage0-test-invalid-arguments-check=running\n'
printf 'stage0-test-invalid-arguments-command=%s test\n' "$STAGE0_BINARY"
if NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" test >"$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 2>&1; then
  cat "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT"
  fail 'expected-stage0-test-invalid-arguments-did-not-fail'
fi
cat "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT"
require_output_pattern '^command=test$' "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-test-invalid-arguments-command'
require_output_pattern '^selector=test$' "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-test-invalid-arguments-selector'
require_output_pattern '^failure-kind=invalid-arguments$' "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-test-invalid-arguments-failure-kind'
require_output_pattern '^human-summary=invalid-arguments$' "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-test-invalid-arguments-human-summary'
require_output_pattern '^  nextpas test --list-groups \[--workspace <root>\]$' "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-test-invalid-arguments-list-groups-usage'
require_output_pattern '^  nextpas test --filter <group> \[--workspace <root>\]$' "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-test-invalid-arguments-filter-usage'
require_output_pattern '"command":"test"' "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-test-invalid-arguments-envelope-command'
require_output_pattern '"selector":"test"' "$STAGE0_TEST_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-test-invalid-arguments-envelope-selector'
printf 'stage0-test-invalid-arguments-check=pass\n'

printf 'stage0-test-unknown-group-check=running\n'
printf 'stage0-test-unknown-group-command=%s test --filter does-not-exist\n' "$STAGE0_BINARY"
if NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" test --filter does-not-exist >"$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 2>&1; then
  cat "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT"
  fail 'expected-stage0-test-unknown-group-did-not-fail'
fi
cat "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT"
require_output_pattern '^command=test$' "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 'missing-stage0-test-unknown-group-command'
require_output_pattern '^selector=group$' "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 'missing-stage0-test-unknown-group-selector'
require_output_pattern '^requested-filter=does-not-exist$' "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 'missing-stage0-test-unknown-group-requested-filter'
require_output_pattern '^failure-kind=unknown-group$' "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 'missing-stage0-test-unknown-group-failure-kind'
require_output_pattern '^human-summary=unknown group: does-not-exist$' "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 'missing-stage0-test-unknown-group-human-summary'
require_output_pattern '^unknown-group: does-not-exist$' "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 'missing-stage0-test-unknown-group-message'
require_output_pattern '"command":"test"' "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 'missing-stage0-test-unknown-group-envelope-command'
require_output_pattern '"requestedFilter":"does-not-exist"' "$STAGE0_TEST_UNKNOWN_GROUP_OUTPUT" 'missing-stage0-test-unknown-group-envelope-requested-filter'
printf 'stage0-test-unknown-group-check=pass\n'

printf 'stage0-test-compiler-pass-check=running\n'
printf 'stage0-test-compiler-pass-command=%s test --filter compiler-pass\n' "$STAGE0_BINARY"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" test --filter compiler-pass >"$STAGE0_TEST_COMPILER_PASS_OUTPUT" 2>&1; then
  cat "$STAGE0_TEST_COMPILER_PASS_OUTPUT"
  fail 'stage0-test-compiler-pass-check-failed'
fi
cat "$STAGE0_TEST_COMPILER_PASS_OUTPUT"
require_output_pattern '^mode=group$' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-mode'
require_output_pattern '^command=test$' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-command'
require_output_pattern '^selector=group$' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-selector'
require_output_pattern '^group=compiler-pass$' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-group'
require_output_pattern '^status=ready$' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-status'
require_output_pattern '^result=pass$' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-result'
require_output_pattern '^command-outcome=success$' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-command-outcome'
require_output_pattern '^human-summary=group compiler-pass passed$' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-human-summary'
require_output_pattern '"command":"test"' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-envelope-command'
require_output_pattern '"selector":"group"' "$STAGE0_TEST_COMPILER_PASS_OUTPUT" 'missing-stage0-test-compiler-pass-envelope-selector'
printf 'stage0-test-compiler-pass-check=pass\n'

printf 'stage0-test-smoke-check=running\n'
printf 'stage0-test-smoke-command=%s test --filter smoke --workspace %s\n' "$STAGE0_BINARY" "$REPO_ROOT"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" test --filter smoke --workspace "$REPO_ROOT" >"$STAGE0_TEST_SMOKE_OUTPUT" 2>&1; then
  cat "$STAGE0_TEST_SMOKE_OUTPUT"
  fail 'stage0-test-smoke-check-failed'
fi
cat "$STAGE0_TEST_SMOKE_OUTPUT"
require_output_pattern '^mode=smoke$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-mode'
require_output_pattern '^command=test$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-command'
require_output_pattern '^selector=smoke$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-selector'
require_output_pattern '^status=ready$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-status'
require_output_pattern '^result=pass$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-result'
require_output_pattern '^smoke-status=ready$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-smoke-status'
require_output_pattern '^smoke-result=pass$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-smoke-result'
require_output_pattern '^command-outcome=success$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-command-outcome'
require_output_pattern '^human-summary=smoke baseline ready$' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-human-summary'
require_output_pattern '"command":"test"' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-envelope-command'
require_output_pattern '"selector":"smoke"' "$STAGE0_TEST_SMOKE_OUTPUT" 'missing-stage0-test-smoke-envelope-selector'
printf 'stage0-test-smoke-check=pass\n'

printf 'stage0-env-status-check=running\n'
printf 'stage0-env-status-command=%s env status --target %s\n' "$STAGE0_BINARY" "$TARGET_ID"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" env status --target "$TARGET_ID" >"$STAGE0_ENV_STATUS_OUTPUT" 2>&1; then
  cat "$STAGE0_ENV_STATUS_OUTPUT"
  fail 'stage0-env-status-check-failed'
fi
cat "$STAGE0_ENV_STATUS_OUTPUT"
require_output_pattern '^mode=env$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-mode'
require_output_pattern '^command=env$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-command'
require_output_pattern '^selector=status$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-selector'
require_output_pattern '^target=linux-x86_64$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-target'
require_output_pattern '^target-config=.*/build/targets/linux-x86_64\.toml$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-target-config'
require_output_pattern '^compiler=fpc$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-compiler'
require_output_pattern '^host-id=linux-x86_64$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-host-id'
require_output_pattern '^toolchain-binding-id=linux-x86_64-to-linux-x86_64-gnu$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-binding-id'
require_output_pattern '^backend-family=native$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-backend-family'
require_output_pattern '^sysroot-mode=runtime-sdk$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-sysroot-mode'
require_output_pattern '^runtime-sdk-id=linux-x86_64$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-runtime-sdk-id'
require_output_pattern '^tool-root-kind=distribution-helper-root$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-tool-root-kind'
require_output_pattern '^runtime-root-kind=distribution-runtime-root$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-runtime-root-kind'
require_output_pattern '^tool-profile-root=.*/build/tool-profiles$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-tool-profile-root'
require_output_pattern '^toolchain-binding-path=.*/build/toolchains/linux-x86_64-to-linux-x86_64-gnu\.toml$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-binding-path'
require_output_pattern '^distribution-bin-dir=.*/nextPas/bin$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-distribution-bin-dir'
require_output_pattern '^distribution-lib-dir=.*/nextPas/lib$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-distribution-lib-dir'
require_output_pattern '^distribution-share-dir=.*/nextPas/share$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-distribution-share-dir'
require_output_pattern '^runtime-root=.*/nextPas/lib/nextpas/runtime/linux-x86_64$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-runtime-root'
require_output_pattern '^runtime-libc=.*/nextPas/lib/nextpas/runtime/linux-x86_64/libc\.so$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-runtime-libc'
require_output_pattern '^runtime-libc-present=false$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-runtime-libc-presence'
require_output_pattern '^environment-readiness=incomplete$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-environment-readiness'
require_output_pattern '^environment-status=(ready|incomplete)$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-environment-status'
require_output_pattern '^runtime-sdk-status=missing$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-runtime-sdk-status'
require_output_pattern '^toolchain-binding-status=ready$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-toolchain-binding-status'
require_output_pattern '^distribution-status=(ready|incomplete)$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-distribution-status'
require_output_pattern '^status=success$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-status'
require_output_pattern '^result=success$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-result'
require_output_pattern '^command-outcome=success$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-command-outcome'
require_output_pattern '^human-summary=environment status captured$' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-human-summary'
require_output_pattern '^command-envelope=.*"command":"env"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-command'
require_output_pattern '^command-envelope=.*"selector":"status"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-selector'
require_output_pattern '^command-envelope=.*"target":"linux-x86_64".*"targetConfig":".*/build/targets/linux-x86_64\.toml".*"compiler":"fpc"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-build-context'
require_output_pattern '^command-envelope=.*"toolchainBindingId":"linux-x86_64-to-linux-x86_64-gnu".*"runtimeSdkId":"linux-x86_64".*"toolProfileRoot":".*/build/tool-profiles"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-toolchain'
require_output_pattern '^command-envelope=.*"toolchainBindingPath":".*/build/toolchains/linux-x86_64-to-linux-x86_64-gnu\.toml".*"distributionBinDir":".*/nextPas/bin".*"distributionLibDir":".*/nextPas/lib".*"distributionShareDir":".*/nextPas/share"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-distribution'
require_output_pattern '^command-envelope=.*"runtimeRoot":".*/nextPas/lib/nextpas/runtime/linux-x86_64".*"runtimeLibc":".*/nextPas/lib/nextpas/runtime/linux-x86_64/libc\.so".*"runtimeLibcPresent":false' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-runtime'
require_output_pattern '^command-envelope=.*"environmentReadiness":"incomplete".*"runtimeSdkStatus":"missing"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-readiness'
require_output_pattern '^command-envelope=.*"environmentStatus":"(ready|incomplete)"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-environment-status'
require_output_pattern '^command-envelope=.*"toolchainBindingStatus":"ready"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-toolchain-binding-status'
require_output_pattern '^command-envelope=.*"distributionStatus":"(ready|incomplete)"' "$STAGE0_ENV_STATUS_OUTPUT" 'missing-stage0-env-status-envelope-distribution-status'
printf 'stage0-env-status-check=pass\n'

printf 'stage0-doctor=running\n'
printf 'stage0-doctor-command=%s doctor --target %s --workspace %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" doctor --target "$TARGET_ID" --workspace "$REPO_ROOT" >"$STAGE0_DOCTOR_OUTPUT" 2>&1; then
  cat "$STAGE0_DOCTOR_OUTPUT"
  fail 'stage0-doctor-failed'
fi
cat "$STAGE0_DOCTOR_OUTPUT"
require_output_pattern '^mode=doctor$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-mode'
require_output_pattern '^command=doctor$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-command'
require_output_pattern '^selector=doctor$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-selector'
require_output_pattern '^target=linux-x86_64$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-target'
require_output_pattern '^environment-readiness=(incomplete|ready)$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-environment-readiness'
require_output_pattern '^runtime-sdk-status=(missing|ready)$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-runtime-sdk-status'
require_output_pattern '^runtime-libc-present=(false|true)$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-runtime-libc-presence'
require_output_pattern '^doctor-workspace-status=ready$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-workspace-status'
require_output_pattern '^doctor-toolchain-binding-status=ready$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-toolchain-binding-status'
require_output_pattern '^doctor-check-count=[1-9][0-9]*$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-check-count'
require_output_pattern '^doctor-finding-count=[0-9]+$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-finding-count'
require_output_pattern '^doctor-finding-code=doctor\.runtime-sdk-missing$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-finding-code'
require_output_pattern '^doctor-finding-severity=warning$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-finding-severity'
require_output_pattern '^doctor-status=(warning|healthy)$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-status'
require_output_pattern '^status=success$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-success-status'
require_output_pattern '^result=success$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-success-result'
require_output_pattern '^command-outcome=success$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-command-outcome'
require_output_pattern '^human-summary=doctor inspection completed$' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-human-summary'
require_output_pattern '^command-envelope=.*"command":"doctor"' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-envelope-command'
require_output_pattern '^command-envelope=.*"selector":"doctor".*"doctorStatus":"(warning|healthy)"' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-envelope-status'
require_output_pattern '^command-envelope=.*"doctorWorkspaceStatus":"ready".*"doctorToolchainBindingStatus":"ready"' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-envelope-readiness'
require_output_pattern '^command-envelope=.*"doctorFindings":\[.*"code":"doctor\.runtime-sdk-missing".*"severity":"warning"' "$STAGE0_DOCTOR_OUTPUT" 'missing-stage0-doctor-envelope-finding'

printf 'stage0-doctor-invalid-arguments-check=running\n'
printf 'stage0-doctor-invalid-arguments-command=%s doctor\n' "$STAGE0_BINARY"
if NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" doctor >"$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT" 2>&1; then
  cat "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT"
  fail 'expected-stage0-doctor-invalid-arguments-did-not-fail'
fi
cat "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT"
require_output_pattern '^command=doctor$' "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-doctor-invalid-arguments-command'
require_output_pattern '^selector=doctor$' "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-doctor-invalid-arguments-selector'
require_output_pattern '^failure-kind=invalid-arguments$' "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-doctor-invalid-arguments-failure-kind'
require_output_pattern '^human-summary=invalid-arguments$' "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-doctor-invalid-arguments-human-summary'
require_output_pattern '^command-envelope=.*"command":"doctor"' "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-doctor-invalid-arguments-envelope-command'
require_output_pattern '^command-envelope=.*"selector":"doctor".*"failureKind":"invalid-arguments"' "$STAGE0_DOCTOR_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-doctor-invalid-arguments-envelope-failure'
printf 'stage0-doctor-check=pass\n'

printf 'stage0-query-symbols-check=running\n'
printf 'stage0-query-symbols-command=%s query symbols examples/smoke/hello_with_units.pas --target %s --workspace %s\n' "$STAGE0_BINARY" "$TARGET_ID" "$REPO_ROOT"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" query symbols examples/smoke/hello_with_units.pas --target "$TARGET_ID" --workspace "$REPO_ROOT" >"$STAGE0_QUERY_SYMBOLS_OUTPUT" 2>&1; then
  cat "$STAGE0_QUERY_SYMBOLS_OUTPUT"
  fail 'stage0-query-symbols-failed'
fi
cat "$STAGE0_QUERY_SYMBOLS_OUTPUT"
require_output_pattern '^mode=query$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-mode'
require_output_pattern '^command=query$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-command'
require_output_pattern '^selector=symbols$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-selector'
require_output_pattern '^query-kind=symbols$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-kind'
require_output_pattern '^query-status=success$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-status'
require_output_pattern '^analysis-source=compilation-session$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-analysis-source'
require_output_pattern '^query-result-count=[1-9][0-9]*$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-result-count'
require_output_pattern '^mir-status=deferred$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-deferred-mir'
require_output_pattern '^backend-plan-status=deferred$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-deferred-backend'
require_output_pattern '^toolchain-plan-status=deferred$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-deferred-toolchain'
require_output_pattern '^lifecycle-stage=syntax:ready,resolution:ready,sema:ready,ir:deferred,backend:deferred,toolchain:deferred$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-deferred-lifecycle'
require_output_pattern '^status=success$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-success-status'
require_output_pattern '^result=success$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-success-result'
require_output_pattern '^command-outcome=success$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-command-outcome'
require_output_pattern '^human-summary=query symbols completed$' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-human-summary'
require_output_pattern '^command-envelope=.*"command":"query"' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-envelope-command'
require_output_pattern '^command-envelope=.*"selector":"symbols".*"queryKind":"symbols"' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-envelope-kind'
require_output_pattern '^command-envelope=.*"queryStatus":"success".*"analysisSource":"compilation-session".*"queryResultCount":[1-9][0-9]*' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-envelope-result'
require_output_pattern '^command-envelope=.*"mirStatus":"deferred".*"backendPlanStatus":"deferred".*"toolchainPlanStatus":"deferred"' "$STAGE0_QUERY_SYMBOLS_OUTPUT" 'missing-stage0-query-symbols-envelope-deferred-stages'

printf 'stage0-query-invalid-arguments-check=running\n'
printf 'stage0-query-invalid-arguments-command=%s query\n' "$STAGE0_BINARY"
if NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" query >"$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT" 2>&1; then
  cat "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT"
  fail 'expected-stage0-query-invalid-arguments-did-not-fail'
fi
cat "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT"
require_output_pattern '^command=query$' "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-query-invalid-arguments-command'
require_output_pattern '^selector=query$' "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-query-invalid-arguments-selector'
require_output_pattern '^failure-kind=invalid-arguments$' "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-query-invalid-arguments-failure-kind'
require_output_pattern '^human-summary=invalid-arguments$' "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-query-invalid-arguments-human-summary'
require_output_pattern '^command-envelope=.*"command":"query"' "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-query-invalid-arguments-envelope-command'
require_output_pattern '^command-envelope=.*"selector":"query".*"failureKind":"invalid-arguments"' "$STAGE0_QUERY_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-query-invalid-arguments-envelope-failure'
printf 'stage0-query-check=pass\n'

printf 'stage0-pkg-inspect-check=running\n'
printf 'stage0-pkg-inspect-command=%s pkg inspect --workspace %s --target %s\n' "$STAGE0_BINARY" "$PACKAGE_MANIFEST_FIXTURE_ROOT" "$TARGET_ID"
if ! NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" pkg inspect --workspace "$PACKAGE_MANIFEST_FIXTURE_ROOT" --target "$TARGET_ID" >"$STAGE0_PKG_INSPECT_OUTPUT" 2>&1; then
  cat "$STAGE0_PKG_INSPECT_OUTPUT"
  fail 'stage0-pkg-inspect-failed'
fi
cat "$STAGE0_PKG_INSPECT_OUTPUT"
require_output_pattern '^command=pkg$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-command'
require_output_pattern '^selector=inspect$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-selector'
require_output_pattern '^package-workflow-status=ready$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-workflow-status'
require_output_pattern '^package-manifest-status=ready$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-manifest-status'
require_output_pattern '^package-source-root-count=[1-9][0-9]*$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-source-root-count'
require_output_pattern '^package-install-plan-status=deferred$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-install-plan-status'
require_output_pattern '^status=success$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-success-status'
require_output_pattern '^result=success$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-success-result'
require_output_pattern '^command-outcome=success$' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-command-outcome'
require_output_pattern '^command-envelope=.*"command":"pkg"' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-envelope-command'
require_output_pattern '^command-envelope=.*"selector":"inspect".*"packageWorkflowStatus":"ready"' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-envelope-workflow'
require_output_pattern '^command-envelope=.*"packageManifestStatus":"ready".*"packageInstallPlanStatus":"deferred".*"packageSourceRootCount":[1-9][0-9]*' "$STAGE0_PKG_INSPECT_OUTPUT" 'missing-stage0-pkg-inspect-envelope-result'

printf 'stage0-pkg-invalid-arguments-check=running\n'
printf 'stage0-pkg-invalid-arguments-command=%s pkg\n' "$STAGE0_BINARY"
if NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" pkg >"$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT" 2>&1; then
  cat "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT"
  fail 'expected-stage0-pkg-invalid-arguments-did-not-fail'
fi
cat "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT"
require_output_pattern '^command=pkg$' "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-pkg-invalid-arguments-command'
require_output_pattern '^selector=pkg$' "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-pkg-invalid-arguments-selector'
require_output_pattern '^failure-kind=invalid-arguments$' "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-pkg-invalid-arguments-failure-kind'
require_output_pattern '^human-summary=invalid-arguments$' "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-pkg-invalid-arguments-human-summary'
require_output_pattern '^command-envelope=.*"command":"pkg"' "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-pkg-invalid-arguments-envelope-command'
require_output_pattern '^command-envelope=.*"selector":"pkg".*"failureKind":"invalid-arguments"' "$STAGE0_PKG_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-pkg-invalid-arguments-envelope-failure'
printf 'stage0-pkg-check=pass\n'

printf 'stage0-env-invalid-arguments-check=running\n'
printf 'stage0-env-invalid-arguments-command=%s env\n' "$STAGE0_BINARY"
if NEXTPAS_REPO_ROOT="$REPO_ROOT" "$STAGE0_BINARY" env >"$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT" 2>&1; then
  cat "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT"
  fail 'expected-stage0-env-invalid-arguments-did-not-fail'
fi
cat "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT"
require_output_pattern '^command=env$' "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-env-invalid-arguments-command'
require_output_pattern '^selector=env$' "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-env-invalid-arguments-selector'
require_output_pattern '^failure-kind=invalid-arguments$' "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-env-invalid-arguments-failure-kind'
require_output_pattern '^human-summary=invalid-arguments$' "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-env-invalid-arguments-human-summary'
require_output_pattern '^  nextpas env status --target linux-x86_64 \[--toolchain-binding <id>\]$' "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-env-invalid-arguments-usage'
require_output_pattern '^command-envelope=.*"command":"env"' "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-env-invalid-arguments-envelope-command'
require_output_pattern '^command-envelope=.*"selector":"env".*"failureKind":"invalid-arguments"' "$STAGE0_ENV_INVALID_ARGUMENTS_OUTPUT" 'missing-stage0-env-invalid-arguments-envelope-failure'
printf 'stage0-env-invalid-arguments-check=pass\n'

printf 'harness-compiler-pass-check=running\n'
printf 'harness-compiler-pass-command=./tests/run_all_tests.sh --filter compiler-pass\n'
if ! ./tests/run_all_tests.sh --filter compiler-pass >"$HARNESS_COMPILER_PASS_OUTPUT" 2>&1; then
  cat "$HARNESS_COMPILER_PASS_OUTPUT"
  fail 'harness-compiler-pass-check-failed'
fi
cat "$HARNESS_COMPILER_PASS_OUTPUT"
require_output_pattern '^executed-fixture-count=1$' "$HARNESS_COMPILER_PASS_OUTPUT" 'missing-harness-executed-fixture-count'
require_output_pattern '^fixture-result=.*tests/compiler/pass/hello_pass\.pas .*result=pass' "$HARNESS_COMPILER_PASS_OUTPUT" 'missing-harness-compiler-pass-fixture-result'
printf 'harness-compiler-pass-check=pass\n'

printf 'smoke-check=running\n'
printf 'smoke-command=./tests/run_all_tests.sh --filter smoke\n'
if ! ./tests/run_all_tests.sh --filter smoke >"$HARNESS_SMOKE_OUTPUT" 2>&1; then
  cat "$HARNESS_SMOKE_OUTPUT"
  fail 'smoke-check-failed'
fi
cat "$HARNESS_SMOKE_OUTPUT"
if ! grep -q '^command-envelope=' "$HARNESS_SMOKE_OUTPUT"; then
  fail 'missing-harness-command-envelope'
fi
require_output_pattern '^smoke-group=compiler-pass .*executed=1 ' "$HARNESS_SMOKE_OUTPUT" 'missing-smoke-compiler-pass-execution'
require_output_pattern '^smoke-group=rtl .*executed=' "$HARNESS_SMOKE_OUTPUT" 'missing-smoke-rtl-execution'
printf 'smoke-check=pass\n'

printf 'status=ready\n'
printf 'result=pass\n'
printf 'command-outcome=success\n'
printf 'command-envelope={"command":"verify-local","exitCode":0,"result":{"selector":"%s","target":"%s","status":"ready","result":"pass","docsCheck":"pass","inputsCheck":"pass","stage0Build":"pass","lexerConformance":"pass","stage0Smoke":"pass","llvmBindingSmoke":"pass","llvmEmptyProgram":"pass","llvmHaltProgram":"pass","llvmHaltExprProgram":"pass","llvmHaltConstProgram":"pass","llvmWritelnProgram":"pass","llvmWritelnIntProgram":"pass","llvmWritelnMultiProgram":"pass","llvmWritelnMixedProgram":"pass","llvmHelloThenHaltProgram":"pass","llvmVarHaltProgram":"pass","llvmNoFoldHaltProgram":"pass","llvmNoFoldHaltExprProgram":"pass","llvmNoFoldVarHaltProgram":"pass","llvmNoFoldVarChainProgram":"pass","llvmNoFoldIfHaltProgram":"pass","llvmNoFoldIfElseHaltProgram":"pass","llvmNoFoldIfVarProgram":"pass","llvmNoFoldRepeatHaltProgram":"pass","llvmNoFoldWhileSumProgram":"pass","llvmNoFoldForSumHaltProgram":"pass","llvmNoFoldForWritelnProgram":"pass","llvmNoFoldWhileCountProgram":"pass","llvmNoFoldForDowntoProgram":"pass","llvmNoFoldRepeatCountProgram":"pass","llvmVarWritelnProgram":"pass","llvmVarChainProgram":"pass","llvmIfHaltProgram":"pass","llvmIfElseHaltProgram":"pass","llvmIfVarProgram":"pass","llvmForWritelnProgram":"pass","llvmForSumHaltProgram":"pass","llvmForDowntoProgram":"pass","llvmIfNotProgram":"pass","llvmIfTrueProgram":"pass","llvmWhileCountProgram":"pass","llvmWhileSumProgram":"pass","llvmRepeatCountProgram":"pass","llvmRepeatHaltProgram":"pass","llvmConstStringProgram":"pass","llvmStringConcatProgram":"pass","llvmProcGreetProgram":"pass","llvmProcTwoProgram":"pass","llvmFnConstHaltProgram":"pass","llvmFnComposeProgram":"pass","llvmFnCallHaltProgram":"pass","llvmFnCallChainProgram":"pass","llvmProcArgProgram":"pass","llvmFnSquareProgram":"pass","semanticSmokeCheck":"pass","toolchainContractCheck":"pass","toolchainFailureCheck":"pass","assemblerFailureAttributionCheck":"pass","linkerFailureAttributionCheck":"pass","coreTextSmokeCheck":"pass","syntaxFailureCheck":"pass","missingUnitCheck":"pass","ambiguousUnitCheck":"pass","unitCycleCheck":"pass","duplicateImportCheck":"pass","rootImplementationCheck":"pass","requestedNameMismatchCheck":"pass","explicitSystemCheck":"pass","explicitUnitRootCheck":"pass","packageManifestSourceRootCheck":"pass","workspaceMemberSourceRootCheck":"pass","sourceDirectoryFallbackCheck":"pass","packageManifestSourcePrecedenceCheck":"pass","outDirOverrideCheck":"pass","rootSourcePrecedenceCheck":"pass","unitRootPrecedenceCheck":"pass","invalidUnitRootCheck":"pass","invalidOutDirCheck":"pass","invalidArtifactRootCheck":"pass","harnessBootstrapDiagnosticsCheck":"pass","stage0TestListGroupsCheck":"pass","stage0TestInvalidArgumentsCheck":"pass","stage0TestUnknownGroupCheck":"pass","stage0TestCompilerPassCheck":"pass","stage0TestSmokeCheck":"pass","stage0EnvStatusCheck":"pass","stage0DoctorCheck":"pass","stage0DoctorInvalidArgumentsCheck":"pass","stage0QueryCheck":"pass","stage0QueryInvalidArgumentsCheck":"pass","stage0PkgCheck":"pass","stage0PkgInvalidArgumentsCheck":"pass","stage0EnvInvalidArgumentsCheck":"pass","harnessCompilerPassCheck":"pass","smokeCheck":"pass"},"diagnostics":[],"buildTraceRef":null,"humanSummary":"local verification passed"}\n' "$VERIFY_SELECTOR" "$TARGET_ID"
printf 'verify-local=pass\n'
printf 'human-summary=local verification passed\n'
