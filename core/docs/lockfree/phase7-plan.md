> **归档**（2026-07-17）：历史 Phase 7 计划。推进主线见 [`roadmap.md`](roadmap.md)。

# Phase 7: EBR Per-thread Retire Buffer

> 创建: 2026-07-06 | 状态: ✅ 实现完成

## 目标

优化 `TEbrDomain.Retire` 的 CAS contention。每次调用都 CAS 操作全局链表，高并发时有 cacheline bouncing。

## 方案实现

### pthread_key_create + 析构函数 ✅

**实现**:
```pascal
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

type
  PEbrThreadBuffer = ^TEbrThreadBuffer;
  TEbrThreadBuffer = record
    Domain: TEbrDomain;
    Count: Int32;
    Entries: array[0..15] of record
      Data: Pointer;
      Reclaim: TLockFreeReclaimProc;
      UserData: Pointer;
    end;
  end;

var
  GEbrTlsKey: pthread_key_t;

procedure EbrThreadBufferDestructor(AValue: Pointer); cdecl;
begin
  { 线程退出时自动 flush 缓冲区 }
  FlushBufferToDomain(PEbrThreadBuffer(AValue));
  FreeMem(AValue);
end;

procedure TEbrDomain.Retire(...);
var
  LBuffer: PEbrThreadBuffer;
begin
  LBuffer := GetThreadBuffer(Self);
  LBuffer^.Entries[LBuffer^.Count] := entry;
  Inc(LBuffer^.Count);
  if LBuffer^.Count >= 16 then
    FlushThreadBuffer(Self);
end;

initialization
  pthread_key_create(@GEbrTlsKey, @EbrThreadBufferDestructor);

finalization
  { 主线程退出时清理 }
  EbrThreadBufferDestructor(pthread_getspecific(GEbrTlsKey));
  pthread_key_delete(GEbrTlsKey);
```

**收益**:
- 减少 ~94% 的 CAS 操作（16 次 retire → 1 次 CAS）
- 线程退出时自动 flush，无内存泄漏
- 主线程在 finalization 段清理

**测试验证**:
- 主测试: 129 passed, 0 failed, 0 leaks
- 压力测试: 16 passed, 0 failed, 0 leaks

## 方案对比

| 方案 | 状态 | 原因 |
|------|------|------|
| threadvar | ❌ 不可行 | 线程退出时泄漏 |
| pthread_key + 析构 | ✅ 实现 | 线程安全，自动清理 |
| Domain 内 buffer | ⚠️ 复杂 | 需要手动管理生命周期 |

## 结论

使用 `pthread_key_create` + 析构函数是正确的方案。解决了 `threadvar` 的限制，实现了：
1. Per-thread 缓冲区减少 CAS contention
2. 线程退出时自动 flush
3. 主线程在 finalization 段清理
4. 0 内存泄漏

---

| 任务 | 状态 | 原因 |
|------|------|------|
| pthread_key 方案 | ✅ 完成 | 线程安全，自动清理 |
| 测试验证 | ✅ 完成 | 129 + 16 tests, 0 leaks |
| 文档更新 | ✅ 完成 | 已记录方案实现 |
