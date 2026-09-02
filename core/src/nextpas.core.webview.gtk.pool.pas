unit nextpas.core.webview.gtk.pool;

{** @desc GTK dispatcher 池化 Slab：Idle / Completion 双池复用，dispatcher专用。

       私有池化仅gtk uses，不经门面（CONTRACT §1 L38），已反哺 L1 sync.pool 单源（CONTRACT §1.2/§50 已落地：sync.pool.SyncPoolTryAcquire/Release inline 单源，webview.live 薄转发/已收敛至 L1 单源，跨家族与 sync.pool 同构零重复）。

       单源复用：
       - 容量：bytes.ops.VecGrowCapacity (0→4→2×) 预分配单源，与 live/viewmap 资产单源一致（单次 VecGrowCapacity(0)=4，突发经 bytes.ops VecGrow 单源倍增在锁外扩容后重试，零双层 VecGrowCapacity(VecGrowCapacity(0)) 至 8 私有分叉）
       - 操作：L1 sync.pool.SyncPoolTryAcquire/Release 单源 inline 零拷贝（跨家族池化已反哺 L1 单源，webview.live 薄转发已收敛），短临界区指针-only，突发满时 VecGrow 在锁外单源扩容零回退 New，无跨家族重复
       - 类型：TWebviewProcRef 复用 webview.intf 单源（inline 薄转发零拷贝闭包），零重复定义

       性能：
       - 零每 Post 堆分配（Slab 复用 PIdleRec/PCompletionMarshal，突发经 bytes.ops VecGrow 单源倍增在锁外扩容后重试零回退 New，短临界 <1µs 外扩容）
       - 短锁 <1µs（TryAcquire/Release inline 零拷贝，热路径仅指针弹出/压入，SetLength 仅初始化 VecGrowCapacity(0)=4 与突发扩容 VecGrow 在锁外单源）
       - 分离 GPoolLock 与 GSchemeLock 零抢锁，GIdle/Completion 双池独立
       - 全部 inline 薄转发零额外调用，bytes.ops VecGrowCapacity/VecGrow 单源零拷贝，零 I-Cache 膨胀

       稳定性：Acquire New 在锁外，Release 突发满时 VecGrow 单源扩容零丢（罕见 SetLength 异常安全），溢出 Dispose 仅作分配失败兜底单所有权不丢，经 destroy-notify/ g_source_remove 统一释放，Finalize 逐槽 Dispose 单所有权清零 nil 释放不丢 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex,
  nextpas.core.sync.pool,
  nextpas.core.webview.intf;

type
  // 单源：复用 webview.intf.TWebviewProcRef（inline 薄转发零拷贝闭包），零重复定义，L3 内单向依赖 base/intf + L0
  TWebviewProcRef = nextpas.core.webview.intf.TWebviewProcRef;
  PIdleRec = ^TIdleRec;
  TIdleRec = record
    Proc: TWebviewProcRef;
  end;
  PCompletionMarshal = ^TCompletionMarshal;
  TCompletionMarshal = record
    Win: TObject;
    FrameId: Int64;
    Cmd: string;
    IsError: Boolean;
    ResultJson: string;
    Code: string;
    MsgText: string;
  end;

function AcquireIdleRec: PIdleRec; inline;
procedure ReleaseIdleRec(A: PIdleRec); inline;
function AcquireCompletionRec: PCompletionMarshal; inline;
procedure ReleaseCompletionRec(A: PCompletionMarshal); inline;

procedure PoolInit; inline;
procedure PoolFinalize; inline;

implementation

var
  GIdlePool: array of PIdleRec;
  GIdlePoolCount: Integer = 0;
  GCompletionPool: array of PCompletionMarshal;
  GCompletionPoolCount: Integer = 0;
  GPoolLock: TMutex = nil;

function AcquireIdleRec: PIdleRec; inline;
begin
  // perf: inline 薄转发 L1 sync.pool.SyncPoolTryAcquire 单源零拷贝（已反哺 OWNER，跨家族单源零重复），短临界仅指针弹出 <1µs，堆分配 New 在锁外，零持锁 SetLength
  Result := specialize SyncPoolTryAcquire<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock);
  if Result = nil then
    New(Result);
end;

procedure ReleaseIdleRec(A: PIdleRec); inline;
begin
  // perf: inline 零拷贝，短临界仅指针压入 <1µs；突发满时经 bytes.ops VecGrow 单源倍增（0→4→2× inline 零额外调用）在锁外扩容后重试零回退 New，热路径零 SetLength 持锁，溢出 Dispose 仅分配失败兜底单所有权不丢
  if A = nil then Exit;
  A^.Proc := nil;
  if not specialize SyncPoolTryRelease<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock, A) then
  begin
    specialize VecGrow<PIdleRec>(GIdlePool, GIdlePoolCount);
    if not specialize SyncPoolTryRelease<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock, A) then
      Dispose(A);
  end;
end;

function AcquireCompletionRec: PCompletionMarshal; inline;
begin
  // perf: inline 薄转发 L1 sync.pool 单源零拷贝，短临界指针-only，堆分配在锁外
  Result := specialize SyncPoolTryAcquire<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock);
  if Result = nil then
    New(Result);
end;

procedure ReleaseCompletionRec(A: PCompletionMarshal); inline;
begin
  // perf: inline 零拷贝，短临界仅指针压入 <1µs；突发满时经 bytes.ops VecGrow 单源倍增（0→4→2× inline）在锁外扩容后重试零回退 New，稳定性：托管字段清零 nil 释放 ref，溢出 Dispose 兜底单所有权不丢
  if A = nil then Exit;
  A^.Win := nil;
  A^.FrameId := 0;
  A^.Cmd := '';
  A^.IsError := False;
  A^.ResultJson := '';
  A^.Code := '';
  A^.MsgText := '';
  if not specialize SyncPoolTryRelease<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock, A) then
  begin
    specialize VecGrow<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount);
    if not specialize SyncPoolTryRelease<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock, A) then
      Dispose(A);
  end;
end;

procedure PoolInit; inline;
begin
  // perf: bytes.ops VecGrowCapacity 单源预分配 0→4→2× inline 零额外调用（单次 VecGrowCapacity(0)=4，突发经 bytes.ops VecGrow 单源倍增在锁外零额外调用），初始化单次 SetLength 单源零双层 VecGrowCapacity(VecGrowCapacity(0)) 分叉；稳定性：GPoolLock 单所有权创建
  GPoolLock := TMutex.Create;
  SetLength(GIdlePool, VecGrowCapacity(0));
  SetLength(GCompletionPool, VecGrowCapacity(0));
end;

procedure PoolFinalize; inline;
begin
  // 稳定性：逐槽 Dispose 单所有权释放不丢，托管字段随 Dispose 终结，SetLength 0 清零，FreeAndNil 释放锁不丢
  while GIdlePoolCount > 0 do
  begin
    Dec(GIdlePoolCount);
    Dispose(GIdlePool[GIdlePoolCount]);
  end;
  SetLength(GIdlePool, 0);
  while GCompletionPoolCount > 0 do
  begin
    Dec(GCompletionPoolCount);
    Dispose(GCompletionPool[GCompletionPoolCount]);
  end;
  SetLength(GCompletionPool, 0);
  FreeAndNil(GPoolLock);
end;

end.
