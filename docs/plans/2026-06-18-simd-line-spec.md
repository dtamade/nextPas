# SIMD 工作线 — 任务规格

## 目标

维护和收尾 `nextpas.core.simd` 模块。SIMD 模块已高度成熟，主要剩余工作是 G21 NEON 基准完成和门控变量简化。

## 当前状态

- G1-G20 全部 100% 完成
- ~13,900+ 测试，全部通过，0 泄漏
- 对 system 模块：零依赖
- SysUtils/Math 依赖：已全部清零
- 状态: `code-green / cross-ready`

## 你的工作区

```bash
cd /home/dtamade/projects/nextPas/.worktrees/core-simd-perf
```

分支: `codex/core-simd-perf`

## 剩余工作

### P0: G21 NEON AArch64 覆盖度基准 ⏱️ 1-2 天

**当前**: benchmark 文件已存在 (`bench_neon_coverage.lpr`, `bench_neon_vs_scalar.lpr`)，执行中。

**任务**：
1. 运行 NEON vs Scalar 基准，收集性能数据
2. 分析 NEON 覆盖度：哪些操作有 NEON 加速，哪些回退到 scalar
3. 记录 NEON 性能提升比例
4. 更新 `docs/simd/GOAL_TREE.md` G21 状态为完成

**验收**：
- [ ] NEON coverage benchmark 可运行
- [ ] 性能数据已记录
- [ ] 文档已更新

### P1: NEON asm 三重门控变量简化评估 ⏱️ 1 天

**当前**: NEON inline asm 需要三重 define 才能启用：
- `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM`
- `NEXTPAS_SIMD_ENABLE_NEON_ASM`
- `NEXTPAS_SIMD_NEON_ASM_COMPILER_READY`

**任务**：
1. 评估是否可以简化为单重或双重门控
2. 检查 FPC trunk 是否已修复 NEON asm 编译器限制
3. 如果可以简化，实施并更新文档

### P2: 文档统计数据自动化刷新 ⏱️ 1 天

**任务**：
1. 运行 slot 计数脚本，更新文档中的覆盖数字
2. 确保 `implementation-matrix.md` 中的 non-x86/x86 数据准确
3. 更新 `GOAL_TREE.md` 中的完成状态

### P3: 准备 Landing ⏱️ 1 天

**任务**：
1. 运行 `closeout-release` 完整收口
2. 确认 `freeze-status` 仍为 `ready=True`
3. 准备 landing candidate

## 不必做的工作

以下工作**不要启动**，保持现状：

- ❌ 不重新生成 simdgen（已知 drift，手动维护更安全）
- ❌ 不修改 SSE2 嵌套函数结构（已到 FPC 31 嵌套限制）
- ❌ 不将 NEON 默认启用（保持 opt-in）
- ❌ 不清理 `asm_suffix_only=10`（有意保留的 shift contract wrapper）

## 必读文档

1. `core/docs/simd/README.md` — 模块总览
2. `core/docs/simd/GOAL_TREE.md` — 目标树 G1-G21
3. `core/docs/simd/closeout.md` — 收尾与回归矩阵
4. `core/docs/simd/maintenance.md` — 维护策略与技术债务清单
5. `core/docs/simd/checklist.md` — 日常/发布门禁命令
6. `core/docs/design-conventions.md` — 框架设计规范

## 工作纪律

1. SIMD 模块处于维护模式，改动要最小化
2. 每次改动后运行：`bash core/tests/nextpas.core.simd/BuildOrTest.sh gate`
3. 0 leaks + `make hygiene` PASS
4. git commit 要有意义的 commit message

## 常用命令

```bash
cd /home/dtamade/projects/nextPas/.worktrees/core-simd-perf

# 快门禁（编译卫生 + 基础回归 + 接口完整度）
bash core/tests/nextpas.core.simd/BuildOrTest.sh gate

# 严格门禁
bash core/tests/nextpas.core.simd/BuildOrTest.sh gate-strict

# host-local closeout
bash core/tests/nextpas.core.simd/BuildOrTest.sh closeout-host-local

# 完整 release 收口
bash core/tests/nextpas.core.simd/BuildOrTest.sh closeout-release

# 卫生检查
make hygiene
```
