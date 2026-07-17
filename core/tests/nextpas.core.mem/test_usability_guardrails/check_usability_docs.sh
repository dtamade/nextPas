#!/usr/bin/env bash
# Source-contract: dual-track and ERROR-POLICY stay documented correctly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
MEM_DOCS="$ROOT/core/docs/mem"
FAIL=0

die() {
  echo "usability-docs FAIL: $*" >&2
  FAIL=1
}

need_file() {
  local f="$1"
  [[ -f "$f" ]] || die "missing $f"
}

need_grep() {
  local f="$1"
  local pat="$2"
  local msg="$3"
  if ! grep -Eq "$pat" "$f"; then
    die "$msg ($f ~ /$pat/)"
  fi
}

forbid_grep() {
  local f="$1"
  local pat="$2"
  local msg="$3"
  if grep -Eq "$pat" "$f"; then
    die "$msg ($f ~ /$pat/)"
  fi
}

need_file "$MEM_DOCS/README.md"
need_file "$MEM_DOCS/API-GUIDE.md"
need_file "$MEM_DOCS/ERROR-POLICY.md"
need_file "$MEM_DOCS/CONTRACT.md"

# README dual-track + anti-patterns
need_grep "$MEM_DOCS/README.md" 'DefaultHeap' 'README must document DefaultHeap'
need_grep "$MEM_DOCS/README.md" 'DefaultAllocator' 'README must document DefaultAllocator'
need_grep "$MEM_DOCS/README.md" '错误用法' 'README must keep 错误用法 section'
need_grep "$MEM_DOCS/README.md" 'NEXTPAS_MEM_DEBUG' 'README must document DEBUG env'
need_grep "$MEM_DOCS/README.md" 'test_usability_guardrails' 'README must link usability gate'
need_grep "$MEM_DOCS/README.md" 'ERROR-POLICY' 'README must link ERROR-POLICY'
need_grep "$MEM_DOCS/README.md" '同.*进程堆|同一进程堆' 'README must state S5 same process heap'
need_grep "$MEM_DOCS/README.md" 'GetRtlAllocator' 'README must mention explicit RTL opt-in'

# Usability score authority (current headline score; no plus-chain inflation)
need_file "$MEM_DOCS/USABILITY-SCORE.md"
need_grep "$MEM_DOCS/USABILITY-SCORE.md" '10\.0|9\.[0-9]' 'USABILITY-SCORE must publish current score'
forbid_grep "$MEM_DOCS/USABILITY-SCORE.md" '10\.0\+{2,}|9\.[0-9]\+{2,}' \
  'USABILITY-SCORE must not use ++++ score inflation'
need_file "$MEM_DOCS/FACADES-SURFACE.md"
need_grep "$MEM_DOCS/FACADES-SURFACE.md" 'Tier-3|Experimental' \
  'FACADES-SURFACE must define Tier-3 freeze'
need_grep "$MEM_DOCS/README.md" 'FACADES-SURFACE' 'README must link FACADES-SURFACE'
need_grep "$MEM_DOCS/ERROR-POLICY.md" 'FormatAllocErrorMsg' \
  'ERROR-POLICY must document FormatAllocErrorMsg'
need_grep "$MEM_DOCS/ERROR-POLICY.md" 'NEXTPAS_MEM_HEAP_SAFETY|HEAP_SAFETY' \
  'ERROR-POLICY must document HEAP_SAFETY'
need_grep "$MEM_DOCS/ERROR-POLICY.md" 'ARENA_STRICT' \
  'ERROR-POLICY must document ARENA_STRICT'
need_grep "$MEM_DOCS/ERROR-POLICY.md" 'ENextPasError|统一 catch' \
  'ERROR-POLICY must document unified catch surface'
need_grep "$MEM_DOCS/README.md" 'debug_coverage_gap' \
  'README must document debug_coverage_gap'
need_grep "$MEM_DOCS/README.md" 'NEXTPAS_MEM_HEAP_SAFETY|HEAP_SAFETY' \
  'README must document HEAP_SAFETY'
need_grep "$MEM_DOCS/API-GUIDE.md" 'FreeMemOf' 'API-GUIDE must document FreeMemOf'
need_grep "$MEM_DOCS/API-GUIDE.md" 'debug_coverage_gap|DebugCoverageGap' \
  'API-GUIDE must document coverage gap'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function FreeMemOf|procedure FreeMemOf' \
  'mem facade must expose FreeMemOf'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function FormatAllocErrorMsg' \
  'mem facade must expose FormatAllocErrorMsg'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function IsMemHeapSafetyEnabled' \
  'mem facade must expose IsMemHeapSafetyEnabled'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function IsMemArenaStrictEnabled' \
  'mem facade must expose IsMemArenaStrictEnabled'
need_grep "$ROOT/core/src/nextpas.core.mem.default.pas" 'debug_coverage_gap=' \
  'FormatMemStats must emit debug_coverage_gap'
need_grep "$ROOT/core/src/nextpas.core.mem.default.pas" 'debug_process=' \
  'FormatMemStats must emit debug_process'
need_grep "$ROOT/core/src/nextpas.core.mem.default.pas" 'heap_safety=' \
  'FormatMemStats must emit heap_safety'
need_grep "$ROOT/core/src/nextpas.core.mem.default.pas" 'arena_strict=' \
  'FormatMemStats must emit arena_strict'
need_grep "$ROOT/core/src/nextpas.core.mem.default.pas" 'function FormatMemDebugProfile' \
  'default must expose FormatMemDebugProfile'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function ReallocMemOf|function TryReallocMemOf' \
  'mem facade must expose ReallocMemOf'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'TestReallocMemOf|ReallocMemOf' \
  'usability guardrails must lock ReallocMemOf'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'TestTryReallocMemOfNilAllocatorGetMem' \
  'usability guardrails must lock TryReallocMemOf nil-allocator symmetry (S1)'
need_grep "$ROOT/core/src/nextpas.core.mem.error.pas" \
  'SanitizeRuntimeAlignment' \
  'error.pas SanitizeRuntimeAlignment must remain (S2 surface)'
need_grep "$ROOT/core/src/nextpas.core.mem.error.pas" \
  "FormatAllocErrorMsg\\('SanitizeRuntimeAlignment'" \
  'error.pas alignment raises must use FormatAllocErrorMsg (S2)'
need_grep "$ROOT/core/src/nextpas.core.mem.error.pas" \
  "FormatAllocErrorMsg\\('SanitizeConfigAlignment'" \
  'error.pas config alignment raises must use FormatAllocErrorMsg (S2)'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" \
  'aeInvalidLayout' \
  'AllocArray overflow must use aeInvalidLayout (T2)'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" \
  'ResolveAllocator\(AAllocator\)' \
  'AllocZeroed/AllocArray must ResolveAllocator nil (T3)'
need_grep "$ROOT/core/src/nextpas.core.mem.allocator.arena.pas" \
  "FormatAllocErrorMsg\\('TLocalArenaAllocator', 'ReallocMem'" \
  'arena ReallocMem must use FormatAllocErrorMsg (T1)'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'TestAllocArrayOverflowIsInvalidLayout|TestAllocZeroedAllocArrayNilAllocator' \
  'usability guardrails must lock T2/T3'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'heap_safety=y|TestFormatMemStatsSafety' \
  'usability guardrails must lock heap_safety in FormatMemStats'
need_grep "$MEM_DOCS/API-GUIDE.md" 'ReallocMemOf|FormatMemDebugProfile' \
  'API-GUIDE must document ReallocMemOf or FormatMemDebugProfile'
need_grep "$MEM_DOCS/USABILITY-EVAL-2026-07-17.md" 'R1|R3' \
  'fresh eval report must list residual findings'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'TestHeapSafetyOptInTracksProcessGetMem|HEAP_SAFETY' \
  'usability guardrails must lock HEAP_SAFETY process track'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'TestFreeMemOfSizedSameHeap|FreeMemOf' \
  'usability guardrails must lock FreeMemOf'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'TestArenaStrictFreeMem|ARENA_STRICT' \
  'usability guardrails must lock ARENA_STRICT dual-mode'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'debug_coverage_gap' \
  'usability guardrails must lock debug_coverage_gap'
forbid_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'Check\(True,' \
  'usability guardrails must not use empty Check(True,...) assertions'
# F6: facade must not re-export Tier-3 experimental allocators
for tier3 in prediction numa replay huge_page watermark sliding thread_cache \
  mapped_file arena2 arena_group bitmap bump cascade coalesce compact cow dual \
  freelist group page pool2 prefix size_class slab stack; do
  forbid_grep "$ROOT/core/src/nextpas.core.mem.pas" \
    "nextpas\\.core\\.mem\\.allocator\\.${tier3}" \
    "mem facade must not uses Tier-3 allocator.${tier3}"
done
need_grep "$MEM_DOCS/USABILITY-SCORE.md" 'GetGrowingIAllocator|Growing IAllocator' 'USABILITY-SCORE must cover S5 root'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" 'HEAP_DEBUG|NEXTPAS_MEM_HEAP_DEBUG' 'USABILITY-SCORE must cover HEAP_DEBUG opt-in'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" 'TryBlockSize|SC8' 'USABILITY-SCORE must cover TryBlockSize/SC8'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" 'SC9' 'USABILITY-SCORE must cover SC9 dual-track'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" 'TryFreeMemOf|U1' 'USABILITY-SCORE must cover TryFreeMemOf/U1 residual'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" 'CLOSED' 'USABILITY-SCORE must mark usability mainline CLOSED'
need_grep "$MEM_DOCS/API-GUIDE.md" 'TryFreeMemOf\(nil' 'API-GUIDE must document TryFreeMemOf nil+owned'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" 'WithRequestArena|HttpRequestAllocatorOf|HttpFormatProcessMemStats' \
  'USABILITY-SCORE must cover product wires'
need_grep "$MEM_DOCS/README.md" 'SC9' 'README must cite SC9 dual-track evidence'
need_grep "$MEM_DOCS/CONTRACT.md" '同堆互释|same.heap|SC9' 'CONTRACT must document same-heap / SC9'
need_grep "$MEM_DOCS/CONTRACT.md" 'GetGrowingIAllocator|Growing IAllocator' 'CONTRACT must document Growing IAllocator root'
need_grep "$MEM_DOCS/CONTRACT.md" 'TryBlockSize' 'CONTRACT must document process TryBlockSize'
need_grep "$MEM_DOCS/README.md" 'NEXTPAS_MEM_HEAP_DEBUG' 'README must document HEAP_DEBUG'
need_grep "$MEM_DOCS/README.md" 'TryBlockSize' 'README must document TryBlockSize'
need_grep "$MEM_DOCS/README.md" 'RequestArenaMiddleware' 'README must document RequestArenaMiddleware'
need_grep "$MEM_DOCS/README.md" 'CreateArenaAllocator' 'README must document CreateArenaAllocator'
need_grep "$MEM_DOCS/README.md" 'CreateVirtualArenaAllocator' 'README must document CreateVirtualArenaAllocator'
need_grep "$MEM_DOCS/API-GUIDE.md" 'NEXTPAS_MEM_HEAP_DEBUG' 'API-GUIDE must document HEAP_DEBUG opt-in'
need_grep "$MEM_DOCS/API-GUIDE.md" 'TryBlockSize' 'API-GUIDE must document TryBlockSize recovery'
need_grep "$MEM_DOCS/API-GUIDE.md" 'CreateArenaAllocator' 'API-GUIDE must document CreateArenaAllocator capacity contract'
need_grep "$MEM_DOCS/API-GUIDE.md" 'CreateVirtualArenaAllocator' 'API-GUIDE must document VirtualArena factory'
need_grep "$MEM_DOCS/API-GUIDE.md" 'RequestArenaMiddleware' 'API-GUIDE must document RequestArenaMiddleware'
need_grep "$MEM_DOCS/API-GUIDE.md" 'HttpUseRequestArena' 'API-GUIDE must document HttpUseRequestArena'
need_grep "$MEM_DOCS/README.md" 'HttpUseRequestArena' 'README must document HttpUseRequestArena'
need_grep "$MEM_DOCS/README.md" 'TCompilerUnitScope|FormatMemStats' 'README must document compiler scope or FormatMemStats'
need_grep "$MEM_DOCS/API-GUIDE.md" 'TCompilerUnitScope' 'API-GUIDE must document TCompilerUnitScope'
need_grep "$MEM_DOCS/API-GUIDE.md" 'FormatMemStats' 'API-GUIDE must document FormatMemStats'
need_grep "$MEM_DOCS/README.md" 'FormatMemStats' 'README must document FormatMemStats'

# Compiler product example
COMPILER_EX="$ROOT/core/examples/nextpas.core.compiler/unit_arena_demo/unit_arena_demo.lpr"
need_file "$COMPILER_EX"
need_grep "$COMPILER_EX" 'TCompilerUnitScope|TCompilerSessionScope' \
  'compiler example must use UnitScope or SessionScope'
need_grep "$COMPILER_EX" 'BeginScope|EndScope|BeginSession|EndSession' \
  'compiler example must pair scope begin/end'
need_grep "$ROOT/core/src/nextpas.core.compiler.mem.pas" 'TCompilerUnitScope' \
  'compiler.mem must expose TCompilerUnitScope'
need_grep "$ROOT/core/src/nextpas.core.compiler.mem.pas" 'TCompilerSessionScope' \
  'compiler.mem must expose TCompilerSessionScope'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function FormatMemStats' \
  'mem facade must expose FormatMemStats'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function IsMemHeapDebugEnabled' \
  'mem facade must expose IsMemHeapDebugEnabled for HEAP_DEBUG discoverability'
need_grep "$ROOT/core/src/nextpas.core.mem.default.pas" \
  'debug_allocs=|debug_frees=' \
  'FormatMemStats must emit debug_allocs/debug_frees when DEBUG wrap is built'
need_grep "$ROOT/core/tests/nextpas.core.mem/test_usability_guardrails/test_usability_guardrails.lpr" \
  'TestFormatMemStatsPluginTrack|TestFormatMemStatsHeapDebugProcessTrack' \
  'usability guardrails must lock FormatMemStats plugin vs HEAP_DEBUG process tracks'
need_grep "$MEM_DOCS/DEBUG-WRAP-DESIGN.md" 'NEXTPAS_MEM_HEAP_DEBUG' \
  'DEBUG-WRAP-DESIGN must document HEAP_DEBUG as implemented'

# Product example wire (hello server must use middleware path, not only manual create)
HELLO_EX="$ROOT/core/examples/nextpas.core.http/http_hello_server/hello_http_server.lpr"
need_file "$HELLO_EX"
need_grep "$HELLO_EX" 'WithRequestArena|NewHttpServerWithRequestArena|HttpWithRequestArena|HttpUseRequestArena|RequestArenaMiddleware' \
  'hello example must mount request arena product path'
need_grep "$HELLO_EX" 'HttpRequestArenaOf' \
  'hello example must consume HttpRequestArenaOf'

# Facade helper exists
need_file "$ROOT/core/src/nextpas.core.http.pas"
need_grep "$ROOT/core/src/nextpas.core.http.pas" 'procedure HttpUseRequestArena' \
  'http facade must expose HttpUseRequestArena'
need_grep "$ROOT/core/src/nextpas.core.http.pas" 'function HttpWithRequestArena' \
  'http facade must expose HttpWithRequestArena'
need_grep "$ROOT/core/src/nextpas.core.http.pas" 'function NewHttpServerWithRequestArena' \
  'http facade must expose NewHttpServerWithRequestArena'
need_grep "$ROOT/core/src/nextpas.core.http.pas" 'function HttpFormatProcessMemStats' \
  'http facade must expose HttpFormatProcessMemStats'
need_grep "$ROOT/core/examples/nextpas.core.http/http_hello_server/hello_http_server.lpr" \
  'WithRequestArena' 'hello must use options carrier RequestArena'
need_grep "$ROOT/core/src/nextpas.core.http.base.pas" 'function WithRequestArena' \
  'THttpServerOptions must expose WithRequestArena'
need_grep "$ROOT/core/src/nextpas.core.http.server.pas" 'HttpWithRequestArena|RequestArena' \
  'http.server must honor RequestArena options wire'
need_grep "$ROOT/core/src/nextpas.core.http.impl.h1.pas" 'InvokeHandler|HttpAttachRequestArena' \
  'H1 must wire connection-scoped RequestArena attach path'
need_grep "$ROOT/core/src/nextpas.core.http.impl.h2.session.pas" 'InvokeHandler|HttpAttachRequestArena' \
  'H2 must wire connection-scoped RequestArena attach path'
need_grep "$ROOT/core/src/nextpas.core.http.impl.h2.types.pas" 'RequestArena' \
  'H2 transport options must expose RequestArena'
need_grep "$ROOT/core/src/nextpas.core.http.impl.registry.pas" 'RequestArena' \
  'registry must pass RequestArena to H1/H2 transport'
need_grep "$ROOT/compiler/frontend/np_compilation_session.pas" 'TCompilerSessionScope|nextpas.core.compiler.mem' \
  'TCompilationSession must wire compiler.mem session scope'
need_grep "$ROOT/compiler/frontend/np_compilation_session.pas" 'MemScopeActive|MemAlloc' \
  'TCompilationSession must expose mem scope accessors'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" 'UnitBegin' \
  'pipeline must call UnitBegin on mem scope phases'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" 'MemAlloc' \
  'pipeline must use MemAlloc for phase scratch'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" 'UnitEnd' \
  'pipeline must call UnitEnd after phase scratch'
need_grep "$ROOT/compiler/frontend/np_compilation_session.pas" 'MemUnitCount|MemSessionPeak' \
  'TCompilationSession must expose unit/peak mem diagnostics'
need_grep "$ROOT/compiler/frontend/np_compilation_session.pas" 'FAstAllocator|MemAstAllocator' \
  'TCompilationSession must own AST IAllocator'
need_grep "$ROOT/compiler/frontend/np_compilation_session.pas" 'FScratchAllocator|MemScratchAllocator' \
  'TCompilationSession must own phase scratch IAllocator'
need_grep "$ROOT/compiler/frontend/np_compilation_session.pas" 'MemFormatSessionStats' \
  'TCompilationSession must expose MemFormatSessionStats'
need_grep "$ROOT/tools/stage0/nextpas_projection_types.pas" \
  'MemSessionStats: string' \
  'session projection must carry MemSessionStats for ops'
need_grep "$ROOT/tools/stage0/nextpas_projection_context.pas" \
  'MemSessionStats := Session\.MemFormatSessionStats' \
  'CaptureSessionProjection must wire MemFormatSessionStats into ops projection'
need_grep "$ROOT/tools/stage0/nextpas_projection_text.pas" \
  'mem-session-stats' \
  'ops text projection must print mem-session-stats'
need_grep "$ROOT/tools/stage0/nextpas_projection_types.pas" \
  'MemProcessStats: string' \
  'doctor projection must carry MemProcessStats for process heap ops'
need_grep "$ROOT/tools/stage0/nextpas_projection_context.pas" \
  'MemProcessStats := FormatMemStats' \
  'doctor capture must fill MemProcessStats from FormatMemStats'
need_grep "$ROOT/tools/stage0/nextpas_projection_text.pas" \
  'mem-process-stats' \
  'doctor text projection must print mem-process-stats'
need_grep "$ROOT/core/src/nextpas.core.compiler.mem.pas" \
  'function FormatStats: string' \
  'TCompilerUnitScope/SessionScope must expose FormatStats one-line diagnostics'
need_grep "$ROOT/core/src/nextpas.core.compiler.mem.pas" \
  'function CompilerFormatSessionStats|function CompilerFormatUnitStats' \
  'compiler.mem must expose discoverable CompilerFormat*Stats aliases'
need_grep "$ROOT/compiler/frontend/np_compilation_session_helpers.inc" \
  'FMemScope\.FormatStats' \
  'MemFormatSessionStats must reuse TCompilerSessionScope.FormatStats core line'
# Arena dual-track contracts (AST vs scratch vs Detach default-heap).
need_grep "$ROOT/compiler/frontend/np_compilation_session.pas" \
  'Not reset by UnitBegin' \
  'FAstAllocator comment must state Not reset by UnitBegin'
need_grep "$ROOT/compiler/frontend/np_compilation_session_helpers.inc" \
  'procedure TCompilationSession\.ResetScratchAllocator' \
  'session must expose ResetScratchAllocator for phase bulk reclaim'
need_grep "$ROOT/compiler/frontend/np_compilation_session_helpers.inc" \
  'FScratchAllocator as TVirtualArenaAllocator\)\.Reset' \
  'ResetScratchAllocator must Reset only FScratchAllocator'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" \
  'FAstAllocator as TVirtualArenaAllocator\)\.Reset' \
  'ResetSyntaxState must Reset FAstAllocator after trees freed'
need_grep "$ROOT/compiler/frontend/np_compilation_session_helpers.inc" \
  'FAstAllocator := CompilerCreateUnitAllocator' \
  'CreateBuildSession must own AST VirtualArena IAllocator'
need_grep "$ROOT/compiler/frontend/np_compilation_session_helpers.inc" \
  'FScratchAllocator := CompilerCreateUnitAllocator' \
  'CreateBuildSession must own scratch VirtualArena IAllocator'
need_grep "$ROOT/core/tests/nextpas.core.compiler/test_compiler_mem/test_compiler_mem.lpr" \
  'TestAstIndependentOfScratchReset|AST independent of scratch' \
  'compiler.mem tests must lock AST vs scratch independence'
need_grep "$ROOT/core/tests/nextpas.core.compiler/test_compiler_mem/test_compiler_mem.lpr" \
  'TestUnitBeginPreservesSessionPeak|UnitBegin preserves SessionPeak' \
  'compiler.mem tests must lock SessionPeak across UnitBegin'
need_grep "$ROOT/core/tests/nextpas.core.compiler/test_compiler_mem/test_compiler_mem.lpr" \
  'TestArenaFreeMemNoOpUntilReset|FreeMem no-op' \
  'compiler.mem tests must lock arena FreeMem no-op until Reset'
need_grep "$ROOT/core/tests/nextpas.core.compiler/test_compiler_mem/test_compiler_mem.lpr" \
  'TestEntryOwnedNestedSurvivesScratchReset|entry-owned nested survives' \
  'compiler.mem tests must lock entry-owned nested default-heap vs scratch'
need_grep "$MEM_DOCS/API-GUIDE.md" \
  'FormatStats|CompilerFormatSessionStats' \
  'API-GUIDE must document compiler session FormatStats diagnostics'
need_grep "$MEM_DOCS/README.md" \
  'FormatStats|CompilerFormatSessionStats' \
  'README must document compiler session FormatStats diagnostics'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" 'ParseGreenTree' \
  'pipeline must ParseGreenTree with session AST allocator'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" 'FScratchAllocator' \
  'pipeline must pass FScratchAllocator to resolver/sema'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" 'FAllocator|AAllocator' \
  'TSemanticAnalyzer must accept scratch IAllocator'
need_grep "$ROOT/compiler/sema/np_sema_analyzer_types.inc" \
  'FGenericWorkQueue: TLongIntVec|FCompilerProcNames: TStringVec' \
  'sema generic work queue and compiler-proc names must be TVec on scratch'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" \
  'FGenericWorkQueue := specialize TVec|FCompilerProcNames := specialize TVec' \
  'sema must construct generic work queue and compiler-proc name TVecs'
need_grep "$ROOT/compiler/sema/np_sema_analyzer_types.inc" \
  'FImportedUnitTrees: TSemaImportedTreeVec|FImportedUnitOwners: TSemaImportedOwnerVec' \
  'sema imported unit tables must be TVec on scratch'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" \
  'FImportedUnitOwners := TSemaImportedOwnerVec|FImportedUnitTrees := TSemaImportedTreeVec' \
  'sema must construct imported unit owner/tree TVecs'
need_grep "$ROOT/compiler/sema/np_sema_overload.pas" \
  'TSemaImportedOwnerVec|TSemaImportedTreeVec' \
  'overload contexts must share imported unit TVec types'
need_grep "$ROOT/compiler/sema/np_sema_analyzer_types.inc" \
  'FPendingSignatures: TPendingSignatureVec|TPendingSignatureVec' \
  'sema pending signatures must be TVec on scratch'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" \
  'FPendingSignatures := TPendingSignatureVec' \
  'sema must construct pending signature TVec'
need_grep "$ROOT/compiler/sema/np_sema_analyzer_types.inc" \
  'ParamNames: TStringVec|ArgTypes: TStringVec' \
  'pending-signature nested ParamNames/ArgTypes must use TStringVec'
need_grep "$ROOT/compiler/sema/np_sema_declaration.inc" \
  'ClonePendingStringVec|FreePendingSignatureNested|ParamNames\.ToArray' \
  'pending signatures must clone/free nested ParamNames/ArgTypes TVec'
need_grep "$ROOT/compiler/sema/np_sema_string_ownership_helpers.inc" \
  'ParamNames\.Free|ArgTypes\.Free' \
  'sema Destroy must Free nested pending-signature ParamNames/ArgTypes'
need_grep "$ROOT/compiler/sema/np_sema_analyzer_types.inc" \
  'FProcedureBodies: TProcedureBodyVec' \
  'sema procedure bodies must be TVec on scratch'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" \
  'FProcedureBodies := TProcedureBodyVec' \
  'sema must construct procedure body TVec'
need_grep "$ROOT/compiler/sema/np_sema_overload.pas" \
  'TProcedureBodyVec = specialize TVec' \
  'procedure body vec type must live in overload module for context borrow'
need_grep "$ROOT/compiler/sema/np_sema_string_ownership.pas" \
  'ProcedureBodies: TProcedureBodyVec' \
  'ownership context must borrow procedure body TVec'
need_grep "$ROOT/compiler/lower/np_hir_lowering.pas" \
  'ProcedureBodies: TProcedureBodyVec' \
  'HIR lowering context must borrow procedure body TVec'
need_grep "$ROOT/compiler/sema/np_sema_runtime_vars.pas" \
  'AAllocator|FAllocator|TStringVec' \
  'TSemaRuntimeVarRegistry must accept optional IAllocator for name TVecs'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" \
  'TSemaRuntimeVarRegistry.Create\(FAllocator\)' \
  'analyzer must pass FAllocator to runtime var registry'
need_grep "$ROOT/compiler/ir/np_mir_optimize.pas" \
  'AAllocator|FAllocator|TMirPassVec' \
  'TMirPassManager must accept optional phase IAllocator for pass registry'
need_grep "$ROOT/compiler/backend/np_backend_plan.pas" \
  'TMirPassManager.Create\(PhaseScratch\)' \
  'backend MIR path must pass PhaseScratch to TMirPassManager'
need_grep "$ROOT/compiler/ir/np_mir_pass_dce.pas" \
  'AAllocator|FAllocator|TMirBoolVec' \
  'TMirDcePass must accept optional IAllocator for UsedRegs TVec'
need_grep "$ROOT/compiler/ir/np_mir_pass_cse.pas" \
  'AAllocator|FAllocator|TMirCseEntryVec' \
  'TMirCsePass must accept optional IAllocator for CseTable TVec'
need_grep "$ROOT/compiler/ir/np_mir_opt_level.pas" \
  'TMirCsePass.Create\(AManager.Allocator\)|TMirDcePass.Create\(AManager.Allocator\)' \
  'opt-level registration must pass manager Allocator to CSE/DCE'
need_grep "$ROOT/compiler/ir/np_mir_pass_deadarg.pas" \
  'AAllocator|FAllocator|TMirBoolVec|TMirParamVec' \
  'TMirDeadArgPass must accept optional IAllocator for work TVecs'
need_grep "$ROOT/compiler/ir/np_mir_pass_escape.pas" \
  'AAllocator|FAllocator|TMirEscapeMapVec' \
  'TMirEscapePass must accept optional IAllocator for EscapeMap TVec'
need_grep "$ROOT/compiler/ir/np_mir_pass_licm.pas" \
  'AAllocator|FAllocator|TMirBlockIdVec' \
  'TMirLicmPass must accept optional IAllocator for LoopBlocks TVec'
need_grep "$ROOT/compiler/ir/np_mir_pass_inline.pas" \
  'AAllocator|FAllocator|TMirValueRemapVec|TMirStmtVec' \
  'TMirInlinePass must accept optional IAllocator for remap/stmt TVecs'
need_grep "$ROOT/compiler/ir/np_mir_opt_level.pas" \
  'TMirInlinePass.Create\(AManager.Allocator\)|TMirDeadArgPass.Create\(AManager.Allocator\)|TMirLicmPass.Create\(AManager.Allocator\)|TMirEscapePass.Create\(AManager.Allocator\)' \
  'opt-level registration must pass manager Allocator to inline/deadarg/licm/escape'
need_grep "$ROOT/compiler/frontend/np_unit_resolver.pas" 'FNodeAllocator|ANodeAllocator' \
  'TUnitResolver must accept node IAllocator for dep trees'
need_grep "$ROOT/compiler/frontend/np_unit_resolver.pas" 'TResolutionStackVec|FResolutionStack: TResolutionStackVec' \
  'TUnitResolver resolution stack must use TVec on node allocator'
need_grep "$ROOT/compiler/frontend/np_unit_graph.pas" \
  'AAllocator|TResolvedUnitVec|TUnitGraphEdgeVec|FResolvedUnits: TResolvedUnitVec' \
  'TUnitGraph must accept optional IAllocator for resolved units/edges TVecs'
need_grep "$ROOT/compiler/frontend/np_unit_resolver_helpers.inc" \
  'TUnitGraph\.Create;' \
  'TUnitGraph Detach product must default-heap Create (outlives ResetScratch)'
forbid_grep "$ROOT/compiler/frontend/np_unit_resolver_helpers.inc" \
  'TUnitGraph\.Create\(FNodeAllocator\)' \
  'TUnitGraph must not allocate on phase FNodeAllocator after Detach'
need_grep "$ROOT/compiler/frontend/np_unit_graph.pas" \
  'TSearchPathEntryVec|FEntries: TSearchPathEntryVec|Create\(AAllocator' \
  'TSearchPathSet must accept optional IAllocator for path entry TVec'
need_grep "$ROOT/compiler/frontend/np_unit_resolver_helpers.inc" \
  'TSearchPathSet\.Create;' \
  'TSearchPathSet Detach product must default-heap Create (outlives ResetScratch)'
forbid_grep "$ROOT/compiler/frontend/np_unit_resolver_helpers.inc" \
  'TSearchPathSet\.Create\(FNodeAllocator\)' \
  'TSearchPathSet must not allocate on phase FNodeAllocator after Detach'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" \
  'Unit graph|Search path|Detach' \
  'USABILITY-SCORE must document unit graph/search paths as session-long after Detach'
need_grep "$ROOT/compiler/frontend/np_unit_resolver.pas" \
  'TRootSearchIndexVec|FRootIndexes: TRootSearchIndexVec|TSearchIndexEntryVec' \
  'TUnitResolver root indexes must use TVec on node allocator'
need_grep "$ROOT/compiler/frontend/np_unit_resolver.pas" \
  'CandidatePaths: TUnitResolverStringVec' \
  'unit resolver search-index nested CandidatePaths must use TUnitResolverStringVec'
need_grep "$ROOT/compiler/frontend/np_unit_resolver_helpers.inc" \
  'FreeSearchIndexEntriesNested|CreateCandidatePathVec|Paths\.ToArray|CandidatePaths\.Push' \
  'unit resolver must clone/free nested CandidatePaths TVec and ToArray at API boundary'
need_grep "$ROOT/compiler/syntax/np_preprocessor.pas" \
  'TIncludePathVec|FSearchPaths: TIncludePathVec|Create\(const ABaseDir: string; AAllocator' \
  'TFileIncludeResolver must accept optional IAllocator for search-path TVec'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" \
  'TFileIncludeResolver.Create\(SourceDir, FScratchAllocator\)' \
  'AnalyzeSyntax must pass FScratchAllocator to TFileIncludeResolver'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" '故意默认堆' \
  'USABILITY-SCORE must document intentional default-heap compiler storage'
need_grep "$ROOT/compiler/ir/np_hir_verifier.pas" 'AAllocator|FAllocator|THirVerifyErrorVec' \
  'THIRVerifier must accept optional IAllocator for error/work TVecs'
need_grep "$ROOT/compiler/sema/np_sema_validation.inc" \
  'specialize TVec|FAllocator|CandidateNames|SeenValues' \
  'sema validation work tables must use TVec on FAllocator'
need_grep "$ROOT/compiler/syntax/np_preprocessor.pas" \
  'AAllocator|TTokenVec|TConditionalFrameVec|FOutputTokens: TTokenVec' \
  'TPreprocessor must accept optional IAllocator for stack/token TVecs'
need_grep "$ROOT/compiler/syntax/np_preprocessor.pas" \
  'TDefineEntryVec|FEntries: TDefineEntryVec|Create\(AAllocator' \
  'TDefineTable must accept optional IAllocator for define entry TVec'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" \
  'TDefineTable.Create\(FScratchAllocator\)' \
  'AnalyzeSyntax must pass FScratchAllocator to TDefineTable'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" \
  'TPreprocessor.Create\(Defines, True, IncResolver, FScratchAllocator\)' \
  'AnalyzeSyntax must pass FScratchAllocator to TPreprocessor'
need_grep "$ROOT/compiler/syntax/np_green_tree.pas" 'Create\(const AAllocator' \
  'TGreenTree must accept IAllocator for node storage'
need_grep "$ROOT/compiler/syntax/np_green_tree.pas" \
  'TGreenStringVec|FInterfaceUses: TGreenStringVec|FImplementationUses: TGreenStringVec' \
  'TGreenTree uses clauses must use TVec on tree allocator'
need_grep "$ROOT/compiler/syntax/np_green_tree.pas" \
  'TGreenForeignProcVec|FForeignProcedureDecls: TGreenForeignProcVec' \
  'TGreenTree foreign procedure decls must use TVec on tree allocator'
need_grep "$ROOT/compiler/frontend/np_compilation_session.pas" \
  'TToolStatusEventVec|FToolStatusEvents: TToolStatusEventVec' \
  'session tool status events must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_compilation_session_helpers.inc" \
  'TToolStatusEventVec\.Create' \
  'session CreateBuildSession must allocate FToolStatusEvents TVec'
need_grep "$ROOT/compiler/frontend/np_file_change_detector.pas" \
  'TFileSnapshotVec|FSnapshots: TFileSnapshotVec|TChangedFileVec' \
  'file change detector must use TVec for snapshots/changed files'
need_grep "$ROOT/compiler/diagnostics/np_diagnostics_sink.pas" \
  'TDiagnosticRecordVec|FDiagnostics: TDiagnosticRecordVec' \
  'diagnostics sink must use TVec for diagnostic records'
need_grep "$ROOT/compiler/diagnostics/np_diagnostics_sink.pas" \
  'TDiagnosticRecordVec\.Create' \
  'diagnostics sink CreateDefault must allocate FDiagnostics TVec'
need_grep "$ROOT/compiler/diagnostics/np_diagnostics_sink.pas" \
  'TRelatedInformationVec|TSuggestedFixVec|TOverloadCandidateVec' \
  'diagnostics nested Related/Fixes/Candidates must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/diagnostics/np_diagnostics_sink.pas" \
  'FreeDiagnosticNestedTables|Payload\.Candidates\.Free' \
  'diagnostics sink must Free nested Related/Fixes/Candidates TVec'
need_grep "$ROOT/compiler/diagnostics/np_diagnostics_sink.pas" \
  'CloneOverloadCandidatesFromArray' \
  'diagnostics must clone analyzer dynarray candidates into entry-owned TVec'
need_grep "$ROOT/compiler/sema/np_sema_seed_call_bindings.inc" \
  'CloneOverloadCandidatesFromArray' \
  'sema emit must clone overload candidates into diagnostics TVec'
need_grep "$ROOT/compiler/backend/np_backend_plan.pas" \
  'TBackendArtifactVec|FArtifacts: TBackendArtifactVec' \
  'backend plan artifacts must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/backend/np_backend_plan.pas" \
  'TBackendLogicalLibraryRequestVec|FLogicalLibraryRequests: TBackendLogicalLibraryRequestVec' \
  'backend plan library requests must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_parallel_scheduler.pas" \
  'TCompileTaskVec|FTasks: TCompileTaskVec' \
  'parallel scheduler tasks must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_parallel_scheduler.pas" \
  'TCompileOrderVec|FCompileOrder: TCompileOrderVec' \
  'parallel scheduler compile order must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_parallel_scheduler.pas" \
  'TCompileTaskVec\.Create|TCompileOrderVec\.Create' \
  'parallel scheduler Create must allocate FTasks/FCompileOrder TVec'
need_grep "$ROOT/compiler/frontend/np_source_database.pas" \
  'TSourceFileEntryVec|FFiles: TSourceFileEntryVec' \
  'source database files must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_source_database.pas" \
  'TSourceFileEntryVec\.Create' \
  'source database Create must allocate FFiles TVec'
need_grep "$ROOT/compiler/frontend/np_source_database.pas" \
  'TSourceLineOffsetVec|LineOffsets: TSourceLineOffsetVec' \
  'source database LineOffsets must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_source_database.pas" \
  'TSourceLineOffsetVec\.Create|LineOffsets\.Free' \
  'source database must Create/Free LineOffsets TVec'
need_grep "$ROOT/compiler/frontend/np_query_database.pas" \
  'TQueryEntryVec|FEntries: TQueryEntryVec' \
  'query database entries must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_workspace_model.pas" \
  'TPackageRefVec|FPackageRefs: TPackageRefVec' \
  'workspace package refs must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_workspace_model.pas" \
  'TProjectUnitRootInfoVec|FProjectUnitRootInfos: TProjectUnitRootInfoVec' \
  'workspace project unit root infos must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_workspace_model.pas" \
  'TProjectUnitRootVec|FProjectUnitRoots: TProjectUnitRootVec' \
  'workspace project unit roots must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_workspace_model.pas" \
  'TProjectUnitRootInfoVec\.Create|TProjectUnitRootVec\.Create' \
  'workspace Create must allocate project unit root TVecs'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan.pas" \
  'TToolInvocationStepVec|FSteps: TToolInvocationStepVec' \
  'toolchain plan steps must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan.pas" \
  'Argv: TToolchainStringVec|Inputs: TToolArtifactRefVec|Outputs: TToolArtifactRefVec' \
  'toolchain step nested Argv/I/O must use TVec (plan-owned default-heap)'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan.pas" \
  'Sidecars: TToolSidecarRefVec|EnvDelta: TToolEnvDeltaVec' \
  'toolchain step nested Sidecars/EnvDelta must use TVec (plan-owned default-heap)'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan_core.inc" \
  'InitToolInvocationStepNested|FreeToolInvocationStepNested' \
  'toolchain plan must init/free nested step TVecs'
need_grep "$ROOT/compiler/sema/np_sema_name_set.pas" \
  'TNameStringVec|Names: TNameStringVec' \
  'sema TNameSet must use TVec (default-heap)'
need_grep "$ROOT/compiler/sema/np_sema_name_set.pas" \
  'TNameStringVec\.Create|NameSetFree' \
  'sema TNameSet must Create TVec and expose NameSetFree'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" \
  'TCachedUnitSymbolsVec|GImportedUnitCache: TCachedUnitSymbolsVec' \
  'sema imported unit cache must use TVec (process default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" \
  'TCachedSymbolEntryVec|Symbols: TCachedSymbolEntryVec' \
  'sema imported unit cache nested Symbols must use TVec'
need_grep "$ROOT/compiler/sema/np_semantic_analyzer.pas" \
  'AppendImportedUnitCacheEntry|TCachedUnitSymbolsVec\.Create' \
  'sema imported unit cache must Create via helper'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan.pas" \
  'TToolArtifactRefVec|ObjectInputs: TToolArtifactRefVec' \
  'logical link object inputs must use TVec (plan-owned default-heap)'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan.pas" \
  'TLogicalLibraryRequestVec|LibraryRequests: TLogicalLibraryRequestVec' \
  'logical link library requests must use TVec (plan-owned default-heap)'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan_core.inc" \
  'TToolArtifactRefVec\.Create|TLogicalLibraryRequestVec\.Create' \
  'toolchain plan Create must allocate logical link TVecs'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan.pas" \
  'TToolchainStringVec|FProjectUnitRoots: TToolchainStringVec' \
  'toolchain planner project unit roots must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan.pas" \
  'FExplicitUnitRoots: TToolchainStringVec|FAdditionalAssemblyBaseNames: TToolchainStringVec' \
  'toolchain planner explicit roots/asm bases must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/toolchain/np_toolchain_plan_planner.inc" \
  'TToolchainStringVec\.Create' \
  'toolchain planner Create must allocate root/asm TVecs'
need_grep "$ROOT/compiler/toolchain/np_toolchain_runner.pas" \
  'TToolchainExecutedStepVec|FSteps: TToolchainExecutedStepVec' \
  'toolchain runner executed steps must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_unit_resolver.pas" \
  'TProjectUnitRootInfoVec|FProjectUnitRootInfos: TProjectUnitRootInfoVec' \
  'unit resolver project unit root infos must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_unit_resolver.pas" \
  'TUnitResolverStringVec|FExplicitUnitRoots: TUnitResolverStringVec' \
  'unit resolver explicit unit roots must use TVec (session-long default-heap)'
need_grep "$ROOT/compiler/frontend/np_unit_resolver_helpers.inc" \
  'TProjectUnitRootInfoVec\.Create|TUnitResolverStringVec\.Create' \
  'unit resolver Create must allocate root TVecs'
need_grep "$ROOT/compiler/syntax/np_lexer.pas" \
  'TTokenVec|FTokens: TTokenVec' \
  'lexer token table must use TVec (TLexerResult-owned default-heap)'
need_grep "$ROOT/compiler/syntax/np_lexer.pas" \
  'TTriviaPieceVec|FPendingTrivia: TTriviaPieceVec' \
  'lexer pending trivia must use TVec (TLexerResult-owned default-heap)'
need_grep "$ROOT/compiler/syntax/np_lexer.pas" \
  'LeadingTrivia: TTriviaPieceVec|TrailingTrivia: TTriviaPieceVec' \
  'lexer token nested Leading/TrailingTrivia must use TTriviaPieceVec'
need_grep "$ROOT/compiler/syntax/np_lexer.pas" \
  'CloneTokenWithTrivia|FreeTokenVecNestedTrivia' \
  'lexer must expose trivia clone/free helpers for value-copy token paths'
need_grep "$ROOT/compiler/syntax/np_lexer_helpers.inc" \
  'TTokenVec\.Create|TTriviaPieceVec\.Create' \
  'lexer Create must allocate FTokens/FPendingTrivia TVec'
need_grep "$ROOT/compiler/syntax/np_lexer_helpers.inc" \
  'FreeTokenVecNestedTrivia|LeadingTrivia\.Push|TrailingTrivia\.Push' \
  'lexer must Free nested token trivia and Push into entry-owned TVec'
need_grep "$ROOT/compiler/syntax/np_preprocessor.pas" \
  'CloneTokenWithTrivia' \
  'preprocessor EmitToken must deep-clone token nested trivia'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirFunctionVec|FFunctions: THirFunctionVec' \
  'HIR module functions must use TVec (module-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirParamVec|Params: THirParamVec' \
  'HIR function nested Params must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirParamVec\.Create|Params\.Push|Params\.Free' \
  'HIR module must Create/Push/Free nested function Params TVec'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirBlockVec|Blocks: THirBlockVec' \
  'HIR function nested Blocks must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirBlockVec\.Create|Blocks\.Push|Blocks\.Free' \
  'HIR module must Create/Push/Free nested function Blocks TVec'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'Blocks\.GetPtr|Block\^\.Instrs|Block\^\.Terminator' \
  'HIR module must mutate nested Blocks in-place via GetPtr'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirInstrVec|Instrs: THirInstrVec' \
  'HIR block nested Instrs must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirSwitchCaseVec|SwitchCases: THirSwitchCaseVec' \
  'HIR terminator nested SwitchCases must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'SwitchCases\.Free' \
  'HIR module must Free nested terminator SwitchCases TVec'
need_grep "$ROOT/compiler/ir/np_hir_builder_ctrlflow.inc" \
  'THirSwitchCaseVec\.Create|SwitchCases\.Push' \
  'HIR builder must Create/Push nested SwitchCases TVec'
need_grep "$ROOT/compiler/ir/np_hir_to_mir.pas" \
  'SwitchCases\.Count' \
  'HIR→MIR must iterate SwitchCases via TVec Count'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirInstrVec\.Create|Instrs\.Push|Instrs\.Free' \
  'HIR module must Create/Push/Free nested block Instrs TVec'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirBlockIdVec|Preds: THirBlockIdVec|Succs: THirBlockIdVec' \
  'HIR block nested Preds/Succs must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'Preds\.Free|Succs\.Free' \
  'HIR module must Free nested block Preds/Succs TVec'
need_grep "$ROOT/compiler/sema/np_semantic_field_meta_vec.pas" \
  'TSemanticFieldMetaVec = specialize TVec' \
  'Fields TVec specialize must live in satellite unit (ELF section limit)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticFieldMetaVec|Fields: TSemanticFieldMetaVec' \
  'sema type-metadata nested Fields must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'Meta\^\.Fields\.Free|Fields\.Free' \
  'sema model must Free nested type-metadata Fields TVec'
need_grep "$ROOT/compiler/sema/np_semantic_model_accessors.inc" \
  'AdoptOrCloneTypeMetaFields|CloneTypeMetaFields' \
  'SetTypeMeta must adopt/clone nested Fields ownership'
# Nested type-meta TVec specializes must stay in satellites (ELF ~65k sections).
forbid_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'specialize TVec<TFieldMeta>|specialize TVec<TVmtSlot>|specialize TVec<TPropertyMeta>|specialize TVec<TInterfaceSlotMeta>' \
  'np_semantic_model must not specialize nested type-meta TVec (use satellite units)'
forbid_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TFieldMeta = record|TVmtSlot = record|TPropertyMeta = record|TInterfaceSlotMeta = record' \
  'nested type-meta records must be defined in satellite units, model only re-exports'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" \
  '故意保留 dynarray|intentional keepers' \
  'USABILITY-SCORE must document intentional dynarray keepers after product-table convergence'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" \
  'product-table dual-track.*CLOSED|dual-track 主线 CLOSED|dual-track = CLOSED' \
  'USABILITY-SCORE must mark product-table dual-track CLOSED after residual audit'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" \
  'Operands.*PhiEntries|THIRInstr\.Operands' \
  'USABILITY-SCORE must keep HIR Operands/PhiEntries as intentional keepers'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" \
  'TDiskCachedUnit\.Symbols|disk symbol cache' \
  'USABILITY-SCORE must document disk symbol cache Symbols as intentional DTO keeper'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" \
  '独立 package lane' \
  'USABILITY-SCORE must keep package DTO as independent package lane, not mem dual-track'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'Operands: array of THIROperand|PhiEntries: array of THIRPhiEntry' \
  'HIR Operands/PhiEntries must remain managed dynarray keepers (not TVec product-table target)'
need_grep "$ROOT/compiler/frontend/np_symbol_cache.pas" \
  'Symbols: array of TDiskCachedSymbolEntry' \
  'disk cache Symbols must remain managed dynarray serialization DTO'
need_grep "$MEM_DOCS/USABILITY-SCORE.md" \
  'np_semantic_field_meta_vec|卫星单元' \
  'USABILITY-SCORE must document field-meta satellite / ELF rule'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticHirChildVec|Children: TSemanticHirChildVec' \
  'sema HirExpr nested Children must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'Children\.Free|SemanticHirChildCount' \
  'sema model must Free nested HirExpr Children TVec and expose nil-safe count'
need_grep "$ROOT/compiler/sema/np_semantic_model_lookup.inc" \
  'TSemanticHirChildVec\.Create|Children\.Push' \
  'AddHirExpr must Create/Push nested Children TVec from open-array input'
need_grep "$ROOT/compiler/sema/np_semantic_vmt_slot_vec.pas" \
  'TSemanticVmtSlotVec = specialize TVec' \
  'VmtSlots TVec specialize must live in satellite unit (ELF section limit)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticVmtSlotVec|VmtSlots: TSemanticVmtSlotVec' \
  'sema type-metadata nested VmtSlots must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'VmtSlots\.Free' \
  'sema model must Free nested type-metadata VmtSlots TVec'
need_grep "$ROOT/compiler/sema/np_semantic_model_accessors.inc" \
  'AdoptOrCloneTypeMetaVmtSlots|CloneTypeMetaVmtSlots' \
  'SetTypeMeta must adopt/clone nested VmtSlots ownership'
need_grep "$ROOT/compiler/sema/np_semantic_property_meta_vec.pas" \
  'TSemanticPropertyMetaVec = specialize TVec' \
  'Properties TVec specialize must live in satellite unit (ELF section limit)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticPropertyMetaVec|Properties: TSemanticPropertyMetaVec' \
  'sema type-metadata nested Properties must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'Properties\.Free' \
  'sema model must Free nested type-metadata Properties TVec'
need_grep "$ROOT/compiler/sema/np_semantic_model_accessors.inc" \
  'AdoptOrCloneTypeMetaProperties|CloneTypeMetaProperties' \
  'SetTypeMeta must adopt/clone nested Properties ownership'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'RetPtrMethods: TSemanticStringVec' \
  'sema type-metadata nested RetPtrMethods must use TSemanticStringVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'RetPtrMethods\.Free' \
  'sema model must Free nested type-metadata RetPtrMethods TVec'
need_grep "$ROOT/compiler/sema/np_semantic_model_accessors.inc" \
  'AdoptOrCloneTypeMetaRetPtrMethods|CloneTypeMetaRetPtrMethods' \
  'SetTypeMeta must adopt/clone nested RetPtrMethods ownership'
need_grep "$ROOT/compiler/sema/np_semantic_interface_slot_vec.pas" \
  'TSemanticInterfaceSlotMetaVec = specialize TVec' \
  'InterfaceSlots TVec specialize must live in satellite unit (ELF section limit)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticInterfaceSlotMetaVec|InterfaceSlots: TSemanticInterfaceSlotMetaVec' \
  'sema type-metadata nested InterfaceSlots must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'InterfaceSlots\.Free' \
  'sema model must Free nested type-metadata InterfaceSlots TVec'
need_grep "$ROOT/compiler/sema/np_semantic_model_accessors.inc" \
  'AdoptOrCloneTypeMetaInterfaceSlots|CloneTypeMetaInterfaceSlots' \
  'SetTypeMeta must adopt/clone nested InterfaceSlots ownership'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirGlobalVec|FGlobals: THirGlobalVec' \
  'HIR module globals must use TVec (module-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirVmtGlobalVec|FVmtGlobals: THirVmtGlobalVec' \
  'HIR module VMT globals must use TVec (module-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirImtGlobalVec|FImtGlobals: THirImtGlobalVec' \
  'HIR module IMT globals must use TVec (module-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirStringVec|FUnitInitOrder: THirStringVec' \
  'HIR module unit-init order must use TVec (module-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'Funcs: THirStringVec|ThunkNames: THirStringVec' \
  'HIR VMT/IMT nested Funcs/ThunkNames must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirLongIntVec|ThunkParamCounts: THirLongIntVec' \
  'HIR IMT nested ThunkParamCounts must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirStringVec\.Create|Funcs\.Push|ThunkNames\.Push|Funcs\.Free' \
  'HIR module must Create/Push/Free VMT/IMT nested TVecs'
need_grep "$ROOT/compiler/ir/np_hir_model.pas" \
  'THirFunctionVec\.Create|THirGlobalVec\.Create|THirVmtGlobalVec\.Create' \
  'HIR module Create must allocate top-level TVecs'
need_grep "$ROOT/compiler/ir/np_hir_llvm_emitter_helpers.inc" \
  'Funcs\.Count|ThunkNames\.Count' \
  'HIR LLVM emitter must iterate VMT/IMT nested tables via TVec Count'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirFunctionVec|FFunctions: TMirFunctionVec' \
  'MIR module functions must use TVec (module-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirParamVec|Params: TMirParamVec' \
  'MIR function nested Params must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirParamVec\.Create|Params\.Push|Params\.Free' \
  'MIR module must Create/Push/Free nested function Params TVec'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirBlockVec|Blocks: TMirBlockVec' \
  'MIR function nested Blocks must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirBlockVec\.Create|Blocks\.Push|Blocks\.Free' \
  'MIR module must Create/Push/Free nested function Blocks TVec'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'Blocks\.GetPtr|Block\^\.Stmts|Block\^\.Terminator' \
  'MIR module must mutate nested Blocks in-place via GetPtr'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirStmtVec|Stmts: TMirStmtVec' \
  'MIR block nested Stmts must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirStmtVec\.Create|Stmts\.Push|Stmts\.Free' \
  'MIR module must Create/Push/Free nested block Stmts TVec'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirOperandVec|Args: TMirOperandVec' \
  'MIR stmt nested Args must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirSwitchCaseVec|SwitchCases: TMirSwitchCaseVec' \
  'MIR terminator nested SwitchCases must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'Args\.Free|SwitchCases\.Free|CloneMirOperandVec' \
  'MIR module must Free nested Args/SwitchCases and expose CloneMirOperandVec'
need_grep "$ROOT/compiler/ir/np_hir_to_mir.pas" \
  'TMirOperandVec\.Create|Args\.Push|TMirSwitchCaseVec\.Create|SwitchCases\.Push' \
  'HIR→MIR must Create/Push nested Args and SwitchCases TVec'
need_grep "$ROOT/compiler/ir/np_mir_to_llvm.pas" \
  'Args\.Count|SwitchCases\.Count' \
  'MIR LLVM translator must iterate Args/SwitchCases via TVec Count'
need_grep "$ROOT/compiler/ir/np_mir_pass_inline.pas" \
  'CloneMirOperandVec' \
  'MIR inline must clone Args when copying callee stmts'
need_grep "$ROOT/compiler/ir/np_mir_pass_deadarg.pas" \
  'SetParams\(Fn\.Id|Kept' \
  'MIR deadarg must write back Params via SetParams open-array copy-out'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirStructTypeVec|FStructTypes: TMirStructTypeVec' \
  'MIR module struct types must use TVec (module-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirStructFieldVec|Fields: TMirStructFieldVec' \
  'MIR struct nested Fields must use TVec (entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirStructFieldVec\.Create|Fields\.Push|Fields\.Free' \
  'MIR module must Create/Push/Free nested struct Fields TVec'
need_grep "$ROOT/compiler/ir/np_mir_model.pas" \
  'TMirFunctionVec\.Create|TMirStructTypeVec\.Create' \
  'MIR module Create must allocate top-level TVecs'
need_grep "$ROOT/compiler/ir/np_mir_to_llvm.pas" \
  'Fields\.Count|Fields\[SizeUInt' \
  'MIR LLVM translator must iterate struct Fields via TVec Count'
need_grep "$ROOT/compiler/ir/np_hir_types.pas" \
  'THirTypeRecVec|FTypes: THirTypeRecVec' \
  'HIR type table must use TVec (table-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_types.pas" \
  'THirTypeRecVec\.Create' \
  'HIR type table Create must allocate FTypes TVec'
need_grep "$ROOT/compiler/ir/np_hir_types.pas" \
  'THirFieldEntryVec|Fields: THirFieldEntryVec' \
  'HIR type nested Fields must use TVec (table-entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_types.pas" \
  'THirParamEntryVec|Params: THirParamEntryVec' \
  'HIR type nested Params must use TVec (table-entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_types.pas" \
  'THirTypeIdVec|InterfaceIds: THirTypeIdVec' \
  'HIR type nested InterfaceIds must use TVec (table-entry-owned default-heap)'
need_grep "$ROOT/compiler/ir/np_hir_types.pas" \
  'THirFieldEntryVec\.Create|Fields\.Push|Fields\.Free' \
  'HIR type table must Create/Push/Free nested Fields TVec'
need_grep "$ROOT/compiler/ir/np_hir_llvm_emitter.pas" \
  'Fields\.Count|Fields\[SizeUInt' \
  'HIR LLVM emitter must iterate type Fields via TVec Count'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticSymbolVec|FSymbols: TSemanticSymbolVec' \
  'semantic model symbols must use TVec (model-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticTypeVec|FTypes: TSemanticTypeVec' \
  'semantic model types must use TVec (model-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticHirExprVec|FHirExprs: TSemanticHirExprVec' \
  'semantic model hir exprs must use TVec (model-owned default-heap)'
need_grep "$ROOT/compiler/sema/np_semantic_model.pas" \
  'TSemanticSymbolVec\.Create|TSemanticTypeVec\.Create|TSemanticHirExprVec\.Create' \
  'semantic model Create must allocate product TVecs'
need_grep "$ROOT/compiler/ir/np_hir_to_mir.pas" 'AAllocator|FValueMap' \
  'THirToMirLowering must accept IAllocator for value map'
need_grep "$ROOT/compiler/ir/np_hir_builder.pas" 'AAllocator|FAllocator' \
  'THIRBuilder must accept optional phase IAllocator'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" \
  'THirToMirLowering.Create.*FScratchAllocator|Create\(HirBuilder.Module, FScratchAllocator\)' \
  'LowerToMir must pass FScratchAllocator to HIR→MIR lowering'
need_grep "$ROOT/compiler/backend/np_backend_plan.pas" 'PhaseScratch|CompilerCreateUnitAllocator' \
  'backend plan must own phase scratch IAllocator for real LLVM HIR path'
need_grep "$ROOT/compiler/backend/np_backend_plan.pas" \
  'THIRBuilder.Create.*PhaseScratch|Create\(FSemaModel, nil, 0, PhaseScratch\)' \
  'backend plan must pass PhaseScratch to THIRBuilder'
need_grep "$ROOT/compiler/backend/np_backend_plan.pas" \
  'THirToMirLowering.Create.*PhaseScratch|Create\(HirBuilder.Module, PhaseScratch\)' \
  'backend MIR path must pass PhaseScratch to HIR→MIR lowering'
need_grep "$ROOT/compiler/ir/np_hir_builder.pas" 'THirBlockNameVec|THirBlockIdVec' \
  'THIRBuilder block maps must use TVec on phase allocator'
need_grep "$ROOT/compiler/ir/np_hir_builder.pas" 'ClearWorkBlocks|RestoreWorkBlocks' \
  'THIRBuilder must clear/restore block maps without dynarray SetLength'
need_grep "$ROOT/compiler/ir/np_hir_builder.pas" 'THirAllocaVec|ClearWorkAllocas|RestoreWorkAllocas' \
  'THIRBuilder allocas must use TVec on phase allocator'
need_grep "$ROOT/compiler/ir/np_hir_builder.pas" 'FSavedAllocas: THirAllocaVec|SnapshotWorkTables' \
  'THIRBuilder FSaved* snapshots must use TVec on phase allocator'
need_grep "$ROOT/compiler/ir/np_hir_builder_funclifecycle.inc" 'SnapshotWorkTables' \
  'function begin/end must snapshot work tables via SnapshotWorkTables'
need_grep "$ROOT/compiler/ir/np_hir_builder.pas" 'TExprStack|Init\(AAllocator|Values\.Push|TryPop' \
  'TExprStack must use TVec Values/Types with optional IAllocator'
need_grep "$ROOT/compiler/ir/np_hir_builder_process.inc" 'S\.Init\(FAllocator\)|CreateNameVec' \
  'ParseIntExprArgTyped must init expr stack and lines on FAllocator'
need_grep "$ROOT/compiler/ir/np_hir_builder_type_helpers.inc" 'FAllocas.Push|RegisterAllocaEntry' \
  'RegisterAllocaEntry must Push into FAllocas TVec'
need_grep "$ROOT/compiler/ir/np_hir_builder_object.inc" 'GetPtr' \
  'in-place alloca field updates must use TVec.GetPtr'
need_grep "$ROOT/compiler/ir/np_hir_builder.pas" 'RegisterGlobal|ClearGlobalRefs' \
  'THIRBuilder globals must use RegisterGlobal/ClearGlobalRefs on TVec'
need_grep "$ROOT/compiler/ir/np_hir_builder.pas" 'FGlobalNames: THirNameVec|FFwdFuncNames: THirNameVec|FIntfVarNames: THirNameVec' \
  'THIRBuilder global/fwd/intf tables must be TVec not dynarray'
need_grep "$ROOT/compiler/ir/np_hir_llvm_emitter.pas" 'AAllocator|FAllocator|TLlvmLineVec' \
  'THIRLlvmEmitter must accept optional phase IAllocator for emit work tables'
need_grep "$ROOT/compiler/backend/np_backend_plan.pas" \
  'THIRLlvmEmitter.Create.*PhaseScratch|Create\(HirBuilder.Module,.*PhaseScratch\)' \
  'backend LLVM direct path must pass PhaseScratch to THIRLlvmEmitter'
need_grep "$ROOT/compiler/ir/np_mir_to_llvm.pas" 'AAllocator|FAllocator|TMirLlvmLineVec' \
  'TMirToLlvmTranslator must accept optional phase IAllocator for output lines'
need_grep "$ROOT/compiler/backend/np_backend_plan.pas" \
  'TMirToLlvmTranslator.Create.*PhaseScratch|Create\(MirModule, PhaseScratch\)' \
  'backend MIR→LLVM path must pass PhaseScratch to TMirToLlvmTranslator'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" \
  'TMirToLlvmTranslator.Create\(FMirModule, FScratchAllocator\)' \
  'session MIR dump must pass FScratchAllocator to TMirToLlvmTranslator'
need_grep "$ROOT/compiler/ir/np_hir_printer.pas" 'AAllocator|FAllocator|THirPrintLineVec' \
  'THIRPrinter must accept optional phase IAllocator for print lines'
need_grep "$ROOT/compiler/frontend/np_compilation_session_pipeline.inc" \
  'THIRPrinter.Create\(HirBuilder.Module, FScratchAllocator\)' \
  'session HIR dump must pass FScratchAllocator to THIRPrinter'
need_grep "$ROOT/core/src/nextpas.core.collections.element_manager.pas" 'SupportsRealloc' \
  'element_manager must handle SupportsRealloc=False for arena TVec growth'
need_file "$ROOT/scripts/rebuild-compiler.sh"
need_grep "$ROOT/scripts/rebuild-compiler.sh" 'Fucore/src|core/src' \
  'rebuild-compiler must include core/src unit path for mem product wire'
need_grep "$ROOT/core/src/nextpas.core.http.pas" 'function HttpRequestAllocatorOf' \
  'http facade must expose HttpRequestAllocatorOf'

# ERROR-POLICY iron rules
need_grep "$MEM_DOCS/ERROR-POLICY.md" '资源不足' 'ERROR-POLICY must state resource-failure rule'
need_grep "$MEM_DOCS/ERROR-POLICY.md" '编程错误' 'ERROR-POLICY must state programming-error rule'
need_grep "$MEM_DOCS/ERROR-POLICY.md" 'NEXTPAS_MEM_DEBUG' 'ERROR-POLICY must scope DEBUG'
need_grep "$MEM_DOCS/ERROR-POLICY.md" 'TryGetMem' 'ERROR-POLICY must document TryGetMem form'
need_grep "$MEM_DOCS/ERROR-POLICY.md" 'TryFreeMem' 'ERROR-POLICY must document TryFreeMem form'
need_grep "$MEM_DOCS/README.md" 'TryGetMem' 'README must document TryGetMem'
need_grep "$MEM_DOCS/API-GUIDE.md" 'TryGetMem' 'API-GUIDE must document TryGetMem'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function TryGetMem' 'mem facade must expose TryGetMem'
need_grep "$ROOT/core/src/nextpas.core.mem.pas" 'function TryFreeMem' 'mem facade must expose TryFreeMem'
need_grep "$ROOT/core/examples/nextpas.core.http/http_server_options_demo/http_server_options_demo.lpr" \
  'HttpUseRequestArena' 'options demo must mount request arena'

# API-GUIDE anti dual-track misuse
need_grep "$MEM_DOCS/API-GUIDE.md" 'DefaultAllocator 当热路径' 'API-GUIDE must warn against DefaultAllocator hot path'
need_grep "$MEM_DOCS/API-GUIDE.md" 'NEXTPAS_MEM_DEBUG' 'API-GUIDE must cover DEBUG blind spot'

# CONTRACT dual-track section
need_grep "$MEM_DOCS/CONTRACT.md" '默认双轨' 'CONTRACT must have dual-track section'

# Historical audit must be marked superseded
need_grep "$MEM_DOCS/USABILITY-AUDIT.md" 'SUPERSEDED' 'USABILITY-AUDIT must be SUPERSEDED'

# Forbidden: README claiming DefaultAllocator is the hot-path default heap
# (allow table rows that say it is NOT hot path)
if grep -E '热路径.*DefaultAllocator|DefaultAllocator.*热路径默认' "$MEM_DOCS/README.md" \
  | grep -Ev '不是|非热|不要|错误|插件|注入' >/dev/null 2>&1; then
  die 'README appears to market DefaultAllocator as hot-path default'
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "usability-docs: FAILED" >&2
  exit 1
fi

echo "usability-docs: PASS"
