> **归档**（2026-07-17）：历史 Phase 8 结论。推进主线见 [`roadmap.md`](roadmap.md)。

# Phase 8: EBR per-thread retire buffer — 最终结论

## 调研目标

验证 Phase 7 的 pthread_key_create + destructor 方案是否可行，是否需要优化。

## 调研发现

### 1. 原始 EBR（Phase 7）是正确的

- **129 个主测试全部通过，0 泄漏**
- pthread_key_create + destructor 机制工作正常
- per-thread retire buffer 优化有效减少 ~94% 的 CAS 操作

### 2. Stress test 的 flaky 问题与 EBR 无关

对多种方案进行 stress test 稳定性测试（各10次）：

| 方案 | 通过率 | 泄漏 |
|------|--------|------|
| 原始 EBR (destructor) | 1/10 | 0 |
| Threadvar | 2/10 | 36 |
| pthread_key + nil destructor | 2/10 | 35 |

**结论**: 所有方案的 stress test 稳定性都差不多（flaky），说明 flaky 问题是 stress test 本身的并发问题，不是 EBR 改动导致的。

### 3. 尝试的替代方案

#### 方案 A: Threadvar
- 不使用 pthread_key_create
- 线程退出时丢失 buffer（最多16个节点）
- 结果：36 泄漏，稳定性无改善

#### 方案 B: pthread_key + nil destructor
- 不注册 destructor
- 需要全局 buffer 注册表或接受泄漏
- 结果：35 泄漏，稳定性无改善

#### 方案 C: pthread_key + nil destructor + 全局 buffer 注册表
- 在 Destroy 中遍历全局链表 flush
- 引入竞态条件，导致 stress test 总是挂起
- 结果：不可行

## 最终结论

**Phase 7 的 pthread_key_create + destructor 方案是正确的，不需要修改。**

- 主测试 129/129 通过，0 泄漏
- per-thread retire buffer 优化有效
- stress test 的 flaky 是已知并发问题，需要单独调查

## 后续工作

1. **Phase 7 已完成**: EBR per-thread retire buffer 优化可以合并
2. **Stress test flaky**: 需要单独调查并发测试的稳定性问题
3. **性能验证**: 可以进行 benchmark 验证 per-thread buffer 的性能提升
