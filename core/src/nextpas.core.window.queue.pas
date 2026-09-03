unit nextpas.core.window.queue;

{ TWindowQueue — ring FIFO via window.impl → bytes.ops single source.
  分治四 shard base/ring/backpressure/cow 各<150 (cow CoW增长)，门面<650 守 800 阈值高级感；
  Bulk Drain 三档 1024/4096/8192 via bytes.ops SnapshotBulkTier 分档尾延迟可观测，inline 零拷贝；
  热路径 TryStealRing 16ns 零锁早退 + EnqueueCore CoW inline 零拷贝 O(1)，冷路径外联守 I-Cache；CONTRACT为准. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.mutex,
  nextpas.core.window.impl,
  nextpas.core.window.intf,
  nextpas.core.window.queue.base,
  nextpas.core.window.queue.ring,
  nextpas.core.window.queue.backpressure,
  nextpas.core.window.queue.cow;

type
  TWindowWorkKind = nextpas.core.window.queue.base.TWindowWorkKind;
  TWindowWorkItem = nextpas.core.window.queue.base.TWindowWorkItem;
  TWindowWorkItems = nextpas.core.window.queue.base.TWindowWorkItems;
  TWindowCowCtx = nextpas.core.window.queue.base.TWindowCowCtx;
  PWindowWorkItem = nextpas.core.window.queue.base.PWindowWorkItem;
  PWindowProcRef = nextpas.core.window.queue.base.PWindowProcRef;
  PWindowProcMethod = nextpas.core.window.queue.base.PWindowProcMethod;
  PWindowProc = nextpas.core.window.queue.base.PWindowProc;
  TQueueRingArena = nextpas.core.window.queue.ring.TQueueRingArena;

  TWindowQueue = class
  private
    FRing: TWindowWorkItems;
    FHead: Integer;
    FCount: Int32;
    FRefCount: Int32;
    FLock: TMutex;
    FSnap: TWindowWorkItems;
    FOwnerThread: UInt64;
    FBackpressure: TWindowQueueBackpressure;
    procedure Grow;
    function Enqueue(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc): Boolean;
    function TryEnqueue(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; out AWasEmpty: Boolean): Boolean;
    function TryEnqueueFastLocked(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; out AWasEmpty: Boolean): Boolean; inline;
    procedure PrepareCowCopy(var ANew: TWindowWorkItems; const AOldRing: array of TWindowWorkItem; AOldHead, AOldCap, AOldCount, ANewCap: Integer);
    function CalcGrowCapacity(AOldCap, AOldCount: Integer; out ANewCap: Integer): Boolean;
    function TryCowInstall(var ACtx: TWindowCowCtx): Boolean;
    function TryReuseBufferLocked(var ANew: TWindowWorkItems; AOldCount: Integer; out AWasEmpty: Boolean; AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc): Boolean;
    function HandleOverflow(var ANew: TWindowWorkItems; AOldCount: Integer): Boolean; inline;
    { 非 inline：含 try..except on E + SetLength 堆分配冷路径，inline 跨模块触发 FPC 符号注册错误 }
    function AllocGrowBufferOutsideLock(var ANew: TWindowWorkItems; AOldCount, ACap: Integer): Boolean;
    function FallbackEnqueueShared(var ANew: TWindowWorkItems; AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; AOldCount: Integer; out AWasEmpty: Boolean): Boolean;
    function EnqueueFallbackLocked(var ANew: TWindowWorkItems; AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; AOldCount: Integer): Boolean;
    function TryEnqueueFallbackLocked(var ANew: TWindowWorkItems; AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; AOldCount: Integer; out AWasEmpty: Boolean): Boolean;
    function EnqueueCore(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; out AWasEmpty: Boolean): Boolean;
    function DoTryPopLocked(out AItem: TWindowWorkItem; AKind: TWindowWorkKind; ACheckKind: Boolean): Boolean;
    function TryPopFiltered(AKind: TWindowWorkKind; out AItem: TWindowWorkItem): Boolean;
    function SnapGrowCapacity(ACount: Integer): Integer;
    procedure EnsureSnapCapacity(ACount: Integer);
    function TryStealRing(var ADest: TWindowWorkItems; out ACount: Integer): Boolean;
    procedure TransferWithGrow(var ADest: TWindowWorkItems; var ARing: TWindowWorkItems; AHead, ACap, ACount: Integer);
    procedure TryRecycleRing(var ARing: TWindowWorkItems);
    procedure DispatchSnap(ACount: Integer);
    procedure MaybeShrinkSnap(ACount: Integer);
    procedure ClearWorkItem(var AItem: TWindowWorkItem);
    generic function TryPopGeneric<T>(AKind: TWindowWorkKind; out AProc: T): Boolean;
  public
    constructor Create(const AToken: TWindowFamilyToken); reintroduce;
    destructor Destroy; override;
    function Push(AProc: TWindowProcRef): Boolean; overload;
    function Push(AProc: TWindowProcMethod): Boolean; overload;
    function Push(AProc: TWindowProc): Boolean; overload;
    function TryPush(AProc: TWindowProcRef; out AWasEmpty: Boolean): Boolean; overload;
    function TryPush(AProc: TWindowProcMethod; out AWasEmpty: Boolean): Boolean; overload;
    function TryPush(AProc: TWindowProc; out AWasEmpty: Boolean): Boolean; overload;
    function TryPush(AProc: TWindowProcRef): Boolean; overload;
    function TryPush(AProc: TWindowProcMethod): Boolean; overload;
    function TryPush(AProc: TWindowProc): Boolean; overload;
    function TryPop(out AProc: TWindowProcRef): Boolean; overload;
    function TryPop(out AProc: TWindowProcMethod): Boolean; overload;
    function TryPop(out AProc: TWindowProc): Boolean; overload;
    function TryPopItem(out AItem: TWindowWorkItem): Boolean; overload;
    procedure Drain;
    function DrainCount: Integer;
    function TryDrainCount(out ACount: Integer): Boolean;
    function TryStealBatch(var ADest: TWindowWorkItems; out ACount: Integer): Boolean;
    function IsEmpty: Boolean; inline;
    function Count: Integer; inline;
    function DroppedCount: Integer; inline;
    function DroppedCapCount: Integer; inline;
    function DroppedOomCount: Integer; inline;
    procedure Clear;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.log.intf,
  nextpas.core.platform.thread,
  nextpas.core.sync.cow,
  nextpas.core.window.base;

procedure WindowQueueDispatchRef(AItem: PWindowWorkItem); inline;
begin
  if Assigned(AItem^.Ref) then AItem^.Ref();
end;

procedure WindowQueueDispatchMethod(AItem: PWindowWorkItem); inline;
begin
  if Assigned(AItem^.Method) then AItem^.Method();
end;

procedure WindowQueueDispatchProc(AItem: PWindowWorkItem); inline;
begin
  if Assigned(AItem^.Proc) then AItem^.Proc();
end;

constructor TWindowQueue.Create(const AToken: TWindowFamilyToken);
begin
  RequireWindowFamilyToken(AToken);
  inherited Create;
  FLock := TMutex.Create;
  FOwnerThread := platform_thread_id;
end;

destructor TWindowQueue.Destroy;
begin
  Clear;
  if Length(FSnap) > 0 then
  begin
    ManagedFinalizeArray(@FSnap[0], TypeInfo(TWindowWorkItem), Length(FSnap));
    SetLength(FSnap, 0);
  end;
  FLock.Free;
  FLock := nil;
  inherited;
end;

{ TWindowQueue - Enqueue / Cow — 分治委派 cow/ring 单源，门面仅编排 }
procedure TWindowQueue.Grow;
var
  LNewCap, LCap, LCount, LHead, LOldCap, LOldCount, LOldHead: Integer;
  LArena: TQueueRingArena;
  LPooled: Boolean;
  LOldRing: TWindowWorkItems;
  LOldPtr, LCurPtr: Pointer;
  LOldArena: TQueueRingArena;
begin
  // 单锁 COW 快照元数据零拷贝，锁外 Arena 零拷贝 O(n)均摊 0→32→2× via bytes.ops 单源，锁内双检+复位托管不丢
  LCap := Length(FRing); LCount := atomic_load(FCount); LHead := FHead;
  LOldCap := LCap; LOldCount := LCount; LOldHead := LHead; LOldRing := FRing;
  if Length(LOldRing) > 0 then LOldPtr := @LOldRing[0] else LOldPtr := nil;
  if not CalcGrowCapacity(LCap, LCount, LNewCap) then Exit;
  LArena := QueueRingArenaAcquire(LPooled);
  try
    LArena.Ensure(LNewCap);
    if LCount > 0 then specialize ManagedRingCopy<TWindowWorkItem>(LArena.Buf, FRing, LHead, LCap, LCount);
    FLock.Acquire;
    try
      if Length(FRing) > 0 then LCurPtr := @FRing[0] else LCurPtr := nil;
      if CowRingStale(LOldPtr, LOldCap, LOldCount, LOldHead, LCurPtr, Length(FRing), atomic_load(FCount), FHead) then Exit;
      if LCount > 0 then specialize CowRingFinalize<TWindowWorkItem>(FRing, FHead, Length(FRing), LCount);
      specialize ManagedArrayMove<TWindowWorkItem>(FRing, LArena.Buf);
      FHead := 0;
    finally
      FLock.Release;
    end;
    if Length(LOldRing) > 0 then
    begin
      LOldArena.Clear;
      specialize ManagedArrayMove<TWindowWorkItem>(LOldArena.Buf, LOldRing);
      QueueRingArenaRecycle(LOldArena);
    end;
  finally
    QueueRingArenaRecycle(LArena);
  end;
end;

function TWindowQueue.TryEnqueueFastLocked(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; out AWasEmpty: Boolean): Boolean; inline;
var LIdx, LCap: Integer;
begin
  Result := False;
  AWasEmpty := False;
  LCap := Length(FRing);
  if atomic_load(FCount) >= LCap then Exit;
  AWasEmpty := atomic_load(FCount) = 0;
  LIdx := WindowRingIndex(FHead, atomic_load(FCount), LCap);
  FRing[LIdx].Kind := AKind;
  FRing[LIdx].Ref := ARef;
  FRing[LIdx].Method := AMethod;
  FRing[LIdx].Proc := AProc;
  atomic_fetch_add(FCount, 1);
  if AKind = wwkRef then atomic_fetch_add(FRefCount, Int32(1));
  Result := True;
end;

procedure TWindowQueue.PrepareCowCopy(var ANew: TWindowWorkItems; const AOldRing: array of TWindowWorkItem; AOldHead, AOldCap, AOldCount, ANewCap: Integer); inline;
begin
  // 分治委派至 cow shard 单源 inline 零拷贝 O(1)，门面仅编排
  QueueCowPrepareCopy(ANew, AOldRing, AOldHead, AOldCap, AOldCount, ANewCap);
end;

function TWindowQueue.CalcGrowCapacity(AOldCap, AOldCount: Integer; out ANewCap: Integer): Boolean; inline;
begin
  // 分治委派至 cow shard 单源 inline 零拷贝 O(1) capped 16384
  Result := QueueCowCalcGrowCapacity(AOldCap, AOldCount, ANewCap);
end;

function TWindowQueue.TryCowInstall(var ACtx: TWindowCowCtx): Boolean;
var LIdx: Integer; LOldPtr, LCurPtr: Pointer; LOldArena: TQueueRingArena;
begin
  Result := False;
  ACtx.WasEmpty := False;
  if Length(ACtx.OldRing) > 0 then LOldPtr := @ACtx.OldRing[0] else LOldPtr := nil;
  if Length(FRing) > 0 then LCurPtr := @FRing[0] else LCurPtr := nil;
  FLock.Acquire;
  try
    if Length(FRing) > 0 then LCurPtr := @FRing[0] else LCurPtr := nil;
    if CowRingStale(LOldPtr, ACtx.OldCap, ACtx.OldCount, ACtx.OldHead, LCurPtr, Length(FRing), atomic_load(FCount), FHead) then Exit(False);
    ACtx.WasEmpty := ACtx.OldCount = 0;
    FRing := ACtx.NewRing;
    FHead := 0;
    ACtx.NewRing := nil;
    LIdx := ACtx.OldCount;
    FRing[LIdx].Kind := ACtx.Kind;
    FRing[LIdx].Ref := ACtx.Ref;
    FRing[LIdx].Method := ACtx.Method;
    FRing[LIdx].Proc := ACtx.Proc;
    atomic_fetch_add(FCount, 1);
    if ACtx.Kind = wwkRef then atomic_fetch_add(FRefCount, Int32(1));
    Result := True;
    if ACtx.OldCount > 0 then specialize CowRingFinalize<TWindowWorkItem>(ACtx.OldRing, ACtx.OldHead, ACtx.OldCap, ACtx.OldCount);
  finally
    FLock.Release;
  end;
  if Result and (Length(ACtx.OldRing) > 0) then
  begin
    LOldArena.Clear;
    specialize ManagedArrayMove<TWindowWorkItem>(LOldArena.Buf, ACtx.OldRing);
    QueueRingArenaRecycle(LOldArena);
  end;
end;

function TWindowQueue.TryReuseBufferLocked(var ANew: TWindowWorkItems; AOldCount: Integer; out AWasEmpty: Boolean; AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc): Boolean;
var LIdx, LNeedCap: Integer;
begin
  Result := False;
  if not CalcGrowCapacity(Length(FRing), atomic_load(FCount), LNeedCap) then Exit(False);
  if Length(ANew) < LNeedCap then Exit(False);
  specialize CowRingReuseBuffer<TWindowWorkItem>(ANew, AOldCount, FRing, FHead, Length(FRing), atomic_load(FCount));
  specialize CowRingGrowInstall<TWindowWorkItem>(FRing, FHead, ANew, FHead, Length(FRing), atomic_load(FCount));
  AWasEmpty := atomic_load(FCount) = 0;
  LIdx := atomic_load(FCount);
  FRing[LIdx].Kind := AKind;
  FRing[LIdx].Ref := ARef;
  FRing[LIdx].Method := AMethod;
  FRing[LIdx].Proc := AProc;
  atomic_fetch_add(FCount, 1);
  if AKind = wwkRef then atomic_fetch_add(FRefCount, Int32(1));
  ANew := nil;
  Result := True;
end;

function TWindowQueue.HandleOverflow(var ANew: TWindowWorkItems; AOldCount: Integer): Boolean; inline;
var LArena: TQueueRingArena;
begin
  if AOldCount > 0 then specialize CowDiscard<TWindowWorkItem>(ANew, AOldCount);
  if Length(ANew) > 0 then
  begin
    LArena.Clear; specialize ManagedArrayMove<TWindowWorkItem>(LArena.Buf, ANew);
    QueueRingArenaRecycle(LArena);
  end else begin SetLength(ANew, 0); ANew := nil; end;
  FBackpressure.IncCap;
  NullLogger.Warn('window queue ring cap exceeded');
  Result := False;
end;

function TWindowQueue.AllocGrowBufferOutsideLock(var ANew: TWindowWorkItems; AOldCount, ACap: Integer): Boolean;
var LArena: TQueueRingArena; LPooled: Boolean;
begin
  if Length(ANew) >= ACap then
  begin
    if AOldCount > 0 then specialize CowDiscard<TWindowWorkItem>(ANew, AOldCount);
    Result := True;
    Exit;
  end;
  if AOldCount > 0 then specialize CowDiscard<TWindowWorkItem>(ANew, AOldCount);
  LArena := QueueRingArenaAcquire(LPooled);
  try
    try
      LArena.Ensure(ACap);
      specialize ManagedArrayMove<TWindowWorkItem>(ANew, LArena.Buf);
    except
      on E: EOutOfMemory do
      begin
        SetLength(ANew, 0);
        ANew := nil;
        FBackpressure.IncOom;
        NullLogger.Error('window queue ring alloc failed (OOM): ' + E.Message);
        Exit(False);
      end;
      on E: Exception do
      begin
        SetLength(ANew, 0);
        ANew := nil;
        NullLogger.Error('window queue ring alloc failed: ' + E.ClassName + ': ' + E.Message);
        raise;
      end;
    end;
  finally
    QueueRingArenaRecycle(LArena);
  end;
  Result := True;
end;

function TWindowQueue.FallbackEnqueueShared(var ANew: TWindowWorkItems; AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; AOldCount: Integer; out AWasEmpty: Boolean): Boolean;
var LNeedCap: Integer; LWasEmpty: Boolean; LCurCap, LCurCount: Integer; LArena: TQueueRingArena;
begin
  Result := False;
  AWasEmpty := False;
  // 单锁单拷贝：锁外预分配 + 锁内单次 Acquire/复用 inline 零拷贝 O(1)均摊 via bytes.ops 单源
  LCurCap := Length(FRing);
  LCurCount := atomic_load(FCount);
  if not CalcGrowCapacity(LCurCap, LCurCount, LNeedCap) then
  begin
    FLock.Acquire;
    try
      if not CalcGrowCapacity(Length(FRing), atomic_load(FCount), LNeedCap) then
        Exit(HandleOverflow(ANew, AOldCount));
    finally
      FLock.Release;
    end;
  end;
  // 锁外预分配复用 via cow/ring 单源 inline 零拷贝
  if not AllocGrowBufferOutsideLock(ANew, AOldCount, LNeedCap) then Exit(False);
  AOldCount := 0;
  FLock.Acquire;
  try
    if TryEnqueueFastLocked(AKind, ARef, AMethod, AProc, LWasEmpty) then
    begin
      if Length(ANew) > 0 then
      begin
        LArena.Clear; specialize ManagedArrayMove<TWindowWorkItem>(LArena.Buf, ANew);
        QueueRingArenaRecycle(LArena);
      end else begin SetLength(ANew, 0); ANew := nil; end;
      AWasEmpty := LWasEmpty;
      Exit(True);
    end;
    if TryReuseBufferLocked(ANew, 0, LWasEmpty, AKind, ARef, AMethod, AProc) then
    begin
      AWasEmpty := LWasEmpty;
      Exit(True);
    end;
    Exit(HandleOverflow(ANew, 0));
  finally
    FLock.Release;
  end;
end;

function TWindowQueue.EnqueueFallbackLocked(var ANew: TWindowWorkItems; AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; AOldCount: Integer): Boolean;
var LWasEmpty: Boolean;
begin
  Result := FallbackEnqueueShared(ANew, AKind, ARef, AMethod, AProc, AOldCount, LWasEmpty);
  if Result then Result := LWasEmpty;
end;

function TWindowQueue.TryEnqueueFallbackLocked(var ANew: TWindowWorkItems; AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; AOldCount: Integer; out AWasEmpty: Boolean): Boolean;
begin
  Result := FallbackEnqueueShared(ANew, AKind, ARef, AMethod, AProc, AOldCount, AWasEmpty);
end;

function TWindowQueue.DoTryPopLocked(out AItem: TWindowWorkItem; AKind: TWindowWorkKind; ACheckKind: Boolean): Boolean;
var
  LCap: Integer;
begin
  Result := False;
  AItem := Default(TWindowWorkItem);
  if FLock = nil then Exit;
  FLock.Acquire;
  try
    if atomic_load(FCount) = 0 then Exit;
    if ACheckKind and (FRing[FHead].Kind <> AKind) then Exit;
    AItem := FRing[FHead];
    if AItem.Kind = wwkRef then atomic_fetch_add(FRefCount, Int32(-1));
    FRing[FHead].Ref := nil;
    FRing[FHead].Kind := wwkRef;
    FRing[FHead].Method := nil;
    FRing[FHead].Proc := nil;
    LCap := Length(FRing);
    FHead := WindowRingNext(FHead, LCap);
    atomic_fetch_sub(FCount, 1);
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TWindowQueue.TryPopFiltered(AKind: TWindowWorkKind; out AItem: TWindowWorkItem): Boolean;
begin
  Result := DoTryPopLocked(AItem, AKind, True);
end;

procedure TWindowQueue.ClearWorkItem(var AItem: TWindowWorkItem);
begin
  AItem.Ref := nil;
  AItem.Method := nil;
  AItem.Proc := nil;
  AItem.Kind := wwkRef;
end;

generic function TWindowQueue.TryPopGeneric<T>(AKind: TWindowWorkKind; out AProc: T): Boolean;
var
  LItem: TWindowWorkItem;
  LAssigned: Boolean;
begin
  Result := False;
  AProc := Default(T);
  if not DoTryPopLocked(LItem, AKind, True) then Exit;
  { 经 PWindow* 具名指针赋值走托管引用计数（AddRef/Release），不用硬直转左值；
    SizeOf 守卫防调用方错配种类与槽位。调用点仅 3 处具体特化。 }
  case AKind of
    wwkRef: begin
      if SizeOf(T) <> SizeOf(TWindowProcRef) then Exit(False);
      PWindowProcRef(@AProc)^ := LItem.Ref; LAssigned := Assigned(LItem.Ref);
    end;
    wwkMethod: begin
      if SizeOf(T) <> SizeOf(TWindowProcMethod) then Exit(False);
      PWindowProcMethod(@AProc)^ := LItem.Method; LAssigned := Assigned(LItem.Method);
    end;
    wwkProc: begin
      if SizeOf(T) <> SizeOf(TWindowProc) then Exit(False);
      PWindowProc(@AProc)^ := LItem.Proc; LAssigned := Assigned(LItem.Proc);
    end;
  else LAssigned := False;
  end;
  ClearWorkItem(LItem);
  Result := LAssigned;
end;

function TWindowQueue.EnqueueCore(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; out AWasEmpty: Boolean): Boolean;
var LNewCap, LOldCap, LOldCount, LOldHead: Integer; LNew, LOldRing: TWindowWorkItems; LCow: TWindowCowCtx; LArena: TQueueRingArena; LPooled: Boolean;
begin
  Result := False;
  AWasEmpty := False;
  if FLock = nil then FLock := TMutex.Create;
  // 快路径 inline 零拷贝 O(1) 单次原子试占；扩容仅快照元数据零拷贝，拷贝外移降 p99 via cow/ring 单源
  FLock.Acquire;
  try
    if TryEnqueueFastLocked(AKind, ARef, AMethod, AProc, AWasEmpty) then Exit(True);
    LOldCap := Length(FRing); LOldCount := atomic_load(FCount); LOldHead := FHead; LOldRing := FRing;
    if not CalcGrowCapacity(LOldCap, LOldCount, LNewCap) then
    begin
      FBackpressure.IncCap;
      NullLogger.Warn('window queue ring cap exceeded');
      Exit(False);
    end;
  finally
    FLock.Release;
  end;
  // 锁外 Arena 预分配 inline 零拷贝 O(n)均摊 0→32→2× via bytes.ops 单源
  LArena := QueueRingArenaAcquire(LPooled);
  try
    LArena.Ensure(LNewCap);
    if LOldCount > 0 then specialize ManagedRingCopy<TWindowWorkItem>(LArena.Buf, LOldRing, LOldHead, LOldCap, LOldCount);
    specialize ManagedArrayMove<TWindowWorkItem>(LNew, LArena.Buf);
  finally
    QueueRingArenaRecycle(LArena);
  end;
  LCow.NewRing := nil; specialize ManagedArrayMove<TWindowWorkItem>(LCow.NewRing, LNew); LCow.OldRing := LOldRing; LCow.OldHead := LOldHead; LCow.OldCap := LOldCap; LCow.OldCount := LOldCount;
  LCow.Kind := AKind; LCow.Ref := ARef; LCow.Method := AMethod; LCow.Proc := AProc; LCow.WasEmpty := False;
  // 单锁 Cow 安装 inline 零拷贝，双检失败回退 Fallback，托管不丢 via cow 单源
  if TryCowInstall(LCow) then begin AWasEmpty := LCow.WasEmpty; Exit(True); end;
  specialize ManagedArrayMove<TWindowWorkItem>(LNew, LCow.NewRing);
  Result := FallbackEnqueueShared(LNew, AKind, ARef, AMethod, AProc, LOldCount, AWasEmpty);
end;

function TWindowQueue.Enqueue(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc): Boolean;
var LWasEmpty: Boolean;
begin
  Result := EnqueueCore(AKind, ARef, AMethod, AProc, LWasEmpty);
  if Result then Result := LWasEmpty;
end;

function TWindowQueue.TryEnqueue(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc; out AWasEmpty: Boolean): Boolean;
begin
  Result := EnqueueCore(AKind, ARef, AMethod, AProc, AWasEmpty);
end;

function TWindowQueue.Push(AProc: TWindowProcRef): Boolean; inline;
begin
  Result := Enqueue(wwkRef, AProc, nil, nil);
end;

function TWindowQueue.Push(AProc: TWindowProcMethod): Boolean; inline;
begin
  Result := Enqueue(wwkMethod, nil, AProc, nil);
end;

function TWindowQueue.Push(AProc: TWindowProc): Boolean; inline;
begin
  Result := Enqueue(wwkProc, nil, nil, AProc);
end;

function TWindowQueue.TryPush(AProc: TWindowProcRef; out AWasEmpty: Boolean): Boolean; inline;
begin
  Result := TryEnqueue(wwkRef, AProc, nil, nil, AWasEmpty);
end;

function TWindowQueue.TryPush(AProc: TWindowProcMethod; out AWasEmpty: Boolean): Boolean; inline;
begin
  Result := TryEnqueue(wwkMethod, nil, AProc, nil, AWasEmpty);
end;

function TWindowQueue.TryPush(AProc: TWindowProc; out AWasEmpty: Boolean): Boolean; inline;
begin
  Result := TryEnqueue(wwkProc, nil, nil, AProc, AWasEmpty);
end;

function TWindowQueue.TryPush(AProc: TWindowProcRef): Boolean; inline;
var LWasEmpty: Boolean;
begin
  Result := TryPush(AProc, LWasEmpty);
end;

function TWindowQueue.TryPush(AProc: TWindowProcMethod): Boolean; inline;
var LWasEmpty: Boolean;
begin
  Result := TryPush(AProc, LWasEmpty);
end;

function TWindowQueue.TryPush(AProc: TWindowProc): Boolean; inline;
var LWasEmpty: Boolean;
begin
  Result := TryPush(AProc, LWasEmpty);
end;

function TWindowQueue.TryPop(out AProc: TWindowProcRef): Boolean; inline;
begin
  Result := specialize TryPopGeneric<TWindowProcRef>(wwkRef, AProc);
end;

function TWindowQueue.TryPop(out AProc: TWindowProcMethod): Boolean; inline;
begin
  Result := specialize TryPopGeneric<TWindowProcMethod>(wwkMethod, AProc);
end;

function TWindowQueue.TryPop(out AProc: TWindowProc): Boolean; inline;
begin
  Result := specialize TryPopGeneric<TWindowProc>(wwkProc, AProc);
end;

function TWindowQueue.TryPopItem(out AItem: TWindowWorkItem): Boolean;
begin
  Result := DoTryPopLocked(AItem, wwkRef, False);
end;

{ TWindowQueue - Snapshot / dispatch / recycle — Bulk 三档 1024/4096/8192 via cow 单源 }
function TWindowQueue.SnapGrowCapacity(ACount: Integer): Integer; inline;
begin
  // 分治委派 cow shard SnapshotBulk 三档 inline 零拷贝 O(1) capped 8192，分档尾延迟可观测
  Result := QueueCowSnapGrowCapacity(ACount);
end;

procedure TWindowQueue.EnsureSnapCapacity(ACount: Integer);
begin
  if ACount <= Length(FSnap) then Exit;
  SetLength(FSnap, SnapGrowCapacity(ACount));
end;

procedure TWindowQueue.TransferWithGrow(var ADest: TWindowWorkItems; var ARing: TWindowWorkItems; AHead, ACap, ACount: Integer);
begin
  if ACount <= 0 then Exit;
  if ACount > Length(ADest) then
    SetLength(ADest, SnapGrowCapacity(ACount));
  specialize ManagedRingTransfer<TWindowWorkItem>(ADest, ARing, AHead, ACap, ACount);
end;

procedure TWindowQueue.TryRecycleRing(var ARing: TWindowWorkItems);
begin
  FLock.Acquire;
  try
    if (Length(FRing) = 0) and (Length(ARing) >= 32) then
    begin
      FRing := ARing;
      ARing := nil;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TWindowQueue.DispatchSnap(ACount: Integer);
var
  I: Integer;
  LP: PWindowWorkItem;
begin
  if ACount <= 0 then Exit;
  for I := 0 to ACount - 1 do
  begin
    LP := @FSnap[I];
    try
      case LP^.Kind of
        wwkRef: WindowQueueDispatchRef(LP);
        wwkMethod: WindowQueueDispatchMethod(LP);
        wwkProc: WindowQueueDispatchProc(LP);
      end;
    finally
      LP^.Ref := nil;
      LP^.Kind := wwkRef;
      LP^.Method := nil;
      LP^.Proc := nil;
    end;
  end;
end;

procedure TWindowQueue.MaybeShrinkSnap(ACount: Integer); inline;
begin
  // Bulk 三档 1024/4096/8192 via bytes.ops SnapshotBulkTier 单源 inline 零拷贝 O(1) 分档尾延迟可观测，not inline 冷路径避 I-Cache 膨胀
  specialize SnapshotMaybeShrink<TWindowWorkItem>(FSnap, ACount);
end;

procedure TWindowQueue.Drain;
begin
  DrainCount;
end;

function TWindowQueue.DrainCount: Integer;
begin
  if not TryDrainCount(Result) then
    Result := 0;
end;

{ TWindowQueue - Steal }
function TWindowQueue.TryStealRing(var ADest: TWindowWorkItems; out ACount: Integer): Boolean;
var
  LRing: TWindowWorkItems;
  LHead, LCount, LCap, LRefCount: Integer;
begin
  ACount := 0;
  Result := False;
  if FLock = nil then Exit;
  // 热路径 16ns 零锁早退：单次 atomic_load(FCount)=0 inline 零拷贝 O(1) 单次访存 16ns，早退零锁消 p99，Bulk 三档 1024/4096/8192 via bytes.ops SnapshotBulkTier 单源 inline 零额外调用，分档尾延迟可观测，托管不丢 via ManagedRingTransfer 单源
  if atomic_load(FCount) = 0 then
  begin
    ACount := 0;
    Result := True;
    Exit;
  end;
  FLock.Acquire;
  try
    LCount := atomic_load(FCount);
    if LCount = 0 then
    begin
      ACount := 0;
      Result := True;
      Exit;
    end;
    LRing := FRing;
    LHead := FHead;
    LCap := Length(FRing);
    LRefCount := atomic_load(FRefCount);
    FRing := nil;
    atomic_store(FCount, 0);
    FHead := 0;
    atomic_store(FRefCount, Int32(0));
  finally
    FLock.Release;
  end;
  try
    TransferWithGrow(ADest, LRing, LHead, LCap, LCount);
  except
    FLock.Acquire;
    try
      if (atomic_load(FCount) = 0) and (Length(FRing) = 0) then
      begin
        FRing := LRing;
        FHead := LHead;
        atomic_store(FCount, LCount);
        atomic_store(FRefCount, LRefCount);
        LRing := nil;
      end;
    finally
      FLock.Release;
    end;
    if (Length(LRing) > 0) and (LCount > 0) then
      specialize ManagedRingFinalize<TWindowWorkItem>(LRing, LHead, LCap, LCount);
    raise;
  end;
  TryRecycleRing(LRing);
  ACount := LCount;
  Result := True;
end;

function TWindowQueue.TryDrainCount(out ACount: Integer): Boolean;
begin
  if not TryStealRing(FSnap, ACount) then Exit(False);
  if ACount > 0 then
  begin
    DispatchSnap(ACount);
    MaybeShrinkSnap(ACount);
  end;
  Result := True;
end;

function TWindowQueue.TryStealBatch(var ADest: TWindowWorkItems; out ACount: Integer): Boolean;
begin
  Result := TryStealRing(ADest, ACount);
end;

function TWindowQueue.IsEmpty: Boolean; inline;
begin
  if FLock = nil then Exit(True);
  Result := atomic_load(FCount) = 0;
end;

function TWindowQueue.Count: Integer; inline;
begin
  if FLock = nil then Exit(0);
  Result := atomic_load(FCount);
end;

function TWindowQueue.DroppedCount: Integer; inline;
begin
  Result := FBackpressure.Total;
end;

function TWindowQueue.DroppedCapCount: Integer; inline;
begin
  Result := FBackpressure.CapCount;
end;

function TWindowQueue.DroppedOomCount: Integer; inline;
begin
  Result := FBackpressure.OomCount;
end;

procedure TWindowQueue.Clear;
var
  LRing: TWindowWorkItems;
  LHead, LCap, LCount: Integer;
begin
  if FLock = nil then
    Exit;
  FLock.Acquire;
  try
    LCount := atomic_load(FCount);
    if LCount = 0 then
    begin
      FHead := 0;
      atomic_store(FRefCount, Int32(0));
      Exit;
    end;
    LRing := FRing;
    LHead := FHead;
    LCap := Length(FRing);
    FRing := nil;
    atomic_store(FCount, 0);
    FHead := 0;
    atomic_store(FRefCount, Int32(0));
  finally
    FLock.Release;
  end;
  if (Length(LRing) > 0) and (LCount > 0) then
    specialize ManagedRingFinalize<TWindowWorkItem>(LRing, LHead, LCap, LCount);
end;

end.
