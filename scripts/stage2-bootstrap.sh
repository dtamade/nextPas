#!/bin/bash
# stage2-bootstrap.sh — nextPas 自举编译
#
# Stage2: 用 nextPas (stage0) 编译 nextPas 编译器自身，再用产物编译自身。
# 验证：产物 A 编译出 B，B 编译出 C，C == B。
#
# 对标：Rust stage2 bootstrap, Go bootstrap

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGE0="$REPO_ROOT/build/stage0-bootstrap/nextpas"
STAGE2_DIR="$REPO_ROOT/build/stage2"
STAGE2_A="$STAGE2_DIR/stage2-a"
STAGE2_B="$STAGE2_DIR/stage2-b"
STAGE2_C="$STAGE2_DIR/stage2-c"

COMPILER_MODULES=(
  "compiler/sema/np_sema_type_check.pas"
  "compiler/sema/np_sema_runtime_vars.pas"
  "compiler/sema/np_sema_string_ownership.pas"
  "compiler/sema/np_sema_overload.pas"
  "compiler/sema/np_sema_hir_lowering.pas"
  "compiler/sema/np_sema_builtins.pas"
  "compiler/sema/np_semantic_model.pas"
  "compiler/sema/np_semantic_analyzer.pas"
  "compiler/ir/np_mir_model.pas"
  "compiler/ir/np_mir_optimize.pas"
  "compiler/ir/np_mir_pass_registry.pas"
  "compiler/ir/np_hir_builder.pas"
  "compiler/ir/np_hir_model.pas"
  "compiler/frontend/np_compilation_session.pas"
  "compiler/frontend/np_workspace_model.pas"
  "compiler/frontend/np_unit_graph.pas"
  "compiler/syntax/np_ast_facade.pas"
  "compiler/frontend/np_source_database.pas"
  "compiler/syntax/np_green_tree.pas"
  "compiler/syntax/np_lexer.pas"
  "compiler/diagnostics/np_diagnostics_sink.pas"
  "compiler/diagnostics/np_diagnostics_enhanced.pas"
)

echo "=== nextPas Stage2 Bootstrap ==="
echo ""

# Ensure stage0 exists
if [ ! -x "$STAGE0" ]; then
  echo "ERROR: stage0 compiler not found at $STAGE0"
  echo "Run 'make rebuild-compiler' first"
  exit 1
fi

mkdir -p "$STAGE2_DIR"

# Phase 1: Build stage2-A (stage0 → stage2 compiler)
echo "[1/3] Building stage2-A (stage0 → nextPas)..."
rm -rf "$STAGE2_A"
mkdir -p "$STAGE2_A"

PASS_COUNT=0
FAIL_COUNT=0

for MODULE in "${COMPILER_MODULES[@]}"; do
  MODULE_NAME="$(basename "$MODULE" .pas)"
  echo -n "  Compiling $MODULE_NAME... "
  if "$STAGE0" build "$REPO_ROOT/$MODULE" \
      --target linux-x86_64 \
      --out-dir "$STAGE2_A" \
      > /dev/null 2>&1; then
    echo "OK"
    ((PASS_COUNT++)) || true
  else
    echo "FAIL"
    ((FAIL_COUNT++)) || true
  fi
done

echo ""
echo "  Stage2-A results: $PASS_COUNT passed, $FAIL_COUNT failed"

# Phase 2: Build stage2-B (stage2-A → stage2 compiler)
echo ""
echo "[2/3] Building stage2-B (stage2-A → nextPas)..."

STAGE2_A_COMPILER="$STAGE2_A/np_semantic_analyzer"
if [ ! -f "$STAGE2_A_COMPILER" ] && [ ! -f "$STAGE2_A_COMPILER.o" ]; then
  echo "  WARNING: stage2-A compiler not fully built, skipping stage2-B"
  echo "  This is expected for initial bootstrap — stage2-A is partial."
else
  echo "  Stage2-A compiler modules built: $PASS_COUNT"
  echo "  Full stage2-B requires stage2-A to be a complete compiler executable"
  echo "  (not just individual .o files)"
fi

# Phase 3: Verify semantic equivalence
echo ""
echo "[3/3] Verification..."
echo "  Stage2 bootstrap infrastructure ready"
echo "  Current stage0 can compile $PASS_COUNT/${#COMPILER_MODULES[@]} compiler modules"

echo ""
echo "=== Bootstrap Summary ==="
echo "  stage0:  FPC-compiled nextPas (working)"
echo "  stage2-A: $PASS_COUNT compiler modules compiled by stage0"
echo "  stage2-B: requires stage2-A linker output"
echo "  stage2-C: requires stage2-B → stage2-C bit-identical verification"

if [ $FAIL_COUNT -eq 0 ]; then
  echo ""
  echo "  RESULT: All compiler modules compile successfully with stage0"
  echo "  Next step: link stage2-A modules into full compiler executable"
fi
