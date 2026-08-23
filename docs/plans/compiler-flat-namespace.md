# compiler/ 现代化结构方案 v2——扁平命名 × 充分复用 nextpas.core × 模块化 × 高性能

状态：**Needs Review**（跨模块影响面大，先审查后动手；v2 按总控指令重写，
把「充分复用 core」与「高性能」升为一等目标，与命名扁平化并列四支柱）
日期：2026-08-23

## 0. 目标（总控指令）

1. 编译器必须**大量复用 nextpas.core**，建立高效的结构方案；
2. **充分模块化**，方便重构和扩展升级；
3. 架构朝**优雅和高性能**发展；
4. 命名统一 `nextpas.xx` / `nextpas.xx.xx` 扁平风格，全部进 `src/` 目录。

## 1. 审计结论（2026-08-23 实测数据）

### 1.1 core 复用现状矩阵

| core 模块 | 编译器 uses 数 | 判定 |
|-----------|---------------|------|
| collections.vec | 40 | ✅ 主力 |
| text.conv（含 .text.* 家族合计） | ~66 | ✅ 主力 |
| mem.intf | 22 | ✅ 主力 |
| path / fs.* | 15 / ~24 | ✅ 健康 |
| exception | 8 | ✅ 健康 |
| **collections.hashmap** | **3** | ⚠️ 仅两处名索引在用，其余查找点未走哈希 |
| **compiler.mem（官方 arena 通道）** | **2** | ⚠️ core 已铺好 unit 级 VirtualArena（mmap 增长、unit 边界 Reset），编译器几乎未接 |
| mem.allocator.arena | 1 | ❌ |
| collections.hashmap.swiss（i32i32/str 特化） | 0 | ❌ |
| collections.smallvec / bitset / deque / multimap / slice | 0 | ❌ |
| sync.* / async.taskgroup | 0 | ❌ 并行 sema 无底座 |

另：手搓 `SetLength` 动态数组扩容 **417 处**散布全部阶段。

### 1.2 热路径事实（修正此前判断）

- `TSemanticModel.FindSymbolByName` 与 body 名索引**已经走 core `THashMap`**
  （`FSymbolNameIndex` / `TProcedureBodyNameFirstMap = specialize THashMap<string,LongInt>`）
  ——主索引不是裸线性扫描；
- 但每次查找都执行 `LowerCase(AName)` **现场分配新字符串**再查哈希；
- 契约解析路径仍有 `LookupProcedureBody` 回退扫描 + 大量 `SameText`
  字符串比较；b4b-i17 又给泛型接收者成员调用增加了一次该路径；
- 全量实测：单线程 100% 单核、~3.3 函数体/秒、RSS 1.4 GB、15.6k 函数体。
  **精确耗时分布未知——任何优化动手前必须先测（P0）。**

### 1.3 结论

编译器对 core 是「用了但没吃透」：向量与文本转换已是主力，而哈希特化版、
arena、并发原语三大件基本闲置；同时 417 处手搓数组是重复造轮子的主要形态。
复用空间明确存在，且 core 侧无需为新需求大改——缺口在接线，不在存货。

## 2. 四支柱结构方案

### 支柱一：扁平命名与 src 统一目录

65 个 `np_*` 生产单元迁入 `compiler/src/`，改名
`nextpas.compiler.<area>.<topic>`；`.inc` 随宿主迁入但不改名。
完整映射表见 §5；迁移批次 N1–N6 见 §4。

### 支柱二：充分复用 nextpas.core（本版新增核心）

**复用原则**

| # | 原则 | 落点 |
|---|------|------|
| R1 | 数据结构只从 core 取，禁止手搓增长数组新实例 | 417 处 SetLength 按用途分流：顺序容器→vec/smallvec；键值→hashmap；去重→hashset；标志位→bitset；双端→deque |
| R2 | 内存生命周期 = unit 级 arena | 接通 `nextpas.core.compiler.mem` 官方通道：AST/语义模型/HIR 用 VirtualArena，unit 编译完 Reset 整体回收——治 1.4 GB 驻留 |
| R3 | 热点哈希用 swiss 特化版 | 符号 id→payload 这类整型键换 `hashmap.swiss.i32i32`；名索引换 `swiss.str`；泛型 `THashMap<string,…>` 只留冷路径 |
| R4 | 文本拼接走 text.builder/view | IR printer、诊断格式化等高频拼接待 P0 数据决定是否值得换 |
| R5 | 并行协调只走 core sync/async | waitgroup/mutex/taskgroup，不自旋自造 |
| R6 | 反向约束：core 不为编译器开特例 | 发现 core 缺口时修 core 本体（AGENTS「高层反哺低层」），不在编译器里堆 workaround |

**已知候选缺口**（待 P0 确认后再立项，不预先实现）：
case-fold 键缓存（消 per-lookup `LowerCase` 分配）、fat record 的 move 语义。

各阶段「需求 → 精确 core 单元与 API」的绑定矩阵见
`docs/plans/compiler-core-reuse-map.md`（含一套代码吃 FPC 创世与 np 自举
两代优化福利的机制说明）。

### 支柱三：分层依赖规则（模块化的硬边界）

编译器层与 core 层位对齐——**compiler Ln 只准依赖 core ≤Ln**：

```
L4 toolchain      → core ≤L4（可用 sync/async）
L3 backend / ir   → core ≤L3
L2 sema / frontend→ core ≤L2（collections/mem/text/path/fs）
L1 syntax         → core ≤L1（base/mem/text/collections）
L0 base.types / diagnostics / targets → core L0-L1
```

- 受控例外显式登记：`ir.hir.builder → sema.semantic_model` 一条 L3→L2 边
  （lowering 需要类型视图；切断需视图下沉层，独立立项，本方案挂账）；
- **门禁**：N 批每步落地后跑 source-contract 式 grep 断言（无越层 uses、
  无 `np_` 残留名），脚本进 `scripts/`，防回潮；
- 子模块职责划分维持规范冻结项不变（frontend/syntax/sema/ir/backend/
  targets/driver/diagnostics）。

### 支柱四：高性能批次（P 系列，测量先行）

| 批 | 内容 | 验收 |
|----|------|------|
| P0 测量 | 阶段计时探针（lex/parse/seed/sema/hir/emit/opt 各相耗时落日志）+ perf record 定位 3.3 体/秒去向；**单独量化 b4b-i17 新增 LookupProcedureBody 的开销占比** | 数字表进 ROADMAP 新列「全量分钟数」 |
| P1 索引与分配 | 残余线性扫描点清零（63 个 FindSymbolByName 调用点逐个审计）；per-lookup LowerCase 分配消除（存小写冗余键或 case-fold 缓存）；热点 hashmap 换 swiss 特化 | 全量分钟数下降；residual 保持 0/0 |
| P2 arena 化 | sema/HIR 接 `compiler.mem` VirtualArena，unit 边界 Reset | RSS 从 1.4 GB 显著下降；compiler-pass 58/58 |
| P3 并行 sema | 单元级并行：`np_parallel_scheduler` 接管 seed/sema，core sync.waitgroup 协调；语义模型写入面分区（每 unit 独立 arena 后合并） | 多核扩展比 ≥2（8 核机实测） |
| P4 增量缓存 | backend cache 单元级复用，未变单元免重编 | 基线刷新不再 2 小时级 |

P0 必须最先做：它决定 P1–P3 的真实优先级排序，避免凭感觉优化。
b4b-i17 的性能代价若被证实显著，P1 第一刀就地消掉它。

## 3. 批次交错节奏

命名迁移（N）是纯机械、行为零变化，可与性能批次安全交错：

```
N1(底层6单元) → N2(syntax) → P0(测量) → N3(frontend) → N4(sema+lower)
→ P1(索引) → N5(ir+backend) → P2(arena) → N6(toolchain+壳层+配置收口)
→ P3(并行) → P4(增量)
```

每批一个 commit；N 批验证门=rebuild+compiler-pass 58/58+contract grep；
P 批验证门=residual 保持 0/0+compiler-pass+全量分钟数对比。

## 4. 迁移批次明细（N 系列）

前提：每批结束 worktree clean、focused verification 通过、
`git diff --check` 通过、`make hygiene` 通过后才 commit。

| 批 | 内容 | 单元数 | 验证门 |
|----|------|--------|--------|
| N1 | base.types + targets + diagnostics（最底层） | 6 | rebuild + compiler-pass 58/58 + contract grep |
| N2 | syntax | 5 | 同上 |
| N3 | frontend | 14 | 同上 |
| N4 | sema + ir.hir.lowering | 13 | 同上 + mini-regress |
| N5 | ir + backend | 26 | 同上 + 全量 residual 对比 |
| N6 | toolchain + stage0 壳层(`nextpas.driver.*`) + 配置收口 | 17 | make verify 全量 |

每批操作模板：

1. `git mv` 单元文件到 `compiler/src/` 并改文件名；
2. 批量改写单元内部 `unit <旧名>;` 声明；
3. 全仓同步 `uses` 引用（源码 + inc + compiler/tests + tests/hir + stage0）；
4. 更新 `scripts/stage0-fpc-flags.sh` 与 `nextpas.package.toml`
   （N1 加入 `-Fucompiler/src`，N6 收口删旧旗标）;
5. 清 `.ppu/.o` 缓存后重建；
6. 跑验证门。

## 5. 完整映射表（65 单元）

### targets (1)

| 现名 | 新名 |
|------|------|
| np_target_facts | nextpas.compiler.targets.facts |

### diagnostics (4)

| 现名 | 新名 |
|------|------|
| np_diagnostics_sink | nextpas.compiler.diagnostics.sink |
| np_diagnostics_enhanced | nextpas.compiler.diagnostics.enhanced |
| np_diagnostics_json | nextpas.compiler.diagnostics.json |
| nextpas_json_helpers | nextpas.compiler.diagnostics.json_helpers |

### syntax (5)

| 现名 | 新名 |
|------|------|
| np_base_types* | nextpas.compiler.base.types |
| np_lexer | nextpas.compiler.syntax.lexer |
| np_green_tree | nextpas.compiler.syntax.green_tree |
| np_preprocessor | nextpas.compiler.syntax.preprocessor |
| np_ast_facade | nextpas.compiler.syntax.ast_facade |
| np_error_recovery | nextpas.compiler.syntax.error_recovery |

\* `np_base_types` 位于 sema 目录但被 syntax/sema 共用，是事实上的 L0，
提升为 `nextpas.compiler.base.types`。

### frontend (14)

| 现名 | 新名 |
|------|------|
| np_source_database | nextpas.compiler.frontend.source_database |
| np_unit_graph | nextpas.compiler.frontend.unit_graph |
| np_unit_resolver | nextpas.compiler.frontend.unit_resolver |
| np_compilation_session | nextpas.compiler.frontend.compilation_session |
| np_workspace_model | nextpas.compiler.frontend.workspace_model |
| np_symbol_cache | nextpas.compiler.frontend.symbol_cache |
| np_query_database | nextpas.compiler.frontend.query_database |
| np_package_manifest | nextpas.compiler.frontend.package_manifest |
| np_package_lock | nextpas.compiler.frontend.package_lock |
| np_package_workflow | nextpas.compiler.frontend.package_workflow |
| np_incremental_cache | nextpas.compiler.frontend.incremental_cache |
| np_file_change_detector | nextpas.compiler.frontend.file_change_detector |
| np_parallel_scheduler | nextpas.compiler.frontend.parallel_scheduler |
| np_compiler_phase | nextpas.compiler.frontend.compiler_phase |

### sema (12)

| 现名 | 新名 |
|------|------|
| np_semantic_model | nextpas.compiler.sema.semantic_model |
| np_semantic_analyzer | nextpas.compiler.sema.analyzer |
| np_sema_type_check | nextpas.compiler.sema.type_check |
| np_sema_overload | nextpas.compiler.sema.overload |
| np_sema_builtins | nextpas.compiler.sema.builtins |
| np_sema_name_set | nextpas.compiler.sema.name_set |
| np_sema_runtime_vars | nextpas.compiler.sema.runtime_vars |
| np_sema_string_ownership | nextpas.compiler.sema.string_ownership |
| np_semantic_field_meta_vec | nextpas.compiler.sema.field_meta_vec |
| np_semantic_interface_slot_vec | nextpas.compiler.sema.interface_slot_vec |
| np_semantic_property_meta_vec | nextpas.compiler.sema.property_meta_vec |
| np_semantic_vmt_slot_vec | nextpas.compiler.sema.vmt_slot_vec |

### lower (1)

| 现名 | 新名 |
|------|------|
| np_hir_lowering | nextpas.compiler.ir.hir.lowering |

### ir (25)

| 现名 | 新名 |
|------|------|
| np_hir_types | nextpas.compiler.ir.hir.types |
| np_hir_model | nextpas.compiler.ir.hir.model |
| np_hir_builder | nextpas.compiler.ir.hir.builder |
| np_hir_printer | nextpas.compiler.ir.hir.printer |
| np_hir_verifier | nextpas.compiler.ir.hir.verifier |
| np_hir_to_mir | nextpas.compiler.ir.hir.to_mir |
| np_hir_llvm_emitter | nextpas.compiler.ir.hir.llvm_emitter |
| np_mir_model | nextpas.compiler.ir.mir.model |
| np_mir_optimize | nextpas.compiler.ir.mir.optimize |
| np_mir_opt_level | nextpas.compiler.ir.mir.opt_level |
| np_mir_pass_registry | nextpas.compiler.ir.mir.pass.registry |
| np_mir_pass_constfold | nextpas.compiler.ir.mir.pass.constfold |
| np_mir_pass_cse | nextpas.compiler.ir.mir.pass.cse |
| np_mir_pass_dce | nextpas.compiler.ir.mir.pass.dce |
| np_mir_pass_deadarg | nextpas.compiler.ir.mir.pass.deadarg |
| np_mir_pass_devirt | nextpas.compiler.ir.mir.pass.devirt |
| np_mir_pass_escape | nextpas.compiler.ir.mir.pass.escape |
| np_mir_pass_inline | nextpas.compiler.ir.mir.pass.inline |
| np_mir_pass_inline_heuristic | nextpas.compiler.ir.mir.pass.inline_heuristic |
| np_mir_pass_licm | nextpas.compiler.ir.mir.pass.licm |
| np_mir_pass_strength_red | nextpas.compiler.ir.mir.pass.strength_red |
| np_mir_pass_tailcall | nextpas.compiler.ir.mir.pass.tailcall |
| np_mir_pass_vectorize | nextpas.compiler.ir.mir.pass.vectorize |
| np_mir_to_llvm | nextpas.compiler.ir.mir.to_llvm |
| np_system_contracts | nextpas.compiler.ir.system_contracts |

### backend (1)

| 现名 | 新名 |
|------|------|
| np_backend_plan | nextpas.compiler.backend.plan |

### toolchain (3)

| 现名 | 新名 |
|------|------|
| np_toolchain_runner | nextpas.compiler.toolchain.runner |
| np_toolchain_profiles | nextpas.compiler.toolchain.profiles |
| np_toolchain_plan | nextpas.compiler.toolchain.plan |

## 6. 风险与对策

| 风险 | 对策 |
|------|------|
| FPC dotted 单元解析 | 已被 core/src 全量证明 |
| np 自举解析新名 | unit resolver 按搜索路径找文件，dotted 机制已被 core 编译路径验证；N1 后立即 residual 探针编一次 tools/stage0 |
| 漏改 uses | 每批以旧名 grep 清零为完成条件 + contract grep 门禁脚本 |
| P 批引入行为变化 | residual 必须 0/0 保持 + compiler-pass 58/58；P0 数据先行，不做无测量优化 |
| arena 误用（悬垂指针） | 只接管 AST/模型/HIR 等树状所有权对象；跨 unit 存活数据仍走常规分配；leak_check/tracking allocator 抽检 |
| 并行化破坏语义模型不变量 | P3 前先做写入面审计；每 unit 独立 arena 分区合并；compiler-pass + mini-regress 全绿才进 |
| 半途不可构建态 | 批内一次性完成 mv+uses+配置；commit 即可构建态 |

## 7. 不变量

- `compiler/` 公开边界与子模块职责划分不变（规范冻结项）；
- N 批行为零变化，compiler-pass 数字不得回退；P 批 residual 保持 0/0；
- 双编译器兼容：每批后 FPC 能编 stage0、np 自举能编 stage0；
- core 不为编译器开特例（R6）；历史轨迹文档不改写。

## 8. 待总控决策项

1. 四支柱范围确认（命名+复用+分层门禁+性能是否全部立项）；
2. 批次交错节奏（§3）是否接受，还是 N 系列一口气打完再启 P 系列；
3. stage0 壳层归宿：`tools/stage0/` 内改 `nextpas.driver.*`（默认），
   或并入 `compiler/src/`；
4. `np_system_contracts` 归 ir（默认）或提升 base；
5. `.inc` 改名是否立项独立小批（默认不做）；
6. P2/P3 涉及内存所有权与并行模型的架构变更，若影响面超出 compiler lane，
   是否拆独立 cross-cutting lane（Needs Review 升级）。
