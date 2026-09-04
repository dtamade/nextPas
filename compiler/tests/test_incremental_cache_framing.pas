program test_incremental_cache_framing;

{$mode objfpc}{$H+}

uses
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.text.format,
  nextpas.compiler.frontend.incremental_cache,
  nextpas.compiler.sema.semantic_model;

procedure WriteRawFile(const APath: string; const AData: TBytes);
var
  F: file;
begin
  AssignFile(F, APath);
  Rewrite(F, 1);
  try
    if Length(AData) > 0 then
      BlockWrite(F, AData[0], Length(AData));
  finally
    CloseFile(F);
  end;
end;

function ReadRawFile(const APath: string): TBytes;
var
  F: file;
  Sz: Int64;
begin
  SetLength(Result, 0);
  if not Exists(APath) then Exit;
  AssignFile(F, APath);
  Reset(F, 1);
  try
    Sz := System.FileSize(F);
    SetLength(Result, Sz);
    if Sz > 0 then
      BlockRead(F, Result[0], Sz);
  finally
    CloseFile(F);
  end;
end;

function MakeModel: TSemanticModel;
begin
  Result := TSemanticModel.Create;
  Result.SetRootName('framing-test');
  Result.MarkReady;
end;

var
  Cache: TIncrementalCache;
  CacheDir: string;
  Model: TSemanticModel;
  Loaded: TSemanticModel;
  Ok: Boolean;
  Data: TBytes;
  EntryPath: string;
  FailCount: LongInt;
  PassCount: LongInt;
  FakePayload: LongInt;

procedure Fail(const AMsg: string);
begin
  WriteLn(StdErr, 'FAIL: ' + AMsg);
  Inc(FailCount);
end;

procedure Pass(const AMsg: string);
begin
  WriteLn('PASS: ' + AMsg);
  Inc(PassCount);
end;

begin
  FailCount := 0;
  PassCount := 0;

  if ParamCount < 1 then
  begin
    WriteLn(StdErr, 'usage: test_incremental_cache_framing <cache-dir>');
    Halt(1);
  end;

  CacheDir := ParamStr(1);
  Cache := TIncrementalCache.Create(CacheDir);
  try

    { === Test 1: V2 round-trip === }
    Model := MakeModel;
    try
      Cache.Save('unit-a', 'source-a', [], Model);

      Ok := Cache.HasCache('unit-a', 'source-a', []);
      if not Ok then Fail('HasCache should return True after Save')
      else Pass('HasCache true after Save');

      Ok := Cache.Load('unit-a', 'source-a', [], Loaded);
      if not Ok then Fail('Load should return True after Save')
      else
      begin
        Pass('Load true after Save');
        if Loaded = nil then Fail('Loaded model should not be nil')
        else
        begin
          if Loaded.RootName <> 'framing-test' then
            Fail('RootName mismatch: got ' + Loaded.RootName)
          else
            Pass('RootName round-trip correct');
          Loaded.Free;
        end;
      end;
    finally
      Model.Free;
    end;

    { === Test 2: source mismatch === }
    Ok := Cache.HasCache('unit-a', 'different-source', []);
    if Ok then Fail('HasCache should miss on source mismatch')
    else Pass('HasCache misses on source mismatch');

    Ok := Cache.Load('unit-a', 'different-source', [], Loaded);
    if Ok then
    begin
      Fail('Load should miss on source mismatch');
      Loaded.Free;
    end
    else Pass('Load misses on source mismatch');

    { === Test 3: deps mismatch === }
    Ok := Cache.HasCache('unit-a', 'source-a', ['dep1']);
    if Ok then Fail('HasCache should miss on deps mismatch')
    else Pass('HasCache misses on deps mismatch');

    { === Test 4: wrong magic === }
    Cache.Invalidate('unit-bad');
    Cache.Save('unit-bad', 'src-bad', [], MakeModel);
    EntryPath := Cache.EntryPath('unit-bad');
    Data := ReadRawFile(EntryPath);
    if Length(Data) >= 4 then
    begin
      Data[0] := Data[0] xor $FF;
      WriteRawFile(EntryPath, Data);

      Ok := Cache.HasCache('unit-bad', 'src-bad', []);
      if Ok then Fail('HasCache should reject wrong magic')
      else Pass('HasCache rejects wrong magic');

      Ok := Cache.Load('unit-bad', 'src-bad', [], Loaded);
      if Ok then
      begin
        Fail('Load should reject wrong magic');
        Loaded.Free;
      end
      else Pass('Load rejects wrong magic');
    end
    else
      Fail('Test 4: could not read cache file');

    { === Test 5: truncated file (< header) === }
    Cache.Invalidate('unit-trunc');
    Cache.Save('unit-trunc', 'src-trunc', [], MakeModel);
    EntryPath := Cache.EntryPath('unit-trunc');
    Data := ReadRawFile(EntryPath);
    if Length(Data) >= 10 then
    begin
      SetLength(Data, 10);
      WriteRawFile(EntryPath, Data);

      Ok := Cache.HasCache('unit-trunc', 'src-trunc', []);
      if Ok then Fail('HasCache should reject truncated file')
      else Pass('HasCache rejects truncated file');

      Ok := Cache.Load('unit-trunc', 'src-trunc', [], Loaded);
      if Ok then
      begin
        Fail('Load should reject truncated file');
        Loaded.Free;
      end
      else Pass('Load rejects truncated file');
    end
    else
      Fail('Test 5: could not read cache file');

    { === Test 6: payload size larger than actual === }
    Cache.Invalidate('unit-size');
    Cache.Save('unit-size', 'src-size', [], MakeModel);
    EntryPath := Cache.EntryPath('unit-size');
    Data := ReadRawFile(EntryPath);
    if Length(Data) >= 12 then
    begin
      FakePayload := $7FFFFFFF;
      Move(FakePayload, Data[8], 4);
      WriteRawFile(EntryPath, Data);

      Ok := Cache.Load('unit-size', 'src-size', [], Loaded);
      if Ok then
      begin
        Fail('Load should reject oversized payload declaration');
        Loaded.Free;
      end
      else Pass('Load rejects oversized payload declaration');
    end
    else
      Fail('Test 6: could not read cache file');

    { === Test 7: payload digest mismatch === }
    Cache.Invalidate('unit-digest');
    Cache.Save('unit-digest', 'src-digest', [], MakeModel);
    EntryPath := Cache.EntryPath('unit-digest');
    Data := ReadRawFile(EntryPath);
    if Length(Data) >= 49 then
    begin
      Data[48] := Data[48] xor $FF;
      WriteRawFile(EntryPath, Data);

      Ok := Cache.Load('unit-digest', 'src-digest', [], Loaded);
      if Ok then
      begin
        Fail('Load should reject digest mismatch');
        Loaded.Free;
      end
      else Pass('Load rejects digest mismatch');
    end
    else
      Fail('Test 7: could not read cache file');

    { === Test 8: trailing bytes === }
    Cache.Invalidate('unit-trail');
    Cache.Save('unit-trail', 'src-trail', [], MakeModel);
    EntryPath := Cache.EntryPath('unit-trail');
    Data := ReadRawFile(EntryPath);
    if Length(Data) >= NPC_HEADER_SIZE then
    begin
      SetLength(Data, Length(Data) + 1);
      Data[High(Data)] := 0;
      WriteRawFile(EntryPath, Data);

      Ok := Cache.Load('unit-trail', 'src-trail', [], Loaded);
      if Ok then
      begin
        Fail('Load should reject trailing bytes');
        Loaded.Free;
      end
      else Pass('Load rejects trailing bytes');
    end
    else
      Fail('Test 8: could not read cache file');

    { === Test 9: wrong version === }
    Cache.Invalidate('unit-ver');
    Cache.Save('unit-ver', 'src-ver', [], MakeModel);
    EntryPath := Cache.EntryPath('unit-ver');
    Data := ReadRawFile(EntryPath);
    if Length(Data) >= 8 then
    begin
      Data[7] := Data[7] xor $FF;
      WriteRawFile(EntryPath, Data);

      Ok := Cache.Load('unit-ver', 'src-ver', [], Loaded);
      if Ok then
      begin
        Fail('Load should reject wrong version');
        Loaded.Free;
      end
      else Pass('Load rejects wrong version');
    end
    else
      Fail('Test 9: could not read cache file');

    Cache.Clear;

  finally
    Cache.Free;
  end;

  WriteLn;
  WriteLn(TextFormat('Framing tests: %d passed, %d failed', [PassCount, FailCount]));
  if FailCount > 0 then
    Halt(1);
  WriteLn('incremental-cache-framing=pass');
end.
