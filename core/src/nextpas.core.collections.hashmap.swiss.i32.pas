unit nextpas.core.collections.hashmap.swiss.i32;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.default,
  nextpas.core.mem,
  nextpas.core.mem.error,
  nextpas.core.simd.base,
  nextpas.core.simd.vec16;

const
  CTRL_EMPTY   = Byte($FF);
  CTRL_DELETED = Byte($80);
  GROUP_SIZE   = 16;

function InlineHash32(x: UInt32): UInt32; inline;

type
  generic TSwissTableI32<V> = class
  public type
    PSlot = ^TSlot;
    TSlot = packed record
      Key: Int32;
      Value: V;
    end;
  private
    FCtrl: PByte;
    FSlots: PSlot;
    FCapacity: SizeUInt;
    FGroupCount: SizeUInt;
    FCount: SizeUInt;
    FGrowthLeft: SizeUInt;
    FAllocator: TMemAllocator;

    procedure AllocTable(ACapacity: SizeUInt);
    procedure FreeTable;
    procedure GrowAndRehash;
    procedure SetCtrl(AIndex: SizeUInt; AValue: Byte); inline;

  public
    constructor Create(aCapacity: SizeUInt = 0);
    constructor CreateWith(aCapacity: SizeUInt; const aAllocator: TMemAllocator);
    destructor Destroy; override;

    function TryGetValue(AKey: Int32; out AValue: V): Boolean;
    function ContainsKey(AKey: Int32): Boolean;
    procedure Put(AKey: Int32; const AValue: V);
    function Get(AKey: Int32): V;
    function Remove(AKey: Int32): Boolean;
    procedure Clear;

    property Count: SizeUInt read FCount;
    property Capacity: SizeUInt read FCapacity;
  end;

implementation

function InlineHash32(x: UInt32): UInt32;
begin
  x := (x xor (x shr 16)) * UInt32($7feb352d);
  x := (x xor (x shr 15)) * UInt32($846ca68b);
  Result := x xor (x shr 16);
end;

{ TSwissTableI32<V> }

procedure TSwissTableI32.SetCtrl(AIndex: SizeUInt; AValue: Byte);
begin
  FCtrl[AIndex] := AValue;
  if AIndex < GROUP_SIZE then
    FCtrl[FCapacity + AIndex] := AValue;
end;

procedure TSwissTableI32.AllocTable(ACapacity: SizeUInt);
var
  LCtrlSize, LSlotSize: SizeUInt;
begin
  FCapacity := ACapacity;
  FGroupCount := ACapacity div GROUP_SIZE;
  LCtrlSize := ACapacity + GROUP_SIZE;
  LSlotSize := ACapacity * SizeOf(TSlot);
  FCtrl := nil;
  FSlots := nil;
  if FAllocator = nil then
    FAllocator := DefaultAllocator;
  FCtrl := FAllocator.GetMem(LCtrlSize);
  if FCtrl = nil then
    raise nextpas.core.mem.error.EOutOfMemory.CreateMsg('TSwissTableI32.AllocTable: ctrl allocation failed');
  FSlots := FAllocator.GetMem(LSlotSize);
  if FSlots = nil then
  begin
    FreeMemOf(FAllocator, FCtrl, LCtrlSize);
    FCtrl := nil;
    raise nextpas.core.mem.error.EOutOfMemory.CreateMsg('TSwissTableI32.AllocTable: slots allocation failed');
  end;
  FillChar(FCtrl^, LCtrlSize, CTRL_EMPTY); // non-zero fill: keep FillChar (CTRL_EMPTY=$FF, not zero) — BytesZero single source only for zero
  BytesZero(FSlots, LSlotSize); // perf: inline FillChar via bytes.ops BytesZero single source zero-copy
  FGrowthLeft := ACapacity - ACapacity div 8;
end;

procedure TSwissTableI32.FreeTable;
var i: SizeUInt;
begin
  if FCtrl = nil then Exit;
  if System.IsManagedType(V) then
    for i := 0 to FCapacity - 1 do
      if FCtrl[i] < $80 then
        Finalize(FSlots[i].Value);
  if FAllocator = nil then
    FAllocator := DefaultAllocator;
  FreeMemOf(FAllocator, FSlots, FCapacity * SizeOf(TSlot));
  FreeMemOf(FAllocator, FCtrl, FCapacity + GROUP_SIZE);
  FCtrl := nil;
  FSlots := nil;
end;

procedure TSwissTableI32.GrowAndRehash;
var
  LOldCtrl: PByte;
  LOldSlots: PSlot;
  LOldCap, i: SizeUInt;
  LNewCap: SizeUInt;
  Lh: UInt32;
  Lh2: Byte;
  LGroupIdx, LProbeOfs: SizeUInt;
  LMask: TMask16;
  LIdx: SizeUInt;
begin
  LOldCtrl := FCtrl;
  LOldSlots := FSlots;
  LOldCap := FCapacity;
  if FCapacity = 0 then LNewCap := 16 else LNewCap := FCapacity * 2;
  AllocTable(LNewCap);
  FCount := 0;
  if LOldCtrl <> nil then
  begin
    for i := 0 to LOldCap - 1 do
    begin
      if LOldCtrl[i] < $80 then
      begin
        Lh := InlineHash32(UInt32(LOldSlots[i].Key));
        Lh2 := Lh and $7F;
        LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
        LProbeOfs := 0;
        while True do
        begin
          LMask := Vec16CmpGtU(@FCtrl[LGroupIdx * GROUP_SIZE], $7F);
          if LMask <> 0 then
          begin
            LIdx := LGroupIdx * GROUP_SIZE + SizeUInt(Vec16Ctz(LMask));
            SetCtrl(LIdx, Lh2);
            BytesCopy(@FSlots[LIdx], @LOldSlots[i], SizeOf(TSlot)); // perf: inline single Move via bytes.ops BytesCopy single source zero-copy
            Inc(FCount);
            Dec(FGrowthLeft);
            Break;
          end;
          Inc(LProbeOfs);
          LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
        end;
      end;
    end;
    if FAllocator = nil then
      FAllocator := DefaultAllocator;
    FreeMemOf(FAllocator, LOldSlots, LOldCap * SizeOf(TSlot));
    FreeMemOf(FAllocator, LOldCtrl, LOldCap + GROUP_SIZE);
  end;
end;

constructor TSwissTableI32.Create(aCapacity: SizeUInt);
begin
  inherited Create;
  FCtrl := nil; FSlots := nil; FAllocator := DefaultAllocator;
  FCapacity := 0; FGroupCount := 0; FCount := 0; FGrowthLeft := 0;
  if aCapacity > 0 then
  begin
    if aCapacity < 16 then aCapacity := 16;
    aCapacity := aCapacity + aCapacity div 7 + 1;
    aCapacity := aCapacity or (aCapacity shr 1);
    aCapacity := aCapacity or (aCapacity shr 2);
    aCapacity := aCapacity or (aCapacity shr 4);
    aCapacity := aCapacity or (aCapacity shr 8);
    aCapacity := aCapacity or (aCapacity shr 16);
    Inc(aCapacity);
    AllocTable(aCapacity);
  end;
end;

constructor TSwissTableI32.CreateWith(aCapacity: SizeUInt; const aAllocator: TMemAllocator);
begin
  inherited Create;
  FCtrl := nil; FSlots := nil;
  if aAllocator <> nil then
    FAllocator := aAllocator
  else
    FAllocator := DefaultAllocator;
  FCapacity := 0; FGroupCount := 0; FCount := 0; FGrowthLeft := 0;
  if aCapacity > 0 then
  begin
    if aCapacity < 16 then aCapacity := 16;
    aCapacity := aCapacity + aCapacity div 7 + 1;
    aCapacity := aCapacity or (aCapacity shr 1);
    aCapacity := aCapacity or (aCapacity shr 2);
    aCapacity := aCapacity or (aCapacity shr 4);
    aCapacity := aCapacity or (aCapacity shr 8);
    aCapacity := aCapacity or (aCapacity shr 16);
    Inc(aCapacity);
    AllocTable(aCapacity);
  end;
end;

destructor TSwissTableI32.Destroy;
begin
  FreeTable;
  inherited Destroy;
end;

function TSwissTableI32.TryGetValue(AKey: Int32; out AValue: V): Boolean;
var
  Lh: UInt32;
  Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase: SizeUInt;
  LMask, LEmptyMask: TMask16;
begin
  if FCapacity = 0 then Exit(False);
  Lh := InlineHash32(UInt32(AKey));
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := Vec16CmpEq(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      Li := LBase + SizeUInt(Vec16Ctz(LMask));
      if FSlots[Li].Key = AKey then
      begin AValue := FSlots[Li].Value; Exit(True); end;
      LMask := LMask and (LMask - 1);
    end;
    LEmptyMask := Vec16CmpEq(@FCtrl[LBase], CTRL_EMPTY);
    if LEmptyMask <> 0 then Exit(False);
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

function TSwissTableI32.ContainsKey(AKey: Int32): Boolean;
var LDummy: V;
begin
  Result := TryGetValue(AKey, LDummy);
end;

procedure TSwissTableI32.Put(AKey: Int32; const AValue: V);
var
  Lh: UInt32;
  Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase, LInsertIdx: SizeUInt;
  LMask, LFreeMask, LEmptyMask, LDeletedMask: TMask16;
  LInsertWasEmpty: Boolean;
  LFoundInsert: Boolean;
begin
  if FCapacity = 0 then GrowAndRehash;
  Lh := InlineHash32(UInt32(AKey));
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  LInsertIdx := 0;
  LFoundInsert := False;
  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := Vec16CmpEq(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      Li := LBase + SizeUInt(Vec16Ctz(LMask));
      if FSlots[Li].Key = AKey then
      begin
        FSlots[Li].Value := AValue;
        Exit;
      end;
      LMask := LMask and (LMask - 1);
    end;
    LFreeMask := Vec16CmpGtU(@FCtrl[LBase], $7F);
    LEmptyMask := Vec16CmpEq(@FCtrl[LBase], CTRL_EMPTY);
    if LFreeMask <> 0 then
    begin
      LDeletedMask := LFreeMask and not LEmptyMask;
      if (LDeletedMask <> 0) and (not LFoundInsert) then
      begin
        LInsertIdx := LBase + SizeUInt(Vec16Ctz(LDeletedMask));
        LFoundInsert := True;
      end;
      if LEmptyMask <> 0 then
      begin
        if not LFoundInsert then
          LInsertIdx := LBase + SizeUInt(Vec16Ctz(LEmptyMask));
        Break;
      end;
    end;
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;

  LInsertWasEmpty := FCtrl[LInsertIdx] = CTRL_EMPTY;
  if LInsertWasEmpty and (FGrowthLeft = 0) then
  begin
    GrowAndRehash;
    Put(AKey, AValue);
    Exit;
  end;

  SetCtrl(LInsertIdx, Lh2);
  FSlots[LInsertIdx].Key := AKey;
  FSlots[LInsertIdx].Value := AValue;
  Inc(FCount);
  if LInsertWasEmpty then
    Dec(FGrowthLeft);
end;

function TSwissTableI32.Get(AKey: Int32): V;
begin
  if not TryGetValue(AKey, Result) then
    raise EInvalidOperation.Create('TSwissTableI32.Get: key not found');
end;

function TSwissTableI32.Remove(AKey: Int32): Boolean;
var
  Lh: UInt32;
  Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase: SizeUInt;
  LMask, LEmptyMask: TMask16;
begin
  if FCapacity = 0 then Exit(False);
  Lh := InlineHash32(UInt32(AKey));
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    LMask := Vec16CmpEq(@FCtrl[LBase], Lh2);
    while LMask <> 0 do
    begin
      Li := LBase + SizeUInt(Vec16Ctz(LMask));
      if FSlots[Li].Key = AKey then
      begin
        if System.IsManagedType(V) then Finalize(FSlots[Li].Value);
        BytesZero(@FSlots[Li], SizeOf(TSlot)); // perf: inline FillChar via bytes.ops BytesZero single source zero-copy
        SetCtrl(Li, CTRL_DELETED);
        Dec(FCount);
        Exit(True);
      end;
      LMask := LMask and (LMask - 1);
    end;
    LEmptyMask := Vec16CmpEq(@FCtrl[LBase], CTRL_EMPTY);
    if LEmptyMask <> 0 then Exit(False);
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

procedure TSwissTableI32.Clear;
begin
  FreeTable;
  FCount := 0; FCapacity := 0; FGroupCount := 0; FGrowthLeft := 0;
end;

end.
