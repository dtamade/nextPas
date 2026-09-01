unit nextpas.core.crypto.p384;
{ WARNING: This module is EXPERIMENTAL. Not all APIs are fully implemented. }

{$mode objfpc}{$H+}{$J-}
{$WARN 5093 off}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv;

type
  TP384Point = record
    X: TBytes;
    Y: TBytes;
  end;

type TJac384 = record X, Y, Z: TBytes; end;
function JacIsInfinity384(const P: TJac384): Boolean;
function JacFromAffine384(const AP: TP384Point; out JP: TJac384; out AError: string): Boolean;
function TryJacDouble384(const P: TJac384; out R: TJac384; out AError: string): Boolean;
function TryJacToAffine384(const P: TJac384; out AP: TP384Point; out AError: string): Boolean;
function TryP384ScalarMultBase(const AScalar: TBytes; out AResult: TP384Point;
  out AError: string): Boolean;
function TryP384ScalarMult(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
function TryP384ScalarMultAffine(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
function TryP384ScalarMultJacobian(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
function TryP384ScalarMultWindowed(const AScalar: TBytes; const APoint: TP384Point;
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
  nextpas.core.errors,
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.encoding.hex,
  nextpas.core.crypto.asn1,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.random;

const
  P384_P_HEX = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFF';
  P384_N_HEX = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC7634D81F4372DDF581A0DB248B0A77AECEC196ACCC52973';
  P384_B_HEX = 'B3312FA7E23EE7E4988E056BE3F82D19181D9C6EFE8141120314088F5013875AC656398D8A2ED19D2A85C8EDD3EC2AEF';

  P384_GX_HEX = 'AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7';
  P384_GY_HEX = '3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F';

var
  GP384_P: TBytes;
  GP384_N: TBytes;
  GP384_B: TBytes;
  GP384_GX: TBytes;
  GP384_GY: TBytes;
  GP384_P_MINUS2: TBytes;
  GP384_N_MINUS2: TBytes;
  GP384BaseTable: array[0..15] of TJac384;
  GP384BaseTableReady: Boolean;

function HexToBytes(const AHex: string): TBytes; inline;
begin
  { perf: inline thin-forward to encoding.hex single source (single SetLength+Move zero-copy, table lookup single pass); owner HexDecode not inline per red-line 2; reuse bytes.ops single-source Move semantics }
  Result := nextpas.core.encoding.hex.HexDecode(AHex);
end;

function P384ModP: TBytes;
begin
  if Length(GP384_P) = 0 then GP384_P := HexToBytes(P384_P_HEX);
  Result := GP384_P;
end;

function P384Order: TBytes;
begin
  if Length(GP384_N) = 0 then GP384_N := HexToBytes(P384_N_HEX);
  Result := GP384_N;
end;

function P384Generator: TP384Point;
begin
  if Length(GP384_GX) = 0 then GP384_GX := HexToBytes(P384_GX_HEX);
  if Length(GP384_GY) = 0 then GP384_GY := HexToBytes(P384_GY_HEX);
  Result.X := GP384_GX;
  Result.Y := GP384_GY;
end;

function P384PMinus2: TBytes;
begin
  if Length(GP384_P_MINUS2) = 0 then GP384_P_MINUS2 := HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFD');
  Result := GP384_P_MINUS2;
end;

function P384NMinus2: TBytes;
begin
  if Length(GP384_N_MINUS2) = 0 then GP384_N_MINUS2 := HexToBytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC7634D81F4372DDF581A0DB248B0A77AECEC196ACCC52971');
  Result := GP384_N_MINUS2;
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

function TryFixedLength48(const AValue: TBytes; out AResult: TBytes; out AError: string): Boolean;
begin
  Result := TryBigIntToFixedLengthFromUnsignedBytes(nextpas.core.bytes.ops.StripLeadingZero(AValue), 48, AResult, AError);
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

  if nextpas.core.bytes.ops.UnsignedEqual(AP.X, AQ.X) then
  begin
    if nextpas.core.bytes.ops.UnsignedEqual(AP.Y, AQ.Y) then
      Exit(TryP384PointDouble(AP, AResult, AError));

    if not TryBigIntAddFromUnsignedBytes(AP.Y, AQ.Y, LSumY, AError) then Exit;
    if not TryBigIntModFromUnsignedBytes(LSumY, LP, LTmp, AError) then Exit;
    if nextpas.core.bytes.ops.IsZeroBytes(LTmp) then
    begin
      AResult := P384InfinityPoint;
      Exit(True);
    end;

    AError := 'Invalid P-384 point addition input';
    Exit;
  end;

  if not TryBigIntSubtractModuloFromUnsignedBytes(AQ.X, AP.X, LP, LDen, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(AQ.Y, AP.Y, LP, LNum, AError) then Exit;
  if not TryBigIntModExpFromUnsignedBytes(LDen, P384PMinus2,
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

  if nextpas.core.bytes.ops.IsZeroBytes(AP.Y) then
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
  if not TryBigIntModExpFromUnsignedBytes(LDen, P384PMinus2,
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

{ Jacobian 384 — single inversion per scalar mult (S40) }
function JacIsInfinity384(const P: TJac384): Boolean;
begin Result := nextpas.core.bytes.ops.IsZeroBytes(P.Z); end;

function JacFromAffine384(const AP: TP384Point; out JP: TJac384; out AError: string): Boolean;
var One: TBytes;
begin
  Result := False;
  if P384PointIsInfinity(AP) then begin SetLength(JP.X,0); SetLength(JP.Y,0); SetLength(JP.Z,0); Exit(True); end;
  One := HexToBytes('01');
  JP.X := AP.X; JP.Y := AP.Y;
  if not TryFixedLength48(One, JP.Z, AError) then Exit;
  if Length(JP.Z)=1 then begin SetLength(JP.Z,48); FillChar(JP.Z[0],48,0); JP.Z[47]:=1; end;
  Result := True;
end;

function TryJacDouble384(const P: TJac384; out R: TJac384; out AError: string): Boolean;
var LP, Y2, Y4, Z2, Z4, X2, S, M, M2, X3, Y3, Z3, Tmp, Tmp2, Three, Four, Eight, Two: TBytes;
begin
  Result := False; R := Default(TJac384); AError := '';
  if JacIsInfinity384(P) then begin R := P; Exit(True); end;
  if nextpas.core.bytes.ops.IsZeroBytes(P.Y) then begin SetLength(R.X,0); SetLength(R.Y,0); SetLength(R.Z,0); Exit(True); end;
  LP := P384ModP;
  Three := HexToBytes('03'); Four := HexToBytes('04'); Eight := HexToBytes('08'); Two := HexToBytes('02');
  if not TryBigIntModMulFromUnsignedBytes(P.Y, P.Y, LP, Y2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Y2, Y2, LP, Y4, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(P.Z, P.Z, LP, Z2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Z2, Z2, LP, Z4, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(P.X, P.X, LP, X2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(P.X, Y2, LP, S, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(S, Four, LP, Tmp, AError) then Exit;
  S := Tmp;
  if not TryBigIntSubtractModuloFromUnsignedBytes(X2, Z4, LP, Tmp, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Tmp, Three, LP, M, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(M, M, LP, M2, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(M2, S, LP, Tmp, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(Tmp, S, LP, X3, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(S, X3, LP, Tmp, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(M, Tmp, LP, Tmp2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Y4, Eight, LP, Y3, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(Tmp2, Y3, LP, Tmp, AError) then Exit;
  Y3 := Tmp;
  if not TryBigIntModMulFromUnsignedBytes(P.Y, P.Z, LP, Z3, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Z3, Two, LP, Tmp, AError) then Exit;
  Z3 := Tmp;
  R.X := X3; R.Y := Y3; R.Z := Z3; Result := True;
end;

function TryJacAdd384(const P, Q: TJac384; out R: TJac384; out AError: string): Boolean;
var LP, Z1_2, Z2_2, Z1_3, Z2_3, U1, U2, S1, S2, H, Rr, H2, H3, U1H2, X3, Y3, Z3, Tmp, Tmp2: TBytes;
begin
  Result := False; R := Default(TJac384); AError := '';
  if JacIsInfinity384(P) then begin R := Q; Exit(True); end;
  if JacIsInfinity384(Q) then begin R := P; Exit(True); end;
  LP := P384ModP;
  if not TryBigIntModMulFromUnsignedBytes(Q.Z, Q.Z, LP, Z2_2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(P.Z, P.Z, LP, Z1_2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Z2_2, Q.Z, LP, Z2_3, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Z1_2, P.Z, LP, Z1_3, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(P.X, Z2_2, LP, U1, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Q.X, Z1_2, LP, U2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(P.Y, Z2_3, LP, S1, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Q.Y, Z1_3, LP, S2, AError) then Exit;
  if nextpas.core.bytes.ops.UnsignedEqual(U1, U2) then begin if nextpas.core.bytes.ops.UnsignedEqual(S1, S2) then Exit(TryJacDouble384(P, R, AError)) else begin SetLength(R.X,0); SetLength(R.Y,0); SetLength(R.Z,0); Exit(True); end; end;
  if not TryBigIntSubtractModuloFromUnsignedBytes(U2, U1, LP, H, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(S2, S1, LP, Rr, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(H, H, LP, H2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(H, H2, LP, H3, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(U1, H2, LP, U1H2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Rr, Rr, LP, X3, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(X3, H3, LP, Tmp, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(Tmp, U1H2, LP, Tmp2, AError) then Exit;
  Tmp := Tmp2;
  if not TryBigIntSubtractModuloFromUnsignedBytes(Tmp, U1H2, LP, X3, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(U1H2, X3, LP, Tmp, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Rr, Tmp, LP, Tmp2, AError) then Exit;
  Tmp := Tmp2;
  if not TryBigIntModMulFromUnsignedBytes(S1, H3, LP, Y3, AError) then Exit;
  if not TryBigIntSubtractModuloFromUnsignedBytes(Tmp, Y3, LP, Tmp2, AError) then Exit;
  Y3 := Tmp2;
  if not TryBigIntModMulFromUnsignedBytes(H, P.Z, LP, Tmp, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Tmp, Q.Z, LP, Z3, AError) then Exit;
  R.X := X3; R.Y := Y3; R.Z := Z3; Result := True;
end;

function TryJacToAffine384(const P: TJac384; out AP: TP384Point; out AError: string): Boolean;
var LP, Zinv, Zinv2, Zinv3, X, Y: TBytes;
begin
  Result := False; AP := P384InfinityPoint; AError := '';
  if JacIsInfinity384(P) then Exit(True);
  LP := P384ModP;
  if not TryBigIntModExpFromUnsignedBytes(P.Z, P384PMinus2, LP, Zinv, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Zinv, Zinv, LP, Zinv2, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(Zinv2, Zinv, LP, Zinv3, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(P.X, Zinv2, LP, X, AError) then Exit;
  if not TryBigIntModMulFromUnsignedBytes(P.Y, Zinv3, LP, Y, AError) then Exit;
  AP.X := X; AP.Y := Y; Result := True;
end;

function TryP384ScalarMultBase(const AScalar: TBytes; out AResult: TP384Point;
  out AError: string): Boolean;
begin
  Result := TryP384ScalarMult(AScalar, P384Generator, AResult, AError);
end;

function TryP384ScalarMultAffine(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
var LScalar48: TBytes; LR0, LR1: TP384Point; LAddResult, LDblResult: TP384Point;
  LByteIndex, LBitIndex, LBit, LSwap, LPrevSwap: Integer;
  procedure CTSwapP384(var A, B: TP384Point; AFlag: Integer);
  var LMask: Byte; I: Integer; LTmp: Byte; LA48, LB48: TBytes; LErr: string;
  begin LMask:=Byte(-AFlag and $FF);
    if not TryFixedLength48(A.X, LA48, LErr) then SetLength(LA48,48);
    if not TryFixedLength48(B.X, LB48, LErr) then SetLength(LB48,48);
    for I:=0 to 47 do begin LTmp:=LMask and (LA48[I] xor LB48[I]); LA48[I]:=LA48[I] xor LTmp; LB48[I]:=LB48[I] xor LTmp; end;
    A.X:=LA48; B.X:=LB48;
    if not TryFixedLength48(A.Y, LA48, LErr) then SetLength(LA48,48);
    if not TryFixedLength48(B.Y, LB48, LErr) then SetLength(LB48,48);
    for I:=0 to 47 do begin LTmp:=LMask and (LA48[I] xor LB48[I]); LA48[I]:=LA48[I] xor LTmp; LB48[I]:=LB48[I] xor LTmp; end;
    A.Y:=LA48; B.Y:=LB48;
  end;
begin Result:=False; AResult:=P384InfinityPoint; AError:='';
  if not TryFixedLength48(AScalar, LScalar48, AError) then Exit;
  LR0:=P384InfinityPoint; LR1:=APoint; LPrevSwap:=0;
  for LByteIndex:=0 to 47 do for LBitIndex:=7 downto 0 do begin
    LBit:=(LScalar48[LByteIndex] shr LBitIndex) and 1; LSwap:=LBit xor LPrevSwap;
    CTSwapP384(LR0,LR1,LSwap); LPrevSwap:=LBit;
    if not TryP384PointAdd(LR0,LR1,LAddResult,AError) then Exit;
    if not TryP384PointDouble(LR0,LDblResult,AError) then Exit;
    LR1:=LAddResult; LR0:=LDblResult;
  end; CTSwapP384(LR0,LR1,LPrevSwap);
  if P384PointIsInfinity(LR0) then begin AError:='Scalar is zero'; Exit; end;
  AResult:=LR0; Result:=True;
end;

procedure CTSwapJac384(var A, B: TJac384; AFlag: Integer);
var LMask: Byte; I: Integer; LTmp: Byte; LA48, LB48: TBytes; LErr: string;
  procedure SwapBytes(var Av,Bv:TBytes);
  var i2: Integer;
  begin
    if not TryFixedLength48(Av, LA48, LErr) then SetLength(LA48,48);
    if not TryFixedLength48(Bv, LB48, LErr) then SetLength(LB48,48);
    for i2:=0 to 47 do begin LTmp:=LMask and (LA48[i2] xor LB48[i2]); LA48[i2]:=LA48[i2] xor LTmp; LB48[i2]:=LB48[i2] xor LTmp; end;
    Av:=LA48; Bv:=LB48;
  end;
begin LMask:=Byte(-AFlag and $FF); SwapBytes(A.X,B.X); SwapBytes(A.Y,B.Y); SwapBytes(A.Z,B.Z); end;

function TryP384ScalarMultJacobian(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
var LScalar48: TBytes; JR0,JR1,JAdd,JDbl: TJac384; LByteIndex,LBitIndex,LBit,LSwap,LPrevSwap: Integer;
begin Result:=False; AResult:=P384InfinityPoint; AError:='';
  if not TryFixedLength48(AScalar, LScalar48, AError) then Exit;
  if P384PointIsInfinity(APoint) then begin AError:='Scalar is zero'; Exit; end;
  SetLength(JR0.X,48); FillChar(JR0.X[0],48,0);
  SetLength(JR0.Y,48); FillChar(JR0.Y[0],48,0);
  SetLength(JR0.Z,48); FillChar(JR0.Z[0],48,0);
  if not JacFromAffine384(APoint, JR1, AError) then Exit;
  if Length(JR1.Z)=0 then begin SetLength(JR1.Z,48); FillChar(JR1.Z[0],48,0); JR1.Z[47]:=1; end;
  if Length(JR1.X)<48 then if not TryFixedLength48(JR1.X, JR1.X, AError) then Exit;
  if Length(JR1.Y)<48 then if not TryFixedLength48(JR1.Y, JR1.Y, AError) then Exit;
  if Length(JR1.Z)<48 then if not TryFixedLength48(JR1.Z, JR1.Z, AError) then Exit;
  LPrevSwap:=0;
  for LByteIndex:=0 to 47 do for LBitIndex:=7 downto 0 do begin
    LBit:=(LScalar48[LByteIndex] shr LBitIndex) and 1; LSwap:=LBit xor LPrevSwap;
    CTSwapJac384(JR0,JR1,LSwap); LPrevSwap:=LBit;
    if not TryJacAdd384(JR0,JR1,JAdd,AError) then Exit;
    if not TryJacDouble384(JR0,JDbl,AError) then Exit;
    JR1:=JAdd; JR0:=JDbl;
  end; CTSwapJac384(JR0,JR1,LPrevSwap);
  if JacIsInfinity384(JR0) then begin AError:='Scalar is zero'; Exit; end;
  if not TryJacToAffine384(JR0, AResult, AError) then Exit;
  Result:=True;
end;

function IsP384BasePoint(const AP: TP384Point): Boolean;
var LG: TP384Point;
begin
  LG := P384Generator;
  Result := nextpas.core.bytes.ops.UnsignedEqual(AP.X, LG.X) and nextpas.core.bytes.ops.UnsignedEqual(AP.Y, LG.Y);
end;

function EnsureP384BaseTable(out AError: string): Boolean;
var I: Integer; JP: TJac384;
begin
  Result := False; AError := '';
  if GP384BaseTableReady then Exit(True);
  if not JacFromAffine384(P384Generator, JP, AError) then Exit;
  if Length(JP.Z)=0 then begin SetLength(JP.Z,48); FillChar(JP.Z[0],48,0); JP.Z[47]:=1; end;
  if Length(JP.X)<48 then if not TryFixedLength48(JP.X, JP.X, AError) then Exit;
  if Length(JP.Y)<48 then if not TryFixedLength48(JP.Y, JP.Y, AError) then Exit;
  if Length(JP.Z)<48 then if not TryFixedLength48(JP.Z, JP.Z, AError) then Exit;
  SetLength(GP384BaseTable[0].X,48); FillChar(GP384BaseTable[0].X[0],48,0);
  SetLength(GP384BaseTable[0].Y,48); FillChar(GP384BaseTable[0].Y[0],48,0);
  SetLength(GP384BaseTable[0].Z,48); FillChar(GP384BaseTable[0].Z[0],48,0);
  GP384BaseTable[1] := JP;
  for I:=2 to 15 do if not TryJacAdd384(GP384BaseTable[I-1], JP, GP384BaseTable[I], AError) then Exit;
  GP384BaseTableReady := True;
  Result := True;
end;

function TryP384ScalarMultWindowed(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
var LScalar48: TBytes; JP: TJac384; Table: array[0..15] of TJac384; JR, JDbl, JAdd: TJac384; LByteIndex, LHalf, W, K: Integer; LFirst: Boolean;
begin Result:=False; AResult:=P384InfinityPoint; AError:='';
  if not TryFixedLength48(AScalar, LScalar48, AError) then Exit;
  if P384PointIsInfinity(APoint) then begin AError:='Scalar is zero'; Exit; end;
  if not JacFromAffine384(APoint, JP, AError) then Exit;
  if Length(JP.Z)=0 then begin SetLength(JP.Z,48); FillChar(JP.Z[0],48,0); JP.Z[47]:=1; end;
  if Length(JP.X)<48 then if not TryFixedLength48(JP.X, JP.X, AError) then Exit;
  if Length(JP.Y)<48 then if not TryFixedLength48(JP.Y, JP.Y, AError) then Exit;
  if Length(JP.Z)<48 then if not TryFixedLength48(JP.Z, JP.Z, AError) then Exit;
  if IsP384BasePoint(APoint) then begin
    if not EnsureP384BaseTable(AError) then Exit;
    Table := GP384BaseTable;
  end else begin
    // Table[0]=inf
    SetLength(Table[0].X,48); FillChar(Table[0].X[0],48,0);
    SetLength(Table[0].Y,48); FillChar(Table[0].Y[0],48,0);
    SetLength(Table[0].Z,48); FillChar(Table[0].Z[0],48,0);
    Table[1]:=JP;
    for K:=2 to 15 do if not TryJacAdd384(Table[K-1], JP, Table[K], AError) then Exit;
  end;
  SetLength(JR.X,48); FillChar(JR.X[0],48,0);
  SetLength(JR.Y,48); FillChar(JR.Y[0],48,0);
  SetLength(JR.Z,48); FillChar(JR.Z[0],48,0);
  LFirst:=True;
  for LByteIndex:=0 to 47 do for LHalf:=0 to 1 do begin
    if LHalf=0 then W:=(LScalar48[LByteIndex] shr 4) and $F else W:=LScalar48[LByteIndex] and $F;
    if not LFirst then begin for K:=1 to 4 do begin if not TryJacDouble384(JR, JDbl, AError) then Exit; JR:=JDbl; end; end else LFirst:=False;
    if W<>0 then begin if not TryJacAdd384(JR, Table[W], JAdd, AError) then Exit; JR:=JAdd; end;
  end;
  if JacIsInfinity384(JR) then begin AError:='Scalar is zero'; Exit; end;
  if not TryJacToAffine384(JR, AResult, AError) then Exit;
  Result:=True;
end;

function TryP384ScalarMult(const AScalar: TBytes; const APoint: TP384Point;
  out AResult: TP384Point; out AError: string): Boolean;
begin Result:=TryP384ScalarMultWindowed(AScalar, APoint, AResult, AError); end;

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

  if nextpas.core.bytes.ops.IsZeroBytes(LX) and nextpas.core.bytes.ops.IsZeroBytes(LY) then
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

  if nextpas.core.bytes.ops.IsZeroBytes(LR) or nextpas.core.bytes.ops.IsZeroBytes(LS) then
  begin
    AError := 'P-384 ECDSA r/s must be non-zero';
    Exit;
  end;

  if (nextpas.core.bytes.ops.CompareUnsigned(LR, LN) >= 0) or (nextpas.core.bytes.ops.CompareUnsigned(LS, LN) >= 0) then
  begin
    AError := 'P-384 ECDSA r/s must be less than curve order';
    Exit;
  end;

  // w = s^-1 mod n
  if not TryBigIntModExpFromUnsignedBytes(LS,
    P384NMinus2,
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

  LR := nextpas.core.bytes.ops.StripLeadingZero(LR);
  LS := nextpas.core.bytes.ops.StripLeadingZero(LS);

  if nextpas.core.bytes.ops.IsZeroBytes(LR) or nextpas.core.bytes.ops.IsZeroBytes(LS) then
  begin
    AError := 'P-384 ECDSA DER r/s must be non-zero';
    Exit;
  end;

  if (nextpas.core.bytes.ops.CompareUnsigned(LR, P384Order) >= 0) or (nextpas.core.bytes.ops.CompareUnsigned(LS, P384Order) >= 0) then
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
