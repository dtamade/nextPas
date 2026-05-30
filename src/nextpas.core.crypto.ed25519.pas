unit nextpas.core.crypto.ed25519;

{$mode objfpc}{$H+}{$J-}
{$WARN 5093 off}

interface

uses
  SysUtils;

function Ed25519Verify(const APublicKey: TBytes; const AMessage: TBytes;
  const ASignature: TBytes): Boolean;

function Ed25519Sign(const APrivateKey: TBytes; const AMessage: TBytes;
  out ASignature: TBytes): Boolean;

function Ed25519PublicKeyFromPrivate(const APrivateKey: TBytes): TBytes;

function Ed25519TestScReduce(const AInput: TBytes): TBytes;
function Ed25519TestScMulAdd(const A, B, C: TBytes): TBytes;
function Ed25519TestFePow2523(const AInput: TBytes): TBytes;
function Ed25519TestFeSq(const AInput: TBytes): TBytes;
function Ed25519TestFeMul(const A, B: TBytes): TBytes;
function Ed25519TestPointDouble(const APoint: TBytes): TBytes;

implementation

uses
  nextpas.core.crypto.hash,
  nextpas.core.crypto.field25519;

type
  TEdPoint = record
    X, Y, Z, T: TFe25519;
  end;

const
  ED25519_D: TFe25519 = (
    -10913610, 13857413, -15372611, 6949391, 114729,
    -8787816, -6275908, -3247719, -18696448, -12055116
  );

  ED25519_D2: TFe25519 = (
    -21827239, -5839606, -30745221, 13898782, 229458,
     15978800, -12551817, -6495438, 29715968, 9444199
  );

  FE_SQRTM1: TFe25519 = (
    -32595792, -7943725, 9377950, 3500415, 12389472,
    -272473, -25146209, -2005654, 326686, 11406482
  );

function Sar(AValue: Int64; AShift: Integer): Int64; inline;
begin
  Result := SarInt64(AValue, AShift);
end;


function EdPointDecode(out P: TEdPoint; const S: TBytes; AOffset: Integer): Boolean;
var
  U, V, V3, VXX, Check: TFe25519;
  XSign: Integer;
  LY: TBytes;
begin
  Result := False;
  SetLength(LY, 32);
  Move(S[AOffset], LY[0], 32);
  XSign := (LY[31] shr 7) and 1;
  LY[31] := LY[31] and $7F;

  FeFromBytes(P.Y, LY, 0);

  FeSq(U, P.Y);
  FeMul(V, U, ED25519_D);
  FeSub(U, U, FE_ONE);
  FeAdd(V, V, FE_ONE);

  FeSq(V3, V);
  FeMul(V3, V3, V);
  FeSq(VXX, V3);
  FeMul(VXX, VXX, V);
  FeMul(VXX, VXX, U);
  FePow2523(VXX, VXX);
  FeMul(VXX, VXX, V3);
  FeMul(P.X, VXX, U);

  FeSq(Check, P.X);
  FeMul(Check, Check, V);
  FeSub(Check, Check, U);
  if not FeIsZero(Check) then
  begin
    FeAdd(Check, Check, U);
    FeAdd(Check, Check, U);
    if not FeIsZero(Check) then
      Exit;
    FeMul(P.X, P.X, FE_SQRTM1);
  end;

  if FeIsNegative(P.X) <> XSign then
    FeNeg(P.X, P.X);

  FeMul(P.T, P.X, P.Y);
  P.Z := FE_ONE;
  Result := True;
end;

procedure EdPointAdd(out R: TEdPoint; const P, Q: TEdPoint);
var
  A, B, C, D, E, F, G, HH: TFe25519;
begin
  FeSub(A, P.Y, P.X);
  FeSub(HH, Q.Y, Q.X);
  FeMul(A, A, HH);
  FeAdd(B, P.Y, P.X);
  FeAdd(HH, Q.Y, Q.X);
  FeMul(B, B, HH);
  FeMul(C, P.T, Q.T);
  FeMul(C, C, ED25519_D2);
  FeMul(D, P.Z, Q.Z);
  FeAdd(D, D, D);
  FeSub(E, B, A);
  FeSub(F, D, C);
  FeAdd(G, D, C);
  FeAdd(HH, B, A);
  FeMul(R.X, E, F);
  FeMul(R.Y, G, HH);
  FeMul(R.Z, F, G);
  FeMul(R.T, E, HH);
end;

procedure EdPointDouble(out R: TEdPoint; const P: TEdPoint);
var
  A, B, C, E, F, G, HH: TFe25519;
begin
  FeSq(A, P.X);
  FeSq(B, P.Y);
  FeSq(C, P.Z); FeAdd(C, C, C);
  FeNeg(HH, A);
  FeAdd(E, P.X, P.Y); FeSq(E, E); FeSub(E, E, A); FeSub(E, E, B);
  FeAdd(G, HH, B);
  FeSub(F, G, C);
  FeSub(HH, HH, B);
  FeMul(R.X, E, F);
  FeMul(R.Y, G, HH);
  FeMul(R.Z, F, G);
  FeMul(R.T, E, HH);
end;

procedure ScReduce(var S: array of Byte);
{ Reduces a 64-byte (512-bit) little-endian integer modulo the Ed25519 group
  order L = 2^252 + 27742317777372353535851937790883648493.
  Binary long division: for each bit from 511 down to 252, if the
  corresponding bit of A is set, subtract L shifted to that position. }
const
  { L in 32-bit little-endian limbs (8 limbs = 256 bits) }
  LL: array[0..7] of UInt32 = (
    $5CF5D3ED, $5812631A, $A2F79CD6, $14DEF9DE,
    $00000000, $00000000, $00000000, $10000000
  );
var
  A: array[0..15] of UInt32;
  I, Bit, LimbOfs, BitOfs, J: Integer;
  Borrow: Int64;
  LShifted: UInt32;
  T: array[0..15] of UInt32;
begin
  { Load 64 bytes into 16 x UInt32 limbs (little-endian) }
  for I := 0 to 15 do
    A[I] := UInt32(S[I*4]) or (UInt32(S[I*4+1]) shl 8) or
             (UInt32(S[I*4+2]) shl 16) or (UInt32(S[I*4+3]) shl 24);

  { Binary long division: for each bit position from 511 down to 252,
    check if that bit is set in A. If so, subtract L << (Bit - 252). }
  for Bit := 511 downto 252 do
  begin
    if ((A[Bit shr 5] shr (Bit and 31)) and 1) = 0 then
      Continue;

    { Subtract L << (Bit - 252) from A }
    LimbOfs := (Bit - 252) shr 5;
    BitOfs := (Bit - 252) and 31;

    Borrow := 0;
    for I := LimbOfs to 15 do
    begin
      J := I - LimbOfs;
      LShifted := 0;
      if (J >= 0) and (J <= 7) then
      begin
        if BitOfs = 0 then
          LShifted := LL[J]
        else
        begin
          LShifted := LL[J] shl BitOfs;
          if (J > 0) then
            LShifted := LShifted or (LL[J-1] shr (32 - BitOfs));
        end;
      end
      else if (J = 8) and (BitOfs > 0) then
        LShifted := LL[7] shr (32 - BitOfs)
      else
        LShifted := 0;

      Borrow := Int64(A[I]) - Int64(LShifted) + Borrow;
      A[I] := UInt32(Borrow and $FFFFFFFF);
      Borrow := Sar(Borrow, 32);
    end;
  end;

  { Final conditional subtraction: if A >= L, subtract L once more }
  Borrow := 0;
  for I := 0 to 7 do
  begin
    Borrow := Int64(A[I]) - Int64(LL[I]) + Borrow;
    T[I] := UInt32(Borrow and $FFFFFFFF);
    Borrow := Sar(Borrow, 32);
  end;
  for I := 8 to 15 do
  begin
    Borrow := Int64(A[I]) + Borrow;
    T[I] := UInt32(Borrow and $FFFFFFFF);
    Borrow := Sar(Borrow, 32);
  end;
  { If no borrow (Borrow >= 0), A >= L, use T; otherwise keep A }
  if Borrow >= 0 then
    for I := 0 to 15 do
      A[I] := T[I];

  { Write back 32 bytes (lower 8 limbs) }
  for I := 0 to 7 do
  begin
    S[I*4]   := Byte(A[I]);
    S[I*4+1] := Byte(A[I] shr 8);
    S[I*4+2] := Byte(A[I] shr 16);
    S[I*4+3] := Byte(A[I] shr 24);
  end;
  { Zero out remaining bytes }
  for I := 32 to 63 do
    S[I] := 0;
end;

procedure EdPointToBytes(out S: TBytes; const P: TEdPoint);
var
  RecipZ, X, Y: TFe25519;
begin
  FeInvert(RecipZ, P.Z);
  FeMul(X, P.X, RecipZ);
  FeMul(Y, P.Y, RecipZ);
  FeToBytes(S, Y);
  S[31] := S[31] xor Byte(FeIsNegative(X) shl 7);
end;

function EdBasePointMul(const AScalar: array of Byte): TEdPoint;
const
  ED25519_BASE_X: TFe25519 = (
    52811034, 25909283, 16144682, 17082669, 27570973,
    30858332, 40966398, 8378388, 20764389, 8758491
  );
  ED25519_BASE_Y: TFe25519 = (
    40265304, 26843545, 13421772, 20132659, 26843545,
    6710886, 53687091, 13421772, 40265318, 26843545
  );
  ED25519_BASE_T: TFe25519 = (
    28827043, 27438313, 39759291, 244362, 8635006,
    11264893, 19351346, 13413597, 16611511, 27139452
  );
var
  Q, T, B: TEdPoint;
  I: Integer;
begin
  B.X := ED25519_BASE_X;
  B.Y := ED25519_BASE_Y;
  B.Z := FE_ONE;
  B.T := ED25519_BASE_T;

  Q.X := FE_ZERO; Q.Y := FE_ONE; Q.Z := FE_ONE; Q.T := FE_ZERO;

  for I := 255 downto 0 do
  begin
    EdPointDouble(T, Q);
    Q := T;
    if ((AScalar[I shr 3] shr (I and 7)) and 1) = 1 then
    begin
      EdPointAdd(T, Q, B);
      Q := T;
    end;
  end;
  Result := Q;
end;

function EdScalarMulPoint(const AScalar: array of Byte; const P: TEdPoint): TEdPoint;
var
  Q, T: TEdPoint;
  I: Integer;
begin
  Q.X := FE_ZERO; Q.Y := FE_ONE; Q.Z := FE_ONE; Q.T := FE_ZERO;

  for I := 255 downto 0 do
  begin
    EdPointDouble(T, Q);
    Q := T;
    if ((AScalar[I shr 3] shr (I and 7)) and 1) = 1 then
    begin
      EdPointAdd(T, Q, P);
      Q := T;
    end;
  end;
  Result := Q;
end;

function Ed25519TestFePow2523(const AInput: TBytes): TBytes;
var
  LIn, LOut: TFe25519;
begin
  FeFromBytes(LIn, AInput, 0);
  FePow2523(LOut, LIn);
  FeToBytes(Result, LOut);
end;

function Ed25519TestScReduce(const AInput: TBytes): TBytes;
var
  LBuf: array[0..63] of Byte;
  I: Integer;
begin
  FillChar(LBuf, 64, 0);
  for I := 0 to High(AInput) do
    if I < 64 then LBuf[I] := AInput[I];
  ScReduce(LBuf);
  SetLength(Result, 32);
  Move(LBuf[0], Result[0], 32);
end;



function Ed25519TestFeSq(const AInput: TBytes): TBytes;
var
  LIn, LOut: TFe25519;
begin
  FeFromBytes(LIn, AInput, 0);
  FeSq(LOut, LIn);
  FeToBytes(Result, LOut);
end;

function Ed25519TestFeMul(const A, B: TBytes): TBytes;
var
  LA, LB, LOut: TFe25519;
begin
  FeFromBytes(LA, A, 0);
  FeFromBytes(LB, B, 0);
  FeMul(LOut, LA, LB);
  FeToBytes(Result, LOut);
end;

function Ed25519TestPointDouble(const APoint: TBytes): TBytes;
var
  P, R: TEdPoint;
begin
  if not EdPointDecode(P, APoint, 0) then
  begin
    SetLength(Result, 32);
    FillChar(Result[0], 32, 0);
    Exit;
  end;
  EdPointDouble(R, P);
  EdPointToBytes(Result, R);
end;

function Ed25519Verify(const APublicKey: TBytes; const AMessage: TBytes;
  const ASignature: TBytes): Boolean;
var
  A, SB, KA, R2: TEdPoint;
  LHash: TBytes;
  LK: array[0..63] of Byte;
  LS: array[0..31] of Byte;
  LCtx: TSHA512Context;
  LCheck: TBytes;
  I: Integer;
  D: Byte;
begin
  Result := False;

  if (Length(APublicKey) <> 32) or (Length(ASignature) <> 64) then
    Exit;

  if not EdPointDecode(A, APublicKey, 0) then
    Exit;
  FeNeg(A.X, A.X);
  FeNeg(A.T, A.T);

  LCtx := TSHA512Context.Create;
  try
    LCtx.Update(Copy(ASignature, 0, 32));
    LCtx.Update(APublicKey);
    LCtx.Update(AMessage);
    LHash := LCtx.Final;
  finally
    LCtx.Free;
  end;

  for I := 0 to 63 do
    LK[I] := LHash[I];
  ScReduce(LK);

  for I := 0 to 31 do
    LS[I] := ASignature[32 + I];

  SB := EdBasePointMul(LS);
  KA := EdScalarMulPoint(LK, A);
  EdPointAdd(R2, SB, KA);

  EdPointToBytes(LCheck, R2);

  D := 0;
  for I := 0 to 31 do
    D := D or (LCheck[I] xor ASignature[I]);

  Result := (D = 0);
end;

procedure ScMulAdd(out S: array of Byte; const A, B, C: array of Byte);
var
  LProduct: array[0..63] of Byte;
  I, J: Integer;
  LCarry: UInt32;
  LSum: UInt32;
begin
  // Compute A*B as 64-byte product (schoolbook multiply in bytes)
  FillChar(LProduct, 64, 0);
  for I := 0 to 31 do
    for J := 0 to 31 do
    begin
      LCarry := UInt32(LProduct[I + J]) + UInt32(A[I]) * UInt32(B[J]);
      LProduct[I + J] := Byte(LCarry);
      LCarry := LCarry shr 8;
      if LCarry > 0 then
      begin
        LSum := UInt32(LProduct[I + J + 1]) + LCarry;
        LProduct[I + J + 1] := Byte(LSum);
        if LSum > 255 then
        begin
          LSum := UInt32(LProduct[I + J + 2]) + (LSum shr 8);
          LProduct[I + J + 2] := Byte(LSum);
          if LSum > 255 then
            LProduct[I + J + 3] := LProduct[I + J + 3] + Byte(LSum shr 8);
        end;
      end;
    end;

  // Add C
  LCarry := 0;
  for I := 0 to 31 do
  begin
    LSum := UInt32(LProduct[I]) + UInt32(C[I]) + LCarry;
    LProduct[I] := Byte(LSum);
    LCarry := LSum shr 8;
  end;
  for I := 32 to 63 do
  begin
    if LCarry = 0 then Break;
    LSum := UInt32(LProduct[I]) + LCarry;
    LProduct[I] := Byte(LSum);
    LCarry := LSum shr 8;
  end;

  // Reduce mod L
  ScReduce(LProduct);

  // Copy result
  for I := 0 to 31 do
    S[I] := LProduct[I];
end;

function Ed25519TestScMulAdd(const A, B, C: TBytes): TBytes;
var
  LA, LB, LC: array[0..63] of Byte;
  LS: array[0..31] of Byte;
  I: Integer;
begin
  FillChar(LA, 64, 0);
  FillChar(LB, 64, 0);
  FillChar(LC, 64, 0);
  for I := 0 to 31 do
  begin
    if I <= High(A) then LA[I] := A[I];
    if I <= High(B) then LB[I] := B[I];
    if I <= High(C) then LC[I] := C[I];
  end;
  ScMulAdd(LS, LA, LB, LC);
  SetLength(Result, 32);
  Move(LS[0], Result[0], 32);
end;

function Ed25519PublicKeyFromPrivate(const APrivateKey: TBytes): TBytes;
var
  LHash: TBytes;
  LScalar: array[0..31] of Byte;
  LPub: TEdPoint;
  I: Integer;
begin
  if Length(APrivateKey) <> 32 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LHash := SHA512(APrivateKey);

  for I := 0 to 31 do
    LScalar[I] := LHash[I];
  // Clamp
  LScalar[0] := LScalar[0] and 248;
  LScalar[31] := (LScalar[31] and 127) or 64;

  LPub := EdBasePointMul(LScalar);
  EdPointToBytes(Result, LPub);
end;

function Ed25519Sign(const APrivateKey: TBytes; const AMessage: TBytes;
  out ASignature: TBytes): Boolean;
var
  LHash, LPublicKey, LPrefix: TBytes;
  LScalar: array[0..31] of Byte;
  LNonceHash: TBytes;
  LNonce: array[0..63] of Byte;
  LR: TEdPoint;
  LRBytes: TBytes;
  LKHash: TBytes;
  LK: array[0..63] of Byte;
  LS: array[0..31] of Byte;
  LCtx: TSHA512Context;
  I: Integer;
begin
  Result := False;
  if Length(APrivateKey) <> 32 then Exit;

  // Step 1: Hash private key
  LHash := SHA512(APrivateKey);
  for I := 0 to 31 do
    LScalar[I] := LHash[I];
  SetLength(LPrefix, 32);
  Move(LHash[32], LPrefix[0], 32);

  // Clamp scalar
  LScalar[0] := LScalar[0] and 248;
  LScalar[31] := (LScalar[31] and 127) or 64;

  // Derive public key
  LPublicKey := Ed25519PublicKeyFromPrivate(APrivateKey);
  if Length(LPublicKey) <> 32 then Exit;

  // Step 2: r = SHA-512(prefix || message) mod L
  LCtx := TSHA512Context.Create;
  try
    LCtx.Update(LPrefix);
    LCtx.Update(AMessage);
    LNonceHash := LCtx.Final;
  finally
    LCtx.Free;
  end;
  for I := 0 to 63 do
    LNonce[I] := LNonceHash[I];
  ScReduce(LNonce);

  // Step 3: R = r * B
  LR := EdBasePointMul(LNonce);
  EdPointToBytes(LRBytes, LR);

  // Step 4: k = SHA-512(R || public_key || message) mod L
  LCtx := TSHA512Context.Create;
  try
    LCtx.Update(LRBytes);
    LCtx.Update(LPublicKey);
    LCtx.Update(AMessage);
    LKHash := LCtx.Final;
  finally
    LCtx.Free;
  end;
  for I := 0 to 63 do
    LK[I] := LKHash[I];
  ScReduce(LK);

  // Step 5: S = (r + k * scalar) mod L
  ScMulAdd(LS, LK, LScalar, LNonce);

  // Build signature: R || S
  SetLength(ASignature, 64);
  Move(LRBytes[0], ASignature[0], 32);
  Move(LS[0], ASignature[32], 32);
  Result := True;
end;

end.
