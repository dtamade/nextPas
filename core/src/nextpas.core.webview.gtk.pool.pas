unit nextpas.core.webview.gtk.pool;

{** @desc GTK dispatcher Slab 池化：Idle / Completion / AssetHolder / Eval 四池私有复用，dispatcher 专用。

       契约：容量/操作单源 L1 bytes.ops / sync.pool，类型单源 webview.intf，私于 gtk 不经门面（CONTRACT §1）。
       性能：inline 薄转发零拷贝，热路径短临界 <1µs，Slab 零每 Post 堆分配，GPoolLock 与 GSchemeLock 分离。
       稳定性：锁外 New / 锁内 VecGrow 扩容异常安全，溢出 Dispose 兜底单所有权不丢，Finalize 逐槽释放。 *}

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
  PAssetHolder = ^TAssetHolder;
  TAssetHolder = record
    Bytes: TBytes;
  end;
  PEvalRec = ^TEvalRec;
  TEvalRec = record
    Callback: TWebviewEvalCallback;
    OnError: TWebviewEvalErrorCallback;
    Done: Boolean;
    Cancel: Pointer;
    Owner: Pointer;
  end;

function AcquireIdleRec: PIdleRec; inline;
procedure ReleaseIdleRec(A: PIdleRec); inline;
function AcquireCompletionRec: PCompletionMarshal; inline;
procedure ReleaseCompletionRec(A: PCompletionMarshal); inline;
function AcquireAssetHolder: PAssetHolder; inline;
procedure ReleaseAssetHolder(A: PAssetHolder); inline;
function AcquireEvalRec: PEvalRec; inline;
procedure ReleaseEvalRec(A: PEvalRec); inline;

procedure PoolInit; inline;
procedure PoolFinalize; inline;

implementation

var
  GIdlePool: array of PIdleRec;
  GIdlePoolCount: Integer = 0;
  GCompletionPool: array of PCompletionMarshal;
  GCompletionPoolCount: Integer = 0;
  GAssetHolderPool: array of PAssetHolder;
  GAssetHolderCount: Integer = 0;
  GEvalPool: array of PEvalRec;
  GEvalPoolCount: Integer = 0;
  GPoolLock: TMutex = nil;

// 单源收口：四池 Acquire/Release 共用泛型薄转发，inline 零拷贝，New/Dispose 仅一处
generic function PoolAcquire<T>(var APool: array of T; var ACount: Integer; ALock: TMutex): T; inline;
begin
  Result := specialize SyncPoolTryAcquire<T>(APool, ACount, ALock);
  if Result = nil then
    New(Result);
end;

generic procedure PoolRelease<T>(var APool: array of T; var ACount: Integer; ALock: TMutex; AItem: T); inline;
begin
  if AItem = nil then Exit;
  if not specialize SyncPoolRelease<T>(APool, ACount, ALock, AItem) then
    Dispose(AItem);
end;

function AcquireIdleRec: PIdleRec; inline;
begin
  // inline 薄转发 PoolAcquire 单源零拷贝，短临界指针-only
  Result := specialize PoolAcquire<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock);
end;

procedure ReleaseIdleRec(A: PIdleRec); inline;
begin
  // inline 薄转发 PoolRelease 单源，托管 Proc nil 释放 ref，溢出 Dispose 兜底不丢
  if A = nil then Exit;
  A^.Proc := nil;
  specialize PoolRelease<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock, A);
end;

function AcquireCompletionRec: PCompletionMarshal; inline;
begin
  // inline 薄转发单源，短临界指针-only，New 在锁外
  Result := specialize PoolAcquire<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock);
end;

procedure ReleaseCompletionRec(A: PCompletionMarshal); inline;
begin
  // inline 单源，托管字段清零释放 ref，突发锁内 VecGrow 单源扩容
  if A = nil then Exit;
  A^.Win := nil; A^.FrameId := 0; A^.Cmd := ''; A^.IsError := False;
  A^.ResultJson := ''; A^.Code := ''; A^.MsgText := '';
  specialize PoolRelease<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock, A);
end;

function AcquireAssetHolder: PAssetHolder; inline;
begin
  // inline 单源，热点小文件 Holder 复用，零每请求堆分配
  Result := specialize PoolAcquire<PAssetHolder>(GAssetHolderPool, GAssetHolderCount, GPoolLock);
end;

procedure ReleaseAssetHolder(A: PAssetHolder); inline;
begin
  // inline 单源，Bytes nil 释放 ref，溢出 Dispose 兜底不丢
  if A = nil then Exit;
  A^.Bytes := nil;
  specialize PoolRelease<PAssetHolder>(GAssetHolderPool, GAssetHolderCount, GPoolLock, A);
end;

function AcquireEvalRec: PEvalRec; inline;
begin
  // inline 单源，Eval 零每帧堆分配，字段清零初始化
  Result := specialize PoolAcquire<PEvalRec>(GEvalPool, GEvalPoolCount, GPoolLock);
  Result^.Callback := nil; Result^.OnError := nil; Result^.Done := False; Result^.Cancel := nil; Result^.Owner := nil;
end;

procedure ReleaseEvalRec(A: PEvalRec); inline;
begin
  // inline 单源，托管 Callback/OnError nil 释放 ref，Cancel 置 nil 不双重释放
  if A = nil then Exit;
  A^.Callback := nil; A^.OnError := nil; A^.Done := False; A^.Owner := nil; A^.Cancel := nil;
  specialize PoolRelease<PEvalRec>(GEvalPool, GEvalPoolCount, GPoolLock, A);
end;

procedure PoolInit; inline;
var
  LCap: Integer;
begin
  // 批量化：单次 VecGrowCapacity(0) 计算批量预分配四池，零 4 次重复调用，单源 0→4→2×
  GPoolLock := TMutex.Create;
  LCap := VecGrowCapacity(0);
  SetLength(GIdlePool, LCap);
  SetLength(GCompletionPool, LCap);
  SetLength(GAssetHolderPool, LCap);
  SetLength(GEvalPool, LCap);
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
  while GAssetHolderCount > 0 do
  begin
    Dec(GAssetHolderCount);
    Dispose(GAssetHolder[GAssetHolderCount]);
  end;
  SetLength(GAssetHolderPool, 0);
  while GEvalPoolCount > 0 do
  begin
    Dec(GEvalPoolCount);
    Dispose(GEvalPool[GEvalPoolCount]);
  end;
  SetLength(GEvalPool, 0);
  FreeAndNil(GPoolLock);
end;

end.
