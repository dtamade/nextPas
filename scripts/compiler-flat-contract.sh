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

# 4. Layering contract for migrated units in compiler/src (R8, plan §支柱三).
#    Axis A: compiler-internal order — a unit may only use lower-or-equal
#            compiler layers (0 base/diagnostics/targets, 1 syntax,
#            2 frontend/sema, 3 ir/backend, 4 toolchain).
#    Axis B/C: core capability ceiling — L2 I/O-capable core families
#            (fs/json/io/process/encoding/compress) require the area to be
#            registered I/O-capable (frontend) or an explicit per-unit
#            exception below.
layer_of() {
  case "$1" in
    nextpas.compiler.base.*|nextpas.compiler.diagnostics.*|nextpas.compiler.targets.*) echo 0 ;;
    nextpas.compiler.syntax.*) echo 1 ;;
    nextpas.compiler.frontend.*|nextpas.compiler.sema.*) echo 2 ;;
    nextpas.compiler.ir.*|nextpas.compiler.backend.*) echo 3 ;;
    nextpas.compiler.toolchain.*) echo 4 ;;
    *) echo -1 ;;
  esac
}

io_exempt="nextpas.compiler.syntax.preprocessor"

for f in compiler/src/*.pas; do
  unit=$(grep -m1 '^unit ' "$f" | sed 's/^unit \([a-z_.]*\);.*/\1/')
  [ -z "$unit" ] && continue
  ulayer=$(layer_of "$unit")
  deps=$(sed "s/'[^']*'//g" "$f" | tr '\n' ' ' \
    | grep -o 'nextpas\.compiler\.[a-z_]*\|nextpas\.core\.[a-z_]*' | sort -u)
  for dep in $deps; do
    case "$dep" in
      nextpas.compiler.*)
        dlayer=$(layer_of "$dep")
        if [ "$dlayer" -ge 0 ] && [ "$dlayer" -gt "$ulayer" ]; then
          echo "FAIL(layer-A): $unit($ulayer) -> $dep($dlayer) upward"
          fail=1
        fi
        ;;
      nextpas.core.*)
        family=${dep#nextpas.core.}
        case "$family" in
          fs|json|io|process|encoding|compress)
            if ! printf '%s\n' "$io_exempt" | grep -qx "$unit" \
               && ! printf '%s' "$unit" | grep -q 'frontend\.'; then
              echo "FAIL(layer-C): $unit uses I/O-capable core.$family without registration"
              fail=1
            fi
            ;;
        esac
        ;;
    esac
  done
done

if [ "$fail" -eq 0 ]; then
  echo "compiler-flat-contract=pass"
fi
exit "$fail"
