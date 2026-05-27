unit nextpas.core.collections.multiset;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.collections.multiset - 多重集合（Bag）
 *
 * 允许重复元素的集合，每个元素有一个计数
 * 底层基于 HashMap<T, SizeUInt> 实现
 *}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.multiset.base,
  nextpas.core.collections.multiset.intf,
  nextpas.core.collections.hashmap;

type
  {**
   * TMultiSet<T>
   *
   * @desc 多重集合实现
   *}
  generic TMultiSet<T> = class(TInterfacedObject, specialize IMultiSet<T>)
  public type
    TInternalMap = specialize THashMap<T, SizeUInt>;
    TSelf = specialize TMultiSet<T>;
  private
    FMap: TInternalMap;
    FTotalCount: SizeUInt;
  public
    constructor Create;
    constructor Create(aAllocator: IAllocator);
    destructor Destroy; override;

    // IMultiSet<T>
    function Add(const aElement: T): SizeUInt;
    function AddN(const aElement: T; aCount: SizeUInt): SizeUInt;
    function Remove(const aElement: T): Boolean;
    function RemoveAll(const aElement: T): SizeUInt;
    function Contains(const aElement: T): Boolean;
    function CountOf(const aElement: T): SizeUInt;
    procedure SetCount(const aElement: T; aCount: SizeUInt);
    procedure Clear;
    function GetCount: SizeUInt;
    function GetTotalCount: SizeUInt;
    function IsEmpty: Boolean;

    // 集合运算
    function Union(const aOther: TSelf): TSelf;
    function Intersection(const aOther: TSelf): TSelf;
    function Difference(const aOther: TSelf): TSelf;

    property Count: SizeUInt read GetCount;
    property TotalCount: SizeUInt read GetTotalCount;
  end;

implementation

{ TMultiSet<T> }

constructor TMultiSet.Create;
begin
  Create(nil);
end;

constructor TMultiSet.Create(aAllocator: IAllocator);
begin
  inherited Create;
  FMap := TInternalMap.Create(0, nil, nil, aAllocator);
  FTotalCount := 0;
end;

destructor TMultiSet.Destroy;
begin
  FMap.Free;
  inherited Destroy;
end;

function TMultiSet.Add(const aElement: T): SizeUInt;
begin
  Result := AddN(aElement, 1);
end;

function TMultiSet.AddN(const aElement: T; aCount: SizeUInt): SizeUInt;
var
  CurrentCount: SizeUInt;
begin
  if aCount = 0 then
  begin
    if FMap.TryGetValue(aElement, CurrentCount) then
      Exit(CurrentCount)
    else
      Exit(0);
  end;

  if FMap.TryGetValue(aElement, CurrentCount) then
  begin
    Result := CurrentCount + aCount;
    FMap.AddOrAssign(aElement, Result);
  end
  else
  begin
    Result := aCount;
    FMap.Add(aElement, aCount);
  end;

  Inc(FTotalCount, aCount);
end;

function TMultiSet.Remove(const aElement: T): Boolean;
var
  CurrentCount: SizeUInt;
begin
  if not FMap.TryGetValue(aElement, CurrentCount) then
    Exit(False);

  if CurrentCount <= 1 then
    FMap.Remove(aElement)
  else
    FMap.AddOrAssign(aElement, CurrentCount - 1);

  Dec(FTotalCount);
  Result := True;
end;

function TMultiSet.RemoveAll(const aElement: T): SizeUInt;
var
  CurrentCount: SizeUInt;
begin
  if not FMap.TryGetValue(aElement, CurrentCount) then
    Exit(0);

  FMap.Remove(aElement);
  Dec(FTotalCount, CurrentCount);
  Result := CurrentCount;
end;

function TMultiSet.Contains(const aElement: T): Boolean;
begin
  Result := FMap.ContainsKey(aElement);
end;

function TMultiSet.CountOf(const aElement: T): SizeUInt;
begin
  if not FMap.TryGetValue(aElement, Result) then
    Result := 0;
end;

procedure TMultiSet.SetCount(const aElement: T; aCount: SizeUInt);
var
  OldCount: SizeUInt;
begin
  if FMap.TryGetValue(aElement, OldCount) then
  begin
    if aCount = 0 then
    begin
      FMap.Remove(aElement);
      Dec(FTotalCount, OldCount);
    end
    else
    begin
      FMap.AddOrAssign(aElement, aCount);
      FTotalCount := FTotalCount - OldCount + aCount;
    end;
  end
  else if aCount > 0 then
  begin
    FMap.Add(aElement, aCount);
    Inc(FTotalCount, aCount);
  end;
end;

procedure TMultiSet.Clear;
begin
  FMap.Clear;
  FTotalCount := 0;
end;

function TMultiSet.GetCount: SizeUInt;
begin
  Result := FMap.Count;
end;

function TMultiSet.GetTotalCount: SizeUInt;
begin
  Result := FTotalCount;
end;

function TMultiSet.IsEmpty: Boolean;
begin
  Result := FMap.IsEmpty;
end;

function TMultiSet.Union(const aOther: TSelf): TSelf;
var
  Entries, OtherEntries: specialize TGenericArray<TInternalMap.TEntry>;
  i: SizeInt;
  OtherCount: SizeUInt;
begin
  Result := TSelf.Create;

  // Add all from self with max counts
  Entries := FMap.ToArray;
  for i := 0 to High(Entries) do
  begin
    OtherCount := aOther.CountOf(Entries[i].Key);
    if Entries[i].Value >= OtherCount then
      Result.SetCount(Entries[i].Key, Entries[i].Value)
    else
      Result.SetCount(Entries[i].Key, OtherCount);
  end;

  // Add elements only in other
  OtherEntries := aOther.FMap.ToArray;
  for i := 0 to High(OtherEntries) do
  begin
    if not FMap.ContainsKey(OtherEntries[i].Key) then
      Result.SetCount(OtherEntries[i].Key, OtherEntries[i].Value);
  end;
end;

function TMultiSet.Intersection(const aOther: TSelf): TSelf;
var
  Entries: specialize TGenericArray<TInternalMap.TEntry>;
  i: SizeInt;
  OtherCount, MinCount: SizeUInt;
begin
  Result := TSelf.Create;

  // Add common elements with min counts
  Entries := FMap.ToArray;
  for i := 0 to High(Entries) do
  begin
    OtherCount := aOther.CountOf(Entries[i].Key);
    if OtherCount > 0 then
    begin
      if Entries[i].Value <= OtherCount then
        MinCount := Entries[i].Value
      else
        MinCount := OtherCount;
      Result.SetCount(Entries[i].Key, MinCount);
    end;
  end;
end;

function TMultiSet.Difference(const aOther: TSelf): TSelf;
var
  Entries: specialize TGenericArray<TInternalMap.TEntry>;
  i: SizeInt;
  OtherCount: SizeUInt;
begin
  Result := TSelf.Create;

  // Add elements from self minus other's count
  Entries := FMap.ToArray;
  for i := 0 to High(Entries) do
  begin
    OtherCount := aOther.CountOf(Entries[i].Key);
    if Entries[i].Value > OtherCount then
      Result.SetCount(Entries[i].Key, Entries[i].Value - OtherCount);
  end;
end;

end.
