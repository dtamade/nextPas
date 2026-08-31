# SIMD 模块工作方法论

> 最后更新: 2026-08-31

## 核心原则

**按图施工，文档驱动，增量验证**
主线图: [roadmap.md](roadmap.md)。当前阶段清单: [plan.md](plan.md)。

## 工作流程

1. **对齐路线图** — 确认当前 phase、非目标与验收
2. **最小调研** — 只读与本 phase 相关的源/契约/测试
3. **增量实施** — 一个逻辑单元一个 commit；禁止假 wrapper
4. **验证** — 用 roadmap §6 清单；触及公共 API 后以 api-coverage 为硬门（Phase 21 起）
5. **收口** — 更新 roadmap 状态行 + plan 清单 + 必要 design；Ready 汇报

重大范围变更：先改 roadmap，再动代码。

## 文档要求

### 必需文档
1. **路线图** (`roadmap.md`) — 权威主线（目标/交付/依赖/优先级/验收）
2. **计划** (`plan.md`) — 当前阶段薄任务清单
3. **设计** (`architecture.md` / `design/*`) — 稳定或专项设计事实
4. **入口** (`README.md`) — 现状摘要与索引

### 文档更新规则
- 路线图：每 phase 收口更新状态；主线变更须显式修订
- 计划：阶段切换时重写清单
- 设计：边界/所有权变化时更新
- **不**维护独立 `progress.md`；进度以 roadmap 状态 + git 历史 + Ready 汇报为准

## 质量保证

### 验证清单
- [ ] 代码编译通过
- [ ] 本模块 focused / 相关 opt-in gate 通过
- [ ] `make hygiene` 通过
- [ ] 性能无未记录的回退
- [ ] 文档与代码同步（尤其验证数字与「进行中」表）
- [ ] 公共 API 变更后 coverage 契约通过

### 禁止事项
- ❌ 跳过路线图直接大改
- ❌ 未验证就进入下一阶段
- ❌ 文档与代码不同步 / 谎报全绿
- ❌ 用 scalar forwarder 伪装 backend 所有权
- ❌ raw-merge 长期 lane 到 main

## 工具支持

### 必需入口
- `make focused FOCUS=core/tests/nextpas.core.simd`
- `make -C core/tests/nextpas.core.simd neon-optin-focused`
- `make -C core/tests/nextpas.core.simd api-coverage-contract`
- `make hygiene`

### 可选工具
- 模块内 `bench_*` / 仓库 benchmark 入口
- **热点复测**: `make -C core/benchmarks/nextpas.core.simd/bench_hotspots clean run`（方法见 [performance-methodology.md](performance-methodology.md)）
- `valgrind` / `perf` / `heaptrack`

## 沟通规范

### 进度报告格式
```
## 进度报告 - [日期]

### 已完成
- [x] 任务 1
- [x] 任务 2

### 进行中
- [ ] 任务 3

### 验证结果
- 测试: X/Y 通过
- 性能: +/-X%
- 覆盖率: X%

### 下一步
- 任务 4
```

### 问题报告格式
```
## 问题报告

### 问题描述
[清晰描述问题]

### 影响范围
[受影响的模块/功能]

### 已尝试方案
[已尝试的解决方案]

### 建议方案
[建议的解决方案]
```

## 最佳实践

1. **小步快跑**: 每次只改一小部分，验证后再继续
2. **文档先行**: 先写文档再写代码
3. **测试驱动**: 先写测试再实现
4. **持续集成**: 每次改动都运行测试
5. **代码审查**: 重要改动需要审查

## 常见陷阱

1. **范围蔓延**: 任务范围不断扩大
2. **完美主义**: 追求完美而延迟交付
3. **忽略测试**: 只写代码不写测试
4. **文档滞后**: 代码改了文档没改
5. **沟通不足**: 不报告进度和问题

## 应对策略

1. **严格范围**: 任务开始前明确范围，超出范围的记录为后续任务
2. **最小可行**: 先实现最小可行版本，再逐步完善
3. **测试优先**: 测试是代码的一部分，不是可选项
4. **文档同步**: 代码和文档同时更新
5. **定期汇报**: 每完成一个任务就汇报进度
