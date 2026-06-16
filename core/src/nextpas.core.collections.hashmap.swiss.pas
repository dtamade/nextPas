unit nextpas.core.collections.hashmap.swiss;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.typinfo,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mem.intf,
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
  type
    TTableBuffers = record
      Ctrl: PByte;
      Slots: PSlot;
      Capacity: SizeUInt;
      GroupCount: SizeUInt;
      GrowthLeft: SizeUInt;
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
    function FindInsertSlot(AHash: UInt32; out AWasEmpty: Boolean): SizeUInt;
    procedure SetCtrl(AIndex: SizeUInt; AValue: Byte); {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    procedure AllocBuffers(ACapacity: SizeUInt; out ABuffers: TTableBuffers);
    procedure FreeRawBuffers(var ABuffers: TTableBuffers);
    function FindInsertSlotIn(ACtrl: PByte; AGroupCount: SizeUInt; AHash: UInt32;
      out AWasEmpty: Boolean): SizeUInt;
    procedure SetCtrlIn(ACtrl: PByte; ACapacity, AIndex: SizeUInt; AValue: Byte);
    procedure AllocTable(ACapacity: SizeUInt);
    procedure FreeTable;
    procedure ClearSlot(AIndex: SizeUInt);
    procedure AssignNewSlot(AIndex: SizeUInt; const AKey: K; const AValue: V);
    procedure RehashToCapacity(ANewCapacity: SizeUInt);
    procedure GrowAndRehash;

  public
    constructor Create(aCapacity: SizeUInt = 0; aHash: THash = nil; aEquals: TEquals = nil; aAllocator: IAllocator = nil);
    destructor Destroy; override;

    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    function AddOrAssign(const AKey: K; const AValue: V): Boolean;
    function Remove(const AKey: K): Boolean;
    procedure Put(const AKey: K; const AValue: V); {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    procedure PutNew(const AKey: K; const AValue: V); {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
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
  LKind: TTypeKind;
begin
  if Assigned(FHash) then Exit(FHash(AKey));

  p := @AKey;
  LKind := GetTypeKind(K);
  // 默认路径：内置 key 类型直接计算，避免额外回调开销。
  if (LKind = tkInteger) or (LKind = tkChar) or (LKind = tkWChar) or
     (LKind = tkBool) or (LKind = tkEnumeration) then
  begin
    case SizeOf(K) of
      1: Exit(InlineHashMix32(PByte(p)^));
      2: Exit(InlineHashMix32(PWord(p)^));
      4: Exit(InlineHashMix32(PUInt32(p)^));
      8: Exit(HashOfUInt64(PQWord(p)^));
    end;
  end;
  if (LKind = tkInt64) or (LKind = tkQWord) then
    Exit(HashOfUInt64(PQWord(p)^));

  if (LKind = tkAString) or (LKind = tkLString) then
    Exit(HashOfAnsiString(PAnsiString(p)^));
  if (LKind = tkUString) or (LKind = tkWString) then
    Exit(HashOfUnicodeString(PUnicodeString(p)^));

  raise ENotSupportedError.Create('TSwissTable: custom hash/equality required for this key type');
end;

function TSwissTable.KeysEqual(const L, R: K): Boolean;
var
  LKind: TTypeKind;
begin
  if Assigned(FEquals) then Exit(FEquals(L, R));

  LKind := GetTypeKind(K);
  // 默认路径：ordinal 类型直接整数比较，避免额外回调开销。
  if (LKind = tkInteger) or (LKind = tkChar) or (LKind = tkWChar) or
     (LKind = tkBool) or (LKind = tkEnumeration) then
  begin
    case SizeOf(K) of
      1: Exit(PByte(@L)^ = PByte(@R)^);
      2: Exit(PWord(@L)^ = PWord(@R)^);
      4: Exit(PUInt32(@L)^ = PUInt32(@R)^);
      8: Exit(PQWord(@L)^ = PQWord(@R)^);
    end;
  end;
  if (LKind = tkInt64) or (LKind = tkQWord) then
    Exit(PQWord(@L)^ = PQWord(@R)^);

  if (LKind = tkAString) or (LKind = tkLString) then
    Exit(PAnsiString(@L)^ = PAnsiString(@R)^);
  if (LKind = tkUString) or (LKind = tkWString) then
    Exit(PUnicodeString(@L)^ = PUnicodeString(@R)^);

  raise ENotSupportedError.Create('TSwissTable: custom hash/equality required for this key type');
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

procedure TSwissTable.AllocBuffers(ACapacity: SizeUInt; out ABuffers: TTableBuffers);
var
  LCtrlSize, LSlotSize: SizeUInt;
begin
  ABuffers.Ctrl := nil;
  ABuffers.Slots := nil;
  ABuffers.Capacity := ACapacity;
  ABuffers.GroupCount := ACapacity div GROUP_SIZE;
  ABuffers.GrowthLeft := ACapacity - ACapacity div 8;
  LCtrlSize := ACapacity + GROUP_SIZE;
  LSlotSize := ACapacity * SizeOf(TSlot);

  if FAllocator <> nil then
  begin
    ABuffers.Ctrl := PByte(FAllocator.GetMem(LCtrlSize));
    try
      ABuffers.Slots := PSlot(FAllocator.GetMem(LSlotSize));
    except
      FAllocator.FreeMem(ABuffers.Ctrl);
      ABuffers.Ctrl := nil;
      raise;
    end;
  end
  else
  begin
    GetMem(ABuffers.Ctrl, LCtrlSize);
    try
      GetMem(ABuffers.Slots, LSlotSize);
    except
      FreeMem(ABuffers.Ctrl);
      ABuffers.Ctrl := nil;
      raise;
    end;
  end;

  FillChar(ABuffers.Ctrl^, LCtrlSize, CTRL_EMPTY);
  if System.IsManagedType(K) or System.IsManagedType(V) then
    FillChar(ABuffers.Slots^, LSlotSize, 0);
end;

procedure TSwissTable.FreeRawBuffers(var ABuffers: TTableBuffers);
begin
  if ABuffers.Ctrl = nil then
    Exit;

  if FAllocator <> nil then
  begin
    FAllocator.FreeMem(ABuffers.Slots);
    FAllocator.FreeMem(ABuffers.Ctrl);
  end
  else
  begin
    FreeMem(ABuffers.Slots);
    FreeMem(ABuffers.Ctrl);
  end;

  ABuffers.Ctrl := nil;
  ABuffers.Slots := nil;
  ABuffers.Capacity := 0;
  ABuffers.GroupCount := 0;
  ABuffers.GrowthLeft := 0;
end;

procedure TSwissTable.AllocTable(ACapacity: SizeUInt);
var
  LBuffers: TTableBuffers;
begin
  AllocBuffers(ACapacity, LBuffers);
  FCtrl := LBuffers.Ctrl;
  FSlots := LBuffers.Slots;
  FCapacity := LBuffers.Capacity;
  FGroupCount := LBuffers.GroupCount;
  FGrowthLeft := LBuffers.GrowthLeft;
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
        ClearSlot(i);
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

procedure TSwissTable.ClearSlot(AIndex: SizeUInt);
begin
  if System.IsManagedType(K) then
    Finalize(FSlots[AIndex].Key);
  if System.IsManagedType(V) then
    Finalize(FSlots[AIndex].Value);
  FillChar(FSlots[AIndex], SizeOf(TSlot), 0);
end;

procedure TSwissTable.AssignNewSlot(AIndex: SizeUInt; const AKey: K; const AValue: V);
var
  LKeyInitialized: Boolean;
  LValueInitialized: Boolean;
begin
  if System.IsManagedType(K) or System.IsManagedType(V) then
  begin
    LKeyInitialized := False;
    LValueInitialized := False;
    try
      if System.IsManagedType(K) then
      begin
        Initialize(FSlots[AIndex].Key);
        LKeyInitialized := True;
      end;
      if System.IsManagedType(V) then
      begin
        Initialize(FSlots[AIndex].Value);
        LValueInitialized := True;
      end;
      FSlots[AIndex].Key := AKey;
      FSlots[AIndex].Value := AValue;
    except
      if LKeyInitialized then
        Finalize(FSlots[AIndex].Key);
      if LValueInitialized then
        Finalize(FSlots[AIndex].Value);
      FillChar(FSlots[AIndex], SizeOf(TSlot), 0);
      raise;
    end;
  end
  else
  begin
    FSlots[AIndex].Key := AKey;
    FSlots[AIndex].Value := AValue;
  end;
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

function TSwissTable.FindInsertSlot(AHash: UInt32; out AWasEmpty: Boolean): SizeUInt;
var
  LGroupIdx, LProbeOfs: SizeUInt;
  LMask, LEmptyMask: TSwissMask;
  LBit: Int32;
begin
  LGroupIdx := (AHash shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;

  while True do
  begin
    LMask := SwissMatchEmptyOrDeleted(@FCtrl[LGroupIdx * GROUP_SIZE]);
    if LMask <> 0 then
    begin
      LBit := SwissCtz(LMask);
      LEmptyMask := SwissMatchEmpty(@FCtrl[LGroupIdx * GROUP_SIZE]);
      AWasEmpty := (LEmptyMask and (TSwissMask(1) shl LBit)) <> 0;
      Result := LGroupIdx * GROUP_SIZE + SizeUInt(LBit);
      Exit;
    end;
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

function TSwissTable.FindInsertSlotIn(ACtrl: PByte; AGroupCount: SizeUInt; AHash: UInt32;
  out AWasEmpty: Boolean): SizeUInt;
var
  LGroupIdx, LProbeOfs: SizeUInt;
  LMask, LEmptyMask: TSwissMask;
  LBit: Int32;
begin
  LGroupIdx := (AHash shr 7) and (AGroupCount - 1);
  LProbeOfs := 0;

  while True do
  begin
    LMask := SwissMatchEmptyOrDeleted(@ACtrl[LGroupIdx * GROUP_SIZE]);
    if LMask <> 0 then
    begin
      LBit := SwissCtz(LMask);
      LEmptyMask := SwissMatchEmpty(@ACtrl[LGroupIdx * GROUP_SIZE]);
      AWasEmpty := (LEmptyMask and (TSwissMask(1) shl LBit)) <> 0;
      Result := LGroupIdx * GROUP_SIZE + SizeUInt(LBit);
      Exit;
    end;
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (AGroupCount - 1);
  end;
end;

procedure TSwissTable.SetCtrlIn(ACtrl: PByte; ACapacity, AIndex: SizeUInt; AValue: Byte);
begin
  ACtrl[AIndex] := AValue;
  if AIndex < GROUP_SIZE then
    ACtrl[ACapacity + AIndex] := AValue;
end;

procedure TSwissTable.RehashToCapacity(ANewCapacity: SizeUInt);
var
  LOldCtrl: PByte;
  LOldSlots: PSlot;
  LOldCap, LOldCount, i: SizeUInt;
  LNewTable: TTableBuffers;
  Lh: UInt32;
  LIdx: SizeUInt;
  LWasEmpty: Boolean;
begin
  LOldCtrl := FCtrl;
  LOldSlots := FSlots;
  LOldCap := FCapacity;
  LOldCount := FCount;
  AllocBuffers(ANewCapacity, LNewTable);
  try
    if LOldCtrl <> nil then
    begin
      for i := 0 to LOldCap - 1 do
      begin
        if LOldCtrl[i] < $80 then
        begin
          Lh := KeyHash(LOldSlots[i].Key);
          LIdx := FindInsertSlotIn(LNewTable.Ctrl, LNewTable.GroupCount, Lh, LWasEmpty);
          SetCtrlIn(LNewTable.Ctrl, LNewTable.Capacity, LIdx, Lh and $7F);
          // Move transfers ownership only after the whole operation commits.
          // On exception, the old table remains the owner and the temporary table is freed raw.
          Move(LOldSlots[i], LNewTable.Slots[LIdx], SizeOf(TSlot));
          if LWasEmpty then
            Dec(LNewTable.GrowthLeft);
        end;
      end;
    end;
  except
    FreeRawBuffers(LNewTable);
    raise;
  end;

  FCtrl := LNewTable.Ctrl;
  FSlots := LNewTable.Slots;
  FCapacity := LNewTable.Capacity;
  FGroupCount := LNewTable.GroupCount;
  FCount := LOldCount;
  FGrowthLeft := LNewTable.GrowthLeft;

  if LOldCtrl <> nil then
  begin
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

procedure TSwissTable.GrowAndRehash;
var
  LNewCap: SizeUInt;
begin
  if FCapacity = 0 then
    LNewCap := MIN_CAPACITY
  else
    LNewCap := FCapacity * 2;

  RehashToCapacity(LNewCap);
end;

{ Public API }

constructor TSwissTable.Create(aCapacity: SizeUInt; aHash: THash; aEquals: TEquals; aAllocator: IAllocator);
begin
  inherited Create;
  if Assigned(aHash) <> Assigned(aEquals) then
    raise EArgumentError.Create('TSwissTable: hash/equality callbacks must be provided together');
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
  if (not Assigned(FHash)) and (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
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
  if (not Assigned(FHash)) and (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
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
  LMask, LFreeMask, LEmptyMask: TSwissMask;
  LBit: Integer;
  LFoundInsert: Boolean;
  LInsertWasEmpty: Boolean;
  LCtrlPtr: PByte;
begin
  if FCapacity = 0 then
    GrowAndRehash;

  if (not Assigned(FHash)) and (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
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
    LCtrlPtr := @FCtrl[LBase];
    LMask := SwissMatchH2(LCtrlPtr, Lh2);
    while LMask <> 0 do
    begin
      LBit := SwissCtz(LMask);
      Li := LBase + SizeUInt(LBit);
      if KeysEqual(FSlots[Li].Key, AKey) then
      begin
        // Managed assignment releases the old value and also handles self-alias.
        FSlots[Li].Value := AValue;
        Exit(False);
      end;
      LMask := LMask and (LMask - 1);
    end;

    LFreeMask := SwissMatchEmptyOrDeleted(LCtrlPtr);
    if LFreeMask <> 0 then
    begin
      LEmptyMask := SwissMatchEmpty(LCtrlPtr);
      if LEmptyMask <> 0 then
      begin
        if not LFoundInsert then
          LInsertIdx := LBase + SizeUInt(SwissCtz(LEmptyMask));
        Break;
      end;
      if not LFoundInsert then
      begin
        LInsertIdx := LBase + SizeUInt(SwissCtz(LFreeMask));
        LFoundInsert := True;
      end;
    end;

    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;

  LInsertWasEmpty := FCtrl[LInsertIdx] = CTRL_EMPTY;
  if LInsertWasEmpty and (FGrowthLeft = 0) then
  begin
    GrowAndRehash;
    PutNew(AKey, AValue);
    Exit(True);
  end;

  AssignNewSlot(LInsertIdx, AKey, AValue);
  SetCtrl(LInsertIdx, Lh2);
  Inc(FCount);
  if LInsertWasEmpty then
    Dec(FGrowthLeft);
  Result := True;
end;

function TSwissTable.Remove(const AKey: K): Boolean;
var
  Lh: UInt32;
  LIdx, LGroupBase: SizeUInt;
begin
  if FCapacity = 0 then Exit(False);
  if (not Assigned(FHash)) and (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
    Lh := InlineHashMix32(PUInt32(@AKey)^)
  else
    Lh := KeyHash(AKey);
  if not FindIndex(AKey, Lh, LIdx) then Exit(False);

  ClearSlot(LIdx);

  LGroupBase := (LIdx div GROUP_SIZE) * GROUP_SIZE;
  if SwissMatchEmpty(@FCtrl[LGroupBase]) <> 0 then
  begin
    SetCtrl(LIdx, CTRL_EMPTY);
    Inc(FGrowthLeft);
  end
  else
    SetCtrl(LIdx, CTRL_DELETED);

  Dec(FCount);
  Result := True;
end;

procedure TSwissTable.Put(const AKey: K; const AValue: V);
begin
  AddOrAssign(AKey, AValue);
end;

procedure TSwissTable.PutNew(const AKey: K; const AValue: V);
var
  Lh: UInt32;
  LIdx: SizeUInt;
  LWasEmpty: Boolean;
begin
  if FCapacity = 0 then
    GrowAndRehash;
  if (not Assigned(FHash)) and (GetTypeKind(K) = tkInteger) and (SizeOf(K) = 4) then
    Lh := InlineHashMix32(PUInt32(@AKey)^)
  else
    Lh := KeyHash(AKey);
  LIdx := FindInsertSlot(Lh, LWasEmpty);
  if LWasEmpty and (FGrowthLeft = 0) then
  begin
    GrowAndRehash;
    LIdx := FindInsertSlot(Lh, LWasEmpty);
  end;
  AssignNewSlot(LIdx, AKey, AValue);
  SetCtrl(LIdx, Lh and $7F);
  Inc(FCount);
  if LWasEmpty then
    Dec(FGrowthLeft);
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
  LNewCap: SizeUInt;
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

  RehashToCapacity(LNewCap);
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
        ClearSlot(i);
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
var
  i: SizeUInt;
  LGroupBase: SizeUInt;
  LKey: K;
  LValue: V;
begin
  if FCapacity = 0 then Exit;
  for i := 0 to FCapacity - 1 do
    if FCtrl[i] < $80 then
    begin
      LKey := FSlots[i].Key;
      LValue := FSlots[i].Value;
      try
        AFunc(LKey, LValue);
      finally
        LKey := Default(K);
        LValue := Default(V);
      end;
      ClearSlot(i);
      LGroupBase := (i div GROUP_SIZE) * GROUP_SIZE;
      if SwissMatchEmpty(@FCtrl[LGroupBase]) <> 0 then
      begin
        SetCtrl(i, CTRL_EMPTY);
        Inc(FGrowthLeft);
      end
      else
        SetCtrl(i, CTRL_DELETED);
      Dec(FCount);
    end;

  FillChar(FCtrl^, FCapacity + GROUP_SIZE, CTRL_EMPTY);
  FCount := 0;
  FGrowthLeft := FCapacity - FCapacity div 8;
end;

function TSwissTable.GetKeys: TKeyArray;
var i, j: SizeUInt;
begin
  Result := nil;
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
