# compiler/ 现代化重构主文档

状态：**执行中**（本文件是重构的唯一权威来源与完整记录；附录 A/B 为支撑文档）
发起：总控指令「充分模块化、现代化；编译器必须大量复用 nextpas.core；
命名扁平化 `nextpas.xx` 风格全部进 src 目录；架构朝优雅和高性能发展」
worktree：`.worktrees/compiler-system`（lane 分支 `codex/compiler-system`）
创建：2026-08-23　最后更新：2026-08-23（v2.9：顶部状态仪表盘+风险编号
R1-R8+验收门精确命令；v2.8：§3.5 顶尖基准；v2.7：接口立项清单；
v2.6：范式决策；v2.5：诚实局限；v2.4：先例对照）

## 0. 状态仪表盘（每批落地时更新此块）

```
迁移进度  ██████░░░░░░░░░░  N1✅ N2✅ │ 10/66 单元 │ compiler/src 22 文件
性能批次  ░░░░░░░░░░░░░░░░░  P0 待启动（下一插入点，N3 后）
正确性    residual 0/0 ✅   compiler-pass 58/58 ✅   opt 首错=支配性违规(新口)
门禁      contract pass ✅   FPC rebuild ✅   np 自举 tree mini ✅
顶尖差距  冷编译 ~900×      RSS 1.4GB→目标 ≤400MB     增量:无→目标秒级(§3.5)
下一口    N3 frontend×14 → P0 阶段计时探针
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
精确阶段耗时分布未知——P0 前禁止凭感觉优化。

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
迁移现状（v2.9 时点）：syntax/diagnostics/targets 已清空，src 持 22 文件；
实时进度以顶部 §0 仪表盘与 `§2.0 复现块`第二条命令为准。

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
                     contract 门禁脚本已实现（覆盖 src 随批扩展）
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
| N3 | frontend ×14 | 同上 | ⬜ |
| N4 | sema ×12 + ir.hir.lowering | +mini-regress | ⬜ |
| N5 | ir ×25 + backend.plan | +全量 residual 对比 | ⬜ |
| N6 | toolchain ×3 + stage0 壳层 nextpas.driver.* + 配置收口 | make verify 全量 | ⬜ |

每批模板：git mv → unit 头改写 → 全仓 uses 同步（含 build 探针源）→
contract 门禁清单扩充 → 清 ppu 重建 → 验收门 → commit。

单批耗时实测参考：N1 ≈ 45 分钟（含全部验证门与 tree mini 8 分钟）；
N2 ≈ 35 分钟。预计 N3-N5 同量级（引用面 frontend 最大 ~60 文件）；
N6 最重（壳层改名 + 三脚本收口 + make verify 全量，预留半天）。

### 4.2 P 系列（性能，测量先行）

| 批 | 内容 | 验收 | 状态 |
|----|------|------|------|
| P0 | 阶段计时探针 + perf 定位 3.3 体秒去向；量化 b4b-i17 的 LookupProcedureBody 开销 | 耗时表进 ROADMAP 新列 | ⬜ 下一起点 |
| P1 | 残余扫描清零 + LowerCase 分配消除 + swiss 接线 | 分钟数降；residual 0/0 保持 | ⬜ |
| P2 | sema/HIR 接 compiler.mem UnitScope/SessionScope | RSS 显著降 | ⬜ |
| P3 | 单元级并行 sema（parallel_scheduler+sync.waitgroup） | **前置：分区 ID 语义设计 spike（L2）**；通过后端到端 ≥2×（44 逻辑核，seed 相目标近线性） | ⬜ 受 L2 约束 |
| P4 | backend cache 单元级复用 | 基线刷新脱离 2 小时级 | ⬜ |

节奏：N1→N2→**P0**→N3→N4→P1→N5→P2→N6→P3→P4（各阶段量化目标见 §3.5，
P5+ 地平线批次见 §3.5.3）。

### 4.2.1 P0 阶段计时探针设计草案

- **打点位置**（复用 SemaTrace 冷路径先例——写文件不算热 walk）：
  `lex`（lexer 进入/退出）、`parse`（green_tree 构建）、`resolution`
  （unit_resolver 全程）、`seed`（SeedFunctionBodies 进度已有日志，改为
  带时间戳）、`sema-per-unit`、`hir-build`、`emit-llvm`、尾部
  `opt -O2 / verify` 由 residual 脚本计时；
- **输出**：`/tmp/m2-phase-timing.tsv`（phase,unit?,ms），会话结束汇总一行
  进构建日志；默认关闭，环境变量 `NEXTPAS_PHASE_TIMING=1` 开启；
- **交付物**：①各相耗时占比表进本文件 §2.3 与 ROADMAP 新列；
  ②perf record 采样 top-10 热函数清单；③b4b-i17 LookupProcedureBody
  开销专项数字（对比 i16 探针二进制同输入耗时）；
- **验收**：三件套齐 + 数字可复现（同输入两次运行偏差 <10%）。

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
已落地 **10**，待迁 **56**。

### 已完成 ✅（N1+N2，10 单元 + 12 inc）

| 新名 | 原位置 |
|------|--------|
| nextpas.compiler.targets.facts | targets/np_target_facts |
| nextpas.compiler.diagnostics.sink | diagnostics/np_diagnostics_sink |
| nextpas.compiler.diagnostics.enhanced | diagnostics/np_diagnostics_enhanced |
| nextpas.compiler.diagnostics.json | diagnostics/np_diagnostics_json |
| nextpas.compiler.diagnostics.json_helpers | diagnostics/nextpas_json_helpers |
| nextpas.compiler.syntax.lexer | syntax/np_lexer |
| nextpas.compiler.syntax.green_tree | syntax/np_green_tree |
| nextpas.compiler.syntax.preprocessor | syntax/np_preprocessor |
| nextpas.compiler.syntax.ast_facade | syntax/np_ast_facade |
| nextpas.compiler.syntax.error_recovery | syntax/np_error_recovery |

inc 随宿主迁入不改名（sink accessors ×1；syntax 家族 ×11）。

### 待迁移（56 单元）

#### frontend(14) → nextpas.compiler.frontend.*（N3 批）

| 现名 | 新名 |
|------|------|
| np_source_database | …frontend.source_database |
| np_unit_graph | …frontend.unit_graph |
| np_unit_resolver | …frontend.unit_resolver |
| np_compilation_session | …frontend.compilation_session |
| np_workspace_model | …frontend.workspace_model |
| np_symbol_cache | …frontend.symbol_cache |
| np_query_database | …frontend.query_database |
| np_package_manifest | …frontend.package_manifest |
| np_package_lock | …frontend.package_lock |
| np_package_workflow | …frontend.package_workflow |
| np_incremental_cache | …frontend.incremental_cache |
| np_file_change_detector | …frontend.file_change_detector |
| np_parallel_scheduler | …frontend.parallel_scheduler |
| np_compiler_phase | …frontend.compiler_phase |

（表中 `…` = `nextpas.compiler`，下同。）

#### sema(12) → nextpas.compiler.sema.*（N4 批）

| 现名 | 新名 |
|------|------|
| np_semantic_model | …sema.semantic_model |
| np_semantic_analyzer | …sema.analyzer |
| np_sema_type_check | …sema.type_check |
| np_sema_overload | …sema.overload |
| np_sema_builtins | …sema.builtins |
| np_sema_name_set | …sema.name_set |
| np_sema_runtime_vars | …sema.runtime_vars |
| np_sema_string_ownership | …sema.string_ownership |
| np_semantic_field_meta_vec | …sema.field_meta_vec |
| np_semantic_interface_slot_vec | …sema.interface_slot_vec |
| np_semantic_property_meta_vec | …sema.property_meta_vec |
| np_semantic_vmt_slot_vec | …sema.vmt_slot_vec |

#### lower(1) + ir(25) → nextpas.compiler.ir.*（N4/N5 批）

| 现名 | 新名 | 批 |
|------|------|----|
| np_hir_lowering | …ir.hir.lowering | N4 |
| np_hir_types | …ir.hir.types | N5 |
| np_hir_model | …ir.hir.model | N5 |
| np_hir_builder | …ir.hir.builder | N5 |
| np_hir_printer | …ir.hir.printer | N5 |
| np_hir_verifier | …ir.hir.verifier | N5 |
| np_hir_to_mir | …ir.hir.to_mir | N5 |
| np_hir_llvm_emitter | …ir.hir.llvm_emitter | N5 |
| np_system_contracts | …ir.system_contracts | N5 |
| np_mir_model | …ir.mir.model | N5 |
| np_mir_optimize | …ir.mir.optimize | N5 |
| np_mir_opt_level | …ir.mir.opt_level | N5 |
| np_mir_pass_registry | …ir.mir.pass.registry | N5 |
| np_mir_pass_constfold | …ir.mir.pass.constfold | N5 |
| np_mir_pass_cse | …ir.mir.pass.cse | N5 |
| np_mir_pass_dce | …ir.mir.pass.dce | N5 |
| np_mir_pass_deadarg | …ir.mir.pass.deadarg | N5 |
| np_mir_pass_devirt | …ir.mir.pass.devirt | N5 |
| np_mir_pass_escape | …ir.mir.pass.escape | N5 |
| np_mir_pass_inline | …ir.mir.pass.inline | N5 |
| np_mir_pass_inline_heuristic | …ir.mir.pass.inline_heuristic | N5 |
| np_mir_pass_licm | …ir.mir.pass.licm | N5 |
| np_mir_pass_strength_red | …ir.mir.pass.strength_red | N5 |
| np_mir_pass_tailcall | …ir.mir.pass.tailcall | N5 |
| np_mir_pass_vectorize | …ir.mir.pass.vectorize | N5 |
| np_mir_to_llvm | …ir.mir.to_llvm | N5 |

#### backend(1) + toolchain(3)（N5/N6 批）

| 现名 | 新名 | 批 |
|------|------|----|
| np_backend_plan | …backend.plan | N5 |
| np_toolchain_runner | …toolchain.runner | N6 |
| np_toolchain_profiles | …toolchain.profiles | N6 |
| np_toolchain_plan | …toolchain.plan | N6 |

#### stage0 壳层 14 单元 → nextpas.driver.*（N6 批，留 tools/stage0）

nextpas_projection_types/context/json/text、nextpas_command_{build,test,
env,doctor,query,pkg}、nextpas_command_envelope、nextpas_json_helpers
（本地副本届时与 src 版二选一收口）、target_config、nextpas.pas 入口。

inc 随宿主迁入不改名（sink accessors ×1；syntax 家族 ×11 已迁；
sema ×33 / ir ×16 / frontend ×7 / 其余随各批）。

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
| v2.9 | （本提交） | 可用性收尾轮：§0 顶部状态仪表盘（每批更新）、风险册编号 R1-R7b-R8、§4.3 验收门精确复现命令（tree mini 全命令）、§2.4 迁移现状标注——此后文档冻结进执行节奏，边际工作转向 N3/P0 |

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
