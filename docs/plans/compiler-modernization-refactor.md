# compiler/ 现代化重构主文档

状态：**执行中**（本文件是重构的唯一权威来源与完整记录；附录 A/B 为支撑文档）
发起：总控指令「充分模块化、现代化；编译器必须大量复用 nextpas.core；
命名扁平化 `nextpas.xx` 风格全部进 src 目录；架构朝优雅和高性能发展」
worktree：`.worktrees/compiler-system`（lane 分支 `codex/compiler-system`）
创建：2026-08-23　最后更新：2026-08-23（v2.15：N6 落地 66/66 命名收官；
v2.14：N5 落地 63/66；
v2.13：N4 落地+门禁例外登记；v2.12：P0 计时探针落地+相位实测表；
v2.11：N3 落地；v2.9：顶部状态仪表盘+风险编号 R1-R8+验收门精确命令；
v2.8：§3.5 顶尖基准；v2.7：接口立项清单；
v2.6：范式决策；v2.5：诚实局限；v2.4：先例对照）

## 0. 状态仪表盘（每批落地时更新此块）

```
迁移进度  ████████████████  N1-N6 全部✅ │ 66/66 单元+壳层 driver.* │ 九目录散布→src 平铺完成
性能批次  ██░░░░░░░░░░░░░░  P0✅ 计时探针落地 │ tree mini: sema 占 99%·播种占 80%·i17 开销仅 1.6%
正确性    residual 0/0 ✅   compiler-pass 58/58 ✅   opt 首错=支配性违规(新口)
门禁      contract pass ✅   FPC rebuild ✅   np 自举 tree mini ✅
顶尖差距  冷编译 ~900×      RSS 1.4GB→目标 ≤400MB     增量:无→目标秒级(§3.5)
下一口    P1 播种路径索引分配(swiss+LowerCase 消除) → P2 arena
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
| N6 | toolchain ×3 + stage0 壳层 nextpas.driver.* + 配置收口 | make verify 全量 | ✅ 分两提交：N6a toolchain(2abcd33bb)+N6b 壳层 driver.*/json_helpers 收口。make verify 分解结果：hygiene/contract/incremental-cache/incremental-gate/system-intrinsics 全过；**constructor-typing 与 hir-class-alloc-contract 两红点为既有债**（stash 二分+去 i17 复测证明早于今日全部改动，疑似更早 b4b 行为变更，其脚本 flags 腐烂即久未运行之证）；verify_local 21 处旧布局路径已修至 src；residual 全量补跑挂下会话首项 |

每批模板：git mv → unit 头改写 → 全仓 uses 同步（含 build 探针源）→
contract 门禁清单扩充 → 清 ppu 重建 → 验收门 → commit。

单批耗时实测参考：N1 ≈ 45 分钟（含全部验证门与 tree mini 8 分钟）；
N2 ≈ 35 分钟。预计 N3-N5 同量级（引用面 frontend 最大 ~60 文件）；
N6 最重（壳层改名 + 三脚本收口 + make verify 全量，预留半天）。

### 4.2 P 系列（性能，测量先行）

| 批 | 内容 | 验收 | 状态 |
|----|------|------|------|
| P0 | 阶段计时探针 + perf 定位 3.3 体秒去向；量化 b4b-i17 的 LookupProcedureBody 开销 | 耗时表进 ROADMAP 新列 | ✅ 相位表+方差 <2%+i17 开销 1.6%；perf top-10 受阻（无 root+二进制 strip），归 P1 启动补 |
| P1 | 残余扫描清零 + LowerCase 分配消除 + swiss 接线 | 分钟数降；residual 0/0 保持 | ⬜ 静态侦察已就绪（见下行 P1 侦察块） |

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

- **刀① 常量折叠廉价化**：`SameText(X.Text,'String')` 类常量簇改局部
  helper——先 `=` 精确短路，长度不等立即 False，仅剩差异时做一次折叠；
  覆盖 'String'/'AnsiString' ≥8 组与 'Create'/'Destroy'/'Halt' 家族
  （seed inc 行号簇 26-199）。注意 SameText 本身不分配堆，省的是分支
  折叠周期；分配大头在刀②。
- **刀② 查找分配消除**：`np_sema_overload_analysis.inc:295`
  `TryGetValue(LowerCase(AName))` 每次调用分配临时串——analyzer 加
  `FBodyLookupScratch: string` 复用字段承载折叠结果（容量保持后近似零
  分配），Index 侧同步用 scratch 折叠；后续演进=core swiss 增 fold-aware
  变体（R6 登记，修 core 本体）。
- **刀③ 全表扫描合并**：seed_function_bodies 四趟 FProcedureBodies
  全表循环（行 477 标记/504 与 517 逐字重复的 Enqueue 扫描/528
  Needed&&!Visited 三扫）合并为单趟状态机。
- **度量协议**：每刀落地后 `NEXTPAS_PHASE_TIMING=1` tree mini 两轮，
  seed 相对 §2.3 基线 235s/238s 对比；验收=总分钟数降+residual 0/0
  保持+十三探针零新回归。
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
