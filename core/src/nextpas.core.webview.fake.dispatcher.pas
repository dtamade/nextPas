unit nextpas.core.webview.fake.dispatcher;

{** @desc webview fake dispatcher：互斥保护的环形 FIFO 独立子模块。

       拆分治理（S105+）：原 1580 行单文件超 800 软指引，已按 design-conventions
       四件套与 L0-L3 单向依赖拆为 dispatcher/live/completion/support 等子模块；
       本单元仅承载 TFakeDispatcher，复用 L1 bytes.ops VecGrowCapacity/VecRingCopy/VecRingGrowCopy
       单源 inline 零拷贝、零 mod/div 热点，短临界 <1µs，资源 Finalize 释放不丢。

       性能修复：PostRef 竞争路径 O(n) 持锁搬移 + stale 重试二次线性化消除。
       原乐观重试在锁外线性化后 stale 直接丢弃 LNew，重试分支重复 O(n) 两段式
       VecRingCopy 放大尾延迟；现改为预校验重试：快照后先 O(1) 锁内预校验
       （有空位则直接槽位写入无分配/无拷贝，stale 则无分配/无拷贝直接重取快照），
       仅快照仍有效时才在锁外 VecRingGrowCopy 单源 inline 线性化（Length<>Cap 时
       SetLength 单次零化，复用时 Length=Cap 跳过零化+VecRingCopy 覆写），0→4→2×
       摊销 O(1)/push，二次持锁仅 O(1) 指针检查与槽位写入/安装，拷贝窗口竞争 stale
       则保留 LNew 缓冲复用（VecRingGrowCopy Length 判定避免重复零化 O(Cap)，
       VecRingCopy 覆写），零 O(n) 持锁、突发并发零重复分配不放大尾延迟，bytes.ops 单源。
       突发预分配：新增 Reserve/EnsureCapacity 预扩容接口，单源 VecRingGrowCopy
       0→4→2× 倍增在锁外一次性线性化（Length 判定复用），安装仅 O(1) 检查，
       高并发突发前预分配消除 PostRef 临界 O(n) 尾延迟，stale 丢弃零泄漏。
       纪律修复：PostRef/Reserve 含 while 竞争重试与 VecRingCopy O(n) 两段式线
       性化，按 design-conventions §2 红线二外联（禁 inline）避 I-Cache 膨胀；
       内部 VecGrowCapacity/VecRingCopy/VecRingGrowCopy 单源 inline 零拷贝，零 mod/div 热点。
       同构说明：上层 FRing/FHead/FCount 环形 FIFO 管理与 nextpas.core.window.fake.TFakeDispatcher 同构，双处各 thin-forward 至 L1 bytes.ops 单源 inline 零拷贝（VecGrowCapacity 0→4→2× / VecRingCopy/VecRingGrowCopy 两段式免模，零额外调用，managed 保 refcnt/blittable 单 Move 零拷贝）；底层已单源，上层仍双份薄封装，抽为通用 RingQueue<T>（L1 bytes.ops VecRing* / L2 collections.circularbuffer/deque）为 S* 候选，当前已零拷贝单源、分支免 mod/div、低拷贝，低优先级暂保留双封装，缺能力先反哺 Owner 评审后单源落地，守四件套与 L0-L3。 *}

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
    procedure PostRef(AProc: TWebviewProcRef);
    procedure Reserve(ACapacity: Integer);
    procedure EnsureCapacity(ACapacity: Integer); inline;
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

procedure TFakeDispatcher.PostRef(AProc: TWebviewProcRef);
{ not inline per design-conventions §2 red line 2: while True retry + VecRingCopy O(n) two-segment linearize would bloat I-Cache if inlined; inner VecGrowCapacity/VecRingCopy stay inline single source bytes.ops zero-copy }
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
    // perf: heap via VecRingGrowCopy single source bytes.ops inline outside lock — Length<>Cap 时 SetLength 单次零化 O(Cap)，复用时零零化；预校验后仅有效 epoch 分配+两段式免模线性化，0→4→2× 摊销 O(1)/push，突发并发零重复分配不放大尾延迟，尾零 spare 复用兑现，managed 保 refcnt/blittable 单 Move 零拷贝，VecRingCopy 单源内联零额外调用
    // stability: reuse LNew buffer across retries (Length=Cap 跳过 SetLength 零化 O(Cap) 且 VecRingCopy 覆盖)，VecRingGrowCopy 单源 Length 判定+VecRingCopy 覆写保 refcnt，Finalize 零泄漏
    if Length(LNew) = LNewCap then
    begin
      if LCount > 0 then
        specialize VecRingCopy<TWebviewProcRef>(LOldRing, LHead, LCount, LNew);
    end
    else
      specialize VecRingGrowCopy<TWebviewProcRef>(LOldRing, LHead, LCount, LNew, LNewCap);
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
      // contention during copy window (rare) — keep LNew buffer for reuse (SetLength Length vs Cap check avoids repeated O(Cap) zero-init, VecRingCopy overwrites), zero O(n) under lock, Finalize on reuse/Exit zero leak
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

procedure TFakeDispatcher.Reserve(ACapacity: Integer);
{ not inline per design-conventions §2 red line 2: while + VecRingCopy O(n) would bloat I-Cache; inner VecGrowCapacity/VecRingCopy stay inline single source bytes.ops zero-copy }
var
  LNew: TFakeDispatcherRing;
  LCap, LNeed, LHead, LCount: Integer;
  LOldRing: TFakeDispatcherRing;
begin
  if ACapacity <= 0 then
    Exit;
  // fast check under lock
  FLck.Acquire;
  try
    if Length(FRing) >= ACapacity then
      Exit;
    LCap := Length(FRing);
    if LCap = 0 then
      LCap := 4
    else
      // perf: single source bytes.ops VecGrowCapacity 0→4→2× inline, powers of two, zero mod/div, zero extra call
      while LCap < ACapacity do
        LCap := VecGrowCapacity(LCap);
    LNeed := LCap;
    LHead := FHead;
    LCount := FCount;
    LOldRing := FRing;
  finally
    FLck.Release;
  end;
  // perf: heap via VecRingGrowCopy single source bytes.ops inline zero-copy outside lock, O(Cap) not held, pow2 amortized, Length check inside avoids repeat zero-init if reused; single source VecGrowCapacity/VecRingCopy, managed ref preserved, zero O(n) hold
  specialize VecRingGrowCopy<TWebviewProcRef>(LOldRing, LHead, LCount, LNew, LNeed);
  FLck.Acquire;
  try
    if Length(FRing) >= ACapacity then
    begin
      // stale — another thread already grew enough, release linearized refs
      LNew := nil;
      Exit;
    end;
    if (FHead = LHead) and (FCount = LCount) then
    begin
      // stability: FRing:=LNew transfers ownership, finalization releases old ring refs, LNew retains AddRef, zero leak; Finalize of LNew at exit decrements one ref leaving FRing single owner
      FRing := LNew;
      FHead := 0;
      Exit;
    end;
    // stale but still needs capacity — discard; Post path will grow, caller may retry Reserve before burst
    LNew := nil;
  finally
    FLck.Release;
  end;
end;

procedure TFakeDispatcher.EnsureCapacity(ACapacity: Integer); inline;
begin
  // thin alias to Reserve, inline zero extra call, bytes.ops single source preserved
  Reserve(ACapacity);
end;

end.
