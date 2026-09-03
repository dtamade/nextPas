unit nextpas.core.window.live;

{ window.live — family shard, owner window.impl, Public facade=no.
  RWLock + atomic snapshot, hash O(1) via live.table/window.hash single source. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.impl,
  nextpas.core.window.hash,
  nextpas.core.sync.intf;

type
  TWindowLiveSnapshot = array of Pointer;

  { window.hash 泛型单容器，bytes.ops 单源 inline 零拷贝 O(1) }
  TLivePtrHash = specialize TWindowOpenHash<Pointer, Integer>;
  TLiveU32Hash = specialize TWindowOpenHash<UInt32, Pointer>;

  TWindowLiveRegistry = class
  private
    FList: array of Pointer;
    FCount: Int32;
    FLck: IRWLock;
    FPtrHash: TLivePtrHash;
    function GetItem(AIndex: Integer): Pointer;
    procedure RebuildPtrHash; inline;
    procedure HashInsertPtr(APtr: Pointer; AIdx: Integer); inline;
    procedure HashRemovePtr(APtr: Pointer); inline;
    function HashFindPtr(APtr: Pointer): Integer; inline;
    function HashNeedsGrowPtr: Boolean; inline;
    procedure EnsureHashCapacityPtr(ANewHashCap: Integer); inline;
    class procedure MaybeShrinkSnapFor(var ASnap: TWindowLiveSnapshot; ACount: Integer); static;
    procedure EnsureLck; inline;
  protected
    procedure EnsureCapacity(ANewCap: Integer); virtual;
  public
    constructor Create(const AToken: TWindowFamilyToken); reintroduce;
    procedure Register(AWin: Pointer);
    procedure Unregister(AWin: Pointer); virtual;
    function Count: Integer; inline;
    function IsEmpty: Boolean; inline;
    function Contains(AWin: Pointer): Boolean;
    function ItemByIndex(AIndex: Integer): Pointer;
    property Items[AIndex: Integer]: Pointer read GetItem; default;
    procedure SnapshotTo(var ADest: TWindowLiveSnapshot);
    procedure Clear; virtual;
    destructor Destroy; override;
  end;

  TWindowSdlLiveRegistry = class(TWindowLiveRegistry)
  private
    FIDs: array of UInt32;
    FHash: TLiveU32Hash;
    procedure RebuildHash; inline;
    procedure HashInsert(AID: UInt32; APtr: Pointer); inline;
    procedure HashRemove(AID: UInt32); inline;
    function HashFind(AID: UInt32): Pointer; inline;
    function HashNeedsGrow: Boolean; inline;
    procedure EnsureHashCapacity(ANewHashCap: Integer); inline;
  protected
    procedure EnsureCapacity(ANewCap: Integer); override;
  public
    constructor Create(const AToken: TWindowFamilyToken); reintroduce;
    procedure Register(AWin: Pointer; AID: UInt32); reintroduce;
    procedure Unregister(AWin: Pointer); override;
    function FindByID(AID: UInt32): Pointer;
    procedure Clear; override;
    destructor Destroy; override;
  end;

{ 聚合活窗计数：owner window.impl GLiveTotal 单源，live thin delegate via WindowLiveAdjust inline 原子 16ns，写锁内与 FCount 成对更新，COW/哈希/RWLock 分治解耦见 live.table/live.arena/sync.cow 单源 }
function WindowTotalLiveCount: Integer; inline;
procedure WindowFakeLiveAdjust(ADelta: Integer); inline;

// 家族共享活窗注册表工厂：WindowFamilyToken 单源，inline 零拷贝单次 Pointer 比较，bytes.ops 单源复用，消 8 后端重复手写 Create(WindowFamilyToken)
function WindowLiveRegistryCreate: TWindowLiveRegistry; inline;
function WindowSdlLiveRegistryCreate: TWindowSdlLiveRegistry; inline;
function WindowLiveRegistryEnsure(var AReg: TWindowLiveRegistry): TWindowLiveRegistry; inline;
function WindowSdlLiveRegistryEnsure(var AReg: TWindowSdlLiveRegistry): TWindowSdlLiveRegistry; inline;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.bytes.ops,
  nextpas.core.sync.cow,
  nextpas.core.sync.rwlock,
  nextpas.core.window.live.arena,
  nextpas.core.window.live.table;

function WindowTotalLiveCount: Integer; inline;
begin
  // thin delegate to owner window.impl single source atomic_load inline 零拷贝 O(1) 16ns，零锁，资源不丢
  Result := nextpas.core.window.impl.WindowTotalLiveCount;
end;

procedure WindowFakeLiveAdjust(ADelta: Integer); inline;
begin
  // thin delegate to owner window.impl WindowFakeLiveAdjust inline 原子 16ns，资源不丢
  nextpas.core.window.impl.WindowFakeLiveAdjust(ADelta);
end;

function WindowLiveRegistryCreate: TWindowLiveRegistry; inline;
begin
  // 工厂单源 via WindowFamilyToken，inline 零拷贝 O(1)
  Result := TWindowLiveRegistry.Create(WindowFamilyToken);
end;

function WindowSdlLiveRegistryCreate: TWindowSdlLiveRegistry; inline;
begin
  Result := TWindowSdlLiveRegistry.Create(WindowFamilyToken);
end;

function WindowLiveRegistryEnsure(var AReg: TWindowLiveRegistry): TWindowLiveRegistry; inline;
begin
  // nil 时托管创建，inline 零拷贝 O(1)，复用 WindowLiveRegistryCreate
  if AReg = nil then AReg := WindowLiveRegistryCreate;
  Result := AReg;
end;

function WindowSdlLiveRegistryEnsure(var AReg: TWindowSdlLiveRegistry): TWindowSdlLiveRegistry; inline;
begin
  if AReg = nil then AReg := WindowSdlLiveRegistryCreate;
  Result := AReg;
end;

procedure LiveInsertLockedDirect(AReg: TWindowLiveRegistry; ASdl: TWindowSdlLiveRegistry; AWin: Pointer; AID: UInt32); inline;
var LPos: Integer;
begin
  LPos := atomic_load(AReg.FCount);
  AReg.FList[LPos] := AWin;
  if ASdl <> nil then
  begin
    if LPos >= Length(ASdl.FIDs) then SetLength(ASdl.FIDs, Length(AReg.FList));
    ASdl.FIDs[LPos] := AID;
    ASdl.FHash.Insert(WindowFamilyToken, AID, AWin);
  end;
  AReg.FPtrHash.Insert(WindowFamilyToken, AWin, LPos);
  atomic_fetch_add(AReg.FCount, Int32(1));
  nextpas.core.window.impl.WindowLiveAdjust(1);
end;

procedure LiveEnsureHashLocked(AReg: TWindowLiveRegistry; ASdl: TWindowSdlLiveRegistry); inline;
var LCnt: Integer;
begin
  LCnt := atomic_load(AReg.FCount);
  if (ASdl <> nil) and CowNeedsGrow(LCnt, ASdl.FHash.Cap) then
    WindowHashEnsureCapacity(ASdl.FHash, WindowFamilyToken, WindowGrowCapacity(ASdl.FHash.Cap), ASdl.FIDs, AReg.FList, LCnt);
  if CowNeedsGrow(LCnt, AReg.FPtrHash.Cap) then
    WindowHashEnsureCapacity(AReg.FPtrHash, WindowFamilyToken, WindowGrowCapacity(AReg.FPtrHash.Cap), AReg.FList, LCnt);
end;

{ 分治解耦 helper：Arena 锁外构建拷贝+哈希重建单源 inline 零拷贝 via bytes.ops/window.hash，COW/RWLock/原子/哈希四职责分离 }
procedure LiveArenaBuildCopies(var AArena: TLiveBuildArena; ASdl: TWindowSdlLiveRegistry; const ASnapList: TWindowLiveSnapshot; const ASnapIDs: array of UInt32; ACnt: Integer; ANeedList, ANeedU32, ANeedPtr: Boolean); inline;
begin
  // 单源 inline 零拷贝 O(1) via bytes.ops ArrayRawCopy + window.hash Rebuild，资源托管不丢，与 live.table/lock/atomic 分治零耦合
  if ANeedList and (ACnt > 0) then
  begin
    specialize ArrayRawCopy<Pointer>(AArena.List, ASnapList, ACnt);
    if ASdl <> nil then specialize ArrayRawCopy<UInt32>(AArena.IDs, ASnapIDs, ACnt);
  end;
  if (ASdl <> nil) and ANeedU32 then
    WindowHashRebuildU32(WindowFamilyToken, AArena.HKeys, AArena.HVals, AArena.HUsed, ASnapIDs, ASnapList, ACnt);
  if ANeedPtr then
    WindowHashRebuildPtr(WindowFamilyToken, AArena.PKeys, AArena.PIdx, AArena.PUsed, ASnapList, ACnt);
end;

procedure LiveDoRegister(AReg: TWindowLiveRegistry; AWin: Pointer; AID: UInt32; AIsSdl: Boolean);
var
  ASdl: TWindowSdlLiveRegistry;
  LOldListCap, LOldPtrCap, LOldU32Cap, LCnt: Integer;
  LNeedList, LNeedPtr, LNeedU32: Boolean;
  LNewListCap, LNewPtrCap, LNewU32Cap: Integer;
  LSnapPtr: Pointer;
  LSnapList: TWindowLiveSnapshot;
  LSnapIDs: array of UInt32;
  LArena, LOld: TLiveBuildArena;
  LPooled, LStale: Boolean;
  LCur, LCurCap: Integer;
  LCurPtr: Pointer;
begin
  // ABA mitigation: optimistic read snapshot + out-of-lock arena alloc with revalidation; pooled via bytes.ops single source (see live.arena), stale discard recycled
  if AReg = nil then Exit;
  if AIsSdl then ASdl := TWindowSdlLiveRegistry(AReg) else ASdl := nil;
  if AReg.FLck = nil then AReg.FLck := TRWLock.Create as IRWLock;
  AReg.FLck.AcquireRead;
  try
    LOldListCap := Length(AReg.FList);
    LOldPtrCap := AReg.FPtrHash.Cap;
    if ASdl <> nil then LOldU32Cap := ASdl.FHash.Cap else LOldU32Cap := 0;
    LCnt := atomic_load(AReg.FCount);
    LNeedList := LCnt = LOldListCap;
    LNeedPtr := CowNeedsGrow(LCnt, LOldPtrCap);
    if ASdl <> nil then LNeedU32 := CowNeedsGrow(LCnt, LOldU32Cap) else LNeedU32 := False;
    if LNeedList then LNewListCap := WindowGrowCapacity(LOldListCap) else LNewListCap := 0;
    if LNeedPtr then LNewPtrCap := WindowGrowCapacity(LOldPtrCap) else LNewPtrCap := 0;
    if (ASdl <> nil) and LNeedU32 then LNewU32Cap := WindowGrowCapacity(LOldU32Cap) else LNewU32Cap := 0;
    if Length(AReg.FList) > 0 then LSnapPtr := @AReg.FList[0] else LSnapPtr := nil;
    if LNeedList or LNeedPtr or LNeedU32 then
    begin LSnapList := AReg.FList; if ASdl <> nil then LSnapIDs := ASdl.FIDs; end else begin LSnapList := nil; LSnapIDs := nil; end;
  finally
    AReg.FLck.ReleaseRead;
  end;
  if LNeedList or LNeedPtr or LNeedU32 then
  begin
    // Phase2 锁外构建：Arena 池化 via live.arena 单源 inline 零拷贝，哈希重建 via window.hash 单源，零锁零堆抖动
    LArena := LiveArenaAcquire(LPooled);
    try
      if LNeedList or LNeedU32 or LNeedPtr then
        LArena.EnsureBatch(LNewListCap, LNewU32Cap, LNewPtrCap);
      LiveArenaBuildCopies(LArena, ASdl, LSnapList, LSnapIDs, LCnt, LNeedList, LNeedU32, LNeedPtr);
      LOld.Clear;
      AReg.FLck.AcquireWrite;
      try
        LCur := atomic_load(AReg.FCount);
        LCurCap := Length(AReg.FList);
        if LCurCap > 0 then LCurPtr := @AReg.FList[0] else LCurPtr := nil;
        if ASdl <> nil then
          LStale := not CowTryInstallLinear(LSnapPtr, LOldListCap, LCnt, LCurPtr, LCurCap, LCur)
            or not CowTryInstallLinear(nil, LOldPtrCap, LCnt, nil, AReg.FPtrHash.Cap, LCur)
            or not CowTryInstallLinear(nil, LOldU32Cap, LCnt, nil, ASdl.FHash.Cap, LCur)
        else
          LStale := not CowTryInstallLinear(LSnapPtr, LOldListCap, LCnt, LCurPtr, LCurCap, LCur)
            or not CowTryInstallLinear(nil, LOldPtrCap, LCnt, nil, AReg.FPtrHash.Cap, LCur);
        if not LStale then
        begin
          if LNeedList then
          begin
            LOld.List := AReg.FList; if ASdl <> nil then LOld.IDs := ASdl.FIDs;
            if not specialize DoCowInsert<Pointer>(AReg.FList, LArena.List, LSnapPtr, LCurPtr, LOldListCap, LCurCap, LCnt, LCur) then
              specialize CowLinearGrowInstall<Pointer>(AReg.FList, LArena.List);
            if ASdl <> nil then ASdl.FIDs := LArena.IDs;
            LArena.List := nil; LArena.IDs := nil;
            LiveArenaRecycle(LOld);
          end;
          if (ASdl <> nil) and LNeedU32 then
          begin
            ASdl.FHash.ExtractBuffers(LOld.HKeys, LOld.HVals, LOld.HUsed);
            ASdl.FHash.AdoptBuffers(LArena.HKeys, LArena.HVals, LArena.HUsed);
            LiveArenaRecycle(LOld);
          end;
          if LNeedPtr then
          begin
            AReg.FPtrHash.ExtractBuffers(LOld.PKeys, LOld.PIdx, LOld.PUsed);
            AReg.FPtrHash.AdoptBuffers(LArena.PKeys, LArena.PIdx, LArena.PUsed);
            LiveArenaRecycle(LOld);
          end;
        end;
        LCur := atomic_load(AReg.FCount);
        if LStale or (not LNeedList) then
          if LCur = Length(AReg.FList) then AReg.EnsureCapacity(WindowGrowCapacity(Length(AReg.FList)));
        if LStale or (not LNeedU32) or (not LNeedPtr) then
          LiveEnsureHashLocked(AReg, ASdl);
        LiveInsertLockedDirect(AReg, ASdl, AWin, AID);
      finally
        AReg.FLck.ReleaseWrite;
      end;
    finally
      LiveArenaRecycle(LArena);
    end;
    Exit;
  end;
  AReg.FLck.AcquireWrite;
  try
    if AReg.FCount = Length(AReg.FList) then
      AReg.EnsureCapacity(WindowGrowCapacity(Length(AReg.FList)));
    LiveEnsureHashLocked(AReg, ASdl);
    LiveInsertLockedDirect(AReg, ASdl, AWin, AID);
  finally
    AReg.FLck.ReleaseWrite;
  end;
end;

{ 单源活表：EnsureCapacity 与末尾换位删除经 live.table 泛型收口，bytes.ops 单源 inline 零拷贝 O(1) }

procedure LiveSyncListPtrCapacity(AReg: TWindowLiveRegistry; ANewCap: Integer);
begin
  // not inline: SetLength+Resize+Rebuild 重逻辑禁 inline 避 I-Cache 膨胀；单源 via live.table inline 零拷贝
  LiveTableSyncListPtr(AReg.FList, AReg.FPtrHash, ANewCap, atomic_load(AReg.FCount));
end;

procedure LiveSyncIDsU32Capacity(ASdl: TWindowSdlLiveRegistry; ANewCap: Integer);
begin
  // not inline: 单源 via live.table inline 零拷贝
  LiveTableSyncIDs(ASdl.FIDs, ASdl.FList, ASdl.FHash, ANewCap, atomic_load(ASdl.FCount));
end;

procedure LiveSwapRemovePtr(AReg: TWindowLiveRegistry; AIdx, ALast: Integer); inline;
begin
  LiveTableSwapRemovePtrRaw(AReg.FList, AReg.FPtrHash, AIdx, ALast);
end;

procedure LiveSwapRemoveSdl(ASdl: TWindowSdlLiveRegistry; AIdx, ALast: Integer); inline;
begin
  LiveTableSwapRemoveIDsRaw(ASdl.FIDs, AIdx, ALast);
  LiveTableSwapRemovePtrRaw(ASdl.FList, ASdl.FPtrHash, AIdx, ALast);
end;

{ TWindowLiveRegistry }

constructor TWindowLiveRegistry.Create(const AToken: TWindowFamilyToken);
begin
  RequireWindowFamilyToken(AToken);
  inherited Create;
  FLck := TRWLock.Create as IRWLock;
end;

procedure TWindowLiveRegistry.Register(AWin: Pointer);
begin
  LiveDoRegister(Self, AWin, 0, False);
end;

procedure TWindowLiveRegistry.EnsureCapacity(ANewCap: Integer);
begin
  // 收口至 LiveSyncListPtrCapacity，bytes.ops 单源 inline 零拷贝 O(1)
  LiveSyncListPtrCapacity(Self, ANewCap);
end;

procedure TWindowLiveRegistry.Unregister(AWin: Pointer);
var
  LIdx, LLast, LCur: Integer;
begin
  if FLck = nil then
    FLck := TRWLock.Create as IRWLock;
  FLck.AcquireWrite;
  try
    LIdx := HashFindPtr(AWin);
    if LIdx < 0 then Exit;
    LCur := atomic_load(FCount);
    if (LIdx < 0) or (LIdx >= LCur) then Exit;
    if FList[LIdx] <> AWin then Exit;
    LLast := LCur - 1;
    LiveTableUnregisterPtr(FList, FPtrHash, LIdx, LLast, AWin);
    atomic_fetch_add(FCount, Int32(-1));
    nextpas.core.window.impl.WindowLiveAdjust(-1);
  finally
    FLck.ReleaseWrite;
  end;
end;

function TWindowLiveRegistry.GetItem(AIndex: Integer): Pointer;
var LCnt: Integer;
begin
  Result := nil;
  if FLck = nil then
    FLck := TRWLock.Create as IRWLock;
  FLck.AcquireRead;
  try
    LCnt := atomic_load(FCount);
    if (AIndex >= 0) and (AIndex < LCnt) then
      Result := FList[AIndex];
  finally
    FLck.ReleaseRead;
  end;
end;

function TWindowLiveRegistry.ItemByIndex(AIndex: Integer): Pointer;
begin
  Result := GetItem(AIndex);
end;

function TWindowLiveRegistry.Count: Integer; inline;
begin
  if FLck = nil then Exit(0);
  Result := atomic_load(FCount);
end;

function TWindowLiveRegistry.IsEmpty: Boolean; inline;
begin
  if FLck = nil then Exit(True);
  Result := atomic_load(FCount) = 0;
end;

function TWindowLiveRegistry.Contains(AWin: Pointer): Boolean;
var LIdx, LCnt: Integer;
begin
  Result := False;
  if (AWin = nil) or (FLck = nil) then Exit;
  FLck.AcquireRead;
  try
    LIdx := HashFindPtr(AWin);
    if LIdx < 0 then Exit;
    LCnt := atomic_load(FCount);
    if (LIdx < 0) or (LIdx >= LCnt) then Exit;
    Result := FList[LIdx] = AWin;
  finally
    FLck.ReleaseRead;
  end;
end;

procedure TWindowLiveRegistry.Clear;
var
  LOld: Integer;
begin
  if FLck = nil then
    FLck := TRWLock.Create as IRWLock;
  FLck.AcquireWrite;
  try
    LOld := atomic_load(FCount);
    LiveTableClearPtr(FList, FPtrHash, LOld);
    atomic_store(FCount, Int32(0));
    if LOld <> 0 then
      nextpas.core.window.impl.WindowLiveAdjust(-LOld);
  finally
    FLck.ReleaseWrite;
  end;
end;

class procedure TWindowLiveRegistry.MaybeShrinkSnapFor(var ASnap: TWindowLiveSnapshot; ACount: Integer);
begin
  // cold path not inline per redline #2; single source via bytes.ops SnapshotMaybeShrink
  specialize SnapshotMaybeShrink<Pointer>(ASnap, ACount);
end;

procedure TWindowLiveRegistry.EnsureLck; inline;
var
  LNew: IRWLock;
  PNew: Pointer;
  LExp: Pointer;
  LAdded: Boolean;
begin
  // atomic lazy FLck: double-check CAS, AddRef/Release managed, try-finally
  if atomic_load(PPointer(@FLck)^, mo_acquire) <> nil then Exit;
  LNew := TRWLock.Create as IRWLock;
  PNew := Pointer(LNew);
  IInterface(PNew)._AddRef;
  LAdded := True;
  try
    LExp := nil;
    if atomic_compare_exchange_strong(PPointer(@FLck)^, LExp, PNew, mo_acq_rel, mo_acquire) then
    begin
      LAdded := False;
      Exit;
    end;
  except
    if LAdded then IInterface(PNew)._Release;
    raise;
  end;
  if LAdded then IInterface(PNew)._Release;
end;

procedure TWindowLiveRegistry.SnapshotTo(var ADest: TWindowLiveSnapshot);
var
  LCount: Integer;
  LRef: TWindowLiveSnapshot;
begin
  // not inline per redline #2: RWLock + shrink heavy, avoid I-Cache bloat
  // pool reuse via bytes.ops single source inline zero-copy O(1); LCount=0 zero-lock
  LCount := atomic_load(FCount);
  if LCount <= 0 then
  begin
    if Length(ADest) > 0 then
      specialize ArraySetLengthNoRealloc<Pointer>(ADest, 0);
    Exit;
  end;
  EnsureLck;
  FLck.AcquireRead;
  try
    LCount := atomic_load(FCount);
    if LCount > 0 then LRef := FList else LRef := nil;
  finally
    FLck.ReleaseRead;
  end;
  if LCount <= 0 then
  begin
    if Length(ADest) > 0 then
      specialize ArraySetLengthNoRealloc<Pointer>(ADest, 0);
    Exit;
  end;
  if Length(ADest) < LCount then
    specialize ManagedEnsureCapacityExact<Pointer>(ADest, LCount);
  specialize ArrayRawCopy<Pointer>(ADest, LRef, LCount);
  if Length(ADest) <> LCount then
  begin
    if (Length(ADest) > BYTES_SNAPSHOT_MAX) or ((Length(ADest) > BYTES_SNAPSHOT_SHRINK_THRESHOLD) and (Length(ADest) > LCount * BYTES_SNAPSHOT_SHRINK_FACTOR)) then
      MaybeShrinkSnapFor(ADest, LCount)
    else
      specialize ArraySetLengthNoRealloc<Pointer>(ADest, LCount);
  end;
end;

destructor TWindowLiveRegistry.Destroy;
begin
  Clear;
  FLck := nil;
  inherited;
end;

{ TWindowLiveRegistry pointer hash - 泛型单容器委托 nextpas.core.window.hash，负载≤0.5 via WindowGrowCapacity 单源 bytes.ops inline 零拷贝 }

procedure TWindowLiveRegistry.RebuildPtrHash; inline;
begin
  WindowHashRebuild(FPtrHash, WindowFamilyToken, FList, atomic_load(FCount));
end;

procedure TWindowLiveRegistry.HashInsertPtr(APtr: Pointer; AIdx: Integer); inline;
begin
  FPtrHash.Insert(WindowFamilyToken, APtr, AIdx);
end;

procedure TWindowLiveRegistry.HashRemovePtr(APtr: Pointer); inline;
begin
  FPtrHash.Remove(WindowFamilyToken, APtr);
end;

function TWindowLiveRegistry.HashFindPtr(APtr: Pointer): Integer; inline;
var LPos: Integer;
begin
  LPos := FPtrHash.FindPos(WindowFamilyToken, APtr);
  if LPos < 0 then Exit(-1);
  Result := FPtrHash.ValueAt(LPos);
end;

function TWindowLiveRegistry.HashNeedsGrowPtr: Boolean; inline;
var LCnt: Integer;
begin
  LCnt := atomic_load(FCount);
  Result := FPtrHash.NeedsGrow(WindowFamilyToken, LCnt);
end;

procedure TWindowLiveRegistry.EnsureHashCapacityPtr(ANewHashCap: Integer); inline;
var LCnt: Integer;
begin
  LCnt := atomic_load(FCount);
  WindowHashEnsureCapacity(FPtrHash, WindowFamilyToken, ANewHashCap, FList, LCnt);
end;

{ TWindowSdlLiveRegistry helpers - 泛型单容器委托 nextpas.core.window.hash，inline 零拷贝 }

procedure TWindowSdlLiveRegistry.RebuildHash; inline;
var LCnt: Integer;
begin
  LCnt := atomic_load(FCount);
  WindowHashRebuild(FHash, WindowFamilyToken, FIDs, FList, LCnt);
end;

procedure TWindowSdlLiveRegistry.HashInsert(AID: UInt32; APtr: Pointer); inline;
begin
  FHash.Insert(WindowFamilyToken, AID, APtr);
end;

procedure TWindowSdlLiveRegistry.HashRemove(AID: UInt32); inline;
begin
  FHash.Remove(WindowFamilyToken, AID);
end;

function TWindowSdlLiveRegistry.HashFind(AID: UInt32): Pointer; inline;
begin
  Result := FHash.Find(WindowFamilyToken, AID);
end;

function TWindowSdlLiveRegistry.HashNeedsGrow: Boolean; inline;
var LCnt: Integer;
begin
  LCnt := atomic_load(FCount);
  Result := FHash.NeedsGrow(WindowFamilyToken, LCnt);
end;

procedure TWindowSdlLiveRegistry.EnsureHashCapacity(ANewHashCap: Integer); inline;
var LCnt: Integer;
begin
  LCnt := atomic_load(FCount);
  WindowHashEnsureCapacity(FHash, WindowFamilyToken, ANewHashCap, FIDs, FList, LCnt);
end;

constructor TWindowSdlLiveRegistry.Create(const AToken: TWindowFamilyToken);
begin
  RequireWindowFamilyToken(AToken);
  inherited Create(AToken);
end;

procedure TWindowSdlLiveRegistry.Register(AWin: Pointer; AID: UInt32);
begin
  LiveDoRegister(Self, AWin, AID, True);
end;

procedure TWindowSdlLiveRegistry.EnsureCapacity(ANewCap: Integer);
begin
  // 单源模板：基类列表+Ptr哈希已由 inherited 收口，FIDs/U32哈希收口至 LiveSyncIDsU32Capacity via bytes.ops 单源 inline 零拷贝
  inherited EnsureCapacity(ANewCap);
  LiveSyncIDsU32Capacity(Self, ANewCap);
end;

procedure TWindowSdlLiveRegistry.Unregister(AWin: Pointer);
var
  LIdx, LLast, LCur: Integer;
  LID: UInt32;
begin
  if FLck = nil then
    FLck := TRWLock.Create as IRWLock;
  FLck.AcquireWrite;
  try
    LIdx := HashFindPtr(AWin);
    if LIdx < 0 then Exit;
    LCur := atomic_load(FCount);
    if (LIdx < 0) or (LIdx >= LCur) then Exit;
    if FList[LIdx] <> AWin then Exit;
    LID := FIDs[LIdx];
    LLast := LCur - 1;
    LiveTableUnregisterSdl(FList, FIDs, FHash, FPtrHash, LIdx, LLast, AWin, LID);
    atomic_fetch_add(FCount, Int32(-1));
    nextpas.core.window.impl.WindowLiveAdjust(-1);
  finally
    FLck.ReleaseWrite;
  end;
end;

function TWindowSdlLiveRegistry.FindByID(AID: UInt32): Pointer;
begin
  Result := nil;
  if AID = 0 then Exit;
  if FLck = nil then Exit;
  FLck.AcquireRead;
  try
    Result := HashFind(AID);
  finally
    FLck.ReleaseRead;
  end;
end;

procedure TWindowSdlLiveRegistry.Clear;
var
  LOld: Integer;
begin
  if FLck = nil then
    FLck := TRWLock.Create as IRWLock;
  FLck.AcquireWrite;
  try
    LOld := atomic_load(FCount);
    LiveTableClearSdl(FList, FIDs, FHash, FPtrHash, LOld);
    atomic_store(FCount, Int32(0));
    if LOld <> 0 then
      nextpas.core.window.impl.WindowLiveAdjust(-LOld);
  finally
    FLck.ReleaseWrite;
  end;
end;

destructor TWindowSdlLiveRegistry.Destroy;
begin
  Clear;
  inherited;
end;

end.
