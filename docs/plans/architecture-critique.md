# nextPas 架构批判

> 日期：2026-07-05
> 范围：compiler/ (49,667 行) + core/ (607,017 行)
> 方法：架构哲学审视 + 业界对标 + 量化分析

---

## 核心判断

**nextPas 有一个"大而全"的框架野心，但缺乏"少而精"的架构纪律。**

这不是说做得不好——自举成功本身就是巨大成就。但当前架构存在 **5 个系统性问题**，如果不纠正，会在未来 2-3 年持续拖累开发效率。

---

## 问题一：编译器不是"内核之上的应用"

### 现状

编译器 49,667 行代码，只引用了 core 框架的 **5 个模块**：

```
nextpas.core.text, nextpas.core.text.conv, nextpas.core.path,
nextpas.core.os.env, nextpas.core.time, nextpas.core.base.utils
```

编译器的核心数据结构——AST、HIR、语义模型——**全部自己实现**，不使用 core 框架的任何数据结构。

### 这意味着什么

| 编译器自己实现的 | core 框架已有的 |
|-----------------|----------------|
| `array of TProcedureBodyEntry` (O(n) 查找) | `THashMap` (O(1)) |
| `array of string` (SetLength+1) | `TVec<string>` (容量翻倍) |
| `TGreenNode = class` (堆分配) | `TFastArena` (64.8ns 分配) |
| `TDefineTable` (O(n) IndexOf) | `THashSet` (O(1)) |
| 手动 `SameText` 比较 | `TStringView` / `TTextCompare` |

**编译器是一艘用木板自己造引擎的火箭——core 框架的零件就放在旁边没用。**

### 健康架构应该是

```
┌─────────────────────────────────────┐
│          nextpas 编译器              │
│  (只实现编译逻辑，不实现数据结构)      │
├─────────────────────────────────────┤
│        nextpas.core 框架             │
│  collections, mem, text, io, ...    │
├─────────────────────────────────────┤
│        FreePascal RTL               │
└─────────────────────────────────────┘
```

当前实际：

```
┌─────────────────────────────────────┐
│          nextpas 编译器              │
│  (编译逻辑 + 全部数据结构自己实现)     │
│  (用木板造引擎)                      │
├─────────────────────────────────────┤
│        nextpas.core 框架             │
│  (编译器只用了 5/975 个模块)          │
│  (精心打造的零件堆在仓库里)           │
├─────────────────────────────────────┤
│        FreePascal RTL               │
└─────────────────────────────────────┘
```

**这是最大的架构问题：编译器不是 core 框架的"客户"，而是 core 框架的"邻居"。**

---

## 问题二：975 个文件，但只有 45 个接口

### 数据

| 指标 | 数值 |
|------|------|
| 总 .pas 文件 | 975 |
| 总 .inc 文件 | 216 |
| 总代码行数 | 607,017 |
| 接口文件 (intf.pas) | 45 |
| 基础类型文件 (base.pas) | 87 |
| 文件 < 50 行 | 89 |
| 文件 > 1000 行 | 113 |
| 平均文件大小 | 1,012 行 |

### 问题

**975 个文件，只有 45 个接口（4.6%）**。这意味着：

1. **实现细节直接暴露** — 大部分模块没有 `intf` 抽象层，调用者直接依赖具体实现
2. **base/intf/impl 模式是装饰而非纪律** — 87 个 base 文件，但很多 base 文件只有 12-22 行（只是 re-export）
3. **无法替换实现** — 没有接口就无法 mock、无法测试、无法替换

### 对标

| 框架 | 接口/抽象比例 | 模式 |
|------|-------------|------|
| Go std | ~100% (interface 是语言特性) | 每个包通过 interface 暴露 |
| Rust std | ~80% (trait 驱动) | Iterator, Read, Write 等 trait |
| Java std | ~60% | Collection, Stream 等接口 |
| **nextPas** | **4.6%** | 大部分是具体实现 |

---

## 问题三：TLS + SIMD 占了框架的 46%

### 数据

| 模块组 | 文件数 | 占比 |
|--------|--------|------|
| TLS (含 OpenSSL API 62 文件) | 231 | 23.7% |
| SIMD (含 145 .inc 文件) | 229 | 23.5% |
| Platform | 90 | 9.2% |
| Collections | 84 | 8.6% |
| TUI | 81 | 8.3% |
| Mem | 57 | 5.8% |
| 其他 | 203 | 20.8% |

**TLS + SIMD = 460 文件，接近一半。**

### 这意味着什么

1. **TLS 的 OpenSSL API 封装（62 文件）** 本质上是 FFI 绑定，不应该和框架内核混在一起
2. **SIMD 的 145 个 .inc 文件** 是 ISA 特定的内联汇编/ intrinsic，应该放在 `core/arch/` 下
3. **框架的"门面"应该是 collections + mem + io + text + time**，但视觉上 TLS 和 SIMD 喧宾夺主

### 健康架构应该是

```
core/
├── kernel/          ← 内核：mem, base, exception, contracts
├── collections/     ← 数据结构
├── io/              ← IO 抽象
├── text/            ← 文本处理
├── net/             ← 网络
├── crypto/          ← 密码学
├── arch/            ← SIMD/平台特定（移出主树）
│   ├── simd/
│   └── platform/
├── tls/             ← TLS（FFI 绑定独立）
│   ├── ffi/
│   │   ├── openssl/
│   │   ├── mbedtls/
│   │   └── wolfssl/
│   └── protocol/
├── http/
├── tui/
└── test/
```

---

## 问题四：IAllocator 抽象未被编译器采用

### 现状

core/mem 有精心设计的分配器体系：

```
IAllocator (接口)
├── TBaseAllocator
├── TArenaAllocator     (64.8ns/alloc)
├── TCrtAllocator
├── TMmapAllocator
├── TMimallocAllocator
├── TTrackingAllocator  (泄漏检测)
├── TGuardAllocator     (越界检测)
├── TLeakCheckAllocator
└── TFallbackAllocator

IArena
├── TFastArena
├── TChunkedArena
├── TConcurrentArena
└── TVirtualArena

IPool / ISlabPool / ...
```

**但编译器完全不用这些。** 编译器用 `class` (堆分配)、`SetLength` (动态数组)、手动 `New/Dispose`。

### 对标

| 编译器 | 内存策略 |
|--------|---------|
| Clang | `llvm::BumpPtrAllocator` + `Arena` — 每个 AST 节点在 arena 中 |
| Rust | `rustc_arena::TypedArena` — 编译结束后一次性释放 |
| Go | 依赖 GC，但 `go/parser` 尽量复用节点 |
| **nextPas** | **独立 class 堆分配 + SetLength+1 动态数组** |

---

## 问题五：编译器 = 50K 行，框架 = 600K 行，但编译器不用框架

### 数据

| 组件 | 代码量 | 编译器使用率 |
|------|--------|-------------|
| core 框架 | 607,017 行 (975 文件) | **0.5%** (5/975 模块) |
| 编译器 | 49,667 行 (31 文件) | — |

**框架是编译器的 12 倍大，但编译器几乎不用框架。**

### 这意味着两种可能

**可能性 A**：框架设计过度，不适合编译器的实际需求
**可能性 B**：编译器实现过快，没有考虑复用框架

**答案是两者都有。**

- 编译器在 C0-C7 冲刺中快速堆砌功能，没时间做架构对齐
- 框架在 L0-L3 建设中追求完整性，但没有把"服务编译器"作为首要设计目标

### 应该怎么办

**编译器应该成为框架的"第一个客户"和"设计驱动者"。**

具体来说：
1. 编译器用 `TVec<T>` 替代所有 `array of T` + `SetLength+1`
2. 编译器用 `THashMap<string, T>` 替代所有 O(n) 线性查找
3. 编译器用 `TFastArena` 管理 AST 节点生命周期
4. 编译器用 `TStringView` 替代字符串拷贝

如果框架的某个模块编译器用不上 → 说明该模块可能不需要在"内核"中。

---

## 架构评分卡

| 维度 | 评分 | 说明 |
|------|------|------|
| **自举能力** | ⭐⭐⭐⭐⭐ | C7 完成，自举成功 |
| **框架完整度** | ⭐⭐⭐⭐ | 975 模块，覆盖极广 |
| **接口抽象** | ⭐⭐ | 4.6% intf 比例太低 |
| **编译器-框架整合** | ⭐ | 编译器基本不用框架 |
| **模块组织** | ⭐⭐ | TLS/SIMD 喧宾夺主 |
| **内存架构** | ⭐⭐⭐ | 分配器设计好，但编译器不用 |
| **API 一致性** | ⭐⭐⭐ | base/intf/impl 模式有但不统一 |

**总评：功能强大，架构松散。像一个所有器官都健康但神经系统没连通的巨人。**

---

## 建议的架构演进路线

### Phase 0: 立即可做（本月）

1. **编译器接入 TFastArena** — 用 arena 管理 AST 节点，立即减少 80% 堆分配
2. **编译器接入 THashMap** — 替换 O(n) 符号查找，立即提升编译速度
3. **建立"编译器是框架客户"原则** — 写入 CLAUDE.md

### Phase 1: 架构对齐（1-2 月）

4. **重组 core/ 目录** — kernel/ collections/ io/ text/ net/ crypto/ arch/ tls/ http/ tui/
5. **TLS/SIMD FFI 绑定独立** — 从框架主树移到 `core/ffi/` 或独立包
6. **提高接口比例** — 目标：50+% 模块有 intf

### Phase 2: 编译器重构（2-4 月）

7. **sema God Class 拆分** — 用框架的接口模式重构
8. **HIR Builder 用框架数据结构** — TVec, THashMap, TStringView
9. **增量编译** — 用框架的 TFileCache / THash 做指纹

---

## 治理关联

- 编译器 findings: `docs/plans/compiler-findings.md`
- 技术债看板: `docs/plans/debt-roadmap.md`
- 目标树: `docs/plans/goal-tree.md`

---

*架构批判不等于否定。nextPas 自举成功是巨大成就。这些问题是"下一步怎么走"的路线问题，不是"做错了什么"的指责。*
