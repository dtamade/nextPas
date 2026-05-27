# Findings & Decisions

## Requirements

- 用户要求继续按路线图推进，但不能再停在碎片化“继续”循环里。
- 用户要求设计和实现都必须建立在真实代码之上，不能空谈现代化。
- 外部审查报告要求优先关闭 `P0` 验证失真，再关闭 `P1` resolver correctness 问题。
- 当前阶段的表述必须诚实：
  已经落地的能力可以明确写，仍然 host-backed 或尚未实现的部分不能包装成已完成。

## Research Findings

- platform 是 L0 系统平台 API/ABI 适配层，负责 OS/CPU、thread、sync、time clock 等低层契约；
  `Stopwatch`、`Duration` 这类用户便利抽象属于 `nextpas.core.time` 或更高层模块，不能作为
  platform 模块成果混入。
- 错误的 `codex/platform-time-extras-preview` 分支只存在于隔离 worktree，尚未合入 main；已删除
  该 worktree/branch，避免 stopwatch 示例污染 platform 收口。
- `platform.time` 的 helper/no-FPC focused tests 原先位于 `core/tests/nextpas.core.time/`，
  这会弱化 L0 platform contract 与 L1 time API 的边界；本批迁入
  `core/tests/nextpas.core.platform.time/`，`nextpas.core.time/test_time` 继续覆盖 L1 public API。
- `core/docs/design-conventions.md` 中 Windows FFI 示例文件名仍写作 `win32.ffi`，与当前真实
  `nextpas.core.platform.windows.ffi.pas` 不一致；同时目标平台描述需要显式包含通用 Unix/BSD
  与 Android。
- `platform.time` 现在通过 nextPas-owned FFI 单元访问平台 ABI：POSIX clock API 位于
  `nextpas.core.platform.posix.ffi`，macOS mach timebase 位于
  `nextpas.core.platform.darwin.ffi`，Windows QPC/FILETIME 位于
  `nextpas.core.platform.windows.ffi`。
- `platform.time` 不再直接 `uses Linux`、`UnixType` 或 `Windows`，也不在实现单元中声明
  `external` ABI；`test_platform_time_no_fpc_units` 固定这个硬规则。
- time conversion helper 现在对不可表示的 UInt64 结果做饱和，对负的 timespec 输入归零，并用
  ceil 计算 frequency resolution，避免对 Windows QPC/macOS timebase 精度做过度承诺。
- QPC / mach timebase 的 fractional multiply/divide 边界已补强：当 divisor 很大导致
  `remainder * multiplier` 会溢出但最终商仍可表示时，走逐位 fallback 而不是直接饱和。
- `build/verify_local.sh` 已提升 platform time focused gates：time helpers、no-FPC 静态检查和 Win64
  compile-only 都会进入 official local verification。
- Batch 104 把 `sema.type-mismatch` evidence 从变量/参数推进到 root-owned 零参 function result：
  `function Flag: Boolean; Pick(Flag);` 调 `Pick(Integer)` 现在会失败且不注册失败 call binding。
- function-result evidence 只接受 root-owned、零参、builtin scalar/string return type；imported、
  带参、member function result、function pointer、class/record/alias/Pointer/Text/Variant 继续 deferred。
- Batch 104 新增 `type-mismatch-function-result-call-check`，用 dedicated fixture 固定 stage0
  `sema.type-mismatch` projection 与 final envelope。
- Batch 104 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `type-mismatch-function-result-call-check=pass`、`typeMismatchFunctionResultCallCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`。
- Batch 131 证明同一条 root-owned 零参 function-result evidence 在 direct class member-call 中
  也已天然成立：`Self.Pick(Flag);` 中 `Pick(Integer)` 与 root-owned `function Flag:
  Boolean` 会失败为 `sema.type-mismatch`，且不注册失败 `member-call` binding。
- 这条边界不需要修改 `compiler/sema/np_semantic_analyzer.pas`：member-call path 已经复用
  `CallArgumentSignatureIsStable(...)` 与 `ExpressionTypeFactIsStable(...)`，因此本轮走
  promotion-first，把 focused truth 提升为 dedicated fixture 和 official verify gate。
- Batch 131 新增 `tests/fixtures/member_type_mismatch_function_result_call` 与
  `member-type-mismatch-function-result-call-check`，final envelope 新增
  `memberTypeMismatchFunctionResultCallCheck":"pass"`。
- Batch 131 fresh `bash build/verify_local.sh` 已输出
  `member-type-mismatch-function-result-call-check=pass`、
  `memberTypeMismatchFunctionResultCallCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 132 证明同一条 root-owned 零参 function-result evidence 在 class method body 内的 bare
  implicit-self method call 中也已天然成立：`procedure TWorker.Run; begin Pick(Flag); end;`
  中，当前 class 的 `Pick(Integer)` 与 root-owned `function Flag: Boolean` 会失败为
  `sema.type-mismatch`，且不注册失败 `member-call` binding。
- 这条边界不需要修改 `compiler/sema/np_semantic_analyzer.pas`：implicit-self bare method fallback
  已经复用 `CallArgumentSignatureIsStable(...)` / `ExpressionTypeFactIsStable(...)` 与既有
  failure propagation；本轮走 promotion-first，把 focused truth 提升为 dedicated fixture 和
  official verify gate。
- Batch 132 新增
  `tests/fixtures/implicit_self_bare_method_function_result_type_mismatch` 与
  `implicit-self-bare-method-function-result-type-mismatch-check`，final envelope 新增
  `implicitSelfBareMethodFunctionResultTypeMismatchCheck":"pass"`。
- Batch 132 fresh `bash build/verify_local.sh` 已输出
  `implicitSelfBareMethodFunctionResultTypeMismatchCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 133 固定下一轮加速方法：沿 G1.5/G1.6 的同一路径矩阵补格，优先选相邻批次已经证明
  failure propagation / stable evidence 成熟的缺口；先 focused probe，GREEN 就 promotion 到 official
  gate，RED 才做最小 analyzer 修复。
- Batch 133 证明 exact current-class bare implicit-self method call 的普通 literal mismatch 已天然成立：
  `procedure TWorker.Run; begin Pick(True); end;` 中，当前 class 的 `Pick(Integer)` 与 Boolean literal
  会失败为 `sema.type-mismatch`，且不注册失败 `member-call` binding。
- 这条边界不需要修改 `compiler/sema/np_semantic_analyzer.pas`：Batch 126 的 implicit-self failure
  propagation 与 stable literal argument signature 已覆盖 current class exact method target。
- Batch 133 新增 `tests/fixtures/implicit_self_bare_method_type_mismatch` 与
  `implicit-self-bare-method-type-mismatch-check`，final envelope 新增
  `implicitSelfBareMethodTypeMismatchCheck":"pass"`。
- Batch 133 fresh `bash build/verify_local.sh` 已输出
  `implicit-self-bare-method-type-mismatch-check=pass`、
  `implicitSelfBareMethodTypeMismatchCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 134 继续同路径诊断矩阵补格：exact current-class bare implicit-self method call
  `procedure TWorker.Run; begin Pick; end;` 中，当前 class 的 `Pick(Integer)` 会失败为
  `sema.wrong-argument-count`，且不注册失败 `member-call` binding。
- 这条边界不需要修改 `compiler/sema/np_semantic_analyzer.pas`：Batch 126/127 的 implicit-self
  failure propagation 已覆盖 current class root-owned method target 的 arity miss。
- Batch 134 新增 `tests/fixtures/implicit_self_bare_method_wrong_argument_count` 与
  `implicit-self-bare-method-wrong-argument-count-check`，final envelope 新增
  `implicitSelfBareMethodWrongArgumentCountCheck":"pass"`。
- Batch 134 fresh `bash build/verify_local.sh` 已输出
  `implicit-self-bare-method-wrong-argument-count-check=pass`、
  `implicitSelfBareMethodWrongArgumentCountCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 135 继续同路径诊断矩阵补格：exact current-class bare implicit-self method call
  `procedure TWorker.Run; begin Pick(True); end;` 中，当前 class 的 `Pick(Integer)` /
  `Pick(AnsiString)` overload set 会失败为 `sema.no-matching-overload`，且不注册失败
  `member-call` binding。
- 这条边界不需要修改 `compiler/sema/np_semantic_analyzer.pas`：Batch 126/128 的 implicit-self
  failure propagation 已覆盖 current class root-owned overload set 的 stable signature no-match。
- Batch 135 新增 `tests/fixtures/implicit_self_bare_method_no_matching_overload` 与
  `implicit-self-bare-method-no-matching-overload-check`，final envelope 新增
  `implicitSelfBareMethodNoMatchingOverloadCheck":"pass"`。
- Batch 135 fresh `bash build/verify_local.sh` 已输出
  `implicit-self-bare-method-no-matching-overload-check=pass`、
  `implicitSelfBareMethodNoMatchingOverloadCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 136 继续同路径诊断矩阵补格：exact current-class bare implicit-self method call
  `procedure TWorker.Run; begin Pick(1); end;` 中，当前 class 的 `Pick(Integer)` /
  `Pick(LongInt)` overload set 会失败为 `sema.ambiguous-overload`，且不注册失败
  `member-call` binding。
- 这条边界不需要修改 `compiler/sema/np_semantic_analyzer.pas`：Batch 126/129 的 implicit-self
  failure propagation 已覆盖 current class root-owned overload set 的 compact signature collision。
- Batch 136 新增 `tests/fixtures/implicit_self_bare_method_ambiguous_overload` 与
  `implicit-self-bare-method-ambiguous-overload-check`，final envelope 新增
  `implicitSelfBareMethodAmbiguousOverloadCheck":"pass"`。
- Batch 136 fresh `bash build/verify_local.sh` 已输出
  `implicit-self-bare-method-ambiguous-overload-check=pass`、
  `implicitSelfBareMethodAmbiguousOverloadCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 137 继续补 imported bare callable 诊断矩阵：root source 没有同名 callable、imported
  `project-source` unit 中存在单一 `procedure Pick(Value: Integer)`，但 root 调用 `Pick;`
  时会失败为 `sema.wrong-argument-count`，且不注册失败 `call` binding。
- 这条边界不需要修改 `compiler/sema/np_semantic_analyzer.pas`：既有 imported project-source
  callable lookup 已能把 single-target arity miss 透传成 `wrong-argument-count`。
- Batch 137 新增 `tests/fixtures/imported_wrong_argument_count` 与
  `imported-wrong-argument-count-check`，final envelope 新增
  `importedWrongArgumentCountCheck":"pass"`。
- Batch 137 fresh `bash build/verify_local.sh` 已输出
  `imported-wrong-argument-count-check=pass`、
  `importedWrongArgumentCountCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 138 把 Batch 137 的 installed-source 防误报护栏补齐：imported `installed-source`
  single-target bare callable arity miss（例如 installed `Helper.Pick(Integer)` 面对 root `Pick;`）
  必须保持 deferred，不发 `sema.wrong-argument-count`，也不注册错误 `call` binding。
- RED focused 证明旧实现会误报
  `sema.wrong-argument-count`；`LookupCallBindingDeclaration(...)` 现在只在 imported callable
  owner 允许 project-source diagnostics 时，才把 imported arity miss 投影为
  `wrong-argument-count`。
- Batch 138 fresh `bash build/verify_local.sh` 已输出
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、`verify-local=pass`
  与 `human-summary=local verification passed`；本批没有修改 `core/`。
- Batch 139 把 imported bare callable ambiguity 的 installed-source 防误报护栏补齐：两个
  `installed-source` helper 同时提供 `Pick(Integer)` 且 root 调用 `Pick(1);` 时，必须保持保守
  跳过，不发 `sema.ambiguous-overload`，也不注册错误 `call` binding。
- RED focused 证明旧实现会误报
  `sema.ambiguous-overload`；`LookupCallBindingDeclaration(...)` 现在只在 imported signature
  match 候选中至少两个来自 project-source owner 时，才把 imported ambiguity 投影为
  `ambiguous-overload`。
- 无 signature 的 imported ambiguity 判定必须按同 arity match 的 project-source 候选数判断，
  不能只按同名 project-source 候选数判断；否则 mixed installed/project-source overload set 可能
  在缺少稳定 signature 时误报。
- Batch 139 fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 `core/`。
- Batch 140 选定加速路线的下一格：project-source imported bare no-match 已有 official
  `imported-no-matching-overload-check`，本轮补 installed-source deferred guard，避免两个
  installed-source helper 的 incomplete overload set 被提前报成 `sema.no-matching-overload`。
- RED focused 证明旧实现会误报 `sema.no-matching-overload`；`LookupCallBindingDeclaration(...)`
  现在只在 imported same-arity candidate set 全部来自允许 project-source diagnostics 的 owner
  时，才把 imported no-match 投影为 `no-matching-overload`。
- Batch 140 fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 `core/`。
- Batch 141 选定同一路线下一格：source-owned bare `unknown-callable` 已有 official
  `unknown-callable-check`，但 installed-source imports 表示当前 imported callable truth 可能不完整；
  此时 root bare name miss 应保守 deferred，避免把 helper/RTL 缺口提前报成普通 unknown callable。
- RED focused 证明旧实现会误报 `sema.unknown-callable`；`LookupCallBindingDeclaration(...)`
  现在只在当前 unit graph 没有 installed-source imports 时，才把 bare name miss 投影为
  `unknown-callable`。
- Batch 141 focused semantic 已输出 `semantic-call-bindings-status=pass`；fresh local verification
  已输出 `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`；本批没有修改 `core/`。
- Batch 142 固定新的提速思路为“语义诊断矩阵单元流水线”：每轮先写 `/plan`，选同族相邻成熟格子，
  focused probe 判真相；GREEN 就 promotion 到 official stage0 gate，RED 才改 analyzer。
- Batch 142 选定 inherited implicit-self bare method + function-result type mismatch：`TWorker.Run`
  中裸调用 parent `Touch(Flag)`，其中 `Touch(Integer)` 来自 `TBaseWorker`，`Flag` 是 root-owned
  `Boolean` function result。
- Focused probe 证明该能力已经由 Batch 126 的 inherited implicit-self failure propagation 与
  Batch 132 的 function-result stable evidence 天然覆盖：输出 `semantic-call-bindings-status=pass`，
  本批不修改 analyzer。
- Batch 142 新增 dedicated fixture 与
  `inherited-implicit-self-bare-method-function-result-type-mismatch-check`，final envelope 新增
  `inheritedImplicitSelfBareMethodFunctionResultTypeMismatchCheck":"pass"`。
- Batch 142 fresh `bash build/verify_local.sh` 已输出
  `inherited-implicit-self-bare-method-function-result-type-mismatch-check=pass`、
  `inheritedImplicitSelfBareMethodFunctionResultTypeMismatchCheck":"pass"`、
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、`verify-local=pass`
  与 `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 143 把提速方法收紧为“组合成熟格单元流水线”：优先把两个已验证能力组合成一个新矩阵格，
  focused probe 先判真相，GREEN 直接 promotion，RED 才改 analyzer。
- Batch 143 组合 Batch 104 的 root-owned 零参 function-result stable evidence 与 Batch 108 的
  imported `project-source` bare callable single-target mismatch：root `Flag: Boolean` 调 imported
  `Helper.Pick(Integer)` 会失败为 `sema.type-mismatch`，且不注册失败 `call` binding。
- Focused probe 证明该组合能力已经天然成立：`LookupCallBindingDeclaration(...)` 的 imported
  `project-source` type-mismatch projection 已接收 `CallArgumentSignatureIsStable(...)` 给出的
  root-owned function-result evidence；本批不修改 analyzer。
- Batch 143 新增 `tests/fixtures/imported_function_result_type_mismatch_call` 与
  `imported-function-result-type-mismatch-call-check`，final envelope 新增
  `importedFunctionResultTypeMismatchCallCheck":"pass"`。
- Batch 143 fresh `bash build/verify_local.sh` 已输出
  `imported-function-result-type-mismatch-call-check=pass`、
  `importedFunctionResultTypeMismatchCallCheck":"pass"`、
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、`verify-local=pass`
  与 `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 144 继续“组合成熟格单元流水线”：把 Batch 109 的 imported direct member single-target
  mismatch 与 Batch 131 的 root-owned function-result member-call evidence 组合成新 gate。
- Batch 144 证明 imported `project-source` direct member-call 也已天然接受 root-owned function-result
  stable evidence：root `Flag: Boolean` 调 imported `Worker.Pick(Integer)` 会失败为
  `sema.type-mismatch`，且不注册失败 `member-call` binding。
- 该能力不需要修改 analyzer：direct member-call path 已经把 `CallArgumentSignatureIsStable(...)`
  的 evidence 传给 `MethodSymbolIdForClassTypeMember(...)`，后者的 imported `project-source`
  type-mismatch provenance gate 已覆盖该组合。
- Batch 144 新增 `tests/fixtures/imported_member_function_result_type_mismatch_call` 与
  `imported-member-function-result-type-mismatch-call-check`，final envelope 新增
  `importedMemberFunctionResultTypeMismatchCallCheck":"pass"`。
- Batch 144 fresh `bash build/verify_local.sh` 已输出
  `imported-member-function-result-type-mismatch-call-check=pass`、
  `importedMemberFunctionResultTypeMismatchCallCheck":"pass"`、
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、`verify-local=pass`
  与 `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 160 把 Batch 144 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  direct member single-target mismatch 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.type-mismatch`，也不注册错误 `member-call` binding。
- Batch 160 focused probe 直接 GREEN：direct member-call path 的 provenance gate 已经阻止
  installed-source direct member function-result type-mismatch 被提前投影为 ordinary type mismatch；本批不修改 analyzer。
- installed-source direct member function-result type-mismatch 的 official proof 只能放在 semantic harness 中用
  `TUnitGraph` 显式标记 `ruoInstalledSource`；普通 stage0 fixture 会把 sibling unit 当作 workspace
  project-source，不能证明 installed-source provenance。
- Batch 145 继续“成熟格组合流水线”：把 Batch 117 的 imported inherited direct member
  single-target mismatch 与 Batch 144 的 imported member root-owned function-result evidence 组合成新 gate。
- Batch 145 focused probe 证明 imported `project-source` inherited direct member-call 也已天然接受
  root-owned function-result stable evidence：root `Flag: Boolean` 调 imported parent
  `TBase.Pick(Integer)` 会失败为 `sema.type-mismatch`，且不注册失败 `member-call` binding。
- 该能力不需要修改 analyzer：parent-chain member-call path 已经把
  `CallArgumentSignatureIsStable(...)` 的 evidence 传给 imported `project-source`
  single-target type-mismatch provenance gate。
- Batch 145 新增 `tests/fixtures/imported_inherited_member_function_result_type_mismatch_call` 与
  `imported-inherited-member-function-result-type-mismatch-call-check`，final envelope 新增
  `importedInheritedMemberFunctionResultTypeMismatchCallCheck":"pass"`。
- Batch 145 fresh `bash build/verify_local.sh` 已输出
  `imported-inherited-member-function-result-type-mismatch-call-check=pass`、
  `importedInheritedMemberFunctionResultTypeMismatchCallCheck":"pass"`、
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、`verify-local=pass`
  与 `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 146 把 Batch 145 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  inherited member single-target mismatch 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.type-mismatch`，也不注册错误 `member-call` binding。
- Focused semantic guard 使用 `TUnitGraph` 显式标记 `Worker` 为 `ruoInstalledSource`；普通 stage0 fixture
  不能证明这条 owner provenance，因为 sibling unit 会按 workspace truth 进入 project-source。
- Batch 146 focused probe 直接 GREEN：parent-chain member-call path 的 provenance gate 已经阻止
  installed-source inherited member function-result mismatch 被提前投影为 ordinary type mismatch；本批不修改 analyzer。
- Batch 146 fresh `bash build/verify_local.sh` 已输出
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、`verify-local=pass`
  与 `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 147 继续“成熟格组合流水线”：把 Batch 114 的 imported inherited
  `project-source` overload-set no-match 与 Batch 145 的 root-owned function-result stable evidence
  组合成新 gate。
- Batch 147 focused probe 已直接 GREEN：root `Flag: Boolean` 调 imported parent overload set
  `TBase.Pick(Integer)` / `TBase.Pick(AnsiString)` 会失败为 `sema.no-matching-overload`，
  semantic model 为 `failure`，且不注册失败 `member-call` binding。
- 该能力不需要修改 analyzer：parent-chain member-call path 已经把
  `CallArgumentSignatureIsStable(...)` 的 root-owned function-result evidence 传给 imported
  `project-source` overload-set no-match projection。
- Batch 147 新增 `tests/fixtures/imported_inherited_member_function_result_no_matching_overload` 与
  `imported-inherited-member-function-result-no-matching-overload-check`，final envelope 新增
  `importedInheritedMemberFunctionResultNoMatchingOverloadCheck":"pass"`。
- Batch 147 fresh `bash build/verify_local.sh` 已输出
  `imported-inherited-member-function-result-no-matching-overload-check=pass`、
  `importedInheritedMemberFunctionResultNoMatchingOverloadCheck":"pass"`、
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、`verify-local=pass`
  与 `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 149 证明 root-owned 零参 builtin function-result evidence 也能穿过 imported
  `project-source` inherited member-call ambiguity：`Worker.Pick(Count)` 面对 parent chain 中
  `Pick(Integer)` / `Pick(LongInt)` 的 compact signature collision 会失败为
  `sema.ambiguous-overload`，且不注册失败 `member-call` binding。
- 该能力不需要修改 analyzer：parent-chain member-call path 已经把
  `CallArgumentSignatureIsStable(...)` 的 root-owned function-result evidence 传给 imported
  `project-source` overload-set ambiguity projection。
- Batch 149 新增
  `tests/fixtures/imported_inherited_member_function_result_ambiguous_overload` 与
  `imported-inherited-member-function-result-ambiguous-overload-check`，final envelope 新增
  `importedInheritedMemberFunctionResultAmbiguousOverloadCheck":"pass"`。
- Batch 150 把 Batch 149 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  inherited member overload-set ambiguity 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.ambiguous-overload`，也不注册错误 `member-call` binding。
- Batch 150 focused probe 直接 GREEN：parent-chain member-call path 的 provenance gate 已经阻止
  installed-source inherited member function-result ambiguity 被提前投影为 ordinary ambiguity；本批不修改 analyzer。
- installed-source function-result ambiguity 的 official proof 只能放在 semantic harness 中用
  `TUnitGraph` 显式标记 `ruoInstalledSource`；普通 stage0 fixture 会把 sibling unit 当作 workspace
  project-source，不能证明 installed-source provenance。
- Batch 151 把 Batch 143 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  bare callable single-target mismatch 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.type-mismatch`，也不注册错误 `call` binding。
- Batch 151 focused probe 直接 GREEN：bare callable path 的 provenance gate 已经阻止 installed-source
  bare function-result mismatch 被提前投影为 ordinary type mismatch；本批不修改 analyzer。
- installed-source bare function-result mismatch 的 official proof 只能放在 semantic harness 中用
  `TUnitGraph` 显式标记 `ruoInstalledSource`；普通 stage0 fixture 会把 sibling unit 当作 workspace
  project-source，不能证明 installed-source provenance。
- Batch 151 fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 152 继续“同族成熟格交叉流水线”：把 Batch 140 的 imported bare callable overload-set
  no-match 与 Batch 143/151 的 root-owned function-result stable evidence 组合成新 gate。
- Batch 152 focused probe 已直接 GREEN：root `Flag: Boolean` 调 imported `project-source` overload set
  `Pick(Integer)` / `Pick(AnsiString)` 会失败为 `sema.no-matching-overload`，semantic model
  为 `failure`，且不注册失败 `call` binding。
- 该能力不需要修改 analyzer：bare callable path 已经把
  `CallArgumentSignatureIsStable(...)` 的 root-owned function-result evidence 传给 imported
  `project-source` overload-set no-match projection。
- Batch 152 新增 `tests/fixtures/imported_function_result_no_matching_overload` 与
  `imported-function-result-no-matching-overload-check`，final envelope 新增
  `importedFunctionResultNoMatchingOverloadCheck":"pass"`。
- Batch 152 fresh `bash build/verify_local.sh` 已输出
  `imported-function-result-no-matching-overload-check=pass`、
  `importedFunctionResultNoMatchingOverloadCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 153 把 Batch 152 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  bare callable overload-set no-match 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.no-matching-overload`，也不注册错误 `call` binding。
- Batch 153 focused probe 直接 GREEN：bare callable path 的 provenance gate 已经阻止 installed-source
  bare function-result no-match 被提前投影为 ordinary no-match；本批不修改 analyzer。
- installed-source bare function-result no-match 的 official proof 只能放在 semantic harness 中用
  `TUnitGraph` 显式标记 `ruoInstalledSource`；普通 stage0 fixture 会把 sibling unit 当作 workspace
  project-source，不能证明 installed-source provenance。
- Batch 153 fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 154 继续“同族成熟格交叉流水线”：把 Batch 139 的 imported bare callable ambiguity 与
  Batch 143/152/153 的 root-owned function-result stable evidence 组合成新 gate。
- Batch 154 focused probe 直接 GREEN：root `Count: Integer` 调 imported `project-source` overload set
  `Pick(Integer)` / `Pick(LongInt)` 会失败为 `sema.ambiguous-overload`，semantic model 为
  `failure`，且不注册失败 `call` binding。
- 该能力不需要修改 analyzer：bare callable path 已经把 root-owned function-result evidence 传给 imported
  `project-source` overload-set ambiguity projection。
- Batch 154 新增 `tests/fixtures/imported_function_result_ambiguous_overload` 与
  `imported-function-result-ambiguous-overload-check`，final envelope 新增
  `importedFunctionResultAmbiguousOverloadCheck":"pass"`。
- Batch 154 fresh `bash build/verify_local.sh` 已输出
  `imported-function-result-ambiguous-overload-check=pass`、
  `importedFunctionResultAmbiguousOverloadCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 155 把 Batch 154 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  bare callable overload-set ambiguity 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.ambiguous-overload`，也不注册错误 `call` binding。
- Batch 155 focused probe 直接 GREEN：bare callable path 的 provenance gate 已经阻止 installed-source
  bare function-result ambiguity 被提前投影为 ordinary ambiguity；本批不修改 analyzer。
- installed-source bare function-result ambiguity 的 official proof 只能放在 semantic harness 中用
  `TUnitGraph` 显式标记 `ruoInstalledSource`；普通 stage0 fixture 会把 sibling unit 当作 workspace
  project-source，不能证明 installed-source provenance。
- Batch 155 fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 156 继续“同族成熟格交叉流水线”：把 Batch 110 的 imported direct member
  overload-set no-match 与 Batch 144 的 direct member root-owned function-result evidence 组合成新 gate。
- Batch 156 focused probe 已直接 GREEN：root `Flag: Boolean` 调 imported `project-source`
  direct member overload set `TWorker.Pick(Integer)` / `TWorker.Pick(AnsiString)` 会失败为
  `sema.no-matching-overload`，semantic model 为 `failure`，且不注册失败 `member-call` binding。
- 该能力不需要修改 analyzer：direct member-call path 已经把 root-owned function-result evidence
  传给 imported `project-source` overload-set no-match projection。
- Batch 156 新增 `tests/fixtures/imported_member_function_result_no_matching_overload` 与
  `imported-member-function-result-no-matching-overload-check`，final envelope 新增
  `importedMemberFunctionResultNoMatchingOverloadCheck":"pass"`。
- Batch 157 继续同族矩阵连打：把 Batch 115/154 的 ambiguity projection 与 Batch 156
  刚固定的 direct imported member function-result evidence 组合成 official gate。
- Batch 157 focused probe 已直接 GREEN：root `Count: Integer` 调 imported `project-source`
  direct member overload set `TWorker.Pick(Integer)` / `TWorker.Pick(LongInt)` 会失败为
  `sema.ambiguous-overload`，semantic model 为 `failure`，且不注册失败 `member-call` binding。
- 该能力不需要修改 analyzer：direct member-call path 已经把 root-owned function-result evidence
  传给 imported `project-source` overload-set ambiguity projection。
- Batch 157 新增 `tests/fixtures/imported_member_function_result_ambiguous_overload` 与
  `imported-member-function-result-ambiguous-overload-check`，final envelope 新增
  `importedMemberFunctionResultAmbiguousOverloadCheck":"pass"`。
- Batch 158 把 Batch 157 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  direct member overload-set ambiguity 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.ambiguous-overload`，也不注册错误 `member-call` binding。
- Batch 158 focused probe 直接 GREEN：direct member-call path 的 provenance gate 已经阻止
  installed-source direct member function-result ambiguity 被提前投影为 ordinary ambiguity；本批不修改 analyzer。
- installed-source direct member function-result ambiguity 的 official proof 只能放在 semantic harness 中用
  `TUnitGraph` 显式标记 `ruoInstalledSource`；普通 stage0 fixture 会把 sibling unit 当作 workspace
  project-source，不能证明 installed-source provenance。
- Batch 159 把 Batch 156 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  direct member overload-set no-match 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.no-matching-overload`，也不注册错误 `member-call` binding。
- Batch 159 focused probe 直接 GREEN：direct member-call path 的 provenance gate 已经阻止
  installed-source direct member function-result no-match 被提前投影为 ordinary no-match；本批不修改 analyzer。
- installed-source direct member function-result no-match 的 official proof 只能放在 semantic harness 中用
  `TUnitGraph` 显式标记 `ruoInstalledSource`；普通 stage0 fixture 会把 sibling unit 当作 workspace
  project-source，不能证明 installed-source provenance。
- Batch 161 把 direct imported member function-result 家族扩到 arity miss：root `Flag: Boolean`
  作为两个 arguments 调 imported `project-source` 单一 `TWorker.Pick(Integer)` 时，会失败为
  `sema.wrong-argument-count`，semantic model 为 `failure`，且不注册失败 `member-call` binding。
- Batch 161 focused probe 与 stage0 probe 都直接 GREEN，证明 direct member-call path 已能把
  root-owned function-result evidence 传给 imported `project-source` arity projection；本批不修改 analyzer。
- Batch 161 新增 `tests/fixtures/imported_member_function_result_wrong_argument_count` 与
  `imported-member-function-result-wrong-argument-count-check`，final envelope 新增
  `importedMemberFunctionResultWrongArgumentCountCheck":"pass"`。
- Batch 162 把 Batch 161 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  direct member single-target arity miss 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.wrong-argument-count`，也不注册错误 `member-call` binding。
- Batch 162 focused probe 直接 GREEN：direct member-call path 的 provenance guard 已经阻止
  installed-source direct member function-result arity miss 被提前投影为 ordinary wrong-argument-count；本批不修改 analyzer。
- installed-source direct member function-result wrong-argument-count 的 official proof 只能放在
  semantic harness 中用 `TUnitGraph` 显式标记 `ruoInstalledSource`；普通 stage0 fixture 会把
  sibling unit 当作 workspace project-source，不能证明 installed-source provenance。
- Batch 148 把 Batch 147 的成对 installed-source 防误报护栏补齐：imported `installed-source`
  inherited member overload-set no-match 即使面对 root-owned function-result evidence，也必须保持
  deferred，不发 `sema.no-matching-overload`，也不注册错误 `member-call` binding。
- Batch 148 focused probe 直接 GREEN：parent-chain member-call path 的 provenance gate 已经阻止
  installed-source inherited member function-result no-match 被提前投影为 ordinary no-match；本批不修改 analyzer。
- Batch 108 把 imported bare single-target signature mismatch 接进 structured diagnostics：
  root source 没有同名 callable、imported `project-source` unit 中只有一个同 arity target，且稳定
  argument signature 与 target param signature 明确不兼容时，`Pick(True)` 会失败为
  `sema.type-mismatch`，且不注册失败 call binding。
- Batch 108 同时固定 imported `installed-source` single-target mismatch 继续 deferred；它不会再错误
  binding，也不会提前报 `sema.type-mismatch`。
- Batch 108 新增 `imported-type-mismatch-call-check`，用 dedicated fixture 固定 stage0
  `sema.type-mismatch` projection 与 final envelope `importedTypeMismatchCallCheck=pass`。
- Batch 108 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `imported-type-mismatch-call-check=pass`、`importedTypeMismatchCallCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`。
- Batch 109 把 imported direct member-call single-target signature mismatch 接进 structured diagnostics：
  receiver type 已知、imported `project-source` unit 的 exact class type 中只有一个同 arity
  member target、且稳定 argument signature 与 target param signature 明确不兼容时，
  `Worker.Pick(True)` 会失败为 `sema.type-mismatch`，且不注册失败 `member-call` binding。
- Batch 109 同时固定 imported `installed-source` member single-target mismatch 继续 deferred；
  它不会再错误 binding，也不会提前报 `sema.type-mismatch`。
- Batch 109 新增 `imported-member-type-mismatch-call-check`，用 dedicated fixture 固定 stage0
  `sema.type-mismatch` projection 与 final envelope `importedMemberTypeMismatchCallCheck=pass`。
- Batch 109 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `imported-member-type-mismatch-call-check=pass`、
  `importedMemberTypeMismatchCallCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`。
- Batch 110 把 imported direct member-call overload-set signature no-match 接进 structured diagnostics：
  receiver type 已知、imported `project-source` unit 的 exact class type 中存在多个同 arity member
  target、且稳定 argument signature 与所有 candidate signature 都不匹配时，`Worker.Pick(True)` 会失败为
  `sema.no-matching-overload`，且不注册失败 `member-call` binding。
- Batch 110 同时固定 imported `installed-source` member overload-set no-match 继续 deferred；它不会错误
  binding，也不会提前报 `sema.no-matching-overload`。
- Batch 110 新增 `imported-member-no-matching-overload-check`，用 dedicated fixture 固定 stage0
  `sema.no-matching-overload` projection 与 final envelope `importedMemberNoMatchingOverloadCheck=pass`。
- Batch 111 把 imported direct member-call 的 source-owned name miss 正式纳入 gate：receiver type 已知、
  imported `project-source` unit 的 exact class / parent chain 不存在同名 method 时，
  `Worker.Missing(1)` 会失败为 `sema.unknown-member`，且不注册失败 `member-call` binding。
- Batch 111 同时把 imported `installed-source` member unknown-member 收回 deferred；它不会错误 binding，
  也不会把 `System` / runtime baseline 或 helper surface 提前报成 ordinary unknown member。
- Batch 111 新增 `imported-unknown-member-check`，用 dedicated fixture 固定 stage0
  `sema.unknown-member` projection 与 final envelope `importedUnknownMemberCheck=pass`。
- Batch 112 把 imported direct member-call 的 source-owned arity miss 正式纳入 gate：receiver type 已知、
  imported `project-source` unit 的 exact class / parent chain 存在同名 method，但没有任何
  visible member target 的参数个数与 call 匹配时，`Worker.Pick(1, 2)` 会失败为
  `sema.wrong-argument-count`，且不注册失败 `member-call` binding。
- Batch 112 同时把 imported `installed-source` member wrong-argument-count 收回 deferred；它不会错误
  binding，也不会把 helper / runtime baseline 的 incomplete imported truth 提前报成 ordinary
  arity error。
- `MethodSymbolIdForExactClassTypeMember(...)` 的 `wrong-argument-count` 分支现在也受 owner provenance
  guard 约束：只有 root source 或 imported `project-source` owner 才允许落诊断，`installed-source`
  继续保守 deferred。
- Batch 112 新增 `imported-member-wrong-argument-count-check`，用 dedicated fixture 固定 stage0
  `sema.wrong-argument-count` projection 与 final envelope
  `importedMemberWrongArgumentCountCheck=pass`。
- Batch 113 把 root-owned inherited direct member-call 的 stable signature no-match 正式纳入 gate：
  exact receiver type 自身没有同名 method、但 parent chain 上存在同名同 arity 的多个 member target，
  且当前稳定 argument signature 与所有 inherited candidate 都不匹配时，`Worker.Pick(True)` 会失败为
  `sema.no-matching-overload`，且不注册失败 `member-call` binding。
- Batch 113 只打开 root-owned inherited member no-match；imported inherited path 继续 deferred，
  不会被这轮顺手放开。
- `MethodSymbolIdForClassTypeMember(...)` 现在对 `no-matching-overload` 的 parent-chain gate 做了
  root-owned 限定：exact receiver 仍可诊断；parent depth 只有 current type owner 属于 root source 时
  才允许 inherited no-match 投影成 structured diagnostic。
- Batch 113 新增 `inherited-member-no-matching-overload-check`，用 dedicated fixture 固定 stage0
  `sema.no-matching-overload` projection 与 final envelope
  `inheritedMemberNoMatchingOverloadCheck=pass`。
- Batch 114 把 imported `project-source` inherited direct member-call 的 stable signature no-match 正式纳入 gate：
  exact receiver type 自身没有同名 method、parent chain 上存在同名同 arity 的多个 inherited member target，
  且当前稳定 argument signature 与所有 inherited candidate 都不匹配时，`Worker.Pick(True)` 会失败为
  `sema.no-matching-overload`，且不注册失败 `member-call` binding。
- Batch 114 同时固定 imported `installed-source` inherited member no-match 继续 deferred；它不会错误
  binding，也不会把 helper / runtime baseline 的 incomplete imported truth 提前报成 ordinary
  overload failure。
- `MethodSymbolIdForClassTypeMember(...)` 现在对 parent-chain `AAllowNoMatchingOverloadDiagnostic`
  采用 root source + imported `project-source` provenance guard：exact receiver 仍可诊断；parent depth
  只有 current type owner 属于 root source 或 imported `project-source` 时才允许 inherited no-match
  投影成 structured diagnostic。
- Batch 114 新增 `imported-inherited-member-no-matching-overload-check`，用 dedicated fixture 固定
  stage0 `sema.no-matching-overload` projection 与 final envelope
  `importedInheritedMemberNoMatchingOverloadCheck=pass`。
- Batch 115 把 imported `project-source` inherited direct member-call 的 ambiguity 正式纳入 gate：
  exact receiver type 自身没有同名 method、parent chain 上存在同名同 arity 的多个 inherited member target，
  且当前稳定 argument signature 无法唯一选择候选时，`Worker.Pick(1)` 会失败为
  `sema.ambiguous-overload`，且不注册失败 `member-call` binding。
- Batch 115 同时固定 imported `installed-source` inherited ambiguity 继续 deferred；它不会错误 binding，
  也不会把 helper / runtime baseline 的 incomplete imported truth 提前报成 ordinary ambiguity。
- `MethodSymbolIdForExactClassTypeMember(...)` 的 ambiguity 分支现在受 owner provenance guard 约束：
  只有 root source 或 imported `project-source` owner 才允许落 `ambiguous-overload`，其余 imported owner
  继续保守 deferred。
- Batch 115 新增 `imported-inherited-member-ambiguous-overload-check`，用 dedicated fixture 固定 stage0
  `sema.ambiguous-overload` projection 与 final envelope
  `importedInheritedMemberAmbiguousOverloadCheck=pass`。
- imported inherited `project-source` 的 wrong-argument-count 在当前实现里已经天然成立：对
  `TWorker = class(TBase)` 且 `TBase.Pick(Integer)` 可见的场景，`Worker.Pick(1, 2)` 的 stage0 build
  会直接输出 `sema.wrong-argument-count`，不需要再改 `compiler/sema/np_semantic_analyzer.pas`。
- imported inherited `installed-source` wrong-argument-count 也继续保持 deferred：由于
  `MethodSymbolIdForExactClassTypeMember(...)` 的 arity miss 分支仍受 owner provenance guard 约束，
  installed-source parent owner 不会被提前投影成 ordinary arity diagnostic。
- Batch 116 新增
  `tests/fixtures/imported_inherited_member_wrong_argument_count` 与
  `imported-inherited-member-wrong-argument-count-check`，把这条已存在行为正式纳入 final envelope
  `importedInheritedMemberWrongArgumentCountCheck=pass`。
- imported inherited `project-source` 的 type-mismatch 在当前实现里也已经天然成立：对
  `TWorker = class(TBase)` 且 `TBase.Pick(Integer)` 可见的场景，`Worker.Pick(True)` 的 stage0 build
  会直接输出 `sema.type-mismatch`，不需要再改 `compiler/sema/np_semantic_analyzer.pas`。
- imported inherited `installed-source` type-mismatch 继续保持 deferred；这和 imported exact member /
  imported inherited wrong-argument-count 的 provenance 策略一致，避免把 incomplete imported truth
  提前投影成 ordinary type mismatch。
- Batch 117 新增
  `tests/fixtures/imported_inherited_member_type_mismatch_call` 与
  `imported-inherited-member-type-mismatch-call-check`，把这条已存在行为正式纳入 final envelope
  `importedInheritedMemberTypeMismatchCallCheck=pass`。
- imported inherited `project-source` 的 unknown-member 在当前实现里也已经天然成立：对
  `TWorker = class(TBase)` 且 parent chain 中不存在 `Missing` 的场景，`Worker.Missing(1)` 的
  semantic regression 与 stage0 build 都会直接输出 `sema.unknown-member`，不需要再改
  `compiler/sema/np_semantic_analyzer.pas`。
- imported inherited `installed-source` unknown-member 继续保持 deferred；focused semantic regression
  证明 `ruoInstalledSource` parent owner 不会被提前投影成 ordinary unknown-member，也不会注册错误
  `member-call` binding。
- Batch 118 新增 `tests/fixtures/imported_inherited_unknown_member` 与
  `imported-inherited-unknown-member-check`，把这条已存在行为正式纳入 final envelope
  `importedInheritedUnknownMemberCheck=pass`。
- 同一家族 sema diagnostics 的加速办法已经更具体了：对只差 provenance / inherited / imported 的相邻
  边界，先做 probe；若能力天然成立，就直接 promotion 到 official gate；只有 probe 失败时才进入最小实现修复。
- 为加快 nextPas 的 sema 热点开发，后续轮次固定采用 `/plan -> 单刀目标 -> RED -> 根因定位 ->
  最小修复 -> focused GREEN -> fresh verify -> review -> commit` 的节奏，限制单轮只处理一个主目标和
  一条热路径，避免并行猜修拖慢收口。
- Batch 119 把 known non-callable member-call 的第一条 direct class field/property 边界接进结构化
  diagnostics：当 receiver type 已知、class layout truth 已知，且同名 field/property 已知存在但被当成
  call 使用时，`Worker.Value(1)` 会失败为 `sema.invalid-call-shape`，且不注册失败 `member-call`
  binding。
- 这次实现直接复用了现有 `ClassTypeHasKnownNonMethodMember(...)` guard：它不再 silent deferred，而是对
  已知 non-callable member 带出 `invalid-call-shape` failure kind，避免把这类边界误报成
  `sema.unknown-member`。
- Batch 119 新增 `tests/fixtures/known_field_member_call` 与 `known-field-member-call-check`，把这条新
  diagnostics 正式纳入 final envelope `knownFieldMemberCallCheck=pass`。
- `System.Free` 与 specialized generic member-call 继续 deferred；这一批只收 known field/property
  member call 的最小稳定边界，不冒进到更复杂 receiver 或完整 member access 语义。
- Batch 120 证明同一条 known non-callable diagnostics 在 direct class property 上也已天然成立：
  当 `TWorker.Value` 是已知 class property 而不是 callable 时，`Worker.Value(1)` 会失败为
  `sema.invalid-call-shape`，且不注册失败 `member-call` binding。
- property 这条边界不需要再改 `compiler/sema/np_semantic_analyzer.pas`：现有
  `ClassTypeHasKnownNonMethodMember(...)` 已经通过 `$read` / `$write` truth 覆盖 property，因此本轮是
  纯 promotion。
- Batch 120 新增 `tests/fixtures/known_property_member_call` 与 `known-property-member-call-check`，把
  direct class property non-callable 也正式纳入 final envelope
  `knownPropertyMemberCallCheck=pass`。
- Batch 121 证明同一条 known non-callable diagnostics 在 inherited class field 上也已天然成立：
  当 `TWorker = class(TBaseWorker)` 且 `TBaseWorker.Value: Integer` 已知存在但不是 callable 时，
  `Worker.Value(1)` 会失败为 `sema.invalid-call-shape`，且不注册失败 `member-call` binding。
- 这条 inherited known field 边界同样不需要再改 `compiler/sema/np_semantic_analyzer.pas`：现有
  `MethodSymbolIdForClassTypeMember(...)` 已沿 `ParentTypeId` 逐层调用
  `ClassTypeHasKnownNonMethodMember(...)`，因此本轮仍是纯 promotion。
- Batch 121 新增 `tests/fixtures/inherited_known_field_member_call` 与
  `inherited-known-field-member-call-check`，把 inherited known field non-callable 也正式纳入
  final envelope `inheritedKnownFieldMemberCallCheck=pass`。
- Batch 122 证明同一条 known non-callable diagnostics 在 inherited class property 上也已天然成立：
  当 `TWorker = class(TBaseWorker)` 且 `TBaseWorker.Value` 是已知 class property 而不是 callable 时，
  `Worker.Value(1)` 会失败为 `sema.invalid-call-shape`，且不注册失败 `member-call` binding。
- 这条 inherited known property 边界同样不需要再改 `compiler/sema/np_semantic_analyzer.pas`：
  现有 `MethodSymbolIdForClassTypeMember(...)` 已沿 `ParentTypeId` 逐层调用
  `ClassTypeHasKnownNonMethodMember(...)`，而后者已经通过 `$read` / `$write` truth 覆盖 property，因此本轮仍是纯 promotion。
- Batch 122 新增 `tests/fixtures/inherited_known_property_member_call` 与
  `inherited-known-property-member-call-check`，把 inherited known property non-callable 也正式纳入
  final envelope `inheritedKnownPropertyMemberCallCheck=pass`。
- Batch 123 把 class method body 内的 bare implicit-self method call 推进到真实 binding truth：
  `procedure TWorker.Run; begin Touch; end;` 中的 `Touch;` 现在会注册为唯一 `member-call` binding，
  target 指向 `TWorker.Touch`，且不报 diagnostic。
- 这次修复不是扩大完整 bare/member resolver，而是最小补齐两个局部缺口：
  `BareCallCalleeName(...)` 在 bare `gnkProcedureCallStatement` 没有 child node 时回退到
  `ACallNode.Text`；`TryRegisterImplicitSelfBareMethodCallBinding(...)` 只在当前 method class 已知、
  bare call 常规 lookup 失败且 failure kind 仍为空或 `unknown-callable` 时，尝试把 bare name 回绑到
  当前 class method symbol。
- fresh stage0 query probe 证明 query/session projection 也已经天然成立，不需要继续改 query path：
  `.sisyphus/tmp/stage0-bootstrap/nextpas query symbols ...member_call_bindings.pas` 已输出
  `query-bindings` 中 `byteOffset=519` 的 `Touch` `member-call`，target 为 `TWorker.Touch`；同一条
  `query-definitions` 也同步投影 `targetName="TWorker.Touch"`。
- 因此 Batch 123 的正确提速方式是 promotion-first：先用 fresh binary 复核 query 真相，再补
  `stage0-query-member-call-bindings-check` 官方 gate，而不是在 query 已经成立时继续猜修 session / projection。
- Batch 123 第一次 full verify 失败点是 official gate 的 byte offset 期望漂移：脚本算到了语句行首，
  而 query truth 的 binding offset 是 callee `Touch` 起点 `519`。修正
  `MEMBER_IMPLICIT_TOUCH_OFFSET` 之后，fresh `bash build/verify_local.sh` 已输出
  `semantic-call-bindings-check=pass`、`stage0-query-member-call-bindings-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。
- Batch 124 证明 class method body 内 bare implicit-self method call 也能沿 parent chain 绑定到
  inherited method：当 `TWorker = class(TBaseWorker)` 且 `TWorker.Run` 内写 `Touch;` 时，
  `Touch;` 会注册为唯一 `member-call` binding，target 指向 `TBaseWorker.Touch`，且不报
  diagnostic。
- 这条 inherited implicit-self bare call 边界不需要修改
  `compiler/sema/np_semantic_analyzer.pas`：Batch 123 的 implicit-self fallback 已复用
  `MethodSymbolIdForClassTypeMember(...)`，后者现有 `ParentTypeId` lookup 已能找到 parent method。
- Batch 124 新增 `TChildWorker.Run` 内 bare `Touch;` 的 query gate；fresh stage0 query probe
  已输出 `query-bindings` 中 `byteOffset=935` 的 `Touch` `member-call`，target 为
  `TBaseWorker.Touch`，同一条 `query-definitions` 也同步投影
  `targetName="TBaseWorker.Touch"`。
- Batch 124 fresh `bash build/verify_local.sh` 已输出
  `semantic-call-bindings-check=pass`、`stage0-query-member-call-bindings-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`；本批没有修改 semantic analyzer，
  也没有修改 `core/`。
- Batch 125 证明 inherited implicit-self bare method call with argument 也能消费现有
  argument-count/signature truth：当 parent class 声明 `TBaseWorker.Touch(Value: Integer)`，
  child class method body 内写 `Touch(7);` 时，`Touch` 会注册为唯一 `member-call`
  binding，target 指向 param signature 为 `i` 的 `TBaseWorker.Touch`，且不报 diagnostic。
- 这条带参数 inherited implicit-self bare call 边界不需要修改
  `compiler/sema/np_semantic_analyzer.pas`：Batch 123 的 implicit-self fallback 已传入
  `CallArgumentCount(...)` 与 compact argument signature，现有
  `MethodSymbolIdForClassTypeMember(...)` 会沿 parent chain 选择同 arity/signature target。
- Batch 125 新增 `TChildWorker.Run` 内 bare `Touch(7);` 的 query gate；fresh stage0 query probe
  已输出 `query-bindings` 中 `byteOffset=1038` 的 `Touch` `member-call`，target 为带
  `targetParamCount=1` / `targetParamSignature="i"` 的 `TBaseWorker.Touch`。
- Batch 125 fresh `bash build/verify_local.sh` 已输出
  `semantic-call-bindings-check=pass`、`stage0-query-member-call-bindings-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`；本批没有修改 semantic analyzer，
  也没有修改 `core/`。
- Batch 126 证明 inherited implicit-self bare method call 的失败路径需要显式透传 lookup
  failure kind：`TBaseWorker.Touch(Value: Integer)` 可见、`TWorker.Run` 内写 `Touch(True);`
  时，旧实现会 silent deferred，因为 implicit-self fallback 只返回 Boolean。
- `TryRegisterImplicitSelfBareMethodCallBinding(...)` 现在返回 failure kind、callee name 与 callee
  offset；当 parent-chain lookup 证明单一 target 的 stable signature 不兼容时，
  `SeedCallBindingsInNode(...)` 会发 `sema.type-mismatch`，且不会注册失败 `member-call` binding。
- Batch 126 新增 dedicated fixture
  `tests/fixtures/inherited_implicit_self_bare_method_type_mismatch` 与
  `inherited-implicit-self-bare-method-type-mismatch-check`，stage0 probe 已输出
  `diagnostic-code=sema.type-mismatch` 与
  `diagnostic-message=argument type mismatch for "Touch"`。
- Batch 126 fresh `bash build/verify_local.sh` 已输出
  `inheritedImplicitSelfBareMethodTypeMismatchCheck":"pass"`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 `core/`。
- Batch 127 采用“失败矩阵补齐”加速策略：沿 Batch 126 的 inherited implicit-self bare method
  failure-kind propagation 继续补 `wrong-argument-count`，避免每轮重新发散找新主题。
- focused semantic 证明 `Touch;` 调 inherited `Touch(Value: Integer)` 已天然失败为
  `sema.wrong-argument-count`，且不注册错误 `member-call` binding；本批不需要修改
  `compiler/sema/np_semantic_analyzer.pas`。
- Batch 127 新增 dedicated fixture
  `tests/fixtures/inherited_implicit_self_bare_method_wrong_argument_count` 与
  `inherited-implicit-self-bare-method-wrong-argument-count-check`，把该能力提升到 official
  verify gate 与 final envelope。
- Batch 127 fresh `bash build/verify_local.sh` 已输出
  `inherited-implicit-self-bare-method-wrong-argument-count-check=pass`、
  `inheritedImplicitSelfBareMethodWrongArgumentCountCheck":"pass"`、
  `semantic-call-bindings-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批没有修改 analyzer，也没有修改 `core/`。
- Batch 128 继续“失败矩阵补齐”加速策略：沿 inherited implicit-self bare method failure-kind
  propagation 补 `no-matching-overload`，与 Batch 126/127 形成同一路径的三格 failure coverage。
- focused semantic 证明 parent class 上 `Touch(Integer)` 与 `Touch(AnsiString)` 同时可见、
  child method body 内写 `Touch(True);` 时，已经天然失败为 `sema.no-matching-overload`，
  且不注册错误 `member-call` binding；本批不需要修改 analyzer。
- Batch 128 新增 dedicated fixture
  `tests/fixtures/inherited_implicit_self_bare_method_no_matching_overload` 与
  `inherited-implicit-self-bare-method-no-matching-overload-check`，把该能力提升到 official
  verify gate 与 final envelope。
- Batch 128 fresh `bash build/verify_local.sh` 已输出
  `inherited-implicit-self-bare-method-no-matching-overload-check=pass`、
  `inheritedImplicitSelfBareMethodNoMatchingOverloadCheck":"pass"`、
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`；本批没有修改 analyzer，
  也没有修改 `core/`。
- Batch 129 把加速打法明确为“同一路径失败矩阵推进”：沿 inherited implicit-self bare
  method failure-kind propagation 连续补格，避免每轮重新发散找新主题。
- focused semantic 证明 parent class 上 `Touch(Integer)` 与 `Touch(LongInt)` 同时可见、
  child method body 内写 `Touch(1);` 时，已经天然失败为 `sema.ambiguous-overload`，
  且不注册错误 `member-call` binding；本批不需要修改 analyzer。
- Batch 129 新增 dedicated fixture
  `tests/fixtures/inherited_implicit_self_bare_method_ambiguous_overload` 与
  `inherited-implicit-self-bare-method-ambiguous-overload-check`，把该能力提升到 official
  verify gate 与 final envelope。
- Batch 129 fresh `bash build/verify_local.sh` 已输出
  `inherited-implicit-self-bare-method-ambiguous-overload-check=pass`、
  `inheritedImplicitSelfBareMethodAmbiguousOverloadCheck":"pass"`、
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`；本批没有修改 analyzer，
  也没有修改 `core/`。
- Batch 130 暴露出 inherited implicit-self failure matrix 之外的相邻缺口：class method body 内
  bare `Missing;` 处于已知 `Self` class context，旧实现既没有把它作为 ordinary
  `sema.unknown-callable` 发出，也没有发 `sema.unknown-member`，而是 silent deferred。
- 修复点很窄：`TryRegisterImplicitSelfBareMethodCallBinding(...)` 已能从
  `MethodSymbolIdForClassTypeMember(...)` 拿到 `unknown-member` failure kind；缺的是
  `SeedCallBindingsInNode(...)` bare-call emission 分支对该 failure kind 的输出。
- Batch 130 新增 dedicated fixture
  `tests/fixtures/implicit_self_bare_method_unknown_member` 与
  `implicit-self-bare-method-unknown-member-check`，把 class method body 内 bare implicit-self
  name miss 固定为 `sema.unknown-member`，且不注册失败 `member-call` binding。
- Batch 130 fresh `bash build/verify_local.sh` 已输出
  `implicit-self-bare-method-unknown-member-check=pass`、
  `implicitSelfBareMethodUnknownMemberCheck":"pass"`、`semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`；本批修复仅触达 `compiler/sema` 的 narrow
  diagnostic emission 与对应 tests/docs/records，没有修改 `core/`。
- Batch 105 把 root-owned bare overload signature no-match 接进 structured diagnostics：
  root source 中存在同名同 arity 多个候选、argument signature 来自稳定 evidence、但没有任何
  candidate signature 匹配时，`Pick(True)` 会失败为 `sema.no-matching-overload`，且不注册失败
  call binding。
- `sema.no-matching-overload` 与 `sema.type-mismatch` 分工明确：单一 target 不兼容继续报
  `type-mismatch`；多候选集合全不匹配报 `no-matching-overload`。
- Batch 105 新增 `no-matching-overload-check`，用 dedicated fixture 固定 stage0
  `sema.no-matching-overload` projection 与 final envelope `noMatchingOverloadCheck=pass`。
- Batch 105 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `no-matching-overload-check=pass`、`noMatchingOverloadCheck":"pass"`、`verify-local=pass`
  与 `human-summary=local verification passed`。
- Batch 106 把 imported bare overload signature no-match 接进 structured diagnostics：
  root source 中没有同名 callable，imported units 中存在同名同 arity 多个候选、argument signature
  来自稳定 evidence、但没有任何 imported candidate signature 匹配时，`Pick(True)` 会失败为
  `sema.no-matching-overload`，且不注册失败 call binding。
- Batch 106 只改变 imported 多候选全不匹配的安全分支：root callable 仍优先，single imported
  target type mismatch、member no-match、implicit conversion、default parameter ranking、var/out
  compatibility 和 visibility checking 继续 deferred。
- Batch 106 新增 `imported-no-matching-overload-check`，用 dedicated fixture 固定 stage0
  `sema.no-matching-overload` projection 与 final envelope `importedNoMatchingOverloadCheck=pass`。
- Batch 106 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `imported-no-matching-overload-check=pass`、`importedNoMatchingOverloadCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`。
- Batch 107 把 direct class member-call overload signature no-match 接进 structured diagnostics：
  root-owned exact class type 中存在同 owner / 同 qualified name / 同 arity 多个 method candidates、
  argument signature 来自稳定 evidence、但没有任何 candidate signature 匹配时，
  `Worker.Pick(True)` 会失败为 `sema.no-matching-overload`，且不注册失败 `member-call` binding。
- Batch 107 只改变 direct class variable receiver + root-owned exact class type 的安全分支：
  imported/inherited member no-match、record/property/array/deref receiver、implicit conversion、
  default parameter ranking、var/out compatibility 和 visibility checking 继续 deferred。
- Batch 107 收口 review 增加了 inherited member no-match guard：parent-chain lookup 可继续绑定
  inherited positive method target，但 inherited overload 全不匹配不能在本批次提前报
  `sema.no-matching-overload`。
- Batch 107 新增 `member-no-matching-overload-check`，用 dedicated fixture 固定 stage0
  `sema.no-matching-overload` projection 与 final envelope `memberNoMatchingOverloadCheck=pass`。
- Batch 107 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `member-no-matching-overload-check=pass`、`memberNoMatchingOverloadCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`。
- Batch 102 已把 platform.time focused tests 迁入 `core/tests/nextpas.core.platform.time/`，
  并让 official gates 指向 platform 命名空间；`nextpas.core.time/test_time` 继续只覆盖 L1
  `time` public API。
- Batch 102 fresh verification 已闭环：focused platform.time tests、`make -C core test`、
  `make -C core examples`、`make -C core benchmarks` 均通过，fresh `bash build/verify_local.sh`
  输出 `corePlatformTimeHelpersCheck=pass`、`corePlatformTimeNoFpcCheck=pass`、
  `corePlatformTimeWin64Check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- platform.time 批次的 fresh verification 已闭环：`make -C core test`、`make -C core examples`、
  `make -C core benchmarks` 通过，`bash build/verify_local.sh` 输出
  `verify-local=pass` 与 `human-summary=local verification passed`。
- `platform.time` 示例/基准必须贴着 L0 clock source 语义：本批新增
  `nextpas.core.platform.time/platform_time_clock` 与
  `nextpas.core.platform.time/bench_platform_time_clock`，只调用 platform clock API，不引入
  `Stopwatch`、`Duration` 或 L1 time convenience API。
- 新增 `nextpas.core.platform.time/test_platform_time_l0_boundary`，把这个边界变成 gate：
  platform.time 源码、platform 门面、platform 示例和 platform 基准不能引用
  `nextpas.core.time`、`TStopwatch`、`TDuration`、`TInstant` 或 Timer。
- 旧 `codex/platform-time-integration` 仍有可参考内容，但其中 `demo_stopwatch`、L1 time 基准、
  通用 Makefile 批量改动和已过期 platform.time 代码不能整条合入；后续只能按模块边界择优搬迁。
- `build/verify_local.sh` 已增加 platform.time boundary/example/benchmark focused gates，并在 final
  envelope 暴露 `corePlatformTimeL0BoundaryCheck`、`corePlatformTimeExampleCheck` 与
  `corePlatformTimeBenchCheck`。
- platform.time L0 surface coverage 的 fresh verification 已闭环：`make test`、`make examples`、
  `make benchmarks` 通过，fresh `bash build/verify_local.sh` 输出
  `corePlatformTimeL0BoundaryCheck=pass`、`corePlatformTimeExampleCheck=pass`、
  `corePlatformTimeBenchCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- `platform.thread` 的 public surface 不应把 current-thread identity 与 create/join/detach lifecycle
  handle 混成同一个类型：`TPlatformThreadHandle` 现在只表示 `platform_thread_create` 返回的 owned
  handle，`platform_thread_self` 返回新的 `TPlatformThreadToken` unowned identity token。
- `platform_thread_self` 的 focused RED 先失败在 `Identifier not found "TPlatformThreadToken"`；
  修正后 `test_platform_thread` 输出 `8 total, 8 passed, 0 failed`，补齐这个 public API 的接口覆盖。
- `platform.thread` 示例和基准必须贴着 L0 thread surface：本批新增
  `platform_thread_lifecycle` 与 `bench_platform_thread_lifecycle`，只覆盖 create/join、TLS、
  self/id、yield/sleep 与 CPU count，不引入 `nextpas.core.thread`。
- 新增 `test_platform_thread_l0_boundary`，把 L0/L1 并发边界变成 gate：platform.thread 源码、
  示例和基准不能引用 `nextpas.core.thread`、ThreadPool、Channel、Future、Scheduler 或 Task。
- `build/verify_local.sh` 已增加 platform.thread behavior/no-FPC/L0-boundary/Win64/example/benchmark
  focused gates，并在 final envelope 暴露 `corePlatformThreadCheck`、
  `corePlatformThreadNoFpcCheck`、`corePlatformThreadL0BoundaryCheck`、
  `corePlatformThreadWin64Check`、`corePlatformThreadExampleCheck` 与
  `corePlatformThreadBenchCheck`。
- Windows FFI 已移除不再消费的 `GetCurrentThread` 声明；self token 使用 `GetCurrentThreadId`，
  避免 Win32 pseudo handle 被误投影成可 join/detach 的 platform handle。
- platform.thread L0 surface coverage 的 fresh verification 已闭环：`make -C core test`、
  `make -C core examples`、`make -C core benchmarks` 均通过；fresh
  `bash build/verify_local.sh` 输出 `corePlatformThreadCheck=pass`、
  `corePlatformThreadNoFpcCheck=pass`、`corePlatformThreadL0BoundaryCheck=pass`、
  `corePlatformThreadWin64Check=pass`、`corePlatformThreadExampleCheck=pass`、
  `corePlatformThreadBenchCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- Batch 103 把 `@np_object_release_invalid` 从 no-op boundary 推进成最小 fatal failure policy：
  invalid helper 会调用 `@llvm.trap()`，随后发出 `unreachable`。
- Batch 103 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- 新 focused RED 固定旧行为缺口：Batch 102 的 invalid helper 仍 `ret void`，因此
  object-free focused test 失败在 `missing-object-free-release-invalid-trap-call`。
- 修正后 magic mismatch / double free 已有最小 fatal runtime 行为，但这还不是结构化 diagnostics、
  Pascal exception、core allocator 接管或完整 validation runtime。
- Batch 102 把 `@np_object_free_release` 的 magic mismatch 路径推进成 compiler-owned
  invalid-release boundary：非法 header 会进入 `invalid:`，调用
  `@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)` 后再汇合到 `done:`。
- Batch 102 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- 新 focused RED 固定旧行为缺口：Batch 101 后的 mismatch path 仍直接跳 `done:`，因此
  object-free focused test 失败在 `missing-object-free-release-header-magic-branch`。
- 修正后 invalid-release helper 当前仍是 no-op；它只是 diagnostics/trap/future runtime policy 的
  唯一挂载点，不是 allocator free、异常抛出、core allocator 接管或完整 validation runtime。
- Batch 101 把 `@np_object_release_valid` 从 no-op boundary 推进成 valid release 后的 magic poison：
  helper 会定位 header offset 8 并写入 `0`，让重复释放同一 payload pointer 在下一次进入
  `@np_object_free_release` 时走 magic mismatch skip 路径。
- Batch 101 fresh verification 已闭环：fresh `bash build/verify_local.sh` 输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- 新 focused RED 固定旧行为缺口：Batch 100 的 valid-release helper 只 `ret void`，因此
  object-free focused test 失败在 `missing-object-free-release-poison-magic-slot`。
- 修正后 release poison 已是实际运行期状态变化，但仍不是 allocator free、diagnostics/trap failure
  path、core allocator 接管或完整 dynamic dispatch runtime。
- Batch 100 把 magic-valid `release:` 占位块推进成 compiler-owned
  `@np_object_release_valid(ptr %raw, i64 %size)` boundary；只有 header magic 校验通过后才会调用，
  参数固定为 header raw pointer 与 payload size。
- 新 focused RED 固定旧行为缺口：Batch 99 的 `release:` 仍只是 `br label %done`，因此
  object-free focused test 失败在 `missing-object-free-release-valid-boundary-call`。
- 修正后 valid-release helper 当前仍是 no-op，只是未来 allocator free / poison / statistics 的唯一
  挂载点；这还不是 allocator free、diagnostics/trap failure path、core allocator 接管或完整 dynamic
  dispatch runtime。
- Batch 99 把 `@np_object_free_release` 从 header read contract 推进到 header magic validation
  branch：读取 `%magic` 后会比较 `1313882451`，合法 header 进入 `release:` 占位块，非法 header
  直接汇合到 `done:`。
- 新 focused RED 固定旧行为缺口：Batch 97 的 release helper 读出 magic 后直接
  `br label %done`，因此 object-free focused test 失败在
  `missing-object-free-release-header-magic-check`。
- 修正后 release helper 已有可观察的合法/非法 header 分支，但 `release:` 当前仍是空占位；这还不是
  真实 allocator free、diagnostics/trap failure path、core allocator 接管或完整 dynamic dispatch
  runtime。
- Batch 97 把 object allocation/release helper boundary 推进成最小 header ownership contract：
  `@np_object_alloc` 现在申请 `payload size + 16`，在 header offset 0 写 payload size，在
  offset 8 写 magic `1313882451`，再返回 payload pointer。
- 新 focused RED 固定旧行为缺口：Batch 96 的 allocation helper 只委托 `@np_alloc(size)`，release
  helper 仍为空，因此 class alloc test 失败在 `missing-hir-class-alloc-header-size`，object-free
  test 失败在 `missing-object-free-release-header-base`。
- 修正后 `@np_object_free_release` 会防御性处理 null，并从 payload pointer 回退 16 bytes 读取
  payload size 与 magic header；这只是 ownership contract 和后续 allocator free 的入口证据，
  还不是验证失败路径或真实 free。
- Batch 96 把 class allocation 的 LLVM lowering 从直接 `@np_alloc` 推进到 compiler-owned
  `@np_object_alloc` helper boundary。
- 新 focused RED 固定旧行为缺口：HIR 已有 `class_alloc` intrinsic，但 LLVM emitter 直接生成
  `call ptr @np_alloc(...)`，因此失败在 `missing-hir-class-alloc-object-helper-call`。
- 修正后 class allocation site 会生成 `call ptr @np_object_alloc(i64 ...)`，内部
  `@np_object_alloc(i64 %size)` helper 再委托 `@np_alloc(i64 %size)`；这只是 object
  allocation/release ABI boundary，不是 object header、ownership metadata 或真实 allocator
  free 已完成的证据。
- Batch 95 把 `object-free-runtime` 中的 `heap-release true` 推进到 HIR/LLVM 后端可见边界：
  matching owned `Destroy` 之后现在会追加 `np.system.object_free.release` HIR marker。
- 新 focused RED 固定旧行为缺口：Batch 94 已有 nil branch 和 guarded `Destroy`，但 builder
  没有 release marker，LLVM 也没有 `@np_object_free_release` hook，因此失败在
  `missing-object-free-release-intrinsic`。
- 修正后 LLVM HIR emitter 会在 `objectfree.destroy.*` 非空分支内按顺序发出
  `@TObject.Destroy` call 与 `call void @np_object_free_release(ptr ...)`，然后汇合到
  `objectfree.end.*`；nil receiver 仍直接跳过二者。
- 当前 `@np_object_free_release` 是内部空 helper，只是稳定 backend/runtime 接入口；真实
  allocator free、object header ownership、完整 dynamic dispatch runtime 和 implicit
  `System.pas` backend/link 接管仍未完成。
- `platform.thread` 现在可以在不直接 `uses` FPC 平台单元的前提下覆盖 thread lifecycle、TLS、
  yield/sleep 和 CPU count；禁止规则由 `test_platform_thread_no_fpc_units` 固定。
- Windows `CreateThread` 不能接收 Pascal cdecl user proc，也不能靠 32-bit thread exit code 携带
  64-bit pointer return value；本批改为 stdcall trampoline state，由 join 读取 state 中保存的
  return pointer。
- `platform.thread` 和 `platform.sync` 共同使用 `posix.ffi`，因此 FFI 文件必须取并集；clean
  preview 基于 `main@ad236a2` 保留 sync 的 mutex/rwlock/condvar 声明，并追加 thread 的
  detach/self/TLS/nanosleep/sched_yield/sysconf 声明。
- 本批刻意不混入独立 `platform.time` hardening commit；`windows.ffi` 只保留 thread/TLS/yield/sleep/
  cpu-count 所需 ABI，后续 time 合并时再追加 QueryPerformance/FileTime 等 time-only FFI。
- Batch 94 把 object-free lifecycle contract 推进到 LLVM HIR emitter：`np.system.object_free`
  现在会生成 receiver pointer 的 `icmp eq ptr ..., null` 与 conditional branch；匹配的
  `np.system.object_free.destroy` call 位于 `objectfree.destroy.*` 非空分支，并在调用后汇合到
  `objectfree.end.*`。
- 新 focused RED 固定旧行为缺口：Batch 92 的 LLVM emitter 只保留 owned destroy ordinary call，
  因此失败在 `missing-object-free-llvm-null-check`。
- 初次 guarded emitter 实现暴露 builder 侧 receiver reload 缺口：owned destroy 前的额外 load 会让
  guard 提前关闭；修正后 `THIRBuilder` 会复用 object-free marker 已解析出的 receiver pointer。
- 修正后 focused test 输出 `hir-object-free-contract-status=pass`；fresh full verify 已输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- 这个切片已经有真实 LLVM nil branch，但仍不是完整对象释放：allocator free、完整 dynamic dispatch
  runtime、implicit `System.pas` 自动 assemble/link 与完整 `System` 平替仍未完成。
- Batch 92 把 `np.system.object_free` 与紧随的 effective `Destroy` 连接成 HIR lifecycle group：
  匹配 receiver/destroy target 的后续 `call-runtime` 现在会成为 `hikIntrinsic` /
  `np.system.object_free.destroy`，而不是裸 `hikCall @TObject.Destroy`。
- 新 focused HIR RED 固定旧行为缺口：在 `object-free-runtime` 后追加匹配
  `call-runtime TObject.Destroy` 时，旧实现失败在 `plain-object-free-destroy-call`。
- 修正后 focused test 输出 `hir-object-free-contract-status=pass`；fresh full verify 已输出
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- LLVM HIR emitter 现在让 `np.system.object_free.destroy` 复用 ordinary call emission，
  所以本批保留当前可执行析构 call 行为，但仍不声称 nil guard、allocator free 或完整动态
  dispatch runtime 已完成。
- Batch 91 把 `object-free-runtime` 从 semantic typed HIR 接到 HIR builder：`THIRBuilder` 现在会
  生成 `hikIntrinsic` / `np.system.object_free` marker，receiver 以 pointer operand 保留，
  effective `Destroy` 名称保存在 `CallTarget`。
- 新 focused HIR RED/GREEN 固定这个边界：旧实现失败在
  `missing-object-free-hir-intrinsic`，修正后输出
  `hir-object-free-contract-status=pass`；`build/verify_local.sh` 也新增
  `hir-object-free-contract` gate，fresh full verify 已输出 `hir-object-free-contract=pass` 与
  `verify-local=pass`。
- 这个 HIR bridge 仍不是真实对象释放：当前 LLVM HIR emitter 不展开 nil guard、不调用 allocator
  free，也不声明完整 dynamic dispatch runtime 已完成。
- Merge-preview closeout 已证明 platform.sync 分支可以和最新 `main` 的 source-backed
  `System/TObject`、`ICondVar`、Vec/interface allocator 等变更共存；冲突只落在设计约定和
  跟踪文档，源码自动合并后通过全量验证。
- `nextpas.core.platform.sync` 当前只依赖 `nextpas.core.platform.posix.ffi`、
  `nextpas.core.platform.linux.ffi`、`nextpas.core.platform.sync.windows.ffi`，不再 `uses`
  FPC 的 `Linux`、`PThreads`、`UnixType`、`BaseUnix`、`Syscall`、`Windows` 平台单元。
- `nextpas.core.platform.linux.ffi` 已保持为纯 ABI 声明文件；`__errno_location` 只作为
  external declaration 暴露，读取 errno 的逻辑位于 `platform.sync` 实现层。
- 主线新增的 `atomic`、`hashmap`、`arena`、`pool`、`thread` 测试项目暴露了 per-project
  Makefile 规则的合并缺口；补齐后 `make -C core test` 已能覆盖全部 core 测试项目。
- 当前硬规则仍有后续债务：`platform.time` 仍存在 FPC 平台单元依赖，应在新
  worktree 中继续按 `posix.ffi` / `linux.ffi` / Windows FFI 边界迁移。
- Platform sync closeout 证明 `build/verify_local.sh` 之前不是 stage0 行为失败，而是 verification
  contract 自身把 explicit workspace 固定成 `.*/nextPas`，导致 linked worktree 下误报
  `missing-stage0-workspace-root`。
- `verify_local` 现在通过 `escape_ere()` 派生当前 `REPO_ROOT`、workspace artifact/output、
  distribution/runtime root 的正则 pattern；line output 用 literal 断言，JSON envelope 用
  escaped regex 断言，保留精确性但不再绑定主 checkout 目录名。
- `core-text-smoke-check` 不再写死 `/home/dtamade/projects/nextPas/rtl/core/...`，而是使用当前
  `REPO_ROOT/rtl/core/...`，让 smoke 在 worktree 内自洽。
- `core-platform-sync-check` 顶层 summary 已同步到当前 14 项接口覆盖；fresh
  `bash build/verify_local.sh` 已通过并输出 `verify-local=pass` / `human-summary=local verification passed`。
- Batch 89 把 source-backed implicit `System` 的对象生命周期从 `TObject.Free` binding 推进到
  no-fold typed HIR 的 effective `Destroy` runtime call：普通 class 没有显式父类时，会继承
  `System.TObject` 的 VMT slot/function metadata。
- `compiler/sema/np_semantic_analyzer.pas` 现在让隐式 `ParentTypeId` 也参与 class layout 复制，
  并让 `Free` lowering 通过 `TClass$vmt_slot_Destroy` / `TClass$vmt_func_<slot>` 选择当前有效
  destructor；继承路径可落到 `TObject.Destroy`，不再硬写不存在的 `TWorker.Destroy`。
- 新 focused semantic RED/GREEN 固定这个边界：旧实现失败在
  `missing-implicit-system-free-inherited-destroy-lowering`，修正后
  `semantic-call-bindings-status=pass`。这仍不是完整 heap free、nil guard、动态 virtual dispatch
  runtime 或 backend/link 接管。
- Batch 88 把 implicit runtime `System` 从无来源 placeholder 推进到 source-backed semantic truth：
  program 即使没有显式 `uses System`，semantic analyzer 也能从
  `units/linux-x86_64/System.pas` 读取 `TObject` / `TObject.Free`。
- 这次升级只发生在 semantic model：implicit runtime unit 的 `OriginClass` 仍是
  `implicit-runtime`，所以 backend extra assemble 继续跳过它，不会让所有 program 自动编译/链接
  nextPas 自定义 `System.pas`。
- 显式 `uses System` 仍不会被 implicit runtime source path 短路；resolver 会继续 normal search，
  并允许 `TUnitGraph.AddResolvedUnit(...)` 把 source-backed implicit runtime 节点升级成显式
  `installed-source` provenance。
- 新增 `tests/fixtures/system_object_free/system_object_free_implicit_binding.pas` 与
  `stage0-query-system-object-free-implicit-check`，固定无显式 uses 下 `Worker.Free` 到
  `TObject.Free` 的 binding 和 definition source path。
- Batch 87 落地第一条 nextPas-owned source-backed `System` truth：`rtl/core/system/System.pas`
  与 `units/linux-x86_64/System.pas` 现在先提供 `TObject.Create`、`TObject.Destroy` 和
  `TObject.Free`。
- 当显式 `uses System` 让 target-installed `System.pas` 进入 `TUnitGraph` / `TSemanticModel`
  后，普通 `class` 会默认继承 owner=`system` 的 `TObject`；`Worker.Free` 通过现有
  `ParentTypeId` 继承 member lookup 绑定到真实 `TObject.Free`，不是新增字符串兜底。
- 新增 `tests/fixtures/system_object_free/system_object_free_binding.pas` 与
  `stage0-query-system-object-free-check`，固定 `querySymbols` 中的 `TObject.Free` method symbol、
  `queryBindings` 中的 `Free` member-call，以及 `queryDefinitions.targetSourcePath` 指向
  `units/linux-x86_64/System.pas`。
- implicit runtime edge 仍保持 placeholder，本批没有让所有 program 自动编译/链接
  `System.pas`；没有 source-backed System truth 的路径仍让 `Free` deferred，避免把最低 runtime
  baseline 缺口误报为普通 unknown member。
- Batch 86 把 receiver type 已知的 direct class member-call name miss 接进 structured diagnostics：
  `Worker.Missing(1)` 这类 class/parent chain 没有同名 method 的调用会发出
  `sema.unknown-member`，model status 进入 `failure`，且不会注册 `member-call` binding。
- `ClassTypeHasKnownNonMethodMember(...)` 让已知 field / property 名称保持 deferred，不把
  `Worker.Value(1)` 这类后续应由 non-callable / field-property access 处理的边界误报成 unknown member。
- 新增 `tests/fixtures/unknown_member/unknown_member_fail.pas` 与 `unknown-member-check`，固定
  stage0 failure projection、`diagnosticsSummary=sema.unknown-member` 和 final envelope
  `unknownMemberCheck=pass`。
- Full verify 首轮暴露 `examples/smoke/llvm_destructor.pas` 的 `C.Free` 被误报为
  `sema.unknown-member`；这不是普通 member miss，而是当前尚未有 source-backed nextPas
  `System` / `TObject` truth 的结果。本批先把 `Free` 保持 deferred，后续要用真实
  `System.pas` / `TObject` 符号替代临时边界。
- Full verify 后段又暴露 `tests/parser/generics_pass.pas` 的 `TIntStack.Push` 被误报为
  `sema.unknown-member`；`TIntStack = specialize TStack<Integer>` 当前还没有 generic instantiation
  member truth。本批把 unknown-member 限定到已有 class layout truth 的 receiver，alias /
  generic specialization / record-like receiver 继续 deferred。
- nextPas-owned `System` 是自举代码和 `core` 框架的最低依赖层：它负责平替宿主 FPC
  `System` 中必须先稳定的基础类型、对象生命周期、启动/退出和 runtime helper 事实；
  `core` 框架应建立在这层之上，而不是反向承担编译器最低语义前提。
- Batch 85 重新验证最新 baseline：detached clean worktree 基于 `287d13d` 已输出
  `unknown-callable-check=pass`、`unit-root-precedence-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。
- `unit_root_precedence` 曾暴露 host FPC backend cache 污染：前序 build 留下的
  `Stage0Greeter` 中间产物可能让后续显式 `--unit-root` 构建运行到旧 installed-source 行为；
  当前 runner 会在 host compiler step 前清理旧 `.ppu/.o/.s/*_link.res/*_ppas.sh`。
- 当前最高价值后续路线仍是非 `core/` 的 G1.5/G1.6：优先补 source-owned、证据稳定、
  误报风险可控的 unknown member 或 no-matching-overload diagnostic。
- Batch 84 把 source-owned bare callable name miss 接进 structured diagnostics：当 bare call
  的名字既不是 root/imported procedure/function、也不是已知 symbol/type/builtin callable 时，
  semantic analyzer 发出 `sema.unknown-callable`，model status 进入 `failure`，且不会注册 call binding。
- 本批刻意不把已知非 callable symbol、typecast 形态、function pointer、imported helper no-match 或
  unknown member 一起归类；这些仍留给后续 G1.5/G1.6 切片。
- 新增 `unknown-callable-check`，用 `tests/fixtures/unknown_callable/unknown_callable_fail.pas`
  固定 stage0 failure projection 与 final envelope `unknownCallableCheck=pass`。
- Batch 83 新增 `docs/architecture/nextpas-goal-tree.md`，把 nextPas 的北极星目标、G0-G8
  能力树、当前完成度、近期优先级和每轮报告格式收成总控地图。
- 目标树明确后续每轮批次必须绑定目标节点；近期最高价值非 core 路线是继续推进
  G1.4/G1.5/G1.6：semantic model、call/member/overload resolution 与 diagnostics。
- 目标树明确当前协作边界：`core/` 由 core 负责人推进；本工作流不直接修改 `core/` 代码，
  只提出 compiler/tooling 侧 integration requirement 或 review/suggestion。
- `build/verify_local.sh` docs-check 现在要求 `docs/architecture/nextpas-goal-tree.md` 存在，
  防止总控目标树脱离 verification surface。
- Batch 82 把 `nextpas.core.time` 纳入顶层官方验证面：`build/verify_local.sh` 新增
  `core-time-check`，编译并运行 `core/tests/nextpas.core.time/test_time/test_time.lpr`，并在
  final envelope 中暴露 `coreTimeCheck=pass`。
- `core.platform.time` 现在是 `TInstant.Now` 的 platform-owned monotonic clock 来源，同时由
  `nextpas.core.platform` facade re-export `PlatformMonotonicNs` / `PlatformRealtimeNs` /
  `PlatformMonotonicResolutionNs`。
- `core.platform.time` 的 Unix 路径使用 `clock_gettime` / `clock_getres`，并检查返回值；Windows
  路径保留 `QueryPerformanceCounter` / `GetSystemTimeAsFileTime` 结构，未知平台 fallback 只保证可编译。
- `nextpas.core.time` focused test 现在覆盖 13 项，包括 direct platform time facade：
  monotonic 不倒退、Linux realtime 可用、resolution 至少 1ns。
- 本批不声明 DateTime、timezone、Timer、scheduler、async runtime 或完整跨平台时间库已经完成。
- Batch 81 把 `sema.type-mismatch` evidence 从变量扩展到当前 callable scope 中已声明为内建
  标量/字符串类型的参数：`procedure Run(Flag: Boolean); begin Pick(Flag); end;` 调
  `Pick(Integer)` 现在会失败并且不注册该失败 call binding。
- `TProcedureBodyEntry` 现在记录 callable scope id，call binding walker 进入 procedure/function
  declaration body 时会切到对应 scope，让参数 lookup 不再退化到 root scope。
- parameter symbol 现在记录声明 type id；stable scalar evidence 明确限制为 `variable` /
  `parameter` symbol，`function Flag: Boolean` 这类函数返回值 symbol 继续不作为 diagnostic evidence。
- bare single-target call 若 argument signature 已知但缺少 stable evidence 且 signature 不匹配，会保持
  no diagnostic / no binding 的 deferred 边界，避免把函数返回值 mismatch 误注册为有效 call binding。
- Batch 81 新增 `type-mismatch-parameter-call-check` 与
  `member-type-mismatch-parameter-call-check`，用 dedicated fixtures 固定 bare/member 参数
  `sema.type-mismatch` projection 与 final envelope。
- Batch 80 把 `sema.type-mismatch` evidence 从 literal/纯表达式扩展到当前 scope 中已声明为内建
  标量/字符串类型的变量参数：`Flag: Boolean; Pick(Flag);` 调 `Pick(Integer)` 现在会失败并且不注册
  binding。
- 新增 `TypeIdHasStableScalarFact(...)`，只认可 `Boolean`、整数/浮点、`Char` 与内建字符串族变量；
  `Pointer`、`Text`、`Variant`、declared class/record/alias、成员访问、函数结果仍不作为 diagnostic
  evidence。
- Batch 80 新增 `type-mismatch-variable-call-check` 与 `member-type-mismatch-variable-call-check`，
  用 dedicated fixtures 固定 bare/member 变量参数 `sema.type-mismatch` projection 与 final envelope。
- Batch 79 把第一条可证明 type no-match 接进 call diagnostics：bare procedure/function call 与
  direct member-call 在只有 root-owned 单一 target、arity 已匹配、argument signature 来自稳定事实且与
  param signature 明确不兼容时，会发 `sema.type-mismatch`，model status 进入 `failure`，且不会注册
  `call` / `member-call` binding。
- `sema.type-mismatch` 还要求 argument signature 来自 literal/纯表达式等稳定事实；变量、成员或函数结果
  相关 no-match 继续 deferred。
- `True` / `False` 现在由 `InferExpressionType(...)` 识别为 `Boolean`，避免 boolean literal
  在 call argument signature 中退化为 unknown identifier。
- `LookupCallBindingDeclaration(...)` 不再因为 bare call target 唯一就绕过 signature check；
  单一 target 的 signature mismatch 会透传 `type-mismatch` failure kind。
- `MethodSymbolIdForExactClassTypeMember(...)` 同样会在 direct member-call 单一 target signature
  mismatch 时透传 `type-mismatch` failure kind。
- Batch 79 仍保持 imported target 与多 overload signature no-match deferred；implicit conversion、完整
  ranking、unknown callable/member、record/property/array/deref receiver 与完整 member resolver 继续 deferred。
- fresh verify 首轮证明 imported RTL/helper surface 不能纳入本批 type-mismatch 诊断：`ExpandFileName` /
  `FileExists` 曾被过宽规则误报，原因是 compact signature 还不足以完整表达 imported declaration
  与 caller-side alias/string facts。
- fresh verify 二轮证明变量 type facts 也不能纳入本批 diagnostic evidence：`SetNext(TNode)` 被变量参数
  `B` / `C` 误报后，type mismatch 诊断边界收紧为 literal/纯表达式稳定事实。
- 新增 `type-mismatch-call-check` 与 `member-type-mismatch-call-check`，用 dedicated stage0 failure
  fixtures 固定 `sema.type-mismatch` projection 与 final envelope。
- Batch 78 把 `sema.wrong-argument-count` 从 bare call 扩到 direct member-call：当前已支持的
  class/type receiver path 中，同名 method 已知但没有任何同 arity target 时，semantic analyzer
  会发 diagnostic，model status 进入 `failure`，且不会注册 `member-call` binding。
- `MethodSymbolIdForExactClassTypeMember(...)` 现在通过 `AResolutionFailureKind` 区分普通
  deferred、`ambiguous-overload` 与 `wrong-argument-count`；exact receiver type 明确 wrong arity
  时不会继续穿透 parent class 代偿。
- Batch 78 仍保持 receiver/type/signature 保守边界：未知 member、receiver 未覆盖、body mismatch、
  signature no-match、implicit conversion、default parameter lowering/ranking、visibility 与完整
  member resolver 继续 deferred。
- `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 里的历史 `Worker.SetValue;`
  负例在 Batch 78 后不再属于 success query fixture；它现在应由 dedicated
  `member_wrong_argument_count_fail.pas` 固定 semantic failure projection。
- 新增 `member-wrong-argument-count-check`，用 `tests/fixtures/member_wrong_argument_count` 固定
  stage0 failure projection 与 final envelope `memberWrongArgumentCountCheck=pass`。
- Batch 77 把 bare callable 的第一条 arity no-match 接进 structured diagnostics：
  root/imported 同优先级内已存在同名 callable，但没有任何候选参数个数匹配调用时，发出
  `sema.wrong-argument-count`，model status 进入 `failure`，且不会注册 call binding。
- `LookupCallBindingDeclaration(...)` 现在区分 name miss、arity miss、ambiguous overload 与
  signature no-match：name miss 仍 deferred，arity miss 报 `wrong-argument-count`，signature
  match count 为 0 仍 deferred。
- 默认参数不能被 arity diagnostics 误伤：bare call 的 arity match 现在按
  `requiredParamCount..ParamCount` 判断，并用已提供参数的 compact signature 前缀消歧；默认参数
  lowering、完整 overload ranking 与 implicit conversion 仍不是本批目标。
- root callable name 继续优先；root 有同名 callable 但 arity 不匹配时不会回落 imported 代偿。
- 新增 `wrong-argument-count-check`，用 `tests/fixtures/wrong_argument_count` 固定 stage0 failure
  projection 与 final envelope `wrongArgumentCountCheck=pass`。
- Batch 76 把 `sema.ambiguous-overload` 从 bare call 扩展到 direct member-call：当同 owner /
  同 qualified method name / 同 arity 的 method candidates 不能被 compact `ParamSignature`
  唯一选择时，semantic analyzer 会发 diagnostic，model status 进入 `failure`，且不会注册
  `member-call` binding。
- member lookup 现在通过 `AResolutionFailureKind` 把 exact class lookup、parent-chain lookup 与
  `TryRegisterMemberCallBinding(...)` 串起来；exact receiver type 明确 ambiguous 时不会继续穿透
  parent class 代偿。
- Batch 76 仍保持 no-match deferred：signature match count 为 0、receiver form 未覆盖或未来
  type-based resolver 才能判断的路径，不会被提前归类成 ambiguity。
- 新增 `ambiguous-member-overload-check`，用 `tests/fixtures/ambiguous_member_overload` 固定 stage0
  failure projection 与 final envelope `ambiguousMemberOverloadCheck=pass`。
- Batch 75 把 bare overload binding 的第一条可证明失败边界接进 structured diagnostics：
  imported bare callable 同名同 arity 多候选且无法唯一选择时，`SeedCallBindingsInNode(...)`
  会发出 `sema.ambiguous-overload`，model status 进入 `failure`，且不会注册 call binding。
- `LookupCallBindingDeclaration(...)` 现在通过 `AResolutionFailureKind` 区分“普通未解析/暂不绑定”
  和“ambiguous-overload”；root callable 仍优先，root 明确 ambiguous 时不会回落 imported。
- 为避免过早把 future resolver 能力误判成错误，Batch 75 只在无 argument signature 或 signature
  匹配数超过 1 的同名同 arity 多候选上报 ambiguity；signature match count 为 0 仍保持 deferred。
- 新增 `ambiguous-overload-check`，用 `tests/fixtures/ambiguous_overload` 固定 stage0 failure
  projection：`failure-kind=semantic-analysis-failed`、`diagnostic-code=sema.ambiguous-overload`、
  `diagnostic-phase=sema` 与 final envelope `ambiguousOverloadCheck=pass`。
- Batch 74 把 Batch 73 的 compact typed argument relation 复用到 bare procedure/function call
  binding：`Pick(1)` 会绑定到 `Pick(Integer)` 的 `i` signature，`Pick(1 = 1)` 会绑定到
  `Pick(Boolean)` 的 `b` signature。
- bare procedure/function symbol 现在会记录 `ParamSignature`；root/imported callable seeding 与
  lazy callable symbol creation 都会同步写入。
- `LookupCallBindingDeclaration(...)` 仍保留 root callable 优先；root 里存在同名同 arity 多候选时，
  只有当前 argument signature 能唯一匹配才会绑定，不会因为 root ambiguous 而回落 imported。
- 新增 `stage0-query-call-bindings-check`，固定 `querySymbols` / `queryDefinitions` 中 bare typed
  overload 的 `paramSignature` / `targetParamSignature` truth。
- Batch 74 仍不声明完整 overload ranking、implicit conversion、default parameter、
  var/out compatibility、visibility checking 或完整 Pascal callable resolver。
- Batch 73 把 member-call overload binding 从 arity identity 推进到最小 typed argument relation：
  `Worker.Pick(1)` 会绑定到 `TWorker.Pick` 的 `i` signature，`Worker.Pick(1 = 1)` 会绑定到
  `b` signature。
- `TSemanticSymbol` 现在有 `ParamSignature`；class method declaration 通过
  `GetParamSignature(...)` 写入 compact signature，当前编码为 `i` / `b` / `s` / `r` / `p`。
- member-call target lookup 在同 owner / 同 qualified name / 同 `ParamCount` 有多个 candidate
  时，会用 call argument signature 做唯一匹配，并继续用 method body declaration signature
  做二次确认；无法推断 argument type 或同签名不唯一时仍保守不绑定。
- `querySymbols` / `queryDefinitions` 现在分别投影 `paramSignature` / `targetParamSignature`；
  stage0 member-call gate 已固定 integer/boolean 同 arity overload 的 target signature。
- Batch 73 仍不声明 implicit conversion ranking、default parameter、var/out compatibility、
  visibility checking、virtual/override dispatch、record/property receiver 或完整 Pascal member resolver。
- Batch 72 把 class method overload 的 member-call target identity 从“同名 method + body 参数数”
  补强为“同名同 owner 同 `ParamCount` method symbol”：`Worker.Pick;` 与 `Worker.Pick(1);`
  现在会分别绑定到 0 参与 1 参的 `TWorker.Pick` method symbol。
- parser 不再跳过 class method declaration 的 parameter list；`gnkClassMethod` 现在携带已有
  `gnkParameterList` / `gnkParameterDecl` 结构，`ProcessClassFields(...)` 可为 method symbol 设置
  `ParamCount`。
- `queryDefinitions` 现在投影 `targetParamCount`，stage0 member-call gate 已固定 overloaded
  `Pick` 的 0 参/1 参 target；这让 automation / future IDE adapter 不必回扫 `querySymbols`
  才能确认 target arity。
- Batch 72 仍不声明 type-based overload resolution、default parameter matching、implicit
  conversion、visibility checking、virtual/override dispatch、record/property receiver 或
  runtime constructor lowering。
- Batch 71 把 `member-call` target lookup 从 receiver exact class type 推进到最小 inherited
  method lookup：`TChild` receiver 在本类没有 `Touch` 时，会沿 `ParentTypeId` 找到
  `TBase.Touch`，并注册 target 为 parent method symbol 的 `member-call` binding。
- inherited lookup 仍走 owner-aware/type-id-aware 路径：每一层 parent 都先通过 `TypeId` 找回
  type symbol，再用该 type symbol 的 owner unit 限定 `TClass.Method`，不会退回裸字符串 lookup。
- 若 exact receiver type 已声明同名 method 但 body/arity 不匹配或不唯一，lookup 会保守停止，
  不穿透 parent 代偿；这仍不是完整 visibility checking、virtual/override dispatch、
  record/property receiver、runtime constructor lowering 或 type-based overload resolution。
- `stage0-query-member-call-bindings-check` 现在固定 `Child.Touch` 的 `queryBindings` /
  `queryDefinitions` truth，target 为 `TBaseWorker.Touch`，继续确认 query surface 保持
  MIR/backend/toolchain deferred。
- Batch 70 把 Batch 69 的 member-call identity 风险收窄到 owner-aware/type-id-aware 路径：
  root/imported unit 同时声明同名 class（例如 `TWorker`）时，root variable receiver 的
  `Worker.Add(...)` 现在必须先消费变量 symbol 上的稳定 `TypeId`，再通过该 type symbol 的
  owner unit 限定 `TClass.Method` target。
- type resolution 现在在可获得 owner unit 的声明期优先匹配同 owner 的 `type` symbol；若当前
  owner 没有匹配，只接受全模型唯一同名 type candidate，跨 owner 同名冲突时保守返回 0，
  避免继续依赖 `FindTypeByName(...)` 的第一个同名 type。
- member target lookup 同时要求 method symbol 与 procedure body declaration 的 owner unit
  与 receiver type symbol 对齐；这仍不是 inherited lookup、visibility checking、record/property
  receiver、runtime constructor lowering、virtual dispatch 或 type-based overload resolution。
- Batch 69 继续把 `member-call` 正向边界推进到 class method body 内的 `Self` receiver：
  `Self.SetValue(9)` 现在会把 `SetValue` 注册为 `member-call`，并指向当前 method context
  提供的 `TWorker.SetValue` method symbol。
- `Self` receiver 的类型不从 source text 猜测：`SeedCallBindingsInNode(...)` 只在进入
  qualified method declaration（例如 `TWorker.Run`）后携带当前 class context，
  `TypeNameForMemberReceiver(...)` 才会把 `Self` 解析成该 class。
- Batch 69 也补上 imported class variable receiver 的 focused semantic 边界：
  root source 中 `uses Worker; var Worker: TWorker;` 后的 `Worker.Add(1, 2)` 可以绑定到
  imported unit `Worker` 的 `TWorker.Add` method symbol。
- 这个 imported 边界要求 imported type section / class method symbols 先进入
  `TSemanticModel`，再处理 root declarations；否则 root variable 的 `TWorker` type id 会是 0，
  后续 receiver type lookup 仍无法进入 `TClass.Method` matching。
- `stage0-query-member-call-bindings-check` 现在还固定 `Self.SetValue(9)` 的
  `queryBindings` / `queryDefinitions` truth，并继续确认 query surface 保持
  MIR/backend/toolchain deferred。
- Batch 69 仍不声明完整 inherited member lookup、visibility checking、runtime constructor
  lowering、record/property/array/deref receiver、virtual dispatch 或 type-based overload。
- Batch 68 关闭 constructor / class type-name receiver 的第一条正向边界：
  `TWorker.Create(42)` 现在会把 `Create` 注册为 `member-call`，并指向 `TWorker.Create`
  method symbol。
- 真实缺口不在 method symbol 生成，而在 receiver type lookup：旧实现只接受变量 receiver，
  `TWorker` 作为已声明 type symbol 时不会进入后续 `TClass.Method` arity matching。
- 新策略是先保留 variable receiver 类型优先级，再保守回落到同一份 `TSemanticModel` 中的
  declared `type` symbol；这样 `Worker.Run` / `Worker.SetValue` 等变量 receiver 行为不变，
  同时让 `TWorker.Create(42)` 进入同一份 compiler-owned binding truth。
- `stage0-query-member-call-bindings-check` 现在同时固定 `Create` / `Run` / `SetValue` / `Add`
  的 `member-call` 与 `queryDefinitions` truth，并继续确认 query surface 保持
  MIR/backend/toolchain deferred。
- 收口复查曾发现残留 `./tests/run_all_tests.sh --filter smoke` 进程；本轮接手后未保留
  semantic fixture failure 复现条件，最新 fresh `bash build/verify_local.sh` 已确认
  `semantic` smoke 使用当前 14 个 fixture 且全部通过。旧
  `.sisyphus/tmp/harness/semantic-type_mismatch_fail` 目录只是历史 artifact，不参与当前 fixture
  收集。
- Batch 68 仍不声明 runtime constructor allocation / lowering、完整 static class method
  semantics、full overload/type dispatch、virtual dispatch、record/property 或 array/deref receiver。
- Batch 67 关闭 expression-position member function call 的第一条正向边界：
  `Halt(Worker.Add(1, 2));` 现在会把参数表达式里的 `Worker.Add(...)` 注册为 `member-call`，
  并指向 `TWorker.Add` method symbol。
- 真实缺口不在 method lookup，而在 binding walker 的 wrapper skip：为避免
  `gnkProcedureCallStatement` 包住同 offset `gnkFunctionCall` 时重复注册，旧实现整棵跳过 wrapped
  child，连参数里的嵌套 call 也一起跳过。
- 新策略是只跳过 wrapper callee 自身，继续递归 wrapped function-call 的参数表达式；这保留 Batch 60
  以来的 duplicate binding guard，同时让 expression-position direct member function call 进入
  compiler-owned binding truth。
- Batch 66 把 `member-call` 从零参数 direct class receiver 推进到参数个数匹配：`Worker.SetValue(7);`
  现在会绑定到 `TWorker.SetValue` method symbol，缺参 `Worker.SetValue;` 不会再因为 method name
  match 被误注册。
- member-call 参数个数匹配仍不等于完整 overload/type dispatch：当前只在存在同名 `TClass.Method`
  body declaration 时要求 `CountDeclParams(...)` 与 call argument count 恰好唯一匹配；同名同参数个数
  的多个 body declaration 仍保持不绑定。
- `stage0-query-member-call-bindings-check` 现在用
  `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 固定 `query-bindings` /
  `queryDefinitions` 中的 `member-call` truth，并确认 query surface 仍保持 MIR/backend/toolchain
  deferred。
- 更复杂的 expression-position member binding 仍保持 deferred：当前只承诺 direct class variable
  receiver 的 `Halt(Worker.Add(1, 2))` 形态；constructor、record/property、array/deref receiver、
  virtual dispatch 与 type-based overload 还需要后续 AST/member expression binding 设计。
- Batch 65 把 selector/member binding 从“只排除误绑定”推进到第一条正向 truth：root source
  中 direct class variable receiver 的零参数 class method call（`Worker.Run;` 与
  `Worker.Run();`）现在会注册 `member-call` binding，并指向 `TWorker.Run` 的 `method`
  semantic symbol。
- member-call binding 不复用 `RegisterClassVar(...)` 这类后端 runtime lowering 副表；receiver
  类型来自已 seed 的 `variable` symbol 的 `TypeId`，target 来自同一份 `TSemanticModel` 中的
  `TClass.Method` / `method` symbol。
- Batch 65 仍不声明完整 selector/member lookup：非零参 class method、overload/type-based
  dispatch、virtual/override dispatch、record method、property accessor、array/deref receiver 与
  constructor binding 都继续保持 deferred。
- Selector/member statement call 的真实风险点已经被 Batch 64 RED 抓住：`Holder.Help();`
  会被 parser 表达成 procedure-call statement 包住 qualified `gnkFunctionCall`，旧
  `SeedCallBindingsInNode(...)` 会继续按 name-only `Help` + 0 参数查找，进而误绑定到 imported
  unit 的 bare `Help` procedure。
- `Holder.Help;` 过去没有误绑只是因为当前 parser wrapper 让 `CallArgumentCount(...)` 返回 1，
  与 imported 0 参数 `Help` 偶然错开；这个行为不能作为长期 contract。
- `TSemanticAnalyzer.IsQualifiedCallNode(...)` 现在显式排除 dot/array/deref selector callee，
  让 name-only binding 只覆盖 bare procedure/function call。完整 selector/member access binding
  仍然留给后续 member lookup 与 type-based dispatch，不由 imported callable lookup 代偿。
- `build/verify_local.sh` 的 stage0 bootstrap 与 lexer/parser/sema bench build dirs 现在使用
  run-private `.sisyphus/tmp/verify-local.<run>/...`，避免并发 verify 或失败重跑互相删除固定目录。
- lexer/parser/sema bench 现在统一通过 `tools/bench/np_bench_timing.pas` 读取 process CPU time，
  并由 verify gate 断言 `*-bench-timing-source=process-cpu`；这让 smoke perf floor 更接近代码自身
  成本，而不是宿主调度等待。
- `nextpas query symbols` 现在会把 binding target definition metadata 作为
  `query-definitions=<json-array>` 与 envelope `queryDefinitions` 投影出来；该 JSON 由
  `TCompilationSession.DefinitionsJson` 从同一份 `TSemanticModel` 的 binding table 与 symbol graph
  派生。
- RED gate 已证明旧 query surface 缺少 definition target projection：fresh verification 失败在
  `missing-stage0-query-definitions-detail`；focused GREEN probe 已确认
  `hello_with_units.pas` 的 `SayHello` call definition target 投影为
  `targetName=SayHello`、`targetKind=procedure`、`targetOwnerUnitName=Stage0Greeter`、
  `targetSourcePath=.../units/linux-x86_64/Stage0Greeter.pas` 与 `targetByteOffset=32`。
- query definition projection 仍是 compilation-session-backed 只读 semantic query；它不新增
  `LanguageServiceSession`，不执行 MIR/backend/toolchain，也不扩展 selector/member access、
  bare function-reference binding、references、rename 或 completion。
- `nextpas query symbols` 现在正在接入 `TSemanticModel` 的 binding side table：计划公开
  `query-bindings=<json-array>` 与 envelope `queryBindings`，条目字段直接来自
  `TSemanticBinding` 的 `bindingId/kind/name/ownerUnitId/byteOffset/targetSymbolId`。
- RED gate 已证明旧 query surface 缺少 binding projection：fresh verification 失败在
  `missing-stage0-query-bindings-detail`；focused GREEN probe 已确认
  `hello_with_units.pas` 的 `SayHello` call occurrence 投影为
  `targetSymbolId=1` 的 call binding。
- query binding projection 仍是 compilation-session-backed 只读 semantic query；它不新增
  `LanguageServiceSession`，不执行 MIR/backend/toolchain，也不扩展 selector/member access 或
  type-based overload resolution。
- Root source call binding 现在已经覆盖 imported unit callable 的最小边界：`SeedImportedUnitBodies`
  会解析 resolved imported units，并为 imported procedure/function declarations seed owner-aware
  callable symbols；`RegisterProcedureBody` 同步保存 owner unit id。
- `LookupCallBindingDeclaration` 当前采用保守绑定规则：root callable 优先；如果 root 没有唯一匹配，
  imported callable 也必须只有一个同名同参数数目的匹配才会成为 binding target。
- `tests/semantic/test_semantic_call_bindings.pas` 现在覆盖 `Help;` 调用绑定到 `Helper` unit 的 callable
  symbol，同时用 `Holder.Help := 1`、`Holder.Help;` 与 `Holder.Help();` 固定 selector/member
  access 不应误注册为 imported call binding。
- owner-aware imported callable symbols 让 `examples/smoke/hello_with_units.pas` 的 semantic smoke
  `symbol-count` 从 4 变成 6；这是 imported callable truth 进入 semantic model 的结果，不是
  verifier 假绿。
- `pkg plan` 现在会在 lockfile valid、manifest-lock identity match 之后继续检查 target snapshot：
  如果 lockfile 已有 `[[snapshot]]` 集合但没有 requested target，install plan 会 blocked 为
  `package-lock-target-snapshot-missing`。
- `tests/fixtures/package_lock_target_snapshot_missing` 固定了 lock entry 与 manifest identity 匹配、
  lock status ready、但 snapshot target 只有 `linux-aarch64` 的边界；fresh verification 已确认
  `linux-x86_64` 请求会停在 target snapshot missing blocker。
- target snapshot missing 仍是 read-only preflight：它不让 lockfile invalid，也不触发 resolver、
  version solving、fetch/install、lockfile rewrite 或 migration。没有 snapshot 的既有最小 v1
  lockfile 继续兼容 ready path。
- `TSemanticModel` 现在新增 `TSemanticBinding` side table，用于表达 source-addressable binding
  truth：当前最小字段为 binding id、kind、name、owner unit id、source byte offset 与 target
  semantic symbol id。
- `TSemanticAnalyzer` 现在会在 `AssignScopesToSymbols` 后生成 root procedure/function call
  bindings；这条路径复用已有 callable body registry 和 semantic symbols，不让 downstream adapter
  自行猜 symbol。
- overloaded procedure call binding 现在使用 call argument count 选择 target declaration；focused
  test 已覆盖 `Pick;` 与 `Pick(1);` 分别绑定到 0 参数与 1 参数 overload。
- parser 目前会把某些 `Pick(1);` 表达成 wrapper `gnkProcedureCallStatement` 内含同 offset
  `gnkFunctionCall`；semantic binding walker 会跳过这种 wrapper child，避免同一个 source
  occurrence 产生重复 binding。
- `tests/semantic/test_semantic_call_bindings.pas` 已覆盖 procedure call、function call 与 overloaded
  procedure call；`build/verify_local.sh` 已新增 `semantic-call-bindings-check=pass`，最终
  verify-local envelope 也投影 `semanticCallBindingsCheck":"pass"`。
- 当前 binding contract 已承诺 root source 中普通 procedure/function call、overload arg-count
  消歧与 imported unit callable binding；selector/member access、bare identifier function-reference
  binding 与完整 type-based overload resolution 仍是后续
  language-service contract 工作，不能被 downstream 包装成已完成。
- Batch 60 给 `nextpas.lock` snapshot skeleton 增加了最小一致性校验：snapshot `selection`
  必须匹配某个 lock entry 的 `name@version`，否则投影
  `package.lock.snapshot-selection-unmatched`。
- `compiler/frontend/np_package_lock.pas` 现在还会把非 `sha256:` digest shape 与重复 snapshot
  target 标成 lock issues；这些仍然只是 parser-side read-only validation，不触发 resolver、
  fetch/install 或 lockfile write。
- `tests/fixtures/package_lock_snapshot_invalid` 固定了 lock entry `0.1.0` 但 snapshot selection
  指向 `0.2.0` 的边界；fresh verification 已确认该路径进入
  `package-lock-status=invalid` 与 `package-lock-invalid` blocker。
- `build/verify_local.sh` 已新增 `stage0PkgPlanLockSnapshotInvalidCheck=pass`，用于冻结 snapshot
  consistency invalid path。
- Batch 59 把 `nextpas.lock` 的最小 v1 只读 parser 从 `[[package]] name/version` 扩展到
  `[[snapshot]] target/provenance/digest/selection` skeleton。
- `TPackageLockTruth` 现在会携带 snapshot count 与 snapshots，stage0 line output 公开
  `package-lock-snapshot-count` 与 `package-lock-snapshots`，command envelope 公开
  `packageLockSnapshotCount` 与 `packageLockSnapshots`。
- `tests/fixtures/package_lock_detail` 现在固定一个 `target=linux-x86_64` 的 snapshot happy path；
  focused probe 已确认 `pkg inspect` 同时输出 snapshot detail，且 `package-install-plan-status`
  仍保持 `ready`。
- `tests/fixtures/package_lock_invalid` 现在固定 `[[snapshot]]` 缺 `digest` 的 invalid path；
  focused probe 已确认该路径投影 `package.lock.snapshot-digest-missing`，并让 `pkg plan`
  停在 `package-lock-invalid` blocker。
- Batch 59 仍然不做 resolver、version solving、fetch/install、lockfile write 或 lockfile migration；
  snapshot skeleton 只是 machine-owned replay shape 的只读投影。
- `package-lock-out-of-sync` blocker 现在有独立 mismatch detail：line output 公开
  `package-install-plan-blocker-expected-package` 与
  `package-install-plan-blocker-lock-entries`，command envelope 公开对应 camelCase 字段。
- mismatch detail 只在 out-of-sync blocker 上输出；focused probe 已确认 ready path 不输出空的
  blocker detail，避免 automation 把空数组误解成阻塞证据。
- Batch 58 仍然不做 resolver、version solving、fetch/install 或 lockfile write；它只把已有
  manifest-lock consistency preflight 的解释力补齐。
- `pkg plan` 现在会在 lockfile valid 之后做最小 manifest-lock identity check：manifest 的
  package name/version 必须出现在 canonical `nextpas.lock` entries 里，否则 install preflight
  会阻塞为 `package-lock-out-of-sync`。
- `TPackageManifestInfo` 现在保存 `[package].version`，并经由 `WorkspaceModel` 进入
  `TPackageWorkflowTruth`；这只是 read-only preflight 输入，不是 resolver 或 lock writer。
- `tests/fixtures/package_lock_out_of_sync` 固定了 manifest `0.1.0` 与 lock `0.2.0`
  不一致的边界；focused probe 已确认实现前会误报 ready，实现后会投影
  `package-install-plan-blocker-code=package-lock-out-of-sync`。
- `build/verify_local.sh` 已新增 `stage0PkgPlanLockOutOfSyncCheck=pass`，用于冻结
  manifest-lock out-of-sync blocked plan path。
- `nextpas.lock` 现在有最小 v1 只读 parser：当前实现读取 `[lockfile] format-version = 1` 与
  `[[package]] name/version`，并通过 `TPackageLockTruth` 投影 format version、entries 与 issues。
- `package-lock-status` 已从存在性 truth 扩展为 `missing|ready|invalid`；invalid lockfile 不再被误报为
  ready，也不会继续落入 `package-lock-missing`。
- invalid lock fixture 会稳定投影 `package-install-plan-status=blocked`、
  `package-install-plan-blocker-code=package-lock-invalid` 与
  `package-install-plan-blocker-message=canonical package lockfile is invalid`。
- `build/verify_local.sh` 已新增 `stage0PkgLockDetailCheck=pass` 与
  `stage0PkgPlanLockInvalidCheck=pass`，分别冻结 lock detail ready path 与 invalid-lock blocked plan path。
- Batch 56 仍然不做 dependency resolution、fetch/install、publish 或 lockfile write；它只把 canonical
  lockfile 的最小可解释读模型纳入 package workflow truth。
- `pkg plan` 的 preflight blocker matrix 现在被完整 gate 到当前 truth 已拥有的四个终止原因：
  `package-manifest-missing`、`package-dependencies-invalid`、
  `package-source-roots-missing` 与 `package-lock-missing`。
- malformed dependency fixture 下的 `nextpas pkg plan` 会稳定投影
  `package-install-plan-status=blocked`、
  `package-install-plan-blocker-code=package-dependencies-invalid` 与
  `package-install-plan-blocker-message=package dependency validation is invalid`。
- `tests/fixtures/package_manifest_no_source_roots` 固定了 manifest/lock ready 但 source roots 为空的
  package truth；该 fixture 下的 `nextpas pkg plan` 会稳定投影
  `package-install-plan-blocker-code=package-source-roots-missing` 与
  `package-install-plan-blocker-message=package source roots are missing`。
- 这个 Batch 55 仍然不做 dependency resolution、fetch/install、publish 或 lockfile write；
  它只把已经存在的 `TPackageWorkflowTruth` preflight truth 纳入 `pkg plan` 专用 promotion gate。
- `pkg plan` 现在不再只靠 ready path 证明自己可用：`build/verify_local.sh` 已新增
  `stage0PkgPlanBlockedCheck=pass` 与 `stage0PkgPlanMissingCheck=pass`，分别冻结
  lockfile 缺失导致的 blocked preflight 和 package truth 缺失导致的 missing preflight。
- workspace member fixture 下的 `nextpas pkg plan` 会稳定投影
  `package-install-plan-status=blocked`、`package-install-plan-blocker-code=package-lock-missing`
  与 `package-install-plan-blocker-message=canonical package lockfile is missing`。
- package-free 临时 workspace 下的 `nextpas pkg plan` 会稳定投影
  `package-workflow-status=missing`、`package-install-plan-status=missing`、
  `package-install-plan-blocker-code=package-manifest-missing` 与
  `package-install-plan-blocker-message=package manifest is missing`。
- `pkg inspect / pkg plan / pkg graph` 现在共享同一份
  `WorkspaceModel` + `TPackageManifestInfo` + `TPackageWorkflowTruth`；其中 `pkg plan` 是真实的
  install plan preflight surface，只读，不碰 resolver、fetch、install 或 lockfile write。
- `nextpas pkg plan --target linux-x86_64` 的负向参数 gate 现在会诚实投影
  `failure-kind=missing-required-option` 与 `human-summary=missing-required-option: --workspace`，
  并在 usage 里公开 `nextpas pkg plan --workspace <root> --target linux-x86_64`。
- fresh `bash build/verify_local.sh` 已再次通过，说明 `stage0PkgPlanCheck=pass`、
  `stage0PkgPlanInvalidArgumentsCheck=pass` 与最终 `verify-local=pass` 已进入正式 promotion path。
- `pkg graph` 现在是一个真正的只读 package workflow projection：它直接复用
  `WorkspaceModel` + `TPackageManifestInfo` + `TPackageWorkflowTruth`，把同一份 truth 展开成
  package root node、declared-dependency nodes 与 `declared-dependency` edges，不碰 resolver、
  fetch、install 或 lockfile write。
- `tests/fixtures/workspace_declared_dependencies/app` 现在会稳定投影
  `packageGraphStatus=ready`、`packageGraphNodeCount=3` 与 `packageGraphEdgeCount=2`，并且
  envelope 会同步携带 `packageGraphNodes` / `packageGraphEdges`。
- `tests/fixtures/workspace_malformed_dependencies/app` 现在会稳定投影
  `packageGraphStatus=invalid`，但仍然把同一份 declared dependencies truth 展开为 root / dependency
  nodes 与 edges，和 package dependency validation 共享同一套只读边界。
- `nextpas pkg graph --target linux-x86_64` 的负向参数 gate 现在会诚实投影
  `failure-kind=missing-required-option` 与 `human-summary=missing-required-option: --workspace`，
  并在 usage 里公开 `nextpas pkg graph --workspace <root> --target linux-x86_64`。
- fresh `bash build/verify_local.sh` 已再次通过，说明 `stage0PkgGraphCheck=pass`、
  `stage0PkgGraphInvalidArgumentsCheck=pass` 与最终 `verify-local=pass` 已进入正式 promotion path。
- `env clean` 现在是一个真正的 workspace-local maintenance surface：它只删除
  `<workspace>/.nextpas/env/selections/<target>.toml` 与
  `<workspace>/.nextpas/env/resolution/<target>.toml`，并通过
  `env-clean-status`、`env-clean-change`、`env-clean-selection-path`、
  `env-clean-resolution-path` 与 `env-clean-removed-count` 投影结果。
- `env clean` 的 repeat 行为已经被收口为 `unchanged` / `0`，不会因为文件已经不存在而重复报
  `removed`；同时 `--toolchain-binding` 也被确认为 invalid-option 边界。
- fresh `bash build/verify_local.sh` 已通过，说明 Batch 51 的 cleanup contract、repeat contract
  与 invalid-arguments contract 都已经进入正式 promotion path。
- `env use` 现在已经是真实 mutation surface：它把 workspace-local preferred binding 写进
  `<workspace>/.nextpas/env/selections/<target>.toml`，并把 selection 结果投影到 line-based
  output 与 `command-envelope=<json>`。
- `env status --workspace <root>` 现在会在没有显式 `--toolchain-binding` 时读取同一份
  selection sidecar，并把 `env-selection-status=ready` 与 selected binding 继续投影出来；
  显式 `--toolchain-binding` 仍然覆盖 workspace-local selection。
- `env sync` 现在会把 workspace-local resolution cache 写进
  `<workspace>/.nextpas/env/resolution/<target>.toml`，并在 line output / envelope 中公开
  `env-resolution-path`、`env-resolution-status=ready` 与 `env-sync-change=materialized|updated|unchanged`。
- fresh `bash build/verify_local.sh` 已再次通过，说明 `env sync` gate 的 workspace-local
  resolution cache contract 和验证脚本变量边界都已收口。
- 这条 selection sidecar 只属于 ArtifactRootSet 管辖的 machine-local state，不回写
  `nextpas.workspace.toml`、`nextpas.package.toml` 或 `nextpas.lock`。
- fresh `bash build/verify_local.sh` 已经把 `stage0EnvUseCheck=pass` 纳入 promotion path，
  所以 `env use` / `env status --workspace` 已进入正式 gate。
- `package-lock-status` 现在已经不再是“path 已知但状态固定 deferred”的空壳字段；
  它会根据 canonical `nextpas.lock` 的存在性投影 `ready|missing`，并由同一份
  `TPackageWorkflowTruth` 贯穿 `doctor` / `pkg inspect`。
- `tests/fixtures/package_manifest_source_root/nextpas.lock` 让 package manifest fixture 形成
  真实 ready path；workspace member / declared dependencies / repo root 仍然缺锁，因此会稳定
  投影 `missing`。
- `package-install-plan-status` 现在改成只读 preflight truth，投影
  `ready|blocked|missing`；有 blocker 时还会同步投影
  `package-install-plan-blocker-code` / `package-install-plan-blocker-message`。
- `tests/fixtures/package_manifest_source_root` 现在会稳定投影 `package-install-plan-status=ready`；
  workspace member / declared dependencies fixture 会因为缺锁稳定投影 `blocked`，而
  `workspace_malformed_dependencies` 会因为 dependency validation invalid 稳定投影 `blocked`。
- Batch 48 已经被 fresh `bash build/verify_local.sh` 验证为 pass，并以 git commit
  `616110c` 收口。
- 当前 `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 顶部已经同步到 `Batch 48`
  install plan preflight truth，不会再误导下一轮“继续”的恢复点。
- 当前 `docs/architecture/architecture-principles-specification.md` 已把用户提出的长期质量目标
  固化为可执行门槛：每个切片都要明确 owner、truth object、projection、promotion gate、
  non-goal 与回退信号；这条规范应作为 `master-roadmap.md`、compiler 自举路线和后续 package /
  language-service / GUI / IDE 工作的共同约束。
- 当前 `query symbols` 的实现已经走 `ResolveWorkspaceModel(...)` 与 `TCompilationSession`，
  并且 public projection 现在同时投影 `querySymbols`、`queryScopes` 与 `queryTypes`；
  这让 CLI/IDE/automation 能直接消费 normalized semantic truth，而不是只知道 query 有结果。
- Batch 37 之后的 focused probe 继续暴露下一层真实缺口：`querySymbols[]` 已经有
  `ownerUnitId`、`scopeId` 与 `typeId`，但如果不投影 `ownerUnitName`、`scopeKind` /
  `scopeName` 与 `typeName` / `typeKind`，CLI、automation 和 future IDE adapter 仍然需要
  自己回查或重扫 semantic truth；因此 Batch 38 选择在 `TCompilationSession.SymbolsJson`
  内从同一份 `TUnitGraph` / `TSemanticModel` 补 semantic metadata，而 Batch 39 则继续把
  `TSemanticScope` / `TSemanticType` graph 作为 normalized `queryScopes` / `queryTypes`
  side tables 投影出来，避免调用方再维护一套 lookup。
- 当前 `compiler/ir/np_hir_builder.pas` 里 `FEntryBlockId` 基础设施已经足够支持 late alloca hoist；
  真正缺的是 `EnsureAlloca(...)` 仍把 `hikAlloca` 发到 current block。
- 当前 `compiler/ir/np_hir_llvm_emitter.pas` 之前依赖 raw `%1/%2/...` 匿名数值 SSA 名，
  并用“按 block 首个 `ResultId` 排序”的方式迁就 LLVM 文本 IR 的顺序编号约束。
- 把 emitter 切到 `%vN` named SSA values 之后，entry-block hoist 可以安全落地，且 block 输出顺序
  可以回到 HIR 原始顺序，不再需要 `ResultId` 排序 hack。
- `tests/hir/test_hir_late_alloca_hoist.pas` + `build/verify_local.sh` 里的 `opt -disable-output`
  probe 已经把这条 contract 冻结下来：late slot 的 `alloca` 必须位于 entry block，生成 IR 也必须可解析。
- 外部审查报告对 `harness` 假绿风险的判断是成立的：
  旧路径确实更接近 fixture/snapshot inventory，而不是完整真实执行。
- 当前 `tests/harness/runner.pas` 已经补成真实执行模型：
  `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt`、`regression`
  都会真实执行，并显式投影 fixture-level 与 smoke-level 结果。
- 当前 `compiler/frontend/np_unit_resolver.pas` 已经补上三个关键 correctness 修正：
  根单元 implementation uses、requested-name mismatch、显式 `System` source upgrade。
- 当前 `compiler/frontend/np_unit_graph.pas` 的 `AddResolvedUnit(...)` 已支持用真实 source-backed
  unit 升级 placeholder 节点，这是显式 `System` 行为变正确的关键。
- 当前 `compiler/syntax/np_green_tree.pas` 已明确接受 `array of const` 这一形态；
  `compiler/sema/np_semantic_analyzer.pas` 的 `GetParamSignature(...)` 也已补上
  `TypeChild` nil guard，避免 `np_diagnostics_sink` 在参数签名抽取阶段 AV。
- `tests/parser/array_of_const_pass.pas` 已新增并纳入 parser smoke，`./tests/run_all_tests.sh --filter parser`
  与 fresh `bash build/verify_local.sh` 都已通过。
- `build/verify_local.sh` 当前已经把新 gate 纳入 promotion path：
  `root-implementation-check`、`requested-name-mismatch-check`、
  `explicit-system-check`、`package-manifest-source-root-check`、
  `workspace-member-source-root-check`、`package-manifest-source-precedence-check`、
  `harness-compiler-pass-check`、`smoke-check`。
- 当前 search path 模型已经不只剩 root source 和 target-installed：
  session 现在还会把 nearest `nextpas.package.toml` 的 source roots、workspace member
  package source roots 与 CLI explicit unit roots 纳入同一条 precedence path。
- 当前 precedence 已经固定为：
  `root-source -> package-source-root -> explicit-unit-root -> target-installed`。
- 当前 `tools/stage0/nextpas.pas` 已经把现有 workspace/package/artifact discovery 结果
  正式提升为 command truth：line-based output 会投影
  `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
  `package-manifest-path`、`artifact-root`、`output-dir`，
  `command-envelope=<json>.result` 也会同步带上 camelCase 版本字段。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小 `test` family：
  `nextpas test --list-groups [--workspace <root>]` 与
  `nextpas test --filter <group> [--workspace <root>]` 都会走 stage0 CLI，
  但真正的 group execution 仍由 `tests/run_all_tests.sh` /
  `tests/harness/runner.pas` 持有。
- 当前 `nextpas test` 的 thin wrapper 会显式把 `NEXTPAS_STAGE0`、
  `NEXTPAS_WORKSPACE_ROOT` 与 `NEXTPAS_REPO_ROOT` 传给 harness；
  driver-side test parse failure 则会继续诚实投影成
  `command=test`、`selector=test` 与 `failure-kind=invalid-arguments`。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `env` surface：
  `nextpas env status --target linux-x86_64 [--toolchain-binding <id>]` 会复用现有
  target/toolchain/distribution/runtime truth，显式投影
  `toolchain-binding-path`、distribution dirs、`runtime-root`、`runtime-libc`、
  `runtime-libc-present`、`environment-readiness` 与 `runtime-sdk-status`。
- 当前 `tools/stage0/nextpas.pas` 也已拥有最小 workspace-local `env sync` surface：
  `nextpas env sync --target linux-x86_64 [--toolchain-binding <id>] --workspace <root>` 会写
  `<workspace>/.nextpas/env/resolution/<target>.toml`，并把 selection 输入、resolved binding、
  distribution/runtime readiness 与 sync delta 公开给 CLI、IDE 与 automation。
- 当前 `env status` 已明确和 `doctor` 分层：即使当前仓库缺少
  `lib/nextpas/runtime/linux-x86_64/libc.so`，命令也继续保持
  `status=success` / `result=success`，把 `environment-readiness=incomplete`、
  `runtime-sdk-status=missing` 与 `runtime-libc-present=false` 当成 state truth，而不是
  command failure。
- 当前 `env status` 已继续补齐 readiness evidence：line-based output 与 envelope 都会投影
  `environment-status` / `environmentStatus`、`toolchain-binding-status` /
  `toolchainBindingStatus` 与 `distribution-status` / `distributionStatus`。
- 当前 `environment-readiness` 保留为兼容字段，并与 `environment-status` 使用同一 derived
  readiness vocabulary；`doctor` 的 binding readiness 也复用同一份 environment projection。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `doctor` surface：
  `nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
  会复用 `env status` 已经使用的 target/toolchain/distribution/runtime truth，并额外投影
  `doctor-status`、`doctor-check-count` 与 `doctor-finding-count`。
- 当前 `doctor` 已明确和 `env sync` / `env use` / `env bootstrap` 分层：即使当前仓库缺少
  `lib/nextpas/runtime/linux-x86_64/libc.so`，inspection 也继续保持
  `status=success` / `result=success`，把健康问题写进
  `doctor-status=warning` 与 `doctor-finding-count=1`，而不是修改环境或把 runtime 缺失误报成
  command execution failure。
- 当前 `doctor` 的 result contract 已从 aggregate summary 继续加固：
  line-based output 会投影 `doctor-workspace-status=ready`、
  `doctor-toolchain-binding-status=ready`、`doctor-finding-code=doctor.runtime-sdk-missing`
  与 `doctor-finding-severity=warning`。
- 当前 `doctor` 的只读 inspection 现在也会把 package/workspace truth 纳入：
  当 `--workspace` 指向没有 package truth 的目录时，会同步投影
  `package-workflow-status=missing`、`package-manifest-status=missing`、
  `package-lock-status=deferred`、`package-install-plan-status=deferred`、
  `package-source-root-count=0`，并给出 `doctor.package-workspace-missing`；这条 finding 仍然不
  改变 `doctor` 的只读边界。
- 当前 `doctor` 的 package/workspace coherence 已经有正反两侧 gate：
  `tests/fixtures/package_manifest_source_root` 会稳定表现为 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1`，并且不会出现
  `doctor.package-workspace-missing`；这防止合法 package workspace 被误报成缺失 package truth。
- 当前 `doctor` 的 workspace descriptor + member package ready 路径也已经进入 gate：
  `tests/fixtures/workspace_member_source_root` 会把显式 workspace descriptor root 稳定解析到
  `app/nextpas.package.toml`，投影 `workspace-descriptor-path`、member
  `package-manifest-path`、`package-root-path`、`package-name`、`package-lockfile-path` 与
  `package-source-root-count=1`，并且不会出现 `doctor.package-workspace-missing`；这防止
  future workspace package tooling 把 workspace root 与 package root 混为一谈。
- 当前 `command-envelope=<json>.result.doctorFindings[]` 会保留同一条 finding 的
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`；这属于
  health inspection result，不替代 compiler diagnostics sink。
- 当前 `build/verify_local.sh` 的 toolchain contract probe 已经不再把
  `tests/toolchain/toolchain_contract_smoke` 与 `.o` 写回源码树：它现在会编译到临时
  `mktemp -d` build dir，并在执行后显式断言源码树里不存在这两个生成物。
- 当前 `build/verify_local.sh` 也已经把 `nextpas test` 的
  `list-groups`、`invalid-arguments`、`unknown-group`、`compiler-pass` 与 `smoke`
  五条 contract 纳入 promotion path，因此 developer tooling 的最小 test 入口不再只靠
  手工运行留证。
- 当前 `build/verify_local.sh` 也已经把 `nextpas env status` 的 success path 与 bare
  `nextpas env` 的 invalid-arguments contract 纳入 promotion path，因此最小 `env`
  公开面不再只靠手工 probe 留证。
- 当前 `build/verify_local.sh` 也已经把 `nextpas doctor` 的 success path 与 bare
  `nextpas doctor` 的 invalid-arguments contract 纳入 promotion path，因此最小 `doctor`
  健康检查入口不再只靠手工 probe 留证。
- 当前 `tools/stage0/nextpas.pas` 现在也已拥有最小只读 `query symbols` surface：
  `nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
  会复用 shared workspace model、target facts 与 `TCompilationSession`，只执行 syntax、
  unit resolution 与 semantic analysis。
- 当前 `query symbols` 已明确和完整 language service 分层：它输出
  `analysis-source=compilation-session`，不宣称拥有 `LanguageServiceSession`、open document
  overlay、incremental invalidation、references、rename preflight 或 completion。
- 当前 `query symbols` 成功路径会投影 `query-kind=symbols`、`query-status=success`、
  `query-result-count=<count>`、`query-symbols=<json-array>`、`query-scopes=<json-array>` 与
  `query-types=<json-array>`，并让 `command-envelope=<json>.result` 同步保留 `queryKind`、
  `queryStatus`、`analysisSource`、`queryResultCount`、`querySymbols`、`queryScopes` 与
  `queryTypes`。
- 当前 `queryScopes` 与 `queryTypes` 不是新的 language service 协议，而是同一份
  `TSemanticModel` 的 normalized side tables；它们保留 `scopeId` / `typeId` 的稳定 identity，
  让调用方可以不再在 CLI 外部自行补 lookup。
- 当前 `build/verify_local.sh` 也已经把 `nextpas query symbols` 的 success path 与 bare
  `nextpas query` 的 invalid-arguments contract 纳入 promotion path，因此最小 `query`
  公开面不再只靠手工 probe 留证。
- 当前 `compiler/frontend/np_package_workflow.pas` 已经存在，并把 package workflow 的第一批
  compiler-owned truth 收成 `TPackageManifestTruth`、`TPackageLockTruth`、
  `TPackageInstallPlanTruth` 与 `TPackageWorkflowTruth`。
- 当前这批 package workflow truth 仍然严格 non-executing：manifest truth 只消费
  `TPackageManifestInfo` 的 manifest/package/source-root 事实，lock/install truth 只冻结
  canonical path/provenance 与 `deferred` 状态，不执行 registry lookup、fetch、solver、
  install placement 或 lockfile write。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  也已经把最小 package workflow contract 纳入真实 gate：
  `package-workflow-manifest-status=ready`、`package-workflow-lock-status=deferred`、
  `package-install-plan-status=deferred` 与 `package-workflow-source-root-count=<non-zero>`；
  这让 package workflow skeleton 不再只靠文档留证。
- 当前 `pkg inspect` 的 detail contract 也已进入 promotion path：line-based output 与
  `command-envelope=<json>.result` 会同时投影 workflow-owned manifest path、package root、
  package name、lock status 与 canonical lockfile path；这仍然是只读 truth projection，
  不执行 fetch、install、dependency resolution、lockfile write 或 publish workflow。
- 当前 `pkg inspect` 的 workspace descriptor + member package ready 路径也已经进入 gate：
  `tests/fixtures/workspace_member_source_root` 会把显式 workspace descriptor root 稳定解析到
  `app/nextpas.package.toml`，投影 `workspace-descriptor-path`、member
  `package-manifest-path`、`package-root-path`、`package-name`、`package-lockfile-path` 与
  `package-source-root-count=1`；这让 `pkg inspect` 与 `doctor` 共享同一条 package workflow
  truth，而不是各自解释 workspace membership。
- 当前 package workflow truth 已经持有完整 `SourceRoots`，不应只公开 count：
  `package-source-roots=<json-array>` 与 envelope `packageSourceRoots` 现在也来自同一份
  `ManifestTruth.SourceRoots`。缺少 package truth 时它稳定为 `[]`，ready package workspace
  则投影 resolved source root 路径，避免 IDE/CI/automation 为了拿 roots 明细再重读 manifest。
- 当前 package workflow truth 已继续持有 declared dependency intent：
  `nextpas.package.toml` 的 `[dependencies]` keyed inline table 会被收成 dependency name /
  requirement，并通过 `package-dependency-count`、`package-dependencies=<json-array>`、
  `packageDependencyCount` 与 `packageDependencies` 只读投影；这仍然不是 dependency
  resolution、fetch/install 或 lockfile write。
- Batch 46 的最新未收口 blocker 是 dependency requirement validation：
  `compiler/frontend/np_package_manifest.pas` 当前 `ParsePackageDependencyInfo(...)` 只抽取
  inline table 里的 `version` / `requirement` 字符串，遇到无法解析的 dependency line 会
  `Continue`，因此 malformed requirement 存在静默消失风险。下一批应把已冻结的最小 grammar
  (`=`、`>`、`>=`、`<`、`<=`，逗号 intersection) 收成 manifest/workflow 层共享 truth，
  并让 `doctor` / `pkg inspect` 公开投影 invalid dependency detail。
- Batch 46 已收口 dependency requirement validation：
  `TPackageManifestInfo` 继续保留所有 declared dependency intent，同时新增 dependency issue
  truth；`TWorkspaceModel.PackageRef` 与 `TPackageWorkflowTruth` 负责把 validation status /
  issue count / issue details 传给 stage0 projection。`doctor` 与 `pkg inspect` 现在都会投影
  `package-dependency-validation-status=valid|invalid|missing`、
  `package-dependency-issue-count=<count>`、`package-dependency-issues=<json-array>`，envelope
  同步投影 camelCase 字段。`tests/fixtures/workspace_malformed_dependencies` 覆盖 `^0.1.0`、
  `~>0.1`、`>=`、`>=0.1.0 || <0.2.0` 与 empty requirement；fresh
  `bash build/verify_local.sh` 已通过。
- 当前 `tests/run_all_tests.sh` 的 stage0 bootstrap failure 已不再把关键回放线索吞掉：
  失败输出会继续带上 `bootstrap-step`、`bootstrap-command`、
  `bootstrap-stderr-file`，并在 stderr 文件非空时直接回显原始 stderr evidence。
- 当前 build/workspace/artifact 相关 truth 已经开始从平铺字段收口：
  `tools/stage0/nextpas.pas` 使用 `TBuildCommandContext` 持有 command-level build context，
  `compiler/frontend/np_compilation_session.pas` 则用 `TBuildContext` 持有
  session-owned build context。
- 当前 `tools/stage0/nextpas.pas` 的 diagnostics/toolchain/build-trace projection
  也已继续从平铺字段收口：
  `TDiagnosticProjectionContext` / `TToolchainProjectionContext` 现在不仅负责
  clear/capture/envelope，也已经覆盖 `PrintSessionProjection(...)` 的
  stdout/stderr mirror；旧 `ActiveDiagnostic*` / `ActiveToolchain*` 残留引用已清除。
- 当前 `compiler/frontend/np_workspace_model.pas` 已经存在，并把 workspace root、
  discovery kind、package refs、project unit root infos、artifact root、output dir、
  host-fpc cache root 与 target selection 收成 compiler-owned `TWorkspaceModel`。
- 当前 `compiler/frontend/np_package_manifest.pas` 现在会为 shared workspace model 提供 typed
  `TPackageManifestInfoArray`、workspace member package info 与 project unit root info；
  parser 职责仍保留在 manifest layer，不再承担最终 workspace ownership。
- 当前 `compiler/frontend/np_compilation_session.pas` 现在会正式拥有并释放
  `WorkspaceModel`；resolver 与 toolchain planner 改为从 model 读取
  `ProjectUnitRootInfos` / `ProjectUnitRoots`。
- 当前 `tools/stage0/nextpas.pas` 现在会先调用 `ResolveWorkspaceModel(...)`，
  从 model 捕获 pre-session build context，并在创建 `TCompilationSession` 后把 ownership
  交给 session；旧 driver-side workspace discovery / artifact placement helper 已被收缩掉。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  现在已经把 explicit workspace、nearest package manifest 与 workspace member 的
  workspace model contract 纳入真实 gate；fresh `bash build/verify_local.sh`
  继续得到 `toolchainContractCheck=pass` 与 `verify-local=pass`。
- 当前 `compiler/toolchain/np_toolchain_runner.pas` 已存在，并能顺序执行 ready
  `TToolchainPlan` 的 steps：它会准备 working/output/sidecar 目录、解析 executable path、
  物化 `response-file` / `resource-list-script` / `archive-command-script`，真实调用外部进程，
  再按 `delete-on-success` 回收 sidecar，并留下 per-step status / exit code。
- 当前 `compiler/frontend/np_compilation_session.pas` 也已把 generic runner 正式接回
  当前 `bootstrap-native-assemble-link` production path：`ExecuteToolchain(...)` 现在直接复用
  `ExecuteToolchainPlan(...)`，并让 session 正式拥有 `tool-run-status`、
  `tool-run-step-count` 与 `primary-tool-run-status`。
- 当前 `tools/stage0/nextpas.pas` 已不再手写 `ResolveCompilerExecutable + TProcess`
  执行宿主 FPC；`stage0 build` 现在通过
  `Session.ExecuteToolchain(GetEnvironmentVariable('PATH'))` 走统一 runner，并把真实
  execution result 同步投影到 line-based output 与 `command-envelope=<json>.result`。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  已把 fake `as` + `ld` 的 `native-assemble-link` execution contract 纳入 promotion path：
  `native-run-status`、assemble/link step status、object/output existence、
  response sidecar cleanup、captured response 与 object-path presence 都已被真实 gate。
- 当前 `compiler/toolchain/np_toolchain_plan.pas` 已让 `PlanFromBackend`
  直接选择 `bootstrap-native-assemble-link` production path：
  `host-fpc-emit-asm -> native-assemble -> native-link` 已经进入真实执行面，而不是继续停留在
  single-step host compile。
- 当前主 smoke success path 已被 verify 冻结为
  `toolchain-plan-family=bootstrap-native-assemble-link`、
  `tool-invocation-count=3`、`tool-run-step-count=3`、
  `primary-tool-step-id=host-fpc-emit-asm`、
  `tool-status-event-count=10` 与
  `build-trace-ref=...-toolchain-plan`；显式 source-backed unit 场景还会继续追加
  `native-assemble-<unit>` step，并让 step/event 数量继续增长。
- 当前 `bootstrap-native-assemble-link` production path 的 later-step failure attribution
  已经收口：如果 failure 发生在 `native-assemble` / `native-link`，
  `compiler/frontend/np_compilation_session.pas` 现在会把
  `diagnostic-step-id`、`diagnostic-profile-id`、`diagnostic-logical-executable`、
  `build-trace-ref=trace-<session-id>-toolchain-plan` 与 `tool-status-events` 的
  step metadata 对齐到真实失败 step；
  `build/verify_local.sh` 也已用 fake `as` / `ld` 负路径冻结
  `toolchain.assembler-exec-failed` / `toolchain.linker-exec-failed` contract。
- 当前 success/failure observability 已整体收口：
  `compiler/frontend/np_compilation_session.pas` 现在会把 `buildTrace.steps[*]` 与
  `tool-status-events` 都扩成完整 multi-step transcript，只让真实失败 step 携带
  `diagnosticRefs`。
- 当前 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  也已把 runner sidecar truth 收进正式 gate：`native-run-transcript` 会冻结
  `materialized=true|false` 与 `cleanupStatus=deleted|retained|not-requested`。
- 当前 `tools/stage0/nextpas.pas` 的 build/session projection writer 也已从
  双分支镜像收敛到统一 helper：
  `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)`
  不再各自维护 stdout/stderr 两套 `WriteLn(...)` 实现，而是复用同一组
  text/integer/boolean projection writer。
- 当前 `tools/stage0/nextpas.pas` 的剩余 session/syntax/resolution/semantic/mir/backend
  projection state 也已继续从平铺 `Active*` 收口到分组 record：
  `TSessionProjectionContext`、`TSyntaxProjectionContext`、
  `TResolutionProjectionContext`、`TSemanticProjectionContext`、
  `TMirProjectionContext`、`TBackendProjectionContext` 现在已经覆盖
  `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
  `CaptureSessionContext(...)` 与 `PrintSessionProjection(...)`；
  旧 `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` /
  `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 残留引用已清除。
- 当前 `tools/stage0/nextpas.pas` 也已把剩余的分组 projection 序列化 / 输出细节继续收敛到
  helper：
  `BuildCommandEnvelopeJson(...)` 现在通过一组
  `Append*ProjectionJsonFields(...)` helper 拼接 result 字段，
  `PrintSessionProjection(...)` 现在通过一组
  `Print*Projection...(...)` helper 输出 line-based projection；
  fresh `bash build/verify_local.sh` 已确认字段顺序、启停条件和
  pre-session/session-owned 边界没有漂移。
- 当前 `tools/stage0/nextpas.pas` 的 clear/capture 路径也已继续收敛到按 record 分组的
  helper：
  `ClearBuildCommandContext(...)`、`ClearSessionContext(...)`、
  `CaptureBuildCommandContext(...)`、`CaptureSessionContext(...)`
  不再各自内联维护大段字段搬运，而是统一调 build/session/diagnostics/syntax/
  resolution/semantic/mir/backend/toolchain 分组 helper；fresh
  `bash build/verify_local.sh` 已确认行为无漂移。
- 当前 `invalid-unit-root` 这类在 session 创建前就失败的路径，也已经不再退回成只有
  `failureKind` 的贫血结果：已知的 `workspace-root` / `artifact-root` / `output-dir`
  等 build context 会继续出现在 line-based output，而
  `command-envelope=<json>.result` 仍保留 `source`、`target` 与 camelCase 对应字段。
- focused probe 已确认同一条 pre-session projection 也真实覆盖
  `invalid-out-dir` 与 `invalid-artifact-root`；这一批不需要继续改
  `tools/stage0/nextpas.pas`，只需要把 verify gate 补齐。
- focused probe 也确认：当 source 周围不存在 `nextpas.workspace.toml` /
  `nextpas.package.toml`，且 CLI 不传 `--workspace` 时，当前真实行为已经是
  `workspace-discovery-kind=source-directory-fallback`，workspace root 退回 source 所在目录，
  默认 artifact 则进入 `<source-dir>/.nextpas/out/linux-x86_64/`。
- 对 `build/verify_local.sh` 做 focused audit 后确认：虽然
  `package-manifest-source-root-check`、`workspace-member-source-root-check`、
  `package-manifest-source-precedence-check` 都已经在真实 promotion path 里跑通，但
  `verify-local` 最终 success envelope 之前还没有同步它们的 camelCase result field。
- focused probe 也确认：`explicit-unit-root`、`out-dir-override`、
  `package-manifest-source-precedence`、`root-source-precedence`、
  `unit-root-precedence` 这些成功路径，当前真实的 `command-envelope=<json>.result`
  已经带有 `outputDir`、`artifact`、`searchPathCount` 与 `searchPaths`；缺口只是
  verify 之前还没有把这批 machine-readable truth 冻结下来。
- focused probe 还确认：`workspaceDescriptorPath` / `packageManifestPath`
  当前不是“总是带字段，有时为空”，而是按 discovery truth 按需出现：
  `stage0-smoke`、`source-directory-fallback`、`invalid-unit-root`、
  `invalid-out-dir`、`invalid-artifact-root` 都不会投影这两个字段；
  `package-manifest-source-root` 与 `package-manifest-source-precedence`
  会只带 `packageManifestPath`，不带 `workspaceDescriptorPath`；
  `workspace-member-source-root` 则会同时带上两者。
- focused probe 进一步确认：剩余 explicit-workspace 主路径
  `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
  `root-source-precedence`、`unit-root-precedence` 与 sessionful failure 的
  `toolchain-failure` 也都稳定省略 `workspaceDescriptorPath` /
  `packageManifestPath`；之前缺的只是更广覆盖的 verify 断言。
- 恢复会话后 fresh rerun `bash build/verify_local.sh` 继续得到
  `verify-local=pass`，说明这批 explicit-workspace omission 断言已经与当前实现一致，
  不需要再改 `tools/stage0/nextpas.pas`。
- focused probe 还确认：当前 `tools/stage0/nextpas.pas` 已经把
  `diagnostics-summary` / `human-summary` 当成共享 summary surface 稳定发出：
  success path 会给出 `diagnostics-summary=none` / `human-summary=build succeeded`，
  syntax / resolution / sema / toolchain failure 会给出对应的 diagnostic summary 与阶段级
  human summary，而显式 workspace 的 pre-session failure 也会继续镜像 envelope 顶层
  `humanSummary`；缺口只是 verify 之前没有把这层 contract 明确冻结。
- 当前 `compiler/frontend/np_unit_resolver.pas` 的 missing/ambiguous diagnostics
  已经不再只输出裸路径：`SearchRootsSummary` 与 `CandidateSummary` 现在会消费
  `TSearchPathEntry`，把 `scope` / `provenance` / `root`（以及 candidate `path`）
  一起投影进 diagnostic message。
- 新一轮 focused verification 已确认：`session-id`、`tool-invocation-plan-ref`、
  `build-trace-ref` 现在都已改成每次 build 唯一；`verify_local.sh` 已从“固定字面量断言”
  切到“同轮一致、跨轮不复用”的真实 contract。
- `compiler/diagnostics/np_diagnostics_sink.pas` 现在已拥有最小 warning contract：
  `EmitWarning` 会产出 severity=`warning` 的 structured diagnostic，
  `SetWarningAsError(true)` 会把同类 warning 提升为 severity=`error`。
- `compiler/diagnostics/np_diagnostics_sink.pas` 现在也已把 split accounting 固定下来：
  promoted warning 会进入 `ErrorCount`，而不会继续留在 `WarningCount`。
- `compiler/frontend/np_compilation_session.pas` 现在已把 diagnostics split 继续投影到
  session / stage0 result：
  line-based output 有 `diagnostics-error-count`、`diagnostics-warning-count`，
  `command-envelope=<json>.result` 也有 `diagnosticErrorCount`、
  `diagnosticWarningCount`。
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  现在已把上述 warning / warning-as-error 行为，以及 resolver search index 的
  `deferred -> ready` 状态、indexed root count 与 scan count 收进 promotion path。
- `compiler/frontend/np_unit_resolver.pas` 现在已引入最小 per-root search index，
  同一 root 的 candidate lookup 不再每次调用都重新全量扫描目录。
- `compiler/frontend/np_compilation_session.pas` 与 `tools/stage0/nextpas.pas`
  现在已把 resolver search index 公开成 session-owned projection：
  `search-index-status`、`indexed-search-root-count`、`search-index-scan-count`
  会跟随真实 lookup 行为变化，而不是总被伪装成 `ready`。
- fresh rerun `./build/verify_local.sh` 已确认：
  `examples/smoke/hello.pas` 继续如实表现为
  `search-index-status=deferred` / `0` / `0`，
  `examples/smoke/hello_with_units.pas` 则如实表现为
  `search-index-status=ready` / `2` / `2`。
- 新一轮 focused probe 也确认：
  `explicit_unit_root`、`package_manifest_source_precedence`、
  `root_source_precedence` 与 `unit_root_precedence` 这些 precedence 成功路径
  都会稳定投影 `search-index-status=partial`，而且 indexed root / scan count
  会随着命中 tier 变化：
  - root-source precedence：`1 / 1`
  - explicit/package precedence 代表路径：`2 / 2`
- `build/verify_local.sh` 现在已把这批 `partial` 行为纳入 promotion path，
  不再只靠手工 probe 留证。
- 当前“编译成功”仍然有明确 bootstrap-host 边界：
  resolution/graph/diagnostics 与 native assemble/link 已进入 nextPas 控制面，但第一步
  `host-fpc-emit-asm` 仍依赖宿主 `fpc` 发射汇编。
- 当前 Stage2 compiler-module self-compile 的首个真实 parser blocker 不是 `FreeAndNil`、
  `Format` 或 `SysUtils` 尾部缺 `implementation`，而是
  `class(Exception);` 这种 shorthand 派生类声明；nextPas parser 对
  `class(Exception) ... end;` 稳定，但对 shorthand 仍会把失败拖到 EOF 才报
  `"IMPLEMENTATION" expected`。
- 当前 `compiler/backend/np_backend_plan.pas` / `compiler/toolchain/np_toolchain_plan.pas`
  原先无条件把 root source 当成 `executable`，这对 compiler units 是错误模型；
  把 `unit` roots 明确降成 `object-file`，并让 toolchain 只走
  `bootstrap-native-assemble`，才能让 self-hosting 成功边界和真实产物形状对齐。
- `build/verify_local.sh` 现在已经把 compiler-module self-compile 纳入 promotion path：
  `np_diagnostics_sink`、`np_source_database` 与 `np_workspace_model` 必须在
  `backend-output-kind=object-file`、
  `toolchain-plan-family=bootstrap-native-assemble`、
  `logical-link-request-status=deferred` 下稳定成功，而且不得偷偷退回 `native-link`。
- `np_workspace_model` 这条 self-compile contract 还额外冻结
  `tool-invocation-count=2` / `tool-run-step-count=2`，防止 unit root 被误扩成 transitive
  extra assemble 或 native link。

## Technical Decisions

| Decision                                                                                                                               | Rationale                                                                                                               |
| -------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------- | ----------------------------------------------------------------------------- |
| 先把 `smoke` 和 CI 变成真实 gate，再继续扩功能                                                                                         | 没有可信验证，后续所有阶段都会被假进展污染                                                                              |
| harness 只按 group 契约收集 `.pas` fixture                                                                                             | 让测试输入和源码树生成物彻底解耦                                                                                        |
| snapshot-bearing groups 统一对比 canonical actual text                                                                                 | 降低输出噪声，提高 baseline 的稳定性和可回放性                                                                          |
| `resolver.unit-name-mismatch` 进入正式 failure model                                                                                   | 防止“文件名像是对的”却静默绑定错误 unit                                                                                 |
| implicit `System` 保留 graph 语义，但显式 `uses System` 必须继续解析真实源码                                                           | 同时保留 runtime edge 显式性和 source provenance correctness                                                            |
| 文档只写当前已验证事实，并明确标注 search path / host-backed 限制                                                                      | 避免把设计目标误写成当前能力                                                                                            |
| `stage0 test` 继续做 thin wrapper，而不是重写 harness                                                                                | harness 已经是 execution owner；driver 只该负责 CLI parse、workspace root 选择与 env bridge                           |
| planning files 与架构文档必须同步最小 package/workspace source root 现状                                                               | 避免下一轮恢复时被过时的“project roots 未落地”表述误导                                                                  |
| 长期质量目标必须先落成 `architecture-principles-specification.md`，再继续扩局部能力                                                   | 防止“现代、高性能、优雅、一流框架”只停留在口号；后续切片要围绕 owner、truth object、projection、promotion gate 和 non-goal 做取舍 |
| 当前 rolling plan 必须进入 docs-check                                                                                                  | 它是后续“继续”恢复当前生产路径的活动入口，不能只靠人工记忆避免 Batch 状态漂移                                           |
| `query symbols` detail 必须由 `TCompilationSession` 投影，而不是由 CLI 重扫源码或 scrape build output                                  | 这样 future IDE/automation 可以复用同一份 semantic symbol graph，同时保持 `stage0` 只是 thin entrypoint                 |
| `.sisyphus/`、FPC 中间产物、runner/bootstrap 产物、snapshot diff evidence 和已知 smoke/example 产物统一进入 ignore                     | 降低源码树污染，避免历史生成物继续影响测试与工作区判断                                                                  |
| resolution diagnostics 继续沿用现有 message 通路，只在 formatter 层接入 typed search-path provenance                                   | 保持改动面最小，同时把 consulted root / candidate origin 变成 verify-able output                                        |
| workspace discovery 这一批只做“已有 truth 的稳定投影”，不提前引入完整 workspace model                                                  | 保持变更 grounded 在当前实现上，同时让 CLI / envelope 更诚实                                                            |
| early failure 继续复用 `Active...` command context，而不是再发明 session-less pseudo model                                             | 保持 ownership 边界不变，同时避免 pre-session failure 丢掉已知 build truth                                              |
| 如果 focused probe 已证明行为存在，下一步先补 verify gate 而不是先改实现                                                               | 让增量更小，也让 promotion path 尽快覆盖真实已落地行为                                                                  |
| verify-local 的 success envelope 也要同步新增 gate 名称                                                                                | 避免结构化 verify 结果落后于 shell gate 现状                                                                            |
| `diagnostics-summary` / `human-summary` 既然已被规范列为最小结果表面，就应一起进入 verify gate                                         | 避免共享 summary surface 继续只靠实现自觉，而没有 promotion-path 保护                                                   |
| session / plan / trace locator 的契约应是“唯一且一致”，不是固定字面量                                                                  | 避免 verify 和文档把实现细节误冻结成错误的公开协议                                                                      |
| 继续扩 toolchain projection 前，先补 semantic diagnostics 和 workspace/source-root truth                                               | 当前最需要的是 ownership 变真实，而不是再增加更多外层投影字段                                                           |
| resolver search index 继续保持 lazy，并把 `deferred                                                                                    | partial                                                                                                                 | ready` 当成有效结果 | 这比强行 eager 扫描更诚实，也更符合 session 当前真实消费过的 search-root 状态 |
| `partial` 必须被当成 precedence 命中的正常成功状态，而不是模糊中间态                                                                   | 只有把它正式 gate 住，后续才能防止高优先级命中后又退化回低价值的全量扫描                                                |
| toolchain contract smoke 必须在临时 build dir 里编译，并显式证明源码树没有被生成物污染                                                 | 否则 verify 自己会继续制造 source-adjacent output，削弱 hygiene contract                                                |
| harness bootstrap failure 必须保留 step/command/stderr locator 和原始 stderr evidence                                                  | 否则 CI 或本地回放仍只看到模糊 failure kind，无法快速定位 bootstrap 失败点                                              |
| internal compaction 必须保持在 owned-shape 层完成，而不是一半 record 一半平铺全局                                                      | 否则后续维护仍要同时理解两套 state surface，增加实现漂移风险                                                            |
| projection writer 也必须收敛到单一路径，而不是 stdout/stderr 各维护一套镜像 `WriteLn(...)`                                             | 否则任何字段调整都容易只改到一边，重新制造 surface drift                                                                |
| 剩余 session/syntax/resolution/semantic/mir/backend projection 也应按阶段 record 化，而不是继续让四条主路径直接消费散落 `Active*` 字段 | 这样才能让 owner shape 一致，同时保持 envelope / CLI surface 不变                                                       |
| 分组 projection 的 JSON 拼接与 line-based 输出细节也应继续收敛到 helper，而不是长期留在两个大函数里                                    | 这样后续再做 compaction 时更容易守住字段顺序、启停条件和 ownership 边界                                                 |
| clear/capture 路径也应按 record helper 收敛，而不是继续把字段清理和复制集中在两个超长入口里                                            | 这样 owner shape 才能在 capture、clear、envelope、print 四条主路径上同时一致                                            |
| 在 backend 还没有 assembly/object intermediate truth 之前，不把 `stage0 build` 伪装成 multi-step native assembler/linker               | 否则会把 typed plan、backend artifact truth 与真实 production path 说错；先落通用 runner 和 contract gate 更诚实        |
| `TToolchainPlan` runner 继续只消费 typed `steps/inputs/outputs/sidecars`，不接受退化回 shell string 的执行模型                         | 这样 future assembler/linker/resource/archiver 复用同一份 plan ownership，而不是重新逃回临时脚本拼接                    |
| 当前 host-compiler production path 也必须复用同一套 runner，而不是继续保留 driver 私有 `TProcess` 路径                                 | 这样 `stage0 build` 的 selection/start/success/failure bookkeeping、CLI projection 与 execution contract 才不会长期分叉 |

## Issues Encountered

| Issue                                                                                                                                                                                              | Resolution                                                                                                                                                                                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 历史 runner、fixture 二进制和 `.o/.ppu` 直接留在源码树里                                                                                                                                           | 补齐 `.gitignore`，并清理已确认的历史生成物、过期 diff 与 fresh verify 产物                                                                                                                                                                    |
| 旧文档仍在描述 inventory-style harness                                                                                                                                                             | 全面回写 `tests/` README 与架构规范，改成真实执行语义                                                                                                                                                                                          |
| `unit-resolution` / `stage0` 文档与 planning files 落回了旧 search path 说法                                                                                                                       | 改回“当前已支持最小 package/workspace source roots，并继续诚实标注非完整 workspace truth”                                                                                                                                                      |
| 容易把当前绿灯误解成“nextPas 已经独立编译全部路径”                                                                                                                                                 | 在 README、架构规范和 planning files 里明确标注 host-backed 边界                                                                                                                                                                               |
| missing / ambiguous unit diagnostics 仍只显示裸路径，无法说明候选来源                                                                                                                              | 在 resolver formatter 层复用 `TSearchPathEntry`，补齐 `scope` / `provenance` / `root` / `path`                                                                                                                                                 |
| workspace / artifact discovery 真实存在，但 CLI / envelope 之前没有把它们当正式 command truth 投影出来                                                                                             | 在 `TCompilationOptions` / `TCompilationSession` 补最小 metadata，并让 stage0 输出/结构化结果同步带上这些字段                                                                                                                                  |
| `invalid-unit-root` 会在 session 创建前失败，导致 failure envelope 一度丢掉已知的 workspace/artifact/output truth                                                                                  | 继续沿用 `Active...` command context，并让 `PrintSessionProjection(...)` 先投影 build context，再按 `session-id` 决定是否打印 session-owned fields                                                                                             |
| `invalid-out-dir` / `invalid-artifact-root` 已经有正确行为，但 promotion path 之前没有 gate 覆盖                                                                                                   | 先用 focused probe 确认现状，再把两条 early-failure baseline 收进 `build/verify_local.sh`                                                                                                                                                      |
| `source-directory-fallback` 行为已在位，但 verify 之前没有冻结这条成功路径的 workspace/artifact contract                                                                                           | 用临时 source-dir probe 确认现状后，补齐 `source-directory-fallback-check` 与 verify-local success envelope 字段                                                                                                                               |
| 三条 package/workspace source-root gate 已经存在，但 verify-local success envelope 仍漏掉对应 machine-readable 字段                                                                                | 先做 gate/result 对照，再把 `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、`packageManifestSourcePrecedenceCheck` 补进最终 `command-envelope=<json>.result`                                                               |
| 多条 success path 虽然已在 envelope 里投影 `outputDir` / `artifact` / `searchPaths`，但 verify 仍主要只看 line-based output                                                                        | 先做 focused probe 确认 truth 已在位，再为 `explicit-unit-root`、`out-dir-override` 与几条 precedence gate 补齐 envelope 断言                                                                                                                  |
| descriptor / manifest projection 的“缺失边界”之前主要靠实现自觉，verify 只冻结了部分 presence case                                                                                                 | 先做 focused probe 确认按需省略已在位，再把代表性 success / failure 路径的 line/envelope absence contract 补进 `build/verify_local.sh`                                                                                                         |
| remaining explicit-workspace 主路径虽然也稳定省略 descriptor / manifest 字段，但 verify 之前只做了代表性 absence 覆盖                                                                              | 继续对 `semantic-smoke`、`explicit-unit-root`、几条 precedence / override 成功路径与 `toolchain-failure` 做 focused probe，并补齐 absence 断言                                                                                                 |
| `diagnostics-summary` / `human-summary` 虽然已由共享输出路径稳定发出，但 verify 之前只零散覆盖少数 failure 文本                                                                                    | 先对 success、sessionful failure 与 pre-session failure 做 focused probe，再把 representative summary line/envelope contract 补进 `build/verify_local.sh`                                                                                      |
| 旧文档把 `plan-build-linux-x86_64-file-1-*` / `trace-build-linux-x86_64-file-1-*` 写成固定示例，已经和实现不符                                                                                     | 全面改成 `plan-<session-id>-...` / `trace-<session-id>-...`，并在规范里明确“唯一且一致”才是正式契约                                                                                                                                            |
| 路线图近期建议一度偏向 richer toolchain projection，容易掩盖 semantic/workspace truth 仍待补强的现实                                                                                               | 在 master roadmap 和 master roadmap plan 里把近期优先级改回 warning contract、resolver/workspace truth，再谈更丰富的 toolchain 外层投影                                                                                                        |
| parser 当前对 shorthand `class(Exception);` 不稳定，而 compiler RTL / frontend/toolchain source 恰好大量使用这种写法                                                                               | 把 shorthand 统一降格为显式 `class(Exception) ... end;`，先把语法形态收敛到已验证路径，避免 Stage2 自编译继续卡在 parser 假象上                                                                                                                |
| compiler unit roots 没有 entry point，但 backend/toolchain 之前仍无条件产出 `executable` 并计划 `native-link`                                                                                      | 把 root kind 接入 backend/toolchain；`unit -> object-file`、`program|library|package -> executable`，让产物模型与真实 Pascal root semantics 对齐                                                                                               |
| `compiler/diagnostics` / `compiler` / `unit-resolution` 规范与 planning files 还没有写出 split diagnostics accounting 和 lazy search-index projection                                              | 依据已通过的 toolchain contract 与 smoke verification，把这两条 contract 回写到架构说明和持续记录里                                                                                                                                            |
| precedence 成功路径上的 `partial` search-index 行为之前只在手工 probe 里可见，promotion path 没有正式保护                                                                                          | 在 `build/verify_local.sh` 为 representative precedence 路径补齐 line/envelope 两层 partial-state 断言，并同步 README/架构规范                                                                                                                 |
| `build/verify_local.sh` 的 toolchain contract probe 之前会把 `tests/toolchain/toolchain_contract_smoke` 与 `.o` 留在源码树                                                                         | 改成临时 build dir，并在 verify 里显式断言源码树中不存在这两个生成物                                                                                                                                                                           |
| `tests/run_all_tests.sh` 的 stage0 bootstrap failure 之前只暴露模糊的 `stage0-build-failed`                                                                                                        | 在 bootstrap failure 输出里补齐 `bootstrap-step`、`bootstrap-command`、`bootstrap-stderr-file`，并回显原始 stderr evidence                                                                                                                     |
| `tools/stage0/nextpas.pas` 在引入 projection record 之后，`PrintSessionProjection(...)` 仍残留旧平铺全局字段访问                                                                                   | 把 stdout/stderr session projection 统一切到 `ActiveDiagnosticsProjection` / `ActiveToolchainProjection`，并用 fresh `bash build/verify_local.sh` 确认行为不变                                                                                 |
| `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)` 之前仍各自维护 stdout/stderr 双分支，任何字段调整都要同步改两遍                                                                 | 引入统一 projection writer helper，把 build/session projection 收敛到单一路径，并用 fresh `bash build/verify_local.sh` 确认输出契约未变                                                                                                        |
| `tools/stage0/nextpas.pas` 里剩余的 `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` / `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 仍是散落平铺状态，导致 owner shape 半收口半悬空 | 引入六个 projection context record，并让 envelope、clear/capture 与 session projection 全部改走分组 context，再用 fresh `bash build/verify_local.sh` 确认无行为漂移                                                                            |
| `BuildCommandEnvelopeJson(...)` / `PrintSessionProjection(...)` 虽然已经吃分组 context，但分组字段的具体 JSON 拼接与 line-based 输出仍集中在两个大函数里，后续容易把顺序或启停条件改偏             | 抽出 `Append*ProjectionJsonFields(...)` 与 `Print*Projection...(...)` helper，并用 fresh `bash build/verify_local.sh` 确认 contract 继续稳定                                                                                                   |
| `ClearSessionContext(...)` / `CaptureSessionContext(...)` 以及 build-context 对应入口仍直接维护跨多个 record 的大段字段清理/复制，后续继续 compaction 时容易漏改某一组 projection                  | 抽出按 record 分组的 clear/capture helper，并用 fresh `bash build/verify_local.sh` 确认公开行为继续稳定                                                                                                                                        |
| workspace/package/artifact truth 仍散落在 driver helper、session 字段与 manifest parser 之间，owner boundary 不够诚实                                                                              | 新增 `compiler/frontend/np_workspace_model.pas`，让 `TCompilationSession` 正式拥有 model，并让 `stage0` 改成 shared model consumer                                                                                                             |
| success-path build trace/status-event 之前仍是单步摘要，later-step failure trace ref 也还是 step-anchored                                                                                          | 扩 `compiler/frontend/np_compilation_session.pas` 与 runner transcript，让 success/failure 全部对齐 plan-level `build-trace-ref=trace-<session-id>-toolchain-plan`，并用 fresh `bash build/verify_local.sh` 冻结 full-step transcript contract |
| 当前多步 production path 已经真实执行 root/native steps，但显式 source-backed unit 还需要额外 assemble step 才能保持 smoke 全绿                                                                    | 在 `TCompilationSession` 收集 source-backed unit 的额外 assembly base name，并让 planner 追加 `native-assemble-<unit>` steps，再用 `build/verify_local.sh` 冻结这条 contract                                                                   |

## 2026-05-23 Follow-up Findings

- `compiler/diagnostics/np_diagnostics_sink.pas` 当前必须显式带 `{$UNITPATH .}`，否则同目录
  `nextpas_json_helpers` 不会稳定进入 compiler-module self-compile 的解析面。
- `units/linux-x86_64/SysUtils.pas` 当前还缺一条真实 compiler dependency；
  `IntToHex(Value: Int64; Digits: Integer)` 补齐后，Stage2 / diagnostics path 才重新闭合。
- `compiler/frontend/np_compilation_session.pas` 的 extra-assemble 边界现在已经明确：
  `unit` root 不追加 transitive deps；linked root 会收集 source-backed units，包括
  `installed-source`，但继续跳过 `implicit-runtime`。
- `examples/smoke/hello_with_units.pas` 在 `run_stage0_build_capture` 的 `--fold` 语境下，
  当前真实 contract 已冻结为 `typed-hir-node-count=8`、
  `tool-invocation-count=5`、`tool-run-step-count=5`、
  `tool-status-event-count=16`；先前看到的 `20` 是 verify 脚本期望漂移，不是实现回归。
- fresh `bash build/verify_local.sh` 已再次拿到 `verify-local=pass`，说明这轮修复没有引入
  新的 toolchain / semantic / self-host contract 漂移。
- 后续接手时不要再把 `np_workspace_model` 当作“只在 notes 里成功”的灰色项：它现在已经和
  `np_diagnostics_sink`、`np_source_database` 一起进入 `compiler-module-self-compile-check`。

## Resources

- [runner.pas](/home/dtamade/projects/nextPas/tests/harness/runner.pas)
- [snapshot_support.pas](/home/dtamade/projects/nextPas/tests/harness/snapshot_support.pas)
- [run_all_tests.sh](/home/dtamade/projects/nextPas/tests/run_all_tests.sh)
- [np_unit_resolver.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_unit_resolver.pas)
- [np_unit_graph.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_unit_graph.pas)
- [np_compilation_session.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_compilation_session.pas)
- [np_workspace_model.pas](/home/dtamade/projects/nextPas/compiler/frontend/np_workspace_model.pas)
- [np_diagnostics_sink.pas](/home/dtamade/projects/nextPas/compiler/diagnostics/np_diagnostics_sink.pas)
- [np_ast_facade.pas](/home/dtamade/projects/nextPas/compiler/syntax/np_ast_facade.pas)
- [verify_local.sh](/home/dtamade/projects/nextPas/build/verify_local.sh)
- [nextpas.pas](/home/dtamade/projects/nextPas/tools/stage0/nextpas.pas)
- [np_toolchain_plan.pas](/home/dtamade/projects/nextPas/compiler/toolchain/np_toolchain_plan.pas)
- [np_toolchain_runner.pas](/home/dtamade/projects/nextPas/compiler/toolchain/np_toolchain_runner.pas)
- [toolchain_contract_smoke.pas](/home/dtamade/projects/nextPas/tests/toolchain/toolchain_contract_smoke.pas)
- [tests/harness/README.md](/home/dtamade/projects/nextPas/tests/harness/README.md)
- [tests/README.md](/home/dtamade/projects/nextPas/tests/README.md)
- [test-harness-specification.md](/home/dtamade/projects/nextPas/docs/architecture/test-harness-specification.md)
- [unit-resolution-specification.md](/home/dtamade/projects/nextPas/docs/architecture/unit-resolution-specification.md)
- [stage0-driver-specification.md](/home/dtamade/projects/nextPas/docs/architecture/stage0-driver-specification.md)
- [compiler-specification.md](/home/dtamade/projects/nextPas/docs/architecture/compiler-specification.md)
- [diagnostics-specification.md](/home/dtamade/projects/nextPas/docs/architecture/diagnostics-specification.md)
- [toolchain-specification.md](/home/dtamade/projects/nextPas/docs/architecture/toolchain-specification.md)
- [stage0 README](/home/dtamade/projects/nextPas/tools/stage0/README.md)
- [verify_local.sh](/home/dtamade/projects/nextPas/build/verify_local.sh)
- [pre-session-build-context-projection-plan.md](/home/dtamade/projects/nextPas/docs/plans/2026-03-26-pre-session-build-context-projection-plan.md)
- [workspace-model-shared-truth-plan.md](/home/dtamade/projects/nextPas/docs/plans/2026-04-05-workspace-model-shared-truth-plan.md)

## Visual/Browser Findings

- 本轮未使用图片或浏览器结果
