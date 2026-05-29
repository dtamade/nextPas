unit nextpas.core.tls.crypto.ed25519;

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

function Ed25519TestFePow2523(const AInput: TBytes): TBytes;
function Ed25519TestFeSq(const AInput: TBytes): TBytes;
function Ed25519TestFeMul(const A, B: TBytes): TBytes;
function Ed25519TestPointDouble(const APoint: TBytes): TBytes;

implementation

uses
  nextpas.core.tls.crypto.hash;

type
  TFe25519 = array[0..9] of Int64;

  TEdPoint = record
    X, Y, Z, T: TFe25519;
  end;

function Sar(AValue: Int64; AShift: Integer): Int64; inline;
begin
  Result := SarInt64(AValue, AShift);
end;

const
  FE_ZERO: TFe25519 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  FE_ONE: TFe25519 = (1, 0, 0, 0, 0, 0, 0, 0, 0, 0);

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

procedure FeFromBytes(out H: TFe25519; const S: TBytes; AOffset: Integer);
var
  H0, H1, H2, H3, H4, H5, H6, H7, H8, H9: Int64;
  C: Int64;

  function Load4(I: Integer): Int64; inline;
  begin
    Result := Int64(S[AOffset+I]) or (Int64(S[AOffset+I+1]) shl 8) or
              (Int64(S[AOffset+I+2]) shl 16) or (Int64(S[AOffset+I+3]) shl 24);
  end;

  function Load3(I: Integer): Int64; inline;
  begin
    Result := Int64(S[AOffset+I]) or (Int64(S[AOffset+I+1]) shl 8) or
              (Int64(S[AOffset+I+2]) shl 16);
  end;

begin
  H0 := Load4(0);
  H1 := Load3(4) shl 6;
  H2 := Load3(7) shl 5;
  H3 := Load3(10) shl 3;
  H4 := Load3(13) shl 2;
  H5 := Load4(16);
  H6 := Load3(20) shl 7;
  H7 := Load3(23) shl 5;
  H8 := Load3(26) shl 4;
  H9 := (Load3(29) and $7FFFFF) shl 2;

  C := Sar(H9 + (Int64(1) shl 24), 25); H0 := H0 + C * 19; H9 := H9 - (C shl 25);
  C := Sar(H1 + (Int64(1) shl 24), 25); H2 := H2 + C; H1 := H1 - (C shl 25);
  C := Sar(H3 + (Int64(1) shl 24), 25); H4 := H4 + C; H3 := H3 - (C shl 25);
  C := Sar(H5 + (Int64(1) shl 24), 25); H6 := H6 + C; H5 := H5 - (C shl 25);
  C := Sar(H7 + (Int64(1) shl 24), 25); H8 := H8 + C; H7 := H7 - (C shl 25);

  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);
  C := Sar(H2 + (Int64(1) shl 25), 26); H3 := H3 + C; H2 := H2 - (C shl 26);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H6 + (Int64(1) shl 25), 26); H7 := H7 + C; H6 := H6 - (C shl 26);
  C := Sar(H8 + (Int64(1) shl 25), 26); H9 := H9 + C; H8 := H8 - (C shl 26);

  H[0] := H0; H[1] := H1; H[2] := H2; H[3] := H3; H[4] := H4;
  H[5] := H5; H[6] := H6; H[7] := H7; H[8] := H8; H[9] := H9;
end;

procedure FeToBytes(out S: TBytes; const H: TFe25519);
var
  T: TFe25519;
  Q, C: Int64;
begin
  T := H;
  Q := Sar(19 * T[9] + (Int64(1) shl 24), 25);
  Q := Sar(T[0] + Q, 26);
  Q := Sar(T[1] + Q, 25);
  Q := Sar(T[2] + Q, 26);
  Q := Sar(T[3] + Q, 25);
  Q := Sar(T[4] + Q, 26);
  Q := Sar(T[5] + Q, 25);
  Q := Sar(T[6] + Q, 26);
  Q := Sar(T[7] + Q, 25);
  Q := Sar(T[8] + Q, 26);
  Q := Sar(T[9] + Q, 25);
  T[0] := T[0] + 19 * Q;

  C := Sar(T[0], 26); T[1] := T[1] + C; T[0] := T[0] - (C shl 26);
  C := Sar(T[1], 25); T[2] := T[2] + C; T[1] := T[1] - (C shl 25);
  C := Sar(T[2], 26); T[3] := T[3] + C; T[2] := T[2] - (C shl 26);
  C := Sar(T[3], 25); T[4] := T[4] + C; T[3] := T[3] - (C shl 25);
  C := Sar(T[4], 26); T[5] := T[5] + C; T[4] := T[4] - (C shl 26);
  C := Sar(T[5], 25); T[6] := T[6] + C; T[5] := T[5] - (C shl 25);
  C := Sar(T[6], 26); T[7] := T[7] + C; T[6] := T[6] - (C shl 26);
  C := Sar(T[7], 25); T[8] := T[8] + C; T[7] := T[7] - (C shl 25);
  C := Sar(T[8], 26); T[9] := T[9] + C; T[8] := T[8] - (C shl 26);
  C := Sar(T[9], 25); T[9] := T[9] - (C shl 25);

  SetLength(S, 32);
  S[0]  := Byte(T[0]);
  S[1]  := Byte(T[0] shr 8);
  S[2]  := Byte(T[0] shr 16);
  S[3]  := Byte((T[0] shr 24) or (T[1] shl 2));
  S[4]  := Byte(T[1] shr 6);
  S[5]  := Byte(T[1] shr 14);
  S[6]  := Byte((T[1] shr 22) or (T[2] shl 3));
  S[7]  := Byte(T[2] shr 5);
  S[8]  := Byte(T[2] shr 13);
  S[9]  := Byte((T[2] shr 21) or (T[3] shl 5));
  S[10] := Byte(T[3] shr 3);
  S[11] := Byte(T[3] shr 11);
  S[12] := Byte((T[3] shr 19) or (T[4] shl 6));
  S[13] := Byte(T[4] shr 2);
  S[14] := Byte(T[4] shr 10);
  S[15] := Byte(T[4] shr 18);
  S[16] := Byte(T[5]);
  S[17] := Byte(T[5] shr 8);
  S[18] := Byte(T[5] shr 16);
  S[19] := Byte((T[5] shr 24) or (T[6] shl 1));
  S[20] := Byte(T[6] shr 7);
  S[21] := Byte(T[6] shr 15);
  S[22] := Byte((T[6] shr 23) or (T[7] shl 3));
  S[23] := Byte(T[7] shr 5);
  S[24] := Byte(T[7] shr 13);
  S[25] := Byte((T[7] shr 21) or (T[8] shl 4));
  S[26] := Byte(T[8] shr 4);
  S[27] := Byte(T[8] shr 12);
  S[28] := Byte((T[8] shr 20) or (T[9] shl 6));
  S[29] := Byte(T[9] shr 2);
  S[30] := Byte(T[9] shr 10);
  S[31] := Byte(T[9] shr 18);
end;

procedure FeAdd(out H: TFe25519; const F, G: TFe25519);
var I: Integer;
begin
  for I := 0 to 9 do H[I] := F[I] + G[I];
end;

procedure FeSub(out H: TFe25519; const F, G: TFe25519);
var I: Integer;
begin
  for I := 0 to 9 do H[I] := F[I] - G[I];
end;

procedure FeNeg(out H: TFe25519; const F: TFe25519);
var I: Integer;
begin
  for I := 0 to 9 do H[I] := -F[I];
end;

procedure FeMul(out H: TFe25519; const F, G: TFe25519);
var
  F0, F1, F2, F3, F4, F5, F6, F7, F8, F9: Int64;
  F1_2, F3_2, F5_2, F7_2, F9_2: Int64;
  G0, G1, G2, G3, G4, G5, G6, G7, G8, G9: Int64;
  G1_19, G2_19, G3_19, G4_19, G5_19, G6_19, G7_19, G8_19, G9_19: Int64;
  H0, H1, H2, H3, H4, H5, H6, H7, H8, H9: Int64;
  C: Int64;
begin
  F0 := F[0]; F1 := F[1]; F2 := F[2]; F3 := F[3]; F4 := F[4];
  F5 := F[5]; F6 := F[6]; F7 := F[7]; F8 := F[8]; F9 := F[9];
  F1_2 := 2*F1; F3_2 := 2*F3; F5_2 := 2*F5; F7_2 := 2*F7; F9_2 := 2*F9;
  G0 := G[0]; G1 := G[1]; G2 := G[2]; G3 := G[3]; G4 := G[4];
  G5 := G[5]; G6 := G[6]; G7 := G[7]; G8 := G[8]; G9 := G[9];
  G1_19 := 19*G1; G2_19 := 19*G2; G3_19 := 19*G3;
  G4_19 := 19*G4; G5_19 := 19*G5; G6_19 := 19*G6;
  G7_19 := 19*G7; G8_19 := 19*G8; G9_19 := 19*G9;

  H0 := F0*G0 + F1_2*G9_19 + F2*G8_19 + F3_2*G7_19 + F4*G6_19 +
        F5_2*G5_19 + F6*G4_19 + F7_2*G3_19 + F8*G2_19 + F9_2*G1_19;
  H1 := F0*G1 + F1*G0 + F2*G9_19 + F3*G8_19 + F4*G7_19 +
        F5*G6_19 + F6*G5_19 + F7*G4_19 + F8*G3_19 + F9*G2_19;
  H2 := F0*G2 + F1_2*G1 + F2*G0 + F3_2*G9_19 + F4*G8_19 +
        F5_2*G7_19 + F6*G6_19 + F7_2*G5_19 + F8*G4_19 + F9_2*G3_19;
  H3 := F0*G3 + F1*G2 + F2*G1 + F3*G0 + F4*G9_19 +
        F5*G8_19 + F6*G7_19 + F7*G6_19 + F8*G5_19 + F9*G4_19;
  H4 := F0*G4 + F1_2*G3 + F2*G2 + F3_2*G1 + F4*G0 +
        F5_2*G9_19 + F6*G8_19 + F7_2*G7_19 + F8*G6_19 + F9_2*G5_19;
  H5 := F0*G5 + F1*G4 + F2*G3 + F3*G2 + F4*G1 +
        F5*G0 + F6*G9_19 + F7*G8_19 + F8*G7_19 + F9*G6_19;
  H6 := F0*G6 + F1_2*G5 + F2*G4 + F3_2*G3 + F4*G2 +
        F5_2*G1 + F6*G0 + F7_2*G9_19 + F8*G8_19 + F9_2*G7_19;
  H7 := F0*G7 + F1*G6 + F2*G5 + F3*G4 + F4*G3 +
        F5*G2 + F6*G1 + F7*G0 + F8*G9_19 + F9*G8_19;
  H8 := F0*G8 + F1_2*G7 + F2*G6 + F3_2*G5 + F4*G4 +
        F5_2*G3 + F6*G2 + F7_2*G1 + F8*G0 + F9_2*G9_19;
  H9 := F0*G9 + F1*G8 + F2*G7 + F3*G6 + F4*G5 +
        F5*G4 + F6*G3 + F7*G2 + F8*G1 + F9*G0;

  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H1 + (Int64(1) shl 24), 25); H2 := H2 + C; H1 := H1 - (C shl 25);
  C := Sar(H5 + (Int64(1) shl 24), 25); H6 := H6 + C; H5 := H5 - (C shl 25);
  C := Sar(H2 + (Int64(1) shl 25), 26); H3 := H3 + C; H2 := H2 - (C shl 26);
  C := Sar(H6 + (Int64(1) shl 25), 26); H7 := H7 + C; H6 := H6 - (C shl 26);
  C := Sar(H3 + (Int64(1) shl 24), 25); H4 := H4 + C; H3 := H3 - (C shl 25);
  C := Sar(H7 + (Int64(1) shl 24), 25); H8 := H8 + C; H7 := H7 - (C shl 25);
  C := Sar(H4 + (Int64(1) shl 25), 26); H5 := H5 + C; H4 := H4 - (C shl 26);
  C := Sar(H8 + (Int64(1) shl 25), 26); H9 := H9 + C; H8 := H8 - (C shl 26);
  C := Sar(H9 + (Int64(1) shl 24), 25); H0 := H0 + C * 19; H9 := H9 - (C shl 25);
  C := Sar(H0 + (Int64(1) shl 25), 26); H1 := H1 + C; H0 := H0 - (C shl 26);

  H[0] := H0; H[1] := H1; H[2] := H2; H[3] := H3; H[4] := H4;
  H[5] := H5; H[6] := H6; H[7] := H7; H[8] := H8; H[9] := H9;
end;

procedure FeSq(out H: TFe25519; const F: TFe25519);
begin
  FeMul(H, F, F);
end;

procedure FeInvert(out O: TFe25519; const Z: TFe25519);
var
  T0, T1, T2, T3: TFe25519;
  I: Integer;
begin
  FeSq(T0, Z);
  FeSq(T1, T0); FeSq(T1, T1);
  FeMul(T1, Z, T1);
  FeMul(T0, T0, T1);
  FeSq(T2, T0);
  FeMul(T1, T1, T2);
  FeSq(T2, T1); for I := 1 to 4 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T2, T1); for I := 1 to 9 do FeSq(T2, T2);
  FeMul(T2, T2, T1);
  FeSq(T3, T2); for I := 1 to 19 do FeSq(T3, T3);
  FeMul(T2, T3, T2);
  FeSq(T2, T2); for I := 1 to 9 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T2, T1); for I := 1 to 49 do FeSq(T2, T2);
  FeMul(T2, T2, T1);
  FeSq(T3, T2); for I := 1 to 99 do FeSq(T3, T3);
  FeMul(T2, T3, T2);
  FeSq(T2, T2); for I := 1 to 49 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T1, T1); for I := 1 to 4 do FeSq(T1, T1);
  FeMul(O, T1, T0);
end;

procedure FePow2523(out O: TFe25519; const Z: TFe25519);
var
  T0, T1, T2: TFe25519;
  I: Integer;
begin
  FeSq(T0, Z);
  FeSq(T1, T0); FeSq(T1, T1);
  FeMul(T1, Z, T1);
  FeMul(T0, T0, T1);
  FeSq(T0, T0);
  FeMul(T0, T1, T0);
  FeSq(T1, T0); for I := 1 to 4 do FeSq(T1, T1);
  FeMul(T0, T1, T0);
  FeSq(T1, T0); for I := 1 to 9 do FeSq(T1, T1);
  FeMul(T1, T1, T0);
  FeSq(T2, T1); for I := 1 to 19 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T1, T1); for I := 1 to 9 do FeSq(T1, T1);
  FeMul(T0, T1, T0);
  FeSq(T1, T0); for I := 1 to 49 do FeSq(T1, T1);
  FeMul(T1, T1, T0);
  FeSq(T2, T1); for I := 1 to 99 do FeSq(T2, T2);
  FeMul(T1, T2, T1);
  FeSq(T1, T1); for I := 1 to 49 do FeSq(T1, T1);
  FeMul(T0, T1, T0);
  FeSq(T0, T0); FeSq(T0, T0);
  FeMul(O, T0, Z);
end;

function FeIsNegative(const F: TFe25519): Integer;
var S: TBytes;
begin
  FeToBytes(S, F);
  Result := Integer(S[0] and 1);
end;

function FeIsZero(const F: TFe25519): Boolean;
var
  S: TBytes;
  I: Integer;
  D: Byte;
begin
  FeToBytes(S, F);
  D := 0;
  for I := 0 to 31 do D := D or S[I];
  Result := (D = 0);
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
  ED25519_BASEPOINT: array[0..31] of Byte = (
    $58, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66,
    $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66, $66
  );
var
  Q, T, B: TEdPoint;
  I: Integer;
  LBP: TBytes;
begin
  SetLength(LBP, 32);
  Move(ED25519_BASEPOINT[0], LBP[0], 32);
  if not EdPointDecode(B, LBP, 0) then
  begin
    Q.X := FE_ZERO; Q.Y := FE_ONE; Q.Z := FE_ONE; Q.T := FE_ZERO;
    Result := Q;
    Exit;
  end;

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
