unit nextpas.core.collections.hashmap.swiss.i32;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.mem.intf,
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
    FAllocator: IAllocator;

    procedure AllocTable(ACapacity: SizeUInt);
    procedure FreeTable;
    procedure GrowAndRehash;
    procedure SetCtrl(AIndex: SizeUInt; AValue: Byte); inline;

  public
    constructor Create(aCapacity: SizeUInt = 0);
    constructor CreateWith(aCapacity: SizeUInt; const aAllocator: IAllocator);
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
begin
  FCapacity := ACapacity;
  FGroupCount := ACapacity div GROUP_SIZE;
  if FAllocator <> nil then
  begin
    FCtrl := FAllocator.Allocate(ACapacity + GROUP_SIZE);
    FSlots := FAllocator.Allocate(ACapacity * SizeOf(TSlot));
  end
  else
  begin
    GetMem(FCtrl, ACapacity + GROUP_SIZE);
    GetMem(FSlots, ACapacity * SizeOf(TSlot));
  end;
  FillChar(FCtrl^, ACapacity + GROUP_SIZE, CTRL_EMPTY);
  FillChar(FSlots^, ACapacity * SizeOf(TSlot), 0);
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
  if FAllocator <> nil then
  begin
    FAllocator.Deallocate(FSlots);
    FAllocator.Deallocate(FCtrl);
  end
  else
  begin
    FreeMem(FSlots);
    FreeMem(FCtrl);
  end;
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
            Move(LOldSlots[i], FSlots[LIdx], SizeOf(TSlot));
            Inc(FCount);
            Dec(FGrowthLeft);
            Break;
          end;
          Inc(LProbeOfs);
          LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
        end;
      end;
    end;
    if FAllocator <> nil then
    begin
      FAllocator.Deallocate(LOldSlots);
      FAllocator.Deallocate(LOldCtrl);
    end
    else
    begin
      FreeMem(LOldSlots);
      FreeMem(LOldCtrl);
    end;
  end;
end;

constructor TSwissTableI32.Create(aCapacity: SizeUInt);
begin
  inherited Create;
  FCtrl := nil; FSlots := nil; FAllocator := nil;
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

constructor TSwissTableI32.CreateWith(aCapacity: SizeUInt; const aAllocator: IAllocator);
begin
  inherited Create;
  FCtrl := nil; FSlots := nil; FAllocator := aAllocator;
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
  LMask, LEmptyMask: TMask16;
begin
  if FGrowthLeft = 0 then GrowAndRehash;
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
        FSlots[Li].Value := AValue;
        Exit;
      end;
      LMask := LMask and (LMask - 1);
    end;
    LEmptyMask := Vec16CmpEq(@FCtrl[LBase], CTRL_EMPTY);
    if LEmptyMask <> 0 then
    begin
      LInsertIdx := LBase + SizeUInt(Vec16Ctz(LEmptyMask));
      SetCtrl(LInsertIdx, Lh2);
      FSlots[LInsertIdx].Key := AKey;
      FSlots[LInsertIdx].Value := AValue;
      Inc(FCount);
      Dec(FGrowthLeft);
      Exit;
    end;
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

function TSwissTableI32.Get(AKey: Int32): V;
begin
  if not TryGetValue(AKey, Result) then
    raise Exception.Create('TSwissTableI32.Get: key not found');
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
        FillChar(FSlots[Li], SizeOf(TSlot), 0);
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
