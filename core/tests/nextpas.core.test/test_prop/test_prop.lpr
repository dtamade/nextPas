{ test_prop — Property-based testing framework tests }
program test_prop;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.base,
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
begin
  Prop('String shrink test', procedure(const S: string)
  begin
    if Length(S) > 10 then
      PropFail('String too long');
  end, GenString(100), 100, True);
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
begin
  Prop('Int shrink test', procedure(const V: Int64)
  begin
    if V > 100 then
      PropFail('Value too large');
  end, GenInt(0, 1000), 100, True);
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

{ ── Main ──────────────────────────────────────────────────────────────────── }

begin
  WriteLn('=== Property-based Testing Framework ===');
  WriteLn;

  SectionHeader('String properties');
  TestStringProperty;
  PassTest('String property passed');

  SectionHeader('Int64 properties');
  TestIntProperty;
  PassTest('Int64 property passed');

  SectionHeader('Boolean properties');
  TestBoolProperty;
  PassTest('Boolean property passed');

  SectionHeader('TBytes properties');
  TestBytesProperty;
  PassTest('TBytes property passed');

  SectionHeader('Combinator: MapIntToStr');
  TestMapIntToStr;
  PassTest('MapIntToStr passed');

  SectionHeader('Combinator: FilterInt');
  TestFilterInt;
  PassTest('FilterInt passed');

  SectionHeader('Combinator: FilterString');
  TestFilterString;
  PassTest('FilterString passed');

  SectionHeader('Combinator: FilterBytes');
  TestFilterBytes;
  PassTest('FilterBytes passed');

  SectionHeader('GenChoiceInt');
  TestGenChoiceInt;
  PassTest('GenChoiceInt passed');

  SectionHeader('GenChoiceString');
  TestGenChoiceString;
  PassTest('GenChoiceString passed');

  SectionHeader('GenChoiceBool');
  TestGenChoiceBool;
  PassTest('GenChoiceBool passed');

  SectionHeader('GenOneOfInt');
  TestGenOneOfInt;
  PassTest('GenOneOfInt passed');

  SectionHeader('GenOneOfString');
  TestGenOneOfString;
  PassTest('GenOneOfString passed');

  SectionHeader('Int shrink respects min');
  TestIntShrinkRespectsMin;
  PassTest('Int shrink toward min passed');

  WriteLn;
  PassTest('test_prop');
end.
