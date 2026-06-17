# FOUNDATION 工作线 — 任务规格

## 目标

维护和完善 L0-L1 基础模块。确保所有基础模块可脱离 FPC RTL 独立运行，为高层模块提供坚实底座。

## 当前状态

- 工作区: `.worktrees/core-foundation`，分支 `codex/core-foundation`
- 大部分 L0-L1 模块已完成
- 与 main 对齐 (HEAD: `4fbbd248c`)
- 多个模块对 system 有不同程度依赖

## 你的工作区

```bash
cd /home/dtamade/projects/nextPas/.worktrees/core-foundation
```

分支: `codex/core-foundation`

## L0-L1 模块完整清单与状态

### L0: 内核（只依赖 FPC RTL）

| 模块 | 状态 | 对 system 依赖 | 待办 |
|------|------|---------------|------|
| `base` | ✅ 完成 | 无 | 维护模式 |
| `errors` | ✅ 完成 | 无 | 维护模式 |
| `exception` | ✅ 完成 | 无 | 维护模式 |
| `platform` | ✅ 完成 | 无 | host matrix 扩充 |
| `mem` | ✅ 完成 | 无 | 已重构，维护模式 |
| `atomic` | ✅ 完成 | 无 | 维护模式 |
| `math` | ✅ 完成 | 无 | 维护模式 |
| `simd` | ✅ 完成 | 无 | 在 SIMD 线维护 |
| `log.intf` | ✅ 完成 | 无 | 维护模式 |
| `system` | ✅ S0-S6 完成 | 自举待推进 | 在 BOOTSTRAP 线维护 |
| `contracts` | ✅ 完成 | 无 | 维护模式 |

### L1: 基础设施（只依赖 L0）

| 模块 | 状态 | 对 system 依赖 | 待办 |
|------|------|---------------|------|
| `bytes` | ✅ 完成 | 无 | 维护模式 |
| `text` | ✅ 完成 | 无 | Unicode 扩展计划 |
| `encoding` | ✅ 完成 | 无 | 维护模式 |
| `collections` | ✅ 完成 | `system.typinfo` | RTTI drift guard |
| `sync` | ✅ 完成 | 无 | 维护模式 |
| `thread` | ✅ 完成 | 无 | 维护模式 |
| `async` | ✅ 完成 | 无 | 维护模式 |
| `io` | ✅ 完成 | `system.classes` (TStream) | 等 BOOTSTRAP Gate 0 |
| `time` | ✅ 完成 | 无 | 维护模式 |
| `id` | ✅ 完成 | 无 | 维护模式 |
| `testing` | 📋 基础 | 无 | 后期迭代 |
| `lockfree` | ✅ 完成 | 无 | 维护模式 |

## 工作优先级

### Phase 1: 审计与适配准备 (Week 1-2) ⏱️ 3-5 天

**目标**: 全面审计各模块对 FPC RTL 和 system 的依赖情况。

**任务**：
1. 运行 FPC RTL 依赖审计脚本（如果存在），或手动 grep 所有 `core/src/nextpas.core.*.pas` 中的 `uses SysUtils, Classes, ...`
2. 生成完整的依赖矩阵：哪些文件依赖哪些 FPC 单元
3. 区分"可立即清理"和"等 system 接口"两类依赖
4. 将审计结果写入 `docs/plans/foundation-fpc-rtl-dependency-audit.md`

### Phase 2: 等待 BOOTSTRAP Gate 0 后的适配 (Week 2-3) ⏱️ 3-5 天

**目标**: 将各模块的 FPC RTL uses 迁移到 system 门面或框架对应模块。

**任务**：
1. `uses Classes` → `uses nextpas.core.system.classes`（等 BOOTSTRAP Gate 0 交付）
2. `uses SysUtils` → 分析每个调用点：
   - `SameText` → `nextpas.core.system.sysutils` 或 `nextpas.core.text`
   - `Format` → `nextpas.core.system.sysutils` 或 `nextpas.core.text.conv`
   - `IntToStr` → `nextpas.core.text.conv`
   - `Trim` → `nextpas.core.text`
   - 其他 SysUtils 函数 → 找到框架对应模块
3. 每次替换后运行 focused gate 验证

### Phase 3: Collections RTTI Guard (Week 2) ⏱️ 1-2 天

**目标**: 为 collections 模块添加 RTTI drift 防护。

**任务**：
1. 在 `core/tests/nextpas.core.collections/` 添加 guard 测试：
   - 验证 `TElementManager<string>` 的 `GetTypeKind` 返回 `tkAString`
   - 验证 `TElementManager<Integer>` 的 `GetTypeKind` 返回 `tkInteger`
   - 覆盖所有 collections 使用的 tk* 枚举值
2. 确保 BOOTSTRAP Gate 1 (RTTI 形状一致性) 通过时，collections guard 也通过

### Phase 4: 跨模块整合验证 (Week 3-4) ⏱️ 2-3 天

**目标**: 确保所有 L0-L1 模块可脱离 FPC RTL 独立编译。

**任务**：
1. 创建 compile-only gate：在 `-Fu` 中排除 FPC 单元路径，验证所有 core 模块可编译
2. 修复发现的隐式 FPC RTL 依赖
3. 运行全量 focused gate 矩阵

## 必读文档

1. `core/docs/design-conventions.md` — 框架设计规范（必读）
2. `core/docs/core-module-registry.md` — 模块注册表
3. `core/docs/system/README.md` — system 模块定位和边界
4. `docs/plans/2026-06-18-five-lines-work-map.md` — 5 线工作地图

## 工作纪律

1. 每个模块改动后必须：该模块 focused gate 全绿 + 0 leaks + `make hygiene` PASS + git commit
2. 不要绕过 system 模块直接调用 FPC RTL
3. 跨模块修改遵循受控跨模块规则（先说明原因/风险/验证计划）
4. 不影响其他 active worktree 的代码
5. benchmark 最后一轮再做

## 常用命令

```bash
cd /home/dtamade/projects/nextPas/.worktrees/core-foundation

# 运行模块 focused gate
make -C core/tests/nextpas.core.<module>/<test> clean test

# 卫生检查
make hygiene

# 审计 worktree 状态
scripts/worktree-audit.sh
```

## 关键约束

- 不绕过 owner boundary
- 不创建裸露的 System.pas 在 core/src/
- 依赖方向只向下：L1 只依赖 L0，不依赖 L2/L3
- 同层内允许单向依赖，禁止循环依赖
- 所有 API 必须通过单元测试才算完成
