unit nextpas.core.collections.hashmap.swiss;

{$I nextpas.core.settings.inc}

interface

uses
  TypInfo,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.hashmap.base,
  nextpas.core.simd.base,
  {$IFDEF HAS_AVX2}
  nextpas.core.simd.vec32;
  {$ELSE}
  nextpas.core.simd.vec16;
  {$ENDIF}

const
  CTRL_EMPTY   = Byte($FF);
  CTRL_DELETED = Byte($80);
  {$IFDEF HAS_AVX2}
  GROUP_SIZE   = 32;
  {$ELSE}
  GROUP_SIZE   = 16;
  {$ENDIF}
  MIN_CAPACITY = GROUP_SIZE;

type
  {$IFDEF HAS_AVX2}
  TSwissMask = TMask32;
  {$ELSE}
  TSwissMask = TMask16;
  {$ENDIF}

function SwissCtz(AMask: TSwissMask): Int32; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchH2(ACtrl: PByte; AH2: Byte): TSwissMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchEmpty(ACtrl: PByte): TSwissMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchEmptyOrDeleted(ACtrl: PByte): TSwissMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

function InlineHashMix32(x: UInt32): UInt32; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

type
  generic TSwissTable<K, V> = class
  public type
    THash = specialize TKeyHashFunc<K>;
    TEquals = specialize TKeyEqualsFunc<K>;
    TRetainFunc = function(const AKey: K; const AValue: V): Boolean;
    TVisitFunc = procedure(const AKey: K; const AValue: V);
    TKeyArray = array of K;
    PSlot = ^TSlot;
    TSlot = record
      Key: K;
      Value: V;
    end;
    TEnumerator = record
    private
      FCtrl: PByte;
      FSlots: PSlot;
      FCapacity: SizeUInt;
      FIdx: SizeUInt;
      FCurrent: TSlot;
    public
      function MoveNext: Boolean;
      property Current: TSlot read FCurrent;
    end;
    TPtrEnumerator = record
    private
      FCtrl: PByte;
      FSlots: PSlot;
      FCapacity: SizeUInt;
      FIdx: SizeUInt;
    public
      function MoveNext: Boolean;
      function GetCurrent: PSlot; inline;
      property Current: PSlot read GetCurrent;
    end;
  private
    FCtrl: PByte;
    FSlots: PSlot;
    FCapacity: SizeUInt;
    FGroupCount: SizeUInt;
    FCount: SizeUInt;
    FGrowthLeft: SizeUInt;
    FHash: THash;
    FEquals: TEquals;
    FAllocator: IAllocator;

    function KeyHash(const AKey: K): UInt32;
    function KeysEqual(const L, R: K): Boolean; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function MatchGroup(ACtrl: PByte; AH2: Byte): TSwissMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function MatchEmpty(ACtrl: PByte): TSwissMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function MatchEmptyOrDeleted(ACtrl: PByte): TSwissMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function FindIndex(const AKey: K; AHash: UInt32; out AIndex: SizeUInt): Boolean;
    function FindInsertSlot(AHash: UInt32): SizeUInt;
    procedure SetCtrl(AIndex: SizeUInt; AValue: Byte); {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    procedure AllocTable(ACapacity: SizeUInt);
    procedure FreeTable;
    procedure GrowAndRehash;

  public
    constructor Create(aCapacity: SizeUInt = 0; aHash: THash = nil; aEquals: TEquals = nil; aAllocator: IAllocator = nil);
    destructor Destroy; override;

    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    function AddOrAssign(const AKey: K; const AValue: V): Boolean;
    function Remove(const AKey: K): Boolean;
    procedure Put(const AKey: K; const AValue: V); {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function Get(const AKey: K): V;
    function GetOrInsert(const AKey: K; const ADefault: V): V;
    procedure Clear;
    procedure Reserve(AMinCapacity: SizeUInt);
    procedure ShrinkToFit;
    procedure Retain(AFunc: TRetainFunc);
    procedure ForEach(AFunc: TVisitFunc);
    procedure Drain(AFunc: TVisitFunc);
    function GetKeys: TKeyArray;
    function GetCtrlByte(AIndex: SizeUInt): Byte; inline;
    function GetSlotKey(AIndex: SizeUInt): K; inline;
    function GetEnumerator: TEnumerator;
    function GetPtrEnumerator: TPtrEnumerator;
    function Slots: PSlot; inline;
    function IsEmpty: Boolean; inline;
    function GetCount: SizeUInt;

    property Count: SizeUInt read FCount;
    property Capacity: SizeUInt read FCapacity;
  end;

implementation

uses
  nextpas.core.collections.hashmap;

function InlineHashMix32(x: UInt32): UInt32; inline;
begin
  x := (x xor (x shr 16)) * UInt32($7feb352d);
  x := (x xor (x shr 15)) * UInt32($846ca68b);
  Result := x xor (x shr 16);
end;

function SwissCtz(AMask: TSwissMask): Int32;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32Ctz(AMask);
  {$ELSE}
  Result := Vec16Ctz(TMask16(AMask));
  {$ENDIF}
end;

function SwissMatchH2(ACtrl: PByte; AH2: Byte): TSwissMask;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32CmpEq(ACtrl, AH2);
  {$ELSE}
  Result := Vec16CmpEq(ACtrl, AH2);
  {$ENDIF}
end;

function SwissMatchEmpty(ACtrl: PByte): TSwissMask;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32CmpEq(ACtrl, CTRL_EMPTY);
  {$ELSE}
  Result := Vec16CmpEq(ACtrl, CTRL_EMPTY);
  {$ENDIF}
end;

function SwissMatchEmptyOrDeleted(ACtrl: PByte): TSwissMask;
begin
  {$IFDEF HAS_AVX2}
  Result := Vec32CmpGtU(ACtrl, $7F);
  {$ELSE}
  Result := Vec16CmpGtU(ACtrl, $7F);
  {$ENDIF}
end;

{ TSwissTable<K,V> - Core helpers }

function TSwissTable.KeyHash(const AKey: K): UInt32;
var
  p: Pointer;
begin
  p := @AKey;
  // 编译期特化：ordinal/基本类型直接计算，绕过 FHash 指针检查
  if (GetTypeKind(K) = tkInteger) or (GetTypeKind(K) = tkChar) or
     (GetTypeKind(K) = tkWChar) or (GetTypeKind(K) = tkBool) or
     (GetTypeKind(K) = tkEnumeration) then
  begin
    case SizeOf(K) of
      1: Exit(InlineHashMix32(PByte(p)^));
      2: Exit(InlineHashMix32(PWord(p)^));
      4: Exit(InlineHashMix32(PUInt32(p)^));
      8: Exit(HashOfUInt64(PQWord(p)^));
    end;
  end;
  if (GetTypeKind(K) = tkInt64) or (GetTypeKind(K) = tkQWord) then
    Exit(HashOfUInt64(PQWord(p)^));

  if (GetTypeKind(K) = tkAString) or (GetTypeKind(K) = tkLString) then
    Exit(HashOfAnsiString(PAnsiString(p)^));
  if (GetTypeKind(K) = tkUString) or (GetTypeKind(K) = tkWString) then
    Exit(HashOfUnicodeString(PUnicodeString(p)^));

  if Assigned(FHash) then Exit(FHash(AKey));
  case SizeOf(K) of
    1: Result := InlineHashMix32(PByte(p)^);
    2: Result := InlineHashMix32(PWord(p)^);
    4: Result := InlineHashMix32(PUInt32(p)^);
    8: Result := HashOfUInt64(PQWord(p)^);
  else
    Result := InlineHashMix32(PUInt32(p)^);
  end;
end;

function TSwissTable.KeysEqual(const L, R: K): Boolean;
begin
  // 编译期特化：ordinal 类型直接整数比较，绕过 FEquals 指针检查
  if (GetTypeKind(K) = tkInteger) or (GetTypeKind(K) = tkChar) or
     (GetTypeKind(K) = tkWChar) or (GetTypeKind(K) = tkBool) or
     (GetTypeKind(K) = tkEnumeration) then
  begin
    case SizeOf(K) of
      1: Exit(PByte(@L)^ = PByte(@R)^);
      2: Exit(PWord(@L)^ = PWord(@R)^);
      4: Exit(PUInt32(@L)^ = PUInt32(@R)^);
      8: Exit(PQWord(@L)^ = PQWord(@R)^);
    end;
  end;
  if (GetTypeKind(K) = tkInt64) or (GetTypeKind(K) = tkQWord) then
    Exit(PQWord(@L)^ = PQWord(@R)^);

  if Assigned(FEquals) then Exit(FEquals(L, R));
  Result := L = R;
end;

function TSwissTable.MatchGroup(ACtrl: PByte; AH2: Byte): TSwissMask;
begin
  Result := SwissMatchH2(ACtrl, AH2);
end;

function TSwissTable.MatchEmpty(ACtrl: PByte): TSwissMask;
begin
  Result := SwissMatchEmpty(ACtrl);
end;

function TSwissTable.MatchEmptyOrDeleted(ACtrl: PByte): TSwissMask;
begin
  Result := SwissMatchEmptyOrDeleted(ACtrl);
end;

procedure TSwissTable.SetCtrl(AIndex: SizeUInt; AValue: Byte);
begin
  FCtrl[AIndex] := AValue;
  if AIndex < GROUP_SIZE then
    FCtrl[FCapacity + AIndex] := AValue;
end;

{ Memory management }

procedure TSwissTable.AllocTable(ACapacity: SizeUInt);
var
  LCtrlSize, LSlotSize: SizeUInt;
begin
  FCapacity := ACapacity;
  FGroupCount := ACapacity div GROUP_SIZE;
  LCtrlSize := ACapacity + GROUP_SIZE;
  LSlotSize := ACapacity * SizeOf(TSlot);
  FCtrl := nil;
  FSlots := nil;

  if FAllocator <> nil then
  begin
    FCtrl := PByte(FAllocator.GetMem(LCtrlSize));
    FSlots := PSlot(FAllocator.GetMem(LSlotSize));
  end
  else
  begin
    GetMem(FCtrl, LCtrlSize);
    try
      GetMem(FSlots, LSlotSize);
    except
      FreeMem(FCtrl);
      FCtrl := nil;
      raise;
    end;
  end;

  FillChar(FCtrl^, LCtrlSize, CTRL_EMPTY);
  if System.IsManagedType(K) or System.IsManagedType(V) then
    FillChar(FSlots^, LSlotSize, 0);
  FGrowthLeft := ACapacity - ACapacity div 8;
end;

procedure TSwissTable.FreeTable;
var
  i: SizeUInt;
begin
  if FCtrl = nil then Exit;
  if System.IsManagedType(K) or System.IsManagedType(V) then
  begin
    for i := 0 to FCapacity - 1 do
      if FCtrl[i] < $80 then
      begin
        Finalize(FSlots[i].Key);
        Finalize(FSlots[i].Value);
      end;
  end;
  if FAllocator <> nil then
  begin
    FAllocator.FreeMem(FSlots);
    FAllocator.FreeMem(FCtrl);
  end
  else
  begin
    FreeMem(FSlots);
    FreeMem(FCtrl);
  end;
  FCtrl := nil;
  FSlots := nil;
end;

{ Probe and find }

function TSwissTable.FindIndex(const AKey: K; AHash: UInt32; out AIndex: SizeUInt): Boolean;
var
  Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase: SizeUInt;
  LMask, LEmptyMask: TSwissMask;
  LBit: Integer;
begin
  if FCapacity = 0 then begin AIndex := 0; Exit(False); end;

  Lh2 := AHash and $7F;
  LGroupIdx := (AHash shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;

  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := SwissMatchH2(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      LBit := SwissCtz(LMask);
      Li := LBase + SizeUInt(LBit);
      if KeysEqual(FSlots[Li].Key, AKey) then
      begin
        AIndex := Li;
        Exit(True);
      end;
      LMask := LMask and (LMask - 1);
    end;

    LEmptyMask := SwissMatchEmpty(@FCtrl[LBase]);
    if LEmptyMask <> 0 then
    begin
      AIndex := LBase + SizeUInt(SwissCtz(LEmptyMask));
      Exit(False);
    end;

    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

function TSwissTable.FindInsertSlot(AHash: UInt32): SizeUInt;
var
  LGroupIdx, LProbeOfs: SizeUInt;
  LMask: TSwissMask;
begin
  LGroupIdx := (AHash shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;

  while True do
  begin
    LMask := SwissMatchEmptyOrDeleted(@FCtrl[LGroupIdx * GROUP_SIZE]);
    if LMask <> 0 then
    begin
      Result := LGroupIdx * GROUP_SIZE + SizeUInt(SwissCtz(LMask));
      Exit;
    end;
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

procedure TSwissTable.GrowAndRehash;
var
  LOldCtrl: PByte;
  LOldSlots: PSlot;
  LOldCap, i: SizeUInt;
  LNewCap: SizeUInt;
  Lh: UInt32;
  LIdx: SizeUInt;
begin
  LOldCtrl := FCtrl;
  LOldSlots := FSlots;
  LOldCap := FCapacity;

  if FCapacity = 0 then
    LNewCap := MIN_CAPACITY
  else
    LNewCap := FCapacity * 2;

  AllocTable(LNewCap);
  FCount := 0;

  if LOldCtrl <> nil then
  begin
    for i := 0 to LOldCap - 1 do
    begin
      if LOldCtrl[i] < $80 then
      begin
        Lh := KeyHash(LOldSlots[i].Key);
        LIdx := FindInsertSlot(Lh);
        SetCtrl(LIdx, Lh and $7F);
        // 所有权转移：用 Move 把旧 slot 的内容（含 managed 引用）搬到新 slot，
        // 不触发 refcount 增减。旧 slot 内存随后整块释放，无需 finalize。
        Move(LOldSlots[i], FSlots[LIdx], SizeOf(TSlot));
        Inc(FCount);
        Dec(FGrowthLeft);
      end;
    end;
    if FAllocator <> nil then
    begin
      FAllocator.FreeMem(LOldSlots);
      FAllocator.FreeMem(LOldCtrl);
    end
    else
    begin
      FreeMem(LOldSlots);
      FreeMem(LOldCtrl);
    end;
  end;
end;

{ Public API }

constructor TSwissTable.Create(aCapacity: SizeUInt; aHash: THash; aEquals: TEquals; aAllocator: IAllocator);
begin
  inherited Create;
  FHash := aHash;
  FEquals := aEquals;
  FAllocator := aAllocator;
  FCtrl := nil;
  FSlots := nil;
  FCapacity := 0;
  FGroupCount := 0;
  FCount := 0;
  FGrowthLeft := 0;
  if aCapacity > 0 then
  begin
    if aCapacity < MIN_CAPACITY then aCapacity := MIN_CAPACITY;
    aCapacity := aCapacity + aCapacity div 7 + 1;
    // capacity must be power of 2 (for group count bitmask)
    aCapacity := aCapacity or (aCapacity shr 1);
    aCapacity := aCapacity or (aCapacity shr 2);
    aCapacity := aCapacity or (aCapacity shr 4);
    aCapacity := aCapacity or (aCapacity shr 8);
    aCapacity := aCapacity or (aCapacity shr 16);
    {$IF SizeOf(SizeUInt) = 8}
    aCapacity := aCapacity or (aCapacity shr 32);
    {$ENDIF}
    Inc(aCapacity);
    if aCapacity < MIN_CAPACITY then aCapacity := MIN_CAPACITY;
    AllocTable(aCapacity);
  end;
end;

destructor TSwissTable.Destroy;
begin
  FreeTable;
  FAllocator := nil;
  inherited Destroy;
end;

function TSwissTable.TryGetValue(const AKey: K; out AValue: V): Boolean;
var
  Lh: UInt32;
  Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase: SizeUInt;
  LMask, LEmptyMask: TSwissMask;
  LBit: Integer;
begin
  if FCapacity = 0 then Exit(False);
  if (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
    Lh := InlineHashMix32(PUInt32(@AKey)^)
  else
    Lh := KeyHash(AKey);
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;

  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := SwissMatchH2(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      LBit := SwissCtz(LMask);
      Li := LBase + SizeUInt(LBit);
      if KeysEqual(FSlots[Li].Key, AKey) then
      begin
        AValue := FSlots[Li].Value;
        Exit(True);
      end;
      LMask := LMask and (LMask - 1);
    end;
    LEmptyMask := SwissMatchEmpty(@FCtrl[LBase]);
    if LEmptyMask <> 0 then Exit(False);
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

function TSwissTable.ContainsKey(const AKey: K): Boolean;
var
  Lh: UInt32;
  Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase: SizeUInt;
  LMask, LEmptyMask: TSwissMask;
  LBit: Integer;
begin
  if FCapacity = 0 then Exit(False);
  if (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
    Lh := InlineHashMix32(PUInt32(@AKey)^)
  else
    Lh := KeyHash(AKey);
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := SwissMatchH2(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      LBit := SwissCtz(LMask);
      Li := LBase + SizeUInt(LBit);
      if KeysEqual(FSlots[Li].Key, AKey) then Exit(True);
      LMask := LMask and (LMask - 1);
    end;
    LEmptyMask := SwissMatchEmpty(@FCtrl[LBase]);
    if LEmptyMask <> 0 then Exit(False);
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

function TSwissTable.AddOrAssign(const AKey: K; const AValue: V): Boolean;
var
  Lh: UInt32;
  Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LInsertIdx, LBase: SizeUInt;
  LMask, LEmptyMask: TSwissMask;
  LBit: Integer;
  LFoundInsert: Boolean;
begin
  if FGrowthLeft = 0 then
    GrowAndRehash;

  if (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
    Lh := InlineHashMix32(PUInt32(@AKey)^)
  else
    Lh := KeyHash(AKey);
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  LFoundInsert := False;
  LInsertIdx := 0;

  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := SwissMatchH2(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      LBit := SwissCtz(LMask);
      Li := LBase + SizeUInt(LBit);
      if KeysEqual(FSlots[Li].Key, AKey) then
      begin
        if System.IsManagedType(V) then
          Finalize(FSlots[Li].Value);
        FSlots[Li].Value := AValue;
        Exit(False);
      end;
      LMask := LMask and (LMask - 1);
    end;

    LEmptyMask := SwissMatchEmpty(@FCtrl[LBase]);
    if LEmptyMask <> 0 then
    begin
      // empty 槽位既是探测链终点，也是首选插入点
      if not LFoundInsert then
        LInsertIdx := LBase + SizeUInt(SwissCtz(LEmptyMask));
      Break;
    end;

    // 整组无 empty：检查 deleted 槽位作为插入点（仅首次记录）
    if not LFoundInsert then
    begin
      LMask := SwissMatchEmptyOrDeleted(@FCtrl[LBase]);
      if LMask <> 0 then
      begin
        LInsertIdx := LBase + SizeUInt(SwissCtz(LMask));
        LFoundInsert := True;
      end;
    end;

    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;

  SetCtrl(LInsertIdx, Lh2);
  FSlots[LInsertIdx].Key := AKey;
  FSlots[LInsertIdx].Value := AValue;
  Inc(FCount);
  Dec(FGrowthLeft);
  Result := True;
end;

function TSwissTable.Remove(const AKey: K): Boolean;
var
  Lh: UInt32;
  LIdx: SizeUInt;
begin
  if FCapacity = 0 then Exit(False);
  if (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
    Lh := InlineHashMix32(PUInt32(@AKey)^)
  else
    Lh := KeyHash(AKey);
  if not FindIndex(AKey, Lh, LIdx) then Exit(False);

  if System.IsManagedType(K) then Finalize(FSlots[LIdx].Key);
  if System.IsManagedType(V) then Finalize(FSlots[LIdx].Value);
  FillChar(FSlots[LIdx], SizeOf(TSlot), 0);
  // Note: DELETED slots do not restore FGrowthLeft. This is intentional
  // (matches Abseil/hashbrown): DELETED preserves probe chains.
  // Growth budget is fully reclaimed on GrowAndRehash.
  SetCtrl(LIdx, CTRL_DELETED);
  Dec(FCount);
  Result := True;
end;

procedure TSwissTable.Put(const AKey: K; const AValue: V);
begin
  AddOrAssign(AKey, AValue);
end;

function TSwissTable.Get(const AKey: K): V;
begin
  if not TryGetValue(AKey, Result) then
    raise EInvalidOperation.Create('TSwissTable.Get: key not found');
end;

function TSwissTable.GetOrInsert(const AKey: K; const ADefault: V): V;
begin
  if not TryGetValue(AKey, Result) then
  begin
    Put(AKey, ADefault);
    Result := ADefault;
  end;
end;

procedure TSwissTable.Clear;
begin
  FreeTable;
  FCount := 0;
  FCapacity := 0;
  FGroupCount := 0;
  FGrowthLeft := 0;
end;

procedure TSwissTable.Reserve(AMinCapacity: SizeUInt);
var LTarget: SizeUInt;
begin
  if AMinCapacity <= FCount then Exit;
  LTarget := AMinCapacity + AMinCapacity div 7 + 1;
  LTarget := LTarget or (LTarget shr 1);
  LTarget := LTarget or (LTarget shr 2);
  LTarget := LTarget or (LTarget shr 4);
  LTarget := LTarget or (LTarget shr 8);
  LTarget := LTarget or (LTarget shr 16);
  {$IF SizeOf(SizeUInt) = 8}
  LTarget := LTarget or (LTarget shr 32);
  {$ENDIF}
  Inc(LTarget);
  if LTarget < MIN_CAPACITY then LTarget := MIN_CAPACITY;
  if LTarget <= FCapacity then Exit;
  if FCapacity = 0 then
    AllocTable(LTarget)
  else
  begin
    while FCapacity < LTarget do
      GrowAndRehash;
  end;
end;

procedure TSwissTable.ShrinkToFit;
var
  LOldCtrl: PByte;
  LOldSlots: PSlot;
  LOldCap, i: SizeUInt;
  LNewCap, Lh: UInt32;
  LIdx: SizeUInt;
begin
  if FCount = 0 then begin Clear; Exit; end;
  LNewCap := FCount + FCount div 7 + 1;
  LNewCap := LNewCap or (LNewCap shr 1);
  LNewCap := LNewCap or (LNewCap shr 2);
  LNewCap := LNewCap or (LNewCap shr 4);
  LNewCap := LNewCap or (LNewCap shr 8);
  LNewCap := LNewCap or (LNewCap shr 16);
  {$IF SizeOf(SizeUInt) = 8}
  LNewCap := LNewCap or (LNewCap shr 32);
  {$ENDIF}
  Inc(LNewCap);
  if LNewCap < MIN_CAPACITY then LNewCap := MIN_CAPACITY;
  if LNewCap >= FCapacity then Exit;

  LOldCtrl := FCtrl;
  LOldSlots := FSlots;
  LOldCap := FCapacity;

  AllocTable(LNewCap);
  FCount := 0;

  for i := 0 to LOldCap - 1 do
  begin
    if LOldCtrl[i] < $80 then
    begin
      Lh := KeyHash(LOldSlots[i].Key);
      LIdx := FindInsertSlot(Lh);
      SetCtrl(LIdx, Lh and $7F);
      Move(LOldSlots[i], FSlots[LIdx], SizeOf(TSlot));
      Inc(FCount);
      Dec(FGrowthLeft);
    end;
  end;

  if FAllocator <> nil then
  begin
    FAllocator.FreeMem(LOldSlots);
    FAllocator.FreeMem(LOldCtrl);
  end
  else
  begin
    FreeMem(LOldSlots);
    FreeMem(LOldCtrl);
  end;
end;

procedure TSwissTable.Retain(AFunc: TRetainFunc);
var i: SizeUInt;
begin
  if FCapacity = 0 then Exit;
  for i := 0 to FCapacity - 1 do
  begin
    if FCtrl[i] < $80 then
    begin
      if not AFunc(FSlots[i].Key, FSlots[i].Value) then
      begin
        if System.IsManagedType(K) then Finalize(FSlots[i].Key);
        if System.IsManagedType(V) then Finalize(FSlots[i].Value);
        FillChar(FSlots[i], SizeOf(TSlot), 0);
        SetCtrl(i, CTRL_DELETED);
        Dec(FCount);
      end;
    end;
  end;
end;

procedure TSwissTable.ForEach(AFunc: TVisitFunc);
var i: SizeUInt;
begin
  if FCapacity = 0 then Exit;
  for i := 0 to FCapacity - 1 do
    if FCtrl[i] < $80 then
      AFunc(FSlots[i].Key, FSlots[i].Value);
end;

procedure TSwissTable.Drain(AFunc: TVisitFunc);
var i: SizeUInt;
begin
  if FCapacity = 0 then Exit;
  for i := 0 to FCapacity - 1 do
    if FCtrl[i] < $80 then
    begin
      AFunc(FSlots[i].Key, FSlots[i].Value);
      if System.IsManagedType(K) then Finalize(FSlots[i].Key);
      if System.IsManagedType(V) then Finalize(FSlots[i].Value);
      SetCtrl(i, CTRL_EMPTY);
    end;
  FCount := 0;
  FGrowthLeft := FCapacity - FCapacity div 8;
end;

function TSwissTable.GetKeys: TKeyArray;
var i, j: SizeUInt;
begin
  SetLength(Result, FCount);
  j := 0;
  if FCapacity > 0 then
    for i := 0 to FCapacity - 1 do
      if FCtrl[i] < $80 then
      begin
        Result[j] := FSlots[i].Key;
        Inc(j);
      end;
end;

function TSwissTable.GetCtrlByte(AIndex: SizeUInt): Byte;
begin
  Result := FCtrl[AIndex];
end;

function TSwissTable.GetSlotKey(AIndex: SizeUInt): K;
begin
  Result := FSlots[AIndex].Key;
end;

function TSwissTable.TEnumerator.MoveNext: Boolean;
begin
  while FIdx < FCapacity do
  begin
    if FCtrl[FIdx] < $80 then
    begin
      FCurrent := FSlots[FIdx];
      Inc(FIdx);
      Exit(True);
    end;
    Inc(FIdx);
  end;
  Result := False;
end;

function TSwissTable.GetEnumerator: TEnumerator;
begin
  Result.FCtrl := FCtrl;
  Result.FSlots := FSlots;
  Result.FCapacity := FCapacity;
  Result.FIdx := 0;
  FillChar(Result.FCurrent, SizeOf(TSlot), 0);
end;

function TSwissTable.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

function TSwissTable.GetCount: SizeUInt;
begin
  Result := FCount;
end;


{ TPtrEnumerator }

function TSwissTable.TPtrEnumerator.MoveNext: Boolean;
begin
  while FIdx < FCapacity do
  begin
    if FCtrl[FIdx] < $80 then
    begin
      Inc(FIdx);
      Exit(True);
    end;
    Inc(FIdx);
  end;
  Result := False;
end;

function TSwissTable.TPtrEnumerator.GetCurrent: PSlot;
begin
  Result := @FSlots[FIdx - 1];
end;

function TSwissTable.GetPtrEnumerator: TPtrEnumerator;
begin
  Result.FCtrl := FCtrl;
  Result.FSlots := FSlots;
  Result.FCapacity := FCapacity;
  Result.FIdx := 0;
end;

function TSwissTable.Slots: PSlot;
begin
  Result := FSlots;
end;
end.