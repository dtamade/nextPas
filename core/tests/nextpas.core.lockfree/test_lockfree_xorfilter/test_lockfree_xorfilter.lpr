program test_lockfree_xorfilter;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.xorfilter,
  nextpas.core.test;

procedure TestBasicContains;
var
  XF: TXorFilter;
  LKeys: array[0..4] of UInt64;
begin
  LKeys[0] := 100;
  LKeys[1] := 200;
  LKeys[2] := 300;
  LKeys[3] := 400;
  LKeys[4] := 500;
  XF := TXorFilter.Create(LKeys);
  try
    Check(XF.Contains(100), 'Should contain 100');
    Check(XF.Contains(200), 'Should contain 200');
    Check(XF.Contains(300), 'Should contain 300');
    Check(XF.Contains(400), 'Should contain 400');
    Check(XF.Contains(500), 'Should contain 500');
    CheckEqual(Int32(5), XF.GetCount, 'Count');
  finally
    XF.Free;
  end;
end;

procedure TestNonMember;
var
  XF: TXorFilter;
  LKeys: array[0..9] of UInt64;
  LFalsePos, LI: Int32;
begin
  for LI := 0 to 9 do
    LKeys[LI] := UInt64((LI + 1) * 100);
  XF := TXorFilter.Create(LKeys);
  try
    LFalsePos := 0;
    for LI := 1000 to 1099 do
      if XF.Contains(UInt64(LI)) then
        Inc(LFalsePos);
    { False positive rate should be < 5% with 8-bit fingerprints }
    Check(LFalsePos < 5, 'False positive rate should be low');
  finally
    XF.Free;
  end;
end;

procedure TestClose;
var
  XF: TXorFilter;
  LKeys: array[0..2] of UInt64;
begin
  LKeys[0] := 1;
  LKeys[1] := 2;
  LKeys[2] := 3;
  XF := TXorFilter.Create(LKeys);
  try
    XF.Close;
    Check(XF.IsClosed, 'Should be closed');
    Check(not XF.Contains(1), 'Should not check on closed');
  finally
    XF.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_xorfilter ===');
  WriteLn;

  TestBasicContains;
  WriteLn('  + Basic contains');

  TestNonMember;
  WriteLn('  + Non-member (false positive rate)');

  TestClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All XOR filter tests passed!');
end.
