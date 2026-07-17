{**
 * Lockfree 数据结构使用示例
 *
 * 演示 nextpas.core.lockfree 模块中各种并发数据结构的使用方法：
 * - SPSC Queue: 单生产者单消费者队列
 * - MPMC Queue: 多生产者多消费者队列
 * - Channel: 有界通道（Go channel 语义）
 * - Selector: 多路复用器（Go select 语义）
 * - HashMap: 分片并发 HashMap
 * - Priority Queue: 并发优先队列
 *}
program lockfree_example;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.lockfree.priority_queue;

{ 示例 1: SPSC Queue - 单生产者单消费者 }
procedure ExampleSpscQueue;
var
  LQueue: specialize TSpscQueue<Int32>;
  LValue: Int32;
  I: Int32;
begin
  WriteLn('=== SPSC Queue 示例 ===');

  LQueue := specialize TSpscQueue<Int32>.Create(1024);
  try
    { 生产者：入队 10 个元素 }
    for I := 1 to 10 do
    begin
      if LQueue.TryEnqueue(I) then
        WriteLn('  入队: ', I)
      else
        WriteLn('  队列满，无法入队: ', I);
    end;

    WriteLn('  队列长度: ', LQueue.ApproxCount);

    { 消费者：出队所有元素 }
    WriteLn('  出队:');
    while LQueue.TryDequeue(LValue) do
      WriteLn('    ', LValue);

    WriteLn('  队列空: ', LQueue.IsEmpty);
  finally
    LQueue.Free;
  end;
  WriteLn;
end;

{ 示例 2: MPMC Queue - 多生产者多消费者 }
procedure ExampleMpmcQueue;
var
  LQueue: specialize TMpmcQueue<Int32>;
  LBatch: array[0..4] of Int32;
  LResult: PtrUInt;
  LValue: Int32;
  I: Int32;
begin
  WriteLn('=== MPMC Queue 示例 ===');

  LQueue := specialize TMpmcQueue<Int32>.Create(1024);
  try
    { 批量入队 }
    for I := 0 to 4 do
      LBatch[I] := (I + 1) * 10;
    LResult := LQueue.EnqueueBatch(LBatch);
    WriteLn('  批量入队: ', LResult, ' 个元素');

    { 批量出队 }
    LResult := LQueue.DequeueBatch(LBatch, 5);
    WriteLn('  批量出队: ', LResult, ' 个元素:');
    for I := 0 to LResult - 1 do
      WriteLn('    ', LBatch[I]);

    { 阻塞等待 }
    WriteLn('  尝试阻塞出队（队列空，会超时）...');
    if LQueue.DequeueTimeout(LValue, 1000000) then { 1ms 超时 }
      WriteLn('    出队: ', LValue)
    else
      WriteLn('    超时，队列为空');
  finally
    LQueue.Free;
  end;
  WriteLn;
end;

{ 示例 3: Channel - 有界通道 }
procedure ExampleChannel;
var
  LChannel: specialize TLockFreeChannel<Int32>;
  LValue: Int32;
begin
  WriteLn('=== Channel 示例 ===');

  LChannel := specialize TLockFreeChannel<Int32>.Create(16);
  try
    { 非阻塞发送 }
    if LChannel.TrySend(42) then
      WriteLn('  发送: 42');

    if LChannel.TrySend(100) then
      WriteLn('  发送: 100');

    WriteLn('  通道长度: ', LChannel.ApproxLen);

    { 非阻塞接收 }
    if LChannel.TryReceive(LValue) then
      WriteLn('  接收: ', LValue);

    if LChannel.TryReceive(LValue) then
      WriteLn('  接收: ', LValue);

    WriteLn('  通道空: ', LChannel.IsEmpty);

    { 关闭通道 }
    LChannel.Close;
    WriteLn('  通道已关闭: ', LChannel.IsClosed);

    { 关闭后发送会失败 }
    if not LChannel.TrySend(999) then
      WriteLn('  关闭后发送失败（符合预期）');
  finally
    LChannel.Free;
  end;
  WriteLn;
end;

{ 示例 4: Selector - 多路复用 }
procedure ExampleSelector;
var
  LCh1, LCh2: specialize TLockFreeChannel<Int32>;
  LSelector: specialize TLockFreeSelector<Int32>;
  LValue: Int32;
  LResult: TSelectResult;
begin
  WriteLn('=== Selector 示例 ===');

  LCh1 := specialize TLockFreeChannel<Int32>.Create(16);
  LCh2 := specialize TLockFreeChannel<Int32>.Create(16);
  try
    { 向两个通道发送数据 }
    LCh1.TrySend(100);
    LCh2.TrySend(200);

    { 创建 selector }
    LSelector := specialize TLockFreeSelector<Int32>.Create;
    try
      LSelector.AddRecv(LCh1, LValue);
      LSelector.AddRecv(LCh2, LValue);

      { 尝试选择 }
      LResult := LSelector.TrySelect;
      if LResult.Completed then
        WriteLn('  从通道 ', LResult.Index, ' 接收: ', LValue);

      LResult := LSelector.TrySelect;
      if LResult.Completed then
        WriteLn('  从通道 ', LResult.Index, ' 接收: ', LValue);
    finally
      LSelector.Free;
    end;
  finally
    LCh1.Free;
    LCh2.Free;
  end;
  WriteLn;
end;

{ 示例 5: HashMap - 分片并发 HashMap }
procedure ExampleHashMap;
var
  LMap: specialize TShardedHashMap<Int32, Int32>;
  LValue: Int32;
  LResult: specialize TShardedHashMap<Int32, Int32>.TGetOrInsertResult;
begin
  WriteLn('=== HashMap 示例 ===');

  LMap := specialize TShardedHashMap<Int32, Int32>.Create;
  try
    { 插入 }
    LMap.Insert(1, 100);
    LMap.Insert(2, 200);
    LMap.Insert(3, 300);
    WriteLn('  插入 3 个键值对: {1:100, 2:200, 3:300}');

    { 查找 }
    if LMap.Find(1, LValue) then
      WriteLn('  查找 key=1: ', LValue);

    if LMap.Find(2, LValue) then
      WriteLn('  查找 key=2: ', LValue);

    { 包含检查 }
    WriteLn('  包含 key=3: ', LMap.Contains(3));
    WriteLn('  包含 key=4: ', LMap.Contains(4));

    { 删除 }
    LMap.Remove(2);
    WriteLn('  删除 key=2 后，包含: ', LMap.Contains(2));

    { GetOrInsert }
    LResult := LMap.GetOrInsert(4, 400);
    WriteLn('  GetOrInsert key=4: value=', LResult.Value, ' existed=', LResult.Existed);

    LResult := LMap.GetOrInsert(4, 999);
    WriteLn('  GetOrInsert key=4: value=', LResult.Value, ' existed=', LResult.Existed);

    WriteLn('  元素数量: ', LMap.Count);
  finally
    LMap.Free;
  end;
  WriteLn;
end;

{ 示例 6: Priority Queue - 并发优先队列 }

function CompareInt32(const A, B: Int32): Integer;
begin
  if A < B then
    Result := -1
  else if A > B then
    Result := 1
  else
    Result := 0;
end;

procedure ExamplePriorityQueue;
var
  LPQ: specialize TConcurrentPriorityQueue<Int32>;
  LValue: Int32;
begin
  WriteLn('=== Priority Queue 示例 ===');

  LPQ := specialize TConcurrentPriorityQueue<Int32>.Create(@CompareInt32);
  try
    { 入队（最小堆） }
    LPQ.Enqueue(30);
    LPQ.Enqueue(10);
    LPQ.Enqueue(50);
    LPQ.Enqueue(20);
    LPQ.Enqueue(40);
    WriteLn('  入队: 30, 10, 50, 20, 40');

    WriteLn('  队列大小: ', LPQ.Count);

    { 出队（按优先级排序） }
    WriteLn('  凭优先级出队:');
    while LPQ.TryDequeue(LValue) do
      WriteLn('    ', LValue);

    WriteLn('  队列空: ', LPQ.IsEmpty);
  finally
    LPQ.Free;
  end;
  WriteLn;
end;

{ 示例 7: 原子操作 }
procedure ExampleAtomics;
var
  LCounter: TAtomicInt32;
  LOld: Int32;
begin
  WriteLn('=== 原子操作示例 ===');

  LCounter := Default(TAtomicInt32);
  LCounter.Store(0);

  { FetchAdd }
  LOld := LCounter.FetchAdd(10);
  WriteLn('  FetchAdd(10): 旧值=', LOld, ', 新值=', LCounter.Load);

  { FetchSub }
  LOld := LCounter.FetchSub(3);
  WriteLn('  FetchSub(3): 旧值=', LOld, ', 新值=', LCounter.Load);

  { CompareExchange }
  if LCounter.CompareExchangeStrong(LOld, 100) then
    WriteLn('  CAS(7 -> 100): 成功')
  else
    WriteLn('  CAS(7 -> 100): 失败, 当前值=', LCounter.Load);

  { Exchange }
  LOld := LCounter.Exchange(200);
  WriteLn('  Exchange(200): 旧值=', LOld, ', 新值=', LCounter.Load);

  WriteLn;
end;

{ 主程序 }
begin
  WriteLn('nextpas.core.lockfree 使用示例');
  WriteLn('==============================');
  WriteLn;

  ExampleSpscQueue;
  ExampleMpmcQueue;
  ExampleChannel;
  ExampleSelector;
  ExampleHashMap;
  ExamplePriorityQueue;
  ExampleAtomics;

  WriteLn('所有示例执行完毕！');
end.
