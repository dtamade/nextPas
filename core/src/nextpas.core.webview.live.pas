unit nextpas.core.webview.live;

{** @desc webview 家族活窗注册表（家族内共享，不经门面）。

       Vec 单源 bytes.ops（VecGrow/Capacity 0→4→2× inline，VecRemoveSwap O(1) 零拷贝），live 已反哺 L1 bytes.ops.TCompactLiveRegistry 单源；
       池化已反哺 L1 sync.pool.SyncPoolTryAcquire/Release 单源，gtk.pool 双池复用；
       本单元均为 inline 薄转发零额外调用，主线程调用、短临界 <1µs 指针-only，析构 Default(T) 释放不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex,
  nextpas.core.sync.pool;

{ 紧凑 Vec：bytes.ops 单源 inline 薄转发 }
generic procedure WebviewLiveAdd<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
generic procedure WebviewLiveRemove<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
generic procedure WebviewLiveRemoveSwap<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
{ 池化 Slab：已反哺 L1 sync.pool 单源 inline 薄转发，家族内薄别名 }
generic function WebviewPoolTryAcquire<T>(var APool: array of T; var ACount: Integer; ALock: TMutex): T; inline;
generic function WebviewPoolTryRelease<T>(var APool: array of T; var ACount: Integer; ALock: TMutex; const AItem: T): Boolean; inline;

type
  { L1 薄别名：TCompactLiveRegistry 单源，inline 零额外调用 }
  generic TWebviewLiveRegistry<T> = class(specialize TCompactLiveRegistry<T>)
  end;

implementation

generic procedure WebviewLiveAdd<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
begin
  // perf: single source VecGrow -> VecGrowCapacity (0→4→2×) inline, zero extra call
  specialize VecGrow<T>(AList, ACount);
  AList[ACount] := AInst;
  Inc(ACount);
end;

generic procedure WebviewLiveRemove<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
begin
  // perf: single source bytes.ops VecRemoveOrdered O(n) 保序搬移 single source; not inline per design-conventions §2 红线二 (real loop bans inline, avoids I-Cache bloat), trailing Default(T) 释放 ref 不丢；order-sensitive 保留，热关闭路径请用 Swap
  specialize VecRemoveOrdered<T>(AList, ACount, AInst);
end;

generic procedure WebviewLiveRemoveSwap<T>(var AList: array of T; var ACount: Integer; const AInst: T); inline;
begin
  // perf: single source bytes.ops VecRemoveSwap inline O(1) 零拷贝末尾换位，trailing Default(T) 释放 ref，不保序，热关闭默认避免 O(n²)
  specialize VecRemoveSwap<T>(AList, ACount, AInst);
end;

generic function WebviewPoolTryAcquire<T>(var APool: array of T; var ACount: Integer; ALock: TMutex): T; inline;
begin
  // L1 单源 inline 薄转发，短临界指针-only <1µs，堆分配在锁外
  Result := specialize SyncPoolTryAcquire<T>(APool, ACount, ALock);
end;

generic function WebviewPoolTryRelease<T>(var APool: array of T; var ACount: Integer; ALock: TMutex; const AItem: T): Boolean; inline;
begin
  // L1 单源 inline 薄转发，短临界指针-only，溢出 Dispose 在外单所有权不丢
  Result := specialize SyncPoolTryRelease<T>(APool, ACount, ALock, AItem);
end;

end.
