{**
 * np_query_database.pas — Query Database
 *
 * 编译查询缓存接口。存储和检索语义分析结果。
 * D 分层：lower 定义 ILowerQuery，frontend 实现适配。
 * Store 泄漏补漏：覆盖/失效时 Free 旧值，需配合 Session ContainsValue/ForgetValue 避免双释。
 *}

unit np_query_database;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}
{$UNITPATH ../lower}

interface

uses
  SysUtils,
  nextpas.core.text.strings,
  nextpas.core.collections.vec,
  np_lower_query;

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
    function ContainsValue(const AValue: TObject): Boolean;
    function ForgetValue(const AValue: TObject): Boolean;
  end;

  TLowerQueryAdapter = class(TInterfacedObject, ILowerQuery)
  private
    FDB: TQueryDatabase;
  public
    constructor Create(ADB: TQueryDatabase);
    function QueryGet(const AKey: string; ADefault: TObject): TObject;
    procedure QueryStore(const AKey: string; AValue: TObject);
  end;

implementation

constructor TQueryDatabase.Create;
begin
  inherited Create;
  FEntries := TQueryEntryVec.Create;
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
      if Entry^.Value <> nil then
        Entry^.Value.Free;
      Entry^.Value := nil;
    end;
  end;
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
  for I := 0 to LongInt(FEntries.Count) - 1 do
    if FEntries[SizeUInt(I)].Key = AKey then
    begin
      EntryPtr := FEntries.GetPtr(SizeUInt(I));
      if (EntryPtr^.Value <> nil) and (EntryPtr^.Value <> AValue) then
        EntryPtr^.Value.Free;
      EntryPtr^.Value := AValue;
      Exit;
    end;
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
    begin
      if EntryPtr^.Value <> nil then
        EntryPtr^.Value.Free;
      EntryPtr^.Value := nil;
    end;
  end;
end;

function TQueryDatabase.ContainsValue(const AValue: TObject): Boolean;
var
  I: LongInt;
begin
  if (FEntries = nil) or (AValue = nil) then
    Exit(False);
  for I := 0 to LongInt(FEntries.Count) - 1 do
    if FEntries[SizeUInt(I)].Value = AValue then
      Exit(True);
  Result := False;
end;

function TQueryDatabase.ForgetValue(const AValue: TObject): Boolean;
var
  I: LongInt;
  EntryPtr: PQueryEntry;
begin
  Result := False;
  if (FEntries = nil) or (AValue = nil) then
    Exit;
  for I := 0 to LongInt(FEntries.Count) - 1 do
  begin
    EntryPtr := FEntries.GetPtr(SizeUInt(I));
    if EntryPtr^.Value = AValue then
    begin
      EntryPtr^.Value := nil;
      Result := True;
      Exit;
    end;
  end;
end;

{ TLowerQueryAdapter }

constructor TLowerQueryAdapter.Create(ADB: TQueryDatabase);
begin
  inherited Create;
  FDB := ADB;
end;

function TLowerQueryAdapter.QueryGet(const AKey: string; ADefault: TObject): TObject;
begin
  if FDB <> nil then
    Result := FDB.Get(AKey, ADefault)
  else
    Result := ADefault;
end;

procedure TLowerQueryAdapter.QueryStore(const AKey: string; AValue: TObject);
begin
  if FDB <> nil then
    FDB.Store(AKey, AValue);
end;

end.
