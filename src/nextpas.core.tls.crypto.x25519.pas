{**
 * Unit: nextpas.core.tls.crypto.x25519
 * Purpose: 纯 Pascal X25519（Curve25519 Montgomery ladder）
 *
 * 说明：
 * - 不依赖外部库
 * - 采用 16x16-bit limb 表示域元素
 * - 用于 TLS 1.3 key_share / ECDHE 共享密钥计算
 *}

unit nextpas.core.tls.crypto.x25519;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils,
  nextpas.core.tls.errors;

const
  X25519_KEY_SIZE = 32;

function ClampX25519Scalar(const AScalar: TBytes): TBytes;
function GenerateX25519PrivateKey: TBytes;
procedure GenerateX25519KeyPair(out APrivateKey, APublicKey: TBytes);

function X25519ScalarMult(const AScalar, AInputU: TBytes): TBytes;
function X25519PublicKeyFromPrivate(const APrivateKey: TBytes): TBytes;
function X25519ComputeSharedSecret(const APrivateKey, APeerPublicKey: TBytes): TBytes;

implementation

uses
  nextpas.core.tls.random;

type
  TFieldElement = array[0..15] of Int64;

procedure EnsureKeyLength(const AValue: TBytes; const AParamName: string);
begin
  if Length(AValue) <> X25519_KEY_SIZE then
    RaiseInvalidParameter(AParamName);
end;

function IsAllZero(const AData: TBytes): Boolean;
var
  I: Integer;
  LOr: Byte;
begin
  LOr := 0;
  for I := 0 to High(AData) do
    LOr := LOr or AData[I];
  Result := LOr = 0;
end;

procedure FEClear(var AValue: TFieldElement);
begin
  FillChar(AValue, SizeOf(AValue), 0);
end;

procedure FEOne(var AValue: TFieldElement);
begin
  FEClear(AValue);
  AValue[0] := 1;
end;

procedure FECopy(var ADest: TFieldElement; const ASrc: TFieldElement);
var
  I: Integer;
begin
  for I := 0 to 15 do
    ADest[I] := ASrc[I];
end;

procedure FEAdd(var AOut: TFieldElement; const ALeft, ARight: TFieldElement);
var
  I: Integer;
begin
  for I := 0 to 15 do
    AOut[I] := ALeft[I] + ARight[I];
end;

procedure FESub(var AOut: TFieldElement; const ALeft, ARight: TFieldElement);
var
  I: Integer;
begin
  for I := 0 to 15 do
    AOut[I] := ALeft[I] - ARight[I];
end;

procedure FECarry(var AValue: TFieldElement);
var
  I: Integer;
  LV, LC: Int64;
begin
  LC := 1;
  for I := 0 to 15 do
  begin
    LV := AValue[I] + LC + 65535;
    LC := LV div 65536;
    AValue[I] := LV - LC * 65536;
  end;

  AValue[0] := AValue[0] + (LC - 1) + 37 * (LC - 1);
end;

procedure FESel(var AP, AQ: TFieldElement; ABit: Integer);
var
  I: Integer;
  LMask: Int64;
  LTemp: Int64;
begin
  LMask := -Int64(ABit and 1);
  for I := 0 to 15 do
  begin
    LTemp := LMask and (AP[I] xor AQ[I]);
    AP[I] := AP[I] xor LTemp;
    AQ[I] := AQ[I] xor LTemp;
  end;
end;

procedure FEMul(var AOut: TFieldElement; const ALeft, ARight: TFieldElement);
var
  LT: array[0..30] of Int64;
  I, J: Integer;
begin
  FillChar(LT, SizeOf(LT), 0);

  for I := 0 to 15 do
    for J := 0 to 15 do
      LT[I + J] := LT[I + J] + ALeft[I] * ARight[J];

  for I := 0 to 14 do
    LT[I] := LT[I] + 38 * LT[I + 16];

  for I := 0 to 15 do
    AOut[I] := LT[I];

  FECarry(AOut);
  FECarry(AOut);
end;

procedure FESquare(var AOut: TFieldElement; const AValue: TFieldElement);
begin
  FEMul(AOut, AValue, AValue);
end;

procedure FEUnpack(var AOut: TFieldElement; const AInput: TBytes);
var
  I: Integer;
begin
  EnsureKeyLength(AInput, 'X25519InputU');

  for I := 0 to 15 do
    AOut[I] := Int64(AInput[2 * I]) + (Int64(AInput[2 * I + 1]) shl 8);

  AOut[15] := AOut[15] and $7FFF;
end;

procedure FEPack(out AOut: TBytes; const AInput: TFieldElement);
var
  LT, LM: TFieldElement;
  I, J: Integer;
  LB: Int64;
begin
  AOut := nil;
  SetLength(AOut, X25519_KEY_SIZE);

  FECopy(LT, AInput);
  FECarry(LT);
  FECarry(LT);
  FECarry(LT);

  for J := 0 to 1 do
  begin
    LM[0] := LT[0] - $FFED;

    for I := 1 to 14 do
    begin
      LM[I] := LT[I] - $FFFF - ((LM[I - 1] shr 16) and 1);
      LM[I - 1] := LM[I - 1] and $FFFF;
    end;

    LM[15] := LT[15] - $7FFF - ((LM[14] shr 16) and 1);
    LB := (LM[15] shr 16) and 1;
    LM[14] := LM[14] and $FFFF;

    FESel(LT, LM, 1 - Integer(LB));
  end;

  for I := 0 to 15 do
  begin
    AOut[2 * I] := Byte(LT[I] and $FF);
    AOut[2 * I + 1] := Byte((LT[I] shr 8) and $FF);
  end;
end;

procedure FEInvert(var AOut: TFieldElement; const AInput: TFieldElement);
var
  LTemp: TFieldElement;
  I: Integer;
begin
  FECopy(LTemp, AInput);

  for I := 253 downto 0 do
  begin
    FESquare(LTemp, LTemp);
    if (I <> 2) and (I <> 4) then
      FEMul(LTemp, LTemp, AInput);
  end;

  FECopy(AOut, LTemp);
end;

procedure FEConstA24(var AOut: TFieldElement);
begin
  FEClear(AOut);
  AOut[0] := 121665;
end;

function ClampX25519Scalar(const AScalar: TBytes): TBytes;
begin
  EnsureKeyLength(AScalar, 'X25519Scalar');

  Result := nil;
  SetLength(Result, X25519_KEY_SIZE);
  Move(AScalar[0], Result[0], X25519_KEY_SIZE);

  Result[0] := Result[0] and $F8;
  Result[31] := (Result[31] and $7F) or $40;
end;

function GenerateX25519PrivateKey: TBytes;
begin
  Result := GenerateSecureRandomBytes(X25519_KEY_SIZE);
  EnsureKeyLength(Result, 'X25519PrivateKey');
  Result := ClampX25519Scalar(Result);
end;

procedure GenerateX25519KeyPair(out APrivateKey, APublicKey: TBytes);
begin
  APrivateKey := GenerateX25519PrivateKey;
  APublicKey := X25519PublicKeyFromPrivate(APrivateKey);
end;

function X25519ScalarMult(const AScalar, AInputU: TBytes): TBytes;
var
  LClampedScalar: TBytes;
  LX1, LX2, LZ2, LX3, LZ3: TFieldElement;
  LA, LB, LC, LD: TFieldElement;
  LAA, LBB, LE: TFieldElement;
  LDA, LCB: TFieldElement;
  LT0, LT1: TFieldElement;
  LA24: TFieldElement;
  LSwap, LBit: Integer;
  I: Integer;
begin
  EnsureKeyLength(AScalar, 'X25519Scalar');
  EnsureKeyLength(AInputU, 'X25519InputU');

  LClampedScalar := ClampX25519Scalar(AScalar);

  FEUnpack(LX1, AInputU);
  FEOne(LX2);
  FEClear(LZ2);
  FECopy(LX3, LX1);
  FEOne(LZ3);
  FEConstA24(LA24);
  LSwap := 0;

  for I := 254 downto 0 do
  begin
    LBit := (LClampedScalar[I shr 3] shr (I and 7)) and 1;
    LSwap := LSwap xor LBit;

    FESel(LX2, LX3, LSwap);
    FESel(LZ2, LZ3, LSwap);
    LSwap := LBit;

    FEAdd(LA, LX2, LZ2);
    FESub(LB, LX2, LZ2);
    FESquare(LAA, LA);
    FESquare(LBB, LB);
    FESub(LE, LAA, LBB);

    FEAdd(LC, LX3, LZ3);
    FESub(LD, LX3, LZ3);
    FEMul(LDA, LD, LA);
    FEMul(LCB, LC, LB);

    FEAdd(LT0, LDA, LCB);
    FESquare(LX3, LT0);

    FESub(LT1, LDA, LCB);
    FESquare(LT1, LT1);
    FEMul(LZ3, LX1, LT1);

    FEMul(LX2, LAA, LBB);
    FEMul(LT0, LE, LA24);
    FEAdd(LT0, LAA, LT0);
    FEMul(LZ2, LE, LT0);
  end;

  FESel(LX2, LX3, LSwap);
  FESel(LZ2, LZ3, LSwap);

  FEInvert(LZ2, LZ2);
  FEMul(LX2, LX2, LZ2);
  FEPack(Result, LX2);
end;

function X25519PublicKeyFromPrivate(const APrivateKey: TBytes): TBytes;
var
  LBasePoint: TBytes;
begin
  EnsureKeyLength(APrivateKey, 'X25519PrivateKey');

  LBasePoint := nil;
  SetLength(LBasePoint, X25519_KEY_SIZE);
  FillChar(LBasePoint[0], X25519_KEY_SIZE, 0);
  LBasePoint[0] := 9;

  Result := X25519ScalarMult(APrivateKey, LBasePoint);
end;

function X25519ComputeSharedSecret(const APrivateKey, APeerPublicKey: TBytes): TBytes;
begin
  EnsureKeyLength(APrivateKey, 'X25519PrivateKey');
  EnsureKeyLength(APeerPublicKey, 'X25519PeerPublicKey');

  Result := X25519ScalarMult(APrivateKey, APeerPublicKey);
  if IsAllZero(Result) then
    RaiseKeyDerivationError('X25519 shared secret is all-zero');
end;

end.
