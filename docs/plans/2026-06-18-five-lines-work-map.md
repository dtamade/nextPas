# nextPas 5 线并行工作地图

> **日期**: 2026-06-18
> **总控**: dtamade
> **目标**: 协调 5 条并行工作线，以 system 模块为核心依赖枢纽，明确各线接口需求和完整开发路线

---

## 总览：5 线全景

```
                    ┌──────────────────────────────────────────┐
                    │           BOOTSTRAP (system + compiler)    │
                    │  提供: np.system.* 契约 + 编译器自举       │
                    │  Worktree: .worktrees/bootstrap           │
                    │  Branch: codex/bootstrap                  │
                    │  状态: 规格已就位，待启动执行              │
                    └──────┬──────────────┬────────────────────┘
                           │              │
              ┌────────────┤              ├──────────────┐
              ▼            ▼              ▼              ▼
     ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
     │FOUNDATION│  │   TLS    │  │   SIMD   │  │    L3    │
     │ L0-L1    │  │ L2-L3    │  │  L0 优化 │  │ L3 框架  │
     │ 基础模块 │  │TLS+HTTP  │  │ 已完成   │  │ 待创建   │
     │待启动    │  │高度成熟  │  │G21进行中 │  │          │
     └──────────┘  └──────────┘  └──────────┘  └──────────┘
```

### 各线当前状态

| 工作线 | Worktree | 分支 | HEAD | 状态 |
|--------|----------|------|------|------|
| **BOOTSTRAP** | `.worktrees/bootstrap` | `codex/bootstrap` | `44ffd651d` | 规格就位，+1 ahead |
| **TLS** | `.worktrees/core-tls` | `codex/core-tls` | `4fbbd248c` | 高度成熟，对齐 main |
| **FOUNDATION** | `.worktrees/core-foundation` | `codex/core-foundation` | `4fbbd248c` | 对齐 main，待启动 |
| **SIMD** | `.worktrees/core-simd-perf` | `codex/core-simd-perf` | `4fbbd248c` | G1-G20 完成，G21 进行中 |
| **L3** | 待创建 | 待创建 | — | 尚未创建 |

---

## 核心依赖枢纽：system 模块

**system 模块是所有其他模块的运行时契约基础。** BOOTSTRAP 线的首要任务是尽快托起其他模块所需的最小接口集。

### 各线对 system 模块的接口需求矩阵

| 需求方 | 需要的 system 接口 | 优先级 | 当前状态 |
|--------|-------------------|--------|---------|
| **TLS** | `system.classes` (TStream, THandleStream, TMemoryStream, TStringStream, TSeekOrigin) | 🔴 硬阻塞 | **已推迟** — 这是最大阻塞点 |
| **TLS** | `system.sysutils` (SameText, Format, IntToStr, Trim, Exception 别名) | 🟡 部分满足 | S4 已提供最小集 |
| **collections** | `system.typinfo` (PTypeInfo, TTypeKind, InitializeArray/FinalizeArray/CopyArray) | 🟡 部分满足 | S4 已提供七符号集 |
| **HTTP** | `system.classes` (TStream 继承链) | 🔴 硬阻塞 | 同 TLS |
| **crypto** | `system.sysutils` (SameText, Format) | 🟡 部分满足 | S4 最小集 |
| **fs** | `system.classes` (TStream, TFileStream) | 🔴 硬阻塞 | 同 TLS |
| **config** | `system.sysutils` (Format, 异常) | 🟡 部分满足 | S4 最小集 |
| **SIMD** | 无 | ✅ 零依赖 | N/A |

### system 模块接口交付优先级

```
第一优先级（Week 1-2）：解除硬阻塞
├── system.classes 最小门面 — TStream 继承链
├── system.sysutils 扩展 — 补齐 TLS/HTTP 所需
└── RTTI 形状一致性验证 (Gate 1)

第二优先级（Week 2-4）：运行时基础
├── 进程生命周期执行 (Gate 3)
├── 堆管理器集成 (Gate 4)
└── 异常展开测试 (Gate 5)

第三优先级（Week 3-5）：多单元支持
├── 单元生命周期执行 (Gate 2)
└── 编译器测试扩展 (pass>=20, fail>=15)
```

---

## BOOTSTRAP 线：完整工作地图

### 定位

`nextpas.core.system` + `compiler/` 合并线。目标是让 nextPas 能够自举（用 nextPas 编译 nextPas）。

### 5 道 Gate（按依赖顺序重排）

原始规格中的 Gate 顺序需要调整，因为其他线依赖 system 模块的接口交付：

```
原顺序: G1 → G5 → G3 → G4 → G2
新顺序: G1 → G5 → G3 → G4 → G2 (执行顺序不变)
但 G1 内部需要新增：system.classes 最小门面 (新 G0)
```

#### 新 Gate 0: system.classes 最小门面 ⏱️ 3-5 天 🔴 最高优先级

**为什么是最高优先级**：TLS、HTTP、fs、crypto 等多个模块的核心类型（TSSLStream、THttpStream 等）继承自 TStream。没有 system.classes，这些模块无法脱离 FPC Classes 单元。

**任务**：
1. 在 `core/src/nextpas.core.system.classes.pas` 中创建最小门面
2. 最小符号集：`TStream`, `THandleStream`, `TMemoryStream`, `TStringStream`, `TSeekOrigin`, `TBytesStream`
3. 策略选择：
   - **路径 A（推荐短期）**：re-export FPC Classes 单元的类型，作为过渡门面
   - **路径 B（长期）**：纯 nextPas 实现的 TStream 层次结构
4. 添加单元测试 `core/tests/nextpas.core.system/test_system_classes/`
5. 通知 TLS/FOUNDATION 线可以开始迁移 uses 子句

**验收**：
- [ ] `nextpas.core.system.classes` 单元可编译
- [ ] TStream 继承链可用
- [ ] TLS 模块可以 `uses nextpas.core.system.classes` 替代 `uses Classes`
- [ ] 单元测试通过，0 leaks

#### Gate 1: RTTI 形状一致性 ⏱️ 3-5 天

（同原规格，不变）

#### Gate 5: 异常展开 ⏱️ 2 天

（同原规格，不变）

#### Gate 3: 进程生命周期执行 ⏱️ 3-5 天

（同原规格，不变）

#### Gate 4: 堆管理器集成 ⏱️ 决策后 1-7 天

（同原规格，不变）

#### Gate 2: 单元生命周期执行 ⏱️ 2-3 周

（同原规格，不变）

### BOOTSTRAP 执行节奏（修订版）

```
Week 1:
  - Gate 0: system.classes 最小门面 — 3-5 天 🔴 最高优先级
  - Gate 1: RTTI 测试 — 3 天（可与 G0 并行）
  - 通知其他线 system.classes 已可用

Week 2:
  - Gate 5: 异常测试 — 2 天
  - Gate 3: 进程生命周期 — 3 天
  - 开始 pass/fail 测试扩展

Week 3:
  - Gate 4: 堆管理器 — 决策+实现
  - 继续 pass/fail 测试扩展

Week 4-5:
  - Gate 2: 单元生命周期 — 最长任务
  - 完成所有 pass/fail 测试

Week 6:
  - 自举集成验证
  - 收口、文档更新、合并 main
```

---

## TLS 线：完整工作地图

### 定位

TLS + HTTP 模块 (L2-L3)。5 后端 TLS 实现 + H1/H2 HTTP transport。

### 当前状态

- TLS: 225 文件, 139K+ 行, 290 测试文件, 5 后端全生产就绪
- HTTP: 36 文件, 37K+ 行, 19 测试工程, 181 H2 测试
- 文档: 20 TLS + 5 HTTP 文档
- 安全审计: 30 findings 100% 修复
- **阻塞点**: 依赖 `system.classes` (TStream)，等待 BOOTSTRAP Gate 0 交付

### 剩余工作

| 优先级 | 工作项 | 估时 | 依赖 |
|--------|--------|------|------|
| P0 | 迁移 uses `Classes` → `nextpas.core.system.classes` | 1-2 天 | BOOTSTRAP Gate 0 |
| P1 | H2 测试覆盖率补齐 (client -33, frame -17, hpack -15) | 3-5 天 | 无 |
| P1 | H2 真实 TLS runtime proof (当前 mock-based) | 2-3 天 | 无 |
| P2 | 文档对齐 (h2-test-coverage-plan.md) | 1 天 | P1 完成后 |
| P2 | FPC RTL 依赖清理 (SysUtils/Classes/BaseUnix/Unix/Windows) | 3-5 天 | BOOTSTRAP Gate 0 |
| P3 | FreePascal 纯 Pascal 后端生产就绪 | 1-2 周 | 无 |
| P4 | H3/QUIC 支持 | 远期 | QUIC 独立模块 |

### 当前 FPC RTL 依赖债务

根据 `goal-tree.md` S6.4 债务表：

| 单元 | TLS 文件数 | 说明 |
|------|-----------|------|
| SysUtils | ~200 | 最大债务持有者 |
| Classes | ~138 | 等待 system.classes |
| Windows | ~18 | WinSSL 后端 |
| DateUtils | ~15 | 证书时间处理 |
| BaseUnix | ~7 | Unix 平台 |
| Unix | ~5 | Unix 平台 |

### TLS 执行节奏

```
Week 1-2: 等待 BOOTSTRAP Gate 0
  - P1: H2 测试覆盖率补齐 (可并行，不依赖 system)
  - P1: H2 真实 TLS runtime proof

Week 2-3: BOOTSTRAP Gate 0 交付后
  - P0: 迁移 uses Classes → system.classes
  - P2: 开始 FPC RTL 依赖清理

Week 3-4:
  - P2: 完成 FPC RTL 依赖清理
  - P3: FreePascal 后端收尾

Week 4+:
  - 文档对齐，landing 准备
```

---

## FOUNDATION 线：完整工作地图

### 定位

L0-L1 基础模块的维护、完善和新增。涵盖 base, errors, platform, mem, bytes, text, encoding, collections, sync, thread, async, io, time, id, testing。

### 当前状态

基于 `codex/core-foundation` 分支，与 main 对齐。大部分模块已完成，但需要审计各模块对 system 的依赖和完成度。

### 模块矩阵

| 模块 | 层级 | 状态 | 对 system 的依赖 | 待办 |
|------|------|------|-----------------|------|
| `base` | L0 | ✅ 完成 | 无 (根模块) | — |
| `errors` | L0 | ✅ 完成 | 无 | — |
| `exception` | L0 | ✅ 完成 | 无 | — |
| `platform` | L0 | ✅ 完成 | 无 | host matrix 持续扩充 |
| `mem` | L0 | ✅ 完成 | 无 | 已重构 |
| `atomic` | L0 | ✅ 完成 | 无 | — |
| `math` | L0 | ✅ 完成 | 无 | 143+10422 测试 |
| `simd` | L0 | ✅ 完成 | 无 (零依赖) | G21 进行中 |
| `log.intf` | L0 | ✅ 完成 | 无 | — |
| `bytes` | L1 | ✅ 完成 | 无 | — |
| `text` | L1 | ✅ 完成 | 无 | Unicode 扩展计划 |
| `encoding` | L1 | ✅ 完成 | 无 | — |
| `collections` | L1 | ✅ 完成 | system.typinfo (TypInfo) | RTTI drift 风险 |
| `sync` | L1 | ✅ 完成 | 无 | — |
| `thread` | L1 | ✅ 完成 | 无 | — |
| `async` | L1 | ✅ 完成 | 无 | — |
| `io` | L1 | ✅ 完成 | system.classes (TStream) | 等待 BOOTSTRAP Gate 0 |
| `time` | L1 | ✅ 完成 | 无 | — |
| `id` | L1 | ✅ 完成 | 无 | — |
| `testing` | L1 | 基础 | 无 | 后期迭代 |

### FOUNDATION 执行节奏

```
Week 1-2: 审计与债务清理
  - 逐模块审计对 system 的依赖
  - 清理各模块的 SysUtils/Classes uses
  - 迁移 uses Classes → system.classes (等 BOOTSTRAP Gate 0)

Week 2-3: 接口完善
  - 配合 BOOTSTRAP Gate 0，适配 system.classes
  - collections 模块 RTTI drift guard 测试

Week 3-4: 跨模块整合
  - 确保 L0-L1 全部模块可脱离 FPC RTL 独立编译
  - 统一依赖方向审计

持续:
  - 新模块开发按需启动
  - 高层模块反哺低层接口修正
```

---

## SIMD 线：完整工作地图

### 定位

SIMD 优化模块 (L0)。为整个框架提供 SIMD 加速能力。

### 当前状态

- G1-G20 全部 100% 完成
- G21 NEON 覆盖度基准：进行中
- ~13,900+ 测试，0 泄漏
- 对 system 模块零依赖
- SysUtils/Math 依赖已全部清零

### 剩余工作

| 优先级 | 工作项 | 估时 |
|--------|--------|------|
| P0 | G21: NEON AArch64 覆盖度基准完成 | 1-2 天 |
| P1 | G16 Phase 3: RISC-V V 硬件验证 | 需硬件 |
| P1 | G17 Phase 4: Dispatch 开销硬件确认 | 1 天 |
| P2 | NEON asm 三重门控变量简化评估 | 1 天 |
| P2 | 文档统计数据自动化刷新 | 1 天 |

### SIMD 执行节奏

```
Week 1:
  - G21 NEON benchmark 收尾

Week 2:
  - 门控变量简化
  - 文档刷新
  - 准备 landing

持续:
  - 维护模式，不需要密集开发
```

---

## L3 线：完整工作地图

### 定位

L3 框架层模块。为应用程序提供开箱即用的框架能力。

### L3 模块清单与状态

| 模块 | 状态 | 源码位置 | 对 system 的依赖 | 优先级 |
|------|------|---------|-----------------|--------|
| `log` | ✅ 完成 | `core/src/nextpas.core.log*` | 无 | — |
| `config` | ✅ 完成 | `core/src/nextpas.core.config*` | system.sysutils | — |
| `http` | ✅ 完成 (在 TLS 线) | `core/src/nextpas.core.http*` | system.classes | — |
| `websocket` | ✅ 完成 | `core/src/nextpas.core.websocket*` | 待审计 | P2 |
| `tui` | ✅ 基本完成 | `core/src/nextpas.core.tui*` | 待审计 | P2 |
| `coroutine` | ✅ 完成 | `core/src/nextpas.core.coroutine*` | 无 | — |
| `event` | 📋 设计阶段 | 无 | 无 | P1 |
| `crypto` | ✅ 完成 (在 TLS 线) | `core/src/nextpas.core.crypto*` | system.sysutils | — |
| `cookie` | ✅ 完成 | `core/src/nextpas.core.cookie*` | 无 | — |
| `redis` | ❌ 未开始 | 无 | 待定 | P3 |
| `mail` | ❌ 未开始 | 无 | 待定 | P3 |
| `migration` | ❌ 未开始 | 无 | 待定 | P3 |
| `ratelimit` | ❌ 未开始 | 无 | 待定 | P2 |
| `auth` | ❌ 未开始 | 无 | 待定 | P2 |
| `template` | ❌ 未开始 | 无 | 待定 | P2 |
| `metrics` | ❌ 未开始 | 无 | 待定 | P2 |
| `job` | ❌ 未开始 | 无 | 待定 | P3 |
| `app` | ❌ 未开始 | 无 | 待定 | P2 |

### L3 执行节奏

```
Phase 1 (Week 1-3): 等待 BOOTSTRAP Gate 0 + 审计
  - 审计已完成 L3 模块的 system 依赖
  - 创建 L3 worktree 和分支
  - 规划未开始模块的开发顺序

Phase 2 (Week 3-6): 已开始模块收尾
  - event 模块设计+实现
  - ratelimit 模块实现
  - auth 模块实现
  - template 模块实现
  - metrics 模块实现
  - app 模块实现

Phase 3 (Week 6+): 新模块开发
  - redis 客户端
  - mail (SMTP/IMAP/POP3)
  - migration
  - job queue
```

---

## 依赖关系图与关键路径

```
BOOTSTRAP Gate 0 (system.classes)
    ├──→ TLS: P0 迁移 uses Classes
    ├──→ FOUNDATION: io 模块适配
    └──→ L3: http/websocket/tui 适配

BOOTSTRAP Gate 1 (RTTI)
    └──→ FOUNDATION: collections RTTI guard

BOOTSTRAP Gate 3 (进程生命周期)
    └──→ 编译器自举基础

BOOTSTRAP Gate 2 (单元生命周期)
    └──→ 多单元程序支持 (所有线受益)
```

### 关键路径（最长依赖链）

```
BOOTSTRAP Gate 0 → TLS P0 迁移 → TLS P2 依赖清理 → TLS landing
                 → FOUNDATION 审计 → FOUNDATION 适配 → FOUNDATION landing
                 → L3 审计 → L3 Phase 2 → L3 landing
```

**关键路径上的阻塞点**：BOOTSTRAP Gate 0（system.classes 最小门面）是全局阻塞点。

---

## 总控协调规则

### 接口变更通知机制

1. BOOTSTRAP 线每完成一个 Gate，立即通知所有线：
   - 新增了哪些 system 接口
   - 哪些接口签名有变更
   - 迁移指南

2. 其他线发现缺少 system 接口时：
   - 先在 `docs/plans/` 中记录需求
   - 通知 BOOTSTRAP 线排期
   - 不绕过 system 直接调用 FPC RTL

### Landing 顺序

```
第一轮 (Week 3-4):
  - BOOTSTRAP Gate 0 + Gate 1 + Gate 5 → landing

第二轮 (Week 5-6):
  - BOOTSTRAP Gate 3 + Gate 4 → landing
  - SIMD G21 → landing

第三轮 (Week 7-8):
  - BOOTSTRAP Gate 2 → landing
  - TLS P0-P2 → landing
  - FOUNDATION 适配 → landing

第四轮 (Week 9+):
  - L3 Phase 2 → landing
  - 自举集成验证
```

### 每周同步节奏

- 每周一：各线汇报进度到总控
- 每周五：总控更新 work map 和 status board
- 遇到阻塞：立即升级，不等周会

---

## 常用命令速查

```bash
# 仓库审计
scripts/worktree-audit.sh
make hygiene

# BOOTSTRAP
cd .worktrees/bootstrap
scripts/rebuild-compiler.sh
make test TEST_FILTER=compiler-pass
make test TEST_FILTER=compiler-fail
make -C core/tests/nextpas.core.system clean test

# TLS
cd .worktrees/core-tls
# TLS 测试入口待确认 (无统一 Makefile)

# FOUNDATION
cd .worktrees/core-foundation
make -C core/tests/<module>/<test> clean test

# SIMD
cd .worktrees/core-simd-perf
bash core/tests/nextpas.core.simd/BuildOrTest.sh gate

# L3 (待创建)
# cd .worktrees/core-l3
```

---

## 目标树位置快照 (2026-06-18)

| 线 | 在总路线图的位置 | 完成度 |
|----|-----------------|--------|
| **BOOTSTRAP** | system S0-S5 完成，S6 完成，5 Gate 规格就位，待启动 | 规格 100%，执行 0% |
| **TLS** | TLS v1.6.0 + HTTP H2 transport，剩余 H2 测试补齐 | 代码 95%，测试 85% |
| **FOUNDATION** | L0-L1 大部分完成，等待 BOOTSTRAP 解阻塞 | 代码 90%，适配 0% |
| **SIMD** | G1-G20 完成，G21 进行中 | 代码 98%，测试 100% |
| **L3** | 部分模块完成，待创建 worktree 和系统化推进 | 代码 50%，规划 0% |
