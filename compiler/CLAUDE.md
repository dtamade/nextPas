# compiler/CLAUDE.md — 编译器工程治理

## 模块结构

```
compiler/
├── frontend/     ← 编译会话、包管理、单元图、搜索路径
├── syntax/       ← Lexer、Preprocessor、Green Tree、AST Facade
├── sema/         ← 语义分析器、语义模型
├── lower/        ← AST→HIR 降级桥接层 (sema→ir)
├── ir/           ← HIR Builder、HIR Model、LLVM Emitter、Verifier
├── backend/      ← 后端计划、代码生成
├── diagnostics/  ← 诊断基础设施
├── targets/      ← 目标平台配置
└── tests/        ← 编译器单元测试
```

## 模块契约

### 边界规则
- **frontend** 不依赖 sema/ir/backend（只提供编译会话和解析基础设施）
- **syntax** 不依赖 sema/ir/backend（纯语法分析）
- **sema** 依赖 syntax/frontend，不依赖 ir/backend/lower
- **lower** 依赖 sema/ir/frontend（桥接层，AST→HIR 降级）
- **ir** 依赖 lower/frontend，不依赖 backend
- **backend** 依赖 ir/frontend
- **diagnostics** 和 **targets** 被所有模块依赖

### 代码规范
- 所有文件必须有 `{$mode ObjFPC}{$H+}`
- 类型前缀：`T` record/class, `I` interface, `E` exception
- 变量前缀：`L` local, `A` parameter, `F` field
- 2-space 缩进
- 函数不超过 100 行（超过必须拆分）

### np_semantic_analyzer.pas 治理
主文件已拆薄为 ~584 行门面 + 40 余个 `.inc`/子单元（sema 目录合计 ~26k 行，
最大热点：`np_sema_walk_halt_calls.inc`、`np_sema_declaration.inc`、`np_sema_codegen.inc`）。
已完成提取:
- `np_sema_builtins.pas` — 内置函数注册表 (~500 行) [✅]
- `np_sema_string_ownership.pas` — 字符串所有权分析 (~836 行) [✅]
- `np_sema_name_set.pas` — 名称集合查找 (O(log n), ~100 行) [✅]

骨架模块（AL2 补全）:
- `np_sema_overload.pas` — 重载解析 (83 行骨架)
- `np_sema_type_check.pas` — 类型检查 (58 行骨架)

已迁移:
- `np_sema_hir_lowering.pas` → `lower/np_hir_lowering.pas` — AST→HIR 降级 [✅ 2026-07-06]

已删除过时文件:
- `np_sema_runtime_expr.inc` (3,345 行) — WalkHaltCalls 副本，已与主文件合并

## 质量门禁

### 提交前必须通过
1. `make test TEST_FILTER=compiler-pass` — 全绿（当前基线 53+ fixtures，以 fresh 运行为准）
2. `make test TEST_FILTER=compiler-fail` — snapshot 匹配
3. `make hygiene` — 无散落产物
4. `scripts/rebuild-compiler.sh` — 编译器重建成功

### 代码变更流程
1. **分析** — 先读相关代码，理解上下文
2. **计划** — 明确改什么、为什么改、影响范围
3. **实现** — 最小改动原则
4. **验证** — 通过所有质量门禁
5. **提交** — 有意义的 commit message

### 测试要求
- 新增功能必须有对应测试
- bug 修复必须有回归测试
- 测试放在 `compiler/tests/` 或 `tests/compiler/`

## 编译器 CLI

```bash
# 编译单个文件
build/stage0-bootstrap/nextpas build <source> --target linux-x86_64 --workspace .worktrees/compiler

# 重建编译器
scripts/rebuild-compiler.sh

# C8 全量扫描
bash scripts/c8_scan.sh
```

## 当前状态 (2026-07-26)

> 权威路线：`docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`（M0–M9）。
> 状态语言纪律：未通过 promotion gate 的能力只能写 `skeleton` / `experimental` /
> `integrated`，不能写 `complete` / `production-ready`。

### 里程碑（M 系列）
- M0 truth recovery: 🏗️ 进行中（deliverable 4 cache-root 隔离未完成；其余 gate 绿）
- M1 bootstrap contract: 🏗️ typed families 渐进迁移中（object-free、process init/fini、
  string triad、dynarray、interface、halt 已由 `TSystemContractKind` 控制；其余 residual 待迁移）
- M2 两跳自举: 🔴 **当前主战场** — M2-0 harness ✅、M2-1 ladder L0–L2 ✅、
  M2-2 (L3 = full stage0 driver A→B link) 进行中；卡在 `opt` 阶段 residual
  undefined symbols（2026-07-26 实测 80 unique / 251 total）。
  **唯一执行入口：`docs/plans/m2/ROADMAP.md`（咬合队列 B0–B8）**；
  探针：`scripts/m2-l3-residual.sh`
- M3+ (kernel/query/parallel/MIR/self-host): 🔲 未开始；slice 9（M2 闭合）之前禁止启动

### 基线 gate（fresh 证据，2026-07-13 起）
- compiler-pass 53/53（fresh + immediate repeat；非 cold/warm 证明）+ compiler-fail 16/16
- `make rebuild-compiler` → `rebuild-compiler=pass`
- NPC V2 framing 14/14 + 五阶段 fail-closed incremental gate
- 生产代码生成路径 = Typed HIR → LLVM（`ir/np_hir_llvm_emitter*`）→ opt/llc/ld；
  **MIR/backend plan 是 experimental skeleton，不作为 gen-B 正确性证据**（F-012）

### 主要债务（P0 阻断级，详见审计 findings F-001~F-022）
- F-001: M2 L3 A→B 未闭合（residual undefined symbols 分桶清理中）
- F-002: permissive overload resolution（last-wins）会静默绑错 body — 需唯一最优否则诊断
- F-003: system kernel 并发原语假实现（空 EnterCriticalSection / 非原子 Interlocked*）
- sema 体量债务（~23k LOC）：Wave0 冻结决定「不并行大拆」，M2 闭合后再做

## M2 探针命令

```bash
./scripts/m2-l3-residual.sh                 # L3 进度唯一度量：rebuild + build + 分桶
./scripts/m2-l3-residual.sh --analyze-only  # 秒级复查现有 nextpas.ll
make m2-two-hop            # a-ready + llvm-smoke
make m2-ladder             # L0-L2 ladder
```

## 已知技术债
- ~~IsBuiltinProcedure 函数列表过长（150+ 函数），需重构为注册表~~ ✅ 已完成
- ~~IsDeferredSystemObjectMember 扩展过多（30+ 方法），需接口方法解析~~ ✅ 已清理并组织
- ~~sema 17,735 行需拆分~~ ✅ 已拆分为 3 文件 (12,175 + 2,217 + 3,345)
- ~~C6-H4 owned string return 限制需编译器级修复~~ ✅ 已完成 (2026-07-03)
- ~~C5 `{$IFDEF}` 预处理器支持~~ ✅ 已完成 (2026-07-03)
- Permissive overload resolution（last-wins）：F-002，M2 Wave1 收紧为唯一最优否则诊断
- sema 主文件仍需继续拆分（目标 <8000）；Wave0 冻结：M2 闭合前不做大拆

## 治理关联
- 项目总控计划: `PLAN.md`
- 总控目标树: `docs/plans/goal-tree.md`（v2.5, AL 阶段地图）
- **当前编译器执行计划**: `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`（M0–M9 权威）
- M2 执行输入: `docs/plans/m2/ROADMAP.md`（**唯一执行入口**）+ `README.md`
- 稳定架构规格: `docs/architecture/compiler-roadmap.md`、`compiler-pipeline-specification.md`
- 历史快照（不再是当前计划）: `compiler/docs/compiler-goal-tree.md`（C0–D8 时代）、
  `docs/plans/selfhost-roadmap.md`、`docs/plans/debt-roadmap.md`、
  `docs/plans/compiler-architecture-plan.md`
