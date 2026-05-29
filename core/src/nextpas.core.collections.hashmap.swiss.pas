unit nextpas.core.collections.hashmap.swiss;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, TypInfo,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.hashmap.base,
  nextpas.core.simd.micro;

const
  CTRL_EMPTY   = Byte($FF);
  CTRL_DELETED = Byte($80);
  GROUP_SIZE   = 16;
  MIN_CAPACITY = 16;

type
  TGroupMask = Word;

function GroupMaskFirstSet(mask: TGroupMask): Integer; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchH2(ACtrl: PByte; AH2: Byte): TGroupMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchEmpty(ACtrl: PByte): TGroupMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
function SwissMatchEmptyOrDeleted(ACtrl: PByte): TGroupMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}

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
    function MatchGroup(ACtrl: PByte; AH2: Byte): TGroupMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function MatchEmpty(ACtrl: PByte): TGroupMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
    function MatchEmptyOrDeleted(ACtrl: PByte): TGroupMask; {$IFDEF NEXTPAS_CORE_INLINE} inline; {$ENDIF}
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

function GroupMaskFirstSet(mask: TGroupMask): Integer;
begin
  if mask = 0 then Exit(-1);
  Result := MicroCtz16(TMask16(mask));
end;

function SwissMatchH2(ACtrl: PByte; AH2: Byte): TGroupMask;
begin
  Result := TGroupMask(MicroCmpEqU8x16_Asm(ACtrl, AH2));
end;

function SwissMatchEmpty(ACtrl: PByte): TGroupMask;
begin
  Result := TGroupMask(MicroCmpEqU8x16_Asm(ACtrl, CTRL_EMPTY));
end;

function SwissMatchEmptyOrDeleted(ACtrl: PByte): TGroupMask;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to GROUP_SIZE - 1 do
    if ACtrl[i] >= $80 then Result := Result or TGroupMask(1 shl i);
end;

{ TSwissTable<K,V> - Core helpers }

function TSwissTable.KeyHash(const AKey: K): UInt32;
var
  p: Pointer;
begin
  if Assigned(FHash) then Exit(FHash(AKey));
  p := @AKey;
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
  if Assigned(FEquals) then Exit(FEquals(L, R));
  Result := L = R;
end;

function TSwissTable.MatchGroup(ACtrl: PByte; AH2: Byte): TGroupMask;
begin
  Result := SwissMatchH2(ACtrl, AH2);
end;

function TSwissTable.MatchEmpty(ACtrl: PByte): TGroupMask;
begin
  Result := SwissMatchEmpty(ACtrl);
end;

function TSwissTable.MatchEmptyOrDeleted(ACtrl: PByte): TGroupMask;
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
  LGroupIdx, LProbeOfs, Li: SizeUInt;
  LMask, LEmptyMask: TGroupMask;
  LBit: Integer;
begin
  if FCapacity = 0 then begin AIndex := 0; Exit(False); end;

  Lh2 := AHash and $7F;
  LGroupIdx := (AHash shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;

  while True do
  begin
    LMask := MatchGroup(@FCtrl[LGroupIdx * GROUP_SIZE], Lh2);
    while LMask <> 0 do
    begin
      LBit := GroupMaskFirstSet(LMask);
      Li := LGroupIdx * GROUP_SIZE + SizeUInt(LBit);
      if KeysEqual(FSlots[Li].Key, AKey) then
      begin
        AIndex := Li;
        Exit(True);
      end;
      LMask := LMask and (LMask - 1);
    end;

    LEmptyMask := MatchEmpty(@FCtrl[LGroupIdx * GROUP_SIZE]);
    if LEmptyMask <> 0 then
    begin
      AIndex := LGroupIdx * GROUP_SIZE + SizeUInt(GroupMaskFirstSet(LEmptyMask));
      Exit(False);
    end;

    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

function TSwissTable.FindInsertSlot(AHash: UInt32): SizeUInt;
var
  LGroupIdx, LProbeOfs: SizeUInt;
  LMask: TGroupMask;
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
        FSlots[LIdx] := LOldSlots[i];
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
  LGroupIdx, LProbeOfs, Li, LInsertIdx: SizeUInt;
  LMask, LEmptyMask: TGroupMask;
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
    LMask := MatchGroup(@FCtrl[LGroupIdx * GROUP_SIZE], Lh2);
    while LMask <> 0 do
    begin
      LBit := GroupMaskFirstSet(LMask);
      Li := LGroupIdx * GROUP_SIZE + SizeUInt(LBit);
      if KeysEqual(FSlots[Li].Key, AKey) then
      begin
        if System.IsManagedType(V) then
          Finalize(FSlots[Li].Value);
        FSlots[Li].Value := AValue;
        Exit(False);
      end;
      LMask := LMask and (LMask - 1);
    end;

    if not LFoundInsert then
    begin
      LEmptyMask := MatchEmptyOrDeleted(@FCtrl[LGroupIdx * GROUP_SIZE]);
      if LEmptyMask <> 0 then
      begin
        LInsertIdx := LGroupIdx * GROUP_SIZE + SizeUInt(GroupMaskFirstSet(LEmptyMask));
        LFoundInsert := True;
      end;
    end;

    LEmptyMask := MatchEmpty(@FCtrl[LGroupIdx * GROUP_SIZE]);
    if LEmptyMask <> 0 then
      Break;

    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;

  if not LFoundInsert then
    LInsertIdx := LGroupIdx * GROUP_SIZE + SizeUInt(GroupMaskFirstSet(MatchEmpty(@FCtrl[LGroupIdx * GROUP_SIZE])));

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