unit nextpas.core.webview.fake.dispatcher;

{** @desc webview fake dispatcher：互斥保护的环形 FIFO 独立子模块。

       拆分治理（S105+）：原 1580 行单文件超 800 软指引，已按 design-conventions
       四件套与 L0-L3 单向依赖拆为 dispatcher/live/completion/support 等子模块；
       本单元仅承载 TFakeDispatcher，复用 L1 bytes.ops VecGrowCapacity/VecRingCopy
       单源 inline 零拷贝、零 mod/div 热点，短临界 <1µs，资源 Finalize 释放不丢。

       性能修复：PostRef 竞争路径 O(n) 持锁搬移 + stale 重试二次线性化消除。
       原乐观重试在锁外线性化后 stale 直接丢弃 LNew，重试分支重复 O(n) 两段式
       VecRingCopy 放大尾延迟；现改为预校验重试：快照后先 O(1) 锁内预校验
       （有空位则直接槽位写入无分配/无拷贝，stale 则无分配/无拷贝直接重取快照），
       仅快照仍有效时才在锁外 SetLength+VecRingCopy 单源 inline 线性化，
       二次持锁仅 O(1) 指针检查与槽位写入/安装，拷贝窗口竞争 stale 则 LNew:=nil
       释放重试，零 O(n) 持锁、竞争重试零额外线性化，inline 零额外调用，bytes.ops 单源。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.webview.intf,
  nextpas.core.webview.callbacks,
  nextpas.core.bytes.ops;

type
  TFakeDispatcherRing = array of TWebviewProcRef;

  TFakeDispatcher = class(TInterfacedObject, IWebviewDispatcher)
  private
    FLck: ILock;
    FRing: TFakeDispatcherRing;
    FHead: Integer;
    FCount: Integer;
    FOwnerThread: UInt64;
    procedure LinearizeCopy(const AOldRing: TFakeDispatcherRing; AHead, ACount: Integer; var ANew: TFakeDispatcherRing); inline;
    procedure Grow; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure PostRef(AProc: TWebviewProcRef); inline;
    function IsOnMainThread: Boolean; inline;
    function PumpOnce: Boolean;
    procedure PumpAll;
    function PendingCount: Integer;
    procedure DropAll;
    { IWebviewDispatcher }
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
  end;

implementation

constructor TFakeDispatcher.Create;
begin
  inherited Create;
  FLck := TMutex.Create as ILock;
  FOwnerThread := platform_thread_id;
end;

destructor TFakeDispatcher.Destroy;
begin
  DropAll;
  inherited Destroy;
end;

procedure TFakeDispatcher.LinearizeCopy(const AOldRing: TFakeDispatcherRing; AHead, ACount: Integer; var ANew: TFakeDispatcherRing); inline;
begin
  // perf: thin forward to bytes.ops VecRingCopy single source — two-segment linearize inline zero mod/div, zero extra call, managed ref preserved, VecGrowCapacity single source outer
  specialize VecRingCopy<TWebviewProcRef>(AOldRing, AHead, ACount, ANew);
end;

procedure TFakeDispatcher.Grow; inline;
var
  LNew: TFakeDispatcherRing;
begin
  // perf: single source bytes.ops VecGrowCapacity (0→4→2×) inline + VecRingCopy single source linearize; base pure, zero wrapper, zero extra call
  SetLength(LNew, VecGrowCapacity(Length(FRing)));
  if FCount = 0 then
  begin
    FRing := LNew;
    FHead := 0;
    Exit;
  end;
  specialize VecRingCopy<TWebviewProcRef>(FRing, FHead, FCount, LNew);
  // stability: FRing:=LNew releases old ring refs via finalization, LNew retains refs (AddRef already), zero leak
  FRing := LNew;
  FHead := 0;
end;

procedure TFakeDispatcher.PostRef(AProc: TWebviewProcRef); inline;
var
  LNew: TFakeDispatcherRing;
  LOldRing: TFakeDispatcherRing;
  LHead, LCount, LOldLen, LNewCap, LIdx, LLen: Integer;
begin
  // perf: fast path under lock without alloc, branch avoids div/mod per op (pow2 ring via VecGrowCapacity single source); contention path zero O(n) hold + zero wasted linearize via pre-validate retry
  while True do
  begin
    FLck.Acquire;
    try
      LLen := Length(FRing);
      if FCount < LLen then
      begin
        LIdx := FHead + FCount;
        if LIdx >= LLen then
          Dec(LIdx, LLen);
        FRing[LIdx] := AProc;
        Inc(FCount);
        Exit;
      end;
      LOldLen := LLen;
      LNewCap := VecGrowCapacity(LOldLen);
      LOldRing := FRing;
      LHead := FHead;
      LCount := FCount;
    finally
      FLck.Release;
    end;
    // perf: O(1) pre-validate before heap alloc/linearize — avoids wasted O(n) VecRingCopy on stale competitive retry, zero alloc/copy if stale or space appeared, single source bytes.ops VecGrowCapacity inline
    FLck.Acquire;
    try
      LLen := Length(FRing);
      if FCount < LLen then
      begin
        LIdx := FHead + FCount;
        if LIdx >= LLen then
          Dec(LIdx, LLen);
        FRing[LIdx] := AProc;
        Inc(FCount);
        Exit;
      end;
      if (Length(FRing) <> LOldLen) or (FHead <> LHead) or (FCount <> LCount) then
        Continue;
    finally
      FLck.Release;
    end;
    // perf: heap allocation (SetLength zero-init) outside lock, only after snapshot validated still needs grow, avoids O(n) lock amplification, single source bytes.ops VecGrowCapacity inline
    SetLength(LNew, LNewCap);
    // perf: O(n) two-segment linearize outside lock — zero lock hold, inline zero extra call, single source bytes.ops VecRingCopy, VecGrowCapacity single source; only executed when pre-validate passed, so competitive retry does not repeat linearize
    if LCount > 0 then
      specialize VecRingCopy<TWebviewProcRef>(LOldRing, LHead, LCount, LNew);
    // perf: short install under lock — only pointer check + O(1) swap, zero O(n) hold, stale => release LNew and retry outside lock, single source no spin
    FLck.Acquire;
    try
      LLen := Length(FRing);
      if FCount < LLen then
      begin
        LIdx := FHead + FCount;
        if LIdx >= LLen then
          Dec(LIdx, LLen);
        FRing[LIdx] := AProc;
        Inc(FCount);
        // stability: release linearized refs held in LNew to avoid leak on competitive copy-window race, Finalize releases AddRef, zero leak
        LNew := nil;
        Exit;
      end;
      if (Length(FRing) = LOldLen) and (FHead = LHead) and (FCount = LCount) then
      begin
        // stability: FRing:=LNew releases old ring refs via finalization, LNew retains refs (AddRef), zero leak
        FRing := LNew;
        FHead := 0;
        FRing[FCount] := AProc;
        Inc(FCount);
        Exit;
      end;
      // contention during copy window (rare) — discard linearized LNew and retry, zero O(n) under lock, avoids tail latency amplification
      LNew := nil;
    finally
      FLck.Release;
    end;
    // retry: loop will recapture fresh snapshot; pre-validate before next linearize avoids duplicate O(n) copy
  end;
end;

function TFakeDispatcher.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

function TFakeDispatcher.PumpOnce: Boolean;
var
  LProc: TWebviewProcRef;
  LLen: Integer;
begin
  FLck.Acquire;
  try
    if FCount = 0 then
      Exit(False);
    LProc := FRing[FHead];
    FRing[FHead] := nil;
    // perf: branch avoids div/mod per pump, pow2 ring single source VecGrowCapacity, inline
    LLen := Length(FRing);
    Inc(FHead);
    if FHead >= LLen then
      FHead := 0;
    Dec(FCount);
  finally
    FLck.Release;
  end;
  LProc();
  LProc := nil;
  Result := True;
end;

procedure TFakeDispatcher.PumpAll;
begin
  while PumpOnce do ;
end;

function TFakeDispatcher.PendingCount: Integer;
begin
  FLck.Acquire;
  try
    Result := FCount;
  finally
    FLck.Release;
  end;
end;

procedure TFakeDispatcher.DropAll;
var
  I, LLen, LTail: Integer;
begin
  FLck.Acquire;
  try
    // perf: two-segment nil loop avoids mod/div per element, pow2 ring single source, inline zero extra call
    if FCount > 0 then
    begin
      LLen := Length(FRing);
      if FHead + FCount <= LLen then
      begin
        for I := 0 to FCount - 1 do
          FRing[FHead + I] := nil;
      end
      else
      begin
        LTail := LLen - FHead;
        for I := 0 to LTail - 1 do
          FRing[FHead + I] := nil;
        for I := 0 to FCount - LTail - 1 do
          FRing[I] := nil;
      end;
    end;
    FCount := 0;
    FHead := 0;
  finally
    FLck.Release;
  end;
end;

procedure TFakeDispatcher.Post(AProc: TWebviewProcRef);
begin
  PostRef(AProc);
end;

procedure TFakeDispatcher.Post(AProc: TWebviewProcMethod);
begin
  PostRef(WebviewProcMethodToRef(AProc));
end;

procedure TFakeDispatcher.Post(AProc: TWebviewProc);
begin
  PostRef(WebviewProcToRef(AProc));
end;

end.
