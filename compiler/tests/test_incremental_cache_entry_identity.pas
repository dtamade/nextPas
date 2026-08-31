program test_incremental_cache_entry_identity;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.frontend.incremental_cache,
  nextpas.compiler.sema.semantic_model;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'incremental-cache-entry-identity-failure=', AMessage);
  Halt(1);
end;

function CacheEntryCount(const ACacheDir: string): LongInt;
var
  SearchRec: TSearchRec;
begin
  Result := 0;
  if FindFirst(IncludeTrailingPathDelimiter(ACacheDir) + '*.npc',
    faAnyFile, SearchRec) <> 0 then
    Exit;
  try
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        Inc(Result);
    until FindNext(SearchRec) <> 0;
  finally
    FindClose(SearchRec);
  end;
end;

function IsFlatDigestEntryName(const AName: string): Boolean;
var
  I: LongInt;
begin
  if Length(AName) <> 68 then
    Exit(False);
  if Copy(AName, 65, 4) <> '.npc' then
    Exit(False);
  for I := 1 to 64 do
    if not (AName[I] in ['0'..'9', 'a'..'f', 'A'..'F']) then
      Exit(False);
  Result := True;
end;

procedure RequireFlatDigestEntries(const ACacheDir: string;
  const AExpectedCount: LongInt);
var
  Count: LongInt;
  SearchRec: TSearchRec;
begin
  Count := CacheEntryCount(ACacheDir);
  if Count <> AExpectedCount then
    Fail('entry-count expected=' + IntToStr(AExpectedCount) +
      ' actual=' + IntToStr(Count));

  if FindFirst(IncludeTrailingPathDelimiter(ACacheDir) + '*.npc',
    faAnyFile, SearchRec) <> 0 then
  begin
    if AExpectedCount = 0 then
      Exit;
    Fail('cache-entry-missing');
  end;
  try
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and
        not IsFlatDigestEntryName(SearchRec.Name) then
        Fail('unsafe-cache-entry-name=' + SearchRec.Name);
    until FindNext(SearchRec) <> 0;
  finally
    FindClose(SearchRec);
  end;
end;

procedure SaveOrFail(ACache: TIncrementalCache; const AUnitId: string;
  const ASourceText: string; AModel: TSemanticModel);
begin
  try
    ACache.Save(AUnitId, ASourceText, [], AModel);
  except
    on E: Exception do
      Fail('save-raised unit=' + AUnitId + ' message=' + E.Message);
  end;
end;

var
  Cache: TIncrementalCache;
  CacheDir: string;
  FirstUnitId: string;
  Model: TSemanticModel;
  SecondUnitId: string;
begin
  if ParamCount <> 1 then
    Fail('usage: test_incremental_cache_entry_identity <cache-dir>');

  CacheDir := ParamStr(1);
  FirstUnitId := '/workspace/first/shared_name.pas';
  SecondUnitId := '/workspace/second/shared_name.pas';

  Model := TSemanticModel.Create;
  Cache := TIncrementalCache.Create(CacheDir);
  try
    Model.SetRootName('cache-entry-identity');
    Model.MarkReady;

    SaveOrFail(Cache, FirstUnitId, 'first-source', Model);
    RequireFlatDigestEntries(CacheDir, 1);

    SaveOrFail(Cache, FirstUnitId, 'updated-first-source', Model);
    RequireFlatDigestEntries(CacheDir, 1);

    SaveOrFail(Cache, SecondUnitId, 'second-source', Model);
    RequireFlatDigestEntries(CacheDir, 2);

    Cache.Invalidate(FirstUnitId);
    RequireFlatDigestEntries(CacheDir, 1);
    Cache.Invalidate(SecondUnitId);
    RequireFlatDigestEntries(CacheDir, 0);

    SaveOrFail(Cache, FirstUnitId, 'first-source', Model);
    SaveOrFail(Cache, SecondUnitId, 'second-source', Model);
    Cache.Clear;
    RequireFlatDigestEntries(CacheDir, 0);
  finally
    Cache.Free;
    Model.Free;
  end;

  WriteLn('incremental-cache-entry-identity=pass');
end.
