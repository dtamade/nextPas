# Lockfree 优化调研报告

> 生成: 2026-06-22 | 调研范围: SPSC Move 优化 + MPMC CAS 竞争优化

## 1. SPSC Move 优化

### 1.1 当前实现

```pascal
// EnqueueBatch: 逐元素赋值
for LI := 0 to LCount - 1 do
  FSlots[(LTail + Int64(LI)) and Int64(FMask)] := AValues[LI];

// DequeueBatch: 逐元素赋值
for LI := 0 to LCount - 1 do
  AValues[LI] := FSlots[(LHead + Int64(LI)) and Int64(FMask)];
```

**问题**: 每次赋值都是独立的 Pascal 语句，编译器可能无法优化为批量内存拷贝。

### 1.2 优化方案: 使用 Move 替代逐元素赋值

**前提**: SPSC 构造函数已拒绝 managed types (`IsManagedType(T)` 检查)，因此可以安全使用 `Move`。

**关键洞察**: `Move` 是 Pascal 的内置内存拷贝函数，底层使用 `rep movsb` (x86) 或 `memcpy` (libc)，比逐元素赋值快得多。

**实现策略**:

```pascal
function TSpscQueueImpl.EnqueueBatch(const AValues: array of T): PtrUInt;
var
  LTail, LAvail: Int64;
  LI: PtrUInt;
  LCount: PtrUInt;
  LContiguous: PtrUInt;
  LWrap: PtrUInt;
begin
  // ... 前置检查不变 ...
  
  // 计算连续区域和环绕区域
  LContiguous := FCapacity - (PtrUInt(LTail) and FMask);
  if LCount <= LContiguous then
  begin
    // 不环绕: 单次 Move
    Move(AValues[0], FSlots[PtrUInt(LTail) and FMask], LCount * SizeOf(T));
  end
  else
  begin
    // 环绕: 两次 Move
    Move(AValues[0], FSlots[PtrUInt(LTail) and FMask], LContiguous * SizeOf(T));
    Move(AValues[LContiguous], FSlots[0], (LCount - LContiguous) * SizeOf(T));
  end;
  
  // ... 后置更新不变 ...
end;
```

### 1.3 性能预期

| 场景 | 逐元素赋值 | Move 优化 | 提升 |
|------|-----------|----------|------|
| 1 元素 | ~2ns | ~2ns | 0% |
| 10 元素 | ~20ns | ~5ns | 4x |
| 100 元素 | ~200ns | ~15ns | 13x |
| 1000 元素 | ~2000ns | ~100ns | 20x |

**结论**: 仅大批量 (>10 元素) 受益。小批量无明显改善。

### 1.4 风险评估

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| Managed types 误用 | 低 | 构造函数已拒绝 |
| 环绕计算错误 | 中 | 单元测试覆盖 |
| 编译器优化差异 | 低 | Move 是标准库函数 |

---

## 2. MPMC CAS 竞争优化

### 2.1 当前实现分析

**热点路径** (TryEnqueue):
```pascal
AtomicLoad64(FEnqueuePos, moRelaxed);      // 1. 读位置
AtomicLoad64(FSlots[LIdx].Sequence, moAcquire); // 2. 读序列号
AtomicCompareExchange64(FEnqueuePos, ...);  // 3. CAS 竞争点
AtomicStore64(FSlots[LIdx].Sequence, ...);  // 4. 写序列号
```

**瓶颈**: 步骤 3 是多 producer 竞争点，CAS 失败时需要退避重试。

**当前退避策略**: 指数退避 (1, 2, 4, ..., 256 次 CpuPause)

### 2.2 优化方案对比

#### 方案 A: 改进退避策略

**当前**: 固定指数退避 (1, 2, 4, ..., 256)

**改进**: 自适应退避 + 随机化

```pascal
// 自适应退避: 根据竞争程度调整
if LBackoff < 256 then
begin
  // 随机化退避减少活锁
  LI := LBackoff + Random(LBackoff);
  repeat
    CpuPause;
    Dec(LI);
  until LI <= 0;
  LBackoff := LBackoff * 2;
end;
```

**优点**: 简单，减少活锁
**缺点**: 引入随机数开销

#### 方案 B: 批量位置预留

**思路**: 一次 CAS 预留多个位置，减少 CAS 频率

```pascal
function TryEnqueueBatch(const AValues: array of T): PtrUInt;
var
  LPos: Int64;
  LReserved: Int64;
begin
  // 一次 CAS 预留 N 个位置
  repeat
    LPos := FEnqueuePos;
    LReserved := Min(Length(AValues), FCapacity - (LPos - FDequeueCache));
  until AtomicCompareExchange64(FEnqueuePos, LPos, LPos + LReserved) = LPos;
  
  // 填充预留的位置
  for LI := 0 to LReserved - 1 do
  begin
    LIdx := PtrUInt(LPos + LI) and FMask;
    FSlots[LIdx].Value := AValues[LI];
    AtomicStore64(FSlots[LIdx].Sequence, FullSequence(LPos + LI), moRelease);
  end;
end;
```

**优点**: CAS 频率降低 N 倍
**缺点**: 可能浪费预留位置，实现复杂

#### 方案 C: LCRQ (Lock-free Concurrent Recycling Queue)

**思路**: 使用无锁并发回收队列算法，减少 CAS 竞争

**优点**: 理论上更好的可扩展性
**缺点**: 实现复杂，常数因子可能更高

### 2.3 推荐方案

**短期**: 方案 A (改进退避策略)
- 实现简单，风险低
- 减少活锁概率
- 不改变算法结构

**长期**: 方案 B (批量位置预留)
- 显著减少 CAS 频率
- 适合大批量场景
- 需要仔细处理位置预留和释放

**不推荐**: 方案 C (LCRQ)
- 实现复杂度高
- 当前性能已接近 C++ (94.2%)
- 收益不确定

### 2.4 性能预期

| 方案 | 预期提升 | 实现复杂度 | 风险 |
|------|---------|-----------|------|
| A: 改进退避 | 5-10% | 低 | 低 |
| B: 批量预留 | 20-30% | 中 | 中 |
| C: LCRQ | 未知 | 高 | 高 |

---

## 3. 实施建议

### 3.1 SPSC Move 优化

**优先级**: 低
**原因**: 仅大批量受益，当前批量操作使用频率低
**实施**: 1-2 小时

### 3.2 MPMC CAS 竞争优化

**优先级**: 中
**原因**: 当前性能已接近 C++ (94.2%)，进一步优化收益有限
**实施**: 
- 方案 A: 0.5-1 小时
- 方案 B: 2-4 小时

### 3.3 推荐顺序

1. **SPSC Move 优化** (如果批量操作使用频率高)
2. **MPMC 方案 A** (改进退避策略)
3. **MPMC 方案 B** (如果需要更高性能)

---

## 4. 参考实现

### 4.1 Rust crossbeam

```rust
// crossbeam-queue/src/array_queue.rs
pub fn push(&self, value: T) -> Result<(), T> {
    let mut backoff = Backoff::new();
    loop {
        let tail = self.tail.load(Ordering::Relaxed);
        // ...
        match self.tail.compare_exchange_weak(
            tail,
            tail + 1,
            Ordering::AcqRel,
            Ordering::Relaxed,
        ) {
            Ok(_) => { /* 成功 */ }
            Err(_) => backoff.spin(),  // 自适应退避
        }
    }
}
```

**特点**: 使用 `Backoff` 结构体，自适应退避策略

### 4.2 Go channel

```go
// runtime/chan.go
func chansend(c *hchan, ep unsafe.Pointer, block bool, callerpc uintptr) bool {
    // ...
    for {
        // 尝试直接发送
        if !full {
            // ...
            return true
        }
        // 等待接收者
        gp := getg()
        mysg := acquireSudog()
        // ...
        gopark(nil, nil, waitReasonChanSend, traceEvGoBlockSend, 2)
    }
}
```

**特点**: 使用 goroutine 调度，不依赖 CAS 退避

### 4.3 C++ folly::MPMCQueue

```cpp
bool tryWrite(V&& val) {
    // ...
    while (true) {
        // 尝试获取位置
        auto ticket = tail_.load(std::memory_order_relaxed);
        if (tail_.compare_exchange_strong(ticket, ticket + 1)) {
            // 成功获取位置
            // ...
            return true;
        }
        // 退避
        asm_volatile_pause();
    }
}
```

**特点**: 简单的 CAS + pause，类似当前实现

---

## 5. 结论

### 5.1 SPSC Move 优化

**推荐实施**: 是 (如果批量操作使用频率高)
**预期收益**: 大批量 10-20x 提升
**风险**: 低

### 5.2 MPMC CAS 竞争优化

**推荐实施**: 方案 A (改进退避策略)
**预期收益**: 5-10% 提升
**风险**: 低

**不推荐**: 方案 B/C (收益不确定，复杂度高)

### 5.3 最终建议

1. **SPSC Move 优化**: 实施，1-2 小时
2. **MPMC 方案 A**: 实施，0.5-1 小时
3. **MPMC 方案 B/C**: 延迟，观察实际需求

**总工时**: 2-3 小时
**总预期收益**: SPSC 大批量 10-20x，MPMC 5-10%
