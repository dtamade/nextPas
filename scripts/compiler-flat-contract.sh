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
  np_error_recovery np_diagnostics_json
  np_source_database np_unit_graph np_unit_resolver
  np_compilation_session np_workspace_model np_symbol_cache
  np_query_database np_package_manifest np_package_lock
  np_package_workflow np_incremental_cache np_file_change_detector
  np_parallel_scheduler np_compiler_phase
  np_semantic_model np_semantic_analyzer np_sema_type_check
  np_sema_overload np_sema_builtins np_sema_name_set
  np_sema_runtime_vars np_sema_string_ownership
  np_semantic_field_meta_vec np_semantic_interface_slot_vec
  np_semantic_property_meta_vec np_semantic_vmt_slot_vec
  np_hir_lowering
  np_hir_types np_hir_model np_hir_builder np_hir_printer
  np_hir_verifier np_hir_to_mir np_hir_llvm_emitter
  np_system_contracts np_mir_model np_mir_optimize np_mir_opt_level
  np_mir_pass_registry np_mir_pass_constfold np_mir_pass_cse
  np_mir_pass_dce np_mir_pass_deadarg np_mir_pass_devirt
  np_mir_pass_escape np_mir_pass_inline_heuristic np_mir_pass_inline
  np_mir_pass_licm np_mir_pass_strength_red np_mir_pass_tailcall
  np_mir_pass_vectorize np_mir_to_llvm np_backend_plan
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

# 轴 B/C I/O 族显式例外（一行一单元；理由见 docs/plans/compiler-modernization-refactor.md R9/§3）：
# - syntax.preprocessor: include 解析需读源文件（N2 登记）
# - sema.analyzer: 播种期对导入单元源文件做 FsExists/FsStat 新鲜度检查（N4 登记，收口归 N7 评估）
# - backend.plan: 规划期 FsDir 目录探测（N5 登记，收口归 N7/P2 评估）
io_exempt="nextpas.compiler.syntax.preprocessor
nextpas.compiler.sema.analyzer
nextpas.compiler.backend.plan"

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
          # R9 结构债(N7 手术清单)：typed-HIR/MIR 所有权迁出 sema/frontend 前
          # 的已知上行边（N4/N5 逐条登记）
          case "$unit|$dep" in
            nextpas.compiler.sema.analyzer|nextpas.compiler.ir*|\
            nextpas.compiler.sema.string_ownership|nextpas.compiler.ir*|\
            nextpas.compiler.sema.semantic_model|nextpas.compiler.ir*|\
            nextpas.compiler.frontend.compilation_session|nextpas.compiler.ir*|\
            nextpas.compiler.frontend.compilation_session|nextpas.compiler.backend*) ;;
            *)
              echo "FAIL(layer-A): $unit($ulayer) -> $dep($dlayer) upward"
              fail=1
              ;;
          esac
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
