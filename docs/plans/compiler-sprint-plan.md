# 编译器 Sprint 计划
> 2026-07-05
> 给接手编译器的开发者（人和 AI）用的执行手册
> 每个 Sprint 结束更新状态
---
## 当前状态
compiler-pass 34/34 | self-compile 19/19 | core 963/972 (99.1%)
---
## 核心问题
编译器 49,667 行。标准库有 THashMap、TVec、TFastArena。编译器全部自己重新实现了一遍。
编译器只引用了标准库 5 个模块：text, text.conv, path, os.env, time, base.utils。剩下 970 个模块没用。
---
## 三个 Sprint
### Sprint 1：接入标准库（5 天）
**不改架构，只换实现。每步独立可回滚。**
#### 任务 1.1 — SemanticModel 用 THashMap（第 1 天）
文件：`compiler/sema/np_semantic_model.pas`
改 6 个函数，全部是 O(n) 线性查找改 O(1) 哈希查找：
```
第 1076 行  FindTypeByName      → for I:=0 to Length(FTypes)-1 do SameText(...)
第 1086 行  FindSymbolByName     → for I:=0 to Length(FSymbols)-1 do SameText(...)
第 1272 行  LookupConstValue     → for I:=0 to Length(FConstValues)-1 do SameText(...)
第 1396 行  GetTypeMetaByName    → for I:=0 to Length(FTypeMeta)-1 do SameText(...)
第 1410 行  GetFieldMetaByName   → for I..for J.. do SameText(...)   [双重循环]
第 1429 行  GetVmtSlotByName     → for I..for J.. do SameText(...)   [双重循环]
```
做法：加 `uses nextpas.core.collections.hashmap`，加几个 `THashMap<string, LongInt>` 字段，查找改成 `TryGetValue`。
验证：`make test TEST_FILTER=compiler-pass` 必须 34/34。
---
#### 任务 1.2 — 动态数组改 TVec（第 2 天）
文件：`compiler/sema/np_semantic_analyzer.pas`、`compiler/ir/np_hir_builder.pas`
全编译器 145 处 `SetLength(arr, Length(arr)+1)` 逐元素扩容。每次触发 ReAllocMem + 全量复制。
优先改增长最频繁的：
- `FProcedureBodies`（每过程一次）
- `Meta.Fields`（每字段一次）
- `Meta.VmtSlots`（每虚方法一次）
做法：`array of T` → `TVec<T>`，`SetLength+1` + 赋值 → `Add()`。
验证：`make test TEST_FILTER=compiler-pass` + `scripts/rebuild-compiler.sh`。
---
#### 任务 1.3 — Green Tree 用 Arena（第 3-4 天）
文件：`compiler/syntax/np_green_tree.pas`
当前 `TGreenNode = class`，每个 token 一次堆分配。5000 token 的源文件 = 5000 次 `Create`。
做法：`TGreenTree` 持有一个 `IArena`，所有子节点在 Arena 里分配，编译结束一次性释放。
如果太复杂就跳过。1.1 + 1.2 已经够了。
---
#### 任务 1.4 — 测量（第 5 天）
改前改后各跑一次：
```bash
time scripts/rebuild-compiler.sh
heaptrc ./build/stage2-test/nextpas build <large_module>
```
---
### Sprint 2：拆分 God Class（10 天）
`np_semantic_analyzer.pas`：12,255 行，279 方法，1 个 class。
**只移代码，不改行为。** 每步跑 compiler-pass 验证。
按从易到难拆：
| 步 | 拆出 | 行数 | 天数 | 风险 |
|----|------|------|------|------|
| 2.1 | 内置函数注册表 → `np_sema_builtins.pas` | ~500 | 0.5 | 极低 |
| 2.2 | 字符串所有权 → `np_sema_string_ownership.pas` | ~2000 | 1 | 低 |
| 2.3 | 重载解析 → `np_sema_overload.pas` | ~1500 | 2 | 中 |
| 2.4 | AST→HIR 降级 → `np_sema_hir_lowering.pas` | ~3000 | 3 | 中 |
| 2.5 | 类型检查 → `np_sema_type_check.pas` | ~1500 | 2 | 高 |
| 2.6 | 清理剩余 | ~3700 | 1.5 | 中 |
**2.1 的具体做法**：
把 150+ 个 `NameSetAdd(FBuiltinProcedures, 'Write')` 调用移到一个独立 unit：
```pascal
unit np_sema_builtins;
function CreateBuiltinRegistry: TNameSet;
begin
  Result := TNameSet.Create;
  NameSetAdd(Result, 'Write');
  NameSetAdd(Result, 'WriteLn');
  // ... 全部 150+ 个
end;
```
`sema` 里改成 `FBuiltinProcedures := CreateBuiltinRegistry;`
**2.3 的具体做法**：
`LookupCallBindingDeclaration` 是目前最复杂的单个方法。把它和相关的 `GetParamSignature`、`HasOverload` 等抽出来做成独立的 `TOverloadResolver`。抽出来后可以单独写单元测试。
---
### Sprint 3：能力补全（15 天）
#### 3.1 — 清理 permissive overload（3 天）
14 处 `{ Permissive: ... }` 妥协，全部在 `LookupCallBindingDeclaration` 里：
```
第 1495 行   { Permissive: pick first exact match instead of failing }
第 1502 行   { Permissive: pick first compatible match instead of failing }
第 1531 行   { Permissive: pick first signature match instead of failing }
第 1594 行   { Permissive: pick first direct import exact match }
第 1613 行   { Permissive: pick first direct import compatible match }
第 1704 行   { Permissive: pick first imported exact match }
第 1711 行   { Permissive: pick first imported compatible match }
第 1724 行   { Permissive: pick first imported signature match }
第 3156 行   { Permissive: pick first exact match for method calls }
第 3169 行   { Permissive: pick first compatible match for method calls }
第 3235 行   { Permissive: pick first same-owner match }
第 3290 行   { Permissive: pick first best match for method calls }
第 3840 行   { Permissive: suppress ambiguous-overload errors for C8 pass }
第 3947 行   { Permissive: suppress ambiguous-overload errors for C8 pass }
```
改成标准重载解析：精确匹配 → 类型提升 → 多个歧义时报错（而不是随便选一个）。
---
#### 3.2 — 增量编译（5 天）
当前改 1 行代码 → 全量重编译。67 单元 6.4 秒。
做法：`TSemanticModel` 序列化到 `.npb` 文件。源文件 hash + 依赖 hash = 指纹。指纹匹配 → 跳过 lex/parse/sema，直接加载缓存。
目标：热编译 < 1 秒。
---
#### 3.3 — HIR 优化（5 天）
当前 HIR → LLVM IR 是 1:1 直译，0 个优化。
加 3 个基础 pass：常量折叠、死代码消除、强度削减。
---
#### 3.4 — sema 单元测试（2 天）
sema 12,255 行，目前 0 个直接单元测试。
Sprint 2 拆完后，每个独立模块至少 5 个测试。
---
## 每个 Sprint 结束检查清单
```bash
# 质量门禁
make test TEST_FILTER=compiler-pass     # 必须 34/34
make test TEST_FILTER=compiler-fail     # snapshot 匹配
scripts/rebuild-compiler.sh             # 必须成功
make hygiene                             # 无散落产物
# 性能
time scripts/rebuild-compiler.sh        # 记录，和 Sprint 开始对比
```
然后更新本文档对应 Sprint 的状态。
---
## 风险
| 风险 | 怎么办 |
|------|--------|
| 1.3 Arena 化太复杂 | 跳过，1.1+1.2 够了 |
| 2.x 拆分引入 bug | 每步跑 compiler-pass，git bisect |
| THashMap 在小数据集比数组慢 | 实测，N<20 保留数组 |
| 3.1 清理导致模块编译失败 | 先跑 C8 scan 统计影响面 |
---
## 相关文档
| 文档 | 什么时候看 |
|------|-----------|
| `compiler-architecture-critique.md` | 理解为什么要做这些 |
| `compiler-findings.md` | 需要更多细节时 |
| `debt-roadmap.md` | 看全部技术债 |
| `goal-tree.md` | 看项目整体进度 |
| `compiler/CLAUDE.md` | 看编译器工程规范 |
---
*最后更新：2026-07-05*
*下次更新：Sprint 1 结束后*
