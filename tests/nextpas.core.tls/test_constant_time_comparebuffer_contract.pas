program test_constant_time_comparebuffer_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.crypto.constant_time;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure TestZeroLengthContract;
var
  A, B: array[0..3] of Byte;
  R: Integer;
begin
  WriteLn;
  WriteLn('=== CompareBuffer Zero-Length Contract ===');

  // Zero-length buffers should compare equal regardless of pointer values
  R := TConstantTime.CompareBuffer(nil, nil, 0);
  Check('Len=0 with nil pointers should be equal', R = 1,
    'Expected 1 for empty buffers');

  FillChar(A, SizeOf(A), $AA);
  FillChar(B, SizeOf(B), $BB);
  R := TConstantTime.CompareBuffer(@A[0], @B[0], 0);
  Check('Len=0 with non-nil pointers should be equal', R = 1,
    'Expected 1 for empty length compare');
end;

procedure TestNonZeroLengthSanity;
var
  A, B: array[0..3] of Byte;
  R: Integer;
begin
  WriteLn;
  WriteLn('=== CompareBuffer Non-Zero Sanity ===');

  A[0] := $01; A[1] := $02; A[2] := $03; A[3] := $04;
  B[0] := $01; B[1] := $02; B[2] := $03; B[3] := $04;
  R := TConstantTime.CompareBuffer(@A[0], @B[0], 4);
  Check('Equal non-zero buffers', R = 1);

  B[3] := $05;
  R := TConstantTime.CompareBuffer(@A[0], @B[0], 4);
  Check('Different non-zero buffers', R = 0);
end;

begin
  WriteLn('========================================');
  WriteLn('Constant-Time CompareBuffer Contract Test');
  WriteLn('========================================');

  TestZeroLengthContract;
  TestNonZeroLengthSanity;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Summary');
  WriteLn('========================================');
  WriteLn('Total: ', TotalTests);
  WriteLn('Passed: ', PassedTests);
  WriteLn('Failed: ', FailedTests);

  if FailedTests > 0 then
    Halt(1);
end.
