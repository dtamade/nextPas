unit nextpas.core.collections.hashmap.swiss.adapter;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.mem.intf,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.hashmap.base,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashmap.swiss,
  nextpas.core.mem.allocator.base;

type
  generic TSwissHashMap<K, V> = class(specialize TGenericCollection<specialize TMapEntry<K, V>>, specialize IHashMap<K, V>)
  public type
    TEntry = specialize TMapEntry<K, V>;
    THash = specialize TKeyHashFunc<K>;
    TEquals = specialize TKeyEqualsFunc<K>;
    TValueSupplier = specialize TValueSupplierFunc<V>;
    TValueModifier = specialize TValueModifierProc<V>;
    TRetainPredicate = specialize TPredicateFunc<TEntry>;
    TKeyArray = array of K;
  private type
    TInner = specialize TSwissTable<K, V>;
  private
    FInner: TInner;
    FIterEntry: TEntry;
    function DoIterGetCurrent(aIter: PPtrIter): Pointer;
    function DoIterMoveNext(aIter: PPtrIter): Boolean;
  protected
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure DoZero(); override;
    procedure DoReverse; override;
  public
    constructor Create(aCapacity: SizeUInt = 0; aHash: THash = nil;
      aEquals: TEquals = nil; aAllocator: TMemAllocator = nil);
    destructor Destroy; override;

    function GetCount: SizeUInt; override;
    function PtrIter: TPtrIter; override;
    procedure Clear; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnchecked(const aDst: TCollection); override;

    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    function Add(const AKey: K; const AValue: V): Boolean;
    function AddOrAssign(const AKey: K; const AValue: V): Boolean;
    function Remove(const AKey: K): Boolean;
    function GetCapacity: SizeUInt;
    function GetLoadFactor: Single;
    procedure Reserve(aCapacity: SizeUInt);
    procedure Put(const AKey: K; const AValue: V);
    function Get(const AKey: K): V;
    function GetOrInsert(const AKey: K; const ADefault: V): V;
    function GetOrInsertWith(const AKey: K; ASupplier: TValueSupplier): V;
    procedure ModifyOrInsert(const AKey: K; AModifier: TValueModifier; const ADefault: V);
    procedure Retain(aPredicate: TRetainPredicate; aData: Pointer);
    { Keys snapshot (order unspecified); mirrors OA THashMap.GetKeys. }
    function GetKeys: TKeyArray;
  end;

implementation

{ TSwissHashMap }

constructor TSwissHashMap.Create(aCapacity: SizeUInt; aHash: THash;
  aEquals: TEquals; aAllocator: TMemAllocator);
begin
  inherited Create(aAllocator);
  FInner := TInner.Create(aCapacity, aHash, aEquals, aAllocator);
end;

destructor TSwissHashMap.Destroy;
begin
  FInner.Free;
  inherited Destroy;
end;

function TSwissHashMap.GetCount: SizeUInt;
begin
  Result := FInner.Count;
end;

function TSwissHashMap.DoIterGetCurrent(aIter: PPtrIter): Pointer;
begin
  Result := @FIterEntry;
end;

function TSwissHashMap.DoIterMoveNext(aIter: PPtrIter): Boolean;
var LIdx: SizeUInt;
begin
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    LIdx := 0;
  end
  else
  begin
    {$PUSH}{$WARN 4055 OFF}
    LIdx := SizeUInt(aIter^.Data) + 1;
    {$POP}
  end;

  while LIdx < FInner.Capacity do
  begin
    if FInner.GetCtrlByte(LIdx) < $80 then
    begin
      FIterEntry.Key := FInner.GetSlotKey(LIdx);
      FInner.TryGetValue(FIterEntry.Key, FIterEntry.Value);
      {$PUSH}{$WARN 4055 OFF}
      aIter^.Data := Pointer(LIdx);
      {$POP}
      Exit(True);
    end;
    Inc(LIdx);
  end;
  Result := False;
end;

function TSwissHashMap.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, Pointer(0));
end;

function TSwissHashMap.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  { Swiss map does not expose contiguous element storage. }
  Result := False;
end;

procedure TSwissHashMap.DoZero();
var
  i: SizeUInt;
  LKey: K;
  LDefault: V;
begin
  { Align with OA THashMap: zero values of occupied slots without removing keys. }
  if FInner.Capacity = 0 then
    Exit;
  FillChar(LDefault, SizeOf(V), 0);
  for i := 0 to FInner.Capacity - 1 do
    if FInner.GetCtrlByte(i) < $80 then
    begin
      LKey := FInner.GetSlotKey(i);
      FInner.Put(LKey, LDefault);
    end;
end;

procedure TSwissHashMap.DoReverse;
begin
  { Hash maps have no fixed order; reverse is a no-op. }
end;

procedure TSwissHashMap.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  i, LCnt: SizeUInt;
  PEntry: ^TEntry;
  LEntry: TEntry;
begin
  if (aDst = nil) or (aCount = 0) or (FInner.Count = 0) then
    Exit;
  PEntry := aDst;
  LCnt := 0;
  for i := 0 to FInner.Capacity - 1 do
  begin
    if FInner.GetCtrlByte(i) < $80 then
    begin
      if LCnt >= aCount then
        Break;
      LEntry.Key := FInner.GetSlotKey(i);
      FInner.TryGetValue(LEntry.Key, LEntry.Value);
      PEntry^ := LEntry;
      Inc(PEntry);
      Inc(LCnt);
    end;
  end;
end;

procedure TSwissHashMap.AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  i: SizeUInt;
  PEntry: ^TEntry;
begin
  if (aSrc = nil) or (aElementCount = 0) then
    Exit;
  PEntry := aSrc;
  for i := 0 to aElementCount - 1 do
  begin
    AddOrAssign(PEntry^.Key, PEntry^.Value);
    Inc(PEntry);
  end;
end;

procedure TSwissHashMap.AppendToUnchecked(const aDst: TCollection);
var
  i: SizeUInt;
  LDst: specialize TSwissHashMap<K, V>;
  LKey: K;
  LVal: V;
begin
  if aDst = nil then
    Exit;
  if aDst is specialize TSwissHashMap<K, V> then
  begin
    LDst := specialize TSwissHashMap<K, V>(aDst);
    for i := 0 to FInner.Capacity - 1 do
      if FInner.GetCtrlByte(i) < $80 then
      begin
        LKey := FInner.GetSlotKey(i);
        FInner.TryGetValue(LKey, LVal);
        LDst.AddOrAssign(LKey, LVal);
      end;
  end
  else
    raise EInvalidOperation.Create(
      'TSwissHashMap.AppendToUnchecked: cannot append to incompatible container type');
end;

function TSwissHashMap.TryGetValue(const AKey: K; out AValue: V): Boolean;
begin
  Result := FInner.TryGetValue(AKey, AValue);
end;

function TSwissHashMap.ContainsKey(const AKey: K): Boolean;
begin
  Result := FInner.ContainsKey(AKey);
end;

function TSwissHashMap.Add(const AKey: K; const AValue: V): Boolean;
begin
  if FInner.ContainsKey(AKey) then Exit(False);
  FInner.Put(AKey, AValue);
  Result := True;
end;

function TSwissHashMap.AddOrAssign(const AKey: K; const AValue: V): Boolean;
begin
  Result := FInner.AddOrAssign(AKey, AValue);
end;

function TSwissHashMap.Remove(const AKey: K): Boolean;
begin
  Result := FInner.Remove(AKey);
end;

function TSwissHashMap.GetCapacity: SizeUInt;
begin
  Result := FInner.Capacity;
end;

function TSwissHashMap.GetLoadFactor: Single;
begin
  if FInner.Capacity = 0 then Exit(0.0);
  Result := FInner.Count / FInner.Capacity;
end;

procedure TSwissHashMap.Reserve(aCapacity: SizeUInt);
begin
  FInner.Reserve(aCapacity);
end;

procedure TSwissHashMap.Put(const AKey: K; const AValue: V);
begin
  FInner.Put(AKey, AValue);
end;

function TSwissHashMap.Get(const AKey: K): V;
begin
  Result := FInner.Get(AKey);
end;

function TSwissHashMap.GetOrInsert(const AKey: K; const ADefault: V): V;
begin
  if not FInner.TryGetValue(AKey, Result) then
  begin
    FInner.Put(AKey, ADefault);
    Result := ADefault;
  end;
end;

function TSwissHashMap.GetOrInsertWith(const AKey: K; ASupplier: TValueSupplier): V;
begin
  if not FInner.TryGetValue(AKey, Result) then
  begin
    Result := ASupplier();
    FInner.Put(AKey, Result);
  end;
end;

procedure TSwissHashMap.ModifyOrInsert(const AKey: K; AModifier: TValueModifier;
  const ADefault: V);
var LVal: V;
begin
  if FInner.TryGetValue(AKey, LVal) then
  begin
    AModifier(LVal);
    FInner.Put(AKey, LVal);
  end
  else
    FInner.Put(AKey, ADefault);
end;

procedure TSwissHashMap.Retain(aPredicate: TRetainPredicate; aData: Pointer);
var
  i: SizeUInt;
  LEntry: TEntry;
begin
  if FInner.Capacity = 0 then Exit;
  for i := 0 to FInner.Capacity - 1 do
    if FInner.GetCtrlByte(i) < $80 then
    begin
      LEntry.Key := FInner.GetSlotKey(i);
      FInner.TryGetValue(LEntry.Key, LEntry.Value);
      if not aPredicate(LEntry, aData) then
        FInner.Remove(LEntry.Key);
    end;
end;

procedure TSwissHashMap.Clear;
begin
  FIterEntry := Default(TEntry);
  FInner.Clear;
end;

function TSwissHashMap.GetKeys: TKeyArray;
begin
  Result := FInner.GetKeys;
end;

end.
