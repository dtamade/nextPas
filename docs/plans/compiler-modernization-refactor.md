# compiler/ 现代化重构主文档

状态：**执行中**（本文件是重构的唯一权威来源与完整记录；附录 A/B 为支撑文档）
发起：总控指令「充分模块化、现代化；编译器必须大量复用 nextpas.core；
命名扁平化 `nextpas.xx` 风格全部进 src 目录；架构朝优雅和高性能发展」
worktree：`.worktrees/compiler-system`（lane 分支 `codex/compiler-system`）
创建：2026-08-23　最后更新：2026-08-23（N2 落地后）

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

### 4.3 验收门定义（每批必过）

```bash
scripts/compiler-flat-contract.sh          # 旧名残留=0；禁入 core 家族=0
make rebuild-compiler                      # FPC 创世构建
make test TEST_FILTER=compiler-pass        # fixtures 58/58
./nextpas-m2-l3-probe build build/m2_mini_tree.pas … + 双步 opt   # np 自举解析
git diff --check && make hygiene
# N4+: mini-regress 13 探针；N5: 全量 residual 对比；N6: make verify
```

## 5. 完整映射表（65 单元；✅=已落地）

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

### 待迁移（55 单元）

**frontend(14)**：np_source_database/unit_graph/unit_resolver/
compilation_session/workspace_model/symbol_cache/query_database/
package_manifest/package_lock/package_workflow/incremental_cache/
file_change_detector/parallel_scheduler/compiler_phase
→ `nextpas.compiler.frontend.*`

**sema(12)**：np_semantic_model→sema.semantic_model；
np_semantic_analyzer→sema.analyzer；np_sema_type_check→sema.type_check；
np_sema_overload→sema.overload；np_sema_builtins→sema.builtins；
np_sema_name_set→sema.name_set；np_sema_runtime_vars→sema.runtime_vars；
np_sema_string_ownership→sema.string_ownership；
np_semantic_field_meta_vec→sema.field_meta_vec；
np_semantic_interface_slot_vec→sema.interface_slot_vec；
np_semantic_property_meta_vec→sema.property_meta_vec；
np_semantic_vmt_slot_vec→sema.vmt_slot_vec

**lower(1)**：np_hir_lowering→ir.hir.lowering

**ir(25)**：np_hir_types/model/builder/printer/verifier/to_mir/
llvm_emitter→ir.hir.{types,model,builder,printer,verifier,to_mir,
llvm_emitter}；np_mir_model/optimize/opt_level→ir.mir.{model,optimize,
opt_level}；np_mir_pass_{registry,constfold,cse,dce,deadarg,devirt,escape,
inline,inline_heuristic,licm,strength_red,tailcall,vectorize}
→ir.mir.pass.*；np_mir_to_llvm→ir.mir.to_llvm；
np_system_contracts→ir.system_contracts

**backend(1)**：np_backend_plan→backend.plan

**toolchain(3)**：np_toolchain_runner/profiles/plan→toolchain.{runner,
profiles,plan}

**stage0 壳层(N6)**：14 个 nextpas_* → `nextpas.driver.*`（留 tools/stage0，
本地 json_helpers 副本届时收口）

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

## 10. 附录

- 附录 A：`docs/plans/compiler-core-reuse-map.md`——core 能力地图×绑定矩阵
  （API 面核实、禁区、两代福利机制）
- 附录 B：本文档前身 `docs/plans/compiler-flat-namespace.md` v2
  （四支柱细化与待决策项 §8，其中未决项由本文件 §8 决策日志接管）
- 附录 C：ROADMAP `docs/plans/m2/ROADMAP.md`——undefined 归零战报与注³⁶
