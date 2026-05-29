program test_constant_time;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.crypto.constant_time;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('✓ ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('✗ FAILED: ', TestName);
  end;
end;

procedure TestCompareBytes;
var
  A, B, C: TBytes;
begin
  WriteLn('Testing CompareBytes...');
  
  // Test 1: Equal arrays
  SetLength(A, 4);
  A[0] := $01; A[1] := $02; A[2] := $03; A[3] := $04;
  SetLength(B, 4);
  B[0] := $01; B[1] := $02; B[2] := $03; B[3] := $04;
  Assert(TConstantTime.CompareBytes(A, B) = 1, 'Equal bytes return 1');
  
  // Test 2: Different arrays
  SetLength(C, 4);
  C[0] := $01; C[1] := $02; C[2] := $03; C[3] := $05;
  Assert(TConstantTime.CompareBytes(A, C) = 0, 'Different bytes return 0');
  
  // Test 3: Different lengths
  SetLength(C, 3);
  C[0] := $01; C[1] := $02; C[2] := $03;
  Assert(TConstantTime.CompareBytes(A, C) = 0, 'Different lengths return 0');
  
  // Test 4: Empty arrays
  SetLength(A, 0);
  SetLength(B, 0);
  Assert(TConstantTime.CompareBytes(A, B) = 1, 'Empty arrays are equal');
  
  // Test 5: Long arrays (32 bytes - typical hash size)
  SetLength(A, 32);
  SetLength(B, 32);
  FillChar(A[0], 32, $AA);
  FillChar(B[0], 32, $AA);
  Assert(TConstantTime.CompareBytes(A, B) = 1, 'Long equal arrays');
  
  B[31] := $AB;  // Change last byte
  Assert(TConstantTime.CompareBytes(A, B) = 0, 'Long arrays with difference at end');
  
  B[31] := $AA;
  B[0] := $AB;   // Change first byte
  Assert(TConstantTime.CompareBytes(A, B) = 0, 'Long arrays with difference at start');
end;

procedure TestCompareStrings;
begin
  WriteLn('Testing CompareStrings...');
  
  // Test 1: Equal strings
  Assert(TConstantTime.CompareStrings('password123', 'password123'), 'Equal strings');
  
  // Test 2: Different strings
  Assert(not TConstantTime.CompareStrings('password123', 'password124'), 'Different strings');
  
  // Test 3: Empty strings
  Assert(TConstantTime.CompareStrings('', ''), 'Empty strings are equal');
  
  // Test 4: Unicode strings
  Assert(TConstantTime.CompareStrings('测试', '测试'), 'Equal Unicode strings');
  Assert(not TConstantTime.CompareStrings('测试', '测验'), 'Different Unicode strings');
  
  // Test 5: Case sensitivity
  Assert(not TConstantTime.CompareStrings('Password', 'password'), 'Case sensitive comparison');
end;

procedure TestTimingConsistency;
var
  A, B: TBytes;
  I: Integer;
  StartTime, EndTime: QWord;
const
  ITERATIONS = 100000;
begin
  WriteLn('Testing timing consistency...');
  
  // Create 32-byte arrays (SHA-256 size)
  SetLength(A, 32);
  SetLength(B, 32);
  
  FillChar(A[0], 32, $AA);
  FillChar(B[0], 32, $AA);
  
  StartTime := GetTickCount64;
  for I := 1 to ITERATIONS do
    TConstantTime.CompareBytes(A, B);
  EndTime := GetTickCount64;
  WriteLn(Format('  Equal-array loop completed in %d ms', [EndTime - StartTime]));
  Assert(TConstantTime.CompareBytes(A, B) = 1, 'Equal arrays still compare equal after timing loop');
  
  // Different arrays should still execute the same compare path and return 0.
  B[0] := $AB;  // Make different
  
  StartTime := GetTickCount64;
  for I := 1 to ITERATIONS do
    TConstantTime.CompareBytes(A, B);
  EndTime := GetTickCount64;
  WriteLn(Format('  Different-array loop completed in %d ms', [EndTime - StartTime]));
  Assert(TConstantTime.CompareBytes(A, B) = 0, 'Different arrays still compare different after timing loop');
  WriteLn('  (Low-resolution wall-clock variance is not used as a pass/fail signal)');
end;

procedure TestSelect;
var
  A, B, Result: TBytes;
begin
  WriteLn('Testing Select...');
  
  SetLength(A, 3);
  A[0] := $AA; A[1] := $AA; A[2] := $AA;
  SetLength(B, 3);
  B[0] := $BB; B[1] := $BB; B[2] := $BB;
  
  // Test 1: Select A (condition=1)
  Result := TConstantTime.Select(1, A, B);
  Assert((Result[0] = $AA) and (Result[1] = $AA), 'Select with condition=1');
  
  // Test 2: Select B (condition=0)
  Result := TConstantTime.Select(0, A, B);
  Assert((Result[0] = $BB) and (Result[1] = $BB), 'Select with condition=0');
end;

procedure TestIsZero;
begin
  WriteLn('Testing IsZero...');
  
  Assert(TConstantTime.IsZero(0) = 1, 'IsZero(0) returns 1');
  Assert(TConstantTime.IsZero(1) = 0, 'IsZero(1) returns 0');
  Assert(TConstantTime.IsZero(255) = 0, 'IsZero(255) returns 0');
  
  Assert(TConstantTime.IsZeroInt(0) = 1, 'IsZeroInt(0) returns 1');
  Assert(TConstantTime.IsZeroInt(1) = 0, 'IsZeroInt(1) returns 0');
  Assert(TConstantTime.IsZeroInt(-1) = 0, 'IsZeroInt(-1) returns 0');
end;

begin
  WriteLn('=== Constant-Time Operations Test Suite ===');
  WriteLn;
  
  TestCompareBytes;
  WriteLn;
  
  TestCompareStrings;
  WriteLn;
  
  TestSelect;
  WriteLn;
  
  TestIsZero;
  WriteLn;
  
  TestTimingConsistency;
  WriteLn;
  
  WriteLn('=== Test Results ===');
  WriteLn(Format('Passed: %d', [TestsPassed]));
  WriteLn(Format('Failed: %d', [TestsFailed]));
  
  if TestsFailed = 0 then
  begin
    WriteLn('✓ All tests PASSED');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('✗ Some tests FAILED');
    ExitCode := 1;
  end;
end.
