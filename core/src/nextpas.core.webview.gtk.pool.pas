unit nextpas.core.webview.gtk.pool;

{** @desc GTK dispatcher 池化 Slab：Idle / Completion 双池复用。

       单源复用：
       - 容量：bytes.ops.VecGrowCapacity (0→4→2×) 预分配单源，与 live/viewmap 资产单源一致
       - 操作：webview.live.WebviewPoolTryAcquire/Release 泛型单源，短临界区指针-only，堆分配在锁外

       性能：
       - 零每 Post 堆分配（Slab 复用 PIdleRec/PCompletionMarshal）
       - 短锁 <1µs（TryAcquire/Release inline 零拷贝），SetLength 仅初始化预分配，运行期不持锁堆分配
       - 分离 GPoolLock 与 GSchemeLock 零抢锁，GIdle/Completion 双池独立

       稳定性：Acquire New 在锁外，Release 溢出 Dispose 在外，单所有权经 destroy-notify/ g_source_remove 统一释放 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex,
  nextpas.core.webview.live;

type
  TWebviewProcRef = reference to procedure;
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
  Result := specialize WebviewPoolTryAcquire<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock);
  if Result = nil then
    New(Result);
end;

procedure ReleaseIdleRec(A: PIdleRec); inline;
begin
  if A = nil then Exit;
  A^.Proc := nil;
  if not specialize WebviewPoolTryRelease<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock, A) then
    Dispose(A);
end;

function AcquireCompletionRec: PCompletionMarshal; inline;
begin
  Result := specialize WebviewPoolTryAcquire<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock);
  if Result = nil then
    New(Result);
end;

procedure ReleaseCompletionRec(A: PCompletionMarshal); inline;
begin
  if A = nil then Exit;
  A^.Win := nil;
  A^.FrameId := 0;
  A^.Cmd := '';
  A^.IsError := False;
  A^.ResultJson := '';
  A^.Code := '';
  A^.MsgText := '';
  if not specialize WebviewPoolTryRelease<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock, A) then
    Dispose(A);
end;

procedure PoolInit; inline;
begin
  GPoolLock := TMutex.Create;
  SetLength(GIdlePool, VecGrowCapacity(VecGrowCapacity(0)));
  SetLength(GCompletionPool, VecGrowCapacity(VecGrowCapacity(0)));
end;

procedure PoolFinalize; inline;
begin
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
