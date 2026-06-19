# P1 Compiler Integration: 4-slot ABI → TString 24B Native

> **状态**: R2 修订版 — Codex R1 审查修正 (3 个严重遗漏 + Phase 顺序调整)
> **前置**: core/src/nextpas.core.text.tstring.pas (34 tests, 0 leaks)
> **路线图**: docs/plans/2026-06-18-system-kernel-roadmap.md Section 3, S7.3
> **质量标准**: 虐哭 FPC，拳打 Go，脚踢 Rust
> **Codex R1 修正**: sret ABI / try-except cleanup / interface methods / dynarray elements / Phase 顺序

---

## 1. 问题陈述

当前编译器使用 **4-slot sidecar ABI** 管理字符串内存：

```
string local var = 4 个独立 alloca:
  name$ptr        — payload 指针
  name$len        — payload 长度
  name$owner      — 分配器请求指针
  name$alloc_size — 原始分配大小

函数返回 = {ptr, i64} 或 {ptr, i64, ptr, i64} 聚合类型
```

目标是迁移到 **TString 24B record native**：

```
string local var = 1 个 alloca:
  name            — 24 字节 TString record (tag + SSO/Heap variant)

函数返回 = %TString (24 bytes)
```

**核心收益**:
- 大幅简化：4 alloca → 1 alloca，消除 ~30 个 string_owned_extract/intrinsic
- SSO 零堆分配（≤15B 内联），短字符串场景性能质变
- CoW refcount 由 runtime 管理，编译器只需 emit init/fini/assign/move 调用
- 为 future intern pool 和 string interning 奠定基础

---

## 2. 迁移策略：6 Phase 渐进式 (R2 修订)

**原则**: 每 Phase 独立可验证，不破坏已有测试。Phase 之间有明确 gate。

**Phase 顺序 (Codex R1 修正)**:
```
Phase 1: Runtime       (独立，不影响编译器)
Phase 2: HIR Types     (类型系统基础设施，先于 emitter/builder)
Phase 3: LLVM Emitter  (新旧 intrinsic 共存)
Phase 4: HIR Builder   (核心改动，拆分 4a→4b→4c→4d)
Phase 5: Sema          (简化 ownership 追踪)
Phase 6: Cleanup       (删除旧代码)
```

---

### Phase 1: LLVM Runtime — TString Native Functions

**目标**: 在 `rtl/runtime/src/` 创建基于 TString 24B record 的新 runtime 函数，与旧 4-slot 函数共存。

**新增文件**: `nextpas.runtime.tstring.ll`

**TString LLVM 类型定义** (24 字节，与 Pascal variant record 布局一致):
```llvm
; TString = 24 bytes variant record
; SSO 路径 (tag=0): [tag:1][len:1][buf:15][pad:7]
; Heap 路径 (tag=$FF): [tag:1][pad:7][header_ptr:8][heap_len:8]
; 两者共享同一 24B 内存，LLVM 用 [24 x i8] 表示原始字节
%TString = type [24 x i8]

; 函数参数用 ptr 传递 (所有 runtime 函数接收 ptr %s 指向 24B record)
; 函数返回用 sret (24B > 16B，x86_64 ABI 不用寄存器返回)
```

**Runtime 函数签名** (全部通过 ptr 操作 24B record):

```llvm
; === 生命周期 ===
declare void @np_tstring_init(ptr %s)                    ; StringInit: 零初始化 24B
declare void @np_tstring_fini(ptr %s)                    ; StringFini: SSO 无操作, Heap decr+free
declare void @np_tstring_assign(ptr %dst, ptr %src)      ; StringAssign: CoW bump refcount
declare void @np_tstring_move(ptr %dst, ptr %src)        ; StringMove: 转移, 源清零

; === 查询 ===
declare i64   @np_tstring_len(ptr %s)                    ; StringLen: tag-based SSO/Heap
declare ptr   @np_tstring_data(ptr %s)                   ; StringData: SSOBuf ptr 或 Heap payload ptr
declare i8    @np_tstring_is_sso(ptr %s)                 ; IsSSO: SSOTag == 0

; === 工厂 ===
declare void  @np_tstring_create(ptr %dst, ptr %data, i64 %len) ; 从 raw bytes 创建
declare void  @np_tstring_from_literal(ptr %dst, ptr %lit, i64 %len) ; 字面量→SSO 或 Heap
declare void  @np_tstring_concat(ptr %dst, ptr %a, ptr %b)  ; CoW concat
declare void  @np_tstring_copy(ptr %dst, ptr %src, i64 %start, i64 %count) ; Copy()
declare void  @np_tstring_from_int(ptr %dst, i64 %val)   ; IntToStr

; === 比较 ===
declare i64   @np_tstring_equal(ptr %a, ptr %b)          ; StringEqual
declare i64   @np_tstring_compare(ptr %a, ptr %b)        ; StringCompare

; === 字段操作 ===
declare void  @np_tstring_field_assign(ptr %dst, ptr %src)  ; 字段赋值: 先 fini old, 再 assign
declare void  @np_tstring_field_fini(ptr %s)                ; 字段清理: fini + clear

; === sret 函数返回辅助 ===
declare void  @np_tstring_ret_move(ptr %sret_dst, ptr %src) ; 移动到 sret 指针
declare void  @np_tstring_ret_copy(ptr %sret_dst, ptr %src) ; 拷贝到 sret 指针 (CoW bump)
```

**实现**: 每个函数内部调用 `nextpas.core.text.tstring.pas` 中已验证的逻辑，以 LLVM IR 实现（与现有 runtime 风格一致）。

**关键区别**:
- 所有操作接收 `ptr` 指向 24B record，而非 4 个独立指针
- `np_tstring_assign` 内部实现 CoW: 先 incr src, 再 decr dst
- `np_tstring_fini` 内部判断 SSO/Heap，SSO 直接清零，Heap decr+free

**验证**:
- 独立 LLVM IR 测试：手动构建 24B record，调用每个函数，验证行为
- 与 core/test_tstring 的 34 个测试等价验证

---

### Phase 2: HIR Types — 类型系统基础设施 (Codex R1: 提前至 Emitter 之前)

**文件**: `compiler/ir/np_hir_types.pas`

**改动**:

1. **更新 string 类型尺寸** (行 420):
```pascal
// 旧: FTypes[Idx].SizeBytes := 16;  // ptr + len = 16B
// 新: FTypes[Idx].SizeBytes := 24;  // TString 24B record
```

2. **更新 `TAllocaEntry`** (np_hir_builder.pas:29):
- `RecordSlots` 字段目前跟踪 4-slot 布局，迁移后 string 不再使用多 slot
- 需要新增 `IsTString: Boolean` 标志或修改 slot 语义

3. **新增 HIR 节点类型** (与旧类型共存):
- `hnkVarDeclTStringRuntime` — 统一的 TString 变量声明 (1 个 24B alloca)
- `hnkAssignTStringLiteral` — 字面量赋值
- `hnkAssignTStringCopy` — Copy() 赋值
- `hnkAssignTStringCall` — 函数返回赋值 (sret)
- `hnkAssignTStringConcat` — concat 赋值
- `hnkAssignTStringFieldLoad` — 字段加载
- `hnkTStringCleanup` — scope exit 清理
- `hnkFieldStoreTString` — 字段存储
- `hnkRetTString` — 函数返回 (sret)

4. **新增 `THIRFunction.IsTStringReturnAbi: Boolean`** 替代 `UsesOwnedStringReturnAbi`

5. **更新 `ParseHirNodeKind` 字符串映射**

**Gate**: 新旧节点类型共存，旧测试不受影响。

---

### Phase 3: LLVM Emitter — TString ABI 基础设施

**目标**: 在 emitter 中添加 TString intrinsic 处理，新旧共存。

**文件**: `compiler/ir/np_hir_llvm_emitter.pas`

**改动**:

1. **添加 `%TString` 类型声明**:
```llvm
; [24 x i8] — 与 Pascal variant record 布局一致
; 通过 GEP + bitcast 访问各字段，不展开 variant
```

2. **新增 intrinsic 处理** (与旧 intrinsic 共存):
- `tstring_init` → `call void @np_tstring_init(ptr ...)`
- `tstring_fini` → `call void @np_tstring_fini(ptr ...)`
- `tstring_assign` → `call void @np_tstring_assign(ptr %dst, ptr %src)`
- `tstring_move` → `call void @np_tstring_move(ptr %dst, ptr %src)`
- `tstring_from_literal` → SSO inline 或 heap alloc
- `tstring_len` → `call i64 @np_tstring_len(ptr ...)`
- `tstring_data` → `call ptr @np_tstring_data(ptr ...)`
- `tstring_concat` → `call void @np_tstring_concat(ptr %dst, ptr %a, ptr %b)`
- `tstring_field_assign` → `call void @np_tstring_field_assign(ptr %dst, ptr %src)`
- `tstring_field_fini` → `call void @np_tstring_field_fini(ptr %s)`

3. **sret 返回处理** (Codex R1 关键修正):
```pascal
// 24B > 16B, x86_64 ABI 不用寄存器返回
// 使用 sret: 函数签名变为 void @func(ptr sret(%TString) %agg.result, ...)
if AFunc.IsTStringReturnAbi then
  RetStr := 'void'
  // 并在 ParamStr 前插入 'ptr sret(%TString) %agg.result'
```

4. **声明新 runtime 函数**: 新增 `EmitTStringHelpers` (与旧 `EmitStringOwnershipHelpers` 共存)

**Gate**: 新旧 intrinsic 共存，旧测试仍通过。

---

### Phase 4: HIR Builder — 核心改动 (拆分为 4a→4b→4c→4d)

**目标**: 逐步将 string 变量从 4 个 alloca 改为 1 个 24B alloca。

**文件**: `compiler/ir/np_hir_builder.pas`

#### Phase 4a: 变量声明 + 基础操作

1. **新增 `EnsureAllocaTString(Name)`**:
```pascal
procedure EnsureAllocaTString(const AName: string);
begin
  // alloca [24 x i8], align 8
  EmitAlloca(AName, '[24 x i8]', 8);
  // 调用 np_tstring_init 零初始化
  EmitIntrinsic('tstring_init', [AName]);
end;
```

2. **新增基础 helper**:
- `EmitTStringAssign(Dst, Src)` — tstring_assign intrinsic
- `EmitTStringFini(Name)` — tstring_fini intrinsic
- `EmitTStringMove(Dst, Src)` — tstring_move intrinsic

3. **处理 `hnkVarDeclTStringRuntime`** (新的统一声明节点)

**Gate**: 新声明节点工作，旧声明节点不受影响。

#### Phase 4b: 赋值操作

4. **重写 ProcessAssign 系列** (10 个函数):

| 旧函数 | 新逻辑 |
|--------|--------|
| ProcessAssignStr | `tstring_from_literal(dst, lit, len)` |
| ProcessAssignStrLiteral | 同上 |
| ProcessAssignStrCopy | `tstring_copy(dst, src, start, count)` |
| ProcessAssignStrCall | **sret**: 调用时传入 dst ptr 作为 sret 参数，函数内部直接写入 |
| ProcessAssignStrOwnedCall | 同上 (不再需要 4-slot extract) |
| ProcessAssignStrConcat | `tstring_concat(dst, a, b)` |
| ProcessAssignStrOwnedConcat | 同上 (不再区分 owned/borrowed concat) |
| ProcessAssignStrVcall | **sret**: 同 Call |
| ProcessAssignStrIvcall | 同上 (interface 方法也走 sret) |
| ProcessAssignStrMoveToResult | `tstring_move(result, src)` |

5. **重写 ProcessRetStr** (2 个 → 1 个):
```pascal
// 旧: 2 种返回 (2-slot {ptr,i64} / 4-slot {ptr,i64,ptr,i64})
// 新: sret — 直接写入 sret_ptr 指向的 24B record
procedure ProcessRetTString(ANode: TTypedHirNode);
begin
  EmitTStringMove('sret_ptr', ANode.Operand);  // 移动到 sret 指针
  // ret void (sret 函数返回 void)
end;
```

6. **重写 ProcessStringTemp** (4 个 → 2 个):
- `ProcessTStringTemp` — 创建 24B temp alloca + init
- `ProcessTStringTempRelease` — emit tstring_fini + 清零

7. **重写 ProcessStringCleanup**:
```pascal
// 旧: ReleaseStringOwner + ClearStringOwner (4 slots)
// 新: EmitTStringFini (1 个 24B record)
```

**Gate**: compiler-pass 11 fixtures + 新 TString 赋值测试全绿。

#### Phase 4c: 字段操作 + 对象清理

8. **重写字段操作** (3 个函数):
- `ProcessFieldStoreStr` → GEP to field, `tstring_field_assign`
- `ProcessFieldStoreStrOwned` → 同上 (不再区分 owned)
- `ProcessAssignStrFieldLoad` → GEP to field, `tstring_assign` to local

9. **重写 EnsureObjectStringCleanupHelper**:
```pascal
// 旧: 遍历 string 字段, 每个字段 4 个 GEP slot (Index, Index+1, Index+2, Index+3) + string_release
// 新: 遍历 string 字段, 每个字段 1 个 GEP + tstring_field_fini
```

10. **重写 Blob 字符串操作** (行 2678-2737):
- `BlobStrVar` → 从 TString alloca 调用 `tstring_data` / `tstring_len`
- `BlobStrLen` → `tstring_len` intrinsic
- `BlobStrCmpPos` → 通过 data/len 指针比较

**Gate**: class string 字段测试 + record string 字段测试全绿。

#### Phase 4d: 边界场景 (Codex R1 关键补充)

11. **try/except cleanup** (⚠️ Codex R1 严重遗漏):
```pascal
// 当 string 变量在 try 块中声明时:
// hnkStringCleanupRuntime 在 except/finally 出口仍需生成
// 迁移后: tstring_fini 替代 ReleaseStringOwner + ClearStringOwner
// 测试: 异常抛出后 string 变量必须被正确 cleanup
```

12. **interface 方法的 string 参数/返回** (⚠️ Codex R1 严重遗漏):
```pascal
// 当前: ProcessAssignStrIvcall 使用 vcall_str intrinsic, 传 4 参数
// 迁移后: IMT 函数签名更新为 sret %TString
// interface 方法返回 string = void @method(ptr sret(%TString), ptr %self, ...)
```

13. **动态数组中的 string 元素** (⚠️ Codex R1 严重遗漏):
```pascal
// array of string 的每个元素从 16B 变为 24B
// dynarray_resize 的 ElemSize 参数更新
// 数组释放时需要对每个元素调用 tstring_fini
// SetLength 初始化新元素为零 (tstring_init)
```

14. **record 中的 string 字段** (⚠️ Codex R1 遗漏):
```pascal
// P5 RAII 已处理 record 字段 cleanup (hnkManagedRecordCleanupRuntime)
// 迁移后: record string 字段从 4-slot 变为 24B
// ProcessRecordFields 的 IsString 标志保持, 但 GEP 和 cleanup 改为 tstring_field_fini
// record 作为参数/返回时, 24B string 字段随 record 整体传递
```

15. **var 参数的 string 传递**:
```pascal
// var S: string 参数 — 传入的是指向 24B record 的指针
// 函数内部直接操作该指针, 赋值用 tstring_assign, 不需要 copy
```

**Gate**: 异常清理测试 + interface 测试 + dynarray 测试 + record 字段测试全绿。

---

### Phase 5: Sema — 简化 String 管理

**目标**: 简化 sema 中的 string ownership 追踪。

**文件**: `compiler/sema/np_semantic_analyzer.pas`

**改动**:

1. **简化变量声明** (行 14421-14523):
```pascal
// 旧: 3 种声明 (owned/borrowed/普通), 区分 ptr/len/owner/alloc_size
// 新: 统一为一种 'var-decl-tstring-runtime' (Phase 2 已定义节点)
FModel.AddTypedHirNode(
  'var-decl-tstring-runtime', Decl.Text, 0, 0, Decl.Text
);
```

2. **简化 ownership 追踪**:
- 保留 `RegisterRuntimeStrVar` / `IsRuntimeStrVar` (变量追踪仍需要 for cleanup)
- 删除 `FOwnedRuntimeStrVarNames` / `FBorrowedRuntimeStrVarNames` 区分 (CoW 统一管理)
- 精简 `OwnedStringReturn` 系列 (~40 函数): 删除 4-slot 相关逻辑
- 保留 `FPendingStringTempNames` (temp cleanup 仍需要)

3. **简化 blob 标记**:
- 删除所有 `'ptr len owner alloc_size'` blob (13 处)
- 新 blob: 仅需变量名 (TString 自包含)

**注意**: 节点类型重命名不在 Phase 5 进行，统一在 Phase 6 cleanup 中处理。

**Gate**: HIR string tests (4571 行) 全绿。

---

### Phase 6: 清理 — 删除旧 4-slot 代码

**前提**: 所有测试通过，旧代码路径已无调用。

**删除内容**:

1. **HIR Builder 删除**:
- `InitializeStringSlots`, `InitializeStringOwnerSlots`
- `ClearStringOwner`, `ReleaseStringOwner`, `StoreOwnedStringResult`
- 所有 `string_owned_extract_*` intrinsic 使用
- `$owner` / `$alloc_size` alloca 相关代码
- 旧 `ProcessAssign*Str*` 函数 (已被新版本替换)

2. **HIR Types 删除**:
- 旧 HIR 节点类型: `hnkVarDeclStrRuntime`, `hnkVarDeclStrOwnedRuntime`, `hnkVarDeclStrBorrowedRuntime`
- 旧赋值节点: `hnkAssignStr*`, `hnkFieldStoreStr*`
- 旧 temp/cleanup 节点: `hnkStringTemp*`, `hnkStringCleanup*`
- `THIRFunction.UsesOwnedStringReturnAbi` 字段和方法

3. **LLVM Emitter 删除**:
- `{ptr, i64}` / `{ptr, i64, ptr, i64}` 聚合类型处理
- `string_release`, `string_owner_clear` intrinsic 处理
- `EmitStringOwnershipHelpers` (替换为 `EmitTStringHelpers`)
- 旧 `ret_str`, `ret_str_owned`, `call_str_func`, `call_str_owned_func`

4. **Sema 删除**:
- `FOwnedRuntimeStrVarNames` / `FBorrowedRuntimeStrVarNames` 数组
- `RegisterOwnedRuntimeStrVar` / `IsOwnedRuntimeStrVar` / `RegisterBorrowedRuntimeStrVar` / `IsBorrowedRuntimeStrVar`
- `RegisterOwnedStringReturnFunc` / `IsOwnedStringReturnFunc`
- 所有 `'ptr len owner alloc_size'` blob 生成
- `OwnedStringReturn` 系列中的 4-slot 相关逻辑

5. **Runtime 删除**:
- `nextpas.runtime.strings.ll` 中的旧 4-slot 函数 (`np_string_release`, `np_str_concat_owned`, `np_str_copy_owned`, `np_int_to_str_owned`)
- 保留 `np_str_cmp`, `np_str_pos` (底层比较/搜索，TString runtime 也用)

6. **HIR Model 删除**:
- `UsesOwnedStringReturnAbi` 字段和方法

**Gate**: full regression + heaptrc 0 leaks。

---

## 3. 函数返回 ABI — sret 统一 (Codex R1 修正)

### 旧方案 (两种返回类型):

```llvm
; 普通 string 返回 (16B, 寄存器传递)
define {ptr, i64} @func() { ... }

; owned string 返回 (32B, 可能需要 sret)
define {ptr, i64, ptr, i64} @func_owned() { ... }
```

### 新方案 (统一 sret):

```llvm
; 所有 string 返回统一为 sret (24B > 16B, 必须用 sret)
define void @func(ptr sret(%TString) %agg.result) {
  ; 直接写入 %agg.result 指向的 24B record
  ; ...
  ret void
}

; 调用端:
%result = alloca %TString, align 8
call void @func(ptr sret(%TString) %result)
; %result 现在包含返回的 TString
```

**sret 优势** (vs by-value):
- 符合 x86_64 ABI (>16B 聚合类型用隐藏 sret 指针)
- 避免 LLVM 优化器隐式 memcpy
- 与现有 sret 机制兼容 (np_hir_llvm_emitter.pas:1185 IsSretFunction)
- 调用端零拷贝: 函数直接写入目标 alloca

**实现细节**:
- Emitter: `IsTStringReturnAbi` → 函数签名加 `ptr sret(%TString) %agg.result` 为首参数
- Emitter: 函数体 `ret void` (sret 函数返回 void)
- Builder: 调用前创建 temp alloca, 传入作为 sret 参数
- Builder: 调用后无需 extract — 数据已在 alloca 中

---

## 4. 字段 ABI 统一

### 旧方案 (class string field = 4 个 object slot):

```
object layout:
  [vtable] [field0:4slot(ptr,len,owner,alloc)] [field1:4slot] ...
每个 string 字段占 4 × 8 = 32 字节
```

### 新方案 (class string field = 1 个 24B TString slot):

```
object layout:
  [vtable] [field0:TString(24B)] [field1:TString(24B)] ...
每个 string 字段占 24 字节
```

**简化**:
- 字段 GEP 从 `Index, Index+1, Index+2, Index+3` 变为单个 GEP
- 字段清理从 4 步 (release + clear x4) 变为 1 步 (tstring_field_fini)
- 字段赋值从 4 步 (release + store x4) 变为 1 步 (tstring_field_assign)

**注意**: 字段操作需要特殊处理 — 字段不是独立 alloca，而是对象内存中的一个 region。
- `tstring_field_assign` 内部: 先 fini old, 再 assign new (原子安全)
- `tstring_field_fini` 内部: fini + memset zero

---

## 5. 测试策略 (R2 修订 — Codex R1 补充)

### 5.1 回归测试 (必须全绿)

| 测试套件 | 文件数 | 说明 |
|----------|--------|------|
| compiler-pass | 11 fixtures | 所有现有 pass 测试 |
| HIR string tests | 8 files | 4571 行 contract + runtime smoke (**需更新预期值**) |
| smoke examples | 7 files | string concat/func/length 等 |

### 5.2 新增测试

| 测试 | Phase | 优先级 | 说明 |
|------|-------|--------|------|
| `test_tstring_runtime.ll` | Phase 1 | P0 | 新 runtime 函数独立测试 |
| `tstring_basic_pass.pas` | Phase 4b | P0 | TString native 基本操作 (赋值/比较/长度) |
| `tstring_sso_pass.pas` | Phase 4b | P0 | SSO 路径 (≤15B 内联, 15/16B 边界) |
| `tstring_cow_pass.pas` | Phase 4b | P0 | CoW 赋值, 自赋值, 多引用 |
| `tstring_concat_pass.pas` | Phase 4b | P0 | Concat 操作, SSO concat |
| `tstring_func_pass.pas` | Phase 4b | P0 | 函数传参和 sret 返回 |
| `tstring_cleanup_pass.pas` | Phase 4d | **Critical** | RAII 自动清理 + try/except cleanup |
| `tstring_field_pass.pas` | Phase 4c | P0 | Class string 字段操作 |
| `tstring_interface_pass.pas` | Phase 4d | **High** | interface 方法的 string 传参/返回 |
| `tstring_dynarray_pass.pas` | Phase 4d | **High** | `array of string` 元素操作/释放 |
| `tstring_record_field_pass.pas` | Phase 4c | Medium | record 中的 string 字段 (P5 RAII 交互) |
| `tstring_var_param_pass.pas` | Phase 4d | Medium | var 参数的 string 传递 |

### 5.3 测试迁移工作量 (Codex R1 提醒)

HIR string tests (4571 行) 直接检查 HIR 节点结构 (owned/borrowed 区分、4-slot 布局)。
迁移后这些测试的预期值需要大规模更新。计划在 Phase 4b 完成后统一更新。

### 5.4 性能验证 (Phase 1 即开始)

| 指标 | 旧方案 | 目标 | 测量方式 |
|------|--------|------|----------|
| 16B string 分配 | 堆分配 (4 slots) | SSO 零分配 | bench_tstring |
| string 赋值 | ptr copy + owner mgmt | CoW refcount bump | bench_tstring |
| string concat | 4-slot extract + store | 1 个 tstring_concat 调用 | bench_concat |
| string cleanup | 4-slot release + clear x4 | 1 个 tstring_fini 调用 | bench_cleanup |
| 函数返回 string | {ptr,i64} 寄存器 | sret 24B | bench_return |

---

## 6. 迁移顺序和门控 (R2 修订)

```
Phase 1 (Runtime)      ← 独立，不影响编译器
    ↓ gate: runtime 函数独立测试通过 + 性能基准建立
Phase 2 (HIR Types)    ← 类型系统基础设施
    ↓ gate: 新旧节点类型共存，旧测试不受影响
Phase 3 (Emitter)      ← 新旧 intrinsic 共存
    ↓ gate: 旧测试仍通过 + 新 intrinsic 基本 emit 正确
Phase 4a (Builder: 声明)  ← 变量声明 + 基础操作
    ↓ gate: 新声明节点工作
Phase 4b (Builder: 赋值)  ← 10 个 ProcessAssign 函数重写
    ↓ gate: compiler-pass + tstring_basic/sso/cow/concat/func 全绿
Phase 4c (Builder: 字段)  ← 字段操作 + 对象清理
    ↓ gate: class/record string 字段测试全绿
Phase 4d (Builder: 边界)  ← try/except + interface + dynarray + var param
    ↓ gate: cleanup/interface/dynarray/var_param 测试全绿
Phase 5 (Sema)         ← 简化 ownership 追踪
    ↓ gate: HIR string tests 更新后全绿
Phase 6 (Cleanup)      ← 删除旧代码
    ↓ gate: full regression + heaptrc 0 leaks
```

---

## 7. 风险和缓解 (R2 修订)

| 风险 | 影响 | 缓解 |
|------|------|------|
| sret ABI 与现有 sret 机制兼容性 | 函数调用端需要创建 temp alloca | 复用 `IsSretFunction` 检测，Phase 3 验证 |
| Phase 4 单次改动量过大 | 500+ 行改动，中间状态难调试 | **拆分 4a→4b→4c→4d**，每步独立验证 |
| try/except cleanup 遗漏 | 异常时 string 内存泄漏 | Phase 4d 专项测试，覆盖 raise 在 string 赋值后的场景 |
| interface 方法 string 返回 | IMT 函数签名需要同步更新 | Phase 4d 专项测试 |
| dynarray string 元素释放 | 数组释放时元素未 cleanup | Phase 4d 专项测试，覆盖 SetLength + 释放 |
| HIR string tests 大量修改 | 4571 行测试需要更新预期值 | Phase 5 统一更新，保持 Phase 4 测试独立 |
| 新旧 runtime 共存期 | 两套 runtime 函数的链接冲突 | Phase 1 独立文件，命名不冲突 |
| SSO 边界条件 | 15/16 字节边界 | 核心层已有 34 测试覆盖 + 新增边界测试 |
| CoW 并发安全性 | 多线程赋值 | InterlockedIncrement/Decrement 已在 core 层验证 |
| 24B record 作为函数参数传递 | x86_64 可能引入 memcpy | 参数始终用 ptr (by-ref)，不用 by-value |

---

## 8. 预估工作量 (R2 修订)

| Phase | 文件 | 预估行数 | 难度 | 预估时间 |
|-------|------|----------|------|----------|
| Phase 1: Runtime | 1 new | ~300 行 LLVM IR | 中 | 1 轮 |
| Phase 2: HIR Types | 1 file | ~80 行改动 | 低 | 0.5 轮 |
| Phase 3: Emitter | 1 file | ~200 行改动 | 中 | 1 轮 |
| Phase 4a: Builder 声明 | 1 file | ~100 行改动 | 中 | 0.5 轮 |
| Phase 4b: Builder 赋值 | 1 file | ~300 行改动 | **高** | 1.5 轮 |
| Phase 4c: Builder 字段 | 1 file | ~150 行改动 | 中 | 1 轮 |
| Phase 4d: Builder 边界 | 1 file | ~200 行改动 | **高** | 1.5 轮 |
| Phase 5: Sema | 1 file | ~250 行改动 | 中 | 1 轮 |
| Phase 6: Cleanup | 4 files | ~-1000 行删除 | 低 | 0.5 轮 |
| 测试 (新增) | 12 files | ~1500 行新增 | 中 | 分散在各 Phase |
| 测试 (迁移) | 8 files | ~500 行更新 | 中 | Phase 5 统一 |
| **合计** | | ~1630 行改动 + 1500 行新增 - 1000 行删除 | | ~9 轮 |

---

## 9. 与 core 层的关系

编译器集成不修改 `core/src/nextpas.core.text.tstring.pas`。编译器生成的 LLVM IR 调用 runtime 函数，runtime 函数内部实现与 core 层逻辑等价（但以 LLVM IR 而非 Pascal 表达）。

长期: 当 nextPas 自举后，runtime 函数可以直接调用 core 层的 Pascal 实现，不再需要 LLVM IR 重复实现。
