program test_clone;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash,
  nextpas.core.crypto.hmac;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then begin WriteLn('  [PASS] ', AName); Inc(GPass); end
  else begin WriteLn('  [FAIL] ', AName); Inc(GFail); end;
end;

procedure TestCloneAlgo(const AName: string; AFactory: IHasher);
var
  H1, H2: IHasher;
  D1, D2: TBytes;
  A, B: array[0..3] of Byte;
begin
  A[0] := $AA; A[1] := $BB; A[2] := $CC; A[3] := $DD;
  B[0] := $11; B[1] := $22; B[2] := $33; B[3] := $44;

  H1 := AFactory;
  H1.Write(A[0], 4);
  H2 := H1.Clone;

  H1.Write(A[0], 4);
  H2.Write(B[0], 4);

  D1 := H1.SumBytes;
  D2 := H2.SumBytes;
  Check(AName + ': divergent after clone', not CompareMem(@D1[0], @D2[0], Length(D1)));

  // Same continuation produces same result
  H1 := AFactory;
  H1.Write(A[0], 4);
  H2 := H1.Clone;
  H1.Write(B[0], 4);
  H2.Write(B[0], 4);
  D1 := H1.SumBytes;
  D2 := H2.SumBytes;
  Check(AName + ': same continuation = same result', CompareMem(@D1[0], @D2[0], Length(D1)));

  // Reset clone doesn't affect original
  H1 := AFactory;
  H1.Write(A[0], 4);
  H2 := H1.Clone;
  H2.Reset;
  H2.Write(B[0], 4);
  D1 := H1.SumBytes;
  D2 := H2.SumBytes;
  Check(AName + ': reset clone independent', not CompareMem(@D1[0], @D2[0], Length(D1)));
end;

procedure TestCloneHMAC;
var
  H1, H2: IHasher;
  D1, D2: TBytes;
  Key: array[0..15] of Byte;
  A, B: array[0..3] of Byte;
begin
  WriteLn('--- HMAC Clone ---');
  FillChar(Key, 16, $0B);
  A[0] := $AA; A[1] := $BB; A[2] := $CC; A[3] := $DD;
  B[0] := $11; B[1] := $22; B[2] := $33; B[3] := $44;

  H1 := NewHMAC(haSHA256, Key[0], 16);
  H1.Write(A[0], 4);
  H2 := H1.Clone;
  H1.Write(A[0], 4);
  H2.Write(B[0], 4);
  D1 := H1.SumBytes;
  D2 := H2.SumBytes;
  Check('HMAC: divergent after clone', not CompareMem(@D1[0], @D2[0], Length(D1)));

  H1 := NewHMAC(haSHA256, Key[0], 16);
  H1.Write(A[0], 4);
  H2 := H1.Clone;
  H1.Write(B[0], 4);
  H2.Write(B[0], 4);
  D1 := H1.SumBytes;
  D2 := H2.SumBytes;
  Check('HMAC: same continuation = same result', CompareMem(@D1[0], @D2[0], Length(D1)));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== Hash Clone Tests ===');
  WriteLn;

  TestCloneAlgo('MD5', NewMD5);
  TestCloneAlgo('SHA1', NewSHA1);
  TestCloneAlgo('SHA256', NewSHA256);
  TestCloneAlgo('SHA384', NewSHA384);
  TestCloneAlgo('SHA512', NewSHA512);
  TestCloneHMAC;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
