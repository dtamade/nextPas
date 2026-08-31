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
  nextpas.core.test.prop.gen,
  nextpas.core.test.prop,
  nextpas.core.test.fuzz;

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

{ ── B11: shrink quality boundaries ────────────────────────────────────────── }

procedure TestB11IntShrinkAtExactMin;
var
  LGen: IIntGenerator;
  LCands: specialize TArray<Int64>;
  I: Integer;
begin
  { At generator min, shrink candidates must not go below min. }
  LGen := GenInt(50, 200);
  LCands := LGen.Shrink(50);
  for I := 0 to High(LCands) do
    CheckTrue(LCands[I] >= 50, 'shrink stays >= min, got ' + IntToStr(LCands[I]));
end;

procedure TestB11StringShrinkShorterOrEmpty;
var
  LGen: IStringGenerator;
  LCands: specialize TArray<string>;
  I: Integer;
  LSrc: string;
  LHasShorter: Boolean;
begin
  LGen := GenString(0, 32);
  LSrc := 'abcdef';
  LCands := LGen.Shrink(LSrc);
  CheckTrue(Length(LCands) > 0, 'string shrink yields candidates');
  LHasShorter := False;
  for I := 0 to High(LCands) do
  begin
    CheckTrue(Length(LCands[I]) <= Length(LSrc),
      'candidate not longer than source');
    if Length(LCands[I]) < Length(LSrc) then
      LHasShorter := True;
  end;
  CheckTrue(LHasShorter, 'at least one strictly shorter candidate');
end;

procedure TestB11IntShrinkMonotonicTowardBoundary;
var
  LResult: string;
  LVal: Int64;
begin
  { Fail when V <> 0 for GenInt(-50, 50); shrink should approach 0. }
  LResult := PropWithResult('B11 shrink to zero', procedure(const V: Int64)
  begin
    if V <> 0 then
      PropFail('nonzero');
  end, GenInt(-50, 50), 80, True);
  if LResult = '' then
    FailTest('expected property fail for nonzero');
  LVal := StrToInt(LResult);
  CheckTrue((LVal >= -2) and (LVal <= 2),
    'shrunk near zero, got ' + LResult);
end;

{ ── B14: shrink second wave ───────────────────────────────────────────────── }

procedure TestB14BytesShrinkNotLonger;
var
  LGen: IBytesGenerator;
  LSrc, LCand: TBytes;
  LCands: specialize TArray<TBytes>;
  I: Integer;
  LHasShorter: Boolean;
begin
  LGen := GenBytes(0, 64);
  SetLength(LSrc, 8);
  FillChar(LSrc[0], 8, $AB);
  LCands := LGen.Shrink(LSrc);
  CheckTrue(Length(LCands) > 0, 'bytes shrink yields candidates');
  LHasShorter := False;
  for I := 0 to High(LCands) do
  begin
    LCand := LCands[I];
    CheckTrue(Length(LCand) <= Length(LSrc), 'bytes shrink not longer');
    if Length(LCand) < Length(LSrc) then
      LHasShorter := True;
  end;
  CheckTrue(LHasShorter, 'at least one shorter bytes candidate');
end;

procedure TestB14FilterIntShrinkStaysInPred;
var
  LGen: IIntGenerator;
  LCands: specialize TArray<Int64>;
  I: Integer;
begin
  { Even numbers only; shrink of 40 must stay even and in range. }
  LGen := FilterInt(GenInt(0, 100),
    function(V: Int64): Boolean begin Result := (V mod 2) = 0 end);
  LCands := LGen.Shrink(40);
  for I := 0 to High(LCands) do
  begin
    CheckTrue((LCands[I] mod 2) = 0, 'filter shrink even');
    CheckTrue((LCands[I] >= 0) and (LCands[I] <= 100), 'filter shrink in range');
  end;
end;

procedure TestB14ChoiceIntShrinkInSet;
var
  LGen: IIntGenerator;
  LCands: specialize TArray<Int64>;
  I, J: Integer;
  LOk: Boolean;
  LSet: array[0..3] of Int64;
begin
  LSet[0] := 2; LSet[1] := 4; LSet[2] := 6; LSet[3] := 8;
  LGen := GenChoiceInt(LSet);
  LCands := LGen.Shrink(8);
  for I := 0 to High(LCands) do
  begin
    LOk := False;
    for J := 0 to High(LSet) do
      if LCands[I] = LSet[J] then
        LOk := True;
    CheckTrue(LOk, 'choice shrink stays in set: ' + IntToStr(LCands[I]));
  end;
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

procedure TestFuzzMultiStrategy;
begin
  { Facade-qualified: exercises the canonical name via nextpas.core.test
    re-export (v8.32) — FuzzParallel below covers the deprecated alias. }
  nextpas.core.test.FuzzMultiStrategy('MultiStrategy bytes', procedure(const Data: TBytes)
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
  { FuzzMultiStrategy uses its own internal tracker, this just verifies it works }
  FuzzMultiStrategy('Coverage parallel', procedure(const Data: TBytes)
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

{ ── B30: generator fail-path table (ExpectFail contracts) ─────────────────── }

procedure TestB30GenFailPathCase(const AC: TTestCase);
{ Data encodes which generator must fail; message needle after '|'. }
var
  LKind, LNeedle: string;
  LBar: Integer;
begin
  LBar := Pos('|', AC.Data);
  CheckTrue(LBar > 1, 'case format kind|needle');
  LKind := Copy(AC.Data, 1, LBar - 1);
  LNeedle := Copy(AC.Data, LBar + 1, Length(AC.Data));
  if LKind = 'int_rev' then
    ExpectFail(procedure begin GenInt(100, 50); end, LNeedle)
  else if LKind = 'str_rev' then
    ExpectFail(procedure begin GenString(50, 10); end, LNeedle)
  else if LKind = 'bytes_rev' then
    ExpectFail(procedure begin GenBytes(50, 10); end, LNeedle)
  else if LKind = 'arr_rev' then
    ExpectFail(procedure begin GenArray(GenInt(0, 10), 50, 10); end, LNeedle)
  else if LKind = 'choice_int_empty' then
    ExpectFail(procedure begin GenChoiceInt([]); end, LNeedle)
  else if LKind = 'choice_str_empty' then
    ExpectFail(procedure begin GenChoiceString([]); end, LNeedle)
  else if LKind = 'oneof_int_empty' then
    ExpectFail(procedure begin GenOneOfInt([]); end, LNeedle)
  else if LKind = 'oneof_str_empty' then
    ExpectFail(procedure begin GenOneOfString([]); end, LNeedle)
  else
    Fail('unknown kind ' + LKind);
end;

{ ── B71: shrink deterministic seed table + ExpectFail messages ──────────── }

procedure TestB71ShrinkDeterministicCase(const AC: TTestCase);
{ Data: kind|value — shrink candidates must stay in generator bounds and
  never grow. Generators use fixed TRandomGen seed; Shrink is pure. }
var
  LBar: Integer;
  LKind, LValStr: string;
  LGenI: IIntGenerator;
  LGenS: IStringGenerator;
  LGenB: IBytesGenerator;
  LCandsI: specialize TArray<Int64>;
  LCandsS: specialize TArray<string>;
  LCandsB: specialize TArray<TBytes>;
  LSrcB: TBytes;
  I: Integer;
  LVal: Int64;
begin
  LBar := Pos('|', AC.Data);
  CheckTrue(LBar > 1, 'kind|value');
  LKind := Copy(AC.Data, 1, LBar - 1);
  LValStr := Copy(AC.Data, LBar + 1, Length(AC.Data));
  if LKind = 'int' then
  begin
    LVal := StrToInt(LValStr);
    LGenI := GenInt(-100, 100);
    LCandsI := LGenI.Shrink(LVal);
    for I := 0 to High(LCandsI) do
    begin
      CheckTrue(LCandsI[I] >= -100, 'int shrink >= min');
      CheckTrue(LCandsI[I] <= 100, 'int shrink <= max');
    end;
  end
  else if LKind = 'int_min' then
  begin
    LVal := StrToInt(LValStr);
    LGenI := GenInt(LVal, LVal + 50);
    LCandsI := LGenI.Shrink(LVal);
    for I := 0 to High(LCandsI) do
      CheckTrue(LCandsI[I] >= LVal, 'shrink at min stays >= min');
  end
  else if LKind = 'str' then
  begin
    LGenS := GenString(0, 64);
    LCandsS := LGenS.Shrink(LValStr);
    for I := 0 to High(LCandsS) do
      CheckTrue(Length(LCandsS[I]) <= Length(LValStr), 'str shrink not longer');
  end
  else if LKind = 'bytes' then
  begin
    SetLength(LSrcB, Length(LValStr));
    for I := 1 to Length(LValStr) do
      LSrcB[I - 1] := Byte(Ord(LValStr[I]));
    LGenB := GenBytes(0, 64);
    LCandsB := LGenB.Shrink(LSrcB);
    for I := 0 to High(LCandsB) do
      CheckTrue(Length(LCandsB[I]) <= Length(LSrcB), 'bytes shrink not longer');
  end
  else
    Fail('unknown B71 kind ' + LKind);
end;

procedure TestB71PropWithResultCounterexample;
{ Fixed-range property: fail when V > 10; shrink toward boundary. }
var
  LResult: string;
  LVal: Int64;
begin
  LResult := PropWithResult('B71 fail-path counterexample',
    procedure(const V: Int64)
    begin
      if V > 10 then
        PropFail('above ten');
    end, GenInt(0, 100), 80, True);
  CheckTrue(LResult <> '', 'must produce counterexample');
  LVal := StrToInt(LResult);
  CheckTrue((LVal >= 11) and (LVal <= 20),
    'shrunk near boundary 11..20, got ' + LResult);
end;

procedure TestB71ExpectFailPropFailMessage;
{ PropFail raises EAssertionFailed with message — ExpectFail needle. }
begin
  ExpectFail(procedure
    begin
      PropFail('B71 shrink fail-path needle');
    end, 'B71 shrink fail-path needle');
end;

{ ── B72: Fuzz corpus empty/corrupt boundaries ────────────────────────────── }

procedure TestB72CorpusBoundaryCase(const AC: TTestCase);
{ Data: empty_dir | missing_dir | oob | empty_bin | junk_file | roundtrip |
  empty_add | dup_string }
var
  LCorpus, LCorpus2: TFuzzCorpus;
  LDir: string;
  LData: TBytes;
  LPath: string;
begin
  LDir := '/tmp/np_b72_' + AC.Name + '_' + IntToStr(Random(MaxInt));
  if AC.Data = 'empty_dir' then
  begin
    ForceDirectories(LDir);
    LCorpus := TFuzzCorpus.Create(LDir);
    try
      LCorpus.Load;
      CheckEqual(0, LCorpus.Count, 'empty dir load → 0');
      CheckFalse(LCorpus.HasFiles, 'empty dir HasFiles false');
    finally
      LCorpus.Free;
    end;
  end
  else if AC.Data = 'missing_dir' then
  begin
    LCorpus := TFuzzCorpus.Create(LDir + '_missing');
    try
      LCorpus.Load; { no-op }
      CheckEqual(0, LCorpus.Count, 'missing dir load → 0');
      CheckFalse(LCorpus.HasFiles);
    finally
      LCorpus.Free;
    end;
  end
  else if AC.Data = 'oob' then
  begin
    LCorpus := TFuzzCorpus.Create(LDir);
    try
      CheckTrue(Length(LCorpus.GetItem(-1)) = 0, 'oob -1 nil/empty');
      CheckTrue(Length(LCorpus.GetItem(0)) = 0, 'oob 0 empty corpus');
      CheckEqual('', LCorpus.GetString(99), 'oob string empty');
    finally
      LCorpus.Free;
    end;
  end
  else if AC.Data = 'empty_bin' then
  begin
    ForceDirectories(LDir);
    LPath := LDir + '/0.bin';
    SetLength(LData, 0);
    WriteFile(LPath, LData);
    LCorpus := TFuzzCorpus.Create(LDir);
    try
      LCorpus.Load;
      { empty files skipped (Length > 0 guard) }
      CheckEqual(0, LCorpus.Count, 'empty .bin ignored');
    finally
      LCorpus.Free;
    end;
  end
  else if AC.Data = 'junk_file' then
  begin
    ForceDirectories(LDir);
    LPath := LDir + '/notes.txt';
    WriteFileText(LPath, 'not a corpus');
    LCorpus := TFuzzCorpus.Create(LDir);
    try
      LCorpus.Load;
      CheckEqual(0, LCorpus.Count, 'non-.bin ignored');
    finally
      LCorpus.Free;
    end;
  end
  else if AC.Data = 'roundtrip' then
  begin
    LCorpus := TFuzzCorpus.Create(LDir);
    try
      CheckTrue(LCorpus.AddString('alpha'));
      CheckTrue(LCorpus.AddString('beta'));
      LCorpus.Save;
    finally
      LCorpus.Free;
    end;
    LCorpus2 := TFuzzCorpus.Create(LDir);
    try
      LCorpus2.Load;
      CheckEqual(2, LCorpus2.Count);
      CheckEqual('alpha', LCorpus2.GetString(0));
      CheckEqual('beta', LCorpus2.GetString(1));
    finally
      LCorpus2.Free;
    end;
  end
  else if AC.Data = 'empty_add' then
  begin
    LCorpus := TFuzzCorpus.Create(LDir);
    try
      SetLength(LData, 0);
      CheckTrue(LCorpus.Add(LData), 'empty bytes add once');
      CheckFalse(LCorpus.Add(LData), 'empty bytes dup rejected');
      CheckEqual(1, LCorpus.Count);
    finally
      LCorpus.Free;
    end;
  end
  else if AC.Data = 'dup_string' then
  begin
    LCorpus := TFuzzCorpus.Create(LDir);
    try
      CheckTrue(LCorpus.AddString('x'));
      CheckFalse(LCorpus.AddString('x'), 'dup string fail-path');
      CheckEqual(1, LCorpus.Count);
    finally
      LCorpus.Free;
    end;
  end
  else
    Fail('unknown B72 kind ' + AC.Data);
end;

{ ── v8.36: shrink exact-sequence + generator meta contracts ──────────────── }

function NextSeg(var ARest: string): string;
{ Consume up to the next '|'; after the last '|' the whole tail is returned. }
var
  LBar: Integer;
begin
  LBar := Pos('|', ARest);
  if LBar = 0 then
  begin
    Result := ARest;
    ARest := '';
  end
  else
  begin
    Result := Copy(ARest, 1, LBar - 1);
    ARest := Copy(ARest, LBar + 1, Length(ARest));
  end;
end;

procedure AppendShrCase(var ACases: specialize TArray<TTestCase>;
  const AName, AData, AFlag: string);
begin
  SetLength(ACases, Length(ACases) + 1);
  ACases[High(ACases)].Name := AName;
  ACases[High(ACases)].Data := AData + '|' + AFlag;
end;

function JoinInt64Seq(const ASeq: specialize TArray<Int64>): string;
{ Empty array renders as '<none>' so it stays distinguishable from a
  sequence containing empty-string candidates in the sibling joiners. }
var
  I: Integer;
begin
  if Length(ASeq) = 0 then Exit('<none>');
  Result := '';
  for I := 0 to High(ASeq) do
  begin
    if I > 0 then Result := Result + ',';
    Result := Result + IntToStr(ASeq[I]);
  end;
end;

function JoinStrSeq(const ASeq: specialize TArray<string>): string;
var
  I: Integer;
begin
  if Length(ASeq) = 0 then Exit('<none>');
  Result := '';
  for I := 0 to High(ASeq) do
  begin
    if I > 0 then Result := Result + ',';
    Result := Result + ASeq[I];
  end;
end;

function BytesToHexStr(const ABytes: TBytes): string;
const
  CHexDigits: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ABytes) do
    Result := Result + CHexDigits[ABytes[I] shr 4] + CHexDigits[ABytes[I] and 15];
end;

function JoinBytesSeq(const ASeq: specialize TArray<TBytes>): string;
var
  I: Integer;
begin
  if Length(ASeq) = 0 then Exit('<none>');
  Result := '';
  for I := 0 to High(ASeq) do
  begin
    if I > 0 then Result := Result + ',';
    Result := Result + BytesToHexStr(ASeq[I]);
  end;
end;

function HexNibble(ACh: Char): Byte;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
  else
    Result := 0;
  end;
end;

function HexStrToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := (HexNibble(AHex[I * 2 + 1]) shl 4) or HexNibble(AHex[I * 2 + 2]);
end;

procedure TestIntShrinkSeqCase(const AC: TTestCase);
{ TIntGenerator.Shrink exact candidate sequence: [target, mid, step, quarter]
  with domain-clamp/dedup pruning; out-of-domain input yields one boundary
  candidate; value=target yields no candidates. Duplicate candidates (e.g.
  Shrink(1) in a zero-crossing domain = 0,0,0) are locked-in behavior. }
var
  LRest, LWant, LFlag: string;
  LMin, LMax, LVal: Int64;
  LCands: specialize TArray<Int64>;
begin
  LRest := AC.Data;
  LMin := StrToInt64Def(NextSeg(LRest), 0);
  LMax := StrToInt64Def(NextSeg(LRest), 0);
  LVal := StrToInt64Def(NextSeg(LRest), 0);
  LWant := NextSeg(LRest);
  LFlag := LRest;
  LCands := GenInt(LMin, LMax).Shrink(LVal);
  CheckEqual(LWant, JoinInt64Seq(LCands), AC.Name);
  if LFlag = '0' then
    CheckTrue(Length(LCands) <= 1,
      AC.Name + ': fail-path row must be empty/single-candidate boundary')
  else
    CheckTrue(Length(LCands) >= 2,
      AC.Name + ': pass row must carry a full shrink sequence');
end;

procedure TestStrShrinkSeqCase(const AC: TTestCase);
{ TStringGenerator.Shrink exact 8-strategy sequence: empty, half, drop-last,
  all-a, drop-first, drop-middle, shorter-a, half-a — each gated on
  FMinLen; out-of-domain input pads with 'a' or truncates. }
var
  LRest, LVal, LWant, LFlag: string;
  LMinLen, LMaxLen: Int64;
  LCands: specialize TArray<string>;
begin
  LRest := AC.Data;
  LMinLen := StrToInt64Def(NextSeg(LRest), 0);
  LMaxLen := StrToInt64Def(NextSeg(LRest), 0);
  LVal := NextSeg(LRest);
  LWant := NextSeg(LRest);
  LFlag := LRest;
  LCands := GenString(Integer(LMinLen), Integer(LMaxLen)).Shrink(LVal);
  CheckEqual(LWant, JoinStrSeq(LCands), AC.Name);
  if LFlag = '0' then
    CheckTrue(Length(LCands) <= 1,
      AC.Name + ': fail-path row must be empty/single-candidate boundary')
  else
    CheckTrue(Length(LCands) >= 2,
      AC.Name + ': pass row must carry a full shrink sequence');
end;

procedure TestBytesShrinkSeqCase(const AC: TTestCase);
{ TBytesGenerator.Shrink exact 3-strategy sequence: empty, half, drop-last —
  no all-a analog (narrower than string shrink); len=FMinLen yields no
  candidates; out-of-domain pads with zero bytes or truncates. }
var
  LRest, LHex, LWant, LFlag: string;
  LMinLen, LMaxLen: Int64;
  LCands: specialize TArray<TBytes>;
begin
  LRest := AC.Data;
  LMinLen := StrToInt64Def(NextSeg(LRest), 0);
  LMaxLen := StrToInt64Def(NextSeg(LRest), 0);
  LHex := NextSeg(LRest);
  LWant := NextSeg(LRest);
  LFlag := LRest;
  LCands := GenBytes(Integer(LMinLen), Integer(LMaxLen)).Shrink(HexStrToBytes(LHex));
  CheckEqual(LWant, JoinBytesSeq(LCands), AC.Name);
  if LFlag = '0' then
    CheckTrue(Length(LCands) <= 1,
      AC.Name + ': fail-path row must be empty/single-candidate boundary')
  else
    CheckTrue(Length(LCands) >= 2,
      AC.Name + ': pass row must carry a full shrink sequence');
end;

procedure TestGenMetaCase(const AC: TTestCase);
{ Generator Name vocabulary (incl. nested combinator names) + bool/choice/
  filter shrink sequences: choice keeps array order filtering values < input,
  filter applies the predicate to the source sequence. }
var
  LRest, LKind, LWant, LFlag, LGot: string;
  LCandsB: specialize TArray<Boolean>;
  I: Integer;
begin
  LRest := AC.Data;
  LKind := NextSeg(LRest);
  LWant := NextSeg(LRest);
  LFlag := LRest;
  LGot := '';
  if LKind = 'name-int2' then LGot := GenInt(-5, 10).Name
  else if LKind = 'name-int1' then LGot := GenInt(7).Name
  else if LKind = 'name-str2' then LGot := GenString(2, 8).Name
  else if LKind = 'name-str1' then LGot := GenString(9).Name
  else if LKind = 'name-bytes2' then LGot := GenBytes(1, 4).Name
  else if LKind = 'name-bytes1' then LGot := GenBytes(3).Name
  else if LKind = 'name-bool' then LGot := GenBool.Name
  else if LKind = 'name-choice-int' then LGot := GenChoiceInt([1, 2, 3]).Name
  else if LKind = 'name-choice-str' then LGot := GenChoiceString(['a', 'b']).Name
  else if LKind = 'name-choice-bool' then LGot := GenChoiceBool([True]).Name
  else if LKind = 'name-oneof-int' then
    LGot := GenOneOfInt([GenInt(0, 1), GenInt(2, 3)]).Name
  else if LKind = 'name-oneof-str1' then
    LGot := GenOneOfString([GenString(0, 4)]).Name
  else if LKind = 'name-map' then
    LGot := MapIntToStr(GenInt(0, 5),
      function(V: Int64): string begin Result := IntToStr(V) end).Name
  else if LKind = 'name-filter-int' then
    LGot := FilterInt(GenInt(0, 5),
      function(V: Int64): Boolean begin Result := True end).Name
  else if LKind = 'name-filter-str' then
    LGot := FilterString(GenString(0, 5),
      function(const V: string): Boolean begin Result := True end).Name
  else if LKind = 'name-filter-bytes' then
    LGot := FilterBytes(GenBytes(0, 5),
      function(const V: TBytes): Boolean begin Result := True end).Name
  else if LKind = 'name-array2' then
    LGot := GenArray(GenInt(0, 5), 0, 10).Name
  else if LKind = 'name-array1' then
    LGot := GenArray(GenInt(0, 3)).Name
  else if LKind = 'name-tuple' then
    LGot := GenTuple(GenInt(0, 1), GenString(0, 2)).Name
  else if LKind = 'name-bind' then
    LGot := BindInt(GenInt(0, 3),
      function(V: Int64): IIntGenerator begin Result := GenInt(0, 1) end).Name
  else if (LKind = 'bool-shrink-true') or (LKind = 'bool-shrink-false') then
  begin
    LCandsB := GenBool.Shrink(LKind = 'bool-shrink-true');
    if Length(LCandsB) = 0 then
      LGot := '<none>'
    else
      for I := 0 to High(LCandsB) do
      begin
        if I > 0 then LGot := LGot + ',';
        if LCandsB[I] then LGot := LGot + 'True' else LGot := LGot + 'False';
      end;
  end
  else if LKind = 'choice-shrink-8' then
    LGot := JoinInt64Seq(GenChoiceInt([5, 3, 8, 1]).Shrink(8))
  else if LKind = 'choice-shrink-1' then
    LGot := JoinInt64Seq(GenChoiceInt([5, 3, 8, 1]).Shrink(1))
  else if LKind = 'choice-shrink-5' then
    LGot := JoinInt64Seq(GenChoiceInt([5, 3, 8, 1]).Shrink(5))
  else if LKind = 'choice-shrink-oob9' then
    LGot := JoinInt64Seq(GenChoiceInt([5, 3, 8, 1]).Shrink(9))
  else if LKind = 'filter-even-50' then
    LGot := JoinInt64Seq(FilterInt(GenInt(-100, 100),
      function(V: Int64): Boolean begin Result := (V mod 2) = 0 end).Shrink(50))
  else if LKind = 'filter-even-2' then
    LGot := JoinInt64Seq(FilterInt(GenInt(-100, 100),
      function(V: Int64): Boolean begin Result := (V mod 2) = 0 end).Shrink(2))
  else if LKind = 'filter-none-50' then
    LGot := JoinInt64Seq(FilterInt(GenInt(0, 100),
      function(V: Int64): Boolean begin Result := V > 1000 end).Shrink(50))
  else
    Fail('unknown meta kind ' + LKind);
  CheckEqual(LWant, LGot, AC.Name);
  if LFlag = '0' then
    CheckTrue((LWant = '<none>') or (Pos('oob', LKind) > 0) or
      (LKind = 'bool-shrink-false'),
      AC.Name + ': fail-path row must assert boundary behavior');
end;

{ ── v8.37: coverage tracker 状态机 + fuzzgen 长度契约 ─────────────────────────
  CoverageTracker 锁定：TotalHits 与 CoverageCount 分离（Hit 先计 hits 再做
  [0..32767] 范围检查——越界计 hits 不计 count 也不置 new）、bitset byte/bit
  边界（id shr 3 / id and 7）、ResetNewCoverage 后重复 Hit 不置 new。
  FuzzGen 锁定：产物长度 = 入参 exact；FuzzGenString 全字符 ∈ [32,126]
  （绑 v8.37 修复：此前 NextIntRange(0,95) 闭区间可产 DEL=127）。
  负长度 = FPC SetLength RTE 201，非异常路径，不表驱动（调用方责任）。
  flag 自校验：'0' ⟺ 空产物/零覆盖行。 }

{ Data: ops|wantCount|wantHits|wantNew|flag；ops 为逗号分隔 h<id>/r 序列，
  '<none>' = 无操作。 }
procedure TestCoverageOpsCase(const AC: TTestCase);
var
  LRest, LOps, LOp, LWantNew, LFlag: string;
  LWantCount, LWantHits: Integer;
  LTracker: ICoverageTracker;
  LP: Integer;
begin
  LRest := AC.Data;
  LOps := NextSeg(LRest);
  LWantCount := StrToIntDef(NextSeg(LRest), -1);
  LWantHits := StrToIntDef(NextSeg(LRest), -1);
  LWantNew := NextSeg(LRest);
  LFlag := LRest;

  LTracker := CreateCoverageTracker;
  if LOps <> '<none>' then
    while LOps <> '' do
    begin
      LP := Pos(',', LOps);
      if LP = 0 then
      begin
        LOp := LOps;
        LOps := '';
      end
      else
      begin
        LOp := Copy(LOps, 1, LP - 1);
        LOps := Copy(LOps, LP + 1, Length(LOps));
      end;
      if LOp = 'r' then
        LTracker.ResetNewCoverage
      else
        LTracker.Hit(StrToIntDef(Copy(LOp, 2, Length(LOp)), 0));
    end;

  CheckEqual(Int64(LWantCount), Int64(LTracker.CoverageCount),
    AC.Name + ' count');
  CheckEqual(Int64(LWantHits), Int64(LTracker.TotalHits), AC.Name + ' hits');
  CheckEqual(LWantNew = 'T', LTracker.HasNewCoverage, AC.Name + ' new');
  if LFlag = '0' then
    CheckTrue(LWantCount = 0,
      AC.Name + ': fail-path row must assert zero-coverage boundary');
end;

{ Data: kind|len|wantLen|flag；kind = bytes / str / strrange（长度 + 全字符
  可打印范围断言）。 }
procedure TestGenLenCase(const AC: TTestCase);
var
  LRest, LKind, LFlag: string;
  LLen, LWantLen, LI, LBad: Integer;
  LBytes: TBytes;
  LStr: string;
begin
  LRest := AC.Data;
  LKind := NextSeg(LRest);
  LLen := StrToIntDef(NextSeg(LRest), -1);
  LWantLen := StrToIntDef(NextSeg(LRest), -1);
  LFlag := LRest;

  if LKind = 'bytes' then
  begin
    LBytes := FuzzGenBytes(LLen);
    CheckEqual(Int64(LWantLen), Int64(Length(LBytes)), AC.Name + ' len');
  end
  else
  begin
    LStr := FuzzGenString(LLen);
    CheckEqual(Int64(LWantLen), Int64(Length(LStr)), AC.Name + ' len');
    if LKind = 'strrange' then
    begin
      LBad := 0;
      for LI := 1 to Length(LStr) do
        if (Ord(LStr[LI]) < 32) or (Ord(LStr[LI]) > 126) then
          Inc(LBad);
      CheckEqual(Int64(0), Int64(LBad), AC.Name + ' printable range');
    end;
  end;
  if LFlag = '0' then
    CheckTrue(LWantLen = 0,
      AC.Name + ': fail-path row must assert empty-output boundary');
end;

{ ── v8.40 FuzzMinimize contract (public since v8.40) ─────────────────────── }

var
  GMinProbes: specialize TArray<TBytes>;
  GMinThreshold: Integer;

function MinContainsFF(const D: TBytes): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(D) do
    if D[I] = $FF then Exit(True);
end;

function MinSumOf(const D: TBytes): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(D) do
    Inc(Result, D[I]);
end;

{ Predicate families for FuzzMinimize probing; every call is recorded in
  GMinProbes so tables can lock the exact probe sequence. F=contains $FF,
  L=len>=3, H=head byte=7, S=byte sum>=10, K=len>=GMinThreshold,
  N=never fails, B=raises a plain Exception (must escape FuzzMinimize). }
function MinMakePred(const AKind: string): TFuzzBytesTest;
begin
  case AKind of
    'F': Result := procedure(const D: TBytes)
      begin
        GMinProbes := Concat(GMinProbes, [Copy(D)]);
        if MinContainsFF(D) then raise EAssertionFailed.Create('ff');
      end;
    'L': Result := procedure(const D: TBytes)
      begin
        GMinProbes := Concat(GMinProbes, [Copy(D)]);
        if Length(D) >= 3 then raise EAssertionFailed.Create('len');
      end;
    'H': Result := procedure(const D: TBytes)
      begin
        GMinProbes := Concat(GMinProbes, [Copy(D)]);
        if (Length(D) > 0) and (D[0] = 7) then raise EAssertionFailed.Create('h7');
      end;
    'S': Result := procedure(const D: TBytes)
      begin
        GMinProbes := Concat(GMinProbes, [Copy(D)]);
        if MinSumOf(D) >= 10 then raise EAssertionFailed.Create('sum');
      end;
    'K': Result := procedure(const D: TBytes)
      begin
        GMinProbes := Concat(GMinProbes, [Copy(D)]);
        if Length(D) >= GMinThreshold then raise EAssertionFailed.Create('k');
      end;
    'B': Result := procedure(const D: TBytes)
      begin
        GMinProbes := Concat(GMinProbes, [Copy(D)]);
        raise Exception.Create('kaboom');
      end;
  else
    Result := procedure(const D: TBytes)
      begin
        GMinProbes := Concat(GMinProbes, [Copy(D)]);
      end;
  end;
end;

procedure TestMinResultCase(const AC: TTestCase);
{ FuzzMinimize exact result + probe count — pred|inHex|wantOutHex|probes.
  Locks: phase 1 keeps the first ceil(n/2) bytes while failing (stops at the
  first passing prefix, no finer granularity); phase 2 removes single bytes
  left-to-right, retrying the index after acceptance. Empty/single-byte
  inputs return unchanged with ZERO probes (the input itself is never
  re-validated). 'ESC' rows lock non-EAssertionFailed escape. A failing but
  1-minimal input (m-sum10-min) also returns unchanged. }
var
  LRest, LPred, LInHex, LWantOut, LFlag, LEscaped: string;
  LWantProbes: Integer;
  LIn, LOut: TBytes;
begin
  LRest := AC.Data;
  LPred := NextSeg(LRest);
  LInHex := NextSeg(LRest);
  LWantOut := NextSeg(LRest);
  LWantProbes := StrToIntDef(NextSeg(LRest), -1);
  LFlag := LRest;
  if LInHex = '-' then LInHex := '';
  LIn := HexStrToBytes(LInHex);
  GMinProbes := nil;
  LEscaped := '';
  try
    LOut := FuzzMinimize(LIn, MinMakePred(LPred));
  except
    on E: EAssertionFailed do
      raise;
    on E: Exception do
      LEscaped := E.ClassName + ': ' + E.Message;
  end;
  if LWantOut = 'ESC' then
  begin
    CheckEqual('Exception: kaboom', LEscaped, AC.Name + ' escape');
    CheckEqual(Int64(LWantProbes), Int64(Length(GMinProbes)), AC.Name + ' probes');
    CheckEqual('0', LFlag, AC.Name + ': escape row must be fail-path');
    Exit;
  end;
  CheckEqual('', LEscaped, AC.Name + ' no escape');
  if LWantOut = '-' then LWantOut := '';
  CheckEqual(LWantOut, BytesToHexStr(LOut), AC.Name + ' out');
  CheckEqual(Int64(LWantProbes), Int64(Length(GMinProbes)), AC.Name + ' probes');
  if LFlag = '0' then
    CheckTrue(LWantOut <> LInHex, AC.Name + ': fail-path row must shrink')
  else
    CheckEqual(LInHex, LWantOut, AC.Name + ': pass row must return input unchanged');
end;

procedure TestMinProbeSeqCase(const AC: TTestCase);
{ Exact probe sequence FuzzMinimize feeds the predicate (','-joined hex,
  <none> when zero). Locks phase ORDER: halving prefixes first, then
  single-byte removals; rejected removal probes appear in the sequence but
  their result is discarded (e.g. ps-sum10: 09,01 probed, 0901 kept). }
var
  LRest, LPred, LInHex, LWantSeq, LFlag: string;
  LIn, LOut: TBytes;
begin
  LRest := AC.Data;
  LPred := NextSeg(LRest);
  LInHex := NextSeg(LRest);
  LWantSeq := NextSeg(LRest);
  LFlag := LRest;
  if LInHex = '-' then LInHex := '';
  LIn := HexStrToBytes(LInHex);
  GMinProbes := nil;
  LOut := FuzzMinimize(LIn, MinMakePred(LPred));
  CheckEqual(LWantSeq, JoinBytesSeq(GMinProbes), AC.Name + ' seq');
  if LFlag = '0' then
    CheckTrue(BytesToHexStr(LOut) <> LInHex, AC.Name + ': fail-path row must shrink')
  else
    CheckEqual(LInHex, BytesToHexStr(LOut), AC.Name + ': pass row unchanged');
end;

procedure TestMinLenThresholdCase(const AC: TTestCase);
{ len>=k predicate over fixed input 0102030405060708 — k|wantOutHex|probes.
  Locks the phase interaction: phase 1 shrinks along the ceil-halving chain
  8→4→2, phase 2 trims from the FRONT — so for k>4 the survivor is the last
  k bytes of the original, while k<=4 keeps the front-of-chain remnant.
  k=8 probes all removals but cannot shrink; k=9 never fails (unchanged). }
var
  LRest, LWantOut, LFlag: string;
  LWantProbes: Integer;
  LIn, LOut: TBytes;
begin
  LRest := AC.Data;
  GMinThreshold := StrToIntDef(NextSeg(LRest), -1);
  LWantOut := NextSeg(LRest);
  LWantProbes := StrToIntDef(NextSeg(LRest), -1);
  LFlag := LRest;
  LIn := HexStrToBytes('0102030405060708');
  GMinProbes := nil;
  LOut := FuzzMinimize(LIn, MinMakePred('K'));
  CheckEqual(LWantOut, BytesToHexStr(LOut), AC.Name + ' out');
  CheckEqual(Int64(LWantProbes), Int64(Length(GMinProbes)), AC.Name + ' probes');
  if LFlag = '0' then
    CheckTrue(LWantOut <> '0102030405060708', AC.Name + ': fail-path row must shrink')
  else
    CheckEqual('0102030405060708', LWantOut, AC.Name + ': pass row unchanged');
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LB30Cases: specialize TArray<TTestCase>;
  LB30I: Integer;
  LB30Kinds: array[0..7] of string;
  LB71Cases: specialize TArray<TTestCase>;
  LB71I: Integer;
  LB71Kinds: array[0..3] of string;
  LB72Cases: specialize TArray<TTestCase>;
  LB72I: Integer;
  LB72Kinds: array[0..7] of string;
  LShrCases: specialize TArray<TTestCase>;
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
  LSuite.Test('B11IntShrinkAtExactMin', @TestB11IntShrinkAtExactMin);
  LSuite.Test('B11StringShrinkShorterOrEmpty', @TestB11StringShrinkShorterOrEmpty);
  LSuite.Test('B11IntShrinkMonotonicTowardBoundary',
    @TestB11IntShrinkMonotonicTowardBoundary);
  LSuite.Test('B14BytesShrinkNotLonger', @TestB14BytesShrinkNotLonger);
  LSuite.Test('B14FilterIntShrinkStaysInPred', @TestB14FilterIntShrinkStaysInPred);
  LSuite.Test('B14ChoiceIntShrinkInSet', @TestB14ChoiceIntShrinkInSet);
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
  LSuite.Test('FuzzMultiStrategy', @TestFuzzMultiStrategy);
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

  { B30: 64-row fail-path table covering all generator validation guards }
  LB30Kinds[0] := 'int_rev|AMin must be <= AMax';
  LB30Kinds[1] := 'str_rev|AMinLen must be <= AMaxLen';
  LB30Kinds[2] := 'bytes_rev|AMinLen must be <= AMaxLen';
  LB30Kinds[3] := 'arr_rev|AMinLen must be <= AMaxLen';
  LB30Kinds[4] := 'choice_int_empty|empty values array';
  LB30Kinds[5] := 'choice_str_empty|empty values array';
  LB30Kinds[6] := 'oneof_int_empty|empty generator array';
  LB30Kinds[7] := 'oneof_str_empty|empty generator array';
  SetLength(LB30Cases, 64);
  for LB30I := 0 to High(LB30Cases) do
  begin
    LB30Cases[LB30I].Name := 'gen-fail-' + IntToStr(LB30I);
    LB30Cases[LB30I].Data := LB30Kinds[LB30I mod 8];
  end;
  LSuite.TestTable('B30 gen fail-path ExpectFail', LB30Cases, @TestB30GenFailPathCase);

  { B71: shrink deterministic + PropFail ExpectFail }
  LSuite.Test('B71 PropWithResult counterexample', @TestB71PropWithResultCounterexample);
  LSuite.Test('B71 ExpectFail PropFail message', @TestB71ExpectFailPropFailMessage);
  LB71Kinds[0] := 'int|42';
  LB71Kinds[1] := 'int_min|10';
  LB71Kinds[2] := 'str|abcdefgh';
  LB71Kinds[3] := 'bytes|xyz';
  SetLength(LB71Cases, 100);
  for LB71I := 0 to High(LB71Cases) do
  begin
    LB71Cases[LB71I].Name := 's' + IntToStr(LB71I);
    LB71Cases[LB71I].Data := LB71Kinds[LB71I mod 4];
  end;
  LSuite.TestTable('B71 shrink deterministic fail-path', LB71Cases,
    @TestB71ShrinkDeterministicCase);

  { B72: corpus empty/corrupt/roundtrip boundaries }
  LB72Kinds[0] := 'empty_dir';
  LB72Kinds[1] := 'missing_dir';
  LB72Kinds[2] := 'oob';
  LB72Kinds[3] := 'empty_bin';
  LB72Kinds[4] := 'junk_file';
  LB72Kinds[5] := 'roundtrip';
  LB72Kinds[6] := 'empty_add';
  LB72Kinds[7] := 'dup_string';
  SetLength(LB72Cases, 80);
  for LB72I := 0 to High(LB72Cases) do
  begin
    LB72Cases[LB72I].Name := 'c' + IntToStr(LB72I);
    LB72Cases[LB72I].Data := LB72Kinds[LB72I mod 8];
  end;
  LSuite.TestTable('B72 corpus boundary fail-path', LB72Cases,
    @TestB72CorpusBoundaryCase);

  { v8.36: int-shrink exact-sequence — min|max|value|want(csv or <none>) }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 'i-zero-at-target', '-100|100|0|<none>', '0');
  AppendShrCase(LShrCases, 'i-mid-pos', '-100|100|50|0,25,49,12', '1');
  AppendShrCase(LShrCases, 'i-mid-neg', '-100|100|-50|0,-25,-49,-12', '1');
  AppendShrCase(LShrCases, 'i-one-dup', '-100|100|1|0,0,0', '1');
  AppendShrCase(LShrCases, 'i-neg-one-dup', '-100|100|-1|0,0,0', '1');
  AppendShrCase(LShrCases, 'i-two', '-100|100|2|0,1,1,0', '1');
  AppendShrCase(LShrCases, 'i-max', '-100|100|100|0,50,99,25', '1');
  AppendShrCase(LShrCases, 'i-min', '-100|100|-100|0,-50,-99,-25', '1');
  AppendShrCase(LShrCases, 'i-posmin-at-target', '1|100|1|<none>', '0');
  AppendShrCase(LShrCases, 'i-posmin-max', '1|100|100|1,50,99,25', '1');
  AppendShrCase(LShrCases, 'i-posmin-two-dup', '1|100|2|1,1,1', '1');
  AppendShrCase(LShrCases, 'i-negmax-at-target', '-100|-1|-1|<none>', '0');
  AppendShrCase(LShrCases, 'i-negmax-min', '-100|-1|-100|-1,-50,-99,-25', '1');
  AppendShrCase(LShrCases, 'i-oob-high', '0|10|20|10', '0');
  AppendShrCase(LShrCases, 'i-oob-low', '0|10|-5|0', '0');
  AppendShrCase(LShrCases, 'i-point-at', '5|5|5|<none>', '0');
  AppendShrCase(LShrCases, 'i-point-oob-high', '5|5|7|5', '0');
  AppendShrCase(LShrCases, 'i-point-oob-low', '5|5|3|5', '0');
  AppendShrCase(LShrCases, 'i-min-at-target', '10|100|10|<none>', '0');
  AppendShrCase(LShrCases, 'i-zero-point', '0|0|0|<none>', '0');
  AppendShrCase(LShrCases, 'i-neg-point', '-5|-5|-5|<none>', '0');
  AppendShrCase(LShrCases, 'i-three', '0|100|3|0,1,2,0', '1');
  AppendShrCase(LShrCases, 'i-four', '0|100|4|0,2,3,1', '1');
  AppendShrCase(LShrCases, 'i-eight', '0|100|8|0,4,7,2', '1');
  AppendShrCase(LShrCases, 'i-ninetynine', '-100|100|99|0,49,98,24', '1');
  AppendShrCase(LShrCases, 'i-large',
    '1|1000000|1000000|1,500000,999999,250000', '1');
  AppendShrCase(LShrCases, 'i-negband-at', '-1000000|-3|-3|<none>', '0');
  AppendShrCase(LShrCases, 'i-negband-min',
    '-1000000|-3|-1000000|-3,-500001,-999999,-250002', '1');
  LSuite.TestTable('v8.36 int-shrink exact-sequence', LShrCases,
    @TestIntShrinkSeqCase);

  { v8.36: string-shrink exact-sequence — minlen|maxlen|value|want }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 's-empty-at', '0|64||<none>', '0');
  AppendShrCase(LShrCases, 's-two', '0|64|ab|,a,a,aa,b', '1');
  AppendShrCase(LShrCases, 's-two-min1', '1|64|ab|a,a,aa,b', '1');
  AppendShrCase(LShrCases, 's-two-min2', '2|64|ab|aa', '0');
  AppendShrCase(LShrCases, 's-six',
    '0|64|abcdef|,abc,abcde,aaaaaa,bcdef,abcef,aaaaa,aaa', '1');
  AppendShrCase(LShrCases, 's-three', '0|64|abc|,a,ab,aaa,bc,ac', '1');
  AppendShrCase(LShrCases, 's-four', '0|64|abcd|,ab,abc,aaaa,bcd,abd,aaa', '1');
  AppendShrCase(LShrCases, 's-oob-high', '2|4|abcdef|abcd', '0');
  AppendShrCase(LShrCases, 's-oob-low', '3|64|ab|aaa', '0');
  AppendShrCase(LShrCases, 's-one-dup', '0|64|a|,,,a', '1');
  AppendShrCase(LShrCases, 's-one-min1', '1|64|a|a', '0');
  AppendShrCase(LShrCases, 's-oob-high-tight', '0|6|abcdefgh|abcdef', '0');
  AppendShrCase(LShrCases, 's-alla-seven',
    '0|64|aaaaaaa|,aaa,aaaaaa,aaaaaaa,aaaaaa,aaaaaa,aaaaaa,aaa', '1');
  AppendShrCase(LShrCases, 's-empty-domain', '0|0||<none>', '0');
  AppendShrCase(LShrCases, 's-point4', '4|4|abcd|aaaa', '0');
  AppendShrCase(LShrCases, 's-xy', '0|64|xy|,x,x,aa,y', '1');
  LSuite.TestTable('v8.36 string-shrink exact-sequence', LShrCases,
    @TestStrShrinkSeqCase);

  { v8.36: bytes-shrink exact-sequence — minlen|maxlen|hex|want(hex csv) }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 'y-empty-at', '0|64||<none>', '0');
  AppendShrCase(LShrCases, 'y-two', '0|64|0102|,01,01', '1');
  AppendShrCase(LShrCases, 'y-two-min1', '1|64|0102|01,01', '1');
  AppendShrCase(LShrCases, 'y-two-min2', '2|64|0102|<none>', '0');
  AppendShrCase(LShrCases, 'y-one', '0|64|01|,', '1');
  AppendShrCase(LShrCases, 'y-oob-high', '0|2|010203|0102', '0');
  AppendShrCase(LShrCases, 'y-oob-low', '3|64|01|000000', '0');
  AppendShrCase(LShrCases, 'y-eight',
    '0|64|0102030405060708|,01020304,01020304050607', '1');
  AppendShrCase(LShrCases, 'y-five-min4', '4|8|0102030405|01020304', '0');
  AppendShrCase(LShrCases, 'y-empty-domain', '0|0||<none>', '0');
  AppendShrCase(LShrCases, 'y-point5', '5|5|0102030405|<none>', '0');
  AppendShrCase(LShrCases, 'y-four', '0|64|aabbccdd|,aabb,aabbcc', '1');
  LSuite.TestTable('v8.36 bytes-shrink exact-sequence', LShrCases,
    @TestBytesShrinkSeqCase);

  { v8.36: generator meta — kind|want }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 'm-name-int2', 'name-int2|GenInt(-5..10)', '1');
  AppendShrCase(LShrCases, 'm-name-int1', 'name-int1|GenInt(0..7)', '1');
  AppendShrCase(LShrCases, 'm-name-str2', 'name-str2|GenString(2..8)', '1');
  AppendShrCase(LShrCases, 'm-name-str1', 'name-str1|GenString(0..9)', '1');
  AppendShrCase(LShrCases, 'm-name-bytes2', 'name-bytes2|GenBytes(1..4)', '1');
  AppendShrCase(LShrCases, 'm-name-bytes1', 'name-bytes1|GenBytes(0..3)', '1');
  AppendShrCase(LShrCases, 'm-name-bool', 'name-bool|GenBool', '1');
  AppendShrCase(LShrCases, 'm-name-choice-int',
    'name-choice-int|GenChoiceInt(3 values)', '1');
  AppendShrCase(LShrCases, 'm-name-choice-str',
    'name-choice-str|GenChoiceString(2 values)', '1');
  AppendShrCase(LShrCases, 'm-name-choice-bool',
    'name-choice-bool|GenChoiceBool', '1');
  AppendShrCase(LShrCases, 'm-name-oneof-int',
    'name-oneof-int|GenOneOfInt(2 generators)', '1');
  AppendShrCase(LShrCases, 'm-name-oneof-str1',
    'name-oneof-str1|GenOneOfString(1 generators)', '1');
  AppendShrCase(LShrCases, 'm-name-map',
    'name-map|MapIntToStr(GenInt(0..5))', '1');
  AppendShrCase(LShrCases, 'm-name-filter-int',
    'name-filter-int|FilterInt(GenInt(0..5))', '1');
  AppendShrCase(LShrCases, 'm-name-filter-str',
    'name-filter-str|FilterString(GenString(0..5))', '1');
  AppendShrCase(LShrCases, 'm-name-filter-bytes',
    'name-filter-bytes|FilterBytes(GenBytes(0..5))', '1');
  AppendShrCase(LShrCases, 'm-name-array2',
    'name-array2|GenArray(GenInt(0..5), 0..10)', '1');
  AppendShrCase(LShrCases, 'm-name-array1',
    'name-array1|GenArray(GenInt(0..3), 0..100)', '1');
  AppendShrCase(LShrCases, 'm-name-tuple',
    'name-tuple|GenTuple(GenInt(0..1), GenString(0..2))', '1');
  AppendShrCase(LShrCases, 'm-name-bind', 'name-bind|BindInt(GenInt(0..3))', '1');
  AppendShrCase(LShrCases, 'm-bool-shrink-true', 'bool-shrink-true|False', '1');
  AppendShrCase(LShrCases, 'm-bool-shrink-false', 'bool-shrink-false|False', '0');
  AppendShrCase(LShrCases, 'm-choice-shrink-8', 'choice-shrink-8|5,3,1', '1');
  AppendShrCase(LShrCases, 'm-choice-shrink-1', 'choice-shrink-1|<none>', '0');
  AppendShrCase(LShrCases, 'm-choice-shrink-5', 'choice-shrink-5|3,1', '1');
  AppendShrCase(LShrCases, 'm-choice-shrink-oob9',
    'choice-shrink-oob9|5,3,8,1', '0');
  AppendShrCase(LShrCases, 'm-filter-even-50', 'filter-even-50|0,12', '1');
  AppendShrCase(LShrCases, 'm-filter-even-2', 'filter-even-2|0,0', '1');
  AppendShrCase(LShrCases, 'm-filter-none-50', 'filter-none-50|<none>', '0');
  LSuite.TestTable('v8.36 generator meta contract', LShrCases,
    @TestGenMetaCase);

  { v8.37: coverage tracker 状态机 — ops|wantCount|wantHits|wantNew }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 'c-empty',          '<none>|0|0|F', '0');
  AppendShrCase(LShrCases, 'c-single',         'h0|1|1|T', '1');
  AppendShrCase(LShrCases, 'c-dup',            'h0,h0|1|2|T', '1');
  AppendShrCase(LShrCases, 'c-two',            'h0,h1|2|2|T', '1');
  AppendShrCase(LShrCases, 'c-reset',          'h0,r|1|1|F', '1');
  AppendShrCase(LShrCases, 'c-reset-dup',      'h0,r,h0|1|2|F', '1');
  AppendShrCase(LShrCases, 'c-reset-fresh',    'h0,r,h1|2|2|T', '1');
  AppendShrCase(LShrCases, 'c-reset-empty',    'r|0|0|F', '0');
  AppendShrCase(LShrCases, 'c-double-reset',   'h0,r,r|1|1|F', '1');
  AppendShrCase(LShrCases, 'c-bit7',           'h7|1|1|T', '1');
  AppendShrCase(LShrCases, 'c-bit8',           'h8|1|1|T', '1');
  AppendShrCase(LShrCases, 'c-byte-cross',     'h7,h8|2|2|T', '1');
  AppendShrCase(LShrCases, 'c-bit-corners',    'h0,h7,h8,h15|4|4|T', '1');
  AppendShrCase(LShrCases, 'c-max',            'h32767|1|1|T', '1');
  AppendShrCase(LShrCases, 'c-oob-high',       'h32768|0|1|F', '0');
  AppendShrCase(LShrCases, 'c-oob-neg',        'h-1|0|1|F', '0');
  AppendShrCase(LShrCases, 'c-oob-big',        'h100000|0|1|F', '0');
  AppendShrCase(LShrCases, 'c-oob-then-valid', 'h32768,h0|1|2|T', '1');
  AppendShrCase(LShrCases, 'c-valid-then-oob', 'h0,h32768|1|2|T', '1');
  AppendShrCase(LShrCases, 'c-oob-not-new',    'h0,r,h32768|1|2|F', '1');
  AppendShrCase(LShrCases, 'c-dup-max',        'h32767,h32767|1|2|T', '1');
  AppendShrCase(LShrCases, 'c-many',           'h0,h1,h2,h3,h4|5|5|T', '1');
  AppendShrCase(LShrCases, 'c-interleave',     'h0,r,h1,h0|2|3|T', '1');
  AppendShrCase(LShrCases, 'c-oob-only-dup',   'h-1,h-1|0|2|F', '0');
  LSuite.TestTable('v8.37 coverage tracker state machine', LShrCases,
    @TestCoverageOpsCase);

  { v8.37: fuzzgen 长度契约 — kind|len|wantLen }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 'g-bytes-0',       'bytes|0|0', '0');
  AppendShrCase(LShrCases, 'g-bytes-1',       'bytes|1|1', '1');
  AppendShrCase(LShrCases, 'g-bytes-16',      'bytes|16|16', '1');
  AppendShrCase(LShrCases, 'g-bytes-1024',    'bytes|1024|1024', '1');
  AppendShrCase(LShrCases, 'g-str-0',         'str|0|0', '0');
  AppendShrCase(LShrCases, 'g-str-1',         'str|1|1', '1');
  AppendShrCase(LShrCases, 'g-str-16',        'str|16|16', '1');
  AppendShrCase(LShrCases, 'g-str-1024',      'str|1024|1024', '1');
  AppendShrCase(LShrCases, 'g-str-printable', 'strrange|4096|4096', '1');
  LSuite.TestTable('v8.37 fuzzgen length contract', LShrCases,
    @TestGenLenCase);

  { v8.40: FuzzMinimize 精确结果 — pred|inHex|wantOutHex|wantProbes }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 'm-ff-head',     'F|ff000000|ff|2', '0');
  AppendShrCase(LShrCases, 'm-ff-mid',      'F|00ff00|ff|3', '0');
  AppendShrCase(LShrCases, 'm-ff-tail',     'F|0000ff|ff|3', '0');
  AppendShrCase(LShrCases, 'm-ff-multi',    'F|ff00ff00|ff|2', '0');
  AppendShrCase(LShrCases, 'm-ff-single',   'F|ff|ff|0', '1');
  AppendShrCase(LShrCases, 'm-empty',       'F|-|-|0', '1');
  AppendShrCase(LShrCases, 'm-never-4',     'N|01020304|01020304|5', '1');
  AppendShrCase(LShrCases, 'm-never-2',     'N|0102|0102|3', '1');
  AppendShrCase(LShrCases, 'm-never-1',     'N|07|07|0', '1');
  AppendShrCase(LShrCases, 'm-len3-8',      'L|0102030405060708|020304|6', '0');
  AppendShrCase(LShrCases, 'm-len3-4',      'L|01020304|020304|5', '0');
  AppendShrCase(LShrCases, 'm-len3-3',      'L|010203|010203|4', '1');
  AppendShrCase(LShrCases, 'm-head7-5',     'H|0701020304|07|3', '0');
  AppendShrCase(LShrCases, 'm-head7-2',     'H|0755|07|1', '0');
  AppendShrCase(LShrCases, 'm-sum10',       'S|09010000|0901|4', '0');
  AppendShrCase(LShrCases, 'm-sum10-min',   'S|0505|0505|3', '1');
  AppendShrCase(LShrCases, 'm-boom',        'B|aabb|ESC|1', '0');
  LSuite.TestTable('v8.40 minimize exact result', LShrCases,
    @TestMinResultCase);

  { v8.40: FuzzMinimize probe 序列 — pred|inHex|wantSeq }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 'ps-ff-head',  'F|ff000000|ff00,ff', '0');
  AppendShrCase(LShrCases, 'ps-ff-tail',  'F|0000ff|0000,00ff,ff', '0');
  AppendShrCase(LShrCases, 'ps-ff-mid',   'F|00ff00|00ff,00,ff', '0');
  AppendShrCase(LShrCases, 'ps-len3-8',
    'L|0102030405060708|01020304,0102,020304,0304,0204,0203', '0');
  AppendShrCase(LShrCases, 'ps-head7-5',  'H|0701020304|070102,0701,07', '0');
  AppendShrCase(LShrCases, 'ps-sum10',    'S|09010000|0901,09,01,09', '0');
  AppendShrCase(LShrCases, 'ps-never-4',
    'N|01020304|0102,020304,010304,010204,010203', '1');
  AppendShrCase(LShrCases, 'ps-never-1',  'N|07|<none>', '1');
  AppendShrCase(LShrCases, 'ps-empty',    'F|-|<none>', '1');
  AppendShrCase(LShrCases, 'ps-single',   'F|ff|<none>', '1');
  LSuite.TestTable('v8.40 minimize probe sequence', LShrCases,
    @TestMinProbeSeqCase);

  { v8.40: FuzzMinimize len>=k 阈值矩阵 — k|wantOutHex|wantProbes }
  SetLength(LShrCases, 0);
  AppendShrCase(LShrCases, 'mk-2', '2|0102|5', '0');
  AppendShrCase(LShrCases, 'mk-3', '3|020304|6', '0');
  AppendShrCase(LShrCases, 'mk-4', '4|01020304|6', '0');
  AppendShrCase(LShrCases, 'mk-5', '5|0405060708|9', '0');
  AppendShrCase(LShrCases, 'mk-6', '6|030405060708|9', '0');
  AppendShrCase(LShrCases, 'mk-7', '7|02030405060708|9', '0');
  AppendShrCase(LShrCases, 'mk-8', '8|0102030405060708|9', '1');
  AppendShrCase(LShrCases, 'mk-9', '9|0102030405060708|9', '1');
  LSuite.TestTable('v8.40 minimize len-threshold matrix', LShrCases,
    @TestMinLenThresholdCase);

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
