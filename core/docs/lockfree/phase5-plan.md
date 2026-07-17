> **归档**（2026-07-17）：历史 Phase 5 计划。推进主线见 [`roadmap.md`](roadmap.md)。

# Phase 5: 并发安全审计

> 创建: 2026-07-06 | 状态: 审计完成

## 审计结果

### P0: BTree 并发安全 — 延迟

**问题**: BTree 的 Find 使用无锁遍历，但 Insert/Remove 可以修改节点结构（SplitChild、MergeChildren 等），存在竞态条件。

**尝试的修复**: Hand-over-hand 锁耦合
- Find: 读锁耦合 ✅ (单线程测试通过)
- Insert: 写锁耦合 ❌ (FRoot 在 root split 时改变，导致其他线程锁住旧 FRoot)

**根因**: BTree 的设计假设只有一个写者。FRoot 可以在 Insert 期间改变，这使得锁耦合无法正确实现。

**决策**: 延迟到架构重设计阶段。当前 BTree 作为"单写者多读者"数据结构使用。

**临时方案**:
- Find 使用无锁读（当前实现）
- Insert/Remove 使用根写锁（当前实现）
- 文档标注: "支持单写者多读者并发，不支持多写者并发"

### P1: SkipList 结构安全 — 延迟

**问题**: SkipList 的 Insert/Remove 遍历时无锁，但会修改节点指针。与 BTree 类似，需要架构重设计。

**决策**: 延迟到架构重设计阶段。

### P2: EBR Per-thread Retire Buffer — 可行

**问题**: TEbrDomain.Retire 每次调用都 CAS 操作全局链表，高并发时有 contention。

**方案**: Per-thread retire buffer，积累 N 个指针后批量 CAS。

**状态**: 待实施。

---

## 文档更新

### BTree 并发限制文档

在 BTree 源码头部添加并发安全说明：

```pascal
{**
 * @desc Concurrent B-Tree using per-node read-write locks.
 *
 * @concurrency Thread-safe for single-writer multi-reader scenarios:
 *   - Find/Contains/Count/ForEach/ForEachRange: lock-free reads
 *   - Insert/Remove/Clear: serialized via root write lock
 *
 * @limitations NOT safe for concurrent writes from multiple threads.
 *   The root pointer (FRoot) can change during Insert (root split),
 *   which causes race conditions with lock-coupling approaches.
 *
 * For true multi-writer concurrency, consider using TShardedHashMap
 * or redesigning with RCU/hazard pointers.
 *}
```

---

## 总结

| 任务 | 状态 | 原因 |
|------|------|------|
| BTree 锁耦合 | ❌ 延迟 | FRoot 变更导致竞态 |
| SkipList 结构安全 | ❌ 延迟 | 类似问题 |
| EBR per-thread retire | ⏸️ 待实施 | 可行 |
| BTree 并发文档 | ✅ 完成 | 已更新源码头部 |
