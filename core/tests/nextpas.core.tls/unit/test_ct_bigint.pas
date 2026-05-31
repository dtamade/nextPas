program test_ct_bigint;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.crypto.ct.bigint;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure TestCTEqual;
var
  A, B: TBytes;
begin
  WriteLn('TestCTEqual');
  A := TBytes.Create($01, $02, $03, $04);
  B := TBytes.Create($01, $02, $03, $04);
  Check(CTBigIntEqual(A, B), 'Equal arrays');

  B[3] := $05;
  Check(not CTBigIntEqual(A, B), 'Unequal arrays');

  SetLength(B, 3);
  Check(not CTBigIntEqual(A, B), 'Different length');
end;

procedure TestCTLessThan;
var
  A, B: TBytes;
begin
  WriteLn('TestCTLessThan');
  A := TBytes.Create($01, $00, $00, $00);
  B := TBytes.Create($02, $00, $00, $00);
  Check(CTBigIntLessThan(A, B), '1 < 2 (little-endian)');
  Check(not CTBigIntLessThan(B, A), '2 not < 1');
  Check(not CTBigIntLessThan(A, A), 'not a < a');
end;

procedure TestCTSelect;
var
  A, B, R: TBytes;
begin
  WriteLn('TestCTSelect');
  A := TBytes.Create($AA, $BB, $CC, $DD);
  B := TBytes.Create($11, $22, $33, $44);

  R := CTBigIntSelect(True, A, B);
  Check(CTBigIntEqual(R, A), 'Select true returns A');

  R := CTBigIntSelect(False, A, B);
  Check(CTBigIntEqual(R, B), 'Select false returns B');
end;

procedure TestCTConditionalSwap;
var
  A, B, OrigA, OrigB: TBytes;
begin
  WriteLn('TestCTConditionalSwap');
  A := TBytes.Create($01, $02, $03, $04);
  B := TBytes.Create($05, $06, $07, $08);
  OrigA := Copy(A);
  OrigB := Copy(B);

  CTBigIntConditionalSwap(False, A, B);
  Check(CTBigIntEqual(A, OrigA), 'No swap when false (A)');
  Check(CTBigIntEqual(B, OrigB), 'No swap when false (B)');

  CTBigIntConditionalSwap(True, A, B);
  Check(CTBigIntEqual(A, OrigB), 'Swap when true (A=origB)');
  Check(CTBigIntEqual(B, OrigA), 'Swap when true (B=origA)');
end;

procedure TestCTModMul;
var
  A, B, M, R: TBytes;
begin
  WriteLn('TestCTModMul');
  // Big-endian: 3, 5, 7
  A := TBytes.Create($00, $00, $00, $03);
  B := TBytes.Create($00, $00, $00, $05);
  M := TBytes.Create($00, $00, $00, $07);
  R := CTBigIntModMul(A, B, M);
  // 3*5 mod 7 = 15 mod 7 = 1
  Check(R[Length(R)-1] = 1, '3*5 mod 7 = 1');
end;

procedure TestCTModExp;
var
  ABase, AExp, AMod, R: TBytes;
begin
  WriteLn('TestCTModExp');
  // Big-endian: 2^10 mod 1001 = 1024 mod 1001 = 23
  ABase := TBytes.Create($00, $00, $00, $02);
  AExp := TBytes.Create($00, $00, $00, $0A);
  AMod := TBytes.Create($00, $00, $03, $E9);  // 1001
  R := CTBigIntModExp(ABase, AExp, AMod);
  // 23 = $17
  Check(R[Length(R)-1] = $17, '2^10 mod 1001 = 23');
end;

begin
  
  LTotal := 0;
  LPassed := 0;

  TestCTEqual;
  TestCTLessThan;
  TestCTSelect;
  TestCTConditionalSwap;
  TestCTModMul;
  TestCTModExp;

  WriteLn;
  WriteLn('CT BigInt tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
