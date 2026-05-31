program test_rsa_ct;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.rsa.ct,
  nextpas.core.crypto.bigint;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFailCount);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(AData) - 1 do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestSmallModExp;
var
  LMsg, LMod, LExp, LSig, LSigOld: TBytes;
  LError, LOldError: string;
begin
  WriteLn('--- Small modexp cross-validate ---');

  LMsg := TBytes.Create(0, 0, 0, 3);
  LMod := TBytes.Create(0, 0, 0, 11);
  LExp := TBytes.Create(0, 0, 0, 7);

  Check(TryRSACTModExpSign(LMsg, LMod, LExp, LSig, LError), 'CT modexp ok');
  Check(LError = '', 'no error');
  Check(LSig[Length(LSig)-1] = 9, '3^7 mod 11 = 9');

  TryBigIntModExpFromUnsignedBytes(LMsg, LExp, LMod, LSigOld, LOldError);
  Check(LSigOld[Length(LSigOld)-1] = 9, 'old also gives 9');
end;

procedure TestModExpIdentity;
var
  LN, LExp, LMsg, LSig: TBytes;
  LError: string;
begin
  WriteLn('--- m^1 mod n = m ---');

  LN := HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF97');
  LExp := HexToBytes('0000000000000000000000000000000000000000000000000000000000000001');
  LMsg := HexToBytes('000000000000000000000000000000000000000000000000000000000000012A');

  Check(TryRSACTModExpSign(LMsg, LN, LExp, LSig, LError), 'm^1 ok');
  Check(LSig[Length(LSig)-1] = $2A, 'low byte preserved');
  Check(LSig[Length(LSig)-2] = $01, 'second byte preserved');
end;

procedure TestModExpSquare;
var
  LN, LExp, LMsg, LSigCT, LSigOld: TBytes;
  LError, LOldError: string;
begin
  WriteLn('--- m^2 mod n ---');

  LN := HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEF');
  LExp := HexToBytes('0000000000000000000000000000000000000000000000000000000000000002');
  LMsg := HexToBytes('0000000000000000000000000000000000000000000000000000000000000005');

  Check(TryRSACTModExpSign(LMsg, LN, LExp, LSigCT, LError), 'CT m^2 ok');
  Check(LSigCT[Length(LSigCT)-1] = 25, '5^2 = 25');

  TryBigIntModExpFromUnsignedBytes(LMsg, LExp, LN, LSigOld, LOldError);
  Check(LSigOld[Length(LSigOld)-1] = 25, 'old also 25');
end;

procedure TestCrossValidate128Byte;
var
  LN, LD, LMsg, LSigCT, LSigOld: TBytes;
  LError, LOldError: string;
  I: Integer;
begin
  WriteLn('--- Cross-validate 1024-bit modexp ---');

  SetLength(LN, 128);
  for I := 0 to 127 do
    LN[I] := Byte((I * 37 + 13) and $FF);
  LN[127] := LN[127] or 1;
  LN[0] := LN[0] or $80;

  SetLength(LD, 128);
  for I := 0 to 127 do
    LD[I] := Byte((I * 53 + 7) and $FF);
  LD[127] := LD[127] or 1;

  SetLength(LMsg, 128);
  for I := 0 to 127 do
    LMsg[I] := Byte((I * 17 + 3) and $FF);
  LMsg[0] := LMsg[0] and $7F;

  Check(TryRSACTModExpSign(LMsg, LN, LD, LSigCT, LError), 'CT 1024-bit ok');
  Check(TryRSAModExpSignPurePascal(LMsg, LN, LD, LSigOld, LOldError), 'old 1024-bit ok');
  Check(BytesToHex(LSigCT) = BytesToHex(LSigOld), 'CT == old for 1024-bit');
end;

procedure TestErrorCases;
var
  LSig: TBytes;
  LError: string;
  LN, LE, LD: TBytes;
begin
  WriteLn('--- Error cases ---');

  SetLength(LN, 0);
  LE := TBytes.Create(1);
  LD := TBytes.Create(1);

  Check(not TryRSACTModExpSign(LE, LN, LD, LSig, LError), 'empty modulus rejected');

  LN := TBytes.Create(0, 0, 0, 4);
  Check(not TryRSACTModExpSign(LE, LN, LD, LSig, LError), 'even modulus rejected');
end;

procedure TestLargerExponent;
var
  LN, LD, LMsg, LSigCT, LSigOld: TBytes;
  LError, LOldError: string;
  I: Integer;
begin
  WriteLn('--- 64-byte modexp with large exponent ---');

  SetLength(LN, 64);
  for I := 0 to 63 do
    LN[I] := Byte((I * 41 + 19) and $FF);
  LN[63] := LN[63] or 1;
  LN[0] := LN[0] or $C0;

  SetLength(LD, 64);
  for I := 0 to 63 do
    LD[I] := Byte((I * 67 + 31) and $FF);
  LD[63] := LD[63] or 1;
  LD[0] := LD[0] or $80;

  SetLength(LMsg, 64);
  for I := 0 to 63 do
    LMsg[I] := Byte((I * 23 + 5) and $FF);
  LMsg[0] := LMsg[0] and $3F;

  Check(TryRSACTModExpSign(LMsg, LN, LD, LSigCT, LError), 'CT 512-bit ok');
  Check(TryRSAModExpSignPurePascal(LMsg, LN, LD, LSigOld, LOldError), 'old 512-bit ok');
  Check(BytesToHex(LSigCT) = BytesToHex(LSigOld), 'CT == old for 512-bit');
end;

begin
  WriteLn('=== RSA CT (Constant-Time) Tests ===');
  WriteLn;

  TestSmallModExp;
  TestModExpIdentity;
  TestModExpSquare;
  TestCrossValidate128Byte;
  TestErrorCases;
  TestLargerExponent;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
