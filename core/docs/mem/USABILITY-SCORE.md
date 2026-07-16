# nextpas.core.mem 可用性评分（权威）

**评估日期**: 2026-07-17（F1–F7 + R1–R5 修复后）
**范围**: `nextpas.core.mem` 对外默认路径、契约、诊断、上层注入
**对标**: Go `runtime` 分配默认 / Rust `GlobalAlloc` + 标准容器体验（工程可用性，非微基准）
**前序**: 独立基线 **7.7** → F1–F7 **9.1** → 二轮审查 **8.9** → R1–R5 **9.3**
**本轮评估**: [USABILITY-EVAL-2026-07-17.md](USABILITY-EVAL-2026-07-17.md)
**调研/计划**: [USABILITY-FINDINGS-RESEARCH.md](USABILITY-FINDINGS-RESEARCH.md) · [USABILITY-FIX-PLAN.md](USABILITY-FIX-PLAN.md)

历史长报告 [USABILITY-AUDIT.md](USABILITY-AUDIT.md) 已 SUPERSEDED，仅作修复履历。

---

## 综合

| 项 | 值 |
|----|-----|
| **综合分** | **9.3 / 10** |
| **等级** | **HIGH** |
| **趋势** | 7.7 → F1–F7 **9.1** → 二轮审查 8.9 → R1–R5 **9.3**（废除 plus-chain 记分） |
| **风险** | LOW–MEDIUM（热路径双 free 仍默认 UB；需 opt-in SAFETY/DEBUG） |

**结论（一句话）**: 双轨零税默认保留；FormatMemStats 含 heap_safety/arena_strict；FreeMemOf+ReallocMemOf 对称；FormatMemDebugProfile 收敛多 env。产品表 dual-track 主线 **CLOSED**（不 reopen）。

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

**Residual audit（product-table dual-track CLOSED）**: 可迁「清晰单所有权 nested 产品表」已清零。再做 dynarray→TVec 要么是上述 keepers，要么应开独立 package lane；**不要**在 mem worktree 上继续冲 HIR Operands / package DTO 整树当可用性阻塞。

---

## 分维（1–10，独立工程可用性 rubric）

| 维度 | 分 | 依据 |
|------|----|------|
| 默认路径正确性 | **9.5** | Growing 热路径；S5 同堆（Growing IAllocator / `GetGrowingIAllocator`）；H1+H2 RequestArena；compiler phase UnitBegin |
| API 可发现性 | **9.3** | `WithRequestArena` / `HttpRequestAllocatorOf` / `HttpFormatProcessMemStats`；`FreeMemOf`/`ReallocMemOf`；`FormatMemDebugProfile`；门面冻结 |
| 调用一致性 | **9.3** | HTTP Options/H1/H2 与 compiler UnitBegin/End 对称 bulk-reclaim；插件 free/realloc sized 对称；Arena strict |
| 错误模型 | **9.0** | ERROR-POLICY + Try* + TryBlockSize/SC8 + FormatAllocErrorMsg；统一 catch 面文档化 |
| 诊断可用性 | **9.5** | FormatMemStats（`heap_debug`/`heap_safety`/`arena_strict`/`debug_process`/`debug_coverage_gap`）；HEAP_DEBUG + HEAP_SAFETY；CI recipe |
| 契约可证明 | **9.5** | guardrails F1–F7 + R1–R5；contract_matrix；SC9 双轨；source-contract 文档门禁 |
| 性能默认 | **9.4** | 热路径零税；HEAP_DEBUG/SAFETY 默认关 |
| 上层可集成 | **9.5** | hello options → native；compiler session 管线真实 MemAlloc；HttpRequestAllocatorOf |
| **加权综合** | **9.3** | — |

### F1–F7 / R1–R5 修复状态

| ID | 状态 | 证据 |
|----|------|------|
| F1 诊断假阴性 | **fixed** | `debug_process` / `debug_coverage_gap` + guardrails |
| F2 sized free 助手 | **fixed** | `FreeMemOf` / `TryFreeMemOf`（DEBUG wrap 时不绕过 tracking） |
| F3 opt-in safety | **fixed** | `NEXTPAS_MEM_HEAP_DEBUG` / `NEXTPAS_MEM_HEAP_SAFETY` |
| F4 arena strict | **fixed** | `NEXTPAS_MEM_ARENA_STRICT` dual-mode |
| F5 错误助手 | **fixed** | `FormatAllocErrorMsg` / ERROR-POLICY catch 面 |
| F6 门面冻结 | **fixed** | [FACADES-SURFACE.md](FACADES-SURFACE.md) + source check |
| F7 纪律 | **fixed** | 无空 always-true 断言；无 plus-chain 记分 |
| R1 heap_safety 可观测 | **fixed** | FormatMemStats `heap_safety=` |
| R2 arena_strict 可观测 | **fixed** | TMemStats + `arena_strict=` |
| R3 ReallocMemOf | **fixed** | 同 FreeMemOf 门控 + tracking 测试 |
| R4 FormatMemDebugProfile | **fixed** | 标志位一行 profile |
| R5 门禁 | **fixed** | check_usability_docs + guardrails |

---

## Lane 收口状态

**产品主线 CLOSED**（非可用性阻塞）：

| 线 | 状态 |
|----|------|
| compiler product-table dual-track（session/nested TVec） | **CLOSED** — intentional keepers 入文档；勿再冲 HIR Operands / package DTO |
| session/unit `FormatStats` + ops `mem-*-stats` | **落地** |
| arena 契约回归 + HEAP_DEBUG / SAFETY 插件轨 | **落地** |
| CI `rebuild-compiler` + stage0 flags 单源 + HEAP_DEBUG env recipe | **落地** |
| F1–F7 可用性发现 | **落地** |
| R1–R5 残留（stats/realloc/profile） | **落地**（本轮） |

**默认 lane focused gate**（`docs/worktrees.md` / `make lane-focused LANE=mem`）：

```text
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
```

按改动表面追加：`test_debug_wrap` / `make stage0-heap-debug-recipe` / `test_compiler_mem`。

### 仍可演进（独立 lane 或远期，非 mem dual-track 阻塞）

1. package manifest/lock DTO 整树 → TVec：**独立 package lane**。
2. 双轨表面（热 vs 插件）— 设计选择，已文档化（SC9）；不追求合并。
3. 全库历史异常类统一到 `EAllocError` — 爆炸半径大，另开 slice。
4. Scorecard 外部对照 / 更多 host 覆盖 — 性能演进，非可用性阻塞。
