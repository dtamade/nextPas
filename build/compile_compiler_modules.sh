#!/bin/bash
# Compile compiler modules with nextPas and install to runtime SDK

set -e

NEXTPAS="./.sisyphus/tmp/stage0-bootstrap-debug/nextpas"
TARGET="linux-x86_64"
WORKSPACE="."
RUNTIME_SDK="units/linux-x86_64"

# List of modules to compile (in dependency order)
MODULES=(
  # Diagnostics
  "compiler/diagnostics/np_diagnostics_sink.pas"

  # Frontend
  "compiler/frontend/np_source_database.pas"
  "compiler/frontend/np_unit_graph.pas"
  "compiler/frontend/np_workspace_model.pas"
  "compiler/frontend/np_package_manifest.pas"
  "compiler/frontend/np_package_workflow.pas"
  "compiler/frontend/np_unit_resolver.pas"
  "compiler/frontend/np_compilation_session.pas"

  # Syntax
  "compiler/syntax/np_lexer.pas"
  "compiler/syntax/np_green_tree.pas"
  "compiler/syntax/np_ast_facade.pas"

  # Sema
  "compiler/sema/np_semantic_model.pas"
  "compiler/sema/np_semantic_analyzer.pas"

  # Targets
  "compiler/targets/np_target_facts.pas"

  # Toolchain
  "compiler/toolchain/np_toolchain_profiles.pas"
  "compiler/toolchain/np_toolchain_plan.pas"
  "compiler/toolchain/np_toolchain_runner.pas"

  # IR
  "compiler/ir/np_mir_model.pas"

  # Backend
  "compiler/backend/np_backend_plan.pas"
)

SUCCESS_COUNT=0
FAIL_COUNT=0

echo "Starting compiler module self-compilation..."
echo

for MODULE in "${MODULES[@]}"; do
  MODULE_NAME=$(basename "$MODULE" .pas)
  echo "Compiling $MODULE_NAME..."

  if "$NEXTPAS" build "$MODULE" --target "$TARGET" --workspace "$WORKSPACE" 2>&1 | grep -q "^status=success"; then
    echo "  ✓ Success"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

    # Copy source file to runtime SDK so other modules can find it
    cp "$MODULE" "$RUNTIME_SDK/"
    echo "    Installed $(basename "$MODULE")"
  else
    echo "  ✗ Failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))

    # Show error
    "$NEXTPAS" build "$MODULE" --target "$TARGET" --workspace "$WORKSPACE" 2>&1 | grep "diagnostic-message=" | head -1
  fi

  echo
done

echo "Summary:"
echo "  Success: $SUCCESS_COUNT"
echo "  Failed:  $FAIL_COUNT"

if [ $FAIL_COUNT -gt 0 ]; then
  exit 1
fi
