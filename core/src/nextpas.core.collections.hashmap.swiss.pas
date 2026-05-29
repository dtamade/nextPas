unit nextpas.core.collections.hashmap.swiss;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, TypInfo,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.hashmap.base,
  nextpas.core.simd.base,
  nextpas.core.simd.vec16;

const
  CTRL_EMPTY   = Byte($FF);
  CTRL_DELETED = Byte($80);
  GROUP_SIZE   = 16;
  MIN_CAPACITY = 16;

function GroupMaskFirstSet(mask: TMask16): Integer; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchH2(ACtrl: PByte; AH2: Byte): TMask16; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchEmpty(ACtrl: PByte): TMask16; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchEmptyOrDeleted(ACtrl: PByte): TMask16; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

type
  generic TSwissTable<K, V> = class
  public type
    THash = specialize TKeyHashFunc<K>;
    TEquals = specialize TKeyEqualsFunc<K>;
    PSlot = ^TSlot;
    TSlot = record
      Key: K;
      Value: V;
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
    function MatchGroup(ACtrl: PByte; AH2: Byte): TMask16; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function MatchEmpty(ACtrl: PByte): TMask16; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function MatchEmptyOrDeleted(ACtrl: PByte): TMask16; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
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
    procedure Clear;
    function GetCount: SizeUInt;

    property Count: SizeUInt read FCount;
    property Capacity: SizeUInt read FCapacity;
  end;

implementation

uses
  nextpas.core.collections.hashmap;

function GroupMaskFirstSet(mask: TMask16): Integer;
begin
  Result := Vec16Ctz(mask);
end;

function SwissMatchH2(ACtrl: PByte; AH2: Byte): TMask16;
begin
  Result := Vec16CmpEq(ACtrl, AH2);
end;

function SwissMatchEmpty(ACtrl: PByte): TMask16;
begin
  Result := Vec16CmpEq(ACtrl, CTRL_EMPTY);
end;

function SwissMatchEmptyOrDeleted(ACtrl: PByte): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to GROUP_SIZE - 1 do
    if ACtrl[i] >= $80 then Result := Result or TMask16(1 shl i);
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
      1: Exit(HashOfUInt32(PByte(p)^));
      2: Exit(HashOfUInt32(PWord(p)^));
      4: Exit(HashOfUInt32(PUInt32(p)^));
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
    1: Result := HashOfUInt32(PByte(p)^);
    2: Result := HashOfUInt32(PWord(p)^);
    4: Result := HashOfUInt32(PUInt32(p)^);
    8: Result := HashOfUInt64(PQWord(p)^);
  else
    Result := HashOfUInt32(PUInt32(p)^);
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

function TSwissTable.MatchGroup(ACtrl: PByte; AH2: Byte): TMask16;
begin
  Result := SwissMatchH2(ACtrl, AH2);
end;

function TSwissTable.MatchEmpty(ACtrl: PByte): TMask16;
begin
  Result := SwissMatchEmpty(ACtrl);
end;

function TSwissTable.MatchEmptyOrDeleted(ACtrl: PByte): TMask16;
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

  if FAllocator <> nil then
  begin
    FCtrl := PByte(FAllocator.GetMem(LCtrlSize));
    FSlots := PSlot(FAllocator.GetMem(LSlotSize));
  end
  else
  begin
    GetMem(FCtrl, LCtrlSize);
    GetMem(FSlots, LSlotSize);
  end;

  FillChar(FCtrl^, LCtrlSize, CTRL_EMPTY);
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
  LMask, LEmptyMask: TMask16;
  LBit: Integer;
begin
  if FCapacity = 0 then begin AIndex := 0; Exit(False); end;

  Lh2 := AHash and $7F;
  LGroupIdx := (AHash shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;

  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := Vec16CmpEq(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      LBit := Vec16Ctz(LMask);
      Li := LBase + SizeUInt(LBit);
      if KeysEqual(FSlots[Li].Key, AKey) then
      begin
        AIndex := Li;
        Exit(True);
      end;
      LMask := LMask and (LMask - 1);
    end;

    LEmptyMask := Vec16CmpEq(@FCtrl[LBase], CTRL_EMPTY);
    if LEmptyMask <> 0 then
    begin
      AIndex := LBase + SizeUInt(Vec16Ctz(LEmptyMask));
      Exit(False);
    end;

    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

function TSwissTable.FindInsertSlot(AHash: UInt32): SizeUInt;
var
  LGroupIdx, LProbeOfs: SizeUInt;
  LMask: TMask16;
begin
  LGroupIdx := (AHash shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;

  while True do
  begin
    LMask := MatchEmptyOrDeleted(@FCtrl[LGroupIdx * GROUP_SIZE]);
    if LMask <> 0 then
    begin
      Result := LGroupIdx * GROUP_SIZE + SizeUInt(GroupMaskFirstSet(LMask));
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
  LIdx: SizeUInt;
begin
  Lh := KeyHash(AKey);
  Result := FindIndex(AKey, Lh, LIdx);
  if Result then
    AValue := FSlots[LIdx].Value;
end;

function TSwissTable.ContainsKey(const AKey: K): Boolean;
var
  Lh: UInt32;
  LIdx: SizeUInt;
begin
  Lh := KeyHash(AKey);
  Result := FindIndex(AKey, Lh, LIdx);
end;

function TSwissTable.AddOrAssign(const AKey: K; const AValue: V): Boolean;
var
  Lh: UInt32;
  Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LInsertIdx, LBase: SizeUInt;
  LMask, LEmptyMask: TMask16;
  LBit: Integer;
  LFoundInsert: Boolean;
begin
  if FGrowthLeft = 0 then
    GrowAndRehash;

  Lh := KeyHash(AKey);
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  LFoundInsert := False;
  LInsertIdx := 0;

  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := Vec16CmpEq(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      LBit := Vec16Ctz(LMask);
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

    LEmptyMask := Vec16CmpEq(@FCtrl[LBase], CTRL_EMPTY);
    if LEmptyMask <> 0 then
    begin
      // empty 槽位既是探测链终点，也是首选插入点
      if not LFoundInsert then
        LInsertIdx := LBase + SizeUInt(Vec16Ctz(LEmptyMask));
      Break;
    end;

    // 整组无 empty：检查 deleted 槽位作为插入点（仅首次记录）
    if not LFoundInsert then
    begin
      LMask := SwissMatchEmptyOrDeleted(@FCtrl[LBase]);
      if LMask <> 0 then
      begin
        LInsertIdx := LBase + SizeUInt(Vec16Ctz(LMask));
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
  Lh := KeyHash(AKey);
  if not FindIndex(AKey, Lh, LIdx) then Exit(False);

  if System.IsManagedType(K) then Finalize(FSlots[LIdx].Key);
  if System.IsManagedType(V) then Finalize(FSlots[LIdx].Value);
  FillChar(FSlots[LIdx], SizeOf(TSlot), 0);
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

procedure TSwissTable.Clear;
begin
  FreeTable;
  FCount := 0;
  FCapacity := 0;
  FGroupCount := 0;
  FGrowthLeft := 0;
end;

function TSwissTable.GetCount: SizeUInt;
begin
  Result := FCount;
end;

end.