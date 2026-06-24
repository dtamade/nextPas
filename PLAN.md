# nextpas.core.mem 模块完善 + 编译器集成计划

## 总体目标
打造 freePascal 领域最优秀的内存管理框架，所有规划、设计与实现都应朝这个标准靠拢。

## 当前状态
✅ 架构修复完成（Phase 1-5）
✅ 性能验证：TFastArena 256B 64.8ns (比 System.GetMem 快 3.8x)
✅ 测试验证：91/91 passed (8个测试套件)

## Phase 1: mem 模块完善（文档+测试覆盖+基准对照）

### 1.1 文档完善
- [ ] 创建 `docs/mem/README.md` - 模块概述
- [ ] 创建 `docs/mem/ARCHITECTURE.md` - 架构设计文档
- [ ] 创建 `docs/mem/API.md` - API 参考文档
- [ ] 创建 `docs/mem/BENCHMARKS.md` - 基准测试报告

### 1.2 测试覆盖 100%
- [ ] 审查现有测试覆盖率
- [ ] 补充缺失的接口测试
- [ ] 验证无内存泄漏（所有测试 0 leaks）
- [ ] 添加边界条件测试
- [ ] 添加并发测试（如果适用）

### 1.3 基准对照
- [ ] 编写基准对照测试（FPC RTL vs Go vs Rust）
- [ ] 生成基准测试报告
- [ ] 优化性能瓶颈

## Phase 2: 编译器集成准备

### 2.1 理解编译器需求
- [ ] 分析 HIR builder 的 Arena 使用情况
- [ ] 分析 LLVM emitter buffer 的使用情况
- [ ] 识别集成点和接口需求

### 2.2 设计集成方案
- [ ] 设计 HIR builder Arena 迁移方案
- [ ] 设计 LLVM emitter buffer 集成方案
- [ ] 与 /codex 讨论方案可行性

### 2.3 实现集成
- [ ] 实现 HIR builder Arena 迁移
- [ ] 实现 LLVM emitter buffer 集成
- [ ] 编写集成测试
- [ ] 验证编译器功能正常

## Phase 3: 复盘与优化

### 3.1 复盘
- [ ] 与 /codex 复盘所有改动
- [ ] 记录经验教训
- [ ] 更新目标树

### 3.2 优化
- [ ] 根据复盘结果优化设计
- [ ] 优化性能
- [ ] 完善文档

## 时间线
- Phase 1: 1-2 天
- Phase 2: 2-3 天
- Phase 3: 1 天

## 关键指标
1. 测试覆盖率 100%
2. 内存泄漏 0
3. 性能超越 Go/Rust
4. 接口设计优雅
5. 文档完整
6. 基准对照完整

## 工具与方法
- 使用 /codex 进行复盘和方案讨论
- 使用 gpt-5.5 xhigh 解决难题
- 使用团队模式加速开发
- 每轮结束提交 git，保持变更清晰好追溯
- 每轮结束报告当前在总路线图的位置
