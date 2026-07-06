# nextpas.core.mem R6 修复实施规划

**规划日期**: 2026-07-05
**基于**: R6-RESEARCH-REPORT.md
**工作分支**: mem (worktree: .worktrees/mem)

---

## 里程碑

### M1: MPSC Inbox 并发修复 [P0] — 预计 1 天

**目标**: 消除 test_stability 崩溃，确保并发安全。

| 步骤 | 文件 | 改动 | 验证 |
|------|------|------|------|
| M1-1 | `cache.thread.pas` | MPSC inbox → Treiber stack（Push=1 CAS, PopAll=1 exchange） | 编译通过 |
| M1-2 | `cache.thread.pas` | 新增 `TreiberStackPush`, `TreiberStackPopAll` | 单元测试 |
| M1-3 | `allocator.growing.pas` | `ThreadExitFlush` 增加 inbox drain | test_stability 通过 |
| M1-4 | `allocator.growing.pas` | `FreeMem` 跨线程路径增加 nil 检查 + 降级 central | test_concurrent 通过 |
| M1-5 | `allocator.growing.pas` | `FindThreadCache` 增加原子读取保护 | test_stability 通过 |
| M1-6 | 全量回归 | 47 套件全跑 | 0 failures, 0 leaks |

**依赖**: 无
**风险**: Treiber stack ABA — 64 位平台指针空间足够，ABA 概率极低。用 `AtomicCmpExchange` 保证。

---

### M2: FreeMem 单参数重载 [P1] — 预计 0.5 天

**目标**: TGrowingAllocator 兼容 IAllocator 风格调用。

| 步骤 | 文件 | 改动 | 验证 |
|------|------|------|------|
| M2-1 | `allocator.growing.pas` | 新增 `FreeMem(APtr: Pointer)` 重载，通过 span 元数据反查 size class | 编译通过 |
| M2-2 | `allocator.growing.pas` | 新增 `FindSizeClassForPtr(APtr): Int32` 内部函数 | 单元测试 |
| M2-3 | `test_stability` | 新增单参数 FreeMem 测试用例 | 通过 |

**依赖**: M1 完成（同一文件）
**风险**: span 查找增加 ~5ns/free。仅影响单参数路径，双参数热路径不受影响。

---

### M3: 文档同步 [P1/P2] — 预计 0.5 天

**目标**: 消除接口混淆，明确设计意图。

| 步骤 | 文件 | 改动 |
|------|------|------|
| M3-1 | `allocator.base.pas` | 头注释说明 canonical IAllocator 在 mem.intf.pas |
| M3-2 | `mem.pas` | 门面决策表增加 "固定大小 vs 通用" 对照 |
| M3-3 | `pool.base.pas` | IPool 注释说明 Acquire vs GetMem 语义差异 |
| M3-4 | `USABILITY-AUDIT.md` | 更新 R6 findings 状态 |

**依赖**: 无
**风险**: 无

---

## 优先级排序

```
M1 (P0, 1天) → M2 (P1, 0.5天) → M3 (P1/P2, 0.5天)
总计: ~2 天
```

## 验收标准

1. `make -C core/tests/nextpas.core.mem clean test` — 全绿，0 failures，0 leaks
2. `test_stability` — 100 轮 × 16 线程无 crash
3. 新增并发压力测试 — 8T × 100K ops 无 crash
4. `git diff --check` — 无 whitespace 错误
5. 所有文档同步完成

## 提交策略

- M1: 1 个 commit（并发修复，原子提交）
- M2: 1 个 commit（API 扩展）
- M3: 1 个 commit（文档同步）
