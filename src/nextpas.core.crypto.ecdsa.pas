{**
 * Unit: nextpas.core.crypto.ecdsa
 * Purpose: TLS 1.3 CertificateVerify 用纯 Pascal ECDSA(P-256) 签名
 *
 * 说明：
 * - 仅实现当前 TLS13 server CertificateVerify 所需最小能力
 * - 曲线固定为 secp256r1 / prime256v1
 * - 使用现有纯 Pascal BigInt 模块进行模运算
 * - nonce 采用 RFC6979(HMAC-SHA256) 确定性生成
 *}

unit nextpas.core.crypto.ecdsa;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types

interface

uses
  SysUtils;

type
  TECPoint = record
    X: TBytes;
    Y: TBytes;
    IsInfinity: Boolean;
  end;

function TryECDSASignP256SHA256(
  const AMessageHash: TBytes;
  const APrivateScalar: TBytes;
  out ASignatureDER: TBytes;
  out AError: string
): Boolean;

function TryECDSAVerifyP256SHA256(
  const AMessageHash: TBytes;
  const APublicPoint: TBytes;
  const ASignatureDER: TBytes;
  out AError: string
): Boolean;

function TryP256ScalarMultBase(const AScalar: TBytes; out AResult: TECPoint; out AError: string): Boolean;
function TryP256ScalarMult(const AScalar: TBytes; const APoint: TECPoint; out AResult: TECPoint; out AError: string): Boolean;
function TryValidateP256Point(const APoint: TECPoint; out AError: string): Boolean;
function TryParseP256PublicPoint(const APublicPoint: TBytes; out APoint: TECPoint; out AError: string): Boolean;
function TryToFixedLength32(const AValue: TBytes; out AResult: TBytes; out AError: string): Boolean;

implementation

uses
  nextpas.core.tls.asn1,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.primitives;

const
  P256_FIELD_P: array[0..31] of Byte = (
    $FF, $FF, $FF, $FF, $00, $00, $00, $01,
    $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
  );

  P256_ORDER_N: array[0..31] of Byte = (
    $FF, $FF, $FF, $FF, $00, $00, $00, $00,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $BC, $E6, $FA, $AD, $A7, $17, $9E, $84,
    $F3, $B9, $CA, $C2, $FC, $63, $25, $51
  );

  P256_A: array[0..31] of Byte = (
    $FF, $FF, $FF, $FF, $00, $00, $00, $01,
    $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FC
  );

  P256_B: array[0..31] of Byte = (
    $5A, $C6, $35, $D8, $AA, $3A, $93, $E7,
    $B3, $EB, $BD, $55, $76, $98, $86, $BC,
    $65, $1D, $06, $B0, $CC, $53, $B0, $F6,
    $3B, $CE, $3C, $3E, $27, $D2, $60, $4B
  );

  P256_GX: array[0..31] of Byte = (
    $6B, $17, $D1, $F2, $E1, $2C, $42, $47,
    $F8, $BC, $E6, $E5, $63, $A4, $40, $F2,
    $77, $03, $7D, $81, $2D, $EB, $33, $A0,
    $F4, $A1, $39, $45, $D8, $98, $C2, $96
  );

  P256_GY: array[0..31] of Byte = (
    $4F, $E3, $42, $E2, $FE, $1A, $7F, $9B,
    $8E, $E7, $EB, $4A, $7C, $0F, $9E, $16,
    $2B, $CE, $33, $57, $6B, $31, $5E, $CE,
    $CB, $B6, $40, $68, $37, $BF, $51, $F5
  );

  P256_HALF_N: array[0..31] of Byte = (
    $7F, $FF, $FF, $FF, $80, $00, $00, $00,
    $7F, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $DE, $73, $7D, $56, $D3, $8B, $CF, $42,
    $79, $DC, $E5, $61, $7E, $31, $92, $A8
  );

function CopyBytes(const AData: TBytes): TBytes;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[0], Length(AData));
end;

function ConstToBytes(const AData: array of Byte): TBytes;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[0], Length(AData));
end;

function ConcatBytes(const ALeft, ARight: TBytes): TBytes;
var
  LLeftLen: Integer;
  LRightLen: Integer;
begin
  LLeftLen := Length(ALeft);
  LRightLen := Length(ARight);
  SetLength(Result, LLeftLen + LRightLen);

  if LLeftLen > 0 then
    Move(ALeft[0], Result[0], LLeftLen);
  if LRightLen > 0 then
    Move(ARight[0], Result[LLeftLen], LRightLen);
end;

function StripLeadingZeroBytes(const AData: TBytes): TBytes;
var
  I: Integer;
begin
  I := 0;
  while (I < Length(AData)) and (AData[I] = 0) do
    Inc(I);

  if I >= Length(AData) then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;

  Result := Copy(AData, I, Length(AData) - I);
end;

function IsZeroBytes(const AData: TBytes): Boolean;
var
  LNorm: TBytes;
begin
  LNorm := StripLeadingZeroBytes(AData);
  Result := (Length(LNorm) = 1) and (LNorm[0] = 0);
end;

function CompareUnsignedBytes(const ALeft, ARight: TBytes): Integer;
var
  LLeft: TBytes;
  LRight: TBytes;
  I: Integer;
begin
  LLeft := StripLeadingZeroBytes(ALeft);
  LRight := StripLeadingZeroBytes(ARight);

  if Length(LLeft) < Length(LRight) then
    Exit(-1);
  if Length(LLeft) > Length(LRight) then
    Exit(1);

  for I := 0 to Length(LLeft) - 1 do
  begin
    if LLeft[I] < LRight[I] then
      Exit(-1);
    if LLeft[I] > LRight[I] then
      Exit(1);
  end;

  Result := 0;
end;

function UnsignedBytesEqual(const ALeft, ARight: TBytes): Boolean;
begin
  Result := CompareUnsignedBytes(ALeft, ARight) = 0;
end;

function TryUnsignedSubtractSmall(const AValue: TBytes; ASub: Byte; out AResult: TBytes): Boolean;
var
  I: Integer;
  LBorrow: Integer;
begin
  AResult := Copy(AValue, 0, Length(AValue));
  Result := False;

  if Length(AResult) = 0 then
    Exit;

  LBorrow := ASub;
  I := High(AResult);
  while (I >= 0) and (LBorrow > 0) do
  begin
    if Integer(AResult[I]) >= LBorrow then
    begin
      AResult[I] := Byte(Integer(AResult[I]) - LBorrow);
      LBorrow := 0;
    end
    else
    begin
      AResult[I] := Byte(256 + Integer(AResult[I]) - LBorrow);
      LBorrow := 1;
    end;
    Dec(I);
  end;

  if LBorrow <> 0 then
    Exit;

  AResult := StripLeadingZeroBytes(AResult);
  Result := True;
end;

function TryUnsignedSubtractAssumingGE(const ALeft, ARight: TBytes; out AResult: TBytes): Boolean;
var
  LLeft: TBytes;
  LRight: TBytes;
  I: Integer;
  J: Integer;
  LLen: Integer;
  LBorrow: Integer;
  LA: Integer;
  LB: Integer;
  LDiff: Integer;
begin
  Result := False;
  SetLength(AResult, 0);

  if CompareUnsignedBytes(ALeft, ARight) < 0 then
    Exit;

  LLeft := StripLeadingZeroBytes(ALeft);
  LRight := StripLeadingZeroBytes(ARight);

  if Length(LLeft) = 0 then
  begin
    SetLength(AResult, 1);
    AResult[0] := 0;
    Exit(True);
  end;

  LLen := Length(LLeft);
  SetLength(AResult, LLen);

  LBorrow := 0;
  J := Length(LRight) - 1;
  for I := LLen - 1 downto 0 do
  begin
    LA := Integer(LLeft[I]) - LBorrow;
    if J >= 0 then
      LB := Integer(LRight[J])
    else
      LB := 0;

    if LA >= LB then
    begin
      LDiff := LA - LB;
      LBorrow := 0;
    end
    else
    begin
      LDiff := LA + 256 - LB;
      LBorrow := 1;
    end;

    AResult[I] := Byte(LDiff and $FF);
    Dec(J);
  end;

  if LBorrow <> 0 then
    Exit(False);

  AResult := StripLeadingZeroBytes(AResult);
  Result := True;
end;

function TryMod(const AValue, AModulus: TBytes; out AResult: TBytes; out AError: string): Boolean;
begin
  Result := TryBigIntModFromUnsignedBytes(AValue, AModulus, AResult, AError);
end;

function TryModAdd(const ALeft, ARight, AModulus: TBytes; out AResult: TBytes; out AError: string): Boolean;
var
  LSum: TBytes;
begin
  SetLength(AResult, 0);
  AError := '';
  Result := False;

  if not TryBigIntAddFromUnsignedBytes(ALeft, ARight, LSum, AError) then
    Exit;

  Result := TryBigIntModFromUnsignedBytes(LSum, AModulus, AResult, AError);
end;

function TryModSub(const ALeft, ARight, AModulus: TBytes; out AResult: TBytes; out AError: string): Boolean;
begin
  Result := TryBigIntSubtractModuloFromUnsignedBytes(ALeft, ARight, AModulus, AResult, AError);
end;

function TryModMul(const ALeft, ARight, AModulus: TBytes; out AResult: TBytes; out AError: string): Boolean;
begin
  Result := TryBigIntModMulFromUnsignedBytes(ALeft, ARight, AModulus, AResult, AError);
end;

function TryModInvPrime(const AValue, APrimeModulus: TBytes; out AInverse: TBytes; out AError: string): Boolean;
var
  LExponent: TBytes;
begin
  SetLength(AInverse, 0);
  AError := '';
  Result := False;

  if not TryUnsignedSubtractSmall(StripLeadingZeroBytes(APrimeModulus), 2, LExponent) then
  begin
    AError := 'Invalid modulus for modular inverse';
    Exit;
  end;

  Result := TryBigIntModExpFromUnsignedBytes(AValue, LExponent, APrimeModulus, AInverse, AError);
end;

function TryToFixedLength32(const AValue: TBytes; out AResult: TBytes; out AError: string): Boolean;
begin
  Result := TryBigIntToFixedLengthFromUnsignedBytes(AValue, 32, AResult, AError);
end;

function P256InfinityPoint: TECPoint;
begin
  SetLength(Result.X, 0);
  SetLength(Result.Y, 0);
  Result.IsInfinity := True;
end;

function P256GeneratorPoint: TECPoint;
begin
  Result.X := ConstToBytes(P256_GX);
  Result.Y := ConstToBytes(P256_GY);
  Result.IsInfinity := False;
end;

function TryP256PointDouble(const AP: TECPoint; out AResult: TECPoint; out AError: string): Boolean;
var
  LP: TBytes;
  LA: TBytes;
  LTmp: TBytes;
  LX2: TBytes;
  LThreeX2: TBytes;
  LNum: TBytes;
  LDen: TBytes;
  LDenInv: TBytes;
  LLambda: TBytes;
  LLambda2: TBytes;
  LTwoX: TBytes;
  LX3: TBytes;
  LXMinusX3: TBytes;
  LY3: TBytes;
begin
  AResult := P256InfinityPoint;
  AError := '';
  Result := False;

  if AP.IsInfinity then
  begin
    AResult := AP;
    Exit(True);
  end;

  if IsZeroBytes(AP.Y) then
  begin
    AResult := P256InfinityPoint;
    Exit(True);
  end;

  LP := ConstToBytes(P256_FIELD_P);
  LA := ConstToBytes(P256_A);

  if not TryModMul(AP.X, AP.X, LP, LX2, AError) then
    Exit;

  if not TryModAdd(LX2, LX2, LP, LThreeX2, AError) then
    Exit;
  if not TryModAdd(LThreeX2, LX2, LP, LTmp, AError) then
    Exit;
  LThreeX2 := LTmp;

  if not TryModAdd(LThreeX2, LA, LP, LNum, AError) then
    Exit;

  if not TryModAdd(AP.Y, AP.Y, LP, LDen, AError) then
    Exit;

  if not TryModInvPrime(LDen, LP, LDenInv, AError) then
    Exit;

  if not TryModMul(LNum, LDenInv, LP, LLambda, AError) then
    Exit;

  if not TryModMul(LLambda, LLambda, LP, LLambda2, AError) then
    Exit;

  if not TryModAdd(AP.X, AP.X, LP, LTwoX, AError) then
    Exit;

  if not TryModSub(LLambda2, LTwoX, LP, LX3, AError) then
    Exit;

  if not TryModSub(AP.X, LX3, LP, LXMinusX3, AError) then
    Exit;

  if not TryModMul(LLambda, LXMinusX3, LP, LY3, AError) then
    Exit;

  if not TryModSub(LY3, AP.Y, LP, LTmp, AError) then
    Exit;
  LY3 := LTmp;

  AResult.X := StripLeadingZeroBytes(LX3);
  AResult.Y := StripLeadingZeroBytes(LY3);
  AResult.IsInfinity := False;
  Result := True;
end;

function TryP256PointAdd(const AP, AQ: TECPoint; out AResult: TECPoint; out AError: string): Boolean;
var
  LP: TBytes;
  LTmp: TBytes;
  LSumY: TBytes;
  LNum: TBytes;
  LDen: TBytes;
  LDenInv: TBytes;
  LLambda: TBytes;
  LLambda2: TBytes;
  LX3: TBytes;
  LXMinusX3: TBytes;
  LY3: TBytes;
begin
  AResult := P256InfinityPoint;
  AError := '';
  Result := False;

  if AP.IsInfinity then
  begin
    AResult := AQ;
    Exit(True);
  end;

  if AQ.IsInfinity then
  begin
    AResult := AP;
    Exit(True);
  end;

  LP := ConstToBytes(P256_FIELD_P);

  if UnsignedBytesEqual(AP.X, AQ.X) then
  begin
    if UnsignedBytesEqual(AP.Y, AQ.Y) then
      Exit(TryP256PointDouble(AP, AResult, AError));

    if not TryModAdd(AP.Y, AQ.Y, LP, LSumY, AError) then
      Exit;

    if IsZeroBytes(LSumY) then
    begin
      AResult := P256InfinityPoint;
      Exit(True);
    end;

    AError := 'Invalid EC point addition input';
    Exit(False);
  end;

  if not TryModSub(AQ.Y, AP.Y, LP, LNum, AError) then
    Exit;

  if not TryModSub(AQ.X, AP.X, LP, LDen, AError) then
    Exit;

  if not TryModInvPrime(LDen, LP, LDenInv, AError) then
    Exit;

  if not TryModMul(LNum, LDenInv, LP, LLambda, AError) then
    Exit;

  if not TryModMul(LLambda, LLambda, LP, LLambda2, AError) then
    Exit;

  if not TryModSub(LLambda2, AP.X, LP, LX3, AError) then
    Exit;

  if not TryModSub(LX3, AQ.X, LP, LTmp, AError) then
    Exit;
  LX3 := LTmp;

  if not TryModSub(AP.X, LX3, LP, LXMinusX3, AError) then
    Exit;

  if not TryModMul(LLambda, LXMinusX3, LP, LY3, AError) then
    Exit;

  if not TryModSub(LY3, AP.Y, LP, LTmp, AError) then
    Exit;
  LY3 := LTmp;

  AResult.X := StripLeadingZeroBytes(LX3);
  AResult.Y := StripLeadingZeroBytes(LY3);
  AResult.IsInfinity := False;
  Result := True;
end;

function TryP256ScalarMult(const AScalar: TBytes; const APoint: TECPoint; out AResult: TECPoint; out AError: string): Boolean;
var
  LScalar32: TBytes;
  LR0, LR1: TECPoint;
  LAddResult, LDblResult: TECPoint;
  LByteIndex: Integer;
  LBitIndex: Integer;
  LBit: Integer;
  LSwap: Integer;
  LPrevSwap: Integer;

  procedure CTSwapPoint(var A, B: TECPoint; AFlag: Integer);
  var
    LMask: Byte;
    I, LLen: Integer;
    LTmp: Byte;
    LA32, LB32: TBytes;
    LAErr: string;
    LInfA, LInfB, LInfTmp: Byte;
  begin
    LMask := Byte(-AFlag and $FF);
    LLen := 32;
    if not TryToFixedLength32(A.X, LA32, LAErr) then SetLength(LA32, LLen);
    if not TryToFixedLength32(B.X, LB32, LAErr) then SetLength(LB32, LLen);
    for I := 0 to LLen - 1 do
    begin
      LTmp := LMask and (LA32[I] xor LB32[I]);
      LA32[I] := LA32[I] xor LTmp;
      LB32[I] := LB32[I] xor LTmp;
    end;
    A.X := LA32; B.X := LB32;

    if not TryToFixedLength32(A.Y, LA32, LAErr) then SetLength(LA32, LLen);
    if not TryToFixedLength32(B.Y, LB32, LAErr) then SetLength(LB32, LLen);
    for I := 0 to LLen - 1 do
    begin
      LTmp := LMask and (LA32[I] xor LB32[I]);
      LA32[I] := LA32[I] xor LTmp;
      LB32[I] := LB32[I] xor LTmp;
    end;
    A.Y := LA32; B.Y := LB32;

    LInfA := Byte(A.IsInfinity);
    LInfB := Byte(B.IsInfinity);
    LInfTmp := LMask and (LInfA xor LInfB);
    A.IsInfinity := Boolean(LInfA xor LInfTmp);
    B.IsInfinity := Boolean(LInfB xor LInfTmp);
  end;

begin
  AResult := P256InfinityPoint;
  AError := '';
  Result := False;

  if not TryToFixedLength32(StripLeadingZeroBytes(AScalar), LScalar32, AError) then
    Exit;

  // Montgomery ladder: constant-time scalar multiplication.
  // R0 starts at infinity, R1 starts at the input point.
  // Each iteration: swap based on current bit, then R1=Add(R0,R1), R0=Double(R0), swap back.
  LR0 := P256InfinityPoint;
  LR1 := APoint;
  LPrevSwap := 0;

  for LByteIndex := 0 to 31 do
  begin
    for LBitIndex := 7 downto 0 do
    begin
      LBit := (LScalar32[LByteIndex] shr LBitIndex) and 1;
      LSwap := LBit xor LPrevSwap;
      CTSwapPoint(LR0, LR1, LSwap);
      LPrevSwap := LBit;

      if not TryP256PointAdd(LR0, LR1, LAddResult, AError) then Exit;
      if not TryP256PointDouble(LR0, LDblResult, AError) then Exit;
      LR1 := LAddResult;
      LR0 := LDblResult;
    end;
  end;
  CTSwapPoint(LR0, LR1, LPrevSwap);

  AResult := LR0;
  Result := True;
end;

function TryP256ScalarMultBase(const AScalar: TBytes; out AResult: TECPoint; out AError: string): Boolean;
var
  LG: TECPoint;
begin
  LG := P256GeneratorPoint;
  Result := TryP256ScalarMult(AScalar, LG, AResult, AError);
end;

function TryValidateP256Point(const APoint: TECPoint; out AError: string): Boolean;
var
  LP: TBytes;
  LA: TBytes;
  LB: TBytes;
  LY2: TBytes;
  LX2: TBytes;
  LX3: TBytes;
  LAx: TBytes;
  LRhs: TBytes;
  LTmp: TBytes;
begin
  AError := '';
  Result := False;

  if APoint.IsInfinity then
  begin
    AError := 'ECDSA public point must not be infinity';
    Exit;
  end;

  LP := ConstToBytes(P256_FIELD_P);
  LA := ConstToBytes(P256_A);
  LB := ConstToBytes(P256_B);

  if (CompareUnsignedBytes(APoint.X, LP) >= 0) or
    (CompareUnsignedBytes(APoint.Y, LP) >= 0) then
  begin
    AError := 'ECDSA public point coordinates are out of range';
    Exit;
  end;

  if not TryModMul(APoint.Y, APoint.Y, LP, LY2, AError) then
    Exit;
  if not TryModMul(APoint.X, APoint.X, LP, LX2, AError) then
    Exit;
  if not TryModMul(LX2, APoint.X, LP, LX3, AError) then
    Exit;
  if not TryModMul(LA, APoint.X, LP, LAx, AError) then
    Exit;
  if not TryModAdd(LX3, LAx, LP, LRhs, AError) then
    Exit;
  if not TryModAdd(LRhs, LB, LP, LTmp, AError) then
    Exit;
  LRhs := LTmp;

  if not UnsignedBytesEqual(LY2, LRhs) then
  begin
    AError := 'ECDSA public point is not on secp256r1';
    Exit;
  end;

  Result := True;
end;

function TryParseP256PublicPoint(
  const APublicPoint: TBytes;
  out APoint: TECPoint;
  out AError: string
): Boolean;
begin
  APoint := P256InfinityPoint;
  AError := '';
  Result := False;

  if Length(APublicPoint) <> 65 then
  begin
    AError := 'ECDSA secp256r1 public point must be uncompressed 65-byte form';
    Exit;
  end;

  if APublicPoint[0] <> $04 then
  begin
    AError := 'ECDSA secp256r1 public point must use uncompressed form';
    Exit;
  end;

  APoint.X := StripLeadingZeroBytes(Copy(APublicPoint, 1, 32));
  APoint.Y := StripLeadingZeroBytes(Copy(APublicPoint, 33, 32));
  APoint.IsInfinity := False;

  Result := TryValidateP256Point(APoint, AError);
end;

function Bits2OctetsP256(const AInput: TBytes): TBytes;
var
  LN: TBytes;
begin
  LN := ConstToBytes(P256_ORDER_N);
  Result := Copy(AInput, 0, Length(AInput));

  if Length(Result) > 32 then
    SetLength(Result, 32);

  if CompareUnsignedBytes(Result, LN) >= 0 then
    TryUnsignedSubtractAssumingGE(Result, LN, Result);

  Result := StripLeadingZeroBytes(Result);
end;

function Int2OctetsP256(const AInput: TBytes): TBytes;
var
  LErr: string;
begin
  if not TryBigIntToFixedLengthFromUnsignedBytes(AInput, 32, Result, LErr) then
  begin
    SetLength(Result, 32);
    FillChar(Result[0], 32, 0);
  end;
end;

function RFC6979ConcatVTagged(const AV: TBytes; ATag: Byte; const AX, AH1: TBytes): TBytes;
var
  LTagArr: TBytes;
begin
  SetLength(LTagArr, 1);
  LTagArr[0] := ATag;
  Result := ConcatBytes(AV, LTagArr);
  Result := ConcatBytes(Result, AX);
  Result := ConcatBytes(Result, AH1);
end;

function TryRFC6979NextK(
  var AK: TBytes;
  var AV: TBytes;
  const AOrder: TBytes;
  out AKCandidate: TBytes;
  out AError: string
): Boolean;
var
  LT: TBytes;
  LZeroTag: TBytes;
begin
  SetLength(AKCandidate, 0);
  AError := '';
  Result := False;

  while True do
  begin
    AV := HMAC_SHA256(AK, AV);
    LT := CopyBytes(AV);

    AKCandidate := StripLeadingZeroBytes(LT);
    if (not IsZeroBytes(AKCandidate)) and (CompareUnsignedBytes(AKCandidate, AOrder) < 0) then
      Exit(True);

    SetLength(LZeroTag, 1);
    LZeroTag[0] := 0;
    AK := HMAC_SHA256(AK, ConcatBytes(AV, LZeroTag));
    AV := HMAC_SHA256(AK, AV);
  end;
end;

function TryBuildECDSASignatureDER(const AR, ASValue: TBytes; out ASignature: TBytes; out AError: string): Boolean;
var
  LWriter: TASN1Writer;
begin
  SetLength(ASignature, 0);
  AError := '';
  Result := False;

  LWriter := TASN1Writer.Create;
  try
    LWriter.BeginSequence;
    LWriter.WriteBigInteger(StripLeadingZeroBytes(AR));
    LWriter.WriteBigInteger(StripLeadingZeroBytes(ASValue));
    LWriter.EndSequence;
    ASignature := LWriter.GetData;
    Result := True;
  finally
    LWriter.Free;
  end;
end;

function TryParseECDSASignatureDER(
  const ASignatureDER: TBytes;
  out AR, ASValue: TBytes;
  out AError: string
): Boolean;
var
  LReader: TASN1Reader;
  LRoot: TASN1Node;
  LOrder: TBytes;
begin
  SetLength(AR, 0);
  SetLength(ASValue, 0);
  AError := '';
  Result := False;

  if Length(ASignatureDER) = 0 then
  begin
    AError := 'ECDSA signature DER is empty';
    Exit;
  end;

  LReader := TASN1Reader.Create(ASignatureDER);
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'ECDSA signature DER parse failed: ' + E.Message;
        Exit;
      end;
    end;

    try
      if (LRoot = nil) or (not LRoot.IsSequence) or (LRoot.ChildCount <> 2) then
      begin
        AError := 'ECDSA signature DER must be ASN.1 SEQUENCE of two INTEGERs';
        Exit;
      end;

      if (not LRoot.GetChild(0).IsInteger) or (not LRoot.GetChild(1).IsInteger) then
      begin
        AError := 'ECDSA signature DER fields must be INTEGERs';
        Exit;
      end;

      AR := StripLeadingZeroBytes(LRoot.GetChild(0).AsBigInteger);
      ASValue := StripLeadingZeroBytes(LRoot.GetChild(1).AsBigInteger);
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;

  if IsZeroBytes(AR) or IsZeroBytes(ASValue) then
  begin
    AError := 'ECDSA signature DER r/s must be non-zero';
    Exit;
  end;

  LOrder := ConstToBytes(P256_ORDER_N);
  if (CompareUnsignedBytes(AR, LOrder) >= 0) or
    (CompareUnsignedBytes(ASValue, LOrder) >= 0) then
  begin
    AError := 'ECDSA signature DER r/s must be less than curve order';
    Exit;
  end;

  Result := True;
end;

function TryECDSAVerifyP256SHA256(
  const AMessageHash: TBytes;
  const APublicPoint: TBytes;
  const ASignatureDER: TBytes;
  out AError: string
): Boolean;
var
  LOrder: TBytes;
  LPublicPoint: TECPoint;
  LR: TBytes;
  LS: TBytes;
  LE: TBytes;
  LW: TBytes;
  LU1: TBytes;
  LU2: TBytes;
  LPoint1: TECPoint;
  LPoint2: TECPoint;
  LSumPoint: TECPoint;
  LXModN: TBytes;
begin
  AError := '';
  Result := False;

  if Length(AMessageHash) <> 32 then
  begin
    AError := 'ECDSA P-256 verifier requires SHA-256 hash input (32 bytes)';
    Exit;
  end;

  if not TryParseECDSASignatureDER(ASignatureDER, LR, LS, AError) then
    Exit;
  if not TryParseP256PublicPoint(APublicPoint, LPublicPoint, AError) then
    Exit;

  LOrder := ConstToBytes(P256_ORDER_N);
  LE := Bits2OctetsP256(AMessageHash);

  if not TryModInvPrime(LS, LOrder, LW, AError) then
    Exit;
  if not TryModMul(LE, LW, LOrder, LU1, AError) then
    Exit;
  if not TryModMul(LR, LW, LOrder, LU2, AError) then
    Exit;

  if not TryP256ScalarMultBase(LU1, LPoint1, AError) then
    Exit;
  if not TryP256ScalarMult(LU2, LPublicPoint, LPoint2, AError) then
    Exit;
  if not TryP256PointAdd(LPoint1, LPoint2, LSumPoint, AError) then
    Exit;

  if LSumPoint.IsInfinity then
  begin
    AError := 'ECDSA verification point is infinity';
    Exit;
  end;

  if not TryMod(LSumPoint.X, LOrder, LXModN, AError) then
    Exit;

  if not UnsignedBytesEqual(LXModN, LR) then
  begin
    AError := 'ECDSA signature does not match public key';
    Exit;
  end;

  Result := True;
end;

function TryECDSASignP256SHA256(
  const AMessageHash: TBytes;
  const APrivateScalar: TBytes;
  out ASignatureDER: TBytes;
  out AError: string
): Boolean;
var
  LN: TBytes;
  LD: TBytes;
  LE: TBytes;
  LK: TBytes;
  LV: TBytes;
  LX: TBytes;
  LH1: TBytes;
  LCandidateK: TBytes;
  LRPoint: TECPoint;
  LR: TBytes;
  LRD: TBytes;
  LSum: TBytes;
  LKInv: TBytes;
  LS: TBytes;
  LTmp: TBytes;
  LTagArr: TBytes;
  I: Integer;
begin
  SetLength(ASignatureDER, 0);
  AError := '';
  Result := False;

  if Length(AMessageHash) <> 32 then
  begin
    AError := 'ECDSA P-256 signer requires SHA-256 hash input (32 bytes)';
    Exit;
  end;

  LN := ConstToBytes(P256_ORDER_N);

  if not TryMod(StripLeadingZeroBytes(APrivateScalar), LN, LD, AError) then
    Exit;

  if IsZeroBytes(LD) then
  begin
    AError := 'ECDSA private scalar is zero';
    Exit;
  end;

  LE := Bits2OctetsP256(AMessageHash);

  LX := Int2OctetsP256(LD);
  LH1 := Int2OctetsP256(LE);

  SetLength(LV, 32);
  SetLength(LK, 32);
  FillChar(LV[0], 32, $01);
  FillChar(LK[0], 32, $00);

  LK := HMAC_SHA256(LK, RFC6979ConcatVTagged(LV, 0, LX, LH1));
  LV := HMAC_SHA256(LK, LV);
  LK := HMAC_SHA256(LK, RFC6979ConcatVTagged(LV, 1, LX, LH1));
  LV := HMAC_SHA256(LK, LV);

  for I := 1 to 64 do
  begin
    if not TryRFC6979NextK(LK, LV, LN, LCandidateK, AError) then
      Exit;

    if not TryP256ScalarMultBase(LCandidateK, LRPoint, AError) then
      Exit;

    if LRPoint.IsInfinity then
      Continue;

    if not TryMod(LRPoint.X, LN, LR, AError) then
      Exit;

    if IsZeroBytes(LR) then
      Continue;

    if not TryModMul(LR, LD, LN, LRD, AError) then
      Exit;

    if not TryModAdd(LRD, LE, LN, LSum, AError) then
      Exit;

    if not TryModInvPrime(LCandidateK, LN, LKInv, AError) then
      Exit;

    if not TryModMul(LKInv, LSum, LN, LS, AError) then
      Exit;

    if IsZeroBytes(LS) then
      Continue;

    if CompareUnsignedBytes(LS, ConstToBytes(P256_HALF_N)) > 0 then
    begin
      if not TryUnsignedSubtractAssumingGE(LN, LS, LTmp) then
      begin
        AError := 'Failed to normalize ECDSA S value';
        Exit;
      end;
      LS := LTmp;
    end;

    if not TryBuildECDSASignatureDER(LR, LS, ASignatureDER, AError) then
      Exit;

    Exit(True);
  end;

  SetLength(LTagArr, 1);
  LTagArr[0] := 0;
  LK := HMAC_SHA256(LK, ConcatBytes(LV, LTagArr));
  LV := HMAC_SHA256(LK, LV);

  AError := 'ECDSA signing failed after repeated nonce attempts';
end;

end.
