# mem 自举前置条件报告

> 日期：2026-06-25
> 状态：A0 完成

## C6-A 依赖分析

| 节点 | 状态 | 说明 |
|------|------|------|
| C5 (lvalue/address 模型) | ✅ 2026-06-25 | 已完成 |
| **C6-A (freestanding allocator)** | ⬜ 未开始 | 编译器自有 malloc/free (mmap + free list) |
| C8-prep (自举探针) | 🏁 待 C6-A | 用 nextPas 编译 core/ 真实模块 |
| C8 (自举修复) | 🏁 待 C8-prep | 根据差距清单修复 |

## 阻塞影响

| 线路 | 是否阻塞 | 说明 |
|------|----------|------|
| A1 (Blocker Matrix) | ❌ 不阻塞 | 静态分析，可用 FPC |
| A2 (FPC Stub) | ❌ 不阻塞 | 静态分析，可用 FPC |
| A3 (自举修复) | ✅ 阻塞 | 需要 nextPas 编译器能运行 |
| A4 (消费者验证) | ✅ 阻塞 | 需要 nextPas 编译器能运行 |
| B1-B4 (回归测试) | ❌ 不阻塞 | 用 FPC 编译运行 |
| C1-C3 (设计改进) | ❌ 不阻塞 | 用 FPC 编译运行 |
| D1-D3 (基准复核) | ❌ 不阻塞 | 用 FPC 编译运行 |

## 决策

1. **继续执行 A1 + B1-B4 + C1-C3 + D1-D3**（不依赖 C6-A）
2. **A3/A4 暂缓**，等待 C6-A 完成后推进
3. **记录 C6-A 为已知阻塞**，在 blocker matrix 中标注

## 下一步

执行 A1: Unit Inventory + Blocker Matrix
