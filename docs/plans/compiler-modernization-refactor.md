# compiler/ 现代化重构主文档

状态：**执行中**（本文件是重构的唯一权威来源与完整记录；附录 A/B 为支撑文档）
发起：总控指令「充分模块化、现代化；编译器必须大量复用 nextpas.core；
命名扁平化 `nextpas.xx` 风格全部进 src 目录；架构朝优雅和高性能发展」
worktree：`.worktrees/compiler-system`（lane 分支 `codex/compiler-system`）
创建：2026-08-23　最后更新：2026-08-23（v2 完善：目录对照树、命名细则、
映射全表展开 66 单元、P0 设计草案、维护规则；计数修正 66=10+56）

---

## 1. 重构目标（不可妥协项）

| # | 目标 | 度量 |
|---|------|------|
| G1 | 命名统一 `nextpas.compiler.<area>.<topic>` 点分扁平 | 65 单元零 `np_` 残留（contract 门禁断言） |
| G2 | 全部生产单元进 `compiler/src/` 平铺 | 九个散布目录清空 |
| G3 | 充分复用 nextpas.core，禁止重复造轮子 | 绑定矩阵落地；SetLength 手搓数组不再新增 |
| G4 | 模块化分层硬边界 | compiler Ln 只依赖 core ≤Ln；受控例外显式登记 |
| G5 | 高性能 | 全量构建分钟数只降不升；residual 保持 0/0 |
| G6 | 行为零变化（N 批）/ 可测量改进（P 批） | compiler-pass 58/58 恒定 |

**一套代码吃两代福利**：所有绑定都落在 core 上——FPC 创世期 core 优化直接
加速编译器构建；np 自举期 core 的代码生成优化反过来加速自举。飞轮成立，
零二次移植。

## 2. 现状审计基线（2026-08-23 实测）

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

## 3. 四支柱方案

```
支柱一 扁平命名      65 单元 → compiler/src/ 点分名（N1-N6 机械迁移）
支柱二 复用 core     R1 数据结构只取 core / R2 unit 级 arena /
                     R3 swiss 特化热表 / R4 text.builder 拼接 /
                     R5 并发只走 core 原语 / R6 缺口修 core 本体不开特例
支柱三 分层硬边界    compiler Ln → core ≤Ln；ir.hir.builder→sema.model 一条
                     受控例外；contract 门禁脚本防回潮
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

### 4.2 P 系列（性能，测量先行）

| 批 | 内容 | 验收 | 状态 |
|----|------|------|------|
| P0 | 阶段计时探针 + perf 定位 3.3 体秒去向；量化 b4b-i17 的 LookupProcedureBody 开销 | 耗时表进 ROADMAP 新列 | ⬜ 下一起点 |
| P1 | 残余扫描清零 + LowerCase 分配消除 + swiss 接线 | 分钟数降；residual 0/0 保持 | ⬜ |
| P2 | sema/HIR 接 compiler.mem UnitScope/SessionScope | RSS 显著降 | ⬜ |
| P3 | 单元级并行 sema（parallel_scheduler+sync.waitgroup） | 多核扩展比 ≥2 | ⬜ |
| P4 | backend cache 单元级复用 | 基线刷新脱离 2 小时级 | ⬜ |

节奏：N1→N2→**P0**→N3→N4→P1→N5→P2→N6→P3→P4。

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
scripts/compiler-flat-contract.sh          # 旧名残留=0；禁入 core 家族=0
make rebuild-compiler                      # FPC 创世构建
make test TEST_FILTER=compiler-pass        # fixtures 58/58
./nextpas-m2-l3-probe build build/m2_mini_tree.pas … + 双步 opt   # np 自举解析
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

## 7. 风险登记册

| 风险 | 对策 | 状态 |
|------|------|------|
| FPC dotted 解析 | core/src 全量背书 | ✅ 关闭 |
| np 自举解析新名 | tree mini 每批实证 | ✅ 机制关闭，逐批复跑 |
| 漏改 uses | 旧名 grep 清零 + contract 门禁 | 运行中 |
| 半途不可构建态 | 批内一次性完成，commit 即可构建态 | 运行中 |
| P 批行为变化 | residual 0/0 保持 + 测量先行 | 待 P0 |
| arena 悬垂指针 | 只接管树状所有权对象；leak_check 抽检 | 待 P2 |
| 并行破坏模型不变量 | 写入面审计 + 每 unit 独立 arena 合并 | 待 P3 |
| rtl lane 的 np_ 家族与本方案冲突 | rtl 改名归 rtl lane；compiler 只消费不拥有 | 监控 |

## 8. 决策日志

| 日期 | 决策 | 依据 |
|------|------|------|
| 2026-08-23 | 四支柱范围全立项，节奏按 §4.2 交错 | 总控指令 |
| 2026-08-23 | inc 不改名随宿主迁入 | 收益/diff 权衡 |
| 2026-08-23 | stage0 壳层留 tools/stage0 改 nextpas.driver.*（N6） | 默认项未被推翻 |
| 2026-08-23 | np_system_contracts 归 ir.system_contracts | 与消费方一致 |
| 2026-08-23 | units 陈旧副本删除属迁移正当范围 | D4 证据链 |

## 9. 回滚策略

每批独立 commit、行为零变化、验证门齐全——任一批可独立 revert 回到
上一可构建态；N 批间无交叉依赖（自底向上顺序仅保证 uses 引用单调收敛）。
P 批引入运行时行为前必须先落 P0 基线数字，回滚判据客观化。

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
