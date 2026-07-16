# nextpas.core.mem 可用性评分（权威）

**评估日期**: 2026-07-16（lane 收口：默认 focused gate + 文档收敛）
**范围**: `nextpas.core.mem` 对外默认路径、契约、诊断、上层注入
**对标**: Go `runtime` 分配默认 / Rust `GlobalAlloc`+标准容器体验（工程可用性，非微基准军备）
**前序**: 7.3 → … → 10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ → 本轮 **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**

历史长报告 [USABILITY-AUDIT.md](USABILITY-AUDIT.md) 已 SUPERSEDED，仅作修复履历。

---

## 综合

| 项 | 值 |
|----|-----|
| **综合分** | **10.0 / 10** |
| **等级** | **HIGH** |
| **趋势** | … → 10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ → **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++**（lane 收口 / 默认 gate 收敛） |
| **风险** | LOW（见下「故意默认堆」与「故意保留 dynarray」；phase 工作表走 scratch，session 级 Detach 产物不挂 reset arena） |

**结论（一句话）**: H1/H2 连接级 LocalArena 与编译 session/backend 管线均走真实 mem 产品路径；根 AST、preprocessor、sema、HIR builder/verifier、HIR/MIR 工作表与多数 MIR pass 分轨使用 `FAstAllocator` / `FScratchAllocator` / `PhaseScratch`；`DetachUnitGraph`/`DetachSearchPaths` 产物故意默认堆。**产品表 dual-track 主线 CLOSED**（2026-07-16 residual audit）：清晰单所有权 session/跨 phase 表与 entry-owned nested 已在默认堆/scratch `TVec`；剩余 dynarray 均为 intentional keepers，**不再作为 mem dual-track 下一刀**。

### 故意默认堆（lifetime 理由；非 phase bulk reclaim 目标）

| 存储 | 理由 |
|------|------|
| HIR 模块顶层表（funcs/globals/vmt/imt/unit-init） | 跨 phase 永久 IR；`THir*Vec` 默认堆；VMT/IMT nested + func `Params`/`Blocks` + block `Instrs`/`Preds`/`Succs` → TVec 默认堆；terminator nested `SwitchCases` → `THirSwitchCaseVec`（entry-owned；`SetTerminator`/`Destroy` Free） |
| HIR type table `FTypes` | 跨 phase 永久 IR；`THirTypeRecVec` 默认堆；nested `Fields`/`Params`/`InterfaceIds` → `THirFieldEntryVec`/`THirParamEntryVec`/`THirTypeIdVec` 默认堆 |
| Semantic model 产品表 | session 级；symbols/types/scopes/hir-exprs/bindings/… → `TSemantic*Vec` 默认堆；type-metadata nested `Fields`/`VmtSlots`/`Properties`/`RetPtrMethods`/`InterfaceSlots` → `TSemanticFieldMetaVec`/`TSemanticVmtSlotVec`/`TSemanticPropertyMetaVec`/`TSemanticStringVec`/`TSemanticInterfaceSlotMetaVec` 默认堆；HirExpr nested `Children` → `TSemanticHirChildVec` 默认堆。**ELF 约束**：`np_semantic_model.o` 在 `-CX` function sections 下已接近 ~65k section 上限；`TVec<TFieldMeta>`/`TVec<TVmtSlot>`/`TVec<TPropertyMeta>`/`TVec<TInterfaceSlotMeta>` 特化放在卫星单元（model 仅 re-export）；`RetPtrMethods` 复用本单元已有 `TSemanticStringVec`。后续 nested TVec 继续落卫星单元，勿再在 model 内新增 `specialize`。 |
| MIR 模块顶层表（funcs/struct-types） | 跨 phase 永久 IR；`TMirFunctionVec`/`TMirStructTypeVec` 默认堆；struct `Fields` + func `Params`/`Blocks` + block `Stmts` → nested TVec 默认堆；stmt nested `Args` → `TMirOperandVec`；terminator nested `SwitchCases` → `TMirSwitchCaseVec`（entry-owned；`SetStmt`/`SetTerminator`/`Destroy` Free；inline/LICM 经 `CloneMirOperandVec`） |
| Diagnostics sink 列表 | 诊断常跨 phase 存活；`TDiagnosticRecordVec` 默认堆；nested `RelatedInformation`/`SuggestedFixes`/`Payload.Candidates` → `TRelatedInformationVec`/`TSuggestedFixVec`/`TOverloadCandidateVec` 默认堆（analyzer `out TOverloadCandidateArray` 仍为 managed dynarray，emit 时 `CloneOverloadCandidatesFromArray`） |
| Backend `FArtifacts` / library requests | 须跨过 `PhaseScratch` bulk reclaim；`TBackendArtifactVec` 默认堆 |
| Source database 文件/行表 | session 级源身份；`TSourceFileEntryVec` 默认堆；行内 `LineOffsets` → `TSourceLineOffsetVec` 默认堆 |
| Lexer `FTokens` | 归 TLexerResult 所有权；`TTokenVec` 默认堆；token nested `LeadingTrivia`/`TrailingTrivia` → `TTriviaPieceVec` 默认堆 |
| Package/workspace/lock/toolchain DTO | 清单与执行计划，非 phase scratch；query/workspace/toolchain planner roots+asm bases/plan+runner steps 已 TVec 默认堆 |
| Toolchain logical link request tables | plan 拥有；ObjectInputs/LibraryRequests/OrderedSymbols → TVec 默认堆 |
| Toolchain step nested Argv/I/O/Sidecars | plan step 拥有；`TToolchainStringVec`/`TToolArtifactRefVec`/`TToolSidecarRefVec`/`TToolEnvDeltaVec` 默认堆；runner 执行前 Argv copy-out |
| Sema builtin name set | process/session 注册表；`TNameSet.Names` → `TNameStringVec` 默认堆 |
| Sema pending-signature work entries | analyzer scratch `FPendingSignatures`；nested `ParamNames`/`ArgTypes` → `TStringVec`（entry-owned，与 `FAllocator` 同轨；`CompletePendingSignatures`/`Destroy` Free） |
| Sema imported unit cache | process 级符号缓存；`GImportedUnitCache`/`Symbols` → `TCachedUnitSymbolsVec`/`TCachedSymbolEntryVec` 默认堆 |
| Unit resolver root tables | session/phase 输入拷贝；`TProjectUnitRootInfoVec`/`TUnitResolverStringVec` 默认堆；search-index nested `CandidatePaths` → entry-owned `TUnitResolverStringVec`（与 `FNodeAllocator` 同轨；`FreeRootIndexEntries`/`EnsureRootIndex` Clear Free；`FindCandidatePaths*` 经 `ToArray` 出边界） |
| Lexer `FPendingTrivia` + token nested trivia | TLexerResult 工作缓冲与 token entry 所有；`TTriviaPieceVec` 默认堆；`EmitToken`/`CreateFromTokens` deep-clone trivia（避免值拷贝双 Free） |
| HIR lowering 固定 arity `Children` / `Operands` | 非增长工作表，open-array 边界 |
| Unit graph / Search path set（`Detach*`） | ResolveUnits 后写入 session；`ResetScratchAllocator` 之后仍被 sema 使用 |
| Tool status events / file-change snapshots | session 级；TVec 默认堆（非 phase scratch） |
| Parallel scheduler tasks + compile order | session 级调度表；`TCompileTaskVec`/`TCompileOrderVec` 默认堆 |

### 故意保留 dynarray（intentional keepers；**CLOSED** — 非 mem dual-track 目标）

| 存储 | 理由 |
|------|------|
| HIR `THIRInstr.Operands` / `PhiEntries` | 指令操作数槽位：builder 以 `SetLength` 按指令 arity 写死（含 call 变长实参）；`PhiEntries` 当前几乎未填充。**非** session 可增长产品表；整表迁 TVec 触点 ~560+ 且与 open-array 式 emit 耦合，故意保留 managed dynarray。terminator `SwitchCases` 已迁 `THirSwitchCaseVec` |
| `TGenericParentRef.ArgIndices` | 泛型实参索引，小且随类型记录值语义；非 session 可增长表 |
| sema walk/codegen 临时 `Children` / `ParamSnapshots` / `TTypeIdArray` | phase scratch 或 API open-array 边界，不进入 Detach 产品面 |
| analyzer `out TOverloadCandidateArray`（sema call-binding） | managed dynarray 适配 build/discard 路径；**不**改成类引用，避免丢弃路径泄漏。sink 产品面经 `CloneOverloadCandidatesFromArray` 拷入 entry-owned `TOverloadCandidateVec` |
| package manifest/lock/workflow DTO `array of …` | 清单加载返回值与 workspace 拷贝面；query/workspace 根表已 TVec。整树迁 TVec 是**独立 package lane**，非 mem dual-track 阻塞 |
| disk symbol cache `TDiskCachedUnit.Symbols` | 磁盘序列化 DTO：`TryLoad`/`Save` 填表即写文件；进程侧产品面已是 `GImportedUnitCache` → `TCachedSymbolEntryVec`。保留 managed dynarray 作 I/O 缓冲 |
| toolchain profile `DriverCandidates: TStringArray` | 配置解析字面量数组，进程级只读配置 |
| open-array 形参（`const AChildren: array of LongInt` 等） | 调用边界，不是存储所有权 |
| builder/pass 局部 scratch（call args、vcall ops、MIR pass `Kept`/`SavedArgs` 等） | 函数栈上临时表，非 session/跨 phase 产品存储 |

**ELF 卫星规则（锁定）**: type-metadata nested 的 `TFieldMeta`/`TVmtSlot`/`TPropertyMeta`/`TInterfaceSlotMeta` 特化必须住在 `np_semantic_*_vec` 卫星单元；`np_semantic_model.pas` 只 re-export，禁止再往 model 内新增 nested `specialize TVec`。

**Residual audit（2026-07-16，product-table dual-track CLOSED）**: 扫过 `compiler/**` 中 record/class 字段与 session 产品表后的结论——可迁「清晰单所有权 nested 产品表」已清零。再做 dynarray→TVec 要么是上述 keepers，要么应开独立 package lane；**不要**在 mem worktree 上继续冲 HIR Operands / package DTO 整树当可用性阻塞。

---

## 分维（1–10，对标 Go/Rust 工程体验）

| 维度 | 分 | 依据 |
|------|----|------|
| 默认路径正确性 | **9.5** | Growing 热路径；S5 同堆（Growing IAllocator / `GetGrowingIAllocator`）；H1+H2 RequestArena；compiler phase UnitBegin |
| API 可发现性 | **10** | `WithRequestArena` / `HttpRequestAllocatorOf` / `HttpFormatProcessMemStats`；`MemAlloc`/`MemUnitCount`/`MemSessionPeak` |
| 调用一致性 | **9.9** | HTTP Options/H1/H2 与 compiler UnitBegin/End 对称 bulk-reclaim |
| 错误模型 | **9.0** | ERROR-POLICY + Try* + TryBlockSize/SC8 |
| 诊断可用性 | **10** | FormatMemStats（`heap_debug`/`debug` + DEBUG 时 `debug_active_*`/`debug_allocs`/`debug_frees`）+ HttpFormatProcessMemStats；session/unit `FormatStats`；ops mem-session/process-stats；门面 `IsMemHeapDebugEnabled`；HEAP_DEBUG 双轨测试锁；CI/verify env recipe 锁 `heap_debug=y|n` |
| 契约可证明 | **10** | H1/H2 InvokeHandler、pipeline UnitBegin/MemAlloc、SessionScope；AST≠scratch Reset、SessionPeak 跨 UnitBegin、FreeMem no-op、entry-owned nested vs Detach 默认堆（test_compiler_mem + guardrails）；SC9 双轨 |
| 性能默认 | **9.4** | 连接级/会话级 arena 复用；Growing 热路径；HEAP_DEBUG 默认关 |
| 上层可集成 | **10** | hello options → native；compiler session 管线真实 MemAlloc；HttpRequestAllocatorOf |
| **加权综合** | **10.0** | — |

---

## 相对 9.9：什么变了

| 项 | 状态 | 效果 |
|----|------|------|
| `AnalyzeSyntax` | **UnitBegin + MemAlloc path scratch + UnitEnd** | 语法阶段真实 session arena 分配 |
| `ResolveUnits` | **UnitBegin + MemAlloc path seed + UnitEnd** | 解析阶段 peak 计入 MemSessionPeak |
| Accessors | **`MemUnitCount` / `MemTotalUsed`** | 会话诊断面完整 |
| Toolchain | **CI 常态化 `make rebuild-compiler`** | flags 单源 `scripts/stage0-fpc-flags.sh`；CI 顺序 tooling→rebuild→verify |

---

## Lane 收口状态（2026-07-16）

**产品主线 CLOSED**（非可用性阻塞；落地项全部进修订记录，不再列在待办里）：

| 线 | 状态 |
|----|------|
| compiler product-table dual-track（session/nested TVec） | **CLOSED** — intentional keepers 入文档；勿再冲 HIR Operands / package DTO |
| session/unit `FormatStats` + ops `mem-*-stats` | **落地** |
| arena 契约回归 + HEAP_DEBUG 插件轨体验 | **落地** |
| CI `rebuild-compiler` + stage0 flags 单源 + HEAP_DEBUG env recipe | **落地** |

**默认 lane focused gate**（`docs/worktrees.md` / `make lane-focused LANE=mem`）：

```text
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
```

按改动表面追加：`test_compiler_mem` / `test_debug_wrap` / `make stage0-heap-debug-recipe` / `test_memory_map_compile_gate`。

### 仍可演进（独立 lane 或远期，非 mem dual-track 阻塞）

1. package manifest/lock DTO 整树 → TVec：**独立 package lane**。
2. 双轨表面（热 vs 插件）— 设计选择，已文档化（SC9）；不追求合并。
3. Scorecard 外部对照 / 更多 host 覆盖 — 性能演进，非可用性阻塞。

---

## 门禁证据（复评当日）

```text
make lane-focused LANE=mem
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make focused FOCUS=core/tests/nextpas.core.http/test_http_mem
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_types
make focused FOCUS=core/tests/nextpas.core.compiler/test_compiler_mem
make stage0-heap-debug-recipe
```

---

## 修订记录

| 日期 | 分 | 说明 |
|------|-----|------|
| 2026-07-15 | 7.3–8.8 | P0→SC9 |
| 2026-07-15 | 9.0–9.6 | HTTP wire → server-root factory |
| 2026-07-15 | 9.7 | THttpServerOptions.WithRequestArena + HttpRequestAllocatorOf |
| 2026-07-15 | 9.8 | H1 connection-scoped RequestArena + TCompilerSessionScope |
| 2026-07-15 | 9.9 | H2 native RequestArena + TCompilationSession mem wire |
| 2026-07-15 | **10.0** | pipeline MemAlloc phase scratch + rebuild-compiler 对齐 |
| 2026-07-15 | **10.0+** | GreenTree `IAllocator` + session `FAstAllocator`；`ReallocElements` arena fallback |
| 2026-07-15 | **10.0++** | `FScratchAllocator`：resolver 依赖树 + sema 工作 TVec；`MemFormatSessionStats`；sema/MIR phase UnitBegin |
| 2026-07-15 | **10.0+++** | HIR builder + HIR→MIR `FValueMap` 接 `FScratchAllocator`；pending cleanup TVec |
| 2026-07-16 | **10.0++++** | backend `PhaseScratch` 接真实 LLVM HIR/MIR 路径；`FBlockNames`/`FBlockIds` → TVec on `FAllocator` |
| 2026-07-16 | **10.0+++++** | `FAllocas` → `THirAllocaVec`；就地字段写走 `GetPtr`；`ClearWorkAllocas`/`RestoreWorkAllocas` |
| 2026-07-16 | **10.0++++++** | globals/global-ref/fwd-func/intf-var 工作表 → TVec；`RegisterGlobal`/`ClearGlobalRefs` |
| 2026-07-16 | **10.0+++++++** | `THIRLlvmEmitter` lines/global-ref/str/debug → TVec；backend 传 `PhaseScratch` |
| 2026-07-16 | **10.0++++++++** | `TMirToLlvmTranslator` 输出行表 → TVec；backend `PhaseScratch` + session `FScratchAllocator` |
| 2026-07-16 | **10.0+++++++++** | `THIRPrinter` 行表 → TVec；session HIR dump 传 `FScratchAllocator` |
| 2026-07-16 | **10.0++++++++++** | sema `FGenericWorkQueue`/`FCompilerProcNames` → TVec on `FScratchAllocator` |
| 2026-07-16 | **10.0+++++++++++** | sema 导入单元 `FImportedUnitTrees`/`Owners` → TVec；overload/HIR ctx 借用 |
| 2026-07-16 | **10.0++++++++++++** | sema `FPendingSignatures` → TVec on `FScratchAllocator` |
| 2026-07-16 | **10.0+++++++++++++** | `TMirPassManager` pass registry → TVec；backend 传 `PhaseScratch` |
| 2026-07-16 | **10.0++++++++++++++** | MIR DCE `UsedRegs` / CSE `CseTable` → TVec；opt-level 传 `AManager.Allocator` |
| 2026-07-16 | **10.0+++++++++++++++** | MIR deadarg/escape/licm/inline 工作表 → TVec；opt-level 透传 Allocator |
| 2026-07-16 | **10.0++++++++++++++++** | sema `FProcedureBodies` → TProcedureBodyVec on FScratchAllocator；ctx 借用 |
| 2026-07-16 | **10.0+++++++++++++++++** | `TSemaRuntimeVarRegistry` 全表 → TStringVec；Create(FAllocator) |
| 2026-07-16 | **10.0++++++++++++++++++** | HIR builder `FSavedAllocas`/`FSavedBlock*` → TVec；`SnapshotWorkTables` + cleanup 局部快照 |
| 2026-07-16 | **10.0+++++++++++++++++++** | HIR `TExprStack` Values/Types + 表达式 token 行表 → TVec on FAllocator |
| 2026-07-16 | **10.0++++++++++++++++++++** | unit resolver `FResolutionStack` + HIR verifier errors/Seen/Defs → TVec |
| 2026-07-16 | **10.0+++++++++++++++++++++** | sema validation CandidateNames/SeenValues → TVec on FAllocator |
| 2026-07-16 | **10.0++++++++++++++++++++++** | preprocessor FStack/FOutputTokens → TVec；session/resolver/sema 注入 scratch |
| 2026-07-16 | **10.0+++++++++++++++++++++++** | unit graph TVec API + topo work；**Detach 产物后改为 default-heap**（见 ++++++++++++++++++++++++++） |
| 2026-07-16 | **10.0++++++++++++++++++++++++** | TDefineTable FEntries → TVec；session/resolver/sema 注入 scratch |
| 2026-07-16 | **10.0+++++++++++++++++++++++++** | FRootIndexes/include paths → TVec on phase scratch；TSearchPathSet API 可选 IAllocator |
| 2026-07-16 | **10.0++++++++++++++++++++++++++** | Detach unit graph/search paths 强制 default-heap Create；禁止挂 FNodeAllocator；guardrail forbid |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++** | GreenTree FInterfaceUses/FImplementationUses/FForeignProcedureDecls → TVec on tree AAllocator |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++** | FToolStatusEvents + file change detector snapshots/changed → session-long TVec |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++** | diagnostics sink FDiagnostics → TDiagnosticRecordVec（session 级默认堆） |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++** | backend plan FArtifacts/FLogicalLibraryRequests → TVec（跨 PhaseScratch 默认堆） |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++** | parallel scheduler FTasks → TCompileTaskVec（session 级默认堆） |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++** | source database FFiles → TSourceFileEntryVec（session 级默认堆） |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++** | query db + workspace package refs + toolchain plan/runner steps → TVec |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++** | lexer FTokens → TTokenVec（TLexerResult 所有权，默认堆） |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++** | HIR module FFunctions/FGlobals/FVmt/FImt/FUnitInitOrder → TVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++** | MIR module FFunctions/FStructTypes → TVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++** | HIR type table FTypes → THirTypeRecVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++** | semantic model 16 产品表 → TVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++** | scheduler FCompileOrder + workspace project unit roots → TVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++** | toolchain planner roots/asm bases + unit resolver root tables → TVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++** | logical link request 三表 + lexer FPendingTrivia → TVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++** | toolchain step Argv/Inputs/Outputs/Sidecars/EnvDelta → TVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++** | sema TNameSet Names → TNameStringVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++** | source database LineOffsets → TSourceLineOffsetVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++** | sema GImportedUnitCache + nested Symbols → TVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++** | HIR type nested Fields/Params/InterfaceIds → TVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++** | HIR VMT/IMT nested Funcs/ThunkNames/ThunkParamCounts → TVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++** | MIR struct nested Fields → TMirStructFieldVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++** | HIR function nested Params → THirParamVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++** | MIR function nested Params → TMirParamVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++** | HIR function nested Blocks → THirBlockVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++** | MIR function nested Blocks → TMirBlockVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++** | MIR block nested Stmts → TMirStmtVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++** | HIR block nested Instrs → THirInstrVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++** | HIR block nested Preds/Succs → THirBlockIdVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | sema type-metadata nested Fields → TSemanticFieldMetaVec 默认堆 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | sema HirExpr nested Children → TSemanticHirChildVec 默认堆 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | sema type-metadata nested VmtSlots → TSemanticVmtSlotVec 默认堆（`np_semantic_vmt_slot_vec` 卫星单元避开 model .o section 上限） |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | sema type-metadata nested Properties → TSemanticPropertyMetaVec 默认堆（`np_semantic_property_meta_vec` 卫星单元） |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | sema type-metadata nested RetPtrMethods → TSemanticStringVec 默认堆（复用 model 内已有 string vec） |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | sema type-metadata nested InterfaceSlots → TSemanticInterfaceSlotMetaVec 默认堆（`np_semantic_interface_slot_vec` 卫星单元） |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | lexer token Leading/TrailingTrivia → TTriviaPieceVec 默认堆（CloneTokenWithTrivia 值拷贝路径） |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | sema type-metadata nested Fields → 卫星单元 `np_semantic_field_meta_vec`（specialize 迁出 model .o，释放 ELF section 余量） |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | product-table dual-track **lane 收敛**：intentional keepers 入文档；model 禁止再塞 nested type-meta `specialize`；ELF 卫星规则 + 审计结论锁定 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | diagnostics nested Related/Fixes/Candidates → TVec 默认堆（analyzer out dynarray 保留；emit clone；sink Destroy Free nested） |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | HIR terminator SwitchCases → THirSwitchCaseVec |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | MIR stmt Args / terminator SwitchCases → TVec |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | sema pending-signature nested ParamNames/ArgTypes → TStringVec |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | unit resolver search-index nested CandidatePaths → TUnitResolverStringVec |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | product-table dual-track **CLOSED**：residual audit；disk cache DTO / local scratch 入 keepers；mem 下一刀离开 dynarray→TVec |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | compiler session/unit `FormatStats` + `CompilerFormat*Stats`；`MemFormatSessionStats` 复用 core 行；诊断可用性 9.3→9.6 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | ops 接线：session 投影 `mem-session-stats` + doctor `mem-process-stats` + envelope JSON；诊断可用性 9.6→9.8 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | arena 契约回归：AST≠scratch、SessionPeak 跨 UnitBegin、FreeMem no-op、entry-owned nested；guardrails 钉 Reset 边界 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | HEAP_DEBUG/插件轨：FormatMemStats debug_allocs/frees；门面 IsMemHeapDebugEnabled；双轨 FormatMemStats 回归；诊断 9.8→9.9 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | CI 常态化 rebuild-compiler：stage0 flags 单源；CI tooling→rebuild→verify；verify 钉 mem-session/process-stats 投影 |
| 2026-07-16 | **10.0+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | HEAP_DEBUG CI 联调：stage0-heap-debug-env-recipe；CI rebuild 后跑；verify 复用；双轨 heap_debug/debug 投影；诊断 9.9→10 |
| 2026-07-16 | **10.0++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++** | lane 收口：默认 focused gate → test_usability_guardrails；文档收敛 CLOSED 主线；Ready 证据矩阵对齐 |
