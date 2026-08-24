# compiler/ 现代化重构主文档

状态：**执行中**（本文件是重构的唯一权威来源与完整记录；附录 A/B 为支撑文档）
发起：总控指令「充分模块化、现代化；编译器必须大量复用 nextpas.core；
命名扁平化 `nextpas.xx` 风格全部进 src 目录；架构朝优雅和高性能发展」
worktree：`.worktrees/compiler-system`（lane 分支 `codex/compiler-system`）
创建：2026-08-23　最后更新：2026-08-25（v2.34：值位置 concat 写实参修复——
EmitPlainStringConcatWriteTemp 无 owned-return 门槛分支，WriteLn(P+Q) 族
从 data 指针整数加法退化归正为 np_tstring_concat 临时+write_str_var
（mini_cat2 四形状 A/B/C/D 全对）；v2.33：residual 战役阶段A 续刀——
DotAccess 字段链地址通道双编码器落地（FoldCore 三路由+codegen record
symbol 路由）；两个结构性新发现挂账=overload 契约断点（atomic_* 族
HasOverload 即退致结构化调用无 byref ops）+deref 基语句吞失（bisect 证明
先在，m2_mini_dotref 复现）；
v2.32：字符串全局 24B 内联存储修复——
程序级 string 全局误发 8 字节 ptr 槽而 tstring 运行时按内联 24B 结构读写，
溢出 16 字节踩相邻全局（mc_e 循环变量 I 打 0,0,0,120 且多跑一轮）；
THIRGlobal.IsTStringStorage 标志+发射 %TString zeroinitializer align 8；
rtl np_tstring_concat dst 别名暂存防护（跨模块）；
新挂账精确化=值位置 concat 表达式退化为 data 指针整数加法（mini_cat2）；
v2.31：b4b-i16 追加刀——
ownership context 计数器按值副本不回写修复（六包装器统一
FBlockLabelCounter:=Ctx.BlockLabelCounter），EncodeStrCallArgs 多字面量
实参同名临时互覆消灭，llvm 绑定执行面实证 nest/two concat 全对；
新挂账=stub SysUtils Result[I] 字符索引 llvm 绑定降级恒等
（UpperCase/LowerCase），先在于本批；
v2.30：residual 调用形状清理战役
阶段A 首刀——by-ref 实参地址通道+enum/const 源头折叠落地，IR 实证
atomic_load 标识符类调用点全数 ptr 级修正（含 global_ref）+Cas 五参全
ABI+字面0 消灭；arity 扫描器对类型级修复盲视，A/B 总数持平 169；
v2.29：concat-swap b4b-i16 修复——
四处发射点倒置归一 builder 契约 DisplayName=dst/Operand=左#9右+Reset 清理
范围收敛保住预注册 owned-func 名册+raise 构造临时免尾声 free，
tryenv mini ok len=0→7；v2.28：调用签名一致性战役开局——
arity 感知选重载修复 CAS 个数错配+发射器 strict 计量器 env 门控落地，
缓存 .ll 全量扫描暴露 residual 层 ~148/探针、L3 1893 处错形存量，
tree 首次真执行 exit139 经基线对照证明先于本批；v2.27：llvm 探针 SIGSEGV 归因
完成——opt noreturn 级联源自 core 原子包装种子参数错配，跨模块移交
core lane；v2.26：llvm 链接步骤动态链接器
override 落地——native-link/llvm-link 共用 AppendDynamicLinkerOverrideArg，
tryenv mini 直接执行成功；v2.25：emitter-temp-placement 正确性线
收官——HIR alloca 发射器级入口提升+except handler 变量绑定+E.Message 字符串
ABI 三层修复，mini tryenv 复现双步 opt PASS+运行语义正确；v2.24：P1 刀⑨ 扫描家族收官
（InstantiateGenericType 体查找接刀② 索引+前缀扫机械化）静窗疑似
-6% 但确认腿遇高载窗口待复测+优化平价剖析法落地；v2.23：P1 刀⑧
泛型实例化 O(N²) 清扫落地噪声级如实记零+D22 教训=debug 画像≠release
现实；v2.22：P1 刀⑦
模型/绿树按值访问消除落地 seed 再 -69%（59.1s→17.9/18.2s，今日累计
-91.8%）+gdb 复剖析驱动选靶；v2.21：P1 刀⑥ ResolveTypeIdForOwner 同名链游走落地 seed -73%
（A/B 实证迄今最大单刀）+mini tree 探针 API 漂移修复；
v2.20：P1 刀⑤ 绿树零分配文本 API 落地 seed 累计 -8%；v2.19：seed 子相归因
96%=encode+gdb 剖析解锁+刀④噪声级落地+刀①③ D20 降级；v2.18：P1 刀② 落地
seed -1.5%/-2.4%；
v2.17：residual 全量复跑 0/0 确认+P1 刀②细则补全；
v2.16：D19 门禁修复+N7 清单+P1 侦察；v2.15：N6 落地 66/66 命名收官；
v2.14：N5 落地 63/66；
v2.13：N4 落地+门禁例外登记；v2.12：P0 计时探针落地+相位实测表；
v2.11：N3 落地；v2.9：顶部状态仪表盘+风险编号 R1-R8+验收门精确命令；
v2.8：§3.5 顶尖基准；v2.7：接口立项清单；
v2.6：范式决策；v2.5：诚实局限；v2.4：先例对照）

## 0. 状态仪表盘（每批落地时更新此块）

```
迁移进度  ████████████████  N1-N6 全部✅ │ 66/66 单元+壳层 driver.* │ 九目录散布→src 平铺完成
性能批次  ████▏░░░░░░░░░░░  P0✅ │ P1: 刀⑥✅seed -73%·刀⑦✅seed 再-69%(59.1→17.9/18.2s) │ 今日累计 -91.8%
正确性    residual 0/0 ✅(0823全量复跑)   compiler-pass 58/58 ✅   opt 首错支配性违规已修✅(v2.25 三层修复)   concat-swap b4b-i16 已修✅(v2.29 tryenv len=7)   residual 标识符类 by-ref 调用点地址化 ✅(v2.30·字面0消灭·DotAccess 类挂账)   DotAccess 字段链地址通道 ✅(v2.33 双编码器就绪·overload 契约断点挂账)   字符串全局 24B 内联存储 ✅(v2.32·mc_e 循环变量踩踏根除)   值位置 concat 写实参 ✅(v2.34·mini_cat2 四形状归正)
门禁      contract pass ✅(78名+层位A已激活·8豁免=N7工单)   FPC rebuild ✅   tree mini ✅   tryenv mini 双步 opt+运行 ✅
顶尖差距  冷编译 ~900×→已收敛一个数量级    RSS 1.4GB→目标 ≤400MB     增量:无→目标秒级(§3.5)
下一口    residual 战役阶段A 续刀主靶=overload-aware 结构化调用契约（atomic_* 族 `overload;` 声明使 HasOverload→TryGetDirectCallContract 即退，结构化 shekCall 无 byref 'r' ops 全参值语义——FindSpanOwnerThreadId 类 DotAccess 现场的真正根因）+ deref 基值位置语句吞失修复（m2_mini_dotref 复现）+ SSE2Shift*Raw/Copy/Delete/SpanInit 多形状家族解剖 + L3 1893 存量新缓存复测；阶段B=方法重载坍缩（ENextPasError.CreateFmt 8 形参裸 define）→ strict 计量器归零后常开；llvm 执行面验证 lane（v2.31 挂账余项：stub SysUtils Result[I] 字符索引恒等→UpperCase/LowerCase 失效+mc_c S[I] 读发索引/写退化整串替换，与 tree exit139 同族；值位置 concat 写实参已修✅v2.34）；或 swiss 接线 → P1 刀⑨静窗复测
```

---

## 1. 重构目标（不可妥协项）

| # | 目标 | 度量 |
|---|------|------|
| G1 | 命名统一 `nextpas.compiler.<area>.<topic>` 点分扁平 | 66 单元零 `np_` 残留（contract 门禁断言） |
| G2 | 全部生产单元进 `compiler/src/` 平铺 | 九个散布目录清空 |
| G3 | 充分复用 nextpas.core，禁止重复造轮子 | 绑定矩阵落地；SetLength 手搓数组不再新增 |
| G4 | 模块化分层硬边界 | compiler Ln 只依赖 core ≤Ln；受控例外显式登记 |
| G5 | 高性能 | 全量构建分钟数只降不升；residual 保持 0/0 |
| G6 | 行为零变化（N 批）/ 可测量改进（P 批） | compiler-pass 58/58 恒定 |

**一套代码吃两代福利**：所有绑定都落在 core 上——FPC 创世期 core 优化直接
加速编译器构建；np 自举期 core 的代码生成优化反过来加速自举。飞轮成立，
零二次移植。

### 1.1 非目标（明确出界项）

| 出界项 | 归属 |
|--------|------|
| `rtl/core/` 的 np_ 家族改名（base_types/text_primitives/process/classes/sysutils/allocator…） | rtl lane；compiler 只消费不拥有（D1） |
| core 本体新增能力（如 case-fold 键缓存） | 修 core 本体走 core lane 测试后消费（R6）；不在本 lane 直接改 core |
| MIR pass 语义、emitter 代码形状等行为级改动 | m2 ROADMAP 咬合队列（b4b-i* / temp-placement 口），与本重构并行不混批 |
| stage0 CLI 投影字段、命令面行为 | N6 仅改单元名与路径，不动 CLI 语义 |

## 2. 现状审计基线（2026-08-23 实测）

### 2.0 审计命令复现块（数字纪律：任何数字可由此重跑）

```bash
# core 各家族 uses 计数
grep -rho 'nextpas\.core\.[a-z_.]*' compiler --include='*.pas' --include='*.inc' | sort | uniq -c | sort -rn
# 生产单元分布（迁移进度）
for d in frontend syntax sema lower ir backend toolchain diagnostics targets; do echo "$d: $(ls compiler/$d/*.pas 2>/dev/null | wc -l)"; done; ls compiler/src/*.pas | wc -l
# 手搓动态数组存量
grep -rn 'SetLength' compiler --include='*.pas' --include='*.inc' | wc -l
# 层位与命名契约（§4.3 门禁之一）
scripts/compiler-flat-contract.sh
```

### 2.1 命名与目录（重构前）

三种风格并存：编译器本体 65 个 `np_*` 散布 9 个子目录；stage0 壳 14 个
`nextpas_*`；core 为 `nextpas.core.*` 点分扁平（标杆形态）。
另有 `rtl/core/` 下整个 np_ 家族（base_types/text_primitives/process/classes/
sysutils/allocator 等）——**rtl 层资产，不在本重构范围**（见勘误 D1）。

### 2.2 core 复用审计

| core 模块 | uses 数 | 判定 |
|-----------|---------|------|
| collections.vec / text.conv / mem.intf / path+fs / exception | 40/~66/22/~39/8 | ✅ 主力 |
| collections.hashmap | **3** | ⚠️ 仅两处名索引 |
| compiler.mem（官方 arena 通道，注释明示给 stage0/compiler 用） | **2** | ⚠️ 几乎未接 |
| swiss.i32i32 / swiss.str / smallvec / bitset / deque / multimap / lrucache | **0** | ❌ 闲置 |
| sync.* / async.taskgroup | **0** | ❌ 并行 sema 无底座 |

手搓 SetLength 动态数组 **417 处**。热路径事实：符号/body 名索引已在用
core THashMap（修正早期 O(n²) 判断），但每次查找现场 LowerCase() 分配 +
契约路径残余扫描 + SameText 调用面。
（uses 计数口径：对 compiler 生产代码按 `nextpas.core.<前缀>` grep 聚合，
含子模块展开；`~` 前缀为跨子模块家族合计。）

### 2.3 性能基线

单线程 100% 单核、~3.3 函数体/秒、RSS 1.4 GB、15.6k 函数体；
全量一轮 ~130-155 分钟（FPC 编同一棵树 ~75 秒，差两个数量级）。

**P0 阶段计时实测**（2026-08-23，探针 `nextpas.compiler.frontend.phase_timing`，
env `NEXTPAS_PHASE_TIMING=1`，TSV `/tmp/m2-phase-timing.tsv`；tree mini
`build/m2_mini_tree.pas` 两次运行，方差全部 <2%）：

| 相位 | Run1 | Run2 | 占比（对四相合计 ~301s） |
|------|-----:|-----:|------|
| syntax | 1 ms | 1 ms | ~0% |
| resolution | 4744 ms | 4666 ms | ~1.6% |
| seed（嵌套于 sema） | **235366 ms** | **238748 ms** | **~79%** |
| sema（含 seed） | **296080 ms** | **299292 ms** | **~99%** |
| mir | 0 ms | 0 ms | 0%（NEXTPAS_MIR 路径） |

结论：**瓶颈高度集中——sema 相占 tree mini 全程 ~99%，其中
SeedFunctionBodies 播种独占 ~80%**。P1 索引分配优化的主战场即播种路径；
resolution 的 4.7s 为次要目标；syntax/mir 可忽略。

**P1 刀② 落地实测**（2026-08-23，同协议两轮，轮间方差 seed 0.4%）：
seed **231954/232932 ms**、sema **292387/293084 ms**、resolution
4562/4575 ms。对 P0 基线：seed **-3.4s/-5.8s（-1.5%/-2.4%）**、sema
约 -3~-6s——两轮均低于基线两轮下界，方向一致；幅度与 i17 A/B 实测的
查找机制总开销上界（+4.8s）同量级，归因干净（消除的是两处查找点的
LowerCase 每次调用临时串分配）。

**P1 刀⑤ 落地实测**（2026-08-23，同协议两轮，轮间方差 seed 1.2%，
测量时环境有并发单线程构建·负载 10/44 核）：seed **221592/219036 ms**、
sema **280708/278678 ms**、encode 相 **218.1/215.6 s**。对刀② 状态：
seed **-10.4/-13.9s（-4.5%/-6.0%）**；对 P0 基线累计 **-13.8/-19.7s
（-5.9%/-8.3%）**——迄今最大单刀。GetText 分配风暴假说证实：绿树
`.Text` 每次访问都 Copy() 物化子串，判空与字面量比较占大头。

**P1 刀⑥ 落地实测**（2026-08-24，**A/B 法**：同日同环境 stash 刀⑥+
重建跑基线腿，pop 后跑刀⑥ 腿，llvm 绑定两轮）：

| 腿 | seed | sema |
|----|-----:|-----:|
| 基线（无刀⑥，HEAD=刀⑤ 状态） | 220505 ms | 280129 ms |
| 刀⑥ 两轮 | **57989 / 60035 ms** | **75633 / 77954 ms** |

Δ = seed **-160.5/-162.6s（-72.8%/-73.7%）**、sema 约 **-73%**——
迄今最大单刀（比此前四刀总和还大一个量级）。机制=`ResolveTypeIdForOwner`
四个分支原为全符号表线性扫（每次调用 O(全部符号)，每迭代付 TSemanticSymbol
13 字段按值拷贝含 4 托管串引用计数+多个 SameText），声明处理区每个
字段/参数/变量类型引用都调它；改为 `FirstSymbolIdByName` 同名链游走
O(k)。等价性论证：AddSymbol 以 `LowerCase(Name)` 为键把新符号链入同名链
且此后不改名（mutator 只动 ScopeId/TypeId/ParamCount 等）⇒ 链成员资格
恰为 SameText 名字匹配（标识符词法严格 ASCII ⇒ SameText⟺键相等）；
SymbolId=存储下标+1 ⇒ 链收集后倒序回填=插入序子序列，tie-break 看到的
候选序列逐位不变。**D21 教训（归因包络错误）**：0823 子相归因
「seed 96%=encode」的分母错位——三个子相探针只覆盖 SeedFunctionBodies
内部；相位总 seed 里还有 ~163s 在未探针的导入单元声明注册区，被
「encode 占 96%」结论掩盖，本轮 A/B 直接暴露。教训：子相探针必须先与
相位总量对账再下结论；跨日对比前先跑当日基线腿。

**复剖析第一轮→刀⑦**（2026-08-24，stage0-debug 重建含刀⑥，
tree mini llvm 绑定+每 2s gdb 批采样 49 样本）：叶帧 fpc_copy 26.5%+
fpc_ansistr_assign 14.3%（托管拷贝机器仍主导），**GetItem
(vec.pas:1038 按值记录返回) 单独 14.3%，其调用方归因=SymbolAt 家族
合计 16/49≈33%**——头号 `TypeSymbolForTypeId`(type_check.pas) 全表扫
10 样本、次号 `FindOuterDeclOf`(seed_function_bodies.inc)+ChildAt ~7
样本、零星 GetTypeMeta×3/InstantiateGenericType 等。刀⑦ 即按此选靶：

| 腿 | seed | sema |
|----|-----:|-----:|
| 基线（HEAD=0e32906da 刀⑥ 状态，同日重建） | 59100 ms | 76870 ms |
| 刀⑦ 两轮 | **17903 / 18231 ms** | **36174 / 36191 ms** |

Δ = seed **-69.7%/-69.2%（约 -41s）**、sema **约 -53%（-40.7s）**；
两轮方差 1.8%。encode 子相自身 54s→14.5s——两靶都在编码循环内部，
与剖析归因吻合。**今日累计 seed 220.5s→17.9s = -91.8%**。

**刀⑦ 落地内容**：①`TSemanticModel.SymbolPtr`（PSemanticSymbol 零拷贝
访问器，越界返回 nil）；`TypeSymbolForTypeId` 改指针扫+谓词重排
（TypeId 整数比较前置，SameText 仅对命中者付）——首匹配语义不变。
②绿树 `ChildIndexOf(ANode)` 零拷贝成员探测（镜像 ChildAt 遍历含循环
自孩子跳过；身份=(FOwner,FIndex) 见 =(A,B) 运算符）；`FindOuterDeclOf`
改 `GetPtrUnchecked(BI)^.Decl` 就地取条目+ChildIndexOf——原先每候选
体付整条 TProcedureBodyEntry 托管记录拷贝+每孩子 32B 数据+16B 门面双份
拷贝。遗留靶：GetTypeMeta(TSemanticType 按值)×3 样本、encode 内字符串
构造。

**复剖析第二轮→刀⑧**（2026-08-24，stage0-debug 含刀⑦，24 样本）：画像
趋平——GetItem 残余调用方散点（FunctionAt/SymbolAt/AddConstValue）、
InstantiateGenericType 构造器传播 ~12%、fpc_copy+ansistr_assign 合计
~29%。刀⑧ 靶=InstantiateGenericType 的 O(N²)（外层全表扫嵌套内层全表
扫+循环不变串拼接每迭代重算）与 FindFunctionReturnType 双份记录拷贝：

| 腿 | seed | sema |
|----|-----:|-----:|
| 基线（HEAD=4385294d6 刀⑦ 状态） | 17963 ms | 35960 ms |
| 刀⑧ 两轮 | 18064 / 18036 ms | 35930 / 36015 ms |

**Δ = ±0.6% 以内 = 噪声级，如实记零**（刀④ 先例：改动严格少工作、
全门禁绿、保留）。**D22 教训：debug(-O1 -g) 画像 ≠ release(-O3) 现实**
——SameText/小函数在 release 下被优化内联后，调试版里显形的调用点在
release 中成本骤降；后续选靶应以 release A/B 为最终裁判，debug 剖析
只做候选发现。刀⑧ 落地内容：①构造器传播改同名链候选（倒序收集保持
升序 tie-break）+链式成员探测+AddSymbol 前字段快照（Push 可能 realloc
使指针悬垂）；②字段传播扫 SymbolPtr 化；③FindFunctionReturnType
GetPtrUnchecked 化。

**复剖析第三轮（优化平价法）→刀⑨**（2026-08-24）：D22 后的方法论补全
——构建「release 同参+仅加 `-g`」剖析版（build/stage0-prof，实测比
release 慢 ~65%，比 -O1 -g 版更接近），25 样本画像：GetItem 残余 24%
但调用方**散布六个不同点**（FixupAliasMethodSymbols/GetTypeMeta/
SymbolAt/GetFieldMetaByName/LookupStringConstValue/FunctionAt 各 1）
——按值访问家族到达平坦底部，无单点可削。刀⑨=收官清扫：
①InstantiateGenericType 体查找接刀② 名字索引
（FirstBodyIndexForNameLocal，索引在 Push 处无遗漏注册、缺席=-1，
首条目=最低索引与原线性扫一致）替代残留线性扫（每迭代托管记录拷贝+
拼接重算）；②walk_halt_calls 泛型模板前缀扫提升不变串+就地读。
**实测**：静窗两轮 seed **16790/16770ms、sema 31586/31752ms**，对当日
五点静窗基线带（17.9-18.2s）疑似 **-6.5%/-12%**；但确认基线腿恰遇
core-db lane 并发高载窗口（load≈31，seed 21567/sema 51306ms），
同窗交错 A/B/A（18.5/19.5s vs 18.1s）方差淹没无法解析。**定案=疑似
小幅正收益待静窗复测归档精确数字**；机制严格少工作+复用既有索引，
保留。D23 教训：并行 lane 会话并发构建时（load>30），±10% 级效应
不可测——测量前必查 `uptime` 与 ppcx64 并发，交错法只能救同量级窗口。

**v2.25 emitter-temp-placement 正确性线**（2026-08-24；mini 复现
`build/m2_mini_tryenv.pas`：try/except on E + FailLike(E.Message)）：

| 层 | 缺陷 | 修复 |
|----|------|------|
| 发射器 | 异常发射在 HIR entry 块中段 setjmp 劈分（bb64→try.body），劈点后 hikAlloca 落 try body 不支配 except 块 load（EnsureAlloca 的 FEntryBlockId 提升只保证进首块、不保证函数序言） | EmitFunction 预扫全函数 alloca 渲染序言缓冲，首块标签后冲刷，主扫跳过 hikAlloca |
| SEMA handler | `on E: C do Body` 的 gnkExceptionHandler 子树被当普通语句直走：E 未注册、无 exc_load 绑定、无类过滤 | LowerRuntimeTryExceptStatement 识别 handler 双形状（child0=标识符→类名），注册 runtime var+class var 映射，发 var-decl-ptr-runtime+assign exc_load |
| SEMA 编码 | E.Message 经 EncodeRuntimeIntExpr DotAccess 兜底成 `var E.Message` 整数槽（builder EmitExprVar 对未知点名就地造 alloca+i64 错 ABI） | EncodeExceptionMemberStrTemp：$read 属性→裸字段→F 前缀三级解析（基类 Exception 兜底），物化 tstring 字段加载临时按 strvar (ptr,len) ABI 传参；命中时跳过结构化 ExprId 附加（否则降级 @Cls.Member getter 残余调用） |

**验证**：mini 双步 opt PASS+运行语义正确（fail msg=cfg broken 正确传播；
len=0 为既有 concat-swap 挂账 b4b-i16 新增可运行实证）；十五探针
13 OPT-PASS+cap/cmpgen/puny 已知挂账零新回归；tree mini 双步 opt PASS；
contract pass+rebuild+compiler-pass 58/58+hygiene。
D24 教训：HIR entry 块不是不变量——异常/finally 发射会在块中段劈分标签，
「提升到 FEntryBlockId」≠「函数序言」；支配性保证必须落在发射器结构层，
SEMA 层的块内提升逻辑对劈分不设防。
新挂账：llvm 绑定产物 ELF interpreter=/lib/ld64.so.1（FPC 默认遗留路径，
本 host 无此文件无法直接执行；探针协议只验 opt 从未执行产物故未暴露）——
需 link 计划按 host 补 --dynamic-linker /lib64/ld-linux-x86-64.so.2，
独立工具链 slice。

**v2.27 llvm 探针 SIGSEGV 归因（2026-08-24；诊断完成，修复移交 core lane）**：
cmpmid/tvec/hashmap 直接执行 SIGSEGV（exit 139），gdb 定位
`np_unit_init_nextpas_core_simd` 无尾声跌落下一函数→ret 取栈垃圾跳转。
机器码↔.ll 对拍（直接 llc 正常 vs 构建管线损坏）锁定破坏发生在 **opt -O2**
阶段：`_start` 被推断 noreturn 并删除其后全部主体（main/fini 全没了），
多个函数体删成 `ret undef`。noreturn 级联源头=core 原子包装种子缺陷：
`atomic_compare_exchange_strong$iii` 定义签名 (ptr,ptr,ptr)，而调用点传
`(i64 0, i64 0, i64, i64, i64)`——字面 0 常量+参数个数错配（mangled 重载
解析失败退化为任意形状调用）；opt 内联后 CAS 恒失败路径被证明支配，
raise/unreachable 随之支配全函数。证据：tvec .ll:3631/7948/8718 三处
5 参调用、EnsureBuilt bb240、opt 后 IR `_start #0(noreturn)+unreachable`。
**归属判定=跨模块（core mem/heap 单元种子）**：按 worktree 纪律不本 lane
单改 core，登记移交 core-db lane；compiler lane 可做的防御性后续=
residual 调用参数个数/类型与被调签名一致性检查（encode 层早失败优于
opt 层静默误编译）。D25 教训：双步 opt PASS 只证 IR 结构合法，不证
语义正确——noreturn/unreachable 是合法但致命的传播源，执行验证面
（动态链接器解锁后）必须进探针协议。

**v2.28 调用签名一致性战役开局（2026-08-25）**：v2.27 处方落地+归因修正。

| 项 | 内容 |
|----|------|
| 归因修正 | v2.27「级联源头=core 包装种子」不完整——core 的 5 参重载声明本身合法（nextpas.core.atomic.pas:350+），错配的调用侧退化是编译器缺陷：`EffectiveRuntimeCalleeName` 经 `LookupProcedureBody`=首体选择，无 arity 感知，值位置重载调用一律打向首个注册体的 mangled 名 |
| 修复① arity 感知选重载 | `EffectiveRuntimeCalleeName` 增可选 `AArgCount`（默认 -1=行为逐位不变）；值位置普通调用两处传 `ChildCount-1`；HasOverload 时按 DeclAcceptsArgCount 过滤同名链取首个可接受体，无匹配回退原路径。IR 实证：strong_64 五参调用点从 `$iii`(3 形参) 改打 `$iiipp`(5 形参)，个数对齐 |
| 修复② strict 计量器 | 发射器普通调用路径 arity 对账，`NEXTPAS_EMIT_STRICT_CALLS=1` 时 raise call-signature-mismatch(target,formals,args)；默认关。阳性对照=isep strict 抓 `IsSep formals=1 args=2` exit217；阴性=默认 off exit0（D19 纪律） |
| 存量扫描（战役规模） | 缓存 .ll 全量对账（裸名调用 vs 同文件 define 形参个数）：每 mini ~148 处、puny 26、isep 2、L3 nextpas.ll **1893** 处（Copy 多形状/CloneBackendArray/ArcTan$p/AddRuntimeContract 等）；类型级漂移（ptr/i64/字面0 物化）与点名方法重载坍缩（ENextPasError.CreateFmt 单一 8 形参裸 define vs 多形状调用点）未计 |
| 执行面新证据 | tree mini 首次真执行 exit139（_start 跳栈地址=v2.27 同族特征）；stash 基线对照同样 139 ⇒ **先于本批存在非回归**，同时实证 D25：该探针历来只过双步 opt 未真跑 |

D26 教训：处方落地前先量存量规模——「一致性检查常开」在 148/1893 现状下
会让全部门禁全红，改 env 门控计量器作为战役验收工具；新检查器除阳性对照
（D19）外还须先扫存量定口径。
验证：rebuild pass(426297 行)+compiler-flat-contract pass+compiler-pass
58/58+tree 双步 opt PASS+strict 计量器阳/阴对照+hygiene pass+diff-check
（本批文件）。遗留=阶段A/B 战役（见仪表盘下一口）；core lane 移交条目
收窄为「包装种子 define 形状是否另有 core 侧问题」待 core-db 复核。

**v2.30 residual 调用形状清理战役·阶段A 首刀（2026-08-25）**：v2.28 立项
的第一口落地，字面 0/实参饥饿类根因修复。

| 项 | 内容 |
|----|------|
| 根因① expr-N 实参饥饿 | enum/const 标识符实参走 FoldCore 结构化回退发 `expr N` token；cond-br blob 消费对 lower 失败的 expr 不压栈直接跳过，`EmitExprCall` 仍按声明 Count 弹栈→不足位静默补 0（opt 层看到字面 0 物化的源头） |
| 根因② by-ref 无地址通道 | `var` 形参 define 侧 ABI 期待 ptr 地址，调用侧却发值加载 `var X`——CAS/store 类原子操作拿到值而非地址 |
| 修复① FoldCore 调用点形参元数据 | 值位置参数循环前置 callee formal meta（LookupProcedureBody→gnkParameterList/gnkParameterDecl 逐参 ParamNameIsByRef）；by-ref+标识符实参合并单分支：隐式 self 字段→`var self`+`field_ref N`，其余一律 `varref X`（builder 解析 alloca/var-param 解引/global_ref，与本文件 interlocked 编码器既有形状同构）——局部/参数/全局/字段四类标识符全数地址化 |
| 修复② 语句位置同构 | EncodeCallStatementArgs 同步补 field_ref 与 const-fold 两分支（其 varref 分支此前已有）；该文件现挂并行会话 WIP trace 行，本批未再动它 |
| 微观实证（本批 IR） | AtomicCas64 五参调用=`AtomicCas64(ptr @g_GState, ptr @g_GExpected, i64 %v17, i64 %v18, i64 %v19)` 与 define (ptr,ptr,i64,i64,i64) 全对齐且探针执行 exit0；GetOrd(mo_acq_rel) 调用点 `%v21=add i64 3,0` 序数 3 折叠正确；atomic_load 标识符类调用点 12 处全数 ptr 级（含 `ptr @g_GProcessRouteState` 等 global_ref），字面0 填充消灭；余 2 处值传递=DotAccess gep+offset 链（非裸标识符，阶段A 出界） |
| 计量口径勘误 | 锁定扫描器 A/B（HEAD vs HEAD+slice 同法同输入）：arity 总数 169=169 持平、逐族零 delta——**本刀修复是类型级（操作数次序/序数值/地址化 vs 字面0），arity 扫描器结构性盲视**；strict 计量器同理只对个数负责；上一会话 135→106 曲线在 v2.29 落地后的今日复测不可复现（旧口径未锁定或 v2.29 改道，存疑不裁），战役后续需第二检查器（类型级对账）补盲 |
| 归属勘误 | helpers.inc 两分支随并行会话 v2.29 concat-swap 提交（13e84e60d）搭车落库（共享 worktree 下 git add 未按文件收窄），代码注释带 "(v2.28 campaign)" 锚点可溯；**D28 教训：共享 worktree 并行会话提交必须按文件清单 add，禁止 -A 扫尾** |
| 遗留家族 | DotAccess by-ref 目标（本批实证 2 处 gep+offset 值传递，需字段链寻址）、SSE2Shift*Raw（1 实参 vs 3 形参）、Copy/Delete/SpanInit/RegisterBackend 多 arity 坍缩、ENextPasError.CreateFmt 18/EAllocError.Create 7 等构造族（阶段B 重载坍缩）、L3 1893 基线待新缓存复测 |

验证：rebuild pass+tree 双步 opt PASS+strict 计量器阳性对照仍红（IsSep
formals=1 args=2 exit217）+compiler-pass 58/58+contract pass+casdrift/
enumfold2 探针执行双绿+锁定口径 arity A/B（169=169 持平）+hygiene pass+
diff-check(本批文件)。core-db 移交条目再收窄：core 5 参重载声明合法已证，
调用侧退化根因已修，无需 core 侧动作。

**v2.33 residual 战役·阶段A 续刀：DotAccess 字段链地址通道（2026-08-25）**：
v2.30 挂账的 DotAccess 类首口，双编码器补地址路由+两个结构性新发现挂账。

| 项 | 内容 |
|----|------|
| 修复① FoldCore 字段链三分支 | TryByRefFieldAddressBlob：`P^.F` 解引用形（TryPointerFieldAccess 元数据）与 pointer-var 基→`var B`+`field_ref idx`；record 型基（var-param/local/global）→**`varref B`+`field_ref idx`**——builder varref 对 var-param alloca 单解引发 caller 记录指针（对齐 define 侧 by-ref ABI），record local 推 alloca 地址本身；类型经符号表 FindSymbolByName+SymbolTypeId 解析，零注册表改动。接线于 by-ref 标识符分支之后、const-fold 之前 |
| 修复② 结构化路径 record 基址 | BuildTargetAddressExpr identifier 分支：scalar-fact 失败后增 record-symbol 路由（SymbolTypeId→TypeMetaIsRecord→BuildRecordBaseAddressExpr）——原代码在此硬 Exit(False)，使结构化调用契约的 'r' 实参子构建必败；shekSymbolAddress 经 LowerSymbolAddressExpr 单解引，语义与修复①同构 |
| 实证边界（诚实） | tree atomic_load ptr 级保持 12 处、值传递 2→3 处不变（第三处=并行会话 v2.32 改动后新现现场）；FindSpanOwnerThreadId 两处未翻转——HIR dump 实证其调用以 `expr N` 结构化节点编码，根本不经过 FoldCore/语句位 token 循环，本批两修复对其为「就绪待命」；D20 教训再验证：接线前先实证编码器归属 |
| 新发现① overload 契约断点 | atomic_load 在 core 声明 `overload;` → HasOverload 使 TryGetDirectCallContract 即刻退出 → 结构化 shekCall 无 ParamKinds（'r' 通道全灭）→ 全参值语义。这是 atomic_* 族 DotAccess 站点的真正主根因；下一刀主靶=overload-aware 结构化契约（v2.28 EffectiveRuntimeCalleeName 的 arity 感知同构推广到 ops 推导） |
| 新发现② deref 基语句吞失 | `GLen := Measure(LP^.FVal)` 整句无 IR（连残迹 call 都无）；git stash 二分证明先于本批存在；m2_mini_dotref.pas 探针复现（scratch 未跟踪与 casdrift 同例），挂账下一切片 |
| 遗留家族 | overload-aware 结构化契约（本批①）＞deref 吞失（本批②）＞SSE2Shift*Raw/Copy/Delete/SpanInit 多形状解剖＞构造族阶段B 重载坍缩＞L3 1893 复测 |

验证：rebuild pass+TREE-DUAL-OPT-PASS+strict 阳性对照 exit217+contract
pass+compiler-pass 58/58+casdrift/dotref/enumfold2 三探针 build+执行
exit0+hygiene pass+diff-check(本批两文件)。

**P1 seed 细分归因**（2026-08-23，子相探针 `seed.reach/plan/encode` 接入
`np_sema_seed_function_bodies.inc`；一轮 tree mini）：

| 子相 | 实测 | 占 seed 比 |
|------|------|-----------|
| seed.reach（CollectReachableBodyRoots 可达性预扫） | 399-971 ms | ~0.4% |
| seed.plan（定点 MarkTypedHir+ExpandCallTargets ×3 轮） | 2.1-5.4 s | ~2% |
| **seed.encode（逐体编码排水）** | **234-251 s** | **~96%** |

结论：**播种的 96% 在编码循环内部**——静态侦察锁定的刀③四趟全表扫描
位于 reach/plan，合计 <3%，动态证据将其降级为噪声级。
（**D21 修正（2026-08-24）**：此结论的分母只是 SeedFunctionBodies 内部；
相位总 seed 中 SeedFunctionBodies 之外还有 ~163s 未探针区域（导入单元
声明注册的 ResolveTypeIdForOwner 全表扫），当时被误读为不存在。见刀⑥
实测块。）

**函数级剖析**（2026-08-23，gdb 批采样法解锁：perf 被
kernel.perf_event_paranoid=3 阻塞且探针二进制 strip——以
`build/stage0-debug`（stage0-fpc-flags 全参 `-g -O1` 经脚本形态构建，
110MB not stripped）跑 tree mini、每 2s `gdb -batch -p PID -ex 'bt 6'`
采 135 样本聚合）：叶帧排名 **fpc_copy 38.5%、fpc_ansistr_assign
16.3%（合计 55%=托管类型深拷贝）、TVec.GetItem+vec.pas:1038 约 22%、
SYSTEM MOVE 8.9%**；次帧显示拷贝主要经 GetItem 按值返回触发。真靶=
encode 内字符串构造（AddTypedNode 的 `'var '+name+#10` 格式化拼接、
MangledNameSig/GetParamSignature 级联）与按值记录传递，非表扫描。
**D20 教训：剖析归因必须先映射到相位再选靶**——刀①③系纯静态侦察产物，
被动态证据证伪为噪声级。

**b4b-i17 开销量化**（同输入 A/B：正向=含 i17 的 LookupProcedureBody
实例名扫描，反向=`git apply -R` a3e71253c 的 +9 行后重编译）：

| 口径 | 有 i17（两轮均值） | 无 i17 | i17 开销 |
|------|-----:|-----:|------|
| seed | 237057 ms | 232525 ms | **+4532 ms (~1.9%)** |
| sema 合计 | 297686 ms | 292906 ms | **+4780 ms (~1.6%)** |

i17 名字扫描代价 ~5s/次 tree mini，量级可接受非主要矛盾；反向组 exit=1
同时复现了 i17 修复前行为，交叉验证补丁有效性。

### 2.4 目录形态对照

```
重构前（散布 9 目录）                    重构后（src 平铺）
compiler/                               compiler/
├── frontend/ 14 pas+7 inc              ├── src/            ← 全部 .pas+.inc
├── syntax/    5 pas+11 inc             │     nextpas.compiler.
├── sema/      12 pas+33 inc            │       targets.facts.pas
├── lower/      1 pas+3 inc             │       diagnostics.sink.pas
├── ir/        25 pas+16 inc            │       syntax.lexer.pas
├── backend/    1 pas+1 inc             │       …(66 单元平铺)
├── toolchain/  3 pas+8 inc             ├── tests/
├── diagnostics/ 4 pas+1 inc            ├── nextpas.package.toml
└── targets/    1 pas                   └── README.md
tools/stage0/ 14 nextpas_* + 2 杂项   →  N6 后改 nextpas.driver.*
```

生产单元总数 **66 = 65 个 `np_` 前缀 + 1 个 `nextpas_` 前缀(json_helpers)**。
inc 随宿主迁入不改名，最终与 .pas 同居 src 平铺（按前缀自然分组可读）。
迁移现状（N6 后）：九个散布目录全部清空，compiler 生产单元 66/66 落位 src；
壳层 driver.* 留驻 tools/stage0。实时进度以顶部 §0 仪表盘与
`§2.0 复现块`第二条命令为准。

## 3. 四支柱方案

```
支柱一 扁平命名      66 单元 → compiler/src/ 点分名（N1-N6 机械迁移）
支柱二 复用 core     R1 数据结构只取 core / R2 unit 级 arena /
                     R3 swiss 特化热表 / R4 text.builder 拼接 /
                     R5 并发只走 core 原语 / R6 缺口修 core 本体不开特例
支柱三 分层硬边界    双轴模型：轴 A 编译器内部序 Ln 只依赖 ≤Ln（0 base/
                     diagnostics/targets，1 syntax，2 frontend/sema，
                     3 ir/backend，4 toolchain）；轴 B/C core 能力天花板——
                     L3+ 家族禁入，L2 I/O 族(fs/json/io/process/encoding/
                     compress)须 area 注册(frontend/driver)或显式例外；
                     contract 门禁已实现（覆盖 src 随批扩展）。
                     **2026-08-23 全量审计修正**：原「ir→sema 唯一反向依赖」
                     表述有误——实测上行违规 **6 条**：syntax.green_tree→
                     source_database(L1→L2)、sema 三单元→hir_types/
                     hir_lowering(L2→L3，根因=typed-HIR 在 sema 内构建)、
                     unit_resolver→toolchain_profiles(L2→L4)；连同 L3→L2
                     的 10 条边，sema↔ir 实为**双向耦合**。处置：随 N3-N5
                     迁移单元进门禁射程时逐条登记例外或重构，结构债归
                     N7 手术清单
支柱四 高性能        P0 测量先行 → P1 索引分配 → P2 arena → P3 并行 → P4 增量
```

### 3.1 命名规范细则

- **格式**：`nextpas.compiler.<area>.<topic>`——area 单层、topic 可含下划线，
  全小写；与 core 的 `nextpas.core.<module>.<sub>` 同构；
- **area 词汇表冻结**（九选一 + driver）：`base` / `diagnostics` / `targets`
  / `syntax` / `frontend` / `sema` / `ir`（hir 与 mir 用二级段：
  `ir.hir.*` / `ir.mir.*`）/ `backend` / `toolchain`；stage0 壳层 N6 起用
  `driver`；
- **禁止**：新造 area 同义词（如 `parser`/`codegen`）、缩写（`sem`/`fe`）、
  大写；跨域单元按主要消费方归属，不设 `common`/`misc` 杂货 area；
- **文件名 = 单元名 + `.pas`**，一一对应（FPC/np 双端解析硬约束）。

### 3.2 先例对照（Zig / Rust / Go）

来源：Go 为本机 `/usr/local/go/src/cmd/compile` 一手考察；
Zig（ziglang/zig `src/`）、Rust（rust-lang/rust `compiler/`）为公开仓库
结构。目的不是照搬，而是校验本方案每个决策是否站在三家已验证的形态上。

| 先例事实 | 我们的对应 | 判定 |
|----------|-----------|------|
| **Go**：`cmd/compile/main.go` 薄入口（命令解析+驱动），全部逻辑在 `internal/<pkg>`；`internal/` 即「外部禁入」标记 | `tools/stage0` 薄壳 N6 改 `nextpas.driver.*`；contract 门禁承担 internal 边界角色 | ✅ 方案获背书 |
| **Go**：`internal/` 平铺小包（syntax/types/ir/noder/typecheck/walk/escape/inline/devirtualize/ssa/ssagen/gc…），一包一阶段职责，无九层目录树 | `compiler/src/` 平铺点分单元，area=包语义 | ✅ 同构 |
| **Rust**：`compiler/rustc_<crate>` 前缀即组件身份（rustc_ast/rustc_parse/rustc_hir/rustc_middle/rustc_codegen_llvm…），crate 边界编译期强制 | `nextpas.compiler.<area>` 点分前缀；contract 门禁=编译期边界的 Pascal 等价物 | ✅ 同构 |
| **Rust**：codegen_ssa trait 抽象后端，llvm/cranelift/gcc 可插拔 | emitter 单元按后端隔离（ir.hir.llvm_emitter）；未来多后端沿此缝切开 | ✅ 预留 |
| **Zig**：编译器自宿从早期就是唯一路径（stage1 C++ 已删除），单一 `src/` 树；文件即模块 | np 自举飞轮是本重构第一原则；src 平铺同型 | ✅ 方案获背书 |
| **Go**：SSA pass 表驱动注册（pass 序列数据化，非散落调用） | `np_mir_pass_registry` 已存在；P 批把 MIR pass 接线对齐表驱动形态 | ✅ 待办(P) |
| **Go**：types 与 types2 两套类型检查器长期共存的历史包袱 | 警示：sema 只允许一套类型检查路径；N4 迁移时若发现平行实现须登记而非扩散 | ⚠️ 纪律 |
| **Go**：per-arch 后端目录（amd64/arm64/loong64…×9） | 单目标阶段拒绝复制；多目标时以 targets facts 参数化而非目录倍增 | ❌ 拒绝 |
| **Zig**：文件名大写驼峰（Sema.zig） | 与 core 全小写规范冲突，拒绝；保持点分小写 | ❌ 拒绝 |
| **Rust**：Cargo 式多 crate 构建图 | FPC 单元模型下 unit 即边界，无需构建级再切分；门禁脚本替代 cargo 依赖声明 | ❌ 拒绝 |

**结论**：本方案四支柱在三家先例上均有直接同构物，无孤注；三处显式拒绝
各有理由记录在案。

### 3.3 已知设计局限（诚实清单）与推翻条件

本方案解决的是**命名/目录/依赖边界/core 复用接线**这一层。以下三件事
它刻意没有解决，登记在此防止「文档完善=设计完整」的错觉：

| # | 局限 | 实测事实 | 为何暂缓 | 触发条件 |
|---|------|----------|----------|----------|
| L1 | **inc 巨类分解未立项**——模块化真正深水区 | `TSemanticAnalyzer` 单类横跨 **26,194 行**（pas+33 inc，最大 inc 3,225 行）；`np_hir_builder` 等同型 | 与正确性收口（temp-placement 口）并行重构同一批文件=高冲突高风险；N 批机械迁移先行不加剧 | residual 0/0 稳定且 N6 落地后，立项「N7 巨类分解」独立 lane：按 §3.2 先例把 inc 族升为真实单元边界 |
| L2 | **P3 并行 sema 难度被低估** | `TSemanticModel` 有 **18 个全局 Vec 字段**，符号/契约 ID 是跨 unit 全局索引；unit 分区并行后 ID 合并语义与所有契约引用冲突 | 未做设计 spike 前不许诺扩展比数字 | P3 开工前必须先出 spike：分区 ID 重映射 or 延迟绑定方案二选一，否则 P3 降级为仅 seed 相并行 |
| L3 | **量化收口目标未定** | 当前仅有基线（~130-155 分钟/1.4GB），无目标值 | 目标必须由 P0 实测分布推导，拍脑袋目标会扭曲优化顺序 | P0 交付时同步给出：全量分钟数目标、RSS 目标、P4 后基线刷新预期 |

**推翻条件**（何种证据迫使重设计）：① P0 实测显示瓶颈与全部假设无关
且 swiss/arena 接线后分钟数无改善——则支柱四推倒按实测重排；
② 层位门禁在 N3/N4 大面积 FAIL 且例外超过 10 处——则 area 划分有误，
重新划界；③ np 自举出现点分名机制性硬阻塞——回退命名支柱，保留其余。
三者之外，方向性问题已有先例与数据背书，不接受无证据的方向性翻案。

### 3.4 范式决策：为什么编译器内部不用「一切皆接口」

实测（2026-08-23）：core 重度接口范式——313 个接口声明、45 个 `.intf`
单元（四件套范式）；compiler 内部具体类范式——56 个 `class` 对 8 个
`interface`；但**边界缝合处已在用接口**：IAllocator ×94（内存策略可换，
P2 arena 即其兑现）、IMirOptimizationPass ×17（多实现 pass 表驱动）、
IInterface ×12（COM 基础设施支持用户代码）。考量：

| # | 考量 | 依据 |
|---|------|------|
| 1 | **单实现组件套接口=双倍 API 维护**：TSemanticModel/Analyzer 各只有一个实现，接口只是同一 API 的第二份拷贝；N 批每改一处要同步两份 | N2 实测单批同步 ~90 文件的教训 |
| 2 | **热路径虚分派代价**：sema CPU-bound（3.3 体秒），契约解析调用以百万计；Pascal 接口调用=接口 vtable+方法 vtable 双重间接，阻断内联 | 性能基线 §2.3 |
| 3 | **FPC 接口生命周期是 COM 引用计数**：与 P2 arena 手工所有权天然冲突（引用计数抖动/悬垂）；直接事故记录：b4b-i15 放弃路径——base.pas 自声明 IInterface 致 FPC 继承树分裂（Got IReader, expected IInterface），回滚 | 注³⁴ |
| 4 | **unit 边界已是 Pascal 的模块封装**：Rust 需要 trait+pub(crate) 是因为 crate 才是其边界；Go internal/ 同理。我们的 contract 门禁提供等价强制力 | §3.2 先例对照 |
| 5 | **先例一致**：Go internal 包内部全是具体 struct、接口在消费侧按需定义；Rust trait 集中在可插拔缝（codegen_ssa）；Zig 干脆无接口 | §3.2 |

**接口的立项标准**（出现即加）：① 同一缝出现第二个实现（多后端 emitter
→ 届时立 emitter 接口）；② 所有权/策略需要运行时切换（内存已做）；
③ 测试替身需求无法用单元级测试覆盖；④ **依赖反转**（消费方定义窄视图，
生产方实现——Go 谚语 accept interfaces 的编译器版）。
反例（不加）：仅为「将来可能」的预防性抽象。

#### 3.4.1 编译器内部模块接口立项清单（按缝逐个量化）

| 缝 | 实测表面 | 接口形态 | 归属 | 触发 |
|----|----------|----------|------|------|
| **ir → sema 反向依赖**（唯一 L3→L2 脏边） | 仅 ~15 个方法/**全只读访问器**（SymbolAt/LookupStringConstValue/GetTypeMetaByName/LookupConstValue/HirExprAt…），~77 调用点 | 消费方拥有的窄只读视图（如 IHirModelView），sema 实现之——依赖方向反转，ir.hir.builder 不再 use sema 单元 | N7 巨类分解批次一并做（与 L1 同一手术） | N6 后 |
| emitter 多后端 | 现 LLVM 单实现；MIR-to-native 若立项即第二实现 | codegen_ssa 式后端 trait（Rust 先例） | 新后端立项时 | 未来 |
| diagnostics sink 多形态 | 现 console 单实现 | ISink 双实现（human/json） | 出现第二个消费者需求时 | 条件触发 |
| P3 并行的模型访问面 | 18 全局 Vec 的写路径分布未审计 | 不一定是接口——先出访问面清单再定（spike L2） | P3 spike 交付物之一 | P3 前 |

**纪律**：内部接口一律消费方拥有、窄面只读优先、禁止生产方预先发布胖
接口；每立一个接口必须在本文登记表面测量数据与方法清单一一对应。

### 3.5 顶尖编译器基准与路线（总控目标）

「顶尖」必须可证伪——本节全部数字有实测来源（2026-08-23 本机 44 逻辑核）。

#### 3.5.1 基准锚点

| 维度 | 顶尖参照（实测） | nextpas 现状 | 差距 |
|------|------------------|--------------|------|
| 冷编译同规模源树 | **Go 冷构建 net/http 全依赖树 8.65s**（本机实测） | 全量自举 94k 行 ~130-155 分钟 | ~**900×** |
| 增量/无操作重建 | Go 热缓存 **0.19s**；rustc query 增量 | 无（每次全量） | ∞ |
| 自宿正确性闭环 | Zig/Rust/Go 日常自举+自测 | ✅ 已有（residual 探针 0/0） | 持平 |
| 诊断体验 | rustc spans/labels/suggestions | 行级文本 | 大 |
| 工具链组件复用 | gopls/rust-analyzer 复用前端 | 无 LSP | 未启动 |

#### 3.5.2 量化目标（中间值先行，P0 后校准终值）

| 指标 | 现状 | P1/P2 后 | P3/P4 后 | 顶尖线 |
|------|------|----------|----------|--------|
| 全量自举分钟数 | 130-155 | ≤45 | ≤15 | 同规模 <1min（Go 锚点） |
| 增量无操作重建 | 无 | — | 单元级缓存命中 ≤60s | 秒级/图级查询 |
| 峰值 RSS | 1.4 GB | ≤600 MB | ≤400 MB | — |
| 正确性红线 | cp58/58·residual 0/0 | 恒定 | 恒定 | 自举自证 |

#### 3.5.3 P5+ 地平线批次（P4 之后向顶尖线推进）

| 批 | 内容 | 先例 |
|----|------|------|
| P5 | 诊断现代化：spans/labels/suggestions（诊断 sink 接口化是前置，§3.4.1） | rustc |
| P6 | query 式增量架构 spike：仅当 P4 达标但距秒级仍远时立项 | rustc query/DAG |
| P7 | 工具链组件：LSP/formatter/vet 直接复用 compiler/src 组件（点分命名的红利兑现） | gopls |
| P8 | fuzzing 进门禁：现有 fuzz_* 语料接入常规验证 | rustc fuzz 文化 |

与既有批次关系：N 系列打地基（命名/边界是一切优化的前提）、P0-P4 主战场、
本节 P5+ 地平线。「顶尖」的推进顺序不变：先正确性收口，再性能，再体验。

## 4. 批次计划与验收门

### 4.1 N 系列（机械改名，行为零变化）

| 批 | 内容 | 验收门 | 状态 |
|----|------|--------|------|
| N1 | targets.facts + diagnostics ×4 + sink accessors inc | contract+rebuild+cp58/58+tree mini | ✅ 8d2b94d90 |
| N2 | syntax ×5 + 11 inc + 清理 units 陈旧遮蔽副本 ×19 | 同上 | ✅ a9d8c054c |
| N3 | frontend ×14 | 同上 | ✅ 34986b475 |
| N4 | sema ×12 + ir.hir.lowering | +mini-regress | ✅ 门禁例外两类登记（I/O 族 FsExists/FsStat、sema→ir 上行边 R9）；十三探针回归见提交说明 |
| N5 | ir ×25 + backend.plan | +全量 residual 对比 | ✅ 门禁例外+1（backend.plan I/O 族 FsDir）；全量 residual 对比归 N6 收口轮统一跑（本轮十三探针+tree mini 代替） |
| N6 | toolchain ×3 + stage0 壳层 nextpas.driver.* + 配置收口 | make verify 全量 | ✅ 分两提交：N6a toolchain(2abcd33bb)+N6b 壳层 driver.*/json_helpers 收口。make verify 分解结果：hygiene/contract/incremental-cache/incremental-gate/system-intrinsics 全过；**constructor-typing 与 hir-class-alloc-contract 两红点为既有债**（stash 二分+去 i17 复测证明早于今日全部改动，疑似更早 b4b 行为变更，其脚本 flags 腐烂即久未运行之证）；verify_local 21 处旧布局路径已修至 src；residual 全量补跑已完成（0/0 保持+opt 首错=已知支配性违规不变）✅ |

每批模板：git mv → unit 头改写 → 全仓 uses 同步（含 build 探针源）→
contract 门禁清单扩充 → 清 ppu 重建 → 验收门 → commit。

单批耗时实测参考：N1 ≈ 45 分钟（含全部验证门与 tree mini 8 分钟）；
N2 ≈ 35 分钟。预计 N3-N5 同量级（引用面 frontend 最大 ~60 文件）；
N6 最重（壳层改名 + 三脚本收口 + make verify 全量，预留半天）。

### 4.2 P 系列（性能，测量先行）

| 批 | 内容 | 验收 | 状态 |
|----|------|------|------|
| P0 | 阶段计时探针 + perf 定位 3.3 体秒去向；量化 b4b-i17 的 LookupProcedureBody 开销 | 耗时表进 ROADMAP 新列 | ✅ 相位表+方差 <2%+i17 开销 1.6%；perf top-10 受阻（无 root+二进制 strip），归 P1 启动补 |
| P1 | 残余扫描清零 + LowerCase 分配消除 + swiss 接线 | 分钟数降；residual 0/0 保持 | ◐ 刀②⑤⑥⑦✅（⑥ -73%、⑦ 再 -69%，今日累计 seed 静窗口径 -91.8%）+刀⑧✅噪声级记零（D22）+刀⑨✅疑似-6% 待静窗复测（D23 高载窗口不可测教训）+剖析基建✅；刀①③ D20 降级挂起；emitter-temp-placement 正确性线已转 ✅（v2.25）；下一口=encode 字符串构造（release A/B 裁判）或 swiss 接线 |

**P1 静态侦察（2026-08-23，只读 grep，数字可复现）**：播种热区字符串
操作点共 **140 处**——`np_sema_seed_function_bodies.inc` ×63、
`np_sema_call_binding.inc` ×62、analyzer ×12、overload_lookup ×3；
其中最高频模式是循环内 `SameText(X.Text, 'String'/'AnsiString')`
对**常量字面量**做逐字符大小写折叠（seed 文件内 ≥8 组），P1 首刀即此：
常量比较改廉价精确匹配或预折叠缓存；次刀=THashMap 当前仅 3 个 sema
文件使用，body 名索引扩容接 swiss.str；第三刀=FProcedureBodies 多趟
全表扫描（477/504/517/528 行四趟）合并。THashMap 消费面与 i17 的
LookupProcedureBody 开销（+4.5s/1.9%，§2.3）同源。
**P1 实施细则（2026-08-23 深读定稿，下会话可直接开工）**：

- **刀① 常量折叠廉价化（⬇️ D20 动态降级）**：SameText 本身已是长度
  早退+逐字节表查（text.conv:414），无分配；其调用点散布 reach/plan/
  encode，但 encode 内每次仅数次数十 ns——预期噪声级，**挂起不排期**，
  留作 encode 字符串构造收口后复查。
- **刀② 查找分配消除（✅ 已落地）**：两处查找点改复用折叠缓冲——
  ①`np_sema_overload_analysis.inc` FirstBodyIndexForNameLocal；
  ②`np_sema_overload_helpers.inc` CtxFirstBodyIndexForName（调用绑定
  主热路径，经 TSemaOverloadContext 走同一张 map）。实现=共享
  `FoldAsciiInto(var AScratch: string; const AName: string)` 放
  sema.overload 单元；analyzer 持 `FBodyLookupScratch` 唯一缓冲，
  Context 以 `BodyLookupScratch: PString` 借用（record 局部重建无复用
  价值故用指针；nil 回退 LowerCase 保持旧语义）。**对原细则的偏差**：
  Index 侧不改 scratch——THashMap.AddOrAssign 对键做托管赋值
  （`Bucket.Key := AKey` 引用别名），传可变缓冲会腐化已存键；
  注册期仅 15.6k 次维持局部 Key 不动。
  两条实现级保证：①折叠语义——helper 只折 ASCII `'A'..'Z'`→小写
  （`or $20`），与 text.char 表驱动 ToLower（ccUpper 仅覆盖 A-Z 区间）
  逐位一致，穷举验证长度 1+2 全字节组合 failures=0；Pascal 标识符
  ASCII 限定，键空间零变化=N 行为不变。②scratch 唯一性——字段只经
  SetLength+写入，禁止整体赋值（会共享缓冲触发 CoW）；实测 unique 串
  容量内反复 SetLength 十万次 alloc-delta=0，热身后零堆操作。
  后续演进=core swiss 增 fold-aware 变体（R6 登记，修 core 本体）。
- **刀③ 全表扫描合并（⬇️ D20 动态降级）**：四趟扫描位于 reach/plan
  子相，合计占 seed <3%（§2.3 归因表）；其读改写拷贝已由刀④ 就地化，
  合并状态机不再有可测量收益，**挂起不排期**。
- **刀④ mark/scan 路径去拷贝（✅ 已落地，噪声级）**：seed 文件 17 处
  `Entry := FProcedureBodies[i] … [i] := Entry` 读改写与高频 GetItem
  读改 `GetPtrUnchecked(i)^` 就地访问（MarkClassMethodCohort 全表扫/
  MarkProcedureBodyNeededByName 链/EnqueueBody/MarkIndex/初始种子扫/
  定点入队扫/编码块两处写回）。语义审计：指针取用点与任何 Push 重分配
  之间无交叉；Needed/Queued/Encoded 终态集合不变。实测 seed
  241.0/255.2s——**噪声级**（第二轮含机器抖动，轮间差 14s）：被转换
  路径本就只占 seed <3%，保留改动（严格少拷贝、全门禁绿）但如实记零。
- **刀⑤ encode 文本访问去分配（✅ 已落地，迄今最大单刀）**：根因=
  `TGreenNode.GetText` 每次访问 `Copy()` 物化子串——`X.Text <> ''`
  判空与 `SameText(X.Text,'lit')` 字面量比较都先付一次堆分配。实现=
  绿树新增零分配 API `TextLen`（镜像 GetText 有效性规则）与
  `TextEquals(AValue, AIgnoreCase)`（就地逐字节比较，忽略大小写折
  ASCII A-Z=text.utils.SameText 同表语义；无效节点仅等于空串，边界
  与 GetText 严格一致）。转换：seed 文件 26 处判空→TextLen+5 组
  SameText 字面量→TextEquals（编码循环参数处理/Return 扫描/外层帧
  注册/初始扫描），walk_halt_calls 45 处 SameText→TextEquals（BFS
  扩展路径全量，sed 受限模式 `[A-Za-z_.()0-9]+\.Text` 机械替换后
  修复 `.Text.TextEquals` 双重限定笔误）；call_binding 的 .Text 系
  传参用途不动。**实测 seed 221.6/219.0s 对刀② 232.0/232.9s 即
  -4.5%/-6.0%**。遗留靶：SymbolAt/ResolveTypeIdForOwner 按值记录
  返回（画像次帧 10+9 样本）留待下刀。
- **刀⑥ ResolveTypeIdForOwner 同名链游走（✅ 已落地，A/B 实证迄今最大
  单刀）**：根因=四个分支全符号表线性扫（`for Index:=0 to SymbolCount-1`
  + `SymbolAt(Index)` 按值拷贝+多 SameText），声明处理区每个字段/参数/
  变量类型引用各调一次，O(声明数×全部符号)。实现=`CollectSameNameIdsInsertionOrder`
  （np_sema_overload_types.inc）：`FirstSymbolIdByName` 取同名链头→计数
  一趟+倒序回填一趟得插入序 id 数组（动态数组，非 TVec——TVec 是类，
  局部变量 nil 引用首次解引用即段错误，本批实测教训）；四分支循环改为
  链上迭代，Name 谓词由链成员资格吸收。等价性三要素：①AddSymbol 以
  LowerCase(Name) 键入链、mutator 永不改名；②标识符词法严格 ASCII
  ⇒SameText⟺键相等（np_lexer_helpers.inc IsIdentifierStart）；③
  SymbolId=下标+1⇒插入序可复原，tie-break 序列逐位不变。
  **实测 A/B（同日 stash 对照）：seed 220.5s→58.0/60.0s（-73%）**、
  sema 280.1s→75.6/78.0s——比此前四刀总和大一个量级；D21 归因包络教训
  见 §2.3。附带修复：build/m2_mini_tree.pas 探针 `RootKind = 0` 对现行
  TGreenRootKind 枚举非法（此前靠 gnu 绑定路径的陈旧 ppu 遮蔽假性通过，
  fixture 刷新缓存后暴露）→改 `grkUnknown` 比较。遗留靶：encode 相内部
  字符串构造仍待削（gdb 复采样定位新榜首）。
- **刀⑦ 模型/绿树按值访问消除（✅ 已落地，复剖析驱动）**：选靶=剖析
  第一轮重采样（49 样本）：SymbolAt 家族 33%（头号 TypeSymbolForTypeId
  全表扫）、FindOuterDeclOf+ChildAt ~14%。①`SymbolPtr` 访问器+
  `TypeSymbolForTypeId` 指针扫+谓词重排（TypeId 整数前置；首匹配语义
  不变）；②绿树 `ChildIndexOf` 零拷贝成员探测+`FindOuterDeclOf`
  GetPtrUnchecked 就地取条目（原每候选体付整条 TProcedureBodyEntry
  托管拷贝+每孩子双份记录拷贝）。**实测 A/B（同日 stash 对照）：seed
  59.1s→17.9/18.2s（-69%）、sema 76.9→36.2s（-53%）**，encode 子相
  54→14.5s 证实两靶在编码循环内。今日累计 seed -91.8%。遗留靶：
  GetTypeMeta 按值×3 样本、encode 内字符串构造。
- **刀⑧ 泛型实例化 O(N²) 清扫（✅ 已落地，噪声级如实记零）**：靶=
  InstantiateGenericType 构造器传播的外层全表扫嵌套内层全表扫+循环
  不变串拼接重算、FindFunctionReturnType 双份记录拷贝。实现=同名链
  候选（倒序收集保持升序 tie-break）+链式成员探测+AddSymbol 前字段
  快照（Push 可能 realloc 悬垂指针）+SymbolPtr/GetPtrUnchecked 就地化。
  **实测 ±0.6% 噪声级**。**D22 教训：debug(-O1) 画像≠release(-O3)
  现实**——调试版显形的 SameText 类调用点在 release 被优化内联；
  后续选靶以 release A/B 为最终裁判，debug 剖析只做候选发现。
- **度量协议**：每刀落地后 `NEXTPAS_PHASE_TIMING=1` tree mini 两轮，
  seed 相对 §2.3 基线 235s/238s 对比；验收=总分钟数降+residual 0/0
  保持+十三探针零新回归。（D21 补充：跨日对比先跑当日基线腿；子相
  探针数字须与相位总量对账。）
| P2 | sema/HIR 接 compiler.mem UnitScope/SessionScope | RSS 显著降 | ⬜ |
| P3 | 单元级并行 sema（parallel_scheduler+sync.waitgroup） | **前置：分区 ID 语义设计 spike（L2）**；通过后端到端 ≥2×（44 逻辑核，seed 相目标近线性） | ⬜ 受 L2 约束 |
| P4 | backend cache 单元级复用 | 基线刷新脱离 2 小时级 | ⬜ |

节奏：N1→N2→**P0**→N3→N4→P1→N5→P2→N6→P3→P4（各阶段量化目标见 §3.5，
P5+ 地平线批次见 §3.5.3）。

### 4.2.1 P0 阶段计时探针（已落地 2026-08-23）

- **实现**：新单元 `nextpas.compiler.frontend.phase_timing`（env
  `NEXTPAS_PHASE_TIMING=1/true/on` 门控，`PhaseBegin/PhaseEnd` 名字匹配
  栈式嵌套，每 PhaseEnd 追加一行 TSV 到 `/tmp/m2-phase-timing.tsv`，
  Append/Rewrite 回退沿用 SemaTrace 冷路径模式；默认关=每次边界一次布尔判断）；
- **实际打点**：`syntax`（AnalyzeSyntax 全程）、`resolution`
  （ResolveUnits 全程）、`sema`（AnalyzeSemantics 全程）、`seed`
  （SeedFunctionBodies，嵌套于 sema）、`mir`（LowerToMir）——五处接线于
  `np_compilation_session_pipeline.inc` 与 `np_sema_seed_foreign_procedures.inc`；
- **与原设计的偏差**：lex/parse 合并为 syntax 单相；sema-per-unit、
  hir-build、emit-llvm 细分打点未做（相位级答案已定位主战场，细分留待
  P1 需要时加）；opt -O2/verify 尾部仍由 residual 脚本计时；
- **交付物**：①相位占比表→§2.3+ROADMAP ✅；②perf top-10 热函数——**受阻**：
  `perf_event_paranoid≥2` 无 root + 探针二进制 strip 无符号；解法归
  P1 启动时处理（stage0 flags 加 `-g` 重链或 sysctl 放宽）；
  ③i17 开销 A/B ✅（反向补丁 a3e71253c 实测 +4.8s/~1.6%，见 §2.3）；
- **验收**：数字可复现达成（同输入两轮偏差全部 <2% <10% 阈值）。

### 4.2.2 N7 结构债手术清单（D19 修复后的 8 条实测上行边）

| # | 边 | 根因 | 手术方向 |
|---|-----|------|----------|
| 1-3 | sema.analyzer / sema.semantic_model / sema.string_ownership → ir | typed-HIR 在 sema 内构建（历史设计） | typed-HIR 构建职责迁 ir 层，sema 只产出语义事实 |
| 4 | frontend.compilation_session → ir | 会话直接持有 HIR/MIR 全流程对象 | 编排下沉 driver 或引入阶段结果接口 |
| 5 | frontend.compilation_session → backend | 同上（plan 对象） | 同 4 |
| 6-7 | frontend.compilation_session / frontend.unit_resolver → toolchain | session 直连 runner；resolver 内联 profile 校验 | 校验上移编排层/resolver 回调注入 |
| 8 | syntax.green_tree → frontend | green_tree 消费 source_database 快照接口 | 快照接口下移 L1 或依赖反转 |

豁免即工单：`exempt_layer_a` 白名单每删一条=一条手术完成；
全部清零时轴 A 检查零豁免运行。

### 4.3 验收门定义（每批必过）

```bash
scripts/compiler-flat-contract.sh          # 旧名残留=0；禁入 core 家族=0；层位双轴
make rebuild-compiler                      # FPC 创世构建
make test TEST_FILTER=compiler-pass        # fixtures 58/58
# np 自举解析（完整命令，探针需先 command install -m 0755 build/stage0-bootstrap/nextpas ./nextpas-m2-l3-probe 刷新）:
rm -f .nextpas/cache/backend/linux-x86_64/m2_mini_tree.ll
./nextpas-m2-l3-probe build build/m2_mini_tree.pas --target linux-x86_64 \
  --toolchain-binding linux-x86_64-to-linux-x86_64-llvm --workspace "$PWD" \
  --out-dir /tmp/m2-nX-tree
opt -O2 .nextpas/cache/backend/linux-x86_64/m2_mini_tree.ll -o /tmp/t.bc \
  && opt -passes=verify /tmp/t.bc -o /dev/null && echo TREE-DUAL-OPT-PASS
git diff --check && make hygiene
# N4+: mini-regress 13 探针；N5: 全量 residual 对比；N6: make verify
```

## 5. 完整映射表（66 单元；✅=已落地）

生产单元总计 **66**（65 个 `np_` 前缀 + json_helpers）；
已落地 **66/66**（N1-N6）。src 现状：67 pas + 71 inc
（含 phase_timing 探针单元，不计入 66 生产单元口径）；stage0 壳层 12 单元
改 nextpas.driver.{command,projection}.* 留驻 tools/stage0，json_helpers 双胞胎已收口。

### 已完成 ✅（N1-N6，66 单元 + 79 inc）

| 新名 | 原位置 | 批 |
|------|--------|----|
| nextpas.compiler.targets.facts | targets/np_target_facts | N1 |
| nextpas.compiler.diagnostics.sink | diagnostics/np_diagnostics_sink | N1 |
| nextpas.compiler.diagnostics.enhanced | diagnostics/np_diagnostics_enhanced | N1 |
| nextpas.compiler.diagnostics.json | diagnostics/np_diagnostics_json | N1 |
| nextpas.compiler.diagnostics.json_helpers | diagnostics/nextpas_json_helpers | N1 |
| nextpas.compiler.syntax.lexer | syntax/np_lexer | N2 |
| nextpas.compiler.syntax.green_tree | syntax/np_green_tree | N2 |
| nextpas.compiler.syntax.preprocessor | syntax/np_preprocessor | N2 |
| nextpas.compiler.syntax.ast_facade | syntax/np_ast_facade | N2 |
| nextpas.compiler.syntax.error_recovery | syntax/np_error_recovery | N2 |
| nextpas.compiler.frontend.source_database | frontend/np_source_database | N3 |
| nextpas.compiler.frontend.unit_graph | frontend/np_unit_graph | N3 |
| nextpas.compiler.frontend.unit_resolver | frontend/np_unit_resolver | N3 |
| nextpas.compiler.frontend.compilation_session | frontend/np_compilation_session | N3 |
| nextpas.compiler.frontend.workspace_model | frontend/np_workspace_model | N3 |
| nextpas.compiler.frontend.symbol_cache | frontend/np_symbol_cache | N3 |
| nextpas.compiler.frontend.query_database | frontend/np_query_database | N3 |
| nextpas.compiler.frontend.package_manifest | frontend/np_package_manifest | N3 |
| nextpas.compiler.frontend.package_lock | frontend/np_package_lock | N3 |
| nextpas.compiler.frontend.package_workflow | frontend/np_package_workflow | N3 |
| nextpas.compiler.frontend.incremental_cache | frontend/np_incremental_cache | N3 |
| nextpas.compiler.frontend.file_change_detector | frontend/np_file_change_detector | N3 |
| nextpas.compiler.frontend.parallel_scheduler | frontend/np_parallel_scheduler | N3 |
| nextpas.compiler.frontend.compiler_phase | frontend/np_compiler_phase | N3 |
| nextpas.compiler.sema.semantic_model | sema/np_semantic_model | N4 |
| nextpas.compiler.sema.analyzer | sema/np_semantic_analyzer | N4 |
| nextpas.compiler.sema.type_check | sema/np_sema_type_check | N4 |
| nextpas.compiler.sema.overload | sema/np_sema_overload | N4 |
| nextpas.compiler.sema.builtins | sema/np_sema_builtins | N4 |
| nextpas.compiler.sema.name_set | sema/np_sema_name_set | N4 |
| nextpas.compiler.sema.runtime_vars | sema/np_sema_runtime_vars | N4 |
| nextpas.compiler.sema.string_ownership | sema/np_sema_string_ownership | N4 |
| nextpas.compiler.sema.field_meta_vec | sema/np_semantic_field_meta_vec | N4 |
| nextpas.compiler.sema.interface_slot_vec | sema/np_semantic_interface_slot_vec | N4 |
| nextpas.compiler.sema.property_meta_vec | sema/np_semantic_property_meta_vec | N4 |
| nextpas.compiler.sema.vmt_slot_vec | sema/np_semantic_vmt_slot_vec | N4 |
| nextpas.compiler.ir.hir.lowering | lower/np_hir_lowering | N4 |
| nextpas.compiler.ir.hir.types | ir/np_hir_types | N5 |
| nextpas.compiler.ir.hir.model | ir/np_hir_model | N5 |
| nextpas.compiler.ir.hir.builder | ir/np_hir_builder | N5 |
| nextpas.compiler.ir.hir.printer | ir/np_hir_printer | N5 |
| nextpas.compiler.ir.hir.verifier | ir/np_hir_verifier | N5 |
| nextpas.compiler.ir.hir.to_mir | ir/np_hir_to_mir | N5 |
| nextpas.compiler.ir.hir.llvm_emitter | ir/np_hir_llvm_emitter | N5 |
| nextpas.compiler.ir.system_contracts | ir/np_system_contracts | N5 |
| nextpas.compiler.ir.mir.model | ir/np_mir_model | N5 |
| nextpas.compiler.ir.mir.optimize | ir/np_mir_optimize | N5 |
| nextpas.compiler.ir.mir.opt_level | ir/np_mir_opt_level | N5 |
| nextpas.compiler.ir.mir.pass.registry | ir/np_mir_pass_registry | N5 |
| nextpas.compiler.ir.mir.pass.constfold | ir/np_mir_pass_constfold | N5 |
| nextpas.compiler.ir.mir.pass.cse | ir/np_mir_pass_cse | N5 |
| nextpas.compiler.ir.mir.pass.dce | ir/np_mir_pass_dce | N5 |
| nextpas.compiler.ir.mir.pass.deadarg | ir/np_mir_pass_deadarg | N5 |
| nextpas.compiler.ir.mir.pass.devirt | ir/np_mir_pass_devirt | N5 |
| nextpas.compiler.ir.mir.pass.escape | ir/np_mir_pass_escape | N5 |
| nextpas.compiler.ir.mir.pass.inline_heuristic | ir/np_mir_pass_inline_heuristic | N5 |
| nextpas.compiler.ir.mir.pass.inline | ir/np_mir_pass_inline | N5 |
| nextpas.compiler.ir.mir.pass.licm | ir/np_mir_pass_licm | N5 |
| nextpas.compiler.ir.mir.pass.strength_red | ir/np_mir_pass_strength_red | N5 |
| nextpas.compiler.ir.mir.pass.tailcall | ir/np_mir_pass_tailcall | N5 |
| nextpas.compiler.ir.mir.pass.vectorize | ir/np_mir_pass_vectorize | N5 |
| nextpas.compiler.ir.mir.to_llvm | ir/np_mir_to_llvm | N5 |
| nextpas.compiler.backend.plan | backend/np_backend_plan | N5 |
| nextpas.compiler.toolchain.plan | toolchain/np_toolchain_plan | N6 |
| nextpas.compiler.toolchain.profiles | toolchain/np_toolchain_profiles | N6 |
| nextpas.compiler.toolchain.runner | toolchain/np_toolchain_runner | N6 |

inc 随宿主迁入不改名：syntax 家族 ×11、sink accessors ×1、frontend ×7、
sema 家族 ×33、hir_lowering 家族 ×3、ir 家族 ×15、backend accessors ×1。

### 壳层改名（N6b，tools/stage0 留驻）

nextpas_command_{build,doctor,envelope,env,pkg,query,test} →
nextpas.driver.command.*；nextpas_projection_{types,context,json,text} →
nextpas.driver.projection.*；target_config → nextpas.driver.target_config；
nextpas_json_helpers 双胞胎删除（与 src 版逐行一致），消费方统一改用
nextpas.compiler.diagnostics.json_helpers；入口 nextpas.pas 名称不变。

inc 随宿主迁入不改名（syntax ×11 / sink accessors ×1 / frontend ×7 /
sema ×33 / hir_lowering ×3 / ir ×15 / backend ×1 / toolchain ×8 已随各批迁入）。

## 6. 执行台账（发现·决策·勘误）

| # | 批次 | 记录 |
|---|------|------|
| D1 | N1 | 勘误：np_base_types 在 rtl/core/base/，属 rtl 层资产（同域还有 np_text_primitives/process/classes/sysutils/allocator 家族），移出本映射表归 rtl lane |
| D2 | N1 | stage0 与 diagnostics 存在同内容 nextpas_json_helpers 双胞胎；壳层暂留旧名吃本地副本，N6 收口 |
| D3 | N1 | contract 门禁首跑抓到 Pos('nextpas.core.crypto',…) 字符串字面量误报——门禁改为剥引号后再匹配 |
| D4 | N2 | units/linux-x86_64/ 19 个被跟踪的陈旧 np_* 快照（历史会话手动 cp，无生成无消费脚本）在 np 解析 target-installed 域中遮蔽正主并拖断已改名依赖链（nextpas_json_helpers not found 根因）；删除并随 N2 提交留痕。build/ 探针源加入每批同步范围 |
| D5 | N2 | np 自举对点分名的解析经 tree mini 实证成立（exit0+双步 opt PASS），N1 时已首次验证 |
| D6 | 文档 | 本主文档建立并取代 flat-namespace v2 成单一权威（v2 冻结）；审查轮修正：G1/支柱一计数 65→66、补非目标 §1.1、P3 基线注明 44 逻辑核、层位断言缺口入风险册 R8 |
| D7 | 审查轮 | R8 落地：contract 门禁新增双轴层位检查——轴 A 编译器内部序（src 点分名推断层）、轴 B/C core I/O 能力注册制；实现时发现原「compiler Ln→core ≤Ln」刚性耦合被现实推翻（diagnostics 用 text/collections、preprocessor 用 fs），改为解耦模型并登记首个例外 syntax.preprocessor(fs)。门禁一次通过 |
| D8 | 总控指令 | 增补 §3.2 先例对照（Zig/Rust/Go）：Go 本机一手考察（main.go 薄入口+internal 平铺包），Zig/Rust 公开结构；四支柱全部获得先例同构背书，三处显式拒绝（per-arch 目录复制/驼峰文件名/多 crate 构建切分）记录在案；新增一条纪律——sema 禁止平行类型检查路径扩散（Go types/types2 包袱教训） |
| D9 | 诚实评估轮 | 增补 §3.3 已知设计局限与推翻条件：L1 inc 巨类（TSemanticAnalyzer 26,194 行实测）分解未立项、L2 P3 并行的 18 个全局 Vec ID 合并语义难题（P3 加 spike 前置）、L3 量化收口目标待 P0 推导；明确三条推翻条件防止无证据翻案，也防止文档完善被误当设计完整 |
| D10 | 总控问询 | 增补 §3.4 范式决策：compiler 内部具体类+边界接口的考量五条（单实现双倍维护/热路径双间接/COM 引用计数与 arena 冲突含 b4b-i15 事故引用/unit 即封装边界/先例一致）；接口立项三标准（第二实现出现/策略运行时切换/测试替身），反例=预防性抽象 |
| D11 | 总控追问 | §3.4 增补立项标准④依赖反转+§3.4.1 内部模块接口立项清单：ir→sema 缝实测仅 ~15 方法全只读访问器/~77 调用点，消费方窄视图可反转唯一脏边，归 N7 与巨类分解同台手术；emitter 后端/sink 双形态/P3 访问面三条按条件触发；纪律=消费方拥有·窄面只读·禁胖接口·每接口登记测量数据 |
| D12 | 总控目标 | 增补 §3.5 顶尖编译器基准与路线：Go 锚点本机一手实测（net/http 冷 8.65s/热 0.19s）对比全量自举 ~900× 差距；量化目标表（分钟数 130-155→≤45→≤15、RSS→≤600MB→≤400MB、正确性红线恒定）；P5+ 地平线批次（诊断现代化/query spike/LSP 工具链/fuzz 进门禁）；顶尖定义可证伪——每个数字附测量方法 |
| D13 | 总控确认轮 | 内部模块化全量审计（127 条内部依赖边）：推翻「ir→sema 唯一反向依赖」旧表述——实测上行违规 6 条+sema↔ir 双向耦合 14 边；根因=typed-HIR 在 sema 内构建（架构级信号：HIR 构建职责可能本应在 ir 层，归 N7 裁决）；意外发现 syntax.green_tree 反向依赖 frontend.source_database、unit_resolver 依赖 toolchain_profiles；处置入 R9：N3-N5 每批验收门必须处置进门禁射程的新增 FAIL |
| D14 | N3 | 工具教训：zsh 不对裸变量做字段分词——N3 首次用 `$files` 变量传文件清单导致 sed 整串当单文件名、清扫大面积空转（残留 90）；N1/N2 的内联 `$(grep -rl …)` 恰好可分词故未暴露。修复=回归内联模式，残留清零。后续批次统一内联或 `${=var}` |
| D15 | P0 | 工具教训：探针副本陈旧伪装回归——A/B 实测后恢复 i17 并 rebuild 了 build/stage0-bootstrap/nextpas，但忘记重拷 `./nextpas-m2-l3-probe`，收尾 tree mini 用了无-i17 的 B 组二进制报 SyncDataPtr undefined exit 1。鉴别=源码 diff 干净+重建后刷新探针即 PASS。纪律：**每次 rebuild 后凡跑 mini 必先重拷探针**（§4.3 命令块已含此步，执行时不可跳） |
| D16 | N4 | 工具教训：点分单元的磁盘文件名必须与 unit 名一致——N4 首轮只 git mv 目录未改文件名（np_semantic_model.pas 内声明 nextpas.compiler.sema.semantic_model），FPC 按单元名搜文件直接 Fatal Can't find。N1-N3 未暴露因当时 mv 与改名一步完成。纪律：**迁移=目录+文件名+unit 头三件齐改** |
| D17 | N6 | 工具教训：文档批量编辑脚本变量重赋值截断整文档——python heredoc 中误写 `s=end_marker.replace(...)` 把全文覆盖成单行落盘。恢复=git restore 回 HEAD（提交纪律的价值实证）；重做改用**先写 /tmp 副本+wc 行数+抽查再 cp 落盘**。附带教训：门禁 ` name ` 模式对点分新名后缀段误报（target_config ⊂ nextpas.driver.target_config），已加 `(^|[^a-z_.])` 前缀卫兵 |
| D18 | N6 | 流程教训：make verify 长期未进批次验收链导致三重腐烂——compiler/tests 五脚本 -Fu 缺 src、verify_local 21 处硬编码旧布局路径、两个契约红点（constructor-typing/class-alloc）带病存续无人知。修复=脚本路径全量接 src；红点经 stash 二分+去 i17 复测归档为既有债转 m2 队列。纪律建议：**每批验收链至少含一个 make verify 组件轮换**，防收口时集中爆雷 |
| D19 | N6 收口后 | 门禁重大缺陷：轴 A 层位检查自诞生起从未生效——dep 提取正则把点分名截断在族段(nextpas.compiler.frontend)，而 layer_of 模式要求族后有字面点号(frontend.*)，两者错位致检查恒跳过；且旧豁免的 unit\|dep 复合 case 写法本身永不命中(双保险失效)。修复=layer_of 追加点号+嵌套白名单 exempt_layer_a。修复后首跑即现形 **8 条真实上行违规**，与 R9 台账完全吻合(清单准、检查瞎)。教训：**新检查器上线必须先验证它能红**——用已知违例做阳性对照 |

## 7. 风险登记册

| 风险 | 对策 | 状态 |
|------|------|------|
| R1 FPC dotted 解析 | core/src 全量背书 | ✅ 关闭 |
| R2 np 自举解析新名 | tree mini 每批实证 | ✅ 机制关闭，逐批复跑 |
| R3 漏改 uses | 旧名 grep 清零 + contract 门禁 | 运行中 |
| R4 半途不可构建态 | 批内一次性完成，commit 即可构建态 | 运行中 |
| R5 P 批行为变化 | residual 0/0 保持 + 测量先行 | 待 P0 |
| R6 arena 悬垂指针 | 只接管树状所有权对象；leak_check 抽检 | 待 P2 |
| R7 并行破坏模型不变量 | 写入面审计 + 每 unit 独立 arena 合并（并入 L2 spike） | 待 P3 |
| R7b rtl lane 的 np_ 家族与本方案冲突 | rtl 改名归 rtl lane；compiler 只消费不拥有 | 监控 |
| R8 分层断言缺口 | 双轴层位门禁（轴 A 内部序+轴 B/C I/O 注册制） | ✅ 关闭（D7）；原刚性 Ln→core≤Ln 模型被现实推翻已记档 |
| R9 编译器内部结构债：6 条上行违规边（green_tree→source_database、sema×3→hir_types/hir_lowering、unit_resolver→toolchain_profiles）+ sema↔ir 双向耦合 14 边 | 门禁现仅覆盖 src 已迁单元；N3-N5 迁移把违规单元带进射程时，每批验收门必须处置新增 FAIL（登记例外或重构），全部清零归 N7 手术；ir→sema 窄视图接口（§3.4.1）是反转手段之一 | **开放**——全量依赖审计 2026-08-23 实测（D13） |

## 8. 决策日志

| 日期 | 决策 | 依据 |
|------|------|------|
| 2026-08-23 | 四支柱范围全立项，节奏按 §4.2 交错 | 总控指令 |
| 2026-08-23 | inc 不改名随宿主迁入 | 收益/diff 权衡 |
| 2026-08-23 | stage0 壳层留 tools/stage0 改 nextpas.driver.*（N6） | 默认项未被推翻 |
| 2026-08-23 | np_system_contracts 归 ir.system_contracts | 与消费方一致 |
| 2026-08-23 | units 陈旧副本删除属迁移正当范围 | D4 证据链 |
| 2026-08-23 | json_helpers 双胞胎：壳层留旧名吃本地副本，src 版为点分正名，N6 二选一收口 | D2 |
| 2026-08-23 | build/ 探针源纳入每批 uses 同步范围 | D4 故障教训 |
| 2026-08-23 | 验收证据持久化载体 = 批次 commit message（关键数字必须写入），/tmp 日志视为易失 | 数字纪律 |

## 9. 回滚策略

每批独立 commit、行为零变化、验证门齐全——回滚自最新批次**向前逐个
revert**（后批引用前批新名，逆序才能保持每步可构建）；N 批间无交叉依赖
（自底向上顺序仅保证 uses 引用单调收敛）。P 批引入运行时行为前必须先落
P0 基线数字，回滚判据客观化。

### 9.1 版本历史

| 版本 | commit | 内容 |
|------|--------|------|
| v1 | cc9c7eef5 | flat-namespace 方案 v2（四支柱初版，现附录 B 冻结） |
| — | dabb4cb10 | 附录 A：core 复用绑定矩阵 |
| v2 | c6145180f | 本主文档建立：十章结构+执行台账 D1-D5 |
| v2.1 | a9fdac52d | 目录对照树/命名细则/映射全表/P0 草案/维护规则；计数修正 66=10+56 |
| v2.2 | 5f2c2808a | 审查轮：非目标 §1.1、耗时参考、P3 基线 44 核、台账 D6、风险 R8、决策日志补全、回滚措辞精确化 |
| v2.3 | 7a696feb7 | R8 落地为双轴层位门禁（轴 A 内部序/轴 B/C I/O 注册制，D7 含模型修正依据）；§2.0 审计命令复现块；支柱三描述同步 |
| v2.4 | 1ecbcd74e | 总控指令：增补 §3.2 先例对照（Zig/Rust/Go），四支柱获先例背书+三拒绝项+sema 单类型检查路径纪律；台账 D8 |
| v2.5 | 2ceee73b9 | 诚实评估轮：新增 §3.3 已知设计局限（L1 巨类 26,194 行实测/L2 并行 ID 难题/L3 目标待 P0）与三条推翻条件；P3 加 spike 前置；台账 D9——回答「方案是否要推翻」：方向不推翻，局限如实入档 |
| v2.6 | 2f2df17c4 | 总控问询：新增 §3.4 范式决策（为什么编译器内部不用一切皆接口——五考量+接口立项三标准）；台账 D10 |
| v2.7 | 69b25104b | 总控追问：§3.4 立项标准④依赖反转+§3.4.1 内部模块接口立项清单（ir→sema 缝量化 ~15 只读方法/~77 调用点归 N7；emitter/sink/P3 访问面条件触发）；纪律四条；台账 D11 |
| v2.8 | 80b8575ac | 总控目标：新增 §3.5 顶尖编译器基准与路线——Go 锚点一手实测（冷 8.65s/热 0.19s，~900× 差距锚定）、量化目标表、P5+ 地平线批次（诊断/查询式增量/LSP/fuzz）；台账 D12 |
| v2.9 | e32964a74 | 可用性收尾轮：§0 顶部状态仪表盘（每批更新）、风险册编号 R1-R7b-R8、§4.3 验收门精确复现命令（tree mini 全命令）、§2.4 迁移现状标注——此后文档冻结进执行节奏，边际工作转向 N3/P0 |
| v2.10 | 326585e07 | 总控确认轮：内部模块化全量依赖审计（127 边）——推翻「唯一反向依赖」旧表述，实测 6 条上行违规+sema↔ir 双向耦合；R9 结构债立项；支柱三修正；N3-N5 验收门加 FAIL 处置要求；台账 D13。回答「模块化是否足够好」：及格但未达顶尖，结构债已全部登记在案 |
| v2.11 | 1440adc69 | N3 落地：frontend 14 单元+7 inc 迁入 src（累计 24/66）；仪表盘刷新；台账 D14 记 zsh 分词工具教训 |
| v2.12 | ba84edf37 | P0 落地+N3 收尾（门禁扩至 23 名+漏网改名 21 处，05ef72669）：phase_timing 探针五相接线；§2.3 实测相位表——tree mini sema 占 99%/播种占 80%，i17 开销 +4.8s(1.6%) 非主要矛盾；perf top-10 受阻登记归 P1；仪表盘/批次表同步 |
| v2.13 | 92dbb1556 | N4 落地：sema 12 单元+hir_lowering 迁入 src（累计 37/66，src 38 pas+55 inc）；门禁清单扩至 36 名+两类显式例外登记（sema.analyzer I/O 族 FsExists/FsStat 播种新鲜度检查、sema.analyzer/sema.string_ownership→ir 上行边 R9/N7）；台账 D16 点分文件名纪律；§5 映射表重写为 N1-N4 全量状态 |
| v2.14 | 91ff9e29d | N5 落地：ir 25 单元+backend.plan 迁入 src（累计 63/66，仅剩 toolchain ×3；src 64 pas+71 inc）；门禁清单扩至 62 名+例外+1（backend.plan FsDir）+上行边登记扩至 frontend.compilation_session→ir/backend 全族；全量 residual 对比诚实改挂 N6 收口轮（本轮以十三探针+tree mini 代证） |
| v2.15 | （本提交） | N6 落地=命名支柱收官：N6a toolchain ×3（2abcd33bb，66 生产单元全清，I/O 例外+3）；N6b 壳层 nextpas.driver.{command,projection}.*+target_config 改名+json_helpers 双胞胎收口+门禁前缀卫兵修复（点分后缀误报）；§5 全表收官；台账 D17 文档脚本截断教训 |
| v2.16 | （本提交） | 收口深化：D19 轴 A 层位检查复活（截断错位+豁免写法双重失效→首次真实运行现形 8 条 R9 违规）；§4.2.2 N7 手术清单立项；P1 静态侦察+实施细则两块（140 处热点/LookupProcedureBody 分配实锤/三刀次序） |
| v2.17 | （本提交） | residual 全量复跑核对：N5/N6 挂账销项（uniq/total=0/0 保持、opt 首错=同族支配性违规 %v8263@RunEnvStatus 仅编号位移）；P1 刀②两条实现级保证补入实施细则（ASCII 折叠语义等价+scratch 缓冲唯一性纪律） |
| v2.18 | （本提交） | P1 刀② 落地：共享 FoldAsciiInto（sema.overload）+analyzer FBodyLookupScratch+Context PString 借用；两查找点消 LowerCase 分配；Index 侧不改（Put 键别名）；实测 seed 235/238s→232/233s（-1.5%/-2.4%，轮间方差 0.4%）；穷举 65k 字节组合折叠等价 failures=0+SetLength 十万次 alloc-delta=0 两项前置实证 |
| v2.19 | （本提交） | seed 子相探针（reach/plan/encode）落地：**encode 占 seed ~96%**，刀③四趟扫描所在 reach/plan <3%；gdb 符号化采样法解锁 perf 受阻（stage0-debug -g 版+135 样本）：fpc_copy 38.5%+ansistr_assign 16.3%=托管拷贝风暴，真靶=encode 字符串构造；刀④ mark/scan 17 处 RMW→GetPtrUnchecked 就地化（噪声级如实记零）；D20 教训=归因必须先映射相位再选靶，刀①③静态降级挂起；刀⑤ encode 字符串构造立项 |
| v2.20 | （本提交） | P1 刀⑤ 落地：绿树零分配文本 API `TextLen`+`TextEquals`（镜像 GetText 有效性与 SameText 折叠语义）；seed 文件 26 判空+5 组字面量、walk_halt_calls 45 组 BFS 路径全量转换；实测 seed 221.6/219.0s 对刀② -4.5%/-6.0%、对 P0 基线累计 -5.9%/-8.3%=迄今最大单刀；遗留靶=SymbolAt/ResolveTypeIdForOwner 按值记录返回 |
| v2.25 | （本提交） | emitter-temp-placement 正确性线收官（三层修复）：①发射器级 hikAlloca 入口提升——EmitFunction 预扫全函数 alloca 渲染进序言缓冲、首块标签后冲刷、主扫跳过（D24 教训：异常发射劈分 HIR entry 块，EnsureAlloca 的 FEntryBlockId 提升不等于函数序言）；②except handler 绑定——LowerRuntimeTryExceptStatement 识别 gnkExceptionHandler，注册 handler 变量（var-decl-ptr-runtime + exc_load 赋值），`on E: C do`/裸 `on E do` 双形状；③E.Message 字符串 ABI——EncodeExceptionMemberStrTemp 物化 tstring 字段加载临时按 strvar (ptr,len) 传参并跳过结构化 ExprId 附加；mini tryenv 复现（build/m2_mini_tryenv.pas）双步 opt PASS+运行语义正确（fail msg=cfg broken）；十五探针 13 OPT-PASS+cap/cmpgen/puny 已知挂账零新回归；新挂账=llvm 产物动态链接器 /lib/ld64.so.1 本 host 缺失（探针只验 opt 从未执行故未暴露）；concat-swap 挂账新增可运行实证（mini len=0） |
| v2.26 | （本提交） | llvm 链接动态链接器 override 落地：AppendDynamicLinkerOverrideArg 共享助手（gnu-ld/lld profile 的 target-default-with-override 策略消费），native-link 与 llvm-link 两链接步骤统一 pin `--dynamic-linker /lib64/ld-linux-x86-64.so.2`（linux-x86_64）；tryenv mini 直接 `./` 执行成功语义正确；**解锁 llvm 产物真执行验证面**：cmpmid/tvec/hashmap 三探针首次可执行即暴露运行期 SIGSEGV（_start 跳栈地址，llvm 代码生成层既有缺陷——gnu 绑定下历来通过，坏解释器此前掩盖；解释器选择本身不影响合法 ELF 执行，非本批引入），逐探针调试转下批挂账；验证=contract pass+rebuild+compiler-pass 58/58（native-link 原路径回归通过）+tree/tryenv 双步 opt PASS+hygiene |
| v2.27 | （本提交） | llvm 探针 SIGSEGV 根因诊断收官（docs-only）：机器码↔.ll 对拍锁定破坏层=opt -O2 noreturn 级联——`_start` 被删主体、init 尾声消失跌落下一函数；级联源头=core 原子包装种子缺陷（atomic_compare_exchange_strong$iii 定义 (ptr,ptr,ptr) vs 调用点字面 0+5 参错配，tvec .ll:3631/7948/8718 实证）；跨模块归属移交 core-db lane+compiler lane 后续防御=encode 层调用签名一致性检查；D25 教训入档（双步 opt PASS 只证结构合法，noreturn 是合法但致命的传播源；执行验证应进探针协议） |
| v2.28 | （本提交） | 调用签名一致性战役开局：①归因修正——core 5 参重载声明合法，调用侧退化是编译器缺陷（EffectiveRuntimeCalleeName 首体选择无 arity 感知）；②修复=EffectiveRuntimeCalleeName 增可选 AArgCount（默认 -1 逐位不变）按 DeclAcceptsArgCount 选体，值位置普通调用两点传实元个数，IR 实证 strong_64 五参调用改打 $iiipp 个数对齐；③发射器 strict 计量器 NEXTPAS_EMIT_STRICT_CALLS 门控（默认关），阳性对照 isep 抓 IsSep formals=1 args=2；④存量扫描=裸名错形每 mini ~148 处、L3 1893 处+类型漂移与方法重载坍缩未计→战役立项（阶段A 类型漂移/阶段B 方法重载）；⑤tree 首次真执行 exit139 经 stash 基线对照证明先于本批非回归；D26 教训入档（处方落地前先量存量规模） |
| v2.29 | （本提交） | concat-swap b4b-i16 收官（`Result := A + '.ext'` 走 NoFold 运行时路径 ret_move 搬空槽，tryenv ok len=0）：①时序根因=TSemaRuntimeVarRegistry.Reset 每函数体清 FOwnedStringReturnFuncNames，把 PreregisterOwnedStringReturnConsumers 在 seeding 前注册好的 owned-func 名册一并抹掉→seed 时 IsOwnedStringReturnFunc 恒 False→Result 不注册 owned→concat 落倒置 else 分支；修复=Reset 只清每体 tracker、名册属跨体全局知识；②形状根因=三处发射点参数倒置（walk_halt_calls Result-concat else 分支/EmitStringFieldStoreRhsTemp/concat.inc 二元'+'递归）DisplayName=左#9右+Operand=dst，builder ProcessAssignTStringConcat 按 Pos(#9,Operand) 拆串 TabPos=0 静默 Exit；另核 field-store concat 三段 Operand（dst#9左#9右）与 builder 两段解析错配；四处统一归一契约 DisplayName=dst/Operand=左#9右（deferred.inc 与 encode_runtime_expr.inc 两处既有正确形状为参照）；③排查 object_free(%436) 错位=实为尾声 EmitClassVarFreeCleanupNodes 对 raise 构造临时（$new_tmp 经 RegisterClassVar）的清理：ok 路径 load 未存 alloca 参与 nil-guard icmp 属 UB、raise 路径不可达死代码；修复=注册表增免清理名册，raise 表达式编码前后差分新注册类变量并抑制其尾声 free（所有权随 exc_store 转移运行时）；④builder 静默 Exit 加 NEXTPAS_DEBUG=1 门控 stderr 告警（assign-tstring-concat/copy/call 缺 tab 或缺 $ts alloca 三族），默认零输出；验证=contract pass+rebuild pass 426315 行+compiler-pass 58/58+tryenv mini ok len=7/bad=fail msg=cfg broken+LoadCfg .ll tstring_concat×1/object_free×0+NEXTPAS_DEBUG 空告警+21 探针全量双步 opt PASS 仅 cap/cmpgen/puny 已知挂账零新回归+hygiene pass+diff-check(本批文件)；D27 教训=探针循环与 make test 并发跑共享 .nextpas 缓存会写坏产生假 BUILD-FAIL（编译器本体 EAccessViolation exit217 同族假象），重门禁须串行或隔离缓存目录 |
| v2.30 | （本提交） | residual 调用形状清理战役阶段A首刀：①根因=expr-N 实参饥饿（FoldCore 结构化回退发 expr N，cond-br 消费不压栈，EmitExprCall 按 Count 弹栈零填充=字面0 物化源头）+by-ref 实参无地址通道（var 形参收到值加载非地址）；②修复=FoldCore 调用点前置 callee 形参元数据（ParamNameIsByRef 逐参扫描）+by-ref 标识符合并分支（field→var self+field_ref，其余→varref 走 builder alloca/var-param/global_ref 三通道，interlocked 既有形状同构），语句位 EncodeCallStatementArgs 同构补齐；③IR 实证=AtomicCas64 五参全 ABI 对齐+探针执行过、GetOrd 序数 3 折叠、atomic_load 标识符类 12 处全数 ptr 级（含 global_ref）字面0 消灭；④计量勘误=锁定口径 arity A/B 169=169 持平（修复属类型级，arity 扫描器结构性盲视；上会话 135→106 复测不可现存疑不裁）；⑤helpers.inc 两分支经 13e84e60d 搭车入库归属勘误+D28 教训（共享 worktree 并行提交禁 -A）；遗留=DotAccess（本批实证 2 处）/SSE2Shift/Copy/Delete/SpanInit/构造族阶段B 重载坍缩/L3 复测/类型级第二检查器立项 |
| v2.31 | （本提交） | b4b-i16 追加刀·计数器回写：①新缺陷实证=SemaTrace 抓 EncodeStrCallArgs 字面量实参两次调用 temp=$str_tmp_1 counter=0 恒定——FillOwnershipContext 将 FBlockLabelCounter **按值**种子进 TSemaOwnershipContext，concat.inc 内 Inc 的是局部副本返回即丢，跨包装调用同名临时互覆（两实参同值='DoeDoe' 族），llvm 绑定执行暴露（gnu 绑定后端 strlit 直传常量掩盖，故 compiler-pass 历来绿）；前缀二进制对照证明先在性非 Fix A 引入（Fix A 使 concat 真发射才可见）；②修复=六个包装器统一回写 FBlockLabelCounter:=Ctx.BlockLabelCounter（EmitStrConcatOperand/EmitOwnedStringCopyTemp/WriteTemp/ConcatWriteTemp/ConcatLengthTemp/StrCompareOperand）；③实证=mini_cat3 nest=[John Doe]8/two=[JohnDoe]7 全对+mini_args 保持正确+tryenv len=7 保持+21 探针与基线逐项一致零回归+compiler-pass 58/58；④新挂账（llvm 执行面）=stub SysUtils Result[I] 字符索引循环 llvm 绑定降级残缺（循环界读未初始化 alloca+循环体削空）→UpperCase/LowerCase 恒等变换，string_concat_owned_pass 在 llvm 绑定 Halt(6)（gnu 绿）——先在于本批（与 concat 无关，字符索引降级缺口），归 llvm 执行面验证 lane 与 tree exit139 同族排队 |
| v2.32 | （本提交） | 字符串全局 24B 内联存储修复+rtl concat 别名防护：①新缺陷实证=mc_a/mc_e for 循环 `S:=S+'x'` 场景循环跑 4 轮（应 3）且循环变量 I 打印 0,0,0,120（120=ord('x')）——根因=ProcessVarDeclTString 程序级全局分支以 GetPtrType 调 FModule.AddGlobal→发射 `@g_X$ts = internal global ptr null`（**8 字节槽**），而全部 tstring 运行时（from_literal/concat/assign/init/fini/len/data）把该地址当内联 24B TString 结构读写，每次写溢出 16 字节踩相邻全局；数值吻合实证=SSO 数据区第 7 字节落位 @g_I（len≤6 该字节为 0、len=7 为末位 'x'=120），Inc(I) 读被踩 0 加 1 恒 ≤3 故多跑一轮；局部变量走 EmitTStringInit alloca [24 x i8] 历来正确唯全局错；②修复=THIRGlobal 增 IsTStringStorage 标志（AddGlobal 可选参数默认 False 全部旧调用点不变），EmitModule 对该类全局发 `internal global %TString zeroinitializer, align 8`（%TString=[24 x i8] 发射端既有命名类型）；不走数组类型注册路线因 TypeToLlvm 对复合类型映射 'ptr'（按引用 ABI）；③受控跨模块 rtl/runtime=nextpas.runtime.tstring.ll np_tstring_concat 签名不变语义增强，dst 与 a/b 同址时 entry alloca 暂存两操作数再拼接（phi 选路），根除自拼 `S:=S+'x'` 别名腐坏（mc_d 直线序列 [abcx][abcxx][abcxxx] 实证），理由=builder 端四处契约归一（v2.29）后该形状成主路径而运行时未设防、不改则 core 执行面正确性目标受阻，风险=纯函数内新增栈暂存零 ABI 变化；④中途教训=首刀误将 %TString 文本置入 thread_local 分支致普通字符串全局变 TLS 变量 SIGSEGV exit139，立即定位修正（TLS 字符串全局维持原状不在范围）；⑤新挂账精确化（llvm 执行面值位置家族）=mini_cat2 `WriteLn(P+Q)` 表达式位置 concat 走通用二元加法路径=np_tstring_data 两指针 ptrtoint 后整数相加打印、字符字面量折叠序数值（120/32）相加；mc_c S[I] 读发索引值/S[1]:='X' 写退化为整串字面量替换（IR 无字节级 gep+store）——与 v2.31 UpperCase/LowerCase 恒等同族归 lane 排队；验证=rebuild pass 426562 行+hygiene 随构建 pass+mc_e 恰 3 轮 I=1,2,3 内容长度全对 exit0+mg1 双字符串全局夹整型布局全对+mc_a/b/d 全对+tryenv ok len=7 保持/bad msg 传播+21 探针逐项一致仅 cap/cmpgen/puny 已知挂账+compiler-pass 58/58+contract pass+diff-check(本批文件)；并行会话脏文件（np_sema_encode_runtime_expr.inc/MIXUSE-AUDIT.md）按 D28 纪律排除在外且经惰性核验（其 by-ref+DotAccess 分支对本批 fixture 不触发） |
| v2.34 | （本提交） | 值位置 concat 写实参修复（mini_cat2 家族归正）：①缺陷实证=WriteLn(P+Q)/WriteLn(P+' '+Q)/WriteLn('x'+P)/WriteLn(P+'!') 四形状全数走 write-int 退化——写实参分类链（walk_halt_calls NoFold 分支）中 EmitOwnedStringWriteTemp 只接单 owned-return 调用节点、EmitOwnedStringConcatWriteTemp 被 ConcatTreeHasSupportedOwnedStringReturn 门槛拒绝纯变量/字面量树→漏入 AddWriteIntRuntimeNode，发射端把 np_tstring_data(P)/np_tstring_data(Q) 两指针 ptrtoint 后整数相加打印、字符字面量折叠序数值（120/32）相加；②修复=新增 EmitPlainStringConcatWriteTemp（string_ownership 单元+TSemanticAnalyzer 包装器），门槛=CanEmitStrConcatOperand 通过且无 owned-return（后者让位 owned 变体保持职责单一），物化形状与 owned 变体同构=var-decl-tstring + assign-tstring-concat(左#9右 builder 契约) + QueuePendingStringTempRelease，接线于 concat-write-temp 分支后；③IR 实证=mini_cat2 五处 np_tstring_concat（嵌套左结合展开正确）+实参全走 write_str_var 零 write_i64_decimal，运行输出 A=JohnDoe/B=John Doe/C=xJohn/D=John! 全对 exit0；④边界=仅 Write/WriteLn 实参位接线，其余值位置（比较右值/Length 实参等）未探未修留 lane；验证=rebuild pass+mini 全家族与 mc_a-e/mg1 与基线逐项一致+tryenv len=7 保持+21 探针逐项一致仅 cap/cmpgen/puny 已知挂账+compiler-pass 58/58+contract pass+hygiene pass+diff-check(本批五源码文件)；回归防线=新增常驻守卫探针 build/m2_mini_globstr.pas(全局串 24B 存储+相邻整型，v2.32 凭证)与 build/m2_mini_valcat.pas(值位置 concat 四形状，v2.34 凭证)按 tryenv 先例转正强制追踪 |
| v2.33 | （本提交） | residual 战役阶段A续刀·DotAccess 字段链地址通道：①FoldCore TryByRefFieldAddressBlob 三路由=P^.F 解引用形（TryPointerFieldAccess）与 pointer-var 基→var B+field_ref，record 型基（var-param/local/global）→**varref B**+field_ref（builder varref 对 var-param 单解引发 caller 记录指针对齐 by-ref ABI；类型经符号表 SymbolTypeId 解析零注册表改动），接线于 by-ref 标识符分支后 const-fold 前；②codegen BuildTargetAddressExpr identifier 分支补 record-symbol 路由（scalar-fact 失败后 SymbolTypeId→TypeMetaIsRecord→BuildRecordBaseAddressExpr）——原硬 Exit(False) 使结构化契约 'r' 子构建必败；③实证边界=tree atomic_load ptr 级保持 12 值传递 2→3（第三处=v2.32 并行改动新现），FindSpanOwnerThreadId 两处未翻转——HIR dump 实证其调用走 expr N 结构化节点根本不经 token 循环，D20 再验证：接线前先实证编码器归属；④新发现主根因=atomic_load 声明 overload; → HasOverload 使 TryGetDirectCallContract 即退 → 结构化 shekCall 无 'r' ops 全参值语义——下一刀主靶=overload-aware 结构化契约（v2.28 arity 感知同构推广到 ops 推导）；⑤新发现挂账=deref 基值位置语句吞失（GLen:=Measure(LP^.FVal) 整句无 IR，stash 二分证明先在，m2_mini_dotref 探针复现）；验证=rebuild pass+TREE-DUAL-OPT-PASS+strict 阳性 exit217+contract pass+compiler-pass 58/58+casdrift/dotref/enumfold2 执行 exit0+hygiene pass+diff-check(本批两文件) |

## 10. 文档维护规则

- **每批落地时**：更新 §4 批次状态、§5 映射表勾销、§6 台账追加 D 条目、
  顶部「最后更新」时间——与该批 commit 同文件同提交；
- **发现即记**：迁移中任何勘误/故障根因/决策变化，当批进 §6/§8，
  不许事后补忆；
- **数字纪律**：本文所有计数与耗时必须来自命令实测，写前跑一遍；
- **单一权威**：本文件是重构唯一权威来源；附录 B（flat-namespace v2）
  即日起**冻结不再更新**，仅作历史细化参考；两文冲突时以本文为准；
- **收口条件**：N6+P4 全部落地、§4 两表全 ✅、§7 风险册关闭或转永久监控，
  本文件转为 `Landed` 状态归档进 `docs/architecture/`（稳定事实部分）。

## 11. 附录

- 附录 A：`docs/plans/compiler-core-reuse-map.md`——core 能力地图×绑定矩阵
  （API 面核实、禁区、两代福利机制）
- 附录 B：`docs/plans/compiler-flat-namespace.md` v2——**已冻结**（§10 维护
  规则），四支柱细化与历史待决策项参考；冲突以本文为准
- 附录 C：ROADMAP `docs/plans/m2/ROADMAP.md`——undefined 归零战报与注³⁶
