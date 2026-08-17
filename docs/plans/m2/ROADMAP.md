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

## 当前战况（2026-08-17 result-fold 后实测）

| 指标 | 值 | 轨迹 |
|------|-----|------|
| undefined unique | **15** | 305 → 80 (B0) → 79 (B1) → 84 (B3a+对方B2) → 79 (B4) → 78 (B3b) → 64 (B3c) → 60 (B4a) → 54 (B6-atomic) → 54 (B5a-strpos) → 54 (B5b-toml) → 53 (B5c-upcase) → 52 (B5d-ecore) → 60 (B5e 口径扩展¹) → 57 (B5f-intfid) → **42 (2026-08-16 基线) → 38 (B6-EXTDECL 口1) → 34 (B6-EXTDECL 口2) → 33 (B6-GETTID) → 30 (B6-NOINLINE) → 36 (B2-IMT²) → 32 (祖先-cohort³) → 32 (P1-Classes-zero⁴) → 31 (P2-Process-zero⁵) → 29 (A-vcall⁶) → 28 (B-destroy-fallback⁷) → 27 (C-alias⁸) → 24 (D-pointer⁹) → 18 (const-upper¹⁰) → 17 (const-fini¹¹) → 16 (stub-pathsep¹²) → 15 (reexport-fields¹³) → 12 (localtypecast¹⁴) → 11 (result-fold¹⁵)** |
| undefined total | **20** | 1338 → 251 (B0) → 173 (B1) → 166 (B3a+对方B2) → 161 (B4) → 120 (B3b) → 103 (B3c) → 92 (B4a) → 80 (B6-atomic；atomic 桶整桶清零) → 75 (B5a-strpos；Pos 7→2) → 74 (B5b-toml；Pos 2→1) → 72 (B5c-upcase；UpCase 2→0) → 69 (B5d-ecore；ECore.Create 3→0) → 79 (B5e 口径扩展¹) → 75 (B5f-intfid；接口ID 3 符号→0) → **64 (2026-08-16 基线) → 61 (B6-EXTDECL 口1) → 52 (B6-EXTDECL 口2) → 49 (B6-GETTID) → 43 (B6-NOINLINE) → 51 (B2-IMT²) → 45 (祖先-cohort³) → 44 (P2-Process-zero⁵) → 42 (A-vcall⁶) → 41 (B-destroy-fallback⁷) → 39 (C-alias⁸) → 35 (D-pointer⁹) → 25 (const-upper¹⁰) → 22 (const-fini¹¹) → 21 (stub-pathsep¹²) → 20 (reexport-fields¹³) → 16 (localtypecast¹⁴) → 15 (result-fold¹⁵)** |

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
| opt 首错 | `use of undefined value '@Pos'`（.ll 218382 行 `call i64 @Pos(ptr, i64, i64)`）——`declaration.inc` 的 `Pos('<', ArgTypes[I])` 动态数组元素实参错编（haystack 编成 I 索引），strpos 形态修复小口 | 本轮后仍（@Int/@Result 已出列） |
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
