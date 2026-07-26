# nextpas.core.bench 系统性审查 findings

**类型**：audit + **2026-07-26 全量闭环实施**
**审查日期**：2026-07-26
**闭环状态**：见下表「状态」列
**约束口径**：FPC RTL 隔离——仅 `nextpas.core.system*` 门面可直接触 RTL；其余经抽象。

---

## 闭环状态总表（2026-07-26）

| ID | 状态 | 交付摘要 |
|----|------|----------|
| F-01 | **Resolved** | parallel → `platform.thread`；无 `system.classes`/`TThread` |
| F-02 | **Resolved** | `TryEnable*` + Enable 失败语义；进程隔离文档 |
| F-03 | **Resolved** | `CompareGroups.HasStatisticalTest=False` + 测试 |
| F-04 | **Resolved** | suite deadline 传入采样；`Timeout_AbortsLongEntry` |
| F-05 | **Resolved** | `RunParallelBenchWithUserData`；删 `GBridgeRunner` |
| F-06 | **Deferred-closed** | 不物理大拆；冻结 + ARCH/README 收口 |
| F-07 | **Resolved** | 注释 + 测试锁定「算术相加」语义 |
| F-08 | **Resolved** | free size=0 / Current* clamp |
| F-09 | **Resolved** | GlobalMemoryTracker 标 deprecated；推荐 GetStats |
| F-10 | **Resolved** | 无 raw → 不显著 |
| F-11 | **Resolved** | README/CONTRACT Advanced 标注 |
| F-12 | **Resolved** | ARCH tooling 口径 |
| F-13 | **Resolved** | 随 P1–P4 补测 |
| F-14 | **Resolved** | `make bench-consumer-smoke` |
| F-15 | **Resolved** | SCORECARD 巨型 historical banner |
| F-16 | **Resolved** | `object_pool.pas` → `recipe_reuse.pas` |
| F-17 | **Resolved** | contract C10 + 源无 system.classes |
| F-18 | **Resolved** | README 主推 AddLoopWithContext |
| F-19 | **Resolved** | 策略：不扩功能，文档对标差距 |
| F-20 | **Resolved** | 子集为真相；全量推迟 |
| F-21 | **Resolved** | CONTRACT heaptrc 互斥说明 |
| F-22 | **Resolved** | 46 处 ticket 注释清理：活约束去标签保留，纯历史/噪音整条删 |
| F-23 | **Deferred-closed** | EBR 明确不实现 |
| F-24 | **Resolved** | TBenchRun Advanced 文档 |
| F-25 | **Resolved** | scipy 金标冻结为 4 个 golden_*.inc；22 条断言接入 4 套件；随手揪出 F-28/29/30 三个真 bug |
| F-26 | **Resolved** | roadmap/ebr 状态句 |
| F-27 | **Mitigated** | 门禁构建阶段 host fpc 偶发 "Can't find unit"；gate 循环构建重试一次 |
| F-28 | **Resolved** | Skewness 调整因子错配：样本矩 z 分套总体矩因子，偏低 ((n-1)/n)^1.5；改 G1=n·Σz³/((n-1)(n-2)) |
| F-29 | **Resolved** | KS 双样本 tie 分支 D 错：改值消耗合并走查（同值两侧全消费后取跳后 ECDF 差） |
| F-30 | **Resolved** | FPC 实数字面量默认 Single 致 1.0/N 降精度；bench 四单元加 {$MINFPCONSTPREC 64}（tranche 2 补涂 report） |
| F-31 | **Resolved** | ModifiedZScore O(N) MAD 归并双奇偶 off-by-one：MAD 恒偏高、漏检异常值；金标索引集钉死 |
| F-32 | **Resolved** | level/alpha 表选择边界比较失配：请求 99%/95% 拿到 95%/90% 表；比较加 BENCH_LEVEL_EPS 余量 |

---

## 总览（原审计）

| 等级 | 数量 | 含义 |
|------|------|------|
| P0 阻断 | 0 | 无已证实「立刻不能用 / 必炸」的阻断项 |
| P1 严重 | 6 | 语义误导、进程级钩子、超时/并行边界、编译器无关耦合 |
| P2 中等 | 12 | 可维护性、测试缺口、文档真相分裂、API 面 |
| P3 建议 | 8 | 对标差距、命名/卫生、增强项 |

**整体判断（审计时）**：功能密度高；主要风险在语义陷阱与全局状态。
**闭环后**：P1 代码项已修；并行去 TThread；门面/EBR 以策略关闭。

---

## Findings

### F-01 · 架构 · P1

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.parallel` |
| 位置 | `core/src/nextpas.core.bench.parallel.pas:15`、`TBenchThread = class(TThread)` ~L101 |
| 分类 | 架构 |
| 等级 | **P1** |
| 描述 | 并行路径依赖 `nextpas.core.system.classes` → 再 export FPC `Classes.TThread`。bench 源码未直接 `uses Classes`，但 **并行能力实质绑定 FPC 对象线程模型**。在「nextpas 编译器透明切换」目标下，`TThread` 语义（Create suspended、WaitFor、异常模型）是硬耦合。 |
| 建议 | 中长期：并行执行迁到 `platform.thread`（或专用 harness 线程 API），`system.classes` 仅作过渡；短期：在 ARCHITECTURE/CONTRACT 标明「并行路径 = FPC TThread 依赖，nextpas backend 必须提供等价物」。 |

---

### F-02 · 架构 · P1

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.memtrack` |
| 位置 | `core/src/nextpas.core.bench.memtrack.pas:15`；`EnableGlobalMemoryTracking` ~L304–L336；`SetMemoryManager` |
| 分类 | 架构 / 代码 |
| 等级 | **P1** |
| 描述 | 内存追踪通过 `nextpas.core.system.memmanager` 安装 **进程级** `SetMemoryManager` 钩子。影响全局分配路径；与其他 hook（heaptrc、未来自定义 allocator）叠加有 OOM/双重计数风险（已有 `HEAPTRC_ACTIVE` 软护栏）。并发 Enable/Disable 用 CAS try-lock **失败则静默 Exit**，调用方可能以为已启用。 |
| 建议 | 文档强制「单 suite 串行 + 测试进程隔离」；Enable 失败应返回 Boolean 或抛明确错误；评估是否改为采样窗口内局部计数（若可行）而非全局 MM hook。 |

---

### F-03 · 代码 · P1

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench`（结果 API） |
| 位置 | `TBenchResults.CompareGroups` · `core/src/nextpas.core.bench.pas:2502–2531` |
| 分类 | 代码 |
| 等级 | **P1** |
| 描述 | `CompareGroups` 对组均值做 `HasHeuristicDifference` / `ComputeApproximatePValue`，却设置 `Result.HasStatisticalTest := True`。与 `CompareTwoResults`（有 RawSamples 才 `HasStatisticalTest=True`，否则 False）不一致。**CI 若信 HasStatisticalTest 会把启发式当正式检验。** |
| 建议 | `CompareGroups` 设 `HasStatisticalTest := False`，或改名/拆 API（`CompareGroupsHeuristic` vs 真 MWU）；文档与测试锁定该标志语义。 |

---

### F-04 · 代码 · P1

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench` / runner |
| 位置 | suite 超时：`bench.pas:1048–1088`；采样：`runner.pas:1236–1245`（`LTimeoutMs := 0`） |
| 分类 | 代码 |
| 等级 | **P1** |
| 描述 | 公开 `SetTimeout` 只在 **条目之间 / 条目完成后** 检查；`RunOne` → `CollectEntrySamples` **不传入 deadline**。单条超长基准可远超 suite timeout；完成后还可能把刚测完的结果标成 `Skipped=Timeout`（丢弃有效样本且浪费时间）。 |
| 建议 | 将 suite deadline 传入 `CollectEntrySamples`/`RunOne`；超时后中断采样并明确 SkipReason；补充 integration 测试「单 entry 超过 timeout 应中止」。 |

---

### F-05 · 代码 · P1

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.runner` |
| 位置 | `GBridgeRunner` / `GBridgeBusy` · `runner.pas:223–228`、`742–757` |
| 分类 | 代码 |
| 等级 | **P1** |
| 描述 | 并行桥接依赖 **文件作用域全局** runner 指针 + CAS busy 位。任意两个 suite/进程内并行 `AddParallel` 互斥；CAS 冲突抛错（好），但设计上无法多 suite 并行跑 parallel 条目。对「进程内嵌套/插件式」使用脆弱。 |
| 建议 | 用 thread-local 或 `TParallelBenchmark` 用户数据回调携带 runner；至少文档写清「进程内同一时刻只能有一个 parallel Run」。 |

---

### F-06 · 架构 · P1

| 字段 | 内容 |
|------|------|
| 模块 | 门面 / 接口 |
| 位置 | `core/src/nextpas.core.bench.pas` ~3264 行；`IBenchResults` ~77 methods · `bench.intf.pas:365+` |
| 分类 | 架构 |
| 等级 | **P1**（可维护性 / 演进风险；非运行时必炸） |
| 描述 | 结果查询、过滤、分组、矩阵、导出、回归全堆在 `IBenchResults` + 单门面单元。API 已冻结，但 **变更成本与审查成本极高**；新同事易误用边缘聚合 API。与 Go `testing.B`（小核心）/ criterion（crate 分层）相比表面积过大。 |
| 建议 | 维持冻结；新能力只进 `report`/`stats` 子单元；长期考虑只读「视图」类型拆分（不破坏默认 Fluent 路径）。**禁止** Idle 期继续堆方法。 |

---

### F-07 · 代码 · P2

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench` |
| 位置 | `GetTotalOpsPerSec` / `GetTotalBytesPerOp` / `GetTotalAllocsPerOp` · `bench.pas` ~2654+；ARCHITECTURE「语义陷阱」表 |
| 分类 | 代码 / 规范 |
| 等级 | **P2** |
| 描述 | 名称像「整体吞吐/整体带宽」，实现是各 entry 指标 **算术相加**。文档已警告，但 API 名仍易被 CI 误用。 |
| 建议 | 弃用式重命名（`SumOpsPerSec`）或文档/报告强制 disclaimer；测试断言「两 entry 各自 1e6 → Total=2e6」防止「以为是几何/整体」的错误修复。 |

---

### F-08 · 代码 · P2

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.memtrack` |
| 位置 | `TrackingFreeMem` · `memtrack.pas:175–185`；`RecordFree` · L247–255 |
| 分类 | 代码 |
| 等级 | **P2** |
| 描述 | Free 时若 `MemSize` 不可用则按 0 字节记账；`CurrentBytes`/`CurrentAllocs` 可被 `AtomicDec` 打成负数语义（无下限钳制）。峰值与 B/op 在复杂分配模式下可能偏。 |
| 建议 | 未知 size 时单独计数 `UnknownFreeCount`；Current* 钳制 ≥0；文档说明精度边界。 |

---

### F-09 · 代码 · P2

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.memtrack` |
| 位置 | `GlobalMemoryTracker` · `memtrack.pas:285–290` |
| 分类 | 代码 |
| 等级 | **P2** |
| 描述 | 函数返回 `TMemoryTracker` **record 值拷贝**。对拷贝调用 `RecordAlloc` 不会更新全局统计（钩子路径用 `GGlobalTracker` 故安全，但公开 API 易误用）。 |
| 建议 | 改为过程式 API only（已有 Get/Reset/Enable），或返回指针/接口；标记 record 返回为 advanced/internal。 |

---

### F-10 · 代码 · P2

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench` |
| 位置 | `CompareTwoResults` · `bench.pas:2916–2960` |
| 分类 | 代码 |
| 等级 | **P2** |
| 描述 | 默认不 `CollectRawSamples` 时 MWU 不可用，静默退回 ratio 阈值启发式，且 `HasStatisticalTest=False`（比 CompareGroups 诚实）。但调用方若不查标志，仍可能把 `IsSignificant` 当严格检验。 |
| 建议 | 默认 suite 对需要对比的路径自动开 raw samples；或 `IsSignificant` 在无检验时强制 False 并 WARNING。 |

---

### F-11 · 架构 · P2

| 字段 | 内容 |
|------|------|
| 模块 | 双路径 API |
| 位置 | `TBenchSuite`（canonical）vs `TBenchRunner` · `runner.pas:87+`；README「Advanced」 |
| 分类 | 架构 |
| 等级 | **P2** |
| 描述 | 两套入口并存；Runner 暴露 Measure/Calibrate 等底层能力。文档已标 Advanced，但测试与示例仍可能教出分叉用法，增加契约面。 |
| 建议 | 继续压向 Suite-only；Runner 标 `@deprecated for new code` 或移到 `bench.internal`（长期）。 |

---

### F-12 · 架构 · P2

| 字段 | 内容 |
|------|------|
| 模块 | 分层 / registry |
| 位置 | `ARCHITECTURE.md` tooling harness；依赖 fs/json/atomic/collections/system.classes |
| 分类 | 架构 |
| 等级 | **P2** |
| 描述 | 历史文档曾暗示「纯 L1」；实为 **tooling 宽依赖**。对依赖审计者易误判。当前 ARCH 已纠正，但跨文档若再写 L1 会回潮。 |
| 建议 | registry + CONTRACT 保持 tooling 口径；CI contract-check 可扫「禁止错误 L1 自称」（文档门）。 |

---

### F-13 · 测试 · P2

| 字段 | 内容 |
|------|------|
| 模块 | 测试矩阵 |
| 位置 | `core/tests/nextpas.core.bench/*`（22 PROJECTS） |
| 分类 | 测试 |
| 等级 | **P2** |
| 描述 | 覆盖面广（stats/MWU/KS/report/xlang/memtrack/parallel heaptrc 等），但缺口包括：**(1)** suite timeout **中断单 entry 采样**；**(2)** `CompareGroups` 的 `HasStatisticalTest` 真值契约；**(3)** memtrack Enable 在并发/二次 hook 下的失败语义；**(4)** 无「nextpas 编译器」路径，仅 host FPC；**(5)** adaptive_warmup 仅 4 tests，偏薄。 |
| 建议 | 按 F-03/F-04 补契约测试；compiler-agnostic 另开阶段，不混进 host gate。 |

---

### F-14 · 测试 · P2

| 字段 | 内容 |
|------|------|
| 模块 | 消费侧 / 回归 |
| 位置 | `core/benchmarks/nextpas.core.*`；checklist 22 模块 |
| 分类 | 测试 |
| 等级 | **P2** |
| 描述 | 框架 gate 不默认编译全量模块 bench；API drift（B47 类）靠人工。维护态仅抽检 hash/json 等。 |
| 建议 | 可选 `make bench-consumer-smoke`（子集 Makefile build）；挂 weekly 而非默认 PR 门。 |

---

### F-15 · 规范 · P2

| 字段 | 内容 |
|------|------|
| 模块 | 文档真相 |
| 位置 | 根目录 `bench/SCORECARD.md`（historical）；`core/docs/bench/scorecard-subset-*`（可复现） |
| 分类 | 规范 / 对标 |
| 等级 | **P2** |
| 描述 | 全文仍印「vs Go 81%」等 **2026-07-02** 数字；页眉已警告 historical，但扫一眼仍像 live 排行榜。对外/对内易误读。 |
| 建议 | 文件顶部改为更醒目 banner，或改名 `SCORECARD.historical-2026-07-02.md`；README 只链子集。 |

---

### F-16 · 规范 · P2

| 字段 | 内容 |
|------|------|
| 模块 | 示例命名 |
| 位置 | `core/examples/bench/object_pool.pas`（内容已是 recipe reuse） |
| 分类 | 规范 |
| 等级 | **P2** |
| 描述 | 文件名与程序意图不一致，检索/教学易错。 |
| 建议 | 重命名为 `recipe_reuse.pas`（或保留兼容 stub 说明）。 |

---

### F-17 · 规范 · FPC RTL 隔离 · P2

| 字段 | 内容 |
|------|------|
| 模块 | bench 全表面（源码/测试/示例） |
| 位置 | 扫描：`core/src/nextpas.core.bench*.pas`、tests、examples |
| 分类 | 规范 / 架构 |
| 等级 | **P2**（合规现状）+ 残余 **P1 耦合**见 F-01/F-02 |
| 描述 | **直接** `uses SysUtils/Classes/BaseUnix/Unix/Windows`：**未发现**（符合隔离）。依赖走 `nextpas.core.*` 与 `nextpas.core.system.classes` / `system.memmanager`。`system.classes` 自身 `uses Classes`；`system.memmanager` 调 `System.Get/SetMemoryManager`——属 system 门面职责。bench 合规，但 **能力仍非编译器无关**。 |
| 建议 | 保持 contract-check C5/C9；扩展检查「禁止绕过 system 门面」；并行/MM 抽象路线图单独立项。 |

---

### F-18 · 代码 · P2

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench` |
| 位置 | `AddLoop` vs `AddLoopWithContext` · intf/README |
| 分类 | 代码 / 规范 |
| 等级 | **P2** |
| 描述 | `AddLoop` 无 `IBenchContext`，无法 `SetBytes`/`Skip`/`ResetTimer`；易被新手当 Go `b.N` 等价物误用。 |
| 建议 | 文档/示例默认只展示 `AddLoopWithContext`；`AddLoop` 标注 limited。 |

---

### F-19 · 对标 · P3

| 字段 | 内容 |
|------|------|
| 模块 | 整体 |
| 位置 | 对比 Go `testing.B` + benchstat；Rust criterion |
| 分类 | 对标 |
| 等级 | **P3** |
| 描述 | **已超**：内建 memtrack、HTML/SVG、多基线矩阵、K-S/BCa 等。**落后/差距**：criterion 式 regression 默认严谨（OLS+CI 默认路径更统一）；Go 式极简 API 心智；并行用标准库线程而非 ad-hoc 全局桥；可复现 scorecard CI 默认；统计 API 默认「无 raw samples 不报 significant」。 |
| 建议 | Idle 不扩功能；若开下一轮，优先「默认统计诚实性 + timeout 真中断 + 并行去全局」而非再堆导出格式。 |

---

### F-20 · 对标 · P3

| 字段 | 内容 |
|------|------|
| 模块 | xlang |
| 位置 | `bench.xlang.pas`；scorecard 子集 11 track |
| 分类 | 对标 |
| 等级 | **P3** |
| 描述 | 解析 Go/Rust/FPC 输出能力在；全量跨语言排行榜未维持。对标工程常见「小而真的 CI bench」而非「60+ 历史表」。 |
| 建议 | 保持 11-track 子集为真相；全量刷新单独授权。 |

---

### F-21 · 测试 · P3

| 字段 | 内容 |
|------|------|
| 模块 | heaptrc 套件 |
| 位置 | `test_bench_*_heaptrc` |
| 分类 | 测试 |
| 等级 | **P3** |
| 描述 | 多套 heaptrc 验证 0 leak，质量较好；与 memtrack 互斥路径依赖 `HEAPTRC_ACTIVE`，非 heaptrc 构建下 `IsHeaptrcEnabled=False`，双重 hook 护栏在生产 `-gh` 未定义宏时可能失效。 |
| 建议 | 运行时探测 heaptrc（若可行）或文档要求 memtrack 测试与 -gh 互斥构建矩阵写清。 |

---

### F-22 · 规范 · P3

| 字段 | 内容 |
|------|------|
| 模块 | 源码风格 |
| 位置 | 门面/runner 中英注释混排；部分 `F-xx`/`PF-xx`/`ST-xx` 历史 ticket 注释 |
| 分类 | 规范 |
| 等级 | **P3** |
| 描述 | 可读，但 ticket 噪音多；新读者难分「仍有效约束」vs「已修记录」。 |
| 建议 | 长期把仍有效约束上收到 CONTRACT；过时 ticket 注释可删（单独卫生 PR）。 |

---

### F-23 · 架构 · P3

| 字段 | 内容 |
|------|------|
| 模块 | EBR × BenchRun |
| 位置 | `ebr-benchrun-design-note.md`（明确不实现） |
| 分类 | 架构 |
| 等级 | **P3** |
| 描述 | 无问题，属正确推迟。列此项避免审计误开新需求。 |
| 建议 | 维持不实现，除非总控授权 + 问题陈述。 |

---

### F-24 · 代码 · P3

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.run` |
| 位置 | `TBenchRun` 原子收集 · `bench.run.pas` |
| 分类 | 代码 / 对标 |
| 等级 | **P3** |
| 描述 | 与 Suite 主路径并行存在的线程安全收集器；使用面窄，文档标 Advanced。维护成本低但增加心智。 |
| 建议 | Idle 保持；勿与 EBR 融合。 |

---

### F-25 · 测试 · P3

| 字段 | 内容 |
|------|------|
| 模块 | 统计正确性 |
| 位置 | `test_bench_stats` / `mannwhitney` / `ks` / `stats_advanced` |
| 分类 | 测试 |
| 等级 | **P3** |
| 描述 | 有已知分布与交叉校验倾向，整体有效。缺少与外部金标（R/Python 固定种子向量）的 **冻结 golden 向量** 文件化（部分数值硬编码在 lpr）。 |
| 建议 | 可选 `testdata/*.json` golden，降低魔法数漂移。 |
| 收口（2026-07-26） | scipy 1.18.0 金标冻结为 4 个 `golden_*.inc`（mwu/ks/descriptive/analyzer），生成器 `tools/gen_golden_vectors.py` 自带 Pascal 近似复刻自检（近似误差 < tol/2 才允许冻结）；数据集为手写字面量（无 RNG，Pascal/Python 解析出相同 double）。22 条 golden 断言接入 4 既存套件（不新增套件，PROJECTS 保持 22）。金标当场揪出三个真 bug：F-28（Skewness 因子）、F-29（KS2 tie 分支）、F-30（Single 字面量精度），证实原区间断言会放过「方向对、数值错」的实现。 |

---

### F-26 · 规范 · P3

| 字段 | 内容 |
|------|------|
| 模块 | 文档集 |
| 位置 | `core/docs/bench/` README/API/CONTRACT/goal-tree/consumer-* / LANE-DUTY |
| 分类 | 规范 |
| 等级 | **P3** |
| 描述 | 文档完备度高（优于多数内部模块）。B48 去重后根目录更干净。残余：`roadmap.md` 与 goal-tree 阶段叙事可能部分过时。 |
| 建议 | roadmap 顶注「历史竞争路线，状态以 goal-tree 为准」。 |

---

### F-27 · 基础设施 · P2（2026-07-26 新增）

| 字段 | 内容 |
|------|------|
| 模块 | 门禁基础设施（非 bench 源码） |
| 位置 | `core/tests/nextpas.core.bench/Makefile` test 循环；host fpc trunk（3.3.1-19195-gebfc7485b1-dirty） |
| 分类 | 基础设施 / flake |
| 等级 | **P2**（侵蚀门禁可信度） |
| 描述 | 全量 gate 中 `test_bench_matrix` 偶发编译失败：`test.check.pas(375,3) Fatal: Can't find unit nextpas.core.test.diff`，而 `core/src/nextpas.core.test.diff.pas` 存在且同目录几十个单元均正常解析。观测频率：2026-07-26 连续 3 次全量 gate 中 1 次；失败运行的 Compiling 序列是成功运行的**严格前缀**（前 207 单元完全一致，第 208 个 `test.diff` 查找失败）→ 编译顺序确定，属编译器/文件查找瞬态。单独 `make clean all` 循环 6/6 通过，无法离线复现。 |
| 处置 | gate 循环拆分构建/运行两阶段：构建失败带 `[BUILD-FLAKE-RETRY]` 标记重试一次（真回归连挂两次仍红）；运行期失败不重试保持严格。根因疑在 host fpc trunk dirty 构建的单元查找路径，非 bench/test 源码问题；若复发频率升高，升级为向 FPC 上游取证报告。 |

---

### F-28 · 正确性 · P1（2026-07-26 由 F-25 金标发现）

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.stats.advanced` |
| 位置 | `TAdvancedStats.Skewness` |
| 分类 | 数值正确性 |
| 等级 | **P1**（结果系统性偏低，区间断言不可见） |
| 描述 | z 分数用样本标准差（ddof=1）计算，却套用总体矩版调整因子 `sqrt(n(n-1))/(n-2)`，两套口径错配，结果恒偏低 `((n-1)/n)^1.5`（n=20 时约 -7.4%）。原区间断言（如「偏度 > 0」）无法察觉。 |
| 处置 | 改为 Fisher-Pearson 调整 G1 正确式：`G1 = n·Σz³/((n-1)(n-2))`；scipy `skew(bias=False)` 金标钉死于 `test_bench_stats_advanced`（tol 1e-9）。 |

---

### F-29 · 正确性 · P1（2026-07-26 由 F-25 金标发现）

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.stats` |
| 位置 | `KolmogorovSmirnovTwoSampleTest` D 统计量 |
| 分类 | 数值正确性 |
| 等级 | **P1**（有 tie 数据时 D 虚高，两组完全相同也报 D=1/n） |
| 描述 | tie 分支比较「一侧跳后 ECDF vs 另一侧跳前 ECDF」，同值未两侧同步消费。极端症状：两组数组完全相同时 D=1/12（应为 0）；带 tie 的 SHIFT 数据 D=0.56（scipy 精确值 0.52）。 |
| 处置 | 重写为值消耗合并走查：每轮取两侧最小值，把两侧所有等于该值的元素全部消费，再取跳后 ECDF 差的最大值。scipy 精确 D 金标钉死（tol 1e-12），含 identical→D=0 回归用例。 |

---

### F-30 · 正确性 · P2（2026-07-26 由 F-25 金标发现）

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.base` / `stats` / `stats.advanced` |
| 位置 | 所有 `1.0/整型` 类表达式（KS ECDF 步长、MWU tie 校正、方差归一化等） |
| 分类 | 数值精度 / FPC 语言陷阱 |
| 等级 | **P2**（~1e-8 级系统误差，叠加统计量后可放大） |
| 描述 | FPC 默认把实数字面量取「能精确表示的最小类型」，`1.0` 为 Single；`1.0 / LN`（LN 整型）整个表达式落在 Single 精度计算，误差 ~1e-8。经最小探针复现：KS D=0.29999999701976776，偏差恰为 2×(Double(Single(0.1))−0.1)。 |
| 处置 | 三个统计相关单元头部加 `{$MINFPCONSTPREC 64}`（字面量最低 Double）。tranche 2 全模块扫描后补涂 `report`（`FormatBytes` 的 `ABytes/1024.0` 为最后一处暴露面），其余单元无整型/字面量混算。core 全局 settings.inc 属跨模块变更，超出本 lane 范围，同类隐患在其他模块普遍存在——已在注释中说明，留待仓库治理层决策。 |

---

### F-31 · 正确性 · P1（2026-07-26 由金标 tranche 2 发现）

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.stats.advanced` |
| 位置 | `TAdvancedStats.DetectOutliers_ModifiedZScore` O(N) MAD 双指针归并 |
| 分类 | 数值正确性 |
| 等级 | **P1**（MAD 恒 ≥ 真值 → Modified Z 恒偏低 → 系统性漏检异常值） |
| 描述 | 双奇偶各有一处 off-by-one：奇数 n 时归并流从 `medIdx±1` 起、不含 median 自身的 0 偏差（全集最小值），但目标秩仍按全集 `n div 2` 取，MAD 高一个秩（手算 [1,2,3,4,100]：真值 1，旧码 2）；偶数 n 时右指针从 `medIdx+1` 起，S[n/2] 的非零偏差被整个跳过（手算 [1,2,3,4]：真值 0.5，旧码 1.5）。两条路径 MAD 均只偏高不偏低，异常值只漏不误报，区间断言不可见。 |
| 处置 | 奇数分支目标秩 `Dec(LTarget)`（n=1 时循环自然跳过，MAD=0 正确）；偶数分支 `RJ := LMedIdx`。金标数据集特意植入横跨新旧 MAD 判界的边界点（生成器 require 强制 `旧MAD > 新MAD` 且新旧索引集不同），修复前实测红（奇偶两路 ModZ 索引集均不符），修复后绿；numpy MAD 索引集金标钉死于 `Golden_Outliers`。 |

---

### F-32 · 正确性 · P1（2026-07-26 由金标 tranche 2 发现）

| 字段 | 内容 |
|------|------|
| 模块 | `nextpas.core.bench.stats.advanced` / `stats` / `base` |
| 位置 | `ConfidenceInterval` level 分支、`TInvAlpha` alpha 分支 |
| 分类 | 数值正确性 / FPC 语言陷阱（F-30 姊妹症） |
| 等级 | **P1**（对所有调用者系统性生效：请求 95% CI 拿到 90% 表，alpha=0.01 拿到 95% 临界值反保守虚报显著性） |
| 描述 | `Double` 参数与不精确实数字面量在阈值边界比较时精度失配：字面量解析为 extended（`{$MINFPCONSTPREC 64}` 只设下限），而 `Double(0.95)=0.94999999999999996 < extended 0.95` 恒成立 → `ALevel >= 0.95` 对字面量调用者恒 False。探针实证：`ConfidenceInterval(0.95)` 落 90% 表（t=1.729 而非 2.093），`(0.99)` 落 95% 表；`TInvAlpha(0.01)` 因 `Double(0.01) > extended 0.01` 落 95% 表（反保守）。alpha=0.05 靠 else 兜底分支侥幸正确。危险点：常用值 0.95/0.99/0.01 恰好全部踩在边界上。 |
| 处置 | `base` 新增 `BENCH_LEVEL_EPS = 1e-6`（覆盖 extended/Double/Single 三种来源的表示差 ~1.2e-8，远小于相邻档位间距 ≥0.04）；`ConfidenceInterval` 三处 `>=` 改 `>= X - EPS`，`TInvAlpha` 两处 `<=` 改 `<= X + EPS`。scipy t 区间金标（CI95/CI99，tol 1e-3）+ Welch 布尔金标钉死。 |

---

## FPC RTL 隔离专项结论

| 检查面 | 结果 |
|--------|------|
| bench 源码直接 `uses` SysUtils/Classes/BaseUnix/… | **通过**（无命中） |
| 测试/示例直接 RTL | **通过**（抽检 + 契约 C5） |
| `core/benchmarks` RTL | 契约 C9 维护态曾全绿（B46） |
| 经 `system.classes` / `system.memmanager` 间接 RTL | **有**（并行 TThread、MM hook）——符合「只经 system 门面」，**不符合**「运行时与编译器完全无关」理想态 |
| 仅 `nextpas.core.system` 可触 RTL | system 子单元承担门面；bench **未越权直连** |

---

## 建议处理优先级（供共决，非本审查实施）

| 批次 | Findings | 理由 |
|------|----------|------|
| A · 语义诚实 | F-03, F-07, F-10 | 低改动、防 CI 误判，ROI 最高 |
| B · 超时真义 | F-04 + 测试 | 行为与 API 名对齐 |
| C · 全局状态 | F-02, F-05, F-08, F-09 | 并发/hook 边界 |
| D · 编译器无关 | F-01, F-17 | 大，需平台线程方案 |
| E · 卫生/对标 | F-15, F-16, F-19–F-26 | Idle 可分批文档 |

**明确不建议 Idle 默认做**：门面物理大拆（F-06 长期）、EBR（F-23）、全量 SCORECARD 刷新（F-20）。

---

## 审查方法（可复核）

1. 阅读 `ARCHITECTURE.md` / `CONTRACT.md` / `README.md` / `LANE-DUTY.md`
2. 解析全部 `nextpas.core.bench*.pas` 的 interface/implementation `uses`
3. 抽读 runner 并行桥、suite timeout、CompareGroups、memtrack hook
4. 统计 `IBenchResults` 方法数（77）、门面行数（~3264）
5. 测试目录 22 PROJECTS 体量与缺口对照
6. 示例/测试 RTL 字面扫描；SCORECARD 历史标记确认
7. **未**改任何 `.pas` 生产逻辑；本文件为唯一新增审查产物

---

## 状态

**Audit complete — Ready for prioritization.**
下一步由你方决定 A–E 批次是否立项；默认维护态可只收 A 类小修。
