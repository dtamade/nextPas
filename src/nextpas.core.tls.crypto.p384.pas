unit nextpas.core.tls.crypto.p384;
{ WARNING: This module is EXPERIMENTAL. Not all APIs are fully implemented. }

{$mode objfpc}{$H+}{$J-}
{$WARN 5093 off}

interface

uses
  SysUtils;

type
  TP384Point = record
    X: TBytes;
    Y: TBytes;
  end;

function TryP384ScalarMultBase(const AScalar: TBytes; out AResult: TP384Point;
  out AError: string): Boolean;
function TryP384ScalarMult(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
function TryP384ECDHEKeyPair(out APrivateKey: TBytes; out APublicKey: TBytes;
  out AError: string): Boolean;
function TryP384ECDHE(const APrivateKey: TBytes; const APeerPublicKey: TBytes;
  out ASharedSecret: TBytes; out AError: string): Boolean;
function TryP384ECDSAVerify(const AHash: TBytes; const ASignature: TBytes;
  const APublicKey: TP384Point; out AError: string): Boolean;
function TryP384ECDSAVerifyDER(const AHash: TBytes; const ASignatureDER: TBytes;
  const APublicKey: TP384Point; out AError: string): Boolean;
function TryP384ValidatePublicKey(const APeerPublicKey: TBytes; out AError: string): Boolean;

implementation

uses
  nextpas.core.tls.asn1,
  nextpas.core.tls.crypto.bigint,
  nextpas.core.tls.random;

const
  P384_P_HEX = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFF';
  P384_N_HEX = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC7634D81F4372DDF581A0DB248B0A77AECEC196ACCC52973';
  P384_B_HEX = 'B3312FA7E23EE7E4988E056BE3F82D19181D9C6EFE8141120314088F5013875AC656398D8A2ED19D2A85C8EDD3EC2AEF';

  P384_GX_HEX = 'AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7';
  P384_GY_HEX = '3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F';

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function P384ModP: TBytes;
begin
  Result := HexToBytes(P384_P_HEX);
end;

function P384Order: TBytes;
begin
  Result := HexToBytes(P384_N_HEX);
end;

function P384Generator: TP384Point;
begin
  Result.X := HexToBytes(P384_GX_HEX);
  Result.Y := HexToBytes(P384_GY_HEX);
end;

function P384InfinityPoint: TP384Point;
begin
  SetLength(Result.X, 0);
  SetLength(Result.Y, 0);
end;

function P384PointIsInfinity(const APoint: TP384Point): Boolean;
var
  I: Integer;
  LAllZero: Boolean;
begin
  if (Length(APoint.X) = 0) and (Length(APoint.Y) = 0) then
    Exit(True);
  if (Length(APoint.X) <> Length(APoint.Y)) then
    Exit(False);
  LAllZero := True;
  for I := 0 to Length(APoint.X) - 1 do
    if APoint.X[I] <> 0 then begin LAllZero := False; Break; end;
  if not LAllZero then Exit(False);
  for I := 0 to Length(APoint.Y) - 1 do
    if APoint.Y[I] <> 0 then begin LAllZero := False; Break; end;
  Result := LAllZero;
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
  LLeft, LRight: TBytes;
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

function TryFixedLength48(const AValue: TBytes; out AResult: TBytes; out AError: string): Boolean;
begin
  Result := TryBigIntToFixedLengthFromUnsignedBytes(StripLeadingZeroBytes(AValue), 48, AResult, AError);
end;

function TryP384PointDouble(const AP: TP384Point; out AResult: TP384Point;
  out AError: string): Boolean; forward;

function TryP384PointAdd(const AP, AQ: TP384Point; out AResult: TP384Point;
  out AError: string): Boolean;
var
  LP, LLambda, LNum, LDen, LDenInv, LLambda2, LX3, LY3, LSumY, LTmp: TBytes;
begin
  Result := False;
  AResult := P384InfinityPoint;
  AError := '';

  if P384PointIsInfinity(AP) then
  begin
    AResult := AQ;
    Exit(True);
  end;
  if P384PointIsInfinity(AQ) then
  begin
    AResult := AP;
    Exit(True);
  end;

  LP := P384ModP;

  if UnsignedBytesEqual(AP.X, AQ.X) then
  begin
    if UnsignedBytesEqual(AP.Y, AQ.Y) then
      Exit(TryP384PointDouble(AP, AResult, AError));

    if not TryBigIntAddFromUnsignedBytes(AP.Y, AQ.Y, LSumY, AError) then Exit;
    if not TryBigIntModFromUnsignedBytes(LSumY, LP, LTmp, AError) then Exit;
    if IsZeroBytes(LTmp) then
    begin
      AResult := P384InfinityPoint;
      Exit(True);
    end;

    AError := 'Invalid P-384 point addition input';
    Exit;
  end;

  if not TryBigIntSubtractModuloFromUnsignedBytes(AQ.X, AP.X, LP, LDen, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(AQ.Y, AP.Y, LP, LNum, AError) then Exit;
  if not TryBigIntModExpFromUnsignedBytes(LDen, HexToBytes(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFD'),
    LP, LDenInv, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(LNum, LDenInv, LP, LLambda, AError) then Exit;

  if not TryBigIntModMulFromUnsignedBytes(LLambda, LLambda, LP, LLambda2, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(LLambda2, AP.X, LP, LX3, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(LX3, AQ.X, LP, LTmp, AError) then Exit;
  LX3 := LTmp;

  if not TryBigIntSubtractModuloFromUnsignedBytes(AP.X, LX3, LP, LY3, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(LLambda, LY3, LP, LTmp, AError) then Exit;
  LY3 := LTmp;
  if not TryBigIntSubtractModuloFromUnsignedBytes(LY3, AP.Y, LP, LTmp, AError) then Exit;
  LY3 := LTmp;

  AResult.X := LX3;
  AResult.Y := LY3;
  Result := True;
end;

function TryP384PointDouble(const AP: TP384Point; out AResult: TP384Point;
  out AError: string): Boolean;
var
  LP, LLambda, LNum, LDen, LDenInv, LLambda2, LX3, LY3, LThree, LTwo, LTmp: TBytes;
begin
  Result := False;
  AResult := P384InfinityPoint;
  AError := '';

  if P384PointIsInfinity(AP) then
  begin
    AResult := AP;
    Exit(True);
  end;

  if IsZeroBytes(AP.Y) then
  begin
    AResult := P384InfinityPoint;
    Exit(True);
  end;

  LP := P384ModP;
  LThree := HexToBytes('03');
  LTwo := HexToBytes('02');

  if not TryBigIntModMulFromUnsignedBytes(AP.X, AP.X, LP, LNum, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(LNum, LThree, LP, LTmp, AError) then Exit;
  LNum := LTmp;
  // a = -3 for P-384, so add a: num = 3*x^2 + a = 3*x^2 - 3
  if not TryBigIntSubtractModuloFromUnsignedBytes(LNum, LThree, LP, LTmp, AError) then Exit;
  LNum := LTmp;

  if not TryBigIntModMulFromUnsignedBytes(AP.Y, LTwo, LP, LDen, AError) then Exit;
  if not TryBigIntModExpFromUnsignedBytes(LDen, HexToBytes(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFD'),
    LP, LDenInv, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(LNum, LDenInv, LP, LLambda, AError) then Exit;

  if not TryBigIntModMulFromUnsignedBytes(LLambda, LLambda, LP, LLambda2, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(LLambda2, AP.X, LP, LX3, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(LX3, AP.X, LP, LTmp, AError) then Exit;
  LX3 := LTmp;

  if not TryBigIntSubtractModuloFromUnsignedBytes(AP.X, LX3, LP, LY3, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(LLambda, LY3, LP, LTmp, AError) then Exit;
  LY3 := LTmp;
  if not TryBigIntSubtractModuloFromUnsignedBytes(LY3, AP.Y, LP, LTmp, AError) then Exit;
  LY3 := LTmp;

  AResult.X := LX3;
  AResult.Y := LY3;
  Result := True;
end;

function TryP384ScalarMultBase(const AScalar: TBytes; out AResult: TP384Point;
  out AError: string): Boolean;
begin
  Result := TryP384ScalarMult(AScalar, P384Generator, AResult, AError);
end;

function TryP384ScalarMult(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
var
  LScalar48: TBytes;
  LR0, LR1: TP384Point;
  LAddResult, LDblResult: TP384Point;
  LByteIndex, LBitIndex: Integer;
  LBit: Integer;
  LSwap, LPrevSwap: Integer;

  procedure CTSwapP384(var A, B: TP384Point; AFlag: Integer);
  var
    LMask: Byte;
    I: Integer;
    LTmp: Byte;
    LA48, LB48: TBytes;
    LErr: string;
  begin
    LMask := Byte(-AFlag and $FF);
    if not TryFixedLength48(A.X, LA48, LErr) then SetLength(LA48, 48);
    if not TryFixedLength48(B.X, LB48, LErr) then SetLength(LB48, 48);
    for I := 0 to 47 do
    begin
      LTmp := LMask and (LA48[I] xor LB48[I]);
      LA48[I] := LA48[I] xor LTmp;
      LB48[I] := LB48[I] xor LTmp;
    end;
    A.X := LA48; B.X := LB48;

    if not TryFixedLength48(A.Y, LA48, LErr) then SetLength(LA48, 48);
    if not TryFixedLength48(B.Y, LB48, LErr) then SetLength(LB48, 48);
    for I := 0 to 47 do
    begin
      LTmp := LMask and (LA48[I] xor LB48[I]);
      LA48[I] := LA48[I] xor LTmp;
      LB48[I] := LB48[I] xor LTmp;
    end;
    A.Y := LA48; B.Y := LB48;
  end;

begin
  Result := False;
  AResult := P384InfinityPoint;
  AError := '';

  if not TryFixedLength48(AScalar, LScalar48, AError) then
    Exit;

  LR0 := P384InfinityPoint;
  LR1 := APoint;
  LPrevSwap := 0;

  for LByteIndex := 0 to 47 do
  begin
    for LBitIndex := 7 downto 0 do
    begin
      LBit := (LScalar48[LByteIndex] shr LBitIndex) and 1;
      LSwap := LBit xor LPrevSwap;
      CTSwapP384(LR0, LR1, LSwap);
      LPrevSwap := LBit;

      if not TryP384PointAdd(LR0, LR1, LAddResult, AError) then Exit;
      if not TryP384PointDouble(LR0, LDblResult, AError) then Exit;
      LR1 := LAddResult;
      LR0 := LDblResult;
    end;
  end;
  CTSwapP384(LR0, LR1, LPrevSwap);

  if P384PointIsInfinity(LR0) then
  begin
    AError := 'Scalar is zero';
    Exit;
  end;

  AResult := LR0;
  Result := True;
end;

function TryP384ECDHEKeyPair(out APrivateKey: TBytes; out APublicKey: TBytes;
  out AError: string): Boolean;
var
  LPoint: TP384Point;
  LX, LY: TBytes;
begin
  Result := False;
  APrivateKey := GenerateSecureRandomBytes(48);
  APrivateKey[0] := APrivateKey[0] and $7F;

  if not TryP384ScalarMultBase(APrivateKey, LPoint, AError) then Exit;
  if not TryFixedLength48(LPoint.X, LX, AError) then Exit;
  if not TryFixedLength48(LPoint.Y, LY, AError) then Exit;

  SetLength(APublicKey, 97);
  APublicKey[0] := $04;
  Move(LX[0], APublicKey[1], 48);
  Move(LY[0], APublicKey[49], 48);
  Result := True;
end;



function TryP384ValidatePublicKey(const APeerPublicKey: TBytes; out AError: string): Boolean;
var
  LX, LY, LP, LB, LY2, LX2, LX3, LThreeX, LRhs, LOne, LTemp: TBytes;
  LErr: string;
begin
  Result := False;

  if (Length(APeerPublicKey) <> 97) or (APeerPublicKey[0] <> $04) then
  begin
    AError := 'Invalid P-384 public key format (expected 04 || X || Y)';
    Exit;
  end;

  SetLength(LX, 48);
  SetLength(LY, 48);
  Move(APeerPublicKey[1], LX[0], 48);
  Move(APeerPublicKey[49], LY[0], 48);
  LP := P384ModP;
  LB := HexToBytes(P384_B_HEX);

  if IsZeroBytes(LX) and IsZeroBytes(LY) then
  begin
    AError := 'P-384 public key is point at infinity';
    Exit;
  end;

  // y^2 mod p
  if not TryBigIntModMulFromUnsignedBytes(LY, LY, LP, LY2, LErr) then
  begin
    AError := 'P-384 validation failed: ' + LErr;
    Exit;
  end;

  // x^2 mod p
  if not TryBigIntModMulFromUnsignedBytes(LX, LX, LP, LX2, LErr) then Exit;
  // x^3 mod p
  if not TryBigIntModMulFromUnsignedBytes(LX2, LX, LP, LX3, LErr) then Exit;

  // 3x mod p
  LOne := HexToBytes('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003');
  if not TryBigIntModMulFromUnsignedBytes(LX, LOne, LP, LThreeX, LErr) then Exit;

  // rhs = x^3 - 3x mod p
  if not TryBigIntSubtractModuloFromUnsignedBytes(LX3, LThreeX, LP, LRhs, LErr) then Exit;
  // rhs = (rhs + b) mod p; use LTemp to avoid aliasing the output parameter.
  if not TryBigIntAddFromUnsignedBytes(LRhs, LB, LTemp, LErr) then Exit;
  if not TryBigIntModFromUnsignedBytes(LTemp, LP, LRhs, LErr) then Exit;

  // Normalize both to 48 bytes (use separate vars to avoid aliasing)
  if not TryBigIntToFixedLengthFromUnsignedBytes(LY2, 48, LTemp, LErr) then Exit;
  LY2 := LTemp;
  if not TryBigIntToFixedLengthFromUnsignedBytes(LRhs, 48, LTemp, LErr) then Exit;
  LRhs := LTemp;

  if not CompareMem(@LY2[0], @LRhs[0], 48) then
  begin
    AError := 'P-384 public key not on curve';
    Exit;
  end;

  Result := True;
end;

function TryP384ECDHE(const APrivateKey: TBytes; const APeerPublicKey: TBytes;
  out ASharedSecret: TBytes; out AError: string): Boolean;
var
  LPeer, LShared: TP384Point;
begin
  Result := False;

  if not TryP384ValidatePublicKey(APeerPublicKey, AError) then
    Exit;

  SetLength(LPeer.X, 48);
  SetLength(LPeer.Y, 48);
  Move(APeerPublicKey[1], LPeer.X[0], 48);
  Move(APeerPublicKey[49], LPeer.Y[0], 48);

  if not TryP384ScalarMult(APrivateKey, LPeer, LShared, AError) then Exit;
  if not TryFixedLength48(LShared.X, ASharedSecret, AError) then Exit;
  Result := True;
end;

function TryP384ECDSAVerify(const AHash: TBytes; const ASignature: TBytes;
  const APublicKey: TP384Point; out AError: string): Boolean;
var
  LN, LR, LS, LW, LU1, LU2: TBytes;
  LP1, LP2, LSum: TP384Point;
  LRCheck, LFixed: TBytes;
begin
  Result := False;
  AError := '';
  LN := P384Order;

  if Length(AHash) <> 48 then
  begin
    AError := 'P-384 ECDSA verifier requires SHA-384 hash input (48 bytes)';
    Exit;
  end;

  if Length(ASignature) < 4 then
  begin
    AError := 'Signature too short';
    Exit;
  end;

  if Length(ASignature) = 96 then
  begin
    LR := Copy(ASignature, 0, 48);
    LS := Copy(ASignature, 48, 48);
  end
  else
  begin
    AError := 'P-384 ECDSA signature must be 96 bytes (raw r||s); use TryP384ECDSAVerifyDER for DER input';
    Exit;
  end;

  if IsZeroBytes(LR) or IsZeroBytes(LS) then
  begin
    AError := 'P-384 ECDSA r/s must be non-zero';
    Exit;
  end;

  if (CompareUnsignedBytes(LR, LN) >= 0) or (CompareUnsignedBytes(LS, LN) >= 0) then
  begin
    AError := 'P-384 ECDSA r/s must be less than curve order';
    Exit;
  end;

  // w = s^-1 mod n
  if not TryBigIntModExpFromUnsignedBytes(LS,
    HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC7634D81F4372DDF581A0DB248B0A77AECEC196ACCC52971'),
    LN, LW, AError) then Exit;

  // u1 = hash * w mod n
  if not TryBigIntModMulFromUnsignedBytes(AHash, LW, LN, LU1, AError) then Exit;
  // u2 = r * w mod n
  if not TryBigIntModMulFromUnsignedBytes(LR, LW, LN, LU2, AError) then Exit;

  // P1 = u1*G, P2 = u2*Q
  if not TryP384ScalarMultBase(LU1, LP1, AError) then Exit;
  if not TryP384ScalarMult(LU2, APublicKey, LP2, AError) then Exit;
  if not TryP384PointAdd(LP1, LP2, LSum, AError) then Exit;
  if P384PointIsInfinity(LSum) then
  begin
    AError := 'ECDSA verification point is infinity';
    Exit;
  end;

  // Check: Sum.X mod n == r
  if not TryBigIntModFromUnsignedBytes(LSum.X, LN, LRCheck, AError) then Exit;
  if not TryFixedLength48(LRCheck, LFixed, AError) then Exit;
  Result := CompareMem(@LFixed[0], @LR[0], 48);
  if not Result then
    AError := 'ECDSA signature verification failed';
end;

function TryParseP384ECDSASignatureDER(const ASignatureDER: TBytes;
  out ARawSignature: TBytes; out AError: string): Boolean;
var
  LReader: TASN1Reader;
  LRoot: TASN1Node;
  LR, LS, LFixedR, LFixedS: TBytes;
begin
  SetLength(ARawSignature, 0);
  AError := '';
  Result := False;
  LRoot := nil;

  if Length(ASignatureDER) = 0 then
  begin
    AError := 'P-384 ECDSA DER signature is empty';
    Exit;
  end;

  LReader := TASN1Reader.Create(ASignatureDER);
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'P-384 ECDSA DER parse failed: ' + E.Message;
        Exit;
      end;
    end;

    try
      if (LRoot = nil) or (not LRoot.IsSequence) or (LRoot.ChildCount <> 2) then
      begin
        AError := 'P-384 ECDSA DER signature must be a SEQUENCE of two INTEGERs';
        Exit;
      end;

      if LReader.Position <> LReader.DataLength then
      begin
        AError := 'P-384 ECDSA DER signature has trailing data';
        Exit;
      end;

      if (not LRoot.GetChild(0).IsInteger) or (not LRoot.GetChild(1).IsInteger) then
      begin
        AError := 'P-384 ECDSA DER signature fields must be INTEGERs';
        Exit;
      end;

      LR := LRoot.GetChild(0).AsBigInteger;
      LS := LRoot.GetChild(1).AsBigInteger;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;

  if (Length(LR) = 0) or (Length(LS) = 0) then
  begin
    AError := 'P-384 ECDSA DER r/s must not be empty';
    Exit;
  end;

  if ((LR[0] and $80) <> 0) or ((LS[0] and $80) <> 0) then
  begin
    AError := 'P-384 ECDSA DER r/s must be positive INTEGERs';
    Exit;
  end;

  LR := StripLeadingZeroBytes(LR);
  LS := StripLeadingZeroBytes(LS);

  if IsZeroBytes(LR) or IsZeroBytes(LS) then
  begin
    AError := 'P-384 ECDSA DER r/s must be non-zero';
    Exit;
  end;

  if (CompareUnsignedBytes(LR, P384Order) >= 0) or (CompareUnsignedBytes(LS, P384Order) >= 0) then
  begin
    AError := 'P-384 ECDSA DER r/s must be less than curve order';
    Exit;
  end;

  SetLength(ARawSignature, 96);
  if not TryFixedLength48(LR, LFixedR, AError) then Exit;
  if not TryFixedLength48(LS, LFixedS, AError) then Exit;
  Move(LFixedR[0], ARawSignature[0], 48);
  Move(LFixedS[0], ARawSignature[48], 48);
  Result := True;
end;

function TryP384ECDSAVerifyDER(const AHash: TBytes; const ASignatureDER: TBytes;
  const APublicKey: TP384Point; out AError: string): Boolean;
var
  LRawSignature: TBytes;
begin
  Result := False;
  if not TryParseP384ECDSASignatureDER(ASignatureDER, LRawSignature, AError) then
    Exit;
  Result := TryP384ECDSAVerify(AHash, LRawSignature, APublicKey, AError);
end;

end.
