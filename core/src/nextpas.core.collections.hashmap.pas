unit nextpas.core.collections.hashmap;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

const
  HASHMAP_INITIAL_CAPACITY = 8;
  HASHMAP_LOAD_FACTOR_NUM  = 3;
  HASHMAP_LOAD_FACTOR_DEN  = 4;

type
  generic THashMap<TKey, TValue> = record
  private
  type
    TEntryState = (esEmpty, esOccupied, esTombstone);
    TEntry = record
      Key: TKey;
      Value: TValue;
      State: TEntryState;
    end;
  private
    FEntries: array of TEntry;
    FCount: SizeUInt;
    FCapacity: SizeUInt;
    function HashKey(const AKey: TKey): UInt32;
    function FindSlot(const AKey: TKey; out AIndex: SizeUInt): Boolean;
    procedure Rehash(const ANewCapacity: SizeUInt);
  public
    procedure Init;
    procedure Done;
    procedure Clear;
    procedure Put(const AKey: TKey; const AValue: TValue);
    function Get(const AKey: TKey; out AValue: TValue): Boolean;
    function Contains(const AKey: TKey): Boolean;
    function Remove(const AKey: TKey): Boolean;
    function GetCount: SizeUInt; inline;
    function IsEmpty: Boolean; inline;
    property Count: SizeUInt read GetCount;
  end;

implementation

{ THashMap<TKey, TValue> - Hash function }

function THashMap.HashKey(const AKey: TKey): UInt32;
var
  LData: PByte;
  LSize: SizeUInt;
  LIdx: SizeUInt;
  LHash: UInt32;
begin
  LHash := 2166136261;
  if GetTypeKind(TKey) = tkAString then
  begin
    LData := PByte(PPointer(@AKey)^);
    LSize := Length(string(PPointer(@AKey)^));
    for LIdx := 0 to LSize - 1 do
    begin
      LHash := LHash xor UInt32(LData[LIdx]);
      LHash := LHash * 16777619;
    end;
  end
  else
  begin
    LData := @AKey;
    LSize := SizeOf(TKey);
    for LIdx := 0 to LSize - 1 do
    begin
      LHash := LHash xor UInt32(LData[LIdx]);
      LHash := LHash * 16777619;
    end;
  end;
  Result := LHash;
end;

{ THashMap<TKey, TValue> - Slot lookup }

function THashMap.FindSlot(const AKey: TKey; out AIndex: SizeUInt): Boolean;
var
  LHash: UInt32;
  LIdx, LFirstTombstone: SizeUInt;
  LFoundTombstone: Boolean;
begin
  Result := False;
  if FCapacity = 0 then
  begin
    AIndex := 0;
    Exit;
  end;
  LHash := HashKey(AKey);
  LIdx := LHash and (FCapacity - 1);
  LFoundTombstone := False;
  LFirstTombstone := 0;
  while True do
  begin
    case FEntries[LIdx].State of
      esEmpty:
      begin
        if LFoundTombstone then
          AIndex := LFirstTombstone
        else
          AIndex := LIdx;
        Exit;
      end;
      esTombstone:
      begin
        if not LFoundTombstone then
        begin
          LFoundTombstone := True;
          LFirstTombstone := LIdx;
        end;
      end;
      esOccupied:
      begin
        if FEntries[LIdx].Key = AKey then
        begin
          AIndex := LIdx;
          Result := True;
          Exit;
        end;
      end;
    end;
    LIdx := (LIdx + 1) and (FCapacity - 1);
  end;
end;

{ THashMap<TKey, TValue> - Rehash }

procedure THashMap.Rehash(const ANewCapacity: SizeUInt);
var
  LOldEntries: array of TEntry;
  LIdx, LNewIdx, LOldLen: SizeUInt;
  LHash: UInt32;
begin
  LOldEntries := FEntries;
  LOldLen := Length(LOldEntries);
  FCapacity := ANewCapacity;
  FEntries := nil;
  SetLength(FEntries, FCapacity);
  for LIdx := 0 to FCapacity - 1 do
    FEntries[LIdx].State := esEmpty;
  FCount := 0;
  if LOldLen > 0 then
    for LIdx := 0 to LOldLen - 1 do
    begin
      if LOldEntries[LIdx].State = esOccupied then
      begin
        LHash := HashKey(LOldEntries[LIdx].Key);
        LNewIdx := LHash and (FCapacity - 1);
        while FEntries[LNewIdx].State = esOccupied do
          LNewIdx := (LNewIdx + 1) and (FCapacity - 1);
        FEntries[LNewIdx].Key := LOldEntries[LIdx].Key;
        FEntries[LNewIdx].Value := LOldEntries[LIdx].Value;
        FEntries[LNewIdx].State := esOccupied;
        Inc(FCount);
      end;
    end;
end;

{ THashMap<TKey, TValue> - Public API }

procedure THashMap.Init;
begin
  FEntries := nil;
  FCount := 0;
  FCapacity := 0;
end;

procedure THashMap.Done;
begin
  FEntries := nil;
  FCount := 0;
  FCapacity := 0;
end;

procedure THashMap.Clear;
var
  LIdx: SizeUInt;
begin
  if FCapacity > 0 then
    for LIdx := 0 to FCapacity - 1 do
      FEntries[LIdx].State := esEmpty;
  FCount := 0;
end;

procedure THashMap.Put(const AKey: TKey; const AValue: TValue);
var
  LIdx: SizeUInt;
begin
  if FCapacity = 0 then
    Rehash(HASHMAP_INITIAL_CAPACITY)
  else if (FCount + 1) * HASHMAP_LOAD_FACTOR_DEN > FCapacity * HASHMAP_LOAD_FACTOR_NUM then
    Rehash(FCapacity * 2);
  if FindSlot(AKey, LIdx) then
  begin
    FEntries[LIdx].Value := AValue;
  end
  else
  begin
    FEntries[LIdx].Key := AKey;
    FEntries[LIdx].Value := AValue;
    FEntries[LIdx].State := esOccupied;
    Inc(FCount);
  end;
end;

function THashMap.Get(const AKey: TKey; out AValue: TValue): Boolean;
var
  LIdx: SizeUInt;
begin
  Result := FindSlot(AKey, LIdx);
  if Result then
    AValue := FEntries[LIdx].Value;
end;

function THashMap.Contains(const AKey: TKey): Boolean;
var
  LIdx: SizeUInt;
begin
  Result := FindSlot(AKey, LIdx);
end;

function THashMap.Remove(const AKey: TKey): Boolean;
var
  LIdx: SizeUInt;
begin
  Result := FindSlot(AKey, LIdx);
  if Result then
  begin
    FEntries[LIdx].State := esTombstone;
    Dec(FCount);
  end;
end;

function THashMap.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function THashMap.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

end.
