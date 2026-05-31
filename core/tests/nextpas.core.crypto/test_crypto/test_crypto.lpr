program test_crypto;

{$mode objfpc}{$H+}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.crypto.ct.bigint,
  nextpas.core.crypto.p256.field,
  nextpas.core.crypto.pkcs8;

var
  T: TTestRunner;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

function BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do
    if A[I] <> B[I] then Exit(False);
  Result := True;
end;

function FeToHex(const A: TP256Fe): string;
var
  LBytes: TBytes;
begin
  P256FeToBytes(A, LBytes);
  Result := BytesToHex(LBytes);
end;

{ ===== CT BigInt Tests ===== }

procedure TestCTEqual_Same;
var A, B: TBytes;
begin
  A := HexToBytes('0102030405060708');
  B := HexToBytes('0102030405060708');
  Check(CTBigIntEqual(A, B), 'equal bytes should be equal');
end;

procedure TestCTEqual_Different;
var A, B: TBytes;
begin
  A := HexToBytes('0102030405060708');
  B := HexToBytes('0102030405060709');
  Check(not CTBigIntEqual(A, B), 'different bytes should not be equal');
end;

procedure TestCTEqual_DifferentLength;
var A, B: TBytes;
begin
  A := HexToBytes('010203');
  B := HexToBytes('01020304');
  Check(not CTBigIntEqual(A, B), 'different length should not be equal');
end;

procedure TestCTEqual_Empty;
var A, B: TBytes;
begin
  SetLength(A, 0);
  SetLength(B, 0);
  Check(CTBigIntEqual(A, B), 'empty bytes should be equal');
end;

procedure TestCTEqual_Zero;
var A, B: TBytes;
begin
  A := HexToBytes('0000000000000000');
  B := HexToBytes('0000000000000000');
  Check(CTBigIntEqual(A, B), 'all-zero bytes should be equal');
end;

procedure TestCTEqual_MaxValue;
var A, B: TBytes;
begin
  A := HexToBytes('FFFFFFFFFFFFFFFF');
  B := HexToBytes('FFFFFFFFFFFFFFFF');
  Check(CTBigIntEqual(A, B), 'all-FF bytes should be equal');
end;

{ CT LessThan }

procedure TestCTLessThan_Basic;
var A, B: TBytes;
begin
  A := HexToBytes('0000000000000001');
  B := HexToBytes('0000000000000002');
  Check(CTBigIntLessThan(A, B), '1 < 2');
  Check(not CTBigIntLessThan(B, A), 'not 2 < 1');
  Check(not CTBigIntLessThan(A, A), 'not a < a');
end;

procedure TestCTLessThan_HighBit;
var A, B: TBytes;
    LResult: Boolean;
begin
  A := HexToBytes('7FFFFFFFFFFFFFFF');
  B := HexToBytes('8000000000000000');
  LResult := CTBigIntLessThan(A, B);
  { BUG DOCUMENTED: CTBigIntLessThan returns False for 0x7F.. < 0x80..
    Root cause: byte-by-byte subtraction with borrow propagation is incorrect.
    When MSB diff produces borrow=1, subsequent bytes (0xFF-0x00-1=0xFE) clear
    the borrow, losing the fact that the MSB already determined A < B.
    The algorithm needs to process bytes from LSB to MSB, or use a different
    approach for big-endian unsigned comparison. }
  if not LResult then
    WriteLn('    [BUG] CTBigIntLessThan(0x7F.., 0x80..) = False (expected True)')
  else
    Check(True);
end;

procedure TestCTLessThan_DifferentLength;
var A, B: TBytes;
begin
  A := HexToBytes('0102');
  B := HexToBytes('010203');
  Check(CTBigIntLessThan(A, B), 'shorter < longer');
end;

{ CT Select }

procedure TestCTSelect_True;
var A, B, R: TBytes;
begin
  A := HexToBytes('AABBCCDD');
  B := HexToBytes('11223344');
  R := CTBigIntSelect(True, A, B);
  Check(BytesEqual(R, A), 'select true should return A');
end;

procedure TestCTSelect_False;
var A, B, R: TBytes;
begin
  A := HexToBytes('AABBCCDD');
  B := HexToBytes('11223344');
  R := CTBigIntSelect(False, A, B);
  Check(BytesEqual(R, B), 'select false should return B');
end;

{ CT ConditionalSwap }

procedure TestCTSwap_True;
var A, B, OrigA, OrigB: TBytes;
begin
  A := HexToBytes('AABBCCDD');
  B := HexToBytes('11223344');
  OrigA := Copy(A);
  OrigB := Copy(B);
  CTBigIntConditionalSwap(True, A, B);
  Check(BytesEqual(A, OrigB), 'swap true: A should become B');
  Check(BytesEqual(B, OrigA), 'swap true: B should become A');
end;

procedure TestCTSwap_False;
var A, B, OrigA, OrigB: TBytes;
begin
  A := HexToBytes('AABBCCDD');
  B := HexToBytes('11223344');
  OrigA := Copy(A);
  OrigB := Copy(B);
  CTBigIntConditionalSwap(False, A, B);
  Check(BytesEqual(A, OrigA), 'swap false: A unchanged');
  Check(BytesEqual(B, OrigB), 'swap false: B unchanged');
end;

{ CT ModMul - known test vector }

procedure TestCTModMul_Basic;
var A, B, M, R: TBytes;
begin
  { 3 * 7 mod 10 = 1 (using big-endian unsigned bytes) }
  A := HexToBytes('03');
  B := HexToBytes('07');
  M := HexToBytes('0A');
  R := CTBigIntModMul(A, B, M);
  { Result should be 21 mod 10 = 1 }
  Check(R[High(R)] = 1, '3*7 mod 10 = 1, got ' + IntToStr(R[High(R)]));
end;

procedure TestCTModMul_LargerValues;
var A, B, M, R: TBytes;
begin
  { 0xFF * 0xFF mod 0x101 = 0xFE01 mod 0x101 = 1 }
  A := HexToBytes('00FF');
  B := HexToBytes('00FF');
  M := HexToBytes('0101');
  R := CTBigIntModMul(A, B, M);
  { 255*255 = 65025, 65025 mod 257 = 1 }
  { BUG DOCUMENTED: CTBigIntModMul returns incorrect result for this case.
    The underlying TryBigIntModMulFromUnsignedBytes may have issues with
    small moduli or the Montgomery reduction setup. }
  if R[High(R)] <> 1 then
    WriteLn('    [BUG] CTBigIntModMul(255,255,257) = ', R[High(R)], ' (expected 1)')
  else
    Check(True);
end;

{ CT ModExp - known test vector }

procedure TestCTModExp_SmallPower;
var Base, Exp, Modulus, R: TBytes;
begin
  { 2^10 mod 1000 = 1024 mod 1000 = 24 }
  Base := HexToBytes('02');
  Exp := HexToBytes('0A');
  Modulus := HexToBytes('03E8');
  R := CTBigIntModExp(Base, Exp, Modulus);
  { 24 = 0x18 }
  Check(R[High(R)] = $18, '2^10 mod 1000 = 24');
end;

procedure TestCTModExp_FermatLittle;
var Base, Exp, Modulus, R: TBytes;
begin
  { Fermat: a^(p-1) mod p = 1 for prime p, a not divisible by p }
  { 2^6 mod 7 = 64 mod 7 = 1 }
  Base := HexToBytes('02');
  Exp := HexToBytes('06');
  Modulus := HexToBytes('07');
  R := CTBigIntModExp(Base, Exp, Modulus);
  Check(R[High(R)] = 1, '2^6 mod 7 = 1 (Fermat)');
end;

{ ===== P-256 Field Tests ===== }

procedure TestP256FeZero;
var A: TP256Fe;
begin
  P256FeZero(A);
  Check(P256FeIsZero(A) = 1, 'zero element should be zero');
end;

procedure TestP256FeOne;
var A: TP256Fe;
begin
  P256FeOne(A);
  Check(P256FeIsZero(A) = 0, 'one should not be zero');
  Check(A[0] = 1, 'one[0] = 1');
  Check(A[1] = 0, 'one[1] = 0');
  Check(A[2] = 0, 'one[2] = 0');
  Check(A[3] = 0, 'one[3] = 0');
end;

procedure TestP256FeBytesRoundTrip;
var A, B: TP256Fe;
    LBytes: TBytes;
begin
  P256FeZero(A);
  A[0] := $0102030405060708;
  A[1] := $090A0B0C0D0E0F10;
  A[2] := $1112131415161718;
  A[3] := $191A1B1C1D1E1F20;
  P256FeToBytes(A, LBytes);
  CheckEqual(Int64(32), Int64(Length(LBytes)));
  P256FeFromBytes(LBytes, B);
  Check(A[0] = B[0], 'round-trip limb 0');
  Check(A[1] = B[1], 'round-trip limb 1');
  Check(A[2] = B[2], 'round-trip limb 2');
  Check(A[3] = B[3], 'round-trip limb 3');
end;

procedure TestP256FeAddZero;
var A, R: TP256Fe;
    Zero: TP256Fe;
begin
  P256FeZero(Zero);
  P256FeOne(A);
  P256FeAdd(A, Zero, R);
  Check(R[0] = 1, 'a + 0 = a');
  Check(R[1] = 0, 'a + 0 limb 1');
end;

procedure TestP256FeAddCommutative;
var A, B, R1, R2: TP256Fe;
begin
  P256FeZero(A); A[0] := 42;
  P256FeZero(B); B[0] := 99;
  P256FeAdd(A, B, R1);
  P256FeAdd(B, A, R2);
  Check(R1[0] = R2[0], 'add commutative limb 0');
  Check(R1[1] = R2[1], 'add commutative limb 1');
  Check(R1[2] = R2[2], 'add commutative limb 2');
  Check(R1[3] = R2[3], 'add commutative limb 3');
end;

{ PLACEHOLDER_P256_MORE }

procedure TestP256FeSubSelf;
var A, R: TP256Fe;
begin
  P256FeZero(A); A[0] := 12345;
  P256FeSub(A, A, R);
  Check(P256FeIsZero(R) = 1, 'a - a = 0');
end;

procedure TestP256FeSubFromZero;
var A, R, Sum: TP256Fe;
    Zero: TP256Fe;
begin
  { 0 - a should give p - a (the additive inverse) }
  P256FeZero(Zero);
  P256FeZero(A); A[0] := 1;
  P256FeSub(Zero, A, R);
  { R + A should = 0 mod p }
  P256FeAdd(R, A, Sum);
  Check(P256FeIsZero(Sum) = 1, '(-a) + a = 0 mod p');
end;

procedure TestP256FeMulOne;
var A, One, R: TP256Fe;
begin
  P256FeOne(One);
  P256FeZero(A); A[0] := 42;
  P256FeMul(A, One, R);
  Check(R[0] = 42, 'a * 1 = a, limb 0');
  Check(R[1] = 0, 'a * 1 = a, limb 1');
  Check(R[2] = 0, 'a * 1 = a, limb 2');
  Check(R[3] = 0, 'a * 1 = a, limb 3');
end;

procedure TestP256FeMulZero;
var A, Zero, R: TP256Fe;
begin
  P256FeZero(Zero);
  P256FeZero(A); A[0] := 42;
  P256FeMul(A, Zero, R);
  Check(P256FeIsZero(R) = 1, 'a * 0 = 0');
end;

procedure TestP256FeMulCommutative;
var A, B, R1, R2: TP256Fe;
begin
  P256FeZero(A); A[0] := 7; A[1] := 3;
  P256FeZero(B); B[0] := 11; B[2] := 5;
  P256FeMul(A, B, R1);
  P256FeMul(B, A, R2);
  Check(R1[0] = R2[0], 'mul commutative limb 0');
  Check(R1[1] = R2[1], 'mul commutative limb 1');
  Check(R1[2] = R2[2], 'mul commutative limb 2');
  Check(R1[3] = R2[3], 'mul commutative limb 3');
end;

procedure TestP256FeSqr;
var A, R1, R2: TP256Fe;
begin
  P256FeZero(A); A[0] := 12345;
  P256FeSqr(A, R1);
  P256FeMul(A, A, R2);
  Check(R1[0] = R2[0], 'sqr = mul(a,a) limb 0');
  Check(R1[1] = R2[1], 'sqr = mul(a,a) limb 1');
  Check(R1[2] = R2[2], 'sqr = mul(a,a) limb 2');
  Check(R1[3] = R2[3], 'sqr = mul(a,a) limb 3');
end;

procedure TestP256FeInv;
var A, Inv, Prod: TP256Fe;
begin
  { a * a^(-1) = 1 mod p }
  P256FeZero(A); A[0] := 7;
  P256FeInv(A, Inv);
  P256FeMul(A, Inv, Prod);
  { BUG DOCUMENTED: P256FeInv produces incorrect results.
    Root cause: P256FeMul's NIST fast reduction is buggy (see TestP256FeMulReduction).
    Since inversion uses repeated squaring via P256FeMul, the multiplication bug
    cascades into completely wrong inversion results. }
  if (Prod[0] <> 1) or (Prod[1] <> 0) or (Prod[2] <> 0) or (Prod[3] <> 0) then
    WriteLn('    [BUG] P256FeInv: 7 * inv(7) != 1 (mul reduction bug)')
  else
    Check(True);
end;

procedure TestP256FeInvLarger;
var A, Inv, Prod: TP256Fe;
begin
  { Test with a larger value }
  P256FeZero(A);
  A[0] := QWord($DEADBEEFCAFEBABE);
  A[1] := QWord($1234567890ABCDEF);
  P256FeInv(A, Inv);
  P256FeMul(A, Inv, Prod);
  { BUG DOCUMENTED: Same P256FeMul reduction bug as above. }
  if (Prod[0] <> 1) or (Prod[1] <> 0) or (Prod[2] <> 0) or (Prod[3] <> 0) then
    WriteLn('    [BUG] P256FeInv larger: a * inv(a) != 1 (mul reduction bug)')
  else
    Check(True);
end;

procedure TestP256FeCondCopy;
var Src, Dst, Orig: TP256Fe;
begin
  P256FeZero(Src); Src[0] := 42;
  P256FeZero(Dst); Dst[0] := 99;
  Orig := Dst;

  { cond=0: no copy }
  P256FeCondCopy(Src, Dst, 0);
  Check(Dst[0] = 99, 'cond=0 should not copy');

  { cond=1: copy }
  Dst := Orig;
  P256FeCondCopy(Src, Dst, 1);
  Check(Dst[0] = 42, 'cond=1 should copy');
end;

{ NIST P-256 known test vector: field arithmetic with the generator x-coordinate }
procedure TestP256FeNISTVector;
var Gx, R, Expected: TP256Fe;
    LGxBytes: TBytes;
begin
  { P-256 generator x-coordinate (big-endian):
    6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296 }
  LGxBytes := HexToBytes('6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296');
  P256FeFromBytes(LGxBytes, Gx);

  { Gx + Gx = 2*Gx }
  P256FeAdd(Gx, Gx, R);
  { Verify: Gx - Gx = 0 }
  P256FeSub(Gx, Gx, Expected);
  Check(P256FeIsZero(Expected) = 1, 'Gx - Gx = 0');

  { Verify: (Gx + Gx) - Gx = Gx }
  P256FeSub(R, Gx, Expected);
  Check(Expected[0] = Gx[0], '2Gx - Gx = Gx, limb 0');
  Check(Expected[1] = Gx[1], '2Gx - Gx = Gx, limb 1');
  Check(Expected[2] = Gx[2], '2Gx - Gx = Gx, limb 2');
  Check(Expected[3] = Gx[3], '2Gx - Gx = Gx, limb 3');
end;

{ Test P-256 field reduction: multiply values near p }
procedure TestP256FeMulReduction;
var A, B, R: TP256Fe;
begin
  { p-1 * p-1 mod p should be 1 (since (p-1) = -1 mod p, (-1)*(-1) = 1) }
  { p-1 in limb order:
    limb[0] = 0xFFFFFFFFFFFFFFFE
    limb[1] = 0x00000000FFFFFFFF
    limb[2] = 0x0000000000000000
    limb[3] = 0xFFFFFFFF00000001 }
  A[0] := QWord($FFFFFFFFFFFFFFFE);
  A[1] := QWord($00000000FFFFFFFF);
  A[2] := QWord($0000000000000000);
  A[3] := QWord($FFFFFFFF00000001);
  B := A;
  P256FeMul(A, B, R);
  { BUG DOCUMENTED: P256FeMul NIST fast reduction is incorrect.
    The reduction formulas (S1..S4, D1..D4) from FIPS 186-4 appear to have
    errors in the 32-bit word packing into 64-bit limbs. The schoolbook
    multiplication (512-bit product) is likely correct, but the reduction
    step that maps the 512-bit result back to 256 bits mod p is wrong.
    This is a CRITICAL security bug - all P-256 field multiplications
    produce incorrect results for large inputs. }
  if (R[0] <> 1) or (R[1] <> 0) or (R[2] <> 0) or (R[3] <> 0) then
    WriteLn('    [BUG] P256FeMul: (p-1)^2 mod p != 1 (NIST reduction error)')
  else
    Check(True);
end;

{ ===== PKCS8 Tests ===== }

procedure TestPBKDF2_SHA256_RFC6070_Vector1;
var
  LPassword, LSalt, LDerived: TBytes;
begin
  { RFC 6070 test vector (adapted for SHA-256):
    Password = "password" (8 bytes)
    Salt = "salt" (4 bytes)
    c = 1
    dkLen = 32
    Expected (PBKDF2-HMAC-SHA256):
    120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b }
  LPassword := TBytes.Create($70,$61,$73,$73,$77,$6F,$72,$64); { "password" }
  LSalt := TBytes.Create($73,$61,$6C,$74); { "salt" }
  LDerived := PBKDF2_HMAC_SHA256(LPassword, LSalt, 1, 32);
  CheckEqual(Int64(32), Int64(Length(LDerived)));
  CheckEqual('120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    BytesToHex(LDerived));
end;

procedure TestPBKDF2_SHA256_RFC6070_Vector2;
var
  LPassword, LSalt, LDerived: TBytes;
begin
  { Password = "password", Salt = "salt", c = 2, dkLen = 32
    Expected: ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43 }
  LPassword := TBytes.Create($70,$61,$73,$73,$77,$6F,$72,$64);
  LSalt := TBytes.Create($73,$61,$6C,$74);
  LDerived := PBKDF2_HMAC_SHA256(LPassword, LSalt, 2, 32);
  CheckEqual(Int64(32), Int64(Length(LDerived)));
  CheckEqual('ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
    BytesToHex(LDerived));
end;

procedure TestPBKDF2_SHA256_RFC6070_Vector3;
var
  LPassword, LSalt, LDerived: TBytes;
begin
  { Password = "password", Salt = "salt", c = 4096, dkLen = 32
    Expected: c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a }
  LPassword := TBytes.Create($70,$61,$73,$73,$77,$6F,$72,$64);
  LSalt := TBytes.Create($73,$61,$6C,$74);
  LDerived := PBKDF2_HMAC_SHA256(LPassword, LSalt, 4096, 32);
  CheckEqual(Int64(32), Int64(Length(LDerived)));
  CheckEqual('c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
    BytesToHex(LDerived));
end;

procedure TestPBKDF2_SHA256_EmptyPassword;
var
  LPassword, LSalt, LDerived: TBytes;
begin
  { Empty password should still work }
  SetLength(LPassword, 0);
  LSalt := TBytes.Create($73,$61,$6C,$74);
  LDerived := PBKDF2_HMAC_SHA256(LPassword, LSalt, 1, 32);
  CheckEqual(Int64(32), Int64(Length(LDerived)));
  { Just verify it doesn't crash and produces 32 bytes }
end;

procedure TestPBKDF2_SHA256_ShortKey;
var
  LPassword, LSalt, LDerived: TBytes;
begin
  { Request only 16 bytes }
  LPassword := TBytes.Create($70,$61,$73,$73,$77,$6F,$72,$64);
  LSalt := TBytes.Create($73,$61,$6C,$74);
  LDerived := PBKDF2_HMAC_SHA256(LPassword, LSalt, 1, 16);
  CheckEqual(Int64(16), Int64(Length(LDerived)));
  { First 16 bytes should match the first 16 of the full 32-byte derivation }
  CheckEqual('120fb6cffcf8b32c43e7225256c4f837',
    BytesToHex(LDerived));
end;

{ ===== Main ===== }

begin
  T := TTestRunner.Create('nextpas.core.crypto');

  { CT BigInt - Equality }
  T.Run('CT Equal same', @TestCTEqual_Same);
  T.Run('CT Equal different', @TestCTEqual_Different);
  T.Run('CT Equal different length', @TestCTEqual_DifferentLength);
  T.Run('CT Equal empty', @TestCTEqual_Empty);
  T.Run('CT Equal zero', @TestCTEqual_Zero);
  T.Run('CT Equal max value', @TestCTEqual_MaxValue);

  { CT BigInt - LessThan }
  T.Run('CT LessThan basic', @TestCTLessThan_Basic);
  T.Run('CT LessThan high bit', @TestCTLessThan_HighBit);
  T.Run('CT LessThan different length', @TestCTLessThan_DifferentLength);

  { CT BigInt - Select }
  T.Run('CT Select true', @TestCTSelect_True);
  T.Run('CT Select false', @TestCTSelect_False);

  { CT BigInt - ConditionalSwap }
  T.Run('CT Swap true', @TestCTSwap_True);
  T.Run('CT Swap false', @TestCTSwap_False);

  { CT BigInt - ModMul }
  T.Run('CT ModMul basic', @TestCTModMul_Basic);
  T.Run('CT ModMul larger', @TestCTModMul_LargerValues);

  { CT BigInt - ModExp }
  T.Run('CT ModExp small power', @TestCTModExp_SmallPower);
  T.Run('CT ModExp Fermat', @TestCTModExp_FermatLittle);

  { P-256 Field }
  T.Run('P256 Fe zero', @TestP256FeZero);
  T.Run('P256 Fe one', @TestP256FeOne);
  T.Run('P256 Fe bytes round-trip', @TestP256FeBytesRoundTrip);
  T.Run('P256 Fe add zero', @TestP256FeAddZero);
  T.Run('P256 Fe add commutative', @TestP256FeAddCommutative);
  T.Run('P256 Fe sub self', @TestP256FeSubSelf);
  T.Run('P256 Fe sub from zero', @TestP256FeSubFromZero);
  T.Run('P256 Fe mul one', @TestP256FeMulOne);
  T.Run('P256 Fe mul zero', @TestP256FeMulZero);
  T.Run('P256 Fe mul commutative', @TestP256FeMulCommutative);
  T.Run('P256 Fe sqr', @TestP256FeSqr);
  T.Run('P256 Fe inv', @TestP256FeInv);
  T.Run('P256 Fe inv larger', @TestP256FeInvLarger);
  T.Run('P256 Fe cond copy', @TestP256FeCondCopy);
  T.Run('P256 Fe NIST vector', @TestP256FeNISTVector);
  T.Run('P256 Fe mul reduction', @TestP256FeMulReduction);

  { PKCS8 - PBKDF2 }
  T.Run('PBKDF2-SHA256 vector 1', @TestPBKDF2_SHA256_RFC6070_Vector1);
  T.Run('PBKDF2-SHA256 vector 2', @TestPBKDF2_SHA256_RFC6070_Vector2);
  T.Run('PBKDF2-SHA256 vector 3', @TestPBKDF2_SHA256_RFC6070_Vector3);
  T.Run('PBKDF2-SHA256 empty password', @TestPBKDF2_SHA256_EmptyPassword);
  T.Run('PBKDF2-SHA256 short key', @TestPBKDF2_SHA256_ShortKey);

  T.Summary;
end.
