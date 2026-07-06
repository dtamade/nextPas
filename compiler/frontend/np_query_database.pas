{**
 * np_query_database.pas — Query Database
 *
 * 编译查询缓存接口。存储和检索语义分析结果。
 * 当前为基础实现，缓存策略待 AL4 完善。
 *}

unit np_query_database;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.core.text.strings;

type
  TQueryDatabase = class
  private
    FEntries: array of record
      Key: string;
      Value: TObject;
    end;
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
  SetLength(FEntries, 0);
end;

destructor TQueryDatabase.Destroy;
var
  I: LongInt;
begin
  for I := 0 to High(FEntries) do
    FEntries[I].Value := nil;  { 不释放 — 所有权在调用者 }
  SetLength(FEntries, 0);
  inherited Destroy;
end;

function TQueryDatabase.Get(const AKey: string; ADefault: TObject): TObject;
var
  I: LongInt;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Key = AKey then
      Exit(FEntries[I].Value);
  Result := ADefault;
end;

procedure TQueryDatabase.Store(const AKey: string; AValue: TObject);
var
  I: LongInt;
begin
  { Overwrite existing entry if key matches }
  for I := 0 to High(FEntries) do
    if FEntries[I].Key = AKey then
    begin
      FEntries[I].Value := AValue;
      Exit;
    end;
  { Append new entry }
  I := Length(FEntries);
  SetLength(FEntries, I + 1);
  FEntries[I].Key := AKey;
  FEntries[I].Value := AValue;
end;

procedure TQueryDatabase.InvalidatePrefix(const APrefix: string);
var
  I: LongInt;
begin
  for I := 0 to High(FEntries) do
    if Pos(APrefix, FEntries[I].Key) = 1 then
      FEntries[I].Value := nil;
end;

end.
