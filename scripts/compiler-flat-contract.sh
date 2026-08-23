#!/usr/bin/env bash
# Compiler flat-namespace contract gate (plan: docs/plans/compiler-flat-namespace.md).
# Asserts migrated units leave zero old-name references and that no
# compiler unit reaches into forbidden core families.
set -u
cd "$(dirname "$0")/.."
fail=0

# 1. Migrated names must not appear anywhere in code trees.
migrated=(
  np_target_facts np_diagnostics_sink np_diagnostics_enhanced
  np_lexer np_green_tree np_preprocessor np_ast_facade
  np_error_recovery
  np_diagnostics_json
)
for name in "${migrated[@]}"; do
  hits=$(grep -rl "\b${name}\b" compiler tools tests --include='*.pas' \
    --include='*.inc' --include='*.lpr' 2>/dev/null | wc -l)
  if [ "$hits" -ne 0 ]; then
    echo "FAIL: stale references to ${name}: ${hits} file(s)"
    fail=1
  fi
done

# 2. json_helpers split: stage0 keeps the local twin, compiler side is dotted.
if grep -rq 'nextpas_json_helpers' compiler --include='*.pas' 2>/dev/null; then
  echo "FAIL: compiler tree must use nextpas.compiler.diagnostics.json_helpers"
  fail=1
fi

# 3. Forbidden core families in the compiler dependency graph.
#    Strip single-quoted string literals first so runtime unit-name checks
#    (e.g. Pos('nextpas.core.crypto', ...)) are not false positives.
forbidden='nextpas\.core\.(tls|http|tui|net|crypto|yaml|toml|sqlite|regex|xml)\b'
hits=$(for d in compiler/src compiler/frontend compiler/syntax compiler/sema \
  compiler/lower compiler/ir compiler/backend compiler/toolchain \
  compiler/diagnostics compiler/targets; do
    find "$d" -name '*.pas' -o -name '*.inc' 2>/dev/null
  done | xargs -r sed "s/'[^']*'//g" | grep -cE "${forbidden}")
if [ "$hits" -ne 0 ]; then
  echo "FAIL: forbidden core family imports in compiler graph: ${hits} line(s)"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "compiler-flat-contract=pass"
fi
exit "$fail"
