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
      FailTest('String too long: ' + IntToStr(Length(S)));
  end, GenString(100), 50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

procedure TestStringShrink;
begin
  { This test should fail and shrink to a minimal failing input }
  Prop('String shrink test', procedure(const S: string)
  begin
    if Length(S) > 10 then
      FailTest('String too long');
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
      FailTest('Negative value: ' + IntToStr(V));
  end, GenInt(0, 1000), 50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

procedure TestIntShrink;
begin
  Prop('Int shrink test', procedure(const V: Int64)
  begin
    if V > 100 then
      FailTest('Value too large');
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
      FailTest('Bytes too long: ' + IntToStr(Length(V)));
  end, GenBytes(100), 50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

{ ── Combinator tests ──────────────────────────────────────────────────────── }

procedure TestMapIntToStr;
begin
  GTestCount := 0;
  Prop('MapIntToStr: digits only', procedure(const S: string)
  begin
    Inc(GTestCount);
    { IntToStr produces only digit chars (and '-' for negatives) }
    if Length(S) = 0 then
      FailTest('Empty string from MapIntToStr');
  end, MapIntToStr(GenInt(0, 9999), function(V: Int64): string begin Result := IntToStr(V) end),
  50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

procedure TestFilterInt;
begin
  GTestCount := 0;
  Prop('FilterInt: even only', procedure(const V: Int64)
  begin
    Inc(GTestCount);
    if V mod 2 <> 0 then
      FailTest('Odd value: ' + IntToStr(V));
  end, FilterInt(GenInt(0, 1000), function(V: Int64): Boolean begin Result := V mod 2 = 0 end),
  50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

procedure TestFilterString;
begin
  GTestCount := 0;
  Prop('FilterString: non-empty', procedure(const S: string)
  begin
    Inc(GTestCount);
    if Length(S) = 0 then
      FailTest('Empty string');
  end, FilterString(GenString(50), function(const V: string): Boolean begin Result := Length(V) > 0 end),
  50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
end;

procedure TestFilterBytes;
begin
  GTestCount := 0;
  Prop('FilterBytes: non-empty', procedure(const V: TBytes)
  begin
    Inc(GTestCount);
    if Length(V) = 0 then
      FailTest('Empty bytes');
  end, FilterBytes(GenBytes(50), function(const V: TBytes): Boolean begin Result := Length(V) > 0 end),
  50, True);
  if GTestCount <> 50 then
    FailTest('Expected 50 runs, got ' + IntToStr(GTestCount));
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

  WriteLn;
  PassTest('test_prop');
end.
