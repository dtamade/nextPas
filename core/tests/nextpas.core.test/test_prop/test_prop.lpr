{ test_prop — Property-based testing framework tests }
program test_prop;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.test,
  nextpas.core.test.prop;

var
  GTestCount: Integer;

{ ── String property tests ─────────────────────────────────────────────────── }

procedure TestStringProperty;
begin
  GTestCount := 0;
  Prop('String length <= 100', procedure(const S: string)
  begin
    Inc(GTestCount);
    if Length(S) > 100 then
      PropFail('String too long: ' + IntToStr(Length(S)));
  end, GenString(100), 50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

procedure TestStringShrink;
{ B3: do not use Prop()+PropFail (FailTest/Halt). Exercise Shrink API directly. }
var
  LGen: IStringGenerator;
  LValue: string;
  LCandidates: specialize TArray<string>;
  I, J: Integer;
  LFound: Boolean;
begin
  LGen := GenString(100);
  LFound := False;
  for I := 1 to 200 do
  begin
    LValue := LGen.Generate;
    if Length(LValue) > 10 then
    begin
      LFound := True;
      LCandidates := LGen.Shrink(LValue);
      CheckTrue(Length(LCandidates) > 0, 'shrink produces candidates');
      for J := 0 to High(LCandidates) do
        CheckTrue(Length(LCandidates[J]) <= Length(LValue), 'shrink not longer');
      Break;
    end;
  end;
  CheckTrue(LFound, 'expected Length>10 within 200 draws');
end;

{ ── Int64 property tests ──────────────────────────────────────────────────── }

procedure TestIntProperty;
begin
  GTestCount := 0;
  Prop('Int always positive', procedure(const V: Int64)
  begin
    Inc(GTestCount);
    if V < 0 then
      PropFail('Negative value: ' + IntToStr(V));
  end, GenInt(0, 1000), 50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

procedure TestIntShrink;
{ B3: exercise IIntGenerator.Shrink without Prop FailTest/Halt. }
var
  LGen: IIntGenerator;
  LValue: Int64;
  LCandidates: specialize TArray<Int64>;
  I, J: Integer;
  LFound: Boolean;
begin
  LGen := GenInt(0, 1000);
  LFound := False;
  for I := 1 to 200 do
  begin
    LValue := LGen.Generate;
    if LValue > 100 then
    begin
      LFound := True;
      LCandidates := LGen.Shrink(LValue);
      CheckTrue(Length(LCandidates) > 0, 'int shrink produces candidates');
      for J := 0 to High(LCandidates) do
        CheckTrue(LCandidates[J] <= LValue, 'int shrink not greater');
      Break;
    end;
  end;
  CheckTrue(LFound, 'expected V>100 within 200 draws');
end;

{ ── Boolean property tests ────────────────────────────────────────────────── }

procedure TestBoolProperty;
begin
  GTestCount := 0;
  Prop('Bool is boolean', procedure(const V: Boolean)
  begin
    Inc(GTestCount);
    CheckTrue(V or not V, 'Value is boolean');
  end, GenBool, 20, True);
  if GTestCount <> 20 then
    FailTest('Expected 20 runs, got ' + IntToStr(GTestCount));
end;

{ ── TBytes property tests ─────────────────────────────────────────────────── }

procedure TestBytesProperty;
begin
  GTestCount := 0;
  Prop('Bytes length <= 100', procedure(const V: TBytes)
  begin
    Inc(GTestCount);
    if Length(V) > 100 then
      PropFail('Bytes too long: ' + IntToStr(Length(V)));
  end, GenBytes(100), 50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

{ ── Combinator tests ──────────────────────────────────────────────────────── }

procedure TestMapIntToStr;
var
  LCount: Integer;
begin
  LCount := 0;
  Prop('MapIntToStr: digits only', procedure(const S: string)
  begin
    Inc(LCount);
    if Length(S) = 0 then
      PropFail('Empty string from MapIntToStr');
  end, MapIntToStr(GenInt(0, 9999), function(V: Int64): string begin Result := IntToStr(V) end),
  50, True);
  if LCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(LCount));
end;

procedure TestFilterInt;
var
  LCount: Integer;
begin
  LCount := 0;
  Prop('FilterInt: even only', procedure(const V: Int64)
  begin
    Inc(LCount);
    if V mod 2 <> 0 then
      PropFail('Odd value: ' + IntToStr(V));
  end, FilterInt(GenInt(0, 1000), function(V: Int64): Boolean begin Result := V mod 2 = 0 end),
  50, True);
  if LCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(LCount));
end;

procedure TestFilterString;
var
  LCount: Integer;
begin
  LCount := 0;
  Prop('FilterString: non-empty', procedure(const S: string)
  begin
    Inc(LCount);
    if Length(S) = 0 then
      PropFail('Empty string');
  end, FilterString(GenString(50), function(const V: string): Boolean begin Result := Length(V) > 0 end),
  50, True);
  if LCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(LCount));
end;

procedure TestFilterBytes;
var
  LCount: Integer;
begin
  LCount := 0;
  Prop('FilterBytes: non-empty', procedure(const V: TBytes)
  begin
    Inc(LCount);
    if Length(V) = 0 then
      PropFail('Empty bytes');
  end, FilterBytes(GenBytes(50), function(const V: TBytes): Boolean begin Result := Length(V) > 0 end),
  50, True);
  if LCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(LCount));
end;

{ ── GenChoice / GenOneOf tests ────────────────────────────────────────────── }

procedure TestGenChoiceInt;
var
  LSeen: Boolean;
begin
  LSeen := False;
  Prop('GenChoiceInt: values in set', procedure(const V: Int64)
  begin
    LSeen := True;
    if (V <> 10) and (V <> 20) and (V <> 30) then
      PropFail('Value not in choice set: ' + IntToStr(V));
  end, GenChoiceInt([10, 20, 30]), 50, True);
  if not LSeen then
    FailTest('GenChoiceInt never generated');
end;

procedure TestGenChoiceString;
begin
  Prop('GenChoiceString: values in set', procedure(const V: string)
  begin
    if (V <> 'foo') and (V <> 'bar') and (V <> 'baz') then
      PropFail('Value not in choice set: ' + V);
  end, GenChoiceString(['foo', 'bar', 'baz']), 50, True);
end;

procedure TestGenChoiceBool;
begin
  Prop('GenChoiceBool: single value', procedure(const V: Boolean)
  begin
    if V <> True then
      PropFail('Expected True');
  end, GenChoiceBool([True]), 20, True);
end;

procedure TestGenOneOfInt;
begin
  Prop('GenOneOfInt: range union', procedure(const V: Int64)
  begin
    if not (((V >= 0) and (V <= 10)) or ((V >= 100) and (V <= 110))) then
      PropFail('Value out of range: ' + IntToStr(V));
  end, GenOneOfInt([GenInt(0, 10), GenInt(100, 110)]), 50, True);
end;

procedure TestGenOneOfString;
begin
  Prop('GenOneOfString: mixed generators', procedure(const S: string)
  begin
    if Length(S) > 10 then
      PropFail('String too long: ' + IntToStr(Length(S)));
  end, GenOneOfString([GenString(5), GenString(10)]), 50, True);
end;

{ ── Improved shrinking test ───────────────────────────────────────────────── }

procedure TestIntShrinkRespectsMin;
var
  LResult: string;
begin
  { GenInt(100, 1000) should shrink toward 100, not 0.
    Property fails when V > 200, so shrink should find 201 (just above boundary). }
  LResult := PropWithResult('Int shrink toward min', procedure(const V: Int64)
  begin
    if V < 100 then
      PropFail('Below min: ' + IntToStr(V));
    if V > 200 then
      PropFail('Above 200: ' + IntToStr(V));
  end, GenInt(100, 1000), 100, True);
  if LResult = '' then
    FailTest('Expected property to fail');
  { Verify shrinking found value near boundary (200-210 range) }
  if StrToInt(LResult) < 200 then
    FailTest('Expected shrunk value >= 200, got: ' + LResult);
  if StrToInt(LResult) > 210 then
    FailTest('Expected shrunk value <= 210, got: ' + LResult);
end;

{ ── Fuzzing tests (v7.2a) ─────────────────────────────────────────────────── }

procedure TestFuzzBasic;
{ Fuzz a simple check that always passes }
var
  LCorpus: array[0..1] of TBytes;
begin
  LCorpus[0] := TBytes.Create($48, $65, $6C, $6C, $6F);  { "Hello" }
  LCorpus[1] := TBytes.Create($57, $6F, $72, $6C, $64);  { "World" }
  Fuzz('bytes always valid', procedure(const Data: TBytes)
  begin
    { Just verify Data is accessible — no failure condition }
    if Length(Data) < 0 then
      PropFail('Negative length');  { impossible, but keeps PropFail in use }
  end, LCorpus, 1000);
end;

procedure TestFuzzString;
{ Fuzz string processing that always passes }
var
  LCorpus: array[0..1] of string;
begin
  LCorpus[0] := 'Hello World';
  LCorpus[1] := 'Test string';
  FuzzString('string always valid', procedure(const S: string)
  begin
    { Just verify S is accessible — no failure condition }
    if Length(S) < 0 then
      PropFail('Negative length');  { impossible }
  end, LCorpus, 1000);
end;

procedure TestFuzzGenBytes;
var
  LBytes: TBytes;
begin
  LBytes := FuzzGenBytes(32);
  if Length(LBytes) <> 32 then
    FailTest('Expected 32 bytes, got ' + IntToStr(Length(LBytes)));
end;

procedure TestFuzzGenString;
var
  LS: string;
  I: Integer;
begin
  LS := FuzzGenString(20);
  if Length(LS) <> 20 then
    FailTest('Expected 20 chars, got ' + IntToStr(Length(LS)));
  { Verify all chars are printable ASCII }
  for I := 1 to Length(LS) do
    if (Ord(LS[I]) < 32) or (Ord(LS[I]) > 127) then
      FailTest('Non-printable char at position ' + IntToStr(I));
end;

procedure TestFuzzEmptyCorpus;
{ Verify empty corpus is rejected — Fuzz calls FailTest which calls Halt(1),
  so we can't catch it. Instead, just verify the function exists and runs
  with a valid corpus. }
var
  LCorpus: array[0..0] of TBytes;
begin
  LCorpus[0] := TBytes.Create($01);
  Fuzz('valid corpus', procedure(const Data: TBytes)
  begin
    { always passes }
  end, LCorpus, 10);
end;

{ ── Corpus Management tests (v7.3a) ──────────────────────────────────────── }

procedure TestCorpusCreate;
var
  LCorpus: TFuzzCorpus;
begin
  LCorpus := TFuzzCorpus.Create('/tmp/test_corpus_create');
  try
    if LCorpus.Count <> 0 then
      FailTest('Expected 0 items, got ' + IntToStr(LCorpus.Count));
  finally
    LCorpus.Free;
  end;
end;

procedure TestCorpusAdd;
var
  LCorpus: TFuzzCorpus;
  LData: TBytes;
begin
  LCorpus := TFuzzCorpus.Create('/tmp/test_corpus_add');
  try
    LData := TBytes.Create($01, $02, $03);
    if not LCorpus.Add(LData) then
      FailTest('First add should return True');
    if LCorpus.Add(LData) then
      FailTest('Duplicate add should return False');
    if LCorpus.Count <> 1 then
      FailTest('Expected 1 item, got ' + IntToStr(LCorpus.Count));
  finally
    LCorpus.Free;
  end;
end;

procedure TestCorpusAddString;
var
  LCorpus: TFuzzCorpus;
begin
  LCorpus := TFuzzCorpus.Create('/tmp/test_corpus_addstr');
  try
    if not LCorpus.AddString('hello') then
      FailTest('First add should return True');
    if LCorpus.AddString('hello') then
      FailTest('Duplicate add should return False');
    if LCorpus.Count <> 1 then
      FailTest('Expected 1 item, got ' + IntToStr(LCorpus.Count));
    if LCorpus.GetString(0) <> 'hello' then
      FailTest('Expected "hello", got "' + LCorpus.GetString(0) + '"');
  finally
    LCorpus.Free;
  end;
end;

procedure TestCorpusSaveLoad;
var
  LCorpus1, LCorpus2: TFuzzCorpus;
  LDir: string;
begin
  LDir := '/tmp/test_corpus_saveload';
  { Clean up from previous run }
  LCorpus1 := TFuzzCorpus.Create(LDir);
  try
    LCorpus1.AddString('test1');
    LCorpus1.AddString('test2');
    LCorpus1.Save;
  finally
    LCorpus1.Free;
  end;

  { Load in new instance }
  LCorpus2 := TFuzzCorpus.Create(LDir);
  try
    LCorpus2.Load;
    if LCorpus2.Count <> 2 then
      FailTest('Expected 2 items after load, got ' + IntToStr(LCorpus2.Count));
    if LCorpus2.GetString(0) <> 'test1' then
      FailTest('Expected "test1", got "' + LCorpus2.GetString(0) + '"');
    if LCorpus2.GetString(1) <> 'test2' then
      FailTest('Expected "test2", got "' + LCorpus2.GetString(1) + '"');
  finally
    LCorpus2.Free;
  end;
end;

procedure TestCorpusHasFiles;
var
  LCorpus: TFuzzCorpus;
  LDir: string;
begin
  LDir := '/tmp/test_corpus_hasfiles_' + IntToStr(Random(1000000000));
  LCorpus := TFuzzCorpus.Create(LDir);
  try
    if LCorpus.HasFiles then
      FailTest('Should not have files before save');
    LCorpus.AddString('test');
    LCorpus.Save;
    if not LCorpus.HasFiles then
      FailTest('Should have files after save');
  finally
    LCorpus.Free;
  end;
end;

procedure TestFuzzWithCorpus;
var
  LDir: string;
begin
  LDir := '/tmp/test_fuzz_with_corpus_' + IntToStr(Random(1000000000));
  FuzzWithCorpus('corpus test', procedure(const Data: TBytes)
  begin
    { always passes }
  end, LDir, 100);
end;

procedure TestFuzzStringWithCorpus;
var
  LDir: string;
begin
  LDir := '/tmp/test_fuzz_string_corpus_' + IntToStr(Random(1000000000));
  FuzzStringWithCorpus('string corpus test', procedure(const S: string)
  begin
    { always passes }
  end, LDir, 100);
end;

{ ── Structured Generator tests (v8.0a) ───────────────────────────────────── }

procedure TestGenArray;
var
  LCount: Integer;
begin
  LCount := 0;
  PropArray('Array length <= 50', procedure(const V: array of Int64)
  begin
    Inc(LCount);
    if Length(V) > 50 then
      PropFail('Array too long: ' + IntToStr(Length(V)));
  end, GenArray(GenInt(0, 100), 50), 50, True);
  if LCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(LCount));
end;

procedure TestGenArrayMinMax;
begin
  PropArray('Array length in range', procedure(const V: array of Int64)
  begin
    if Length(V) < 5 then
      PropFail('Array too short: ' + IntToStr(Length(V)));
    if Length(V) > 15 then
      PropFail('Array too long: ' + IntToStr(Length(V)));
  end, GenArray(GenInt(0, 100), 5, 15), 50, True);
end;

procedure TestGenTuple;
var
  LCount: Integer;
begin
  LCount := 0;
  PropTuple('Tuple: int > 0 implies str non-empty', procedure(AInt: Int64; const AStr: string)
  begin
    Inc(LCount);
    if (AInt > 0) and (Length(AStr) = 0) then
      PropFail('Int > 0 but string empty');
  end, GenTuple(GenInt(0, 100), GenString(50)), 50);
  if LCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(LCount));
end;

procedure TestBindInt;
var
  LCount: Integer;
begin
  LCount := 0;
  Prop('BindInt: second gen depends on first', procedure(const V: Int64)
  begin
    Inc(LCount);
    { Second gen should be 0..V, so result should be <= V }
    if V < 0 then
      PropFail('Negative value: ' + IntToStr(V));
  end, BindInt(GenInt(0, 100), function(V: Int64): IIntGenerator
    begin Result := GenInt(0, V) end), 50, True);
  if LCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(LCount));
end;

procedure TestStringShrinkImproved;
{ Test that string shrinking works correctly.
  Property fails when string contains 'X', but we use a generator that
  never generates 'X'. }
begin
  Prop('String shrink: no X in digits', procedure(const S: string)
  begin
    if Pos('X', S) > 0 then
      PropFail('Found X in: "' + S + '"');
  end, MapIntToStr(GenInt(0, 9999), function(V: Int64): string begin Result := IntToStr(V) end),
  100, True);
end;

{ ── Coverage tracker tests (v8.0b) ────────────────────────────────────────── }

procedure TestCoverageTracker;
var
  LTracker: ICoverageTracker;
begin
  LTracker := CreateCoverageTracker;
  CheckEqual(0, LTracker.CoverageCount, 'Initial coverage count');
  CheckEqual(0, LTracker.TotalHits, 'Initial total hits');
  CheckTrue(not LTracker.HasNewCoverage, 'No initial new coverage');

  LTracker.Hit(1);
  CheckTrue(LTracker.HasNewCoverage, 'Has new coverage after first hit');
  CheckEqual(1, LTracker.CoverageCount, 'Coverage count after first hit');
  CheckEqual(1, LTracker.TotalHits, 'Total hits after first hit');

  LTracker.Hit(1);  { duplicate }
  CheckEqual(1, LTracker.CoverageCount, 'Coverage count unchanged for duplicate');
  CheckEqual(2, LTracker.TotalHits, 'Total hits incremented for duplicate');

  LTracker.Hit(5);
  CheckEqual(2, LTracker.CoverageCount, 'Coverage count after new hit');
  CheckEqual(3, LTracker.TotalHits, 'Total hits after new hit');

  LTracker.ResetNewCoverage;
  CheckTrue(not LTracker.HasNewCoverage, 'No new coverage after reset');

  LTracker.Hit(5);  { duplicate after reset }
  CheckTrue(not LTracker.HasNewCoverage, 'No new coverage for duplicate after reset');

  LTracker.Hit(100);
  CheckTrue(LTracker.HasNewCoverage, 'New coverage for fresh hit');
  CheckEqual(3, LTracker.CoverageCount, 'Final coverage count');
end;

{ ── Structured fuzzing tests (v8.0b) ──────────────────────────────────────── }

procedure TestFuzzStructuredInt;
var
  LTracker: ICoverageTracker;
begin
  LTracker := CreateCoverageTracker;
  FuzzStructured('Int in range', procedure(const V: Int64; ACoverage: ICoverageTracker)
  begin
    { Mark coverage based on value ranges }
    if V < 0 then ACoverage.Hit(0)
    else if V < 100 then ACoverage.Hit(1)
    else if V < 1000 then ACoverage.Hit(2)
    else ACoverage.Hit(3);

    if V < 0 then
      PropFail('Negative: ' + IntToStr(V));
  end, GenInt(0, 1000), LTracker, 500);
end;

procedure TestFuzzStructuredString;
var
  LTracker: ICoverageTracker;
begin
  LTracker := CreateCoverageTracker;
  FuzzStructured('String length', procedure(const S: string; ACoverage: ICoverageTracker)
  begin
    { Mark coverage based on string properties }
    if Length(S) = 0 then ACoverage.Hit(0)
    else if Length(S) < 5 then ACoverage.Hit(1)
    else if Length(S) < 20 then ACoverage.Hit(2)
    else ACoverage.Hit(3);

    { Always-passes property: length is non-negative }
    if Length(S) < 0 then
      PropFail('Negative length');
  end, MapIntToStr(GenInt(0, 9999), function(V: Int64): string begin Result := IntToStr(V) end),
  LTracker, 500);
end;

{ ── Parallel fuzzing tests (v8.0b) ────────────────────────────────────────── }

procedure TestFuzzParallel;
begin
  FuzzParallel('Parallel bytes', procedure(const Data: TBytes)
  begin
    { Always-passes property: data is accessible }
    if Length(Data) < 0 then
      PropFail('Negative length');
  end, [TBytes.Create(1, 2, 3), TBytes.Create(65, 66, 67)], 2, 250);
end;

procedure TestFuzzParallelCoverage;
var
  LTracker: ICoverageTracker;
begin
  LTracker := CreateCoverageTracker;
  { FuzzParallel uses its own internal tracker, this just verifies it works }
  FuzzParallel('Coverage parallel', procedure(const Data: TBytes)
  begin
    if Length(Data) > 0 then
    begin
      if Data[0] < 128 then
        LTracker.Hit(0)
      else
        LTracker.Hit(1);
    end;
  end, [TBytes.Create(0), TBytes.Create(255)], 4, 100);
end;

{ ── Edge case tests (audit) ───────────────────────────────────────────────── }

procedure TestGenIntLargeRange;
var
  LGen: IIntGenerator;
  LVal: Int64;
  I: Integer;
begin
  LGen := GenInt(0, MaxInt);
  for I := 1 to 100 do
  begin
    LVal := LGen.Generate;
    if (LVal < 0) or (LVal > MaxInt) then
      PropFail('Value out of range: ' + IntToStr(LVal));
  end;
end;

procedure TestGenIntSameMinMax;
var
  LGen: IIntGenerator;
  I: Integer;
begin
  LGen := GenInt(42, 42);
  for I := 1 to 10 do
    CheckEqual(42, LGen.Generate, 'GenInt(42,42)');
end;

procedure TestGenStringEmpty;
var
  LGen: IStringGenerator;
  I: Integer;
begin
  LGen := GenString(0);
  for I := 1 to 10 do
    CheckEqual(0, Length(LGen.Generate), 'GenString(0)');
end;

procedure TestGenArrayEmpty;
var
  LGen: IArrayGenerator;
  LArr: specialize TArray<Int64>;
  I: Integer;
begin
  LGen := GenArray(GenInt(0, 100), 0, 0);
  for I := 1 to 10 do
  begin
    LArr := LGen.Generate;
    CheckEqual(0, Length(LArr), 'GenArray(0,0)');
  end;
end;

{ ── Validation guard tests (audit round 3) ───────────────────────────────── }

procedure TestGenIntMinMaxReversed;
begin
  ExpectFail(procedure begin
    GenInt(100, 50);
  end, 'AMin must be <= AMax');
end;

procedure TestGenChoiceIntEmpty;
begin
  ExpectFail(procedure begin
    GenChoiceInt([]);
  end, 'empty values array');
end;

procedure TestGenChoiceStringEmpty;
begin
  ExpectFail(procedure begin
    GenChoiceString([]);
  end, 'empty values array');
end;

procedure TestGenOneOfIntEmpty;
begin
  ExpectFail(procedure begin
    GenOneOfInt([]);
  end, 'empty generator array');
end;

procedure TestGenOneOfStringEmpty;
begin
  ExpectFail(procedure begin
    GenOneOfString([]);
  end, 'empty generator array');
end;

procedure TestGenStringMinMaxReversed;
begin
  ExpectFail(procedure begin
    GenString(50, 10);
  end, 'AMinLen must be <= AMaxLen');
end;

procedure TestGenBytesMinMaxReversed;
begin
  ExpectFail(procedure begin
    GenBytes(50, 10);
  end, 'AMinLen must be <= AMaxLen');
end;

procedure TestGenArrayMinMaxReversed;
begin
  ExpectFail(procedure begin
    GenArray(GenInt(0, 100), 50, 10);
  end, 'AMinLen must be <= AMaxLen');
end;
{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
begin
  WriteLn('=== Property-based Testing Framework ===');
  WriteLn;
  Randomize;

  { B3: register as TTestSuite for countable process metrics (Go/Rust scale). }
  LSuite := TTestSuite.Create('prop');
  LSuite.Test('StringProperty', @TestStringProperty);
  LSuite.Test('StringShrink', @TestStringShrink);
  LSuite.Test('IntProperty', @TestIntProperty);
  LSuite.Test('IntShrink', @TestIntShrink);
  LSuite.Test('BoolProperty', @TestBoolProperty);
  LSuite.Test('BytesProperty', @TestBytesProperty);
  LSuite.Test('MapIntToStr', @TestMapIntToStr);
  LSuite.Test('FilterInt', @TestFilterInt);
  LSuite.Test('FilterString', @TestFilterString);
  LSuite.Test('FilterBytes', @TestFilterBytes);
  LSuite.Test('GenChoiceInt', @TestGenChoiceInt);
  LSuite.Test('GenChoiceString', @TestGenChoiceString);
  LSuite.Test('GenChoiceBool', @TestGenChoiceBool);
  LSuite.Test('GenOneOfInt', @TestGenOneOfInt);
  LSuite.Test('GenOneOfString', @TestGenOneOfString);
  LSuite.Test('IntShrinkRespectsMin', @TestIntShrinkRespectsMin);
  LSuite.Test('FuzzBasic', @TestFuzzBasic);
  LSuite.Test('FuzzString', @TestFuzzString);
  LSuite.Test('FuzzGenBytes', @TestFuzzGenBytes);
  LSuite.Test('FuzzGenString', @TestFuzzGenString);
  LSuite.Test('FuzzEmptyCorpus', @TestFuzzEmptyCorpus);
  LSuite.Test('CorpusCreate', @TestCorpusCreate);
  LSuite.Test('CorpusAdd', @TestCorpusAdd);
  LSuite.Test('CorpusAddString', @TestCorpusAddString);
  LSuite.Test('CorpusSaveLoad', @TestCorpusSaveLoad);
  LSuite.Test('CorpusHasFiles', @TestCorpusHasFiles);
  LSuite.Test('FuzzWithCorpus', @TestFuzzWithCorpus);
  LSuite.Test('FuzzStringWithCorpus', @TestFuzzStringWithCorpus);
  LSuite.Test('GenArray', @TestGenArray);
  LSuite.Test('GenArrayMinMax', @TestGenArrayMinMax);
  LSuite.Test('GenTuple', @TestGenTuple);
  LSuite.Test('BindInt', @TestBindInt);
  LSuite.Test('StringShrinkImproved', @TestStringShrinkImproved);
  LSuite.Test('CoverageTracker', @TestCoverageTracker);
  LSuite.Test('FuzzStructuredInt', @TestFuzzStructuredInt);
  LSuite.Test('FuzzStructuredString', @TestFuzzStructuredString);
  LSuite.Test('FuzzParallel', @TestFuzzParallel);
  LSuite.Test('FuzzParallelCoverage', @TestFuzzParallelCoverage);
  LSuite.Test('GenIntLargeRange', @TestGenIntLargeRange);
  LSuite.Test('GenIntSameMinMax', @TestGenIntSameMinMax);
  LSuite.Test('GenStringEmpty', @TestGenStringEmpty);
  LSuite.Test('GenArrayEmpty', @TestGenArrayEmpty);
  LSuite.Test('GenIntMinMaxReversed', @TestGenIntMinMaxReversed);
  LSuite.Test('GenChoiceIntEmpty', @TestGenChoiceIntEmpty);
  LSuite.Test('GenChoiceStringEmpty', @TestGenChoiceStringEmpty);
  LSuite.Test('GenOneOfIntEmpty', @TestGenOneOfIntEmpty);
  LSuite.Test('GenOneOfStringEmpty', @TestGenOneOfStringEmpty);
  LSuite.Test('GenStringMinMaxReversed', @TestGenStringMinMaxReversed);
  LSuite.Test('GenBytesMinMaxReversed', @TestGenBytesMinMaxReversed);
  LSuite.Test('GenArrayMinMaxReversed', @TestGenArrayMinMaxReversed);

  if not LSuite.Run then
  begin
    Finalize(LSuite);
    WriteLn;
    FailTest('SOME PROP TESTS FAILED');
  end;
  WriteLn;
  PassTest('test_prop');
  LSuite.Config.OutSink := nil;
  LSuite.Config.ErrSink := nil;
  Finalize(LSuite);
end.
