# Lockfree Formal Models（TLA+）

> **角色**: R8 研究证据入口 · **非** T1 默认验证门
> **诚实状态**: [`../r8-research-status.md`](../r8-research-status.md)
> **契约**: formal 加深 **不** 改变 T1 运行时语义（见 [`../CONTRACT.md`](../CONTRACT.md) §6.1）

---

## 1. 模型 ↔ Pascal 对照

| TLA+ 模型 | 配置 | Pascal 镜像 / 相关测试 | 覆盖要点 |
|-----------|------|------------------------|----------|
| [`tla/SpscQueue.tla`](tla/SpscQueue.tla) | [`tla/SpscQueue.cfg`](tla/SpscQueue.cfg) | `test_lockfree` SPSC 路径；`test_lockfree_formal` | 有界 SPSC、TypeOK、FIFO |
| [`tla/MpmcQueue.tla`](tla/MpmcQueue.tla) | [`tla/MpmcQueue.cfg`](tla/MpmcQueue.cfg) | 同上 + MPMC rings | sequence / 并发 publish-consume 抽象 |
| [`tla/LockFreeChannel.tla`](tla/LockFreeChannel.tla) | [`tla/LockFreeChannel.cfg`](tla/LockFreeChannel.cfg) | Channel 主测 + formal；cap=1 以 R5 为准 | Close、buffer、send/receive |
| [`tla/LockFreeStack.tla`](tla/LockFreeStack.tla) | [`tla/LockFreeStack.cfg`](tla/LockFreeStack.cfg) | Stack `TryPush`/`TryPop`/`Close` 主测 | LIFO、有界、Close 拒绝 publish |

Pascal formal 套件：

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree/test_lockfree_formal clean test
```

R8 聚合门（含 formal）：

```bash
make -C core/tests/nextpas.core.lockfree verify-r8
```

---

## 2. 如何运行 TLC（若环境可用）

先决条件：

- Java 运行时
- [TLA+ Tools](https://github.com/tlaplus/tlaplus)（含 `tla2tools.jar` / TLC）

示例（路径按本机安装调整）：

```bash
# 从 formal/tla 目录
cd core/docs/lockfree/formal/tla

# 使用 jar 时（示例）：
java -cp /path/to/tla2tools.jar tlc2.TLC -config SpscQueue.cfg SpscQueue.tla
java -cp /path/to/tla2tools.jar tlc2.TLC -config MpmcQueue.cfg MpmcQueue.tla
java -cp /path/to/tla2tools.jar tlc2.TLC -config LockFreeChannel.cfg LockFreeChannel.tla
java -cp /path/to/tla2tools.jar tlc2.TLC -config LockFreeStack.cfg LockFreeStack.tla
```

或使用 Toolbox GUI 打开对应 `.tla` 并加载同名 `.cfg`。

---

## 3. 无 TLC 时的姿势

许多 CI / 开发机 **没有** Java 或 TLC：

| 证据层 | 是否必需 | 说明 |
|--------|----------|------|
| `.tla` / `.cfg` 入仓 | 是（研究工件） | **model-only** 可读证据 |
| `test_lockfree_formal` | 推荐 | Pascal 侧边界 / Close / 顺序镜像 |
| TLC 跑通 | **可选** | 有工具时加深；无工具不阻塞 Maintenance / T1 |

**禁止**：因缺 TLC 而降低 `verify-t1` 期望，或把 formal 失败伪装成 T1 绿。

---

## 4. 硬规则

- Formal 属于 **R8 / Experimental**，不进默认门面
- 不替代 CONTRACT 与 `verify-t1`
- 模型与实现冲突时：先修 bug 或更新模型；无法对齐则记入 CONTRACT §6.1 限制表
