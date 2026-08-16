# M2-L3 作战路线图 — 唯一执行入口

> **这是 AI 会话的唯一入口文件。** 打开本文件 → 跑探针 → 按咬合队列干一口 → 提交。
> 不需要读其他任何路线图就能开工。战略背景（M0–M9）见
> `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`，但执行只看本文件。
>
> 最后校准：2026-07-26（fresh 探针实测，非转抄）

## 唯一目标（当前唯一目标，做完才有下一个）

**L3 闭合 = `tools/stage0/nextpas.pas` 经 A 的 LLVM 路径 link 出可执行 gen-B。**

链条：`nextpas.ll` → `opt -O2` ✅ → `llc` ✅ → `ld + libnprt.a` ✅ → B 可执行。
当前断点在 `opt`，且性质已收敛为**纯 undefined symbols**（B1–B4 在清）：
B6.5 类型一致性与 VMT 引号已清（2026-07-26，opt 能完整解析全 .ll，首错是
`use of undefined value`），B7 的 toolchain planning 前置阻塞也已全清
（planning ready，link argv 完整），opt PASS 后 llc/link 无已知拦路虎。

## 唯一度量（每次会话开始和结束各跑一次）

```bash
./scripts/m2-l3-residual.sh                 # 全链：rebuild + L3 build + 分桶分析
./scripts/m2-l3-residual.sh --analyze-only  # 秒级：只分析现有 nextpas.ll
```

输出 `undefined uniq/total` + 分桶 + opt 首错 + 历史趋势
（history: `.nextpas/m2-residual-history.tsv`）。**这个数字只许降不许升。**

## 当前战况（2026-08-17 B6-EXTDECL 后实测）

| 指标 | 值 | 轨迹 |
|------|-----|------|
| undefined unique | **34** | 305 → 80 (B0) → 79 (B1) → 84 (B3a+对方B2) → 79 (B4) → 78 (B3b) → 64 (B3c) → 60 (B4a) → 54 (B6-atomic) → 54 (B5a-strpos) → 54 (B5b-toml) → 53 (B5c-upcase) → 52 (B5d-ecore) → 60 (B5e 口径扩展¹) → 57 (B5f-intfid) → **42 (2026-08-16 基线) → 38 (B6-EXTDECL 口1: implementation 区 external 声明注册 binding) → 34 (B6-EXTDECL 口2: emitter 大小写敏感去重 + SeedImportedCallableSymbol CleanName)** |
| undefined total | **52** | 1338 → 251 (B0) → 173 (B1) → 166 (B3a+对方B2) → 161 (B4) → 120 (B3b) → 103 (B3c) → 92 (B4a) → 80 (B6-atomic；atomic 桶整桶清零) → 75 (B5a-strpos；Pos 7→2) → 74 (B5b-toml；Pos 2→1) → 72 (B5c-upcase；UpCase 2→0) → 69 (B5d-ecore；ECore.Create 3→0) → 79 (B5e 口径扩展¹) → 75 (B5f-intfid；接口ID 3 符号→0) → **64 (2026-08-16 基线) → 61 (B6-EXTDECL 口1) → 52 (B6-EXTDECL 口2)** |

¹ B5e 探针口径扩展（2026-07-26）：旧口径只统计 `call|invoke` 引用，漏掉
vmt/imt 表项与 store 操作数（`ptr @X`）——imt 4 缺口 opt 报错但探针不计
（「探针清零 ≠ opt 通过」盲区）。新口径 = call + ptr-ref 引用，resolved 加
global 定义（`^@X =`）。同一 .ll 对照：旧 52/69 = 新 60/79（浮出 8 uniq：
TStream vmt ×6 + TVec 泛型 ×2，全属 method-object 既有家族）。之后以新
口径为准，数字只降不升纪律从 60/79 起算。
| opt 首错 | `use of undefined value '@GetCurrentThreadId'`——**runtime-decl 桶**（core 调 FPC System 内建 `GetCurrentThreadId`，stub System 无声明） | B6-EXTDECL 后 |
| toolchain planning | **ready**（5 库 link argv 完整），失败点=llvm-opt-exec-failed | B7 后 |

⚠️ B3a 那一格数字是**两个会话改动的混合体**，别用它给单个提交归因。B3a 自己
清零了 23 处 total（`TMirPassManager.FAllocator` 10、`TGreenTree.RootNode` 9、
`TGreenTree.FRootNode` 4）；同期对方 B2 让 `IHasher.Write` 不再 undefined，
但新引入 `TInterfacedObject.Destroy`(7)、`ECore.Create`(3) 等，故 unique 一度反升。
B4 之后回到 79 uniq，且比 B1 时的 79 少了 12 处 total。

**opt 首错换了性质**：从「undefined symbol」变成「类型不匹配」
（`np_string_release` 调用点传 i32、声明要 i64）。这说明 undefined 清到一定
程度后，下一层门槛是 **call-site 类型一致性**，需要新增一类修复工作，
不在原 B0–B8 队列里——建议作为 **B6.5 类型一致性**插在 opt PASS 之前。

分桶（B3a 后实测，按 total 降序）：

| Bucket | uniq | total | 代表符号 | 根因猜想 | 主战文件 |
|--------|------|-------|----------|----------|----------|
| method-object | 42 | 99 | `TGreenNode.Text`(41), `TInterfacedObject.Destroy`(7), `TToolchainPlan.Free`(3) | property string getter（B3b）/ `.Free` 未走 object-free（B3c）/ 对方 B2 新引入的构造析构 | `sema/np_sema_encode_runtime_expr.inc`, `np_sema_walk_halt_calls.inc` |
| project-helper | 20 | 31 | 见下方拆解——**不是单一根因** | 四类混装 | 见下方拆解 |
| const-upper | 7 | 12 | `PLATFORM_FS_SHORT_READ_ERROR`, `MaxInt` | const 未 fold | `sema/np_sema_evaluate_integer_constant.inc` |
| atomic | 6 | 12 | `InterlockedCompareExchange` | → LLVM `atomicrmw`/`cmpxchg`（F-003-1b） | `ir/np_hir_llvm_emitter_instr.inc` |
| runtime-decl | 8 | 11 | `np_*`, `platform_*` | 缺 declare 或 libnprt 未接线 | emitter declare 表 + `rtl/` |
| var-param | 1 | 1 | — | B1 已基本清零（self 64 + Result 15 灭） | — |
| 杂项 | ~4 | ~8 | `Pos`, `UpCase` | 缺 runtime helper/intrinsic | tstring/runtime family |

### project-helper 桶拆解（2026-07-26 实测，awk 分桶把四类塞进了一格）

探针的 `bucket()` 只按名字形状分类，所以「不带点、非全大写、无 `np_` 前缀」的全落进
project-helper。实际是四类不同根因，B4 要按类打而不是按桶打：

| 类 | 符号样例 | total | 真实根因 |
|----|----------|-------|----------|
| intrinsic 缺失 | `Pos`(7), `UpCase`(2), `Int`(2) | ~11 | 内置函数未降级为 runtime helper |
| **参数名/局部名 residual** | `aX86`, `aLeaf80000002`, `aElementCount`, `aDst`, `b`, `Result`(1) | ~9 | 与 B1 的 `self` 同病，但走的是别的 EmitExprVar 路径（B1 只修了 `self` 和 `Inc/Dec(Result)`） |
| 类型 cast 未识别 | `PSizeUInt`(2), `PSizeUIntArray`, `IPipeDrainReader`(2), `IWriteCloser` | ~6 | `PSizeUInt(x)` 这类类型转换被当函数调用；`EmitExprCall` 的 cast 分支只认 scalar fact，不认指针/接口类型名 |
| libc/FPC helper | `getcwd`(2), `system`, `SarLongint`, `PathSeparator` | ~5 | 缺 declare 或该走 platform 层 |

（`InterlockedCompareExchange` 族虽然也不带点，已被 awk 正确归入 atomic 桶。）

⚠️ **并行会话警告**：同 worktree 有另一 AI 会话（Cursor）正在做 B2（interface
parent IMT，`FixupInterfaceParentImt`，涉及 `np_sema_declaration.inc` 等 4 个
sema 文件的未提交改动）。开工前 `git status` 看到这些改动 = 对方还在干，
**跳过 B2 领 B3/B4**，避免撞车。另悉 B7 前方已知断点：toolchain planning 报
`toolchain.c-library-not-found`（缺 `lib/nextpas/runtime/linux-x86_64/libc.so` 映射）。

## 咬合队列（一口 = 一个会话内可完成 = 一次提交）

严格按序，每口结束必须：探针数字下降 → 追加 history → `git commit`。

- [x] **B0 落盘 WIP** ✅ c1ee243d7：51 文件 +4845/-693 落盘，基线 80/251 确认。
- [x] **B1 self/Result 桶** ✅ 16b58e28b：两根因修复（嵌套过程 `self` 零值 alloca
      兜底；`Inc/Dec(Result)` 补 FCurrentRetVarName 重映射）。251→173 total /
      80→79 uniq，var-param 桶 65→1。
- [x] **B2 接口 vcall（IHasher.Write）** ✅（本 commit，opt 首错 19700→50250 行）：
      真根因是**双层**——① `SeedCachedTypeGaps` 把接口类型误判为类
      （`IHasher.Sum` 等 method symbol 前缀命中 HasClassLikeMembers），空 Meta
      （VmtSlots=nil、ParentClassName='TObject'）整体覆盖 seed 期已建好的接口
      meta，连 `$vmt_count`/`$parent_class` consts 一起清零；② seed 倒序
      （consumer 先于 provider）令子接口处理时父接口类型未注册，父 IMT 继承
      分支被跳过（`@IHasher.Write` 是父接口 IWriter 的方法）。修法：
      ① `SeedCachedTypeGaps` 覆盖分支前跳过已有明细（VmtSlots 或 VmtCount>0）
      的类型；② 新增 `FixupInterfaceParentImt`（ivcall 编码前）：父 slots 在前、
      自身 slots 后移，consts/方法 symbol/ret 标记同步覆盖，布局与完整处理的
      ProcessInterfaceMethods 一致。验证：IHasher slots 变
      [Write(0), Sum(1)…Clone(6)]，`@IHasher.Write` 清零，opt 首错换人。
      挂账：seed 期 meta 恢复后 `@TStream.vmt` ×6 + `@TToolStatusEventVec.vmt`
      ×2 表项计入口径（method-object 既有家族，见战况注²），下一口按
      method-object 桶处理。
- [x] **B3a property → 背后字段** ✅ 92d7f8b9c（清零 23 处 total）：`property RootNode read FRootNode` 的
      声明 read 目标是**字段**而非 getter，三个产地（`np_sema_encode_runtime_expr.inc`
      的 class-DotAccess $read 命中处、ptr-field-receiver 兜底处、record-DotAccess
      Folded<0 处）都直接生成 `call @Type.FField` → undefined。修法：命中 `$read`
      后先 `TypeMetaFieldIndex` 判定，是字段就发 `field`/`rload`/`int+arr_load`。
      覆盖 `TMirPassManager.FAllocator`(10)、`TGreenTree.RootNode`(9)、
      `TGreenTree.FRootNode`(4)、`TToolStatusEventVec.Count`(4) 等 ~30 处。
- [x] **B3b property → string getter** ✅（清零 `TGreenNode.Text` 41 处，
      161→120 total / 79→78 uniq，method-object 桶 99→58）：真根因比预估深一层——
      **parser 把 record 体的 `property` 声明整段跳 token 不产节点**
      （`np_green_tree_clone_type.inc` record 分支的一锅端跳过集合含
      tkPropertyKeyword），语义层无从登记 `$read`。三层联动修复：
      ① parser record 分支新增 property 专项解析（产 gnkClassProperty +
      read:/write: 子节点，与 class 分支同构）；② ProcessRecordFields 新增
      gnkClassProperty 登记（`RecName.Prop$read`/`$write` + `$ret_str_`）；
      ③ `np_sema_walk_halt_calls.inc` 兜底分支先查 `$read`：字段目标发
      field-load，getter 目标发真实 getter 调用，record receiver 用 `recvar`
      保 ptr（原 `var` 会把 record local int 化）。**未动 emitter sret 启发式**：
      assign-tstring-call-runtime 静态调用路径 Operands[0] 天然是 dest ptr，
      「第一参 ptr→sret」在此路恰好正确，预估的启发式改造不需要。
      opt 首错保持 `np_string_release` i32/i64（B6.5），无新错误类型。
- [x] **B3c `.Free` 字段 receiver** ✅（120→103 total / 78→64 uniq，
      method-object 桶 58→41，`.Free` 家族全清）：字段 receiver（`FPlan.Free`）
      过不了 `LookupClassVar` → residual `@TX.Free`。修法**零 IR 消费端改动**：
      walk 的 `.Free` 分支补 else-if——`TypeMetaFieldIndex(FCurrentMethodClass,
      recv) >= 0` 时，字段类名经符号表扫描（Name+Kind='field'，照抄
      encode:1561 模式）解析，改写为「`var-decl-ptr-runtime` 声明
      `$objfree_tmp_N`（ptr 槽）→ `assign-runtime` 存入 `field self <idx> p`
      → 对 tmp 走既有 object-free-runtime + call-runtime Destroy 流程」。
      pending 匹配按 var 名耦合，nil-guard/heap-release/cleanup 契约链
      自动成立。**必须先发 var-decl-ptr**：让 assign-runtime 兜底建槽会是
      i64 型，Destroy 实参就成了 B6.5 类的 call-site 类型错。
      ROADMAP 原稿设想的 receiver blob 直挂 `field self <idx> p` 不需要。
- [~] **B4 project-helper 四类收尾**（按上方拆解表分类打，不要当一个桶打）：
      - [x] **`constref` 形参前缀从不剥离** ✅ 16b137263（清零 5 处）：
        `StripParamModifier` 补 `constref:` 剥离 + seed 三处改无条件剥离；
        `ParamNameIsByRef` 保持只认 `var:`/`out:`（职责分离，constref 的
        ptr ABI 本来就对，当普通 record 形参处理即可）。
      - [~] **形参名 residual（aDst/aElementCount）已定性、未修**：不是形参
        seed——是 `TElementManager.FreeElements` 的**方法体前缀漏进了
        `np_unit_init_..._element_manager`**（.ll 里 init 函数含
        `if aElementCount = 0 → exit; if aDst = nil → raise EArgumentNil`
        整段，41 字符字符串字面量坐实）。最小复现五轮成分注入
        （泛型类+类内 type PElement=^T+嵌套 begin/end+raise 带字符串+
        {$IFDEF} inline+方法序列仿真）都没复现——触发成分还差
        settings.inc modeswitch / specialize 接口父类 / impl-uses 之一，
        需 green-tree dump 深查。单独立口再打。
      - [x] **`inherited Destroy` 落错父类（TInterfacedObject.Destroy×7）** ✅
        （B4a，与 PSize 注册同口，103→92 total / 64→60 uniq）：stub
        `TInterfacedObject` 没声明 Destroy，`inherited Destroy` 沿祖先链
        只在 TObject 命中；但 walk 的最终选择逻辑把「TObject-only 命中」
        当兜底丢弃、改用**方法盲的直接父类猜测** OwnerClassName →
        residual `@TInterfacedObject.Destroy`。修法（walk_halt_calls.inc
        :2352）：**found-anywhere wins**——FuncName 非空一律用命中结果，
        OwnerClassName 只兜底「链上完全无符号」的情况。附带清掉 2 处
        同款 inherited 残差。已知风险已注释：若中间父类方法因泛型实例化
        缺口（B4b）缺符号，会静默落 TObject 跳过父类清理——B8 smoke 验行为。
      - [x] **类型 cast：PSizeUInt** ✅（本口 B4a）：根因不在 EmitExprCall——
        是 `PSizeUInt`/`PSizeInt` 这对 FPC System 内置指针别名**没在
        np_sema_builtins 注册**（PByte/PPtrInt 等都有）。补三段式注册
        （AddType+SetTypeParent+sskPointer fact）即走通既有 cast 分支。
        `PSizeUIntArray`(1) 是**过程内局部 type 段**声明（growing.pas:662），
        parser/seed 均不处理局部 type 段（同 B3b property 的整段跳），
        1 处残差不值单独口，挂账。
      - **IPipeDrainReader/IWriteCloser 重新定性**：.ll 里是**零参调用**
        `call i64 @IPipeDrainReader()`——不是 cast，是
        `Supports(x, IIntf, out)` 的类型标识符实参（pipe.pas:574）。
        归 B2 接口机器领域（GUID/IMT 查询），等对方 B2 落地后一起看。
      - intrinsic（`Pos`/`UpCase`/`Int`）与 libc（`getcwd`/`system`/`SarLongint`）
        分别归 B5、B6 一起处理更省重建。
- [ ] **B4b 跨单元泛型特化不实例化模板体**（/tmp 最小探针坐实，2026-07-26）：
      `specialize TEM<LongInt>`（TEM 在另一单元）→ ① 成员调用直接
      `sema.unknown-member`；② 只 Create/Free 时 0 个 `@TIntEM.*` define，
      `TIntEM.Create` **静默回落 `TObject.Create`**，`@TIntEM.Destroy`
      undefined。现有 generics 测试全是同单元特化，跨单元是空白。
      这是 `TToolStatusEventVec.Create/Count/Push`(8) 残差的病根，也是
      method-object 桶的最大剩余块。⚠️ 大口：涉及泛型模板导出/导入
      （green tree 跨 unit 取模板体）+ 实例化编码，可能要动 seeding
      （对方占用中）——排在对方 B2 提交后。
      更新（2026-08-18 尝试+回滚）：「模板名回绕」方案（helper
      ResolveGenericInstanceMethodName 接入 ResolveClassMethodCalleeName/
      MarkProcedureBodyNeededByName/ResolvePropertyReadCallee/
      EffectiveRuntimeCalleeName，调用点与 vmt 槽统一到模板名）实测
      **9/13 → 12/25 升**：Create/GetDefaultGrowStrategyI 4 total 出列，
      但模板体被标定编码后内部引用暴露 7 新 uniq（TSpan.FromPointer×2、
      FIndex×2、FCurrent、GetAllocator、GetElementSize、
      TAlignedWrapperStrategy.DEFAULT_ALIGN_SIZE）——TVec 模板内嵌
      specialize TArray<T>(TVecBuf)/TSpan/IGrowthStrategy 递归实例化链，
      模板名单点回绕不收敛。已回滚（探针实测恢复 9/13）。结论：
      必须做「实例化时递归展开嵌套泛型」的完整机制（实例名克隆 +
      FGenericWorkQueue 递归消费），单点回绕不可行。
      **侦察更新（2026-08-18，只读）**：6/10 中 method-object 族
      （TToolStatusEventVec.Count×4/Create×2/Push×1、TVec.Create×1、
      TVec.GetDefaultGrowStrategyI×1）与 Pos 同属此条目根因。根因链
      三段并确认：
      ① `InstantiateGenericType`（declaration.inc:2230）只克隆方法
      **符号**（`InstanceName.Method` AddSymbol，2395 行）与元数据/vmt
      表项（2565 行 `$vmt_func_` 写 `TToolStatusEventVec.Count`），
      **从不克隆方法体**——`ResolveClassMethodCalleeName`
      （type_metadata.inc:147）沿 ClassHasMethod 命中符号
      （FindSymbolByName）→ 最终 callee 名是实例名
      `TToolStatusEventVec.Count`，而 FProcedureBodies 只有模板名
      `TVec.Count` → MarkCallTargets 标定 miss → 不 define → undefined。
      ② encode 路径**无类型参数替换上下文**（grep 全 sema 无
      GenericArgSubst/CurrentGenericArgs 类状态）：泛型体 green tree
      直接按名翻译，body 内 `T` 不换成实参——这是同单元泛型测试能过
      （模板体不引用 T 布局）而 TVec<T> 必炸（体内嵌 TArray<T>/
      TSpan<T>/IGrowthStrategy）的根因，也是回绕方案暴露 7 新 uniq
      的同一机制。③ 函数特化已有先行范式：`specialize Fn<T>(...)`
      调用（walk_halt_calls.inc:1786 / encode_runtime_expr.inc:1358）
      把模板体按 `Fn$<实参>` 名 RegisterProcedureBody 克隆并
      `FGenericWorkQueue.Push`，WorkHead 定点循环（seed_function_bodies
      .inc:824）消费——类型特化缺的正是同款「克隆+入队」，但必须配
      ②的替换地基，否则克隆体编出来仍是模板引用。
      **实施分期建议**（每期独立探针+提交，数字只许降/持平）：
      Ⅰ. encode 类型参数替换上下文（实例化时把模板体按实例替换
      `T`→实参、`TVec.`→`InstanceName.`，嵌套 specialize 递归走
      ResolveOrInstantiateInlineGeneric）——地基，零 undefined 口径
      变化；Ⅱ. InstantiateGenericType 克隆模板方法体（复用 ③ 范式）
      + 标 Needed + 入队；Ⅲ. 若 vmt 表项/内联引用仍有剩余，再排。
      模板体注册名格式（`TVec.Count` vs `TVec<T>.Count`，影响 2406
      行 SubstSig 匹配与克隆查找）实施时用 TEMP-DIAG 先确认。
      **口 3 白名单克隆 ✅（2026-08-18，5/10 → 3/5，提交 8f90e4300）**：
      白名单 {Count, GetDefaultGrowStrategyI}（体自包含：纯字段读 /
      FactorGrow 全局调用），Needed 直标 + 防重，全 TVec 特化实例统一
      生效，opt 首错保持 @Pos 零新错误。**剩余 3 uniq 依赖「缺口乙
      （实例化上下文）」闭环**（2026-08-18 侦察，为下口立项）：
      `TToolStatusEventVec.Create`×3 链 = Create(1参) → Create(4参) →
      `inherited Create`(父类实例 TGenericCollection<TToolStatusEventRecord>)
      + `TVecBuf.Create`(TArray<TToolStatusEventRecord>) + SyncDataPtr；
      `Push`×1 链 = GetPtrUnchecked + `^ := aElement`(T 宽 store)；
      `Pos`×1 链 = `ArgTypes[I]`(TStringVec default Items → GetItem) →
      `GetPtrUnchecked(aIndex)^`(T 值 load)。三个链的公共需求：
      ① 克隆体 encode 时把 `T` 映射到实参（TArray.GetPtrUnchecked 体
      `PElement(FMemory) + aIndex` 的指针算术 stride、GetItem/Push 的
      T load/store 宽度）；② 嵌套类型实例化（TVecBuf=specialize
      TArray<T>、父类 specialize TGenericCollection<T> → 实例方法体
      递归克隆——口 2 已证父类实例方法体能 define，缺的是名字一致与
      字段/类型上下文）；③ FuncRef 短名统一（口 2 残留
      `@DoPredicateFuncProxy` vs 全限定 define）。**实现形态建议**：
      encode 方法体前建 `FCurrentGenericInstance`（模板名+实参表+实例名，
      实例化时把 ArgTypes 存成 `InstanceName.$generic_args` consts），
      类型名解析入口（TypeMeta*/FindTypeByName/cast/指针算术）对
      「泛型参数名」查表回落实参；白名单按链成员扩（GetPtrUnchecked/
      SyncDataPtr/TArray.GetPtrUnchecked/GetItem 等）。
      **口 4 实例化上下文 ✅（2026-08-18，3/5 → 1/1，提交见本 commit）**：
      按立项形态完整落地（FCurrentGenericInstance + `$generic_arg_<T>`
      consts + TypeMetaSize 回退 + 白名单链扩 + Body 指针去重），
      Create×3 链与 Push×1 链整链清零，剩 Pos×1。细节见注 ²¹。
      **剩余 Pos×1（下口立项）**：opt 首错 201774 行 `call i64 @Pos(ptr,
      i64, i64)`——`declaration.inc` 的 `Pos('<', ArgTypes[I])` 处
      haystack 是泛型 class 实例 default 索引属性（`TStringVec =
      specialize TVec<string>`：`ArgTypes[I]` 读 `TVec.Items[I]` →
      GetItem 实例方法体已 define，但 Items 读表达式本身仍残留
      value-load 空洞）。与 strpos 形态不同：strpos 是缺 runtime
      helper define，此处是**泛型实例 property read 的编码路径残渣**。
      下口从建小样本（含 `specialize TVec<string>.Items[I]` 读的测试）
      定位 value-load 空洞具体分支开始。
      **口 2 尝试+回滚（2026-08-18，探针 5/10 → 10/20 升）**：
      `InstantiateGenericType` 尾部加「模板方法体克隆」——按
      `GenericName.` 前缀克隆全部模板方法体到实例名（手动 Push +
      `IndexProcedureBodyName` + `FGenericWorkQueue.Push`；vmt 槽方法
      显式 `Needed:=True`，其余靠调用点 walk 标定）。**正面证据**：
      原 5 uniq 的 9 total（TToolStatusEventVec.Count×4/Create×3/
      Push×1/GetDefaultGrowStrategyI×1）**全部清零**，递归克隆生效
      （`.ll` 出现 `define @"TGenericCollection<TToolStatusEventRecord>.
      DoEqualsFuncProxy"` —— 嵌套父类实例（带实参）方法体已生成）。
      **新暴露 9 uniq / 20 total**（三类形态）：① 裸字段名当函数调用
      `@FInternalEquals(i64,i64)`/`@FInternalComparer`/`@FIndex()`/
      `@FCurrent()`（克隆体字段解析 miss，缺实例字段上下文）；② 函数
      指针短名 `ptrtoint ptr @DoPredicateFuncProxy`（无限定）vs define
      用全限定 `TGenericCollection<TToolStatusEventRecord>.
      DoPredicateFuncProxy` —— 方法引用（FuncRef）取名不统一；③ 全局
      函数 `@CompareByte`×5 未 define（FPC helper 族，克隆体调用点已
      产出但无 body/declare）；另 opt 首错提前到 87483 行类型不匹配
      （i32/i64）。结论：克隆机制本身成立，但需配套①实例字段上下文、
      ②FuncRef 取名统一、③CompareByte 等 FPC helper 的 declare/stub
      面，才能闭环——按「一次一个残渣面」拆口，勿再全量克隆上探针。
- [~] **B5 const fold + intrinsic 尾巴**：const-upper 7 个 + `Pos`/`UpCase`/`Int`。
      - [x] **B5a Pos 主体（strpos 数组下标 haystack + const needle）** ✅
        （80→75 total，Pos 7→2）：主流残留是「字符串数组元素 haystack」——
        现有编码把 TString(24B) 元素当 int 数组读（8B stride + load i64），
        (data,len) 语义丢失。修法与 B6 `ilk` 同哲学：新 RPN token
        `tsload`（带 arg 自查 `<name>$ptr`，无 arg pop 栈上基址；×24 →
        `gep_i8` → `np_tstring_data/len` 压 2 slot，emitter 零改动）+
        sema Pos 拦截分支扩展三形态（needle 补 `LookupStringConstValue`
        查表转 strlit，覆盖 builtins 注册的 DirectorySeparator 等 5 名；
        haystack 补 `IsRuntimeArrVar` 数组下标 → `tsload <name>` 与
        `TryClassFieldArrayAccess` 字段数组 → `field <base> <idx> p` +
        `tsload`）。fixture `pos_string_array_pass.pas`（host FPC golden）
        三 haystack × const needle 全过；compiler-pass 55/55。
        ⚠️ 已知边界：字符串数组元素**写端**在 LLVM 路径尚缺
        （EnvPut 的 `AItems[I] := ...`/SetLength 整段未生成），tsload
        读取语义要等写端补齐才能 smoke 级验证——B8 显性化。
      - [x] **B5b Pos-toml（call 实参物化）** ✅（75→74 total，Pos 2→1）：
        `Pos(LowerCase(a), LowerCase(b))` 双侧物化——needle/haystack 各起
        `$pos_ndl_N`/`$pos_hay_N` TString 临时 + `assign-tstring-call-runtime`
        （callee=EffectiveRuntimeCalleeName + EncodeStrCallArgs 惯用法）。
        旧退化编码把 (data,len) 误拆成 `LowerCase$s(sret data_ptr, len)`
        （sret 指向源指针=错误 ABI），本修复同时是正确性修复。
        fixture `pos_call_operand_pass.pas`（4 检查点 host golden）。
      - [ ] **Pos 残余 1 处 → 挂 B4b**：`InstantiateGenericType` 的
        `Pos('<', ArgTypes[I])` —— `ArgTypes` 是 `TStringVec`
        （`specialize TVec<string>`，类默认索引器=方法调用，**非**数组
        登记缺口）。正确编码需 `TStringVec.GetItem`，但 .ll 中 0 个
        TStringVec 符号（跨单元泛型实例未发射）——现在物化会给
        method-object 桶引入新 undefined（桶回升）。B4b 泛型实例整桶
        落地后由 `$pos_hay_N` + getter 物化自然接住。
      - [x] **B5c UpCase 半场** ✅（74→72 total / 54→53 uniq，UpCase 2→0，
        无桶回升）：新一元 intrinsic token `upcase`——sema 三处
        （`np_sema_encode_runtime_expr.inc` 家族列表 + HasOverload guard +
        三条 token 发射链）+ builder token 表（`np_hir_builder_process.inc`）
        + emitter branchless select 模板（`np_hir_llvm_emitter_instr.inc`：
        `['a'..'z'] → c-32`，icmp×2+and+sub+select，无分支）。
        附带：UpCase 补注册 `np_sema_builtins.pas`——独立 fixture 编译时
        sema 报 `unknown-callable`（真实闭包因 RTL 声明可见不受影响），
        注册后 fixture 才能独立过门禁。fixture `upcase_char_pass.pas`
        （5 检查点 host FPC golden）。**Int(2) 剩余**：`System.Int(AValue)`
        f64 向零截断（trig/random/scalar 3 站点），float intrinsic 面
        比 upcase 深（需 fptrunc/fp 处理链），单独口再打。
      - [x] **B5d ECore.Create 别名 canonical 化** ✅（72→69 total /
        53→52 uniq，ECore.Create 3→0，method-object 32→29，无桶回升）：
        取证修正——3 处 `@ECore.Create` **不是** raise 表达式路径，而是
        base.pas `EXxx = class(ECore)` 子类构造器 body 里的
        **statement 位置 `inherited Create(AMessage)`**
        （EArgumentNil/EInvalidArgument/EOverflow 三个 define 体内）。
        真身 `@ENextPasError.Create` define 一直存在。病灶=**同一语义
        两套解析器**：raise 路径走 `ResolveClassMethodCalleeName`
        （懂 alias），而 statement-inherited（walk:2490）与
        expression-inherited（encode:1329）各自带一条祖先链走查
        （不懂 alias），'ECore' 站 body/symbol 命中即发射幽灵 callee。
        修法=收敛到单一解析权威：两侧在**非 TObject 命中站**
        （BaseName/FuncName 轨）把 callee 过一遍
        `ResolveClassMethodCalleeName`（$resolve 表 + alias peel +
        祖先链三合一，空则保持原发射→最坏恒等现状）；TObject 兜底轨与
        receiver-backstop 轨保持 raw（B4/B4a 行为不动）。对照实验：
        encode-only rebuild 探针纹丝不动（72/53）→ 证明真实路径在
        walk 侧。fixture `inherited_create_alias_pass.pas` +
        `inherited_create_alias_parent.pas`（ECore 形态完整复刻：
        跨单元 qualified alias + 子类 ctor + inherited Create + 运行时
        验证 message 到达 base 字段；LLVM binding 下修复前
        `@EAliasCore.Create` opt fail、修复后 `call @TAliasBase.Create` ✓，
        残余 `@TChild.Destroy` 属 method-object 合成 Destroy 家族，
        非本口）。**新暴露口（B5e 候选）**：opt 首错换人
        `@EToolProfileError.imt.ENextPasError`——IMT 合成对跨单元
        parent（ENextPasError 段）未发射。**二层挂账**：call 站 2 参
        (self,msg) vs `ENextPasError.Create` define 5 参 —— F-002
        last-wins overload 阴影，undefined 清零后单独口对齐 ABI。
      - [x] **B5e imt 悬空引用 + 探针口径补盲** ✅（imt 缺口 4→0，
        探针 69/52 持平→口径扩展后基线 79/60；opt 首错
        `@EToolProfileError.imt.ENextPasError` → `@IPipeDrainReader`）：
        脱节机制——builder `EmitInterfaceSlotStore`
        （`np_hir_builder_object.inc:627`）**无条件**发 `imt_store` 引用，
        emitter `EmitImtGlobals`（`np_hir_llvm_emitter_helpers.inc:322`）
        对 **0-thunk 条目跳过 define** → 引用悬空。根子：
        `RegisterInterfaceSlots`（declaration.inc:1064，对方占用）只排除
        TObject/TInterfacedObject、不判 class/interface，把
        `EXxx = class(ENextPasError)` 的**跨单元 parent class** 塞进
        InterfaceSlots（×3：EToolProfileError/EToolchainRunnerError/
        EWorkspaceModelError）；第 4 个 `TLockGuardImpl.imt.ILockGuard`
        是真接口但跨单元 meta VmtCount=0。修法（builder 侧双拦截，
        不动对方文件）：① `Kind='class'` 的 slot 直接 Exit（parent class
        不该有 imt）；② `VmtCount<=0` 不发 imt_store（无 thunk 表反正
        为空，悬空引用比缺失 dispatch 更糟）。**探针口径补盲**：
        `m2-l3-residual.sh` 旧口径只抓 `call|invoke`，imt/vmt 表项与
        store 操作数（`ptr @X`）不计——补 ptr-ref 引用 + global 定义
        （`^@X =`）进 resolved。**挂账**：ILockGuard 类跨单元 interface
        VmtSlots seed 缺口（dispatch 正确性，非 undefined 阻塞）。
      - [x] **B5f 接口类型标识物化（最小版）**（2026-07-26，79/60 →
        75/57）：`Supports(AObj, IIntf, LOut)` 的第二实参（接口
        **类型名**作表达式，FPC 语义=物化接口 GUID）掉进 sema 裸
        标识符兜底 `var X` blob，emitter 对无 alloca 的 var 再兜底
        residual `call @X()` → **全部** `Supports$fii` 站点悬空
        （IPipeDrainReader×2 + IWriteCloser×1，源
        `nextpas.core.process.pipe.pas` DrainWith*）。三处修复：
        ① FoldCore 尾部拦截「裸标识符 = interface 类型名」→ 编码
        `int <type-symbol-id>`（真 GUID 物化挂账）；② RTL
        `System.pas` TObject 补 `GetInterface(AIID: PtrUInt;
        out AObj: Pointer): Boolean` 骨架（恒 False——`Supports`
        在 False 分支自行 ClearOutInterface，语义=安全降级）+
        `make system-projection-sync`；③ `IsSystemMinimalBodyName`
        白名单（System 单元防 flood 只 seed 12 个方法 body）补
        `TObject.GetInterface`——**取证教训：白名单不补则 body
        静默不 seed，与参数写法无关**（untyped `const AIID; out
        AObj` 与具型签名都试过，白名单才是根因）。挂账：真 GUID/imt
        查询语义（与 B5e VmtSlots seed 缺口同域，B5f-full 一起设计）；
        `TInterfaceSlotMeta.InterfaceName` 属 method-object 桶另族。
      const-upper 也是两类：**字符串常量未 fold**
      （`NPSYSTEM_UNIT_INIT = 'np.system.unit_init'` @
      `core/src/nextpas.core.system.contracts.pas:13`、`PATH_ENV_PREFIX = 'PATH='`）
      与**跨单元常量别名 seed 时序**，外加 FPC 内置 `MaxInt` 需内建。

      别名那类根因已查实（不是 EvaluateIntegerConstant 不认别名——它第 41 行
      就查 `LookupConstValue`）：**是 seed 顺序**。对照证据——基常量
      `PLATFORM_ERR_IO = 5`（`nextpas.core.platform.error.pas:49`）**0 处
      residual**，而别名 `PLATFORM_FS_SHORT_READ_ERROR = PLATFORM_ERR_IO`
      （`nextpas.core.platform.fs.pas:77`，**另一个单元**）3 处 residual。
      处理 fs.pas 的 const 段时 error.pas 的常量还没登记，
      `EvaluateIntegerConstant` 失败 → 该 const 干脆没进表 → 引用处 residual。
      修法：仿对方 B2 的 `FixupInterfaceParentImt` 模式，在所有单元 seed 完
      之后补一轮 const 重解析（`ProcessConstSection` 对已登记的会
      `SeededValue` skip，可安全重跑）。
      ⚠️ 该修法要在 `np_sema_analyzer_types.inc` 加方法声明，而并行会话正在
      改同一文件——**等对方那批改动提交后再动**，否则 `git add` 会把对方的
      半成品一起带进你的提交。
- [~] **B6 atomic + external declare**：
      - [x] **atomic 半场** ✅ e59254a51（92→80 total / 60→54 uniq，
        atomic 桶 12 整桶清零，17 处 atomic 指令发射，0 残留）：两个根因
        两条路——①语句形态：sema 大拆时 3d8121441 的 167 行 Interlocked
        编码段静默丢失（`git log -S` 取证），原样恢复进
        `np_sema_walk_halt_calls.inc`；②赋值形态（`old := InterlockedXxx(...)`）：
        普通 'call' blob 把 by-ref target load 成值、地址到 builder 已丢——
        在 `EncodeRuntimeIntExprFoldCore` 加嵌套 `TryEncodeInterlockedValueCall`
        编码 target **地址**（`varref` 兜局部/var-param/全局，
        `var self`+`field_ref` 兜字段）+ 新 RPN token `ilk <op>`，
        `EmitExprInterlocked` 复用既有 5 种 interlocked-* intrinsic，
        **emitter 零改动**。builder 两处 ptr→i64 归一化
        （NormalizeScalarValueToType → ptrtoint）兜指针交换调用点。
        新 fixture `interlocked_atomic_pass.pas`（host-FPC golden 校验）
        全链编译运行过——CAS 命中/未命中/旧值语义/64 位/全局/var-param 全对。
        顺带绕掉 units stub 假实现 InterlockedCompareExchange（F-003 病灶）。
        已知死逻辑（不动）：ProcessInterlockedOp 的 Increment +1 调整分支
        `Copy(...,1,7)='int 1'#10` 恒 False——语句形态丢结果无实害，
        赋值形态 Increment 在 L3 闭包不存在。
      - [x] **B6-EXTDECL external 纯声明注册 + emitter 大小写去重** ✅
        （2026-08-17，42/64 → 34/52 uniq/total，`np_*`/`getcwd`/
        `system` 家族全清，opt 首错换人）——**两口服**：
        **口1 implementation 区 external 声明注册 binding**
        （42→38 uniq / 64→61 total）：`np_open` 等在 stub
        SysUtils 的 **implementation 区**声明（`AttachImplementationBodiesInNode`
        对无 body 声明直接 Continue），而既有 `RegisterBodiesInNode`
        只覆盖 interface 区 → external 声明既无 symbol 也无 binding，
        调用点 fallback 发 `@np_open` residual。修法：该分支新增无
        body 处理——`FindDeclBody = nil` 且文本含 `;external:` 时
        走 `SeedImportedCallableSymbol` 注册。主战文件
        `compiler/sema/np_sema_seed_imported_unit_bodies.inc`。
        **口2 emitter 大小写敏感去重 + CleanName 注册**
        （38→34 uniq / 61→52 total）：两个根因——
        ① emitter 函数去重循环用 `SameText`（大小写不敏感），core 的
        Pascal `GetCwd`/`OpenDir`/`ReadDir`/`Stat`（define）把 stub 的
        `getcwd`/`opendir`/`readdir`/`stat`（external declare）挤掉
        （LLVM 大小写敏感，`call @getcwd` 无 declare）→ 改大小写敏感
        比较（`np_hir_llvm_emitter.pas`）；② `SeedImportedCallableSymbol`
        用**带 `;external:c:getcwd` 后缀的完整文本**注册 symbol 名，
        调用点按纯名查 miss→fallback core 同名 Pascal 函数（sret
        形态）→ 注册前截断 CleanName。新 fixture
        `tests/compiler/pass/` 由 compiler-pass 58/58 全过低证明。
        验证：undefined 34/52 稳定，无桶回升。
- [x] **B6.5 call-site 类型一致性 + 全局名引号** ✅ c6d7d5d1c：预估的
      「一类修复工作」实测只有 **1 处** call 实参不匹配（python 静态扫描全
      .ll：SSA 定义类型 vs call 实参标注，唯一命中 = `np_string_release`
      的 alloc_size）——产地 `np_hir_builder_cleanup.inc:483` 直接把 i32
      槽 load 塞进 i64 ABI 位，照同文件 dynarray fini 范本补
      `NormalizeScalarValueToType(i32→i64)`（$alloc_size 槽存储保持 i32，
      槽约定与 $len 一致）。修掉后 opt 首错暴露第二层：**VMT/IMT 定义与
      is-check 引用是裸拼接**，泛型模板名含 `<T>` 时与槽引用处
      （`LlvmGlobalRef` 有引号）不一致 → 三处统一走 `LlvmGlobalRef`。
      验证：opt 首错从语法错（`@TGenericCollection<T>.vmt`）变为
      `use of undefined value '@ECore.Create'` —— **全 .ll 解析通过**，
      opt 全 PASS 门天然挂在 undefined 清零（B1–B4）之后，本口无残留。
- [~] **B7 llc + link gen-B**：`llc` 出 `.o`，`ld + libnprt.a` link 出 B。
      **✅ 前置阻塞已全清** e8daa1a73（两层）：
      ① `scripts/setup-runtime-sdk.sh`（新）幂等装配
      `lib/nextpas/runtime/<sdk-id>/lib{c,pthread,dl,util,rt}.so`
      symlink → host libc ld script（glibc 2.34+ 已合并这四库）+
      `.gitignore` 规则；② planner `ResolveDirectLinkLibraries` 放行标准
      POSIX 库组（原来只认 'c'）逐库 FsExists 校验 `lib<id>.so`，两个
      link 消费端（llvm/host 对称）硬编码 `-lc` 换成
      `AppendDirectLinkLibraryArgs` 按 backend 请求逐库发 `-l<id>`。
      **探针证据**：planning 诊断三级链走完
      （c-library-not-found → import-library-resolution-failed(pthread) →
      **toolchainPlanStatus=ready**），llvm-link argv 完整
      （`-L<sdk> -lc -lpthread -ldl -lutil -lrt` + libnprt.a），失败点
      回归 `llvm-opt-exec-failed`（L3 本征）。
      **剩余部分自动跟随 opt PASS**：undefined 清零后 llc/link 直接跑；
      crt1.o/_start 入口等 link 期需求届时才暴露，是本口最后一段。
      原侦察注记（下方）保留作历史，其中「planner 只校验 libc.so」已过时。
      历史：toolchain planning 曾直接失败在
      `toolchain.c-library-not-found`。`np_toolchain_plan_planner.inc:137-147`
      把 runtime root 定为 `<repo>/lib/nextpas/runtime/<RuntimeSdkId>`，
      第 183-196 行要求该目录下 **实际存在** `libc.so`（`FsExists` 硬校验，
      且 `allowHostFallback=false` 不许回落到 host libc）。当前
      `lib/nextpas/runtime/` **整个目录都不存在**，仓库里唯一的 runtime 素材是
      `rtl/runtime/linux-x86_64/np_setjmp.s`，也没有任何脚本会去布置这个 SDK 目录
      （`grep -rl "lib/nextpas/runtime" scripts/ rtl/ Makefile` 无命中）。
      所以要先决定 SDK 布局策略：装一个指向系统 libc 的 SDK 目录、还是让
      planner 支持显式的 host-libc 绑定。这一步不需要等 opt PASS，可并行做。

      **侦察补充（2026-07-26，B4a 等待期查实）**：
      - 精确缺失路径 = `lib/nextpas/runtime/linux-x86_64/libc.so`
        （`runtime_sdk = "linux-x86_64"` 来自
        `build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml` [sysroot] 段）。
      - `allow_host_fallback = false` 是 **binding toml 配置层决策**，不是
        planner 硬编码——但设计意图（distribution-runtime-root）就是发行版
        自带 SDK 目录，开发期该由脚本装配，不建议改配置绕。
      - planner 还要求 `SysrootMode='runtime-sdk'` + `RuntimeRootKind=
        'distribution-runtime-root'` 字符串精确匹配——binding 已满足，无需动。
      - **libnprt.a 走的是另一条解析路**（`FindRuntimeLibrary`，planner:109-135）：
        `NEXTPAS_RUNTIME_DIR` env 或 `build/runtime/<target>/libnprt.a`，
        与 SDK 目录无关，别混。
      - `.gitignore` 无 `lib/` 规则；SDK 若用 symlink 指系统 libc
        （跨机不可移植）必须连带 `/lib/nextpas/runtime/` ignore 规则。
      - 修法定型：`scripts/setup-runtime-sdk.sh`（symlink 系统 libc.so.6 →
        SDK 目录）+ gitignore 条目，零编译器改动。planner 只校验 libc.so
        存在；crt1.o/ld-linux 等 link 期需求到 gnu-ld 步骤才暴露，走通
        planning 后再看。
      验证：`scripts/m2-two-hop.sh --phase build-b` 绿；B 能跑 `--help`。
- [ ] **B8 smoke-b**：B 编译 `examples/smoke/hello.pas` 跑通。
      验证：`m2-two-hop.sh smoke-b` 绿 → **L3 闭合，M2-2 完成**。

B8 之后才轮到 M2-3（B 编 C + equivalence report），届时在本文件续写队列。

## 会话协议（AI 开工模板）

1. **开局**（2 分钟）：`git status` 确认没踩别人改动 → `./scripts/m2-l3-residual.sh --analyze-only`
   看当前数字和首错 → 对照咬合队列找到当前口。
2. **干活**：只碰当前口涉及的文件。修完 `./scripts/m2-l3-residual.sh`（全链）验证数字下降。
3. **收口**：compiler-pass 53/53 不回退（`make test TEST_FILTER=compiler-pass`）→
   勾掉队列项 + 更新「当前战况」表 → 提交（探针数字写进 commit message）。
4. **数字升了 = 立即停**，回滚本口改动，在本文件记一行失败原因，换思路再来。
5. **rebuild 前先看有没有别人在编译**：`pgrep -af "ppcx64|rebuild-compiler.sh"`。
   两个会话共享 `build/stage0-bootstrap/`，同时 rebuild 必定竞态，症状是
   `ld.bfd: 找不到 …/<某模块>.o`（本会话已撞三次）。**不要 kill 对方**，用
   `until ! pgrep -f "ppcx64|rebuild-compiler.sh"; do sleep 15; done` 等它完。
   **同会话内也禁止并行**：探针 rebuild 与 `make test` 同时跑会互相删
   `build/stage0-bootstrap/` 产物（rebuild 链接 Fatal + fixture exit 127，
   result-fold 口实测）——先探针全链再 compiler-pass，串行。
   ⚠️ **`--no-rebuild` 复用的是 `./nextpas-m2-l3-probe` 这个拷贝，不是
   `build/stage0-bootstrap/nextpas`**（脚本只在 rebuild 分支才 cp）。自己跑过
   `rebuild-compiler.sh` 之后必须先手动
   `/bin/cp -f build/stage0-bootstrap/nextpas ./nextpas-m2-l3-probe`
   再 `--no-rebuild`，否则探针用旧编译器出假阴性（本会话 B4a 白跑一轮 8 分钟）。
6. **`make test` 报 `stage0-build-failed` 别急着怀疑自己的代码**：先看
   `build/stage0-bootstrap/stage0-build.stderr.txt`。若内容是
   `EAccessViolation`，那是 **FPC 自己崩了**，不是你的语法错误——原因是
   harness 的 `ensure_stage0`（`tests/run_all_tests.sh:89-114`）**不清理 PPU**
   就复用 `-FU build/stage0-bootstrap`，而 `scripts/rebuild-compiler.sh:22-25`
   会删 `*.ppu`/`*.o`；两者交替使用（尤其有并行会话时）就让 FPC 读到
   半新半旧的 PPU 集合而崩溃。解法：跑一次 `./scripts/rebuild-compiler.sh`
   （带清理）让 PPU 与源码一致，再跑 `make test`。本会话撞了三次。
7. **`pgrep -f` 会匹配到自己**：`until ! pgrep -f "xxx build"` 这行命令文本
   本身含 `xxx build`，于是永远等不到退出。要么加
   `| grep -v "zsh -c\|until "` 过滤，要么直接等产物文件出现
   （`until [ -f .../nextpas.ll ]`）。本会话被这个卡了 20 分钟。

## 禁止事项（L3 闭合前一律不做）

- ❌ sema 大拆 / compiler 去 SysUtils / MIR 生产化（Wave0 冻结，F-011/F-008/F-012）
- ❌ 读旧路线图考古（历史快照只在争议时查证）
- ❌ 一口咬多个桶（跨桶改动无法归因数字变化）
- ❌ 用 host FPC 编 B 源伪装 closed（红线）
- ❌ 新增 FPC RTL allowlist 条目（F-009 只减不增）

## 附录：文档权威链（导航用，执行不需要）

| 层 | 文件 | 用途 |
|----|------|------|
| 执行 | **本文件** | 唯一开工入口 |
| 探针 | `scripts/m2-l3-residual.sh` | 唯一进度度量 |
| 战略 | `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md` | M0–M9 晋级门 |
| 总控 | `PLAN.md` | 项目级事实与纪律 |
| 史料 | `docs/plans/m2/wave0-ledger.md` | nofold33–35 时代台账（数字已过期） |
| 审计 | 根 `findings.md`（不进主线） | F-001~F-022 原始审计 |
