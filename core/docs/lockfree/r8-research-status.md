# R8 Research Status（诚实收口）

> **日期**: 2026-07-17
> **角色**: R8（NUMA / TSX-RTM / TLA+）研究线 **honest status**，非生产提升清单
> **主线**: H2 complete / **Maintenance** — 见 [`READY.md`](READY.md)
> **详细历史计划**: [`long-term-roadmap.md`](long-term-roadmap.md)（研究计划；以本文件为当前诚实状态）
> **形式化入口**: [`formal/README.md`](formal/README.md)

---

## 0. 总览

| 轴 | 成熟度 | 默认门面 | 备注 |
|----|--------|----------|------|
| **NUMA** | Experimental / T3 | **否** | Phase 1–2 done；Phase 3 线程亲和 residual |
| **TSX/RTM** | Experimental / T3 | **否** | 无硬件时 fallback |
| **TLA+ / formal** | Experimental 研究证据 | **否** | 模型 + Pascal formal suite；TLC 环境可选 |

**R8 研究 pack close-out（opt-in docs）**：本文件 + formal README +（可选）Stack 模型 + `verify-r8` Makefile 目标。
**不** 把任何 R8 轴升入 T1，**不** 污染 `verify-t1`。

---

## 1. NUMA

### 代码

| 路径 | 角色 |
|------|------|
| `core/src/nextpas.core.numa.pas` | NUMA 拓扑门面 |
| `core/src/nextpas.core.numa.linux.pas` | Linux `/sys` 实现 |
| `core/src/nextpas.core.numa.windows.pas` | Windows 绑定 |
| `core/src/nextpas.core.lockfree.hashmap.numa.pas` | NUMA 分片 HashMap（T3） |
| `core/tests/nextpas.core.lockfree/test_lockfree_numa/` | 测试门 |

### 进度

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 | 拓扑检测 | **done** |
| 2 | NUMA 感知数据结构（hashmap.numa） | **done** |
| 3 | 线程亲和绑定 | **residual / not done** |

### Gate

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree/test_lockfree_numa clean test
```

### Tier

**Experimental / T3** — 仅 **direct import** `nextpas.core.lockfree.hashmap.numa` / `nextpas.core.numa`；**不进** `uses nextpas.core.lockfree` 默认门面。

---

## 2. TSX / RTM

### 代码

| 路径 | 角色 |
|------|------|
| `core/src/nextpas.core.lockfree.rtm.pas` | RTM 内联 / 抽象 |
| `core/src/nextpas.core.lockfree.hashmap.rtm.pas` | HashMap RTM 路径（T3） |
| `core/tests/nextpas.core.lockfree/test_lockfree_rtm/` | 测试门 |

### 行为

- 硬件支持时尝试事务路径
- **不支持或 abort** 时走 **fallback**（CAS / 非 RTM 路径）
- 不得假设目标机始终有 TSX

### Gate

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree/test_lockfree_rtm clean test
```

### Tier

**Experimental** — direct import only；不进默认门面；不进 T1 契约。

---

## 3. TLA+ / formal

### 模型

| 模型 | 路径 |
|------|------|
| SPSC | `formal/tla/SpscQueue.{tla,cfg}` |
| MPMC | `formal/tla/MpmcQueue.{tla,cfg}` |
| Channel | `formal/tla/LockFreeChannel.{tla,cfg}` |
| Stack（加深） | `formal/tla/LockFreeStack.{tla,cfg}` |

### Pascal 镜像

| 套件 | 路径 |
|------|------|
| formal suite | `core/tests/nextpas.core.lockfree/test_lockfree_formal/` |

### TLC

环境可能 **没有** Java / TLC：

- 默认：**model-only 文档** + **Pascal formal suite** 作为可运行证据
- 有 TLC 时按 [`formal/README.md`](formal/README.md) 运行

### Gate

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree/test_lockfree_formal clean test
```

### Tier

研究证据；**非** CI 默认 `verify-t1` 门；不改变 T1 运行时契约。

---

## 4. 一键 R8 研究门（opt-in）

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-r8
# 日志默认: core/build/verify-lockfree/verify-r8.log
```

`verify-r8` **独立于** `verify-t1`；失败不得用降级 T1 期望来“变绿”。

---

## 5. 硬规则

1. **R8 不在** 默认 `uses nextpas.core.lockfree` 门面
2. **无信封绝对 Mops** 对外营销（见 [`bench-envelope.md`](bench-envelope.md)）
3. **`verify-t1` 必须保绿且不被 R8 污染**（不把 NUMA/RTM/formal 塞进 T1 默认门）
4. R8 **生产化** 属于重大变更：先讨论 / 新章程（如 H3 或独立 ADR），**不** 借本文件静默升级
5. **不发明 R9**；生产向后续见 [`roadmap-h3.md`](roadmap-h3.md)（charter only）

---

## 6. 跨模块依赖（预期）

R8 轴（NUMA / RTM / formal）**无** core 跨模块生产依赖；预期见 [`consumer-audit.md`](consumer-audit.md) 脚注。
这是研究/实验面的正常状态，不是 H3 阻塞条件。
