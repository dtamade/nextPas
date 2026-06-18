# nextPas 5 线并行工作地图

> **日期**: 2026-06-19
> **总控**: dtamade
> **目标**: 协调 5 条并行工作线，以 system 模块为核心依赖枢纽，明确各线接口需求和完整开发路线
> **当前最高优先级**: BOOTSTRAP R6 — 编译器运行时归位 (SysUtils→nextpas.core) + musl 目标

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
| **BOOTSTRAP** | `.worktrees/rtl-bootstrap` | `rtl-bootstrap` | `1d02504ae` | R5 自举收敛 ✅，**R6 运行时归位+musl 待启动** 🔴 |
| **TLS** | `.worktrees/core-tls` | `codex/core-tls` | `4fbbd248c` | 高度成熟，对齐 main |
| **FOUNDATION** | `.worktrees/core-foundation` | `codex/core-foundation` | `4fbbd248c` | 对齐 main，待启动 |
| **SIMD** | `.worktrees/core-simd-perf` | `codex/core-simd-perf` | `4fbbd248c` | G1-G20 完成，G21 进行中 |
| **L3** | 待创建 | 待创建 | — | 尚未创建 |

---

## 核心依赖枢纽：system 模块

**system 模块是所有其他模块的运行时契约基础。** 关键发现：system 的三个兼容门面
(`classes`/`sysutils`/`typinfo`) 都已存在最小 live slice，不是从零开始的阻塞点，
而是需要收口验证和按需扩展的"剩余兼容债务点"。

### 各线对 system 模块的接口需求矩阵（修正版）

| 需求方 | 需要的 system 接口 | 优先级 | 当前状态 |
|--------|-------------------|--------|---------|
| **TLS** | `system.classes` (TStream 链: TStream/THandleStream/TMemoryStream/TStringStream/TSeekOrigin) | 🟢 已满足 | stream-only shim live，http.client.pas 已迁出 Classes |
| **TLS** | TThread/TList/TInterfacedObject (非 system scope) | 🟡 residual RTL debt | 按 owner boundary：thread/collections/base 各自承担，本轮不进 system |
| **TLS** | TFileStream/TStringList (非 system scope) | 🟡 等 io 模块 | system.classes 不扩，等 `nextpas.core.io` 提供 TFileStream 替代 |
| **TLS** | `system.sysutils` (SameText/Format/IntToStr/Trim/Exception 别名) | 🟢 最小已满足 | S4 已提供最小 live slice |
| **HTTP** | `system.classes` (TStream 继承链) | 🟡 最小已 live | 同 TLS stream 链 |
| **collections** | `system.typinfo` (PTypeInfo/TTypeKind/InitializeArray/FinalizeArray/CopyArray) | 🟢 七符号已 live | S4 已提供，需 ongoing RTTI drift guard |
| **fs** | TFileStream/fm* 常量 (非 system scope) | 🟡 等 io 模块 | system.classes 不扩，由 io owner 承担 |
| **io** | `system.classes` (TStream), `io.memory` (TBytesStream) | 🟡 部分 | TBytesStream 属 io.memory owner，不应进 system.classes |
| **crypto** | `system.sysutils` (SameText/Format) | 🟢 最小已满足 | S4 最小集 |
| **config** | `system.sysutils` (Format/异常) | 🟢 最小已满足 | S4 最小集 |
| **compiler/toolchain** | TFileStream/TStringList (非 system scope) | 🟡 等 io 模块 | system.classes 不扩，由 io/collections owner 承担 |
| **SIMD** | 无 | ✅ 零依赖 | N/A |

### system.classes 当前真实状态

`core/src/nextpas.core.system.classes.pas` **已存在**，是纯 re-export facade：

```pascal
type
  TStream = Classes.TStream;
  THandleStream = Classes.THandleStream;
  TMemoryStream = Classes.TMemoryStream;
  TStringStream = Classes.TStringStream;
  TSeekOrigin = Classes.TSeekOrigin;
```

**已提供的 stream-core 面**：TStream/THandleStream/TMemoryStream/TStringStream/TSeekOrigin ✅
**本轮不扩展**：Codex 审查明确否决扩 system.classes。TFileStream/TStringList 属 io/collections owner。
**Classes 按符号四分类**：stream（system shim）/ thread（thread owner）/ list（collections owner）/ interfaced-base（base seam）

真实 Classes 债务（Codex 审查细化 2026-06-18）：
- ✅ `http.client.pas`：已迁，drop uses Classes（TBytes→base, Exception→errors）
- 🔧 `async.pas` (TList private)：API redesign → dynamic array
- 🔧 `store.pas` (TList public)：API redesign → TLS owner 专属类型
- 🟡 `transport.pas` (TInterfacedObject)：residual RTL debt
- 🟡 `ocsp.stapling.pas` (TThread)：residual RTL debt
- 🟡 `tui.task.pas` (TThread)：residual RTL debt

### system 模块接口交付优先级（修正版）

```
第一优先级（Week 1-2）：收口已存在的最小面 + Codex 审查整改
├── ✅ system.classes 收口验证：stream-only shim 确认，Codex 审查通过
├── ✅ http.client.pas 已迁出 Classes（→ base + errors）
├── system.classes 文档 drift 已修复（goal-tree + README）
├── RTTI 形状一致性验证 (Gate 1)
└── 待做：async.pas/store.pas TList API redesign

第二优先级（Week 2-4）：运行时基础
├── 进程生命周期执行 (Gate 3)
├── 异常展开测试 (Gate 5，已接近完成，可早收)
└── 堆管理器集成 (Gate 4)

第三优先级（Week 3-5）：自举关键路径
├── 单元生命周期执行 (Gate 2) — self-hosting critical gate，不可无限后置
└── 编译器测试扩展 (pass>=20, fail>=15)
```

---

## BOOTSTRAP 线：完整工作地图

### 定位

`nextpas.core.system` + `compiler/` 合并线。目标是让 nextPas 能够自举（用 nextPas 编译 nextPas）。

### 6 道 Gate（按真实依赖重排）

system.classes/sysutils/typinfo 三个兼容门面都已存在最小 live slice。
真正未完成的是收口验证 + file-text-compat 扩展。

```
真实依赖顺序（按 self-hosting criticality）:
G1 (RTTI) → G3 (进程生命周期) → G2 (单元生命周期) — critical path
G5 (异常) — 已接近完成，可早收
G4 (堆) — 视决策插入
G0 (classes 收口+扩展) — 解除跨线兼容债务
```

#### Gate 0: system.classes 收口验证与扩展 ⏱️ 3-5 天 🟡 跨线兼容阻塞

**当前真实状态**：`core/src/nextpas.core.system.classes.pas` 已存在，是纯 re-export facade。
已提供 stream-core 面 (TStream/THandleStream/TMemoryStream/TStringStream/TSeekOrigin)。
**缺失** file-text-compat 面 (TFileStream/fm* 常量/TStringList)，影响 19+ TLS 文件 + compiler/toolchain。

**任务**：
1. **收口验证**已存在的 stream-core facade：
   - 确认 `system.classes` 门面通过编译和 source-contract gate
   - 添加单元测试 `core/tests/nextpas.core.system/test_system_classes/`
2. **file-text-compat 扩展**（需单独 review）：
   - 审计 TFileStream/TStringList 消费面（19+ 文件）
   - 决策：扩展现有 facade vs 等待纯 Pascal io 模块
   - 如果扩展，加入 `TFileStream`、`fm*` 常量、`TStringList`
3. **移除 TBytesStream** 从 system.classes 计划（owner 是 `nextpas.core.io.memory`）
4. **更新 system 文档**：README 中 "Classes 已推迟" → "已最小 live，需收口验证"
5. 通知所有线 stream-core 面已可用，file-text-compat 面待决策

**验收**：
- [ ] system.classes 已有 facade 通过 source-contract gate
- [ ] file-text-compat 扩展决策完成，文档化
- [ ] 单元测试通过，0 leaks
- [ ] system 文档状态更新

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

### BOOTSTRAP 执行节奏（修正版 — 基于 self-hosting criticality）

```
Week 1:
  - Gate 0: system.classes 收口验证 — 2 天（facade 已存在）
  - Gate 0b: file-text-compat 扩展决策 — 1 天
  - Gate 1: RTTI 测试 — 3 天（可与 G0 并行）
  - 通知所有线 stream-core 面已可用

Week 2:
  - Gate 5: 异常测试 — 2 天（已接近完成，可早收）
  - Gate 3: 进程生命周期 — 3 天
  - 开始 pass/fail 测试扩展

Week 3:
  - Gate 4: 堆管理器 — 决策+实现
  - 继续 pass/fail 测试扩展

Week 4-5:
  - Gate 2: 单元生命周期 — self-hosting critical gate，最长单点任务
  - 完成所有 pass/fail 测试

Week 6:
  - 自举集成验证
  - 用 nextPas 编译 nextPas 编译器本身
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
- **兼容阻塞点**: stream-core 面已 live (TStream/THandleStream/TMemoryStream/TStringStream/TSeekOrigin)
- **缺失**: file-text-compat 面 (TFileStream/fm*/TStringList) — 19+ 文件使用，等待 BOOTSTRAP Gate 0b 决策

### 剩余工作

| 优先级 | 工作项 | 估时 | 依赖 |
|--------|--------|------|------|
| P0 | 迁移 6 个直接 uses Classes 的文件 → system.classes | 1 天 | 无（facade 已存在） |
| P0 | 等待 file-text-compat 决策 (TFileStream/TStringList) | — | BOOTSTRAP Gate 0b |
| P1 | H2 测试覆盖率补齐 (client -33, frame -17, hpack -15) | 3-5 天 | 无 |
| P1 | H2 真实 TLS runtime proof (当前 mock-based) | 2-3 天 | 无 |
| P2 | 文档对齐 (h2-test-coverage-plan.md) | 1 天 | P1 完成后 |
| P2 | FPC RTL 依赖清理 (SysUtils/BaseUnix/Unix/Windows/DateUtils) | 3-5 天 | 无（SysUtils 面已 live） |
| P3 | FreePascal 纯 Pascal 后端生产就绪 | 1-2 周 | 无 |
| P4 | H3/QUIC 支持 | 远期 | QUIC 独立模块 |

### 当前 FPC RTL 依赖债务（按 source 取证修正）

旧 summary 口径 ~138 Classes 文件，按当前 file allowlist + 生产源码面取证：

| 单元 | TLS 生产文件数 | 说明 |
|------|-------------|------|
| SysUtils | ~200 (旧 summary 口径) | 需逐步替换为 system.sysutils + text/conv 模块 |
| Classes (直接 uses) | **6** | ocsp/transport/http/openssl + tui task |
| Classes (TFileStream/TStringList) | **19+** | cert/quick/crypto/logging/openssl — 等待 file-compat 决策 |
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
| `io` | L1 | ✅ 完成 | system.classes (TStream) — stream-core 已 live | TBytesStream 属 io.memory owner |
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

### L3 执行节奏（修正版 — 先审计已存在模块，再开发新模块）

```
Phase 1 (Week 1-2): 已存在 L3 模块依赖审计
  - 审计 config/http/websocket/tui/coroutine/cookie 的 system/FPC RTL 依赖
  - 生成完整依赖矩阵 → docs/plans/l3-dependency-audit.md
  - 不创建独立 L3 worktree，审计在 main checkout 完成

Phase 2 (Week 2-4): 等 system 兼容边界收口后，创建 L3 worktree
  - 等 BOOTSTRAP Gate 0 收口 (stream-core + file-text-compat 决策)
  - 创建 L3 worktree 和分支
  - 迁移已完成模块的 FPC RTL uses → system 门面

Phase 3 (Week 4+): 新模块开发（按 consumer pressure 驱动）
  - 只启动有明确消费方需求的模块
  - 推荐顺序: event → ratelimit → auth → template → metrics → app
  - 每个模块先写设计文档，与 /codex 讨论后实现

Phase 4 (远期): 低优先级模块
  - redis / mail / migration / job — 等有真实 consumer pressure 再启动
```

---

## 依赖关系图与关键路径

```
BOOTSTRAP Gate 0 (system.classes 收口验证)
    ├──→ TLS: P0 迁移 6 个直接 uses Classes 文件 (无阻塞，facade 已存在)
    ├──→ FOUNDATION: io 模块已有 stream-core 面可用
    └──→ L3: 已完成模块审计

BOOTSTRAP Gate 0b (file-text-compat 决策: TFileStream/fm*/TStringList)
    ├──→ TLS: 19+ 文件解除阻塞
    ├──→ compiler/toolchain: TFileStream/TStringList 迁移
    └──→ fs: TFileStream 可用

BOOTSTRAP Gate 1 (RTTI)
    └──→ FOUNDATION: collections RTTI guard + ongoing drift monitoring

BOOTSTRAP Gate 2 (单元生命周期) — self-hosting critical gate
    └──→ 多单元程序支持 (所有线受益)

BOOTSTRAP Gate 3 (进程生命周期)
    └──→ 编译器自举基础
```

### 关键路径（最长依赖链）

```
BOOTSTRAP Gate 0b → TLS 19 文件迁移 → TLS FPC RTL 清理 → TLS landing
                  → compiler/toolchain 适配 → 自举集成验证
```

**关键路径上的阻塞点**：BOOTSTRAP Gate 0b (file-text-compat 决策) 是剩余的最大阻塞点。

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

### Landing 顺序（修正版 — 基于真实 blocker）

```
第一轮 (Week 2-3):
  - BOOTSTRAP Gate 0 (system.classes 收口) + Gate 1 (RTTI) + Gate 5 (异常) → landing
  - SIMD G21 → landing

第二轮 (Week 4-5):
  - BOOTSTRAP Gate 0b (file-text-compat) + Gate 3 (进程生命周期) + Gate 4 (堆) → landing
  - TLS P0 (6 文件迁移) → landing

第三轮 (Week 6-8):
  - BOOTSTRAP Gate 2 (单元生命周期) → landing
  - TLS P2 (FPC RTL 清理) → landing
  - FOUNDATION 审计+适配 → landing

第四轮 (Week 8+):
  - L3 Phase 2 (已完成模块迁移) → landing
  - L3 Phase 3 (新模块) → landing
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

## 目标树位置快照 (2026-06-18，Codex 复盘修正)

| 线 | 在总路线图的位置 | 完成度 | 修正点 |
|----|-----------------|--------|--------|
| **BOOTSTRAP** | system S0-S5 完成，S6 完成；system.classes **已存在**需收口 | 规格 100%，执行 5% | Gate 0 从"创建"→"收口验证+扩展" |
| **TLS** | TLS v1.6.0 + HTTP H2 transport；剩余 H2 测试补齐 + 6 文件 Classes 迁移 | 代码 95%，测试 85% | Classes 债务从 ~138→6(直接)+19(file-compat) |
| **FOUNDATION** | L0-L1 大部分完成；io 模块 stream-core 面已可用 | 代码 90%，适配 0% | 阻塞从"等 Gate 0"→"stream-core 已 live" |
| **SIMD** | G1-G20 完成，G21 进行中 | 代码 98%，测试 100% | 不变 |
| **L3** | 部分模块完成；**先审计再开发**，不抢跑新模块 | 代码 50%，规划 0% | 新模块延后到 system 收口后 |
