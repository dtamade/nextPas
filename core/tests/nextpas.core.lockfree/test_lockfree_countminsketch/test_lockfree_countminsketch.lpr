{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_countminsketch;

uses
  SysUtils,
  nextpas.core.lockfree.countminsketch;

var
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure Test_BasicAddEstimate;
var
  LSketch: TCountMinSketch;
begin
  WriteLn('--- Basic Add/Estimate ---');
  LSketch := TCountMinSketch.Create(4, 1024);
  try
    Check(LSketch.Estimate('key1') = 0, 'Estimate empty = 0');

    LSketch.Add('key1');
    Check(LSketch.Estimate('key1') >= 1, 'Estimate after 1 add >= 1');

    LSketch.Add('key1');
    LSketch.Add('key1');
    Check(LSketch.Estimate('key1') >= 3, 'Estimate after 3 adds >= 3');

    LSketch.Add('key2', 10);
    Check(LSketch.Estimate('key2') >= 10, 'Estimate key2 >= 10');
  finally
    LSketch.Free;
  end;
end;

procedure Test_NoFalseNegatives;
var
  LSketch: TCountMinSketch;
  I: Int32;
begin
  WriteLn('--- No False Negatives ---');
  LSketch := TCountMinSketch.Create(4, 4096);
  try
    for I := 0 to 99 do
      LSketch.Add('item-' + IntToStr(I), I + 1);

    for I := 0 to 99 do
      Check(LSketch.Estimate('item-' + IntToStr(I)) >= I + 1,
        'Estimate(item-' + IntToStr(I) + ') >= ' + IntToStr(I + 1));
  finally
    LSketch.Free;
  end;
end;

procedure Test_Reset;
var
  LSketch: TCountMinSketch;
begin
  WriteLn('--- Reset ---');
  LSketch := TCountMinSketch.Create(4, 1024);
  try
    LSketch.Add('key1', 100);
    Check(LSketch.Estimate('key1') >= 100, 'Estimate >= 100');

    LSketch.Reset;
    Check(LSketch.Estimate('key1') = 0, 'Estimate after reset = 0');
  finally
    LSketch.Free;
  end;
end;

procedure Test_Dimensions;
var
  LSketch: TCountMinSketch;
begin
  WriteLn('--- Dimensions ---');
  LSketch := TCountMinSketch.Create(5, 2048);
  try
    Check(LSketch.Depth = 5, 'Depth = 5');
    Check(LSketch.Width = 2048, 'Width = 2048');
  finally
    LSketch.Free;
  end;
end;

procedure Test_OverEstimate;
var
  LSketch: TCountMinSketch;
begin
  WriteLn('--- Over-Estimate (probabilistic) ---');
  LSketch := TCountMinSketch.Create(4, 1024);
  try
    LSketch.Add('frequent', 1000);
    { Non-added key might have small false positive estimate }
    { But should never be negative }
    Check(LSketch.Estimate('nonexistent') >= 0, 'Non-existent >= 0');
  finally
    LSketch.Free;
  end;
end;

procedure Test_CounterSaturatesInsteadOfWrapping;
var
  LSketch: TCountMinSketch;
begin
  WriteLn('--- Counter Saturation ---');
  LSketch := TCountMinSketch.Create(4, 1024);
  try
    LSketch.Add('overflow', High(Int32));
    Check(LSketch.Estimate('overflow') = High(Int32), 'counter reaches Int32 maximum');
    LSketch.Add('overflow', 1);
    Check(LSketch.Estimate('overflow') = High(Int32),
      'counter saturates instead of wrapping negative');
  finally
    LSketch.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== Count-Min Sketch Tests ===');
  Test_BasicAddEstimate;
  Test_NoFalseNegatives;
  Test_Reset;
  Test_Dimensions;
  Test_OverEstimate;
  Test_CounterSaturatesInsteadOfWrapping;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
