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

## 当前战况（2026-08-23 b4b-i17 真实全量基线后实测）

| 指标 | 值 | 轨迹 |
|------|-----|------|
| tree mini 相位耗时（P0 探针，NEXTPAS_PHASE_TIMING=1，两轮方差 <2%） | **sema 296s（99%）·seed 235s（79%）·resolution 4.7s·syntax ~0** → P1 刀②后 seed **232s**、sema 292-293s（-1.5%/-2.4%，2026-08-23） | b4b-i17 LookupProcedureBody 开销 A/B 实测 **+4.8s（~1.6%）非主要矛盾**；主战场=播种路径本身（3.3 体秒），P1 索引分配直接攻此相；探针=`nextpas.compiler.frontend.phase_timing`，TSV `/tmp/m2-phase-timing.tsv`，perf top-10 受阻（无 root+strip）归 P1 启动补 |
| verify 契约红点（2026-08-23 N6 收口发现） | **compiler/tests 两门禁带病存续**：run_semantic_constructor_type_infer=wrong-create-binding-target(11≠7)、tests/hir test_hir_class_alloc_contract=missing-hir-class-alloc-intrinsic | stash 二分证明早于今日全部改动、去 b4b-i17 复测仍红→元凶更早（i 系列行为变更期），因 make verify 不在批次链而长期未暴露；归本表新口：verify-contract-archaeology，修复后 make verify 方可全绿；同轮修复 compiler/tests 五脚本与 verify_local 21 处 src 路径腐烂 |
| undefined unique | **0** | 305 → 80 (B0) → 79 (B1) → 84 (B3a+对方B2) → 79 (B4) → 78 (B3b) → 64 (B3c) → 60 (B4a) → 54 (B6-atomic) → 54 (B5a-strpos) → 54 (B5b-toml) → 53 (B5c-upcase) → 52 (B5d-ecore) → 60 (B5e 口径扩展¹) → 57 (B5f-intfid) → **42 (2026-08-16 基线) → 38 (B6-EXTDECL 口1) → 34 (B6-EXTDECL 口2) → 33 (B6-GETTID) → 30 (B6-NOINLINE) → 36 (B2-IMT²) → 32 (祖先-cohort³) → 32 (P1-Classes-zero⁴) → 31 (P2-Process-zero⁵) → 29 (A-vcall⁶) → 28 (B-destroy-fallback⁷) → 27 (C-alias⁸) → 24 (D-pointer⁹) → 18 (const-upper¹⁰) → 17 (const-fini¹¹) → 16 (stub-pathsep¹²) → 15 (reexport-fields¹³) → 12 (localtypecast¹⁴) → 11 (result-fold¹⁵) → 9 (caret-ptr¹⁶) → 7 (simd-constref¹⁷) → 6 (b65-sar¹⁸) → 5 (b4b-i1¹⁹) → 3 (b4b-i2²⁰) → 1 (b4b-i3²¹) → 1 (b4b-i4²²) → **2 (b4b-i5²³)** → 2 (b4b-i6²⁴ 静态修复) → 2 (b4b-i7²⁵ R8 探针 2/6 持平) → **0 (b4b-i8²⁶ mini 表面 0/0 + opt PASS)** → **0 (b4b-i9²⁷ THashMap slice,hashmap mini 0/0 + generic 回归 0/0 + 双 opt PASS)** → **0 (b4b-i10²⁸ TVecBuf 泛型别名,双 mini 0/0 + 双 opt PASS + compiler-pass 58/58)** → **0 (b4b-i11²⁹ isep-body/strlen-cast,isep/path 双 mini 0/0 + 双 opt PASS + compiler-pass 58/58)** → **0 (b4b-i12³⁰ case 选择器字符取值,puny switch 语义闭环 + 四 mini 0/0 + 双 opt PASS + compiler-pass 58/58)** → **0 (b4b-i13³¹ 接口实现方法可达性,iface mini TImpl 三方法 define + 五 mini 双 opt PASS + compiler-pass 58/58)** → **5 (b4b-i13³² 真实全量基线:探针刷新后 CompareByte/TNameFirstMap/SarLongint 全清,暴露面扩大浮出 Pos×68 等,见注³²)** → **4 (b4b-i14³³ vmt/imt store 引号,TVec uniq 清零 total -11,opt 首错进语义层)** → **2 (b4b-i15³⁴ IInterface dispatch 元数据+S_OK 常量,iface-qinterface/S_OK 两口清零)** → **1 (b4b-i16³⁵ Pos 拼接+字符字面量操作数物化,project-helper 桶整桶清零 Pos -68)** → **0 (b4b-i17³⁶ ordinary 契约实例名优先,SyncDataPtr×6 归零,undefined 全表清零,opt 首错转支配性违规)** → **0 (2026-08-23 全量复跑³⁷ N5/N6 挂账销项,0/0 保持)** |
| undefined total | **0** | 1338 → 251 (B0) → 173 (B1) → 166 (B3a+对方B2) → 161 (B4) → 120 (B3b) → 103 (B3c) → 92 (B4a) → 80 (B6-atomic；atomic 桶整桶清零) → 75 (B5a-strpos；Pos 7→2) → 74 (B5b-toml；Pos 2→1) → 72 (B5c-upcase；UpCase 2→0) → 69 (B5d-ecore；ECore.Create 3→0) → 79 (B5e 口径扩展¹) → 75 (B5f-intfid；接口ID 3 符号→0) → **64 (2026-08-16 基线) → 61 (B6-EXTDECL 口1) → 52 (B6-EXTDECL 口2) → 49 (B6-GETTID) → 43 (B6-NOINLINE) → 51 (B2-IMT²) → 45 (祖先-cohort³) → 44 (P2-Process-zero⁵) → 42 (A-vcall⁶) → 41 (B-destroy-fallback⁷) → 39 (C-alias⁸) → 35 (D-pointer⁹) → 25 (const-upper¹⁰) → 22 (const-fini¹¹) → 21 (stub-pathsep¹²) → 20 (reexport-fields¹³) → 16 (localtypecast¹⁴) → 15 (result-fold¹⁵) → 13 (caret-ptr¹⁶) → 11 (simd-constref¹⁷) → 10 (b65-sar¹⁸) → 10 (b4b-i1¹⁹) → 5 (b4b-i2²⁰) → 1 (b4b-i3²¹) → 1 (b4b-i4²²) → **2 (b4b-i5²³)** → 2 (b4b-i6²⁴ 静态修复) → 2 (b4b-i7²⁵ R8 探针 2/6 持平) → **0 (b4b-i8²⁶ mini 表面 0/0 + opt PASS)** → **0 (b4b-i9²⁷ THashMap slice,hashmap mini 0/0 + generic 回归 0/0 + 双 opt PASS)** → **0 (b4b-i10²⁸ TVecBuf 泛型别名,双 mini 0/0 + 双 opt PASS + compiler-pass 58/58)** → **0 (b4b-i11²⁹ isep-body/strlen-cast,isep/path 双 mini 0/0 + 双 opt PASS + compiler-pass 58/58)** → **0 (b4b-i12³⁰ case 选择器字符取值,puny switch 语义闭环 + 四 mini 0/0 + 双 opt PASS + compiler-pass 58/58)** → **0 (b4b-i13³¹ 接口实现方法可达性,iface mini TImpl 三方法 define + 五 mini 双 opt PASS + compiler-pass 58/58)** → **87 (b4b-i13³² 真实全量基线,见注³²)** → **76 (b4b-i14³³ vmt/imt store 引号,TVec×11 清零,opt 首错进语义层)** → **74 (b4b-i15³⁴ IInterface dispatch 元数据+S_OK 常量,iface-qinterface/S_OK 两口清零)** → **6 (b4b-i16³⁵ Pos 操作数物化,Pos×68 清零 project-helper 桶整桶消失)** → **0 (b4b-i17³⁶ SyncDataPtr×6 收口,undefined 全表归零)** → **0 (2026-08-23 全量复跑³⁷ N5/N6 挂账销项,0/0 保持)** |

¹ B5e 探针口径扩展（2026-07-26）：旧口径只统计 `call|invoke` 引用，漏掉
vmt/imt 表项与 store 操作数（`ptr @X`）——imt 4 缺口 opt 报错但探针不计
（「探针清零 ≠ opt 通过」盲区）。新口径 = call + ptr-ref 引用，resolved 加
global 定义（`^@X =`）。同一 .ll 对照：旧 52/69 = 新 60/79（浮出 8 uniq：
TStream vmt ×6 + TVec 泛型 ×2，全属 method-object 既有家族）。之后以新
口径为准，数字只降不升纪律从 60/79 起算。

² B2-IMT 后数字**升格非回退**：IHasher.Write(1) 与 TFileStream.ReadBuffer(1)
清零，opt 首错从 19700 行推进到 50250 行；同时 seed 期 meta 恢复让
`@TStream.vmt`/`@TToolStatusEventVec.vmt` 表完整生成，其表项引用
`TStream.GetPosition/SetPosition/GetSize/SetSize/Read/Write/Seek` 与
`TVec.Create/GetDefaultGrowStrategyI`（8 uniq）计入口径——与 B5e 浮出的
家族完全重合（method-object 桶），非新 bug。

³ 祖先-cohort（本 commit）：`MarkClassMethodCohort` 沿祖先链标记——子类
vmt 表引用父类方法槽（`TFileStream.vmt = [TStream.vmt, …]`），父类方法
无 direct Create/Destroy 触达时缺 define（TStream 6 方法）。修复后
TStream/vmt 家族 6 uniq 8 total 清零；新浮出 `TCollection.AppendToUnchecked`/
`Clear`（class virtual 方法被 direct call 且方法体未注册，method-object
家族成员继续暴露，挂账）。

⁴ P1-Classes-zero（本 commit）：`TryReadCoreTextFile` 改用
`nextpas.core.fs.util.FsReadFileText`（含 BOM/UTF-8/UTF-16/Latin-1 处理），
`rtl/core/text/np_text_primitives.pas` 去掉 `uses Classes`。编译链对
`Classes` stub 消费清零：`.ll` 中 `@TStream.*`/`@TFileStream.*` define 全部
消失；数字持平（32/45 不升）。注意：catch 必须用具体 core 异常类型
（ENotFoundError/ENextPasError）——nextPas 编译时 stub `SysUtils.Exception`
与 `nextpas.core.exception.Exception` 是互不相关的两个 class(TObject)，
`on Exception` 会失效。此口同时让 B6.5 挂账的
`TFileStream.Create`（4 参 define vs 3 实参）符号从 .ll 消失自动减压。

⁵ P2-Process-zero（本 commit）：`nextpas_command_test.pas`（stage0 test 命令）
的 RunTest 改用 `nextpas.core.process`（ICommand builder：
`/usr/bin/env` + Dir + EnvAdd×3 + Arg + Status.ExitCode），去掉 `uses
process`。编译链对 `Process` stub 消费清零：`.ll` 中 @TProcess.*/
@np_unit_init_process 全部消失，`TProcess.FCurrentDirectory`(1) 出列 →
31/44。行为验证：新编译器 `test --list-groups` 实测列出 11 组。
B6.5 挂账 `TProcess.Create`（2 参 define vs 1 实参）随之自动减压。
注意：原实现 `--filter` 是独立参数，迁移时用 `Args(['--filter', name])`
保持 argv 语义一致。

⁶ A-vcall（本 commit）：`np_sema_walk_halt_calls.inc` 三处语句位 class-receiver
分支（DotAccess-in-FunctionCall 带参 / 裸 DotAccess / implicit-self）加
`TypeMetaVmtSlot >= 0` 检查，命中时改发 vcall 槽 dispatch（halt-call-runtime
'__discard__'，与 interface ivcall 分支同构，builder/emitter 零改动）。
根因：语句位 class virtual 调用历来被静态绑定 direct call 到声明类符号，
abstract virtual（TCollection.Clear/AppendToUnchecked 无方法体）→ undefined。
验证：31/44 → 29/42 恰好 -2 无桶回升；.ll 中调用点变为
`load vmt → gep slot → load 槽函数 → 间接 call`（TCollection.AppendUnchecked
体 slot 17）；compiler-pass 58/58；hygiene pass。观感：有方法体的 virtual
语句调用一并转 dispatch（语义向 FPC 对齐，define 不被直接引用无副作用）。

⁷ B-destroy-fallback（本 commit）：`.Free` 分支（直接 receiver + 字段
receiver 两处）在 `TypeMetaVmtSlot('Destroy')`/`$vmt_func_` 解析出的
`Class.Destroy` 无方法体时，沿 `NextClassAncestorName` 找第一个有方法体的
`X.Destroy`（found-anywhere-wins，TObject.Destroy 由根 seed 兜底）。
根因：未声明 destructor 的类（TAstFacade，仅 `constructor Create`）在
`TCompilationSession.Destroy` 的 `.Free` 清理中 fallback 成本名
`@TAstFacade.Destroy` → undefined。验证：29/42 → 28/41；.ll 中该槽位
call 从 `@TAstFacade.Destroy` 变 `@TObject.Destroy`（同函数 14 个 destroy
调用中唯一异常者归位）；compiler-pass 58/58；hygiene pass。

⁸ C-alias（本 commit）：record 类型别名（`TStringBuilder = TBufStringBuilder`，
`core/src/nextpas.core.text.builder.pas:67`）的 receiver 方法调用
（`LBuilder.ToString`，`nextpas.core.text.utils.pas:187`）callee 名用 receiver
声明类型名拼限定名，而 record 方法既不注册 method symbol 也不复制
`$ret_str_/$ret_ptr_` 形态常量（别名处理块只复制 interface/class 的
VmtSlots）→ 返回形态判定失败（i64 假形态）且 `@TStringBuilder.ToString`
未定义。修复两层：① `walk_halt_calls` 三处 record receiver 方法发射点
（`Result := recvar.Method`、WriteLn 方法 sret、WriteLn 字段/方法）经新增
`ResolveRecordAliasTypeName`（沿 AliasTargetTypeId 只解析 record 目标链）
把 callee 名落到真实定义类型；② `FixupAliasMethodSymbols` 后置补齐从
FProcedureBodies（record 方法无 symbol，只能从 body Decl 判定返回形态）
复制 `$ret_str_/$ret_ptr_` 常量。TEMP-DIAG 实证：别名 AliasTargetTypeId
已就位（=1864），符号表无 `TBufStringBuilder.ToString`（record 方法
走 body 索引非符号表），卡点在绑定早退 + 发射名未跟随。验证：28/41 →
27/39（恰为 ToString 2 处调用）；.ll 两处 `call i64 @TStringBuilder.ToString`
变 `call void @TBufStringBuilder.ToString(ptr sret(%TString), …)`；
compiler-pass 58/58；hygiene pass。

⁹ D-pointer（本 commit）：`RegisterOneOuterFrame`（嵌套函数捕获注册，
`np_sema_seed_function_bodies.inc`）对捕获的 class 参数/变量硬编码
`RegisterClassVar(OName, 'Pointer')`，而普通参数注册用真实类型名 →
嵌套函数内 `ALexer.TokenCount`（const 参数, `np_unit_resolver.pas:163`）
与 `AModel.TypeCount` 等类成员访问 Receiver 类型名落 'Pointer' →
`@Pointer.TypeCount/TokenCount/GetTypeMeta` undefined（.ll 344506/344524/
363578/363629），真实定义为 `@TSemanticModel.*`/`@TLexerResult.TokenCount`。
修复：捕获注册两处（参数+变量）在 `TypeMetaIsClass` 时注册真实类型名，
仅 `^`/pointer 保留 'Pointer'，与普通参数注册路径对齐。验证：27/39 →
24/35（Pointer.* 4 uses/3 uniq 归零）；`.ll` 中 `@Pointer.(TypeCount|
TokenCount|GetTypeMeta)` 计数 0；compiler-pass 58/58；hygiene pass。
遗留（挂账）：嵌套捕获的接收者值未 store 进兜底 alloca（.ll 读未初始化
slot，运行时 UB）——需静态链接/隐藏实参传播，非 undefined 口径，单独立项。

¹⁰ const-upper（本 commit）：字符串常量标识符作函数实参未 fold——`EncodeStrCallArgs`/
`EncodeCallStatementArgs`（walk 路径）与 `EncodeRuntimeIntExprFoldCore` 的
gnkFunctionCall 实参循环（encode 路径）三处均缺 const-string 分支，常量名
落 funcref 残余 → `call @NPSYSTEM_UNIT_INIT()` 等 0 参裸调用（undefined）。
修法：三处各加「`EvaluateStringConstant` 命中 → 折叠」分支（fold 成
`strlit '<quoted>'` 或 literal temp，前者用新全局 `EncodePascalStringLiteral`
重建带引号文本——单引号加倍转义，`np_semantic_analyzer.pas` forward 声明 +
`np_sema_seeding.inc` 实现）。一次性清零 8 uniq/12 total：NPSYSTEM_UNIT_INIT×2、
NPSYSTEM_UNIT_FINI×2、PATH_ENV_PREFIX×2、MEM_HEAP_SAFETY_ENV×2、MEM_DEBUG_ENV×1、
MEM_ARENA_STRICT_ENV×1、PathSeparator×1（字符串常量家族全清）；`@AddRuntimeContract`
（嵌套过程 4 参 define vs TSemanticModel 方法 1 参调用）形态雷未触发（opt 首错
仍 `@Int`，位置 57371→57375 行微移，非回退）。验证：21/30 → 18/25；
compiler-pass 58/58；hygiene pass。遗留：`PLATFORM_FS_SHORT_READ_ERROR`（整数
常量跨单元别名 seed 时序，fs.pas 先于 error.pas 处理）3 uses 属同桶不同根因，
修法=全单元 seed 后补登（FinalizeConstSections），下一口。

¹¹ const-fini（本 commit）：`FinalizeConstSections`——所有单元 seed 完
（`FixupAliasMethodSymbols` 后）递归扫描 `FImportedUnitTrees` + `FRootAst`
所有 `gnkConstSection`，对**未登记值**的 `gnkConstDecl` 重跑 Evaluate* 补登
（已登记 skip，不重复 AddSymbol）。跨单元整数常量别名 seed 时序缺口：
fs.pas 的 `PLATFORM_FS_SHORT_READ_ERROR = PLATFORM_ERR_IO`（error.pas 的
基常量，SeedImportedUnitBodies 倒序遍历下未及登记）Evaluate 失败没进表 →
引用处 3 处 `call @PLATFORM_FS_SHORT_READ_ERROR()`。补登后
`EvaluateIntegerConstant` 沿 `LookupConstValue` 解析到 5。验证：
18/25 → 17/22（const-upper 桶整桶清零）；compiler-pass 58/58；hygiene pass。
遗留：`PathSeparator` 1 use——单字符字符串常量在字符比较场景
（`AValue[I] <> PathSeparator`，LocalFileSearch）编码成 i64 比较未 fold，
与字符串实参折叠不同路径，独立小口。

¹² stub-pathsep（本 commit）：`PathSeparator` 1 use（`LocalFileSearch` 的
`ASearchPath[SepPos] <> PathSeparator` 字符比较）根因是 stub SysUtils 缺
`PathSeparator` 常量声明（有 `PathDelim`/`DirectorySeparator` 但无新标准名）——
未声明标识符编译链落 `call @PathSeparator()`。修法：`units/linux-x86_64/
SysUtils.pas` 补 `PathSeparator = '/'`。验证：17/22 → 16/21；compiler-pass
58/58；hygiene pass。周边同型挂账：`SarLongint`（FPC System 内建，编译器仅
名字登记无展开逻辑，`.ll` 形态 `call @SarLongint(i64, ptr)` 且第 2 参形态错，
需内建展开+参数定型）、`TPthreadKeyDtor`（过程类型 cast 表达式
`TPthreadKeyDtor(ADestructor)` 被编码成函数调用）——各 1 use 独立小口。

¹³ reexport-fields（本 commit）：`TInterfaceSlotMeta.InterfaceName` 1 use
（`THIRBuilder.EmitInterfaceSlotStore` 的 `IntfName := ASlot.InterfaceName`，
record const 参数 string 字段读取）根因是 re-export 别名 meta 覆盖：
`np_semantic_model.pas` 的 `TInterfaceSlotMeta =
np_semantic_interface_slot_vec.TInterfaceSlotMeta` 使类型名 index last-wins
指向别名 meta（继承 Size/IsRecord 但 **Fields 不继承**）；walk
`TypeMetaFieldIsStr` 只查 meta.Fields/$str 常量，别名 Fields=nil → 属性/VMT
兜底全空 → fallback 错编 `call i64 @TInterfaceSlotMeta.InterfaceName(sret,
ASlot)` 方法调用。修法：别名分支继承 `AliasTargetMeta.Fields`（SetTypeMeta
的 AdoptOrClone 自动 clone 共享 vec，无所有权风险；VmtSlots 同款先例）。
最小复现（probe 直接编译）：record re-export 别名 → class 方法内
`S := ASlot.Name` → `call i64 @TSlot.Name`（rc=1）；修复后 rc=0、
`np_tstring_field_assign`。验证：16/21 → 15/20（仅此 1 use 出列，无浮出），
opt 首错 57371→57476 行微移非回退；compiler-pass 58/58；hygiene pass。

¹⁴ localtypecast（本 commit）：`PSizeUIntArray` 1 use（`TGrowingAllocator.
MixedBatch` 的 `LSizesPtr := PSizeUIntArray(ASizes)`）+ `TPthreadKeyDtor`
1 use（`platform_tls_create_with_destructor` 的
`pthread_key_create(@LKey, TPthreadKeyDtor(ADestructor))`）——都是**方法/
函数体内 type 段声明的局部类型**作强制 cast 目标。根因：局部类型不进类型
表（WalkDeclarations 只处理单元级 type 段，方法体 type 段无
ProcessTypeSection），`TryGetTypeCastTargetTypeId`（ResolveTypeId）解析失败
→ sema 报 unknown-callable（root 场景）/ encode 层 fallback residual call
@类型名（imported 场景 .ll 错编）。修法双修：encode 层 1199 通用
gnkFunctionCall 分支开头加宽松 cast 兜底（单参 + 标识符头 + 无过程
symbol/body → 按 cast fold 实参值、不发 call）；sema 层 SeedCallBindings
cast 检测加同款豁免（合法 local type cast 不再误报）。**首轮宽松版回归**：
`NextBodyIndexForNameLocal(Index)` 类无前缀方法调用被兜底误判 cast（裸名无
symbol 是方法未绑定前的常态），implicit-self 绑定被抢 → `call ptr @self()`
8 uses 浮出（uniq 15→13 但 total 20→24 升）→ 收紧：豁免仅在
`FCurrentMethodClass=''`（sema）或 `Class.Method` 限定查也 miss（encode）
时生效。**附带出列**：`Int` 2 uses（`AVX2ArrayFractF64` 的 `Int(pS[i])`
浮点取整内建）被兜底 fold 成 identity 值传递——语义近似非真实现（B6.5-
Double 立项后修正），opt 首错从 @Int 推进到 @Pos。验证：15/20 → 12/16
（3 uniq 4 total），三复现测试（root 全局/方法/imported）rc 1→0；
compiler-pass 58/58；hygiene pass。

¹⁵ result-fold（本 commit）：`PathNameLenWithoutTrailingSeparators` 的
`IsSep(APath[Result-1])` 实参错编——嵌套在数组索引里的 `Result` 走基础版
EncodeRuntimeIntExpr（gnkIdentifier 编成 `var Result` 文本），emitter 按
`Result` 找不到 alloca → 残差 `call i64 @Result()`（1 use，var-param 桶
最后一格）；同时 PAnsiChar 索引无专用 encode，通用 arrload 的 `$ptr` 槽
不存在 → 基址静默丢弃，实参只剩索引值（i64 vs 形参 ptr 不匹配，opt 挂）。
修法三处：(1) 基础版 EncodeRuntimeIntExpr/BoolExpr 加 `ARetVarName` 参数
（默认 ''），gnkIdentifier 把 `Result` 映射为 `var <retvar注册名>`（retvar
alloca 以函数名注册），Fold 两处 fallback 调用点传 FCurrentRetVarName；
(2) Fold gnkArrayAccess 三分支前加 PAnsiChar 分支（LookupPointerVar<>''）
→ `arr_elem_ref <名>`（元素地址，匹配 Char 形参 ptr ABI）；(3)
EmitExprArrElemRef `$ptr` fallback 到裸参数 alloca（PAnsiChar 参数只注册
裸名），裸指针按 1 字节元素用 `gep_i8`（原固定 `gep_i64` 会把地址算 8 倍）。
验证：12/16 → 11/15（@Result 出列，var-param 桶清零），test_result_idx
复现 rc 1→0 且 `.ll` `getelementptr i8` + `call IsSep(ptr)` 类型匹配；
compiler-pass 58/58；hygiene pass。**挂账**：IsSep 的 `C = '/'` body 错编
（objectfree 模板——赋值 RHS 布尔值表达式无比较编码路径，值上下文 cmp
缺口，L3 正确性）；`StrLen(APath)` 被宽松 cast 兜底误判为类型转换（静默
错编「APath 地址当整数」；stage0 不用 StrLen，探针不受影响，但第三方程序
会错——cast 兜底需排除已知可调用名）。**协议教训**：探针 rebuild 与
`make test` 并发会互相删 build/ 产物（rebuild 链接失败 + fixture exit 127），
必须串行。

¹⁶ caret-ptr（本 commit）：`TElementManager.FillElements` 的
`var LPDst: ^T`（单字母泛型参数指针）被词法器按 FPC control-char 字面量
规则 lex 成 `tkCharLiteral`（`^`+字母+分隔符 → char literal）→
ParseTypeReference 返回 nil 且不消费 → ParseVarSection 停在 `^T` →
ParseProcedureDecl 本地声明循环退出后看不到 begin → 兜底 skip 到 begin →
末尾「无 initialization 关键字的 FPC 语法」伪分支把方法体当 unit init 吞掉，
FillElements 前两句（`call @aElementCount()`/`call @aDst()`）泄漏为残差
（a/aDst/aElementCount 3 uniq）。FPC 语义实测：裸 `^T` 表达式=control-char
值（fp_min8 通过），`var p: ^T;` 类型声明=指针（fp_min6 通过），FPC 在
类型位置消歧；nextPas 缺这步。修法：ParseTypeReference case 加
tkCharLiteral 分支——lexeme 形如 `^X`（X 单字母）时重解释为指针类型
`gnkIdentifier('^X')`。验证：11/15 → 9/13（aDst/aElementCount 出列；
`a`/`b` 属 simd constref 独立病灶未动），test_em opt 通过（此前挂
undefined），unit 复现 mini_e 语法恢复（此前 FAKE-INIT）；compiler-pass
58/58；hygiene pass。挂账：`^T` 形态覆盖所有类型位置（别名/参数/返回），
本轮只实证 var 段。

¹⁷ simd-constref（本 commit）：`simd_cmpneq_pd(constref a, b: TM128)` 的
参数引用在 .ll 中编成 `call i64 @a()`/`call i64 @b()`（参数名当函数调用），
a/b 2 uniq undefined。根因链：① parser 参数名带修饰符前缀
（`'constref:'`+名，np_green_tree_parse_declarations）；②
SeedFunctionBodies 编码循环对「普通标量参数」else 分支发
`var-decl-runtime` 节点时 AOperand 误传 `ParamChild.Text`（带前缀
`constref:a`），其它 5 个子分支（str/arr/record/varref）均传干净名；
③ HIR ProcessVarDecl hnkVarDeclRuntime 参数分支
`RegisterAllocaEntry(AOperand)` 把 alloca 注册成 `constref:a`；④ encode
gnkIdentifier 无条件发 `var <text>`（`var a`）；⑤ EmitExprVar
`FindAlloca('a')` miss → 兜底 `hikCall('a')` → .ll `call @a()`。仅 constref
且未被识别为 record/var 的参数形态暴露（simd TM128 走 i64 槽）；assembler
实现的 simd 函数不引用参数名故无症状。修法：else 分支 AOperand 改用干净名
`RetVarName`（与其余分支一致）。验证：9/13 → 7/11（a/b 出列，7 uniq 全归
既有挂账：method-object 泛型家族 5 + SarLongint/Pos 各 1）；compiler-pass
58/58；hygiene pass。挂账：TM128 参数仍按 i64 槽编码（B6.5 ABI 域），
opt 类型一致性另议。

¹⁸ b65-sar（本 commit）：SIMD 标量模板
`Result.i[i] := SarLongint(aSrc[i], count)`（core simd
scalar.arith.wide）三层缺口一次收净，数字 7/11 → 6/10（top 变
5+1：method-object 泛型家族 5 → TToolStatusEventVec.Count×4/
Create×2/Push×1 + TVec.Create×1/GetDefaultGrowStrategyI×1，project-
helper 仅 Pos；SarLongint 出列、零新 uniq）。(1) **标量参数槽**：
`ParamTypeIsScalarCode`（16+ 位标量 → 'i' i64 槽，不再 RegisterClassVar/
'p' ptr 槽；8 位 Char/Byte/Boolean 保旧路径——Char 形参惯例接字符槽
地址，IsSep(C: Char) 类调用点依赖之）；(2) **RHS 数值指针索引**：
encode `PInt32[i]` → 新 token `pelem_load`（元素大小感知 gep_i16/32/64/
i8 + load；PChar/… 仍走地址语义），`PointeeElemSizeCode` 沿
AliasTargetTypeId 取 pointee size（PInt32→4）；(3) **移位链**：
`SarLongint(a,b)` → `a b sar` → hikShr → emitter `ashr`（顺带补 hikShl
`shl` 渲染，此前两指令均无渲染 → dangling SSA）；LHS 配套两处：`aDst[i]`
赋值目标经 `LowerArrayElemExpr` bare-name alloca 路径（指针形参无 $ptr
槽，旧 fallback 丢基址 → `use of undefined value %v…`，opt 116945 行），
`ProcessAssignArrElem` 两处 StoreType 改为元素宽度优先（TargetResult.
TypeId 为 htkInt/htkPointer 时用之；RHS 是 i64(SarLongint)、元素 i32 时
按 RHS store 会写溢出）。验证：6/10 保持、opt 首错从 116945 行 SSA 空洞
推进到 201034 行 `@Pos`（B4b 域）；compiler-pass 58/58；hygiene pass。
挂账：8 位标量（Byte/Char/Boolean）参数仍走 ptr 槽（B6.5 ABI 域）、
公共 `arrload` 兜底未随动（ProcessAssignArrElem fallback 174-198 仍按
RHS 宽度 store，主路径不触发即可）。

¹⁹ b4b-i1（本 commit）：B4b 分期Ⅰ第一刀——**vmt 表槽位名统一到实例名**。
`EnsureVmtForClass`/`ProcessVmtStore` 槽位名获取改为**优先查
`<Class>$vmt_func_N` consts**（`InstantiateGenericType` 2565 行已把模板
`TVec.` 前缀替换成 `InstanceName.`），共享的模板 `Meta.VmtSlots`
（FuncQualName 仍是裸模板名 `TVec.Create` / `TVec.GetDefaultGrowStrategyI`）
降为回退；改的是 HIR builder 两处循环，不复制/污染共享 VmtSlots。
普通类 consts 与 VmtSlots 同源（declaration.inc:1439 父类 slots 复制），
优先级反转零行为变化，仅泛型实例差异生效。验证：**6/10 → 5/10**——
vmt 表 `@TVec.Create`/`@TVec.GetDefaultGrowStrategyI` 两处裸模板名引用
合并进实例名（`TToolStatusEventVec.Create` 3 total：2 调用点 + 1 vmt 槽），
剩余 5 uniq 全部实例名形态（Count×4/Create×3/Push×1/GetDefault
GrowStrategyI×1 + Pos×1）；opt 首错保持 `@Pos`（201034 行，vmt 改动零新
错误面，402182 行 vmt 表已无裸模板名，仅剩带引号父类槽
`@"TGenericCollection<T>.vmt"`——不在探针口径，opt 面排队在 @Pos 后）。
compiler-pass 58/58；hygiene pass。挂账：父类槽 `TGenericCollection<T>.vmt`
待实例化（B4b 分期Ⅱ 递归）；`TVec.GetDefaultGrowStrategyI` 等改名后方法体
仍缺 define（B4b 分期Ⅱ 方法体克隆）。

²⁰ b4b-i2（本 commit）：B4b 分期Ⅱ 首刀——**白名单方法体克隆**。
口 2 全量克隆探针 5/10 → 10/20 升（已回滚，见 B4b 条目失败记录），
但正面情报：原 5 uniq 9 total 全清、递归克隆能生成嵌套父类实例方法体
（`TGenericCollection<TToolStatusEventRecord>.DoEqualsFuncProxy` 已
define）；残渣三类形态（裸字段当函数 `@FInternalEquals`、函数指针短名
`@DoPredicateFuncProxy`、全局函数 `@CompareByte`×5）。据此收窄：
`InstantiateGenericType` 克隆循环加**白名单 {Count, GetDefaultGrow
StrategyI}**（体自包含：纯字段读 / `FactorGrow(1.5)` 全局调用——FactorGrow
基线已在 defined.txt），手动 Push + `IndexProcedureBodyName` +
`FirstBodyIndexForNameLocal` 防重，`Needed:=True` 直标。验证：
**5/10 → 3/5**（Count×4 + GetDefaultGrowStrategyI×1 清零，全 TVec
特化实例统一生效）；opt 首错保持 `@Pos`（201416 行，克隆体编码零新
错误）；compiler-pass 58/58；hygiene pass。剩余：
`TToolStatusEventVec.Create`×3 + `Push`×1 + `Pos`×1。挂账：
Create/Push 链含父类实例（inherited Create）、嵌套类型（TVecBuf=
TArray<T>）、全局函数与 T 布局 store——需「实例上下文 + 链上克隆」面，
下口按链闭合成员逐个扩白名单。

²¹ b4b-i3（本 commit）：B4b 缺口乙闭环第一刀——**实例化上下文
（FCurrentGenericInstance）**。按口 3 立项形态落地：`InstantiateGenericType`
存 `InstanceName.$generic_inst`（存在标记）与 `InstanceName.$generic_arg_<T>`
= 实参 consts（declaration.inc）；seed WorkHead 循环 encode 克隆体前按
方法名推导实例名并查标记设 `FCurrentGenericInstance`、编码后清除
（seed_function_bodies.inc）；`TypeMetaSize` wrapper 遇 `Result<=0` 且
当前实例存在时查 `$generic_arg_<ATypeName>` 回落实参递归解析
（overload_analysis.inc）。白名单按链闭合扩：通用
{Count, GetDefaultGrowStrategyI}；`TArray` 模板 + {GetPtrUnchecked,
GetMemory, GetCount}；`TToolStatusEventVec` 实例 + {Create, Push,
GetPtrUnchecked, SyncDataPtr, GetItem}；去重从「名唯一」改「Body 指针
唯一」——同名重载（TVec.Create ×2）各自克隆。验证：**3/5 → 1/1**
（Create×3 链 + Push×1 链整链清零——T 指针算术 stride / T load-store
宽度全部经实参映射解析成功；Count/GetDefaultGrowStrategyI 无回退）；
opt 首错仍 `@Pos`（201416 → 201774 行）；compiler-pass 58/58；
hygiene pass。剩余：`Pos`×1——泛型 default 索引属性 haystack 兜底
（`ArgTypes[I]` → `TVec.Items` → `GetItem` 实例方法已 define，但
`TVec.Items[I]` 读表达式的 value-load 路径仍残，下口按 strpos 形态收）

²² b4b-i4（本 commit）：B4b 缺口乙闭环第二刀——**泛型实例化时序重试 + 全
TVec 白名单**。根因链：单元图按发现序注册（`AddResolvedUnit` Push 非拓扑
序），`SeedImportedUnitBodies` 逆序遍历时 `core.collections.vec` 模板晚于
compiler 各单元的 specialize 实例化 → `InstantiateGenericType` 中
`GenericTypeId <= 0` 提前 Exit（118 次，TStringVec 含）→ 实例成空壳（无
`$size`）→ 方法体局部 var 的 class 登记（seed_function_bodies 1289 行）因
`TypeMetaSize<=0` 跳过 → `LookupClassVar('ArgTypes')=''` → strpos haystack
分支全 miss → 兜底裸 `@Pos`（needle/haystack 错位）。修复三件套：
① 延后重试队列 `FGenericRetrySpecs`（`ASpecText+#9+AOwnerUnitId+#9+
AInstanceTypeId`），主循环后重放（上限 4096 轮）；② 白名单从 2 实例扩到
`SameText(GenericName,'TVec')` 全覆盖 14 方法（Create/Push/GetPtrUnchecked/
SyncDataPtr/GetItem/GetUnchecked/EnsureCapacity/GetPtr/GetCapacity/Clear/
PushUnchecked/Zero/Resize/ToArray）+ 通用 {Count, GetDefaultGrowStrategyI} +
`TArray` {GetPtrUnchecked, GetMemory, GetCount}；③ 去重按 Body 指针（同名
重载各自克隆）。验证轨迹：**23/62 (R1) → 127/133 (R2) → 111/111 (R3) →
1/1 (R4)**——`@Pos` 清零（连续两轮）；TVec 直系 14 方法 110 实例清零
（GetUnchecked×110 是最后桶）；compiler-pass 58/58；hygiene pass。剩余：
`TProcedureBodyNameFirstMap.Create`（THashMap 家族）+ 探针口径盲区
`TGenericCollection<T>.Create` 系列（TVec 克隆体的 `inherited Create` 带出的
泛型父类实例方法，尖括号实例名不在 `$sym` 统计口径，opt 首错 207650 行）——
同属「泛型基类实例方法链」（TGenericCollection 112 方法，Create 体内嵌
`TElementManager<T>` 模板），下一口收 |

²³ b4b-i5（本 commit）：**泛型基类实例方法链闭合**——白名单扩
`TGenericCollection`/`TElementManager` 实例方法族 + DefaultProxy 排除。
验证轨迹：**4/182 (R5) → 2/6 (R6)**（R5 浮出：DoCompare*/DoEquals* 克隆体完整化
引用 DefaultProxy 2 方法，其体调 FInternalComparer/FInternalEquals 字段方法指针
（编码缺陷）→ 176 undefined；R6 排除 DefaultProxy → 2/6，遗留
`CompareByte`×5（字符串比较链挂账）+ `TProcedureBodyNameFirstMap.Create`×1
（THashMap 挂账））。**R7 结论（探针 2/6 持平，未提交）**：尖括号实例名
（`TGenericCollection<Boolean>.Create`）的 inherited 解析试验
（`NextClassAncestorName` strip 模板名回查）验证**无效**——克隆体
`TGenericCollection<T>.Create` 的 **body 注册即残缺**：StatementList 仅 1 条
`gnkProcedureCallStatement('Create')`（inherited 前缀丢失、FElementManager/case
分支全缺）；该 'Create' 语句被语句级 walk（walk_halt_calls 3103 全局函数优先
分支）误绑定到 .ll 中同名全局符号 Create（某 FsCreate 包装），输出裸
`call @Create`。对照 `TBoolVec.Create` 克隆体完整（inherited →
`TGenericCollection<Boolean>.Create` + 字段 + SyncDataPtr），当时的「耗时登记
晚于实例化克隆源」推因**不成立**——b4b-i6（注²⁴）诊断证明 FProcedureBodies
里 4 个 Create 重载模板 entry 各自完整（stmts=5/1/1/2）且全部克隆进编码队列，
残缺的真相是 RegisterProcedureBody 的同签名合并（参见注²⁴）与
`specialize X<T>.M` 泛型方法调用 walk 缺位。数字纪律说明：b4b-i4 的 1/1 掩盖口径盲区
（尖括号实例名不在 `$sym`），2/6 即当前真实残余；compiler-pass 58/58；
hygiene pass。 |

²⁴ b4b-i6（本 commit）：**RegisterProcedureBody 同签名合并的根因修复**。
克隆体残缺（StatementList 仅 1 条的 'Create'）的静态归因链：parser 对
`const aSrc: array of T` 生成 Text='' 的 gnkArrayType 参数类型节点 →
GetParamIdentitySignature 拼出的身份签名把 `TGenericCollection.Create
(aAllocator,aData)`（主重载，1959 行，stmts=5）与 `Create(const aSrc: array
of T; aAllocator; aData)`（2118 行，stmts=2）判为**同一签名
`tmemallocator|pointer`** → RegisterProcedureBody 同名+同签名更新把完整主重载
body 覆盖为委托重载体（body 共享指针被克隆，残缺即必然）。修复：open-array
空类型段占位 `'?'`。诊断验证（mini 入口 build/m2_mini_generic.pas）：
模板侧 4 个 Create 重载独立存在（sig=[tmemallocator|pointer] stmts=5、
[?] stmts=1、[?|tmemallocator] stmts=1、[?|tmemallocator|pointer] stmts=2），
全部 [CLONE-OK] 进编码队列；裸 `call @Create` 计数归零。minic 复跑后克隆体
**仍 5 参残缺**（TElementManager<Boolean> 引用数=0）——第二根因已定位**
（b4b-i7 挂账）**：walk 普通路径对 `specialize TElementManager<T>.Create`
这类**泛型方法调用**缺位（walk_halt_calls 1774 行 specialize 分支是为编译时
求值自由函数 `specialize X<T>` 写的：拆出 `X$args` 丢掉 `.M`、不做 T→实参
替换、不触发现场实例化），1959 主重载体在 `FElementManager := specialize
...` 语句处编码中断（TVec 主重载同样断在 `FBuf := TVecBuf.Create`）；对照
TGC 的 DoCompare*/DoEquals*/GetElementTypeInfo 克隆体完整（其体无 specialize
调用）。**opt 验证同时被 CompareByte 链（b4b-i8 挂账）阻隔**：RTL 比较函数
（CompareStr/AnsiCompareStr/CompareMemRange）调用的 FPC magic `CompareByte`
无 define，且 `aLeft[1]` 字符串索引生成的 strcharload 指令在 HIR 解码端
（np_hir_builder_process.inc）无分支——参数退化为索引常量。本轮 mini 实测
opt 首错 = `@CompareByte`（.ll 2311 行）。compiler-pass 58/58；hygiene pass。 |

²⁵ b4b-i7（本 commit）：**specialize 泛型方法调用链 + 零参方法调用编码**。
（a）parser：`specialize X<T>.M` 在 '>' 后恢复 '.M' 拼接（原 dot-walk 被
尖括号参数截断，callee 退化为裸泛型名）；（b）新增
`ResolveSpecializedClassMethodCall`：模板参数经 FCurrentGenericInstance 的
`$generic_arg_<name>` 替换为实参、实例类型 FindTypeByName<=0 时
ResolveOrInstantiateInlineGeneric 现场实例化、最后
ResolveClassMethodCalleeName 决议 callee；（c）walk 两个分支：赋值 RHS
`F := specialize X<T>.M(...)`（RegisterClassVar(Decoded,OwnerClassName) 让
后续 `FElementManager.GetElementSize` 经 LookupClassVar 找到方法）与语句
形式；（d）encode 成员调用链守卫 `ChildCount>=2` 放宽为 `>=1`——零参调用
`GetElementTypeInfo()` 之前整个被挡在隐式 self 分支（FCurrentMethodClass
链解析 + `var self` + `call Class.Method n+1`）之外而静默丢弃，修后 .ll 出现
`%v = call ptr @"TGenericCollection<Boolean>.GetElementTypeInfo"(ptr %self)`
+ store 到 LTypeInfo；（e）receiver 为当前类字段时用 `field self <idx> [p]`
而非 `var FField`（后者无 alloca，退化为 `call @FField()`），并新增
DotAccess 无括号方法引用分支（`FElementManager.GetElementSize` 无括号形态）。
**未收，挂账（5）**：`case LTypeInfo^.Kind of` 整体缺失——LowerRuntimeCase
Statement 第 1458 行选择器 EncodeRuntimeIntExprFold 失败即 Exit；根因链：
walker 局部变量声明（codegen 1850-1859）对 `LTypeInfo: PTypeInfo` 未注册
pointer var（TypeMetaIsPointer('PTypeInfo') 判定不成立）→
LookupPointerVar('LTypeInfo')='' → TryPointerFieldAccess 失败；case 体内
`TInternalCompareMethod(@DoCompareBool)` 方法引用存储是另一独立缺口。数字：
R8 探针 undefined uniq=2 total=6 持平不升；compiler-pass 58/58；hygiene pass。 |

²⁶ b4b-i8（本 commit）：**CompareByte 链 + seed meta 保护 + 属性/虚方法引用
+ 局部 alloca 副作用修复**，mini（build/m2_mini_generic.pas）**opt 全链通过**
（undefined uniq=0 total=0；opt+llc+ld 成功、diagnostic=0、可执行文件产出）。
（a）CompareByte magic：encode 端新增 untyped-const 地址参数处理（字符串索引
参数经 `tsdata` 取 char 缓冲地址+索引修正，`P^` 传指针值），映射到 runtime
`np_compare_byte`（declare 进 np_hir_llvm_emitter_helpers.inc、define 进
`nextpas.runtime.strings.ll` 字典序 memcmp），5 处 `@CompareByte` 清零；
（b）SeedCachedTypeGaps 保护补 `Meta.Fields<>nil`（原只查 VmtSlots/VmtCount，
方法全非 virtual 的类如 TElementManager 被空 meta 覆盖，META-CLR 55→0）；
（c）1653 无括号方法引用分支排除 `$read` 属性（`aSrc.Data` 是属性读取不是
方法引用）并对 virtual/abstract 成员（TCollection.GetCount）改走 vmt vcall
（direct call @Type.GetCount 无 define）；2242 `$read` getter 分支同样加
vcall 分发；（d）**EnsureAlloca 副作用修复（本轮最后一根因）**：存在性检查
原用 `FindAlloca`，它查不到局部时回退 SameText 全局匹配并当场 materialize
global_ref——局部 `b: Byte` 撞上程序级全局 `B: TBoolVec` 后 `FindAlloca` 返回
非零 → EnsureAlloca 提前退出，局部 b 永远无 alloca，全部引用落 `@g_b`（未定义
全局，opt 报 use of undefined value）。修法：改用无副作用的 `FindLocalAlloca`；
（e）PByte 元素索引值加载：numeric-pointee 分支护栏 `Folded>1` 放宽为 `>=1`
（PByte 元素大小 1 时之前落进丢 base 的通用 arrload fallback，`b := pB[i]`
只编出索引 i）；builder 端 EmitExprPtrElemLoad 已支持 size 1（gep_i8+i8 load）。
验证：Utf8Validate_SSE2 的 `b := pB[i]` 变为 gep+load i8+sext 的整数比较，
`@g_b` 归零、`@g_B`（程序变量）保留。**挂账**：① 可执行文件 PT_INTERP=
/lib/ld64.so.1 本机不存在（toolchain linker profile 既有问题，此前轮次只验
opt 未运行过产物）；② CompareByte 调用点参数签名 i64/ptr 混用（x86-64 ABI
等价，运行时正确，静态类型注解待统一）；③ THashMap.Create / TVecBuf 泛型别名 /
method-object / (5) case 选择器 / project-helper SarLongint / b2-next /
capture-ub / b65-double / isep-body / strlen-cast / sar-shift 挂账不变。
数字：mini 0/0 + opt PASS；compiler-pass 待跑；hygiene pass。 |

²⁷ b4b-i9（本 commit）：**THashMap.Create 白名单 slice**。注²² 挂账
`TProcedureBodyNameFirstMap.Create`（THashMap 家族）b51 探针复现为 opt 首错
`use of undefined value '@TNameFirstMap.Create'`（.ll 699 行）——THashMap 模板
方法体未克隆到实例名（白名单未覆盖该 GenericName）。临时 [wl-diag] 诊断：
GenericName=THashMap、InstanceName=TNameFirstMap、templateEntries=42（模板侧
42 个 `THashMap.` 前缀 body entry 完整存在，名字形态匹配，问题只在白名单）。
修法：白名单扩 THashMap slice {Create, InitCapacity, NextPow2, RecalcMaxLoad}
——Create 闭包：Create 调 InitCapacity（inherited base Create 由
TGenericCollection slice 覆盖），InitCapacity 调 NextPow2/RecalcMaxLoad；保持
slice 到闭包边界，one probe per slice。验证：hashmap mini
（build/m2_mini_hashmap.pas，`specialize THashMap<string,LongInt>`）opt -O2
PASS + `-passes=verify` PASS、undefined uniq=0、
`@TNameFirstMap.(Create|InitCapacity|NextPow2|RecalcMaxLoad)` 4 define 齐；
m2_mini_generic 回归 opt PASS + verify PASS + 0 undefined；compiler-pass
58/58；hygiene pass。挂账：TVecBuf 泛型别名 / method-object / (5) case 选择器 /
project-helper SarLongint / b2-next / capture-ub / b65-double / isep-body /
strlen-cast / sar-shift 不变；toolchain 汇编面 `nextpas.core.simd.sse2`
（`crc32l %sil` 非法寄存器，emitter 指令编码既有问题，属 native 后端非 LLVM
链）与本口无因果，继续挂账。

²⁸ b4b-i10（本 commit）：**TVecBuf 类内泛型别名闭环 + 字段 receiver 走类域
meta + ClassHasMethod 只认 body**，注²⁶/²⁷ 挂账的「TVecBuf 泛型别名」清零。
（a）parser：类体内 type 段（`TVecBuf = specialize TArray<T>`）原被「跳过到
visibility」整体丢弃（零节点），改递归 ParseTypeSection 产 gnkTypeSection；
（b）ProcessClassFields 注册类内别名：AddType + AddSymbol（'type' 符号——
ResolveTypeIdForOwner 查 symbol 表，缺它时 FBuf TypeId=0、方法 receiver 落
PAnsiChar）+ `$class_spec`/`$class_owner_unit` 常量 + SetTypeAliasTarget
seed metadata entry（GetTypeMeta 线性查 FTypeMetadataEntries，FindTypeByName
不播种，不 seed 则 alias0 分支 GetTypeMeta 失败）；
（c）PeelAliasClassName alias0 分支：`$class_spec` 的 `<...>` 模板参数经
`FCurrentGenericInstance.$generic_arg_<T>` 映射成具体 arg（TVec<Boolean>
实例下 T→Boolean），拼出 ExpandedName `TArray<Boolean>`，FindTypeByName
不中则 ResolveOrInstantiateInlineGeneric 实例化；
（d）encode 字段 receiver：原按 Name 取查到的第一个 symbol，被 text.builder
的 `FBuf: PAnsiChar` 劫持（GetMemory/GetCount 2 uniq 落 PAnsiChar）→ 改
GetFieldMetaByName 限定当前类 meta；
（e）ClassHasMethod 只认 body、不再 OR 符号命中：TArray<Boolean> 自身不声明
Create（继承自 TGenericCollection<T>），符号命中无 body 会编出 undefined
callee——现在经祖先链落 TGenericCollection<Boolean>.Create（白名单 body 在）。
验证：generic（TVec<Boolean>/TVec<LongInt>）+ hashmap 双 mini opt -O2 PASS +
`-passes=verify` PASS、undefined uniq=0、.ll 中 TVecBuf/PAnsiChar 零残留
（expanded=TArray<Boolean>/TArray<LongInt> found=1）；compiler-pass 58/58；
hygiene pass。挂账：method-object / (5) case 选择器 / project-helper
SarLongint / b2-next / capture-ub / b65-double / isep-body / strlen-cast /
sar-shift 不变；toolchain sse2 汇编面 `crc32l %sil` 继续挂账。 |

²⁹ b4b-i11（本 commit）：**字符比较值语义闭环**（isep-body 挂账清零，
strlen-cast 的 `#0` 折叠同域收口）。
（a）值上下文比较缺口：赋值 RHS `Result := C = '/'` 原无比较 fold 路径
（TryEmitIntLiteral 产结构化 `expr 47` 行，ParseIntExprArgTyped 失败不入栈、
成功即 Exit 截断 → cmp 左操作数空栈），赋值被静默丢弃、函数体退化成
objectfree 空模板 → 二元分支补 `= <> < <= > >=` fold + `expr N` 行改产
`int N`；
（b）Char 形参 ABI（8 位标量经 seed 注册为伪类变量，槽存字符地址）与 char
指针索引（StrLen: `S[Result]` 经 arr_elem_ref 只产元素地址）在比较前经
`charval`（load i8）取值：IntExpr 二元比较（赋值 RHS）与 BoolExpr 比较
（while/if 条件）两路注入；`while S[Result] <> #0` 原编码成 `icmp ne ptr`
（`&S[Result] != null` 恒真死循环），现 `load i8` + `icmp ne i8` + Inc +
回跳完整；
（c）`'x'`/`#num`/`#$hex` 字面量折叠成码值（原 `Ord('#')=35` 错折，`#0` 折
35 致 while 条件错）；
（d）8 位伪类标量变量/Pointer 收尾不再生成 object-free 模板（死 null 检查
残留清零）。
验证：isep（`Result := C = '/'`）+ path（`while S[Result] <> #0`）双 mini
opt -O2 PASS + `-passes=verify` PASS、undefined uniq=0、.ll IsSep
`icmp eq i8`、StrLen `load i8`+`icmp ne i8`+Inc+回跳 语义完整、objectfree
零残留；generic/hashmap 回归 0/0；compiler-pass 58/58；hygiene pass。
挂账：method-object / (5) case 选择器 / project-helper Sarlongint /
b2-next / capture-ub / b65-double / sar-shift 不变；toolchain sse2
汇编面 `crc32l %sil` 继续挂账。 |

³⁰ b4b-i12（本 commit）：**case 选择器字符取值闭环**（(5) case 选择器 挂账的
「选择器编码失败即 Exit」侧清零；PTypeInfo 指针 var 子项未触及，继续挂账）。
DigitDecode(C: Char) 探针实锤：switch 选择器原为 `ptrtoint` 字符地址
（地址对比 65/97/48 永不命中，恒走 default -1），分支体 `Ord(C)` 同样取
地址（`sub i64 0, 地址`），且 `Ord('A')` 折叠后空 blob（TryEmitIntLiteral
成功块只列 Pred/Succ/Abs/UpCase，Ord 直落 Exit 返回空串）——sub 退化成
`0 - C`。
（a）LowerRuntimeCaseStatement：选择器 fold 后若为 char 值 operand（8 位
伪类变量 / char 指针索引，判据同 b4b-i11）追加 `charval`（load i8）；
（b）intrinsic 单参数路径（Ord/UpCase/Pred/Succ/Abs/Bsf*/Bsr*）：char 值
operand 同样先加载（Ord(C) 不再取地址）；
（c）`Ord('A')` 等字符字面量参数：TryEmitIntLiteral 成功块补 Ord 分支产
`int N`（结构化 `expr` 行在二元 blob 中间会被 ParseIntExprArgTyped 丢弃，
同 #num 折叠教训）。
验证：puny 探针（DigitDecode）switch 选择器 `load i8`+`sext`+`switch i64`
对 65-90/97-122/48-57 分支、分支体 `C-65`/`C-97`/`(C-48)+26`、default -1
语义完整；isep/path/generic/hashmap 四 mini 回归 0/0 + 双 opt PASS；
compiler-pass 58/58；hygiene pass。puny 全链 opt 仍被既有 `@Copy` 未定义
挡住（runtime helper 缺失家族，非本口引入，行号仅随新增代码位移）。
挂账：method-object / project-helper Sarlongint / b2-next / capture-ub /
b65-double / sar-shift / case-selector 的 PTypeInfo 侧 不变；toolchain
sse2 汇编面 `crc32l %sil` 继续挂账。 |

³¹ b4b-i13（本 commit）：**接口实现方法可达性闭环**（b2-next 挂账清零）。
真根因：imt 常量（thunk）静态调 `@实现类.方法`，而接口调用点（ivcall）
只经 slot/thunk，可达性收集（main green + TypedHir call + body 内 call）
看不到实现类方法 — thunk 引用悬空（opt: `use of undefined value
'@TImpl.Bar1'`）。修法：CollectReachableBodyRoots 根标记段新增
MarkInterfaceImplementorMethods：遍历 root 单元 declared 类型中带
InterfaceSlots 的类，对其接口 VmtSlots 方法逐名 Mark（ClassName.MethodName）。
只限 root 单元：导入单元接口方法全量 seed 会爆泛型/克隆家族（远端同类
缺口并入挂账，留待专用口）。验证：iface mini（IFoo 父接口 2 方法 +
IBar 自身 1 方法，TImpl implements IBar）→ TImpl.Foo1/Foo2/Bar1 三方法
define、thunk 引用解析、build succeeded、opt -O2 + `-passes=verify` PASS；
needed 13→16；isep/path/generic/hashmap 回归双 PASS；compiler-pass
58/58；hygiene pass。挂账：method-object / project-helper Sarlongint /
capture-ub / b65-double / sar-shift / case-selector 的 PTypeInfo 侧 /
导入单元接口实现方法（root 限定外的 b2-next 同族）不变；toolchain sse2
汇编面 `crc32l %sil` 继续挂账。 |

³² b4b-i13 真实全量基线（本 commit，无编译器语义改动）：**探针刷新纪律
缺口修正 + cmpbyte-diag 闭环 + sar-confirm 闭环**。根因：`m2-l3-residual.sh`
的 `PROBE=./nextpas-m2-l3-probe` 是固定名，只有 `--no-rebuild` 关闭时才从
`build/stage0-bootstrap/nextpas` 刷新——b4b-i7 起的全量基线（含 b4b-i13
提交时的「2/6 持平」）全部跑在 b4b-i6 时代（08-20 07:10）的旧探针上，
i7~i13 的修复从未反映到全量数字。诊断过程：mini（b97/b100）CompareStr
命中 np_compare_byte 而全量裸调 @CompareByte，三探针（直接调用/函数链/
泛型克隆体）均未复现 → 最终 strings 对比二进制发现默认探针停在 i6。
刷新探针后真实全量：**CompareByte×5 清零**（b4b-i8 生效，np_compare_byte
×7 命中）、**TProcedureBodyNameFirstMap.Create 清零**（b4b-i9 生效）、
**SarLongint 消失**（sar-confirm 挂账闭环）；uniq 2→5、total 6→87 的
上升是编码覆盖面扩大（i7~i13 泛型/接口/字符修复让更多 body 正确入列）
暴露的下游调用点，非语义回退——旧 2/6 是「病没暴露」的假象。新暴露面：
Pos×68（sysutils 字符串函数，project-helper）、TVec×11+TVec.SyncDataPtr×6
（泛型实例 vmt 名尖括号未加引号 → opt 首错变 IR 语法层 store
`@TVec<string>.vmt`）、S_OK×1（const-upper）、IInterface.QueryInterface×1。
纪律：每次 rebuild 后必须 `command install -m 0755
build/stage0-bootstrap/nextpas ./nextpas-m2-l3-probe`；「数字只许降」以
同一探针二进制为前提，跨代际基线刷新须注明暴露面变化。验证：五 mini
双 opt PASS 不变；compiler-pass 58/58；hygiene pass；git diff --check。 |

³³ b4b-i14（本 commit）：**vmt/imt store 引号闭环**（tvec-vmt-quote 口）。
根因：`np_hir_llvm_emitter_instr.inc` 的 `vmt_store`/`imt_store` 发射硬拼
`'store ptr @' + CallTarget`，泛型实例名（`TVec<string>.vmt`）含尖括号，
LLVM IR 未引号标识符只容 `[A-Za-z$._0-9]` → opt 报
`expected ',' after store operand`（IR 语法层，11 处 TVec 实例 vmt store
全挡）。而 vmt 定义侧（EmitVmtGlobals）与调用点早已走 `LlvmGlobalRef`
（按需加引号），唯二漏网是这两个 store。修法：两处改走 `LlvmGlobalRef`，
对合法名零变化、对含 `<>'" 等字符的名自动加引号。
验证：全量 5/87→**4/76**（TVec uniq 清零、total 恰 -11）；.ll 未引号
尖括号残留 0；opt 首错从语法层推进到语义层
`@IInterface.QueryInterface`（97582 行）；十 mini 回归 isep/path/generic/
hashmap/iface/sar/cmpbyte/cmpmid/cmpgen/tvec 编译全过 + tvec 双步 opt
PASS；compiler-pass 58/58；hygiene pass；git diff --check。
新暴露记录（非本口引入，b101/b102 隔离确认同态）：puny mini 浮出
`@Copy` undefined（DetectLinuxCores 调 Copy 字符串切片——i11~i13 可达性
扩大的暴露面，与 Pos×68 同属 sysutils-string 家族，归 pos-intrinsic 口）；
cmpgen mini 浮出 `@TC.DoContains` 等 vmt 槽 undefined——vmt 表发射把
DoContains/DoCountOf/DoFill/IsCompatible 等槽填成实例名前缀（TC.XXX），
但克隆白名单只覆盖 DoCompare*/DoEquals*/Create/GetElementTypeInfo，
方法体无 define（method-object 泛型家族的精确形态，修法候选：vmt 槽
回退基类实现或白名单扩展）。工作方式：每口先设计最便宜的可信验证
（定向 mini 探针），全量仅用于基线刷新节点，不逐口串行等待。 |

³⁴ b4b-i15（本 commit）：**内建 IInterface dispatch 元数据 seed + S_OK
常量化**（iface-qinterface / s-ok-const 两口清零）。根因：sema builtins
对 `IInterface` 只 AddType 不设 meta——Meta.Size=0 且无 `$vmt_count`
const，表达式位接口方法调用过不了 TypeIdHasKnownClassLayout
（np_sema_type_check.pas 要求 `(not IsRecord) and Size>0` 或 vmt_count
const），TryGetDispatchedMemberCallContract 失败 → 静态绑定 fallback →
`@IInterface.QueryInterface` 无 define（S_OK 同理无 fold）。修法：
np_sema_builtins.pas 在 AddType('IUnknown') 后补全元数据——`$vmt_count`=3、
`$vmt_slot_{QueryInterface,_AddRef,_Release}`=0/1/2 consts、三方法符号
（QueryInterface 2 参 'pp' 签名；_AddRef/_Release 0 参）、Meta.Size:=8 +
IsRecord:=False（SetTypeMeta 全字段显式赋值）。S_OK：core.base.pas const
区加 `S_OK = 0`（FPC System/ObjPas 均无此常量，实验证实双编译器无冲突）。
放弃路径记录：① base.pas 声明 `IInterface = interface`——FPC 下与
System.IInterface 分裂继承树，nextpas.core.process.pipe.pas 报
"Got IReader, expected IInterface"，回滚；② SetTypeScalarFact(sskPointer)——
receiver 类型名被解析成 'Pointer' → `@Pointer.QueryInterface`，回退。
验证：qi mini（TFoo class Supports 表达式位）slot dispatch 形态
`load vmt → gep slot 0 → call i64 %v378(ptr,…)`、双步 opt PASS；十 mini
回归 8 PASS + puny(@Copy)/cmpgen(@TC.DoContains) 为注³³已知挂账非新回归；
compiler-pass 58/58；全量 4/76→**2/74**，opt 首错推进到 `@Pos`
（362582 行，pos-intrinsic 口成下一目标）；hygiene pass；git diff --check。 |

³⁵ b4b-i16（本 commit）：**Pos 通用 codegen 操作数物化闭环**
（pos-intrinsic 口，project-helper 桶整桶清零）。根因：EncodeRuntimeIntExprFoldCore
的 Pos 分支只认手工枚举形态（strlit/已注册标识符/字符串常量/带体调用/
数组元素/属性 getter），两类高频形态全部落空——①拼接树针与草堆
（`Pos(',' + SC + ',', ',' + IntfList + ',')`，CheckSingleConstraint 等）
②字符字面量针（`Pos(#9, …)`/`Pos(#10, …)` blob 解析家族，THIRBuilder.Process*
63 处）→ 落到通用整数折叠：拼接树变 ptrtoint/add 垃圾参数、char 针变
序数常量（IR 里 `add i64 9, 0` 即 TAB 的 ASCII 码），裸调 `@Pos` 无 define。
修法：新增 EncodePosConcatOperand——已注册 $ts 标识符直通名字；字符串字面量
与字符字面量（#NN/#$HH/'c'）物化为 `$pos_cat_N` 临时（var-decl-tstring-runtime
+ assign-tstring-literal-runtime，字面量节点收解码字节故引号字符也安全，
#13#10 多段拒绝）；'+' 子树递归物化（assign-tstring-concat-runtime，
Name=dest/Operand=左#9右）；临时全入 QueuePendingStringTempRelease。
Pos 分支守卫放宽为"空则尝试"，不支持的种类返回 '' 原行为不变。全程复用
已有 np_str_pos 管线（blob 'strpos' → EmitExprStrPos → emitter declare），
builder/emitter 零改动。放弃路径记录：EmitStrConcatOperand 的拼接分支
dest 与操作数写反（Name=left#9right、Text=dest），本口绕开未修（挂账）。
中间基线：仅拼接修复时全量 2/74→2/69（Pos 68→63，暴露剩余全是 char 针）；
补字符字面量后 2/74→**1/6**（Pos 全清 -68，project-helper 桶消失；
puny mini 的 @Copy 为 mini 级暴露、全量不可达，hnkTStringCopyRuntime
有消费端无生产端，归 copy-intrinsic 下口）。验证：pos mini 五形态
（拼接针草堆/#9 针/strlit+全局/局部/记录字段/函数内局部）双步 opt PASS；
十一探针回归 9 PASS + puny(@Copy)/cmpgen(@TC.DoContains) 注³³已知挂账；
compiler-pass 58/58；opt 首错推进到 `@TVec.SyncDataPtr`（479600 行，
method-object 口成下一目标）；hygiene pass；git diff --check。 |

³⁶ b4b-i17（本 commit）：**ordinary 成员调用契约实例名优先——SyncDataPtr
口收口，undefined 全表归零（uniq 1→0、total 6→0）**。根因链：内联特化
`specialize TVec<T>.Xxx(...)` 只克隆白名单方法体到实例名、方法符号仍挂
模板名（np_sema_declaration.inc InstantiateGenericType 批量注册）；别名实例
则符号与体都带实例前缀——双路径不对称。语句位隐式 self 调用
（walk_halt_calls.inc :3122 分支）产的 blob 用实例名正确，但
AttachStatementCallExpr 附带的结构化表达式经 TryGetOrdinaryMemberCallContract
按**符号名**解析落模板名 `TVec.SyncDataPtr`；builder ProcessCallRuntime
（np_hir_builder_runtime.inc :81）见 ExprId>0 整体弃 blob 用表达式 →
实例名 define 16 个齐全却无人调用、模板名 call 无 define。修法
（np_sema_codegen.inc +9 行）：ordinary 契约解析中接收者类型名含 '<' 且
`ReceiverTypeName + '.' + MemberName` 下有注册体时改用该实例名。
复现探针：build/m2_mini_tree.pas（uses np_green_tree 拉编译器单元，
8 分钟替代 2 小时全量）。验证：tree mini exit 1→0、@TVec.SyncDataPtr 残留
3→0、双步 opt PASS；十三探针回归 11 PASS + puny(@Copy)/cmpgen(@TC.DoContains)
注³³已知挂账不变；compiler-pass 58/58；全量基线 0/0（本轮 sema 单相
~150 分钟，i17 新增的 LookupProcedureBody 名字扫描疑似有性能代价，
列入 perf 批次首项量化）；hygiene pass；git diff --check。新浮出记录：
opt 首错性质切换——undefined 清零后暴露支配性违规（`$wrt_tmp` alloca 在
try-end 后发射不支配使用块），归 emitter temp-placement 新口（下一目标）。 |

³⁷ 2026-08-23 N5/N6 收口后的 residual 全量复跑（下会话首项挂账销项）：
uniq/total 保持 **0/0**（define=7805 declare=263，buckets/明细空文件），
opt 首错=同一支配性违规家族仅编号位移（`%v8263 = alloca i64` 于
`@RunEnvStatus` try-end 后发射、except 块 `%v8264 = load` 使用，.ll
10024/10031 行）——N5 ir×25+backend.plan 与 N6 toolchain×3+壳层
driver.* 全部迁移零新增残留。历史 TSV 追加 2026-08-23-1704 行。 |

| opt 首错 | `Instruction does not dominate all uses!`（`%v8263 = alloca i64` 等 `$wrt_tmp` 家族 alloca 在 `@RunEnvStatus` 的 `np_try_pop()` 后发射、except 块 `%v8264 = load` 使用不支配（.ll 10024/10031 行）；性质从 undefined 转为支配性违规——undefined uniq/total 已全表清空、buckets/undefined_uniq 明细均为空文件）；上一口为 `@TVec.SyncDataPtr`（已修，注³⁶） | 2026-08-23 全量复跑实测（uniq/total **0/0**；opt 因支配性违规 FAIL 不变，归 emitter temp-placement 新口） |
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
- [x] **B6-GETTID GetCurrentThreadId 裸调归零** ✅（2026-08-17，
      33/49 uniq/total，runtime-decl 桶 GetCurrentThreadId×3 清零，opt 首错
      换人 `@IHasher.Write`）：core 8 处裸调 FPC System 内建
      `GetCurrentThreadId`（stub System 无声明 → residual），7 处 Linux
      生效（msqueue:223 / channel:363 / mem.central:301 /
      mem.allocator.growing:176/197/471；platform.thread:951/956 是
      Windows 分支，Windows 下 stub 有声明，语义正确，不动）。**定点
      探针实证**：FPC Linux 的 `GetCurrentThreadId` = gettid 语义
      （主线程返回 1，非 pthread descriptor 地址）→ 与 core 已有
      `platform_thread_id`（host 层 = `UInt64(UInt32(gettid))`，Linux）语义
      一致。修法：调用点统一改 `platform_thread_id`（与 mem.central:338
      既有「portable thread id」实践一致，符合 owner boundary 不裸用
      FPC System）；msqueue/channel 补 implementation uses
      `nextpas.core.platform.thread`；msqueue/channel 哈希注释原写
      “pthread descriptor addresses, 8MB apart” 与 gettid 小数字实况
      矛盾，改为真实特征描述（奇常数乘法散布小步长）。验证：
      `test_lockfree_msqueue` 20244/20244 过、0 泄漏，探针 34/52→33/49
      稳定，无桶回升。
- [x] **B6-NOINLINE parser 指令表补 noinline，platform.memory 实现区不再截断** ✅
      （2026-08-17，33/49 → 30/43 uniq/total，platform_virtual_* 3 符号
      6 total 清零，**runtime-decl 桶整桶清零**）：platform_virtual_
      reserve/commit/release 有实现（platform.memory.pas:432/453/496）却
      0 define、调用点全 i64 fallback。查证：parser 的 `IsCallingDirective`
      指令表（np_green_tree_parser_impl.inc:210）**无 `noinline`**，而
      platform.memory 的 `procedure platform_secure_zero_memory_barrier;
      noinline;`（249 行）触发**实现区静默截断**——该声明节点无任何
      子节点（连 parameter-list 都没有）、250 行后全部实现（platform_
      secure_zero_memory、platform_aligned_alloc 系列、platform_virtual_*、
      platform_madvise_thp）整个丢失，且**无诊断错误**（parser 不报错
      静默吞）。最小复刻 `procedure foo; noinline; begin…end; function
      bar…` 坐实：foo 零子节点 + bar 整体丢失；指令表补 `noinline` 后
      foo/bar 全恢复。修法：IsCallingDirective 加 `(L = 'noinline')`。
      探针确认：platform_virtual 有 define（reserve/commit/release）且部分
      调用点升级为正确签名（`call ptr @platform_virtual_reserve`）。
      **挂账**：mem.central:88832/97126 等调用点仍是 i64 参数旧形态
      （调用点编码未按 symbol 签名取参），此刻不 undefined（名字匹配
      define 即 resolve），opt 过 IHasher.Write（B2）后下一层类型检查会
      暴露——届时按 B6.5 类 call-site 类型一致性处理。验证：探针
      30/43 稳定，compiler-pass 58/58，hygiene pass，无桶回升。
- [x] **B6-COHORT 祖先链 cohort（method-object 家族：TStream.vmt 表项清零）** ✅
      （2026-08-17，36/51 → 32/45 uniq/total，TStream vmt×6 清零）：子类
      vmt 表引用祖先方法槽（`TFileStream.vmt = [TStream.vmt, …]`），但
      `MarkClassMethodCohort` 只标记被 direct 触达类自身——TStream 的
      virtual 方法（SetPosition/GetSize/SetSize/Read/Write/Seek）无 direct
      Create/Destroy 触达 → Needed=False → 无 define → vmt 表项 undefined。
      修法：cohort 沿祖先链（FindTypeByName → ParentTypeId，深度≤16）全部
      标记，与「类实例化则整族方法可用」语义一致。验证：TStream 家族 6
      uniq 8 total 清零；**挂账**：新浮出 `TCollection.AppendToUnchecked`/
      `Clear`（class virtual 方法被 direct call 且方法体未注册——祖先
      cohort 扩大了可达面后 method-object 家族继续暴露，下口按 class
      virtual dispatch/方法体注册处理）。compiler-pass 58/58，hygiene pass。
- [ ] **B6.5-Double 浮点标量运算编码（opt 首错 @Int 依赖项）**：全 .ll
      0 次 load double / fadd——nextPas 前端从无浮点标量运算编码。
      `Int(pS[i])`（AVX2ArrayFractF64:3047）宿主函数整体畸形（pS[i] 取值
      退化为索引）。需要：double literal → f64 常量、load/store double、
      fadd/fsub/fmul/fdiv/fneg、fcmp、fptosi/sitofp、参数 f64 ABI，
      以及 Int/Trunc/Round/Frac 内置折叠（llvm.trunc.f64 或 runtime
      helper）。**范围=一个功能面，单独立项，不放 B4 装填**。
- [x] **B6.5-Sar 整数移位链 + 指针元素值索引（@SarLongint 1 use）** ✅（本 commit，
      7/11 → 6/10）：SIMD
      标量模板 `Result.i[i] := SarLongint(aSrc[i], count)`（core simd
      scalar.arith.wide，探针经 dispatch 表引入）。三层缺口互相依赖：
      (1) **移位链全缺**——encode/emitter 无 shl/shr/sar token（lexer
      只有 tkShrKeyword），`SarLongint`（FPC 算术右移内建）无识别 →
      残差 `call @SarLongint`；(2) **数值指针（PInt32）索引无值语义**——
      result-fold 口把字符指针索引收窄到 arr_elem_ref（地址，Char 形参
      ptr ABI）后，PInt32[I] 落通用 arrload（$ptr 缺失→基址丢）→ 赋值
      RHS 编码失败静默错编（`F := P[I]` 实测变 `F := I 地址`）；需
      「元素大小感知的 gep+load」；(3) **标量整数参数分配 ptr 槽**——
      参数注册 `TypeMetaSize>0` 分支把非 record 标量（Int32/Integer）
      RegisterClassVar → var-decl-ptr-runtime（.ll `F(I: Int32)` 形参
      ptr）。三件套一起动（sar → `ashr` 指令链 + 数值指针索引元素大小
      编码 + 标量参数槽类型修正），属 B6.5 类型正确性面。
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
