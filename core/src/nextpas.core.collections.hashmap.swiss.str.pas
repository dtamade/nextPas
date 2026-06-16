unit nextpas.core.collections.hashmap.swiss.str;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.errors,
  nextpas.core.simd.base,
  nextpas.core.simd.vec16;

const
  CTRL_EMPTY   = Byte($FF);
  CTRL_DELETED = Byte($80);
  GROUP_SIZE   = 16;

type
  generic TSwissTableStr<V> = class
  public type
    PSlot = ^TSlot;
    TSlot = record
      Key: string;
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
    function FindInsertSlot(AHash: UInt32; out AWasEmpty: Boolean): SizeUInt;
    class function HashStr(const S: string): UInt32; static; inline;

  public
    constructor Create(aCapacity: SizeUInt = 0);
    constructor CreateWith(aCapacity: SizeUInt; const aAllocator: IAllocator);
    destructor Destroy; override;

    function TryGetValue(const AKey: string; out AValue: V): Boolean;
    function ContainsKey(const AKey: string): Boolean;
    procedure Put(const AKey: string; const AValue: V);
    function Get(const AKey: string): V;
    function Remove(const AKey: string): Boolean;
    procedure Clear;

    property Count: SizeUInt read FCount;
    property Capacity: SizeUInt read FCapacity;
  end;

implementation

class function TSwissTableStr.HashStr(const S: string): UInt32;
var
  i: Integer;
begin
  Result := 2166136261;
  for i := 1 to Length(S) do
    Result := (Result xor Ord(S[i])) * 16777619;
  Result := (Result xor (Result shr 16)) * UInt32($7feb352d);
  Result := (Result xor (Result shr 15)) * UInt32($846ca68b);
  Result := Result xor (Result shr 16);
end;

procedure TSwissTableStr.SetCtrl(AIndex: SizeUInt; AValue: Byte);
begin
  FCtrl[AIndex] := AValue;
  if AIndex < GROUP_SIZE then
    FCtrl[FCapacity + AIndex] := AValue;
end;

procedure TSwissTableStr.AllocTable(ACapacity: SizeUInt);
begin
  FCapacity := ACapacity;
  FGroupCount := ACapacity div GROUP_SIZE;
  FCtrl := nil;
  FSlots := nil;
  if FAllocator <> nil then
  begin
    FCtrl := FAllocator.GetMem(ACapacity + GROUP_SIZE);
    FSlots := FAllocator.GetMem(ACapacity * SizeOf(TSlot));
  end
  else
  begin
    GetMem(FCtrl, ACapacity + GROUP_SIZE);
    try
      GetMem(FSlots, ACapacity * SizeOf(TSlot));
    except
      FreeMem(FCtrl);
      FCtrl := nil;
      raise;
    end;
  end;
  FillChar(FCtrl^, ACapacity + GROUP_SIZE, CTRL_EMPTY);
  FillChar(FSlots^, ACapacity * SizeOf(TSlot), 0);
  FGrowthLeft := ACapacity - ACapacity div 8;
end;

procedure TSwissTableStr.FreeTable;
var i: SizeUInt;
begin
  if FCtrl = nil then Exit;
  for i := 0 to FCapacity - 1 do
    if FCtrl[i] < $80 then
    begin
      Finalize(FSlots[i].Key);
      if System.IsManagedType(V) then
        Finalize(FSlots[i].Value);
    end;
  if FAllocator <> nil then FAllocator.FreeMem(FSlots) else FreeMem(FSlots);
  if FAllocator <> nil then FAllocator.FreeMem(FCtrl) else FreeMem(FCtrl);
  FCtrl := nil; FSlots := nil;
end;

function TSwissTableStr.FindInsertSlot(AHash: UInt32; out AWasEmpty: Boolean): SizeUInt;
var
  LGroupIdx, LProbeOfs: SizeUInt;
  LFreeMask, LEmptyMask: TMask16;
  LBit: Integer;
begin
  LGroupIdx := (AHash shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  while True do
  begin
    LEmptyMask := Vec16CmpEq(@FCtrl[LGroupIdx * GROUP_SIZE], CTRL_EMPTY);
    LFreeMask := LEmptyMask or Vec16CmpEq(@FCtrl[LGroupIdx * GROUP_SIZE], CTRL_DELETED);
    if LFreeMask <> 0 then
    begin
      LBit := Vec16Ctz(LFreeMask);
      AWasEmpty := (LEmptyMask and (TMask16(1) shl LBit)) <> 0;
      Result := LGroupIdx * GROUP_SIZE + SizeUInt(LBit);
      Exit;
    end;
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

procedure TSwissTableStr.GrowAndRehash;
var
  LOldCtrl: PByte; LOldSlots: PSlot;
  LOldCap, i, LIdx: SizeUInt;
  LNewCap: SizeUInt;
  Lh: UInt32;
  LWasEmpty: Boolean;
begin
  LOldCtrl := FCtrl; LOldSlots := FSlots; LOldCap := FCapacity;
  if FCapacity = 0 then LNewCap := 16 else LNewCap := FCapacity * 2;
  AllocTable(LNewCap);
  FCount := 0;
  if LOldCtrl <> nil then
  begin
    for i := 0 to LOldCap - 1 do
      if LOldCtrl[i] < $80 then
      begin
        Lh := HashStr(LOldSlots[i].Key);
        LIdx := FindInsertSlot(Lh, LWasEmpty);
        SetCtrl(LIdx, Lh and $7F);
        Move(LOldSlots[i], FSlots[LIdx], SizeOf(TSlot));
        Inc(FCount);
        if LWasEmpty then
          Dec(FGrowthLeft);
      end;
    if FAllocator <> nil then FAllocator.FreeMem(LOldSlots) else FreeMem(LOldSlots); if FAllocator <> nil then FAllocator.FreeMem(LOldCtrl) else FreeMem(LOldCtrl);
  end;
end;

constructor TSwissTableStr.Create(aCapacity: SizeUInt);
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

constructor TSwissTableStr.CreateWith(aCapacity: SizeUInt; const aAllocator: IAllocator);
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

destructor TSwissTableStr.Destroy;
begin
  FreeTable;
  inherited Destroy;
end;

function TSwissTableStr.TryGetValue(const AKey: string; out AValue: V): Boolean;
var
  Lh: UInt32; Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase: SizeUInt;
  LMask, LEmptyMask: TMask16;
begin
  if FCapacity = 0 then Exit(False);
  Lh := HashStr(AKey);
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

function TSwissTableStr.ContainsKey(const AKey: string): Boolean;
var LDummy: V;
begin
  Result := TryGetValue(AKey, LDummy);
end;

procedure TSwissTableStr.Put(const AKey: string; const AValue: V);
var
  Lh: UInt32; Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase, LInsertIdx: SizeUInt;
  LMask, LFreeMask, LEmptyMask: TMask16;
  LFoundInsert, LInsertWasEmpty: Boolean;
begin
  if FCapacity = 0 then GrowAndRehash;
  Lh := HashStr(AKey);
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  LFoundInsert := False;
  LInsertIdx := 0;
  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    Vec16ProbeGroup(@FCtrl[LBase], Lh2, LMask, LEmptyMask);
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

    LFreeMask := LEmptyMask or Vec16CmpEq(@FCtrl[LBase], CTRL_DELETED);
    if LFreeMask <> 0 then
    begin
      if LEmptyMask <> 0 then
      begin
        if not LFoundInsert then
          LInsertIdx := LBase + SizeUInt(Vec16Ctz(LEmptyMask));
        Break;
      end;
      if not LFoundInsert then
      begin
        LInsertIdx := LBase + SizeUInt(Vec16Ctz(LFreeMask));
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

function TSwissTableStr.Get(const AKey: string): V;
begin
  if not TryGetValue(AKey, Result) then
    raise Exception.Create('TSwissTableStr.Get: key not found');
end;

function TSwissTableStr.Remove(const AKey: string): Boolean;
var
  Lh: UInt32; Lh2: Byte;
  LGroupIdx, LProbeOfs, Li, LBase: SizeUInt;
  LMask, LEmptyMask: TMask16;
begin
  if FCapacity = 0 then Exit(False);
  Lh := HashStr(AKey);
  Lh2 := Lh and $7F;
  LGroupIdx := (Lh shr 7) and (FGroupCount - 1);
  LProbeOfs := 0;
  while True do
  begin
    LBase := LGroupIdx * GROUP_SIZE;
    Vec16ProbeGroup(@FCtrl[LBase], Lh2, LMask, LEmptyMask);
    while LMask <> 0 do
    begin
      Li := LBase + SizeUInt(Vec16Ctz(LMask));
      if FSlots[Li].Key = AKey then
      begin
        Finalize(FSlots[Li].Key);
        if System.IsManagedType(V) then Finalize(FSlots[Li].Value);
        FillChar(FSlots[Li], SizeOf(TSlot), 0);
        if LEmptyMask <> 0 then
        begin
          SetCtrl(Li, CTRL_EMPTY);
          Inc(FGrowthLeft);
        end
        else
          SetCtrl(Li, CTRL_DELETED);
        Dec(FCount); Exit(True);
      end;
      LMask := LMask and (LMask - 1);
    end;
    if LEmptyMask <> 0 then Exit(False);
    Inc(LProbeOfs);
    LGroupIdx := (LGroupIdx + LProbeOfs) and (FGroupCount - 1);
  end;
end;

procedure TSwissTableStr.Clear;
begin
  FreeTable;
  FCount := 0; FCapacity := 0; FGroupCount := 0; FGrowthLeft := 0;
end;

end.
