unit nextpas.core.webview.gtk.pool;

{** @desc GTK dispatcher 池化 Slab：Idle / Completion 双池复用，dispatcher专用。

       私有池化仅gtk uses，不经门面（CONTRACT §1 L38），可抽 L1 sync.pool/mem.pool 候选已显式登记
       （CONTRACT §1.2），当前滞留家族内私有；与跨家族池化重复已收敛至 bytes.ops + live Pool 单源，
       抽取需反哺 L1 sync.pool/mem.pool owner 并经设计评审不自行外溢（L0-L3 守恒）。

       单源复用：
       - 容量：bytes.ops.VecGrowCapacity (0→4→2×) 预分配单源，与 live/viewmap 资产单源一致
       - 操作：webview.live.WebviewPoolTryAcquire/Release 泛型单源，短临界区指针-only，堆分配在锁外
       - 类型：TWebviewProcRef 复用 webview.intf 单源（inline 薄转发零拷贝闭包），零重复定义

       性能：
       - 零每 Post 堆分配（Slab 复用 PIdleRec/PCompletionMarshal）
       - 短锁 <1µs（TryAcquire/Release inline 零拷贝），SetLength 仅初始化预分配，运行期不持锁堆分配
       - 分离 GPoolLock 与 GSchemeLock 零抢锁，GIdle/Completion 双池独立
       - 全部 inline 薄转发零额外调用，bytes.ops 单源零拷贝，零 I-Cache 膨胀

       稳定性：Acquire New 在锁外，Release 溢出 Dispose 在外，单所有权经 destroy-notify/ g_source_remove 统一释放，Finalize 逐槽 Dispose 单所有权清零 nil 释放不丢 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex,
  nextpas.core.webview.intf,
  nextpas.core.webview.live;

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
  // perf: inline 薄转发 live.WebviewPoolTryAcquire 单源零拷贝，短临界仅指针弹出 <1µs，堆分配 New 在锁外，零持锁 SetLength
  Result := specialize WebviewPoolTryAcquire<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock);
  if Result = nil then
    New(Result);
end;

procedure ReleaseIdleRec(A: PIdleRec); inline;
begin
  // perf: inline 零拷贝，短临界仅指针压入，溢出 Dispose 在锁外单所有权释放不丢
  if A = nil then Exit;
  A^.Proc := nil;
  if not specialize WebviewPoolTryRelease<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock, A) then
    Dispose(A);
end;

function AcquireCompletionRec: PCompletionMarshal; inline;
begin
  // perf: inline 薄转发 live 单源零拷贝，短临界指针-only，堆分配在锁外
  Result := specialize WebviewPoolTryAcquire<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock);
  if Result = nil then
    New(Result);
end;

procedure ReleaseCompletionRec(A: PCompletionMarshal); inline;
begin
  // perf: inline 零拷贝，短临界仅指针压入，溢出 Dispose 单所有权；稳定性：托管字段清零 nil 释放 ref 不丢
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
  // perf: bytes.ops VecGrowCapacity 单源预分配 0→4→2× inline 零额外调用，初始化单次 SetLength，运行期零持锁扩容；稳定性：GPoolLock 单所有权创建
  GPoolLock := TMutex.Create;
  SetLength(GIdlePool, VecGrowCapacity(VecGrowCapacity(0)));
  SetLength(GCompletionPool, VecGrowCapacity(VecGrowCapacity(0)));
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
