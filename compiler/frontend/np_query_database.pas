{**
 * np_query_database.pas — Query Database
 *
 * 编译查询缓存接口。存储和检索语义分析结果。
 * 当前为基础实现，缓存策略待 AL4 完善。
 *}

unit np_query_database;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  SysUtils,
  nextpas.core.text.strings,
  nextpas.core.collections.vec;

type
  TQueryEntry = record
    Key: string;
    Value: TObject;
  end;
  PQueryEntry = ^TQueryEntry;
  TQueryEntryVec = specialize TVec<TQueryEntry>;

  TQueryDatabase = class
  private
    FEntries: TQueryEntryVec;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const AKey: string; ADefault: TObject): TObject;
    procedure Store(const AKey: string; AValue: TObject);
    procedure InvalidatePrefix(const APrefix: string);
  end;

implementation

constructor TQueryDatabase.Create;
begin
  inherited Create;
  FEntries := TQueryEntryVec.Create;
end;

destructor TQueryDatabase.Destroy;
begin
  // Weak cache: session owns lifecycle, avoid double-free
  FEntries.Free;
  FEntries := nil;
  inherited Destroy;
end;

function TQueryDatabase.Get(const AKey: string; ADefault: TObject): TObject;
var
  I: LongInt;
begin
  if FEntries = nil then
    Exit(ADefault);
  for I := 0 to LongInt(FEntries.Count) - 1 do
    if FEntries[SizeUInt(I)].Key = AKey then
      Exit(FEntries[SizeUInt(I)].Value);
  Result := ADefault;
end;

procedure TQueryDatabase.Store(const AKey: string; AValue: TObject);
var
  I: LongInt;
  Entry: TQueryEntry;
  EntryPtr: PQueryEntry;
begin
  if FEntries = nil then
    FEntries := TQueryEntryVec.Create;
  { Overwrite existing entry if key matches }
  for I := 0 to LongInt(FEntries.Count) - 1 do
    if FEntries[SizeUInt(I)].Key = AKey then
    begin
      EntryPtr := FEntries.GetPtr(SizeUInt(I));
      EntryPtr^.Value := AValue;
      Exit;
    end;
  { Append new entry }
  Entry := Default(TQueryEntry);
  Entry.Key := AKey;
  Entry.Value := AValue;
  FEntries.Push(Entry);
end;

procedure TQueryDatabase.InvalidatePrefix(const APrefix: string);
var
  I: LongInt;
  EntryPtr: PQueryEntry;
begin
  if FEntries = nil then
    Exit;
  for I := 0 to LongInt(FEntries.Count) - 1 do
  begin
    EntryPtr := FEntries.GetPtr(SizeUInt(I));
    if Pos(APrefix, EntryPtr^.Key) = 1 then
      EntryPtr^.Value := nil;
  end;
end;

end.
