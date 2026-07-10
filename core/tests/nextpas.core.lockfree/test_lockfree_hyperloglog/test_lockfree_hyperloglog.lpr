{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_hyperloglog;

uses
  SysUtils,
  nextpas.core.lockfree.hyperloglog;

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

procedure Test_BasicEstimate;
var
  LHll: THyperLogLog;
  LEstimate: Int64;
  I: Int32;
begin
  WriteLn('--- Basic Estimate ---');
  LHll := THyperLogLog.Create(14);
  try
    Check(LHll.RegisterCount = 16384, 'Register count = 16384');

    for I := 0 to 9999 do
      LHll.Add('element-' + IntToStr(I));

    LEstimate := LHll.Estimate;
    { Should be within 10% of 10000 }
    Check((LEstimate > 8000) and (LEstimate < 12000),
      'Estimate ~10000 (got ' + IntToStr(LEstimate) + ')');
  finally
    LHll.Free;
  end;
end;

procedure Test_UniqueCount;
var
  LHll: THyperLogLog;
  LEstimate: Int64;
  I: Int32;
begin
  WriteLn('--- Unique Count ---');
  LHll := THyperLogLog.Create(14);
  try
    { Add 1000 unique elements }
    for I := 0 to 999 do
      LHll.Add('unique-' + IntToStr(I));

    LEstimate := LHll.Estimate;
    { Should be within 15% of 1000 }
    Check((LEstimate > 850) and (LEstimate < 1150),
      'Estimate ~1000 (got ' + IntToStr(LEstimate) + ')');
  finally
    LHll.Free;
  end;
end;

procedure Test_Duplicates;
var
  LHll: THyperLogLog;
  LEstimate: Int64;
  I, J: Int32;
begin
  WriteLn('--- Duplicates ---');
  LHll := THyperLogLog.Create(14);
  try
    { Add same 100 elements 10 times }
    for J := 0 to 9 do
      for I := 0 to 99 do
        LHll.Add('dup-' + IntToStr(I));

    LEstimate := LHll.Estimate;
    { Should be ~100, not 1000 }
    Check((LEstimate > 80) and (LEstimate < 120),
      'Estimate ~100 (got ' + IntToStr(LEstimate) + ')');
  finally
    LHll.Free;
  end;
end;

procedure Test_EmptyStringIsAValidElement;
var
  LHll: THyperLogLog;
begin
  WriteLn('--- Empty String ---');
  LHll := THyperLogLog.Create(14);
  try
    LHll.Add('');
    Check(LHll.Estimate = 1, 'empty string contributes one unique element');
    LHll.Add('');
    Check(LHll.Estimate = 1, 'duplicate empty string does not increase cardinality');
  finally
    LHll.Free;
  end;
end;

procedure Test_Reset;
var
  LHll: THyperLogLog;
  I: Int32;
begin
  WriteLn('--- Reset ---');
  LHll := THyperLogLog.Create(14);
  try
    for I := 0 to 999 do
      LHll.Add('element-' + IntToStr(I));

    Check(LHll.Estimate > 0, 'Estimate > 0 before reset');

    LHll.Reset;
    Check(LHll.Estimate = 0, 'Estimate = 0 after reset');
  finally
    LHll.Free;
  end;
end;

procedure Test_Merge;
var
  LHll1, LHll2: THyperLogLog;
  LEstimate: Int64;
  I: Int32;
begin
  WriteLn('--- Merge ---');
  LHll1 := THyperLogLog.Create(14);
  LHll2 := THyperLogLog.Create(14);
  try
    for I := 0 to 499 do
      LHll1.Add('element-' + IntToStr(I));

    for I := 500 to 999 do
      LHll2.Add('element-' + IntToStr(I));

    Check(LHll1.Merge(LHll2), 'Merge returns true');

    LEstimate := LHll1.Estimate;
    { Should be ~1000 }
    Check((LEstimate > 800) and (LEstimate < 1200),
      'Estimate after merge ~1000 (got ' + IntToStr(LEstimate) + ')');
  finally
    LHll1.Free;
    LHll2.Free;
  end;
end;

procedure Test_SmallPrecision;
var
  LHll: THyperLogLog;
  LEstimate: Int64;
  I: Int32;
begin
  WriteLn('--- Small Precision ---');
  LHll := THyperLogLog.Create(4);
  try
    Check(LHll.RegisterCount = 16, 'Register count = 16');

    for I := 0 to 99 do
      LHll.Add('element-' + IntToStr(I));

    LEstimate := LHll.Estimate;
    { Should be roughly ~100 (less precise with p=4) }
    Check((LEstimate > 50) and (LEstimate < 200),
      'Estimate ~100 (got ' + IntToStr(LEstimate) + ')');
  finally
    LHll.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== HyperLogLog Tests ===');
  Test_BasicEstimate;
  Test_UniqueCount;
  Test_Duplicates;
  Test_EmptyStringIsAValidElement;
  Test_Reset;
  Test_Merge;
  Test_SmallPrecision;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
