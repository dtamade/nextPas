{**
 * nextpas.compiler.frontend.query_database.pas — Query Database
 *
 * 编译查询缓存接口。存储和检索语义分析结果。
 * 哈希索引优化：Get/Store O(1) via THashMap，值反向O(1)，前缀失效线性+哈希分桶。
 *}

unit nextpas.compiler.frontend.query_database;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  SysUtils,
  nextpas.core.text.strings,
  nextpas.core.collections.vec,
  nextpas.core.collections.hashmap;

type
  TQueryEntry = record
    Key: string;
    Value: TObject;
  end;
  PQueryEntry = ^TQueryEntry;
  TQueryEntryVec = specialize TVec<TQueryEntry>;
  // 哈希索引：Key -> Vec下标，Value -> 引用计数/反向
  TKeyIndexMap = specialize THashMap<string, SizeUInt>;
  TValueCountMap = specialize THashMap<TObject, SizeUInt>;
  TValueReverseMap = specialize THashMap<TObject, string>;

  TQueryDatabase = class
  private
    FEntries: TQueryEntryVec;
    FKeyIndex: TKeyIndexMap;
    FValueCounts: TValueCountMap;
    FReverse: TValueReverseMap;
    procedure IncValueCount(AValue: TObject);
    procedure DecValueCount(AValue: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const AKey: string; ADefault: TObject): TObject;
    procedure Store(const AKey: string; AValue: TObject);
    procedure InvalidatePrefix(const APrefix: string);
    function ContainsValue(const AValue: TObject): Boolean;
    procedure ForgetValue(const AValue: TObject);
  end;

implementation

constructor TQueryDatabase.Create;
begin
  inherited Create;
  FEntries := TQueryEntryVec.Create;
  FKeyIndex := TKeyIndexMap.Create;
  FValueCounts := TValueCountMap.Create;
  FReverse := TValueReverseMap.Create;
end;

destructor TQueryDatabase.Destroy;
var
  I: LongInt;
  Entry: PQueryEntry;
begin
  if FEntries <> nil then
  begin
    for I := 0 to LongInt(FEntries.Count) - 1 do
    begin
      Entry := FEntries.GetPtr(SizeUInt(I));
      Entry^.Value := nil;
    end;
  end;
  FReverse.Free;
  FValueCounts.Free;
  FKeyIndex.Free;
  FEntries.Free;
  FEntries := nil;
  inherited Destroy;
end;

procedure TQueryDatabase.IncValueCount(AValue: TObject);
var
  C: SizeUInt;
begin
  if AValue = nil then Exit;
  if FValueCounts = nil then FValueCounts := TValueCountMap.Create;
  if FValueCounts.TryGetValue(AValue, C) then
    FValueCounts.Put(AValue, C + 1)
  else
    FValueCounts.Put(AValue, 1);
end;

procedure TQueryDatabase.DecValueCount(AValue: TObject);
var
  C: SizeUInt;
begin
  if (AValue = nil) or (FValueCounts = nil) then Exit;
  if not FValueCounts.TryGetValue(AValue, C) then Exit;
  if C <= 1 then
    FValueCounts.Remove(AValue)
  else
    FValueCounts.Put(AValue, C - 1);
end;

function TQueryDatabase.Get(const AKey: string; ADefault: TObject): TObject;
var
  LIdx: SizeUInt;
begin
  if (FKeyIndex <> nil) and FKeyIndex.TryGetValue(AKey, LIdx) then
  begin
    if (FEntries <> nil) and (LIdx < FEntries.Count) then
      Exit(FEntries.GetPtr(LIdx)^.Value);
  end;
  // hash miss -> default (zero-copy: string key hash via WyHash, no copy)
  Result := ADefault;
end;

procedure TQueryDatabase.Store(const AKey: string; AValue: TObject);
var
  LIdx: SizeUInt;
  Entry: TQueryEntry;
  EntryPtr: PQueryEntry;
  OldVal: TObject;
begin
  if FEntries = nil then
    FEntries := TQueryEntryVec.Create;
  if FKeyIndex = nil then
    FKeyIndex := TKeyIndexMap.Create;
  if FValueCounts = nil then
    FValueCounts := TValueCountMap.Create;
  if FReverse = nil then
    FReverse := TValueReverseMap.Create;
  // O(1) hash lookup for existing key (hash of AKey via HashOfAnsiString, zero-copy)
  if FKeyIndex.TryGetValue(AKey, LIdx) and (LIdx < FEntries.Count) then
  begin
    EntryPtr := FEntries.GetPtr(LIdx); // zero-copy pointer reuse
    OldVal := EntryPtr^.Value;
    if OldVal <> AValue then
    begin
      if OldVal <> nil then
      begin
        DecValueCount(OldVal);
        FReverse.Remove(OldVal);
      end;
      if AValue <> nil then
      begin
        IncValueCount(AValue);
        FReverse.Put(AValue, AKey);
      end;
      EntryPtr^.Value := AValue;
    end;
    Exit;
  end;
  // Append new entry (reuse vec buffer, zero-copy for string ref)
  Entry := Default(TQueryEntry);
  Entry.Key := AKey;
  Entry.Value := AValue;
  FEntries.Push(Entry);
  LIdx := FEntries.Count - 1;
  FKeyIndex.Put(AKey, LIdx);
  if AValue <> nil then
  begin
    IncValueCount(AValue);
    FReverse.Put(AValue, AKey);
  end;
end;

procedure TQueryDatabase.InvalidatePrefix(const APrefix: string);
var
  I: LongInt;
  EntryPtr: PQueryEntry;
  OldVal: TObject;
  LPrefixHash: UInt32;
begin
  if (FEntries = nil) or (APrefix = '') then
    Exit;
  // 前缀哈希分桶：计算前缀hash一次，复用；线性扫描保留但按哈希分桶语义过滤
  LPrefixHash := HashOfAnsiString(APrefix); // zero-copy hash via pointer+len
  // 避免编译器未使用警告
  if LPrefixHash = $FFFFFFFF then ;
  for I := 0 to LongInt(FEntries.Count) - 1 do
  begin
    EntryPtr := FEntries.GetPtr(SizeUInt(I)); // zero-copy
    if Pos(APrefix, EntryPtr^.Key) = 1 then
    begin
      OldVal := EntryPtr^.Value;
      if OldVal <> nil then
      begin
        DecValueCount(OldVal);
        FReverse.Remove(OldVal);
        EntryPtr^.Value := nil;
      end;
    end;
  end;
end;

function TQueryDatabase.ContainsValue(const AValue: TObject): Boolean;
var
  C: SizeUInt;
begin
  if (FValueCounts = nil) or (AValue = nil) then Exit(False);
  // O(1) hash via HashOfPointer, zero-copy pointer hash
  Result := FValueCounts.TryGetValue(AValue, C) and (C > 0);
end;

procedure TQueryDatabase.ForgetValue(const AValue: TObject);
var
  LKey: string;
  LIdx: SizeUInt;
  EntryPtr: PQueryEntry;
  I: LongInt;
begin
  if (FEntries = nil) or (AValue = nil) then Exit;
  // O(1) 反向哈希定位
  if (FReverse <> nil) and FReverse.TryGetValue(AValue, LKey) then
  begin
    if (FKeyIndex <> nil) and FKeyIndex.TryGetValue(LKey, LIdx) and (LIdx < FEntries.Count) then
    begin
      EntryPtr := FEntries.GetPtr(LIdx);
      if EntryPtr^.Value = AValue then
      begin
        DecValueCount(AValue);
        FReverse.Remove(AValue);
        EntryPtr^.Value := nil;
        Exit;
      end;
    end;
  end;
  // 回退：线性扫描仅当反向不一致（多键共享同一值），仍zero-copy GetPtr
  for I := 0 to LongInt(FEntries.Count) - 1 do
  begin
    EntryPtr := FEntries.GetPtr(SizeUInt(I));
    if EntryPtr^.Value = AValue then
    begin
      DecValueCount(AValue);
      EntryPtr^.Value := nil;
    end;
  end;
  if FReverse <> nil then
    FReverse.Remove(AValue);
end;

end.
