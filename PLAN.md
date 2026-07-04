# nextPas 项目总控计划

> 最后更新：2026-07-05
> 目标树：`docs/plans/goal-tree.md` | 自举路线图：`docs/plans/selfhost-roadmap.md` | 编译器治理：`compiler/CLAUDE.md`

## 北极星

打造 FreePascal 领域最优秀的编译器+运行时生态系统。

## 当前状态 (2026-07-05)

### ✅ 已完成
| 里程碑 | 内容 | 日期 |
|--------|------|------|
| C0-C4 | 编译器基础架构 | 2026-06-02 |
| C5 | `{$IFDEF}` 预处理器支持 | 2026-07-03 |
| C6-H4 | owned string return 改进 | 2026-07-03 |
| C7 | 自举验证 | 2026-07-03 |
| L0-L3 | 框架层模块契约 (57/57) | 2026-07-04 |
| - | mem 审计 R4+R5 清零 | 2026-07-05 |
| - | bench 审计 14/17 修复 | 2026-07-05 |

### 🔢 关键指标
- compiler-pass: 34/34 ✅
- self-compile: 19/19 ✅
- core/ 覆盖率: 963/972 (99.1%)
- 契约体系: 57 模块全覆盖 ✅

### 🏗️ 进行中
- **test 框架可用性修复**: M1 安全加固 ✅, M2 API 统一 🔄, M3 功能增强 🔲, M4 质量加固 🔲
- **bench 审计收尾**: 14/17 findings 修复，3 个文档化跳过
- **c2p_win32_compat**: 平台排除（C8 最后残留）

## 三阶段路线图

### 阶段 1: 编译器自举收尾
- [ ] c2p_win32_compat 平台排除
- [ ] C7 深化：目标运行时配置、多目标 IR、LLVM O2/LTO
- [ ] permissive overload resolution → 正式重载解析
- [ ] sema 主文件继续拆分（12,175 → 目标 <8000）

### 阶段 2: 框架深度完善
- [ ] mail 模块契约（L3 最后一块）
- [ ] test 框架 M2-M4 完成
- [ ] mem 模块编译器集成（HIR builder Arena, LLVM emitter buffer）
- [ ] 增量编译（P0：符号表热缓存 → 热编译 <1s）

### 阶段 3: 生态建设
- [ ] 架构文档、API 文档完善
- [ ] 贡献指南、示例项目
- [ ] IDE 支持、调试工具链

## 治理文档索引

| 文档 | 用途 |
|------|------|
| `docs/plans/goal-tree.md` | 项目总控地图，每轮工作前后查阅同步 |
| `docs/plans/selfhost-roadmap.md` | 自举路线图（合并自 c8-roadmap + selfhost-blockers） |
| `compiler/CLAUDE.md` | 编译器工程治理：模块结构、质量门禁、技术债 |
| `core/docs/design-conventions.md` | Core 模块设计规范 |
| `docs/contracts/` | 57 模块代码契约 |
| `docs/plans/debt-roadmap.md` | 技术债看板（待建立） |

## 工作纪律
- 每轮开始前查阅 `goal-tree.md` 对齐方向
- 每轮结束后同步 goal-tree 状态
- 代码变更通过质量门禁后提交，commit message 有明确语义
- 重大设计决策写入 `docs/adr/`
