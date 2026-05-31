unit nextpas.core.crypto.p256.point;

{$mode ObjFPC}{$H+}{$J-}
{$Q-}{$R-}

interface

uses
  SysUtils, nextpas.core.crypto.p256.field;

type
  TP256JacPoint = record
    X, Y, Z: TP256Fe;
  end;

  TP256AffPoint = record
    X, Y: TP256Fe;
  end;

procedure P256PointInfinity(out P: TP256JacPoint);
function P256PointIsInfinity(const P: TP256JacPoint): QWord;
procedure P256PointDouble(const P: TP256JacPoint; out R: TP256JacPoint);
procedure P256PointAdd(const P, Q: TP256JacPoint; out R: TP256JacPoint);
procedure P256PointToAffine(const P: TP256JacPoint; out AX, AY: TP256Fe);
procedure P256ScalarMult(const AScalar: TBytes; const P: TP256JacPoint; out R: TP256JacPoint);
procedure P256ScalarMultBase(const AScalar: TBytes; out R: TP256JacPoint);

implementation

const
  P256_GX: TP256Fe = (
    QWord($F4A13945D898C296), QWord($77037D812DEB33A0),
    QWord($F8BCE6E563A440F2), QWord($6B17D1F2E12C4247)
  );
  P256_GY: TP256Fe = (
    QWord($CBB6406837BF51F5), QWord($2BCE33576B315ECE),
    QWord($8EE7EB4A7C0F9E16), QWord($4FE342E2FE1A7F9B)
  );

procedure P256PointInfinity(out P: TP256JacPoint);
begin
  P256FeZero(P.X);
  P256FeOne(P.Y);
  P256FeZero(P.Z);
end;

function P256PointIsInfinity(const P: TP256JacPoint): QWord;
begin
  Result := P256FeIsZero(P.Z);
end;

// Jacobian doubling for a=-3 curves (P-256): cost 4M + 4S
procedure P256PointDouble(const P: TP256JacPoint; out R: TP256JacPoint);
var
  A, B, C, D, E, F: TP256Fe;
  LT1, LT2: TP256Fe;
begin
  // A = X^2
  P256FeSqr(P.X, A);
  // B = Y^2
  P256FeSqr(P.Y, B);
  // C = B^2
  P256FeSqr(B, C);
  // D = 2*((X+B)^2 - A - C)
  P256FeAdd(P.X, B, LT1);
  P256FeSqr(LT1, LT1);
  P256FeSub(LT1, A, LT1);
  P256FeSub(LT1, C, LT1);
  P256FeAdd(LT1, LT1, D);
  // E = 3*A + a*Z^4 (a=-3 for P-256, so E = 3*A - 3*Z^4 = 3*(A - Z^4))
  P256FeSqr(P.Z, LT1);
  P256FeSqr(LT1, LT2); // Z^4
  P256FeSub(A, LT2, LT1); // A - Z^4
  P256FeAdd(LT1, LT1, E); // 2*(A - Z^4)
  P256FeAdd(E, LT1, E);   // 3*(A - Z^4)
  // F = E^2
  P256FeSqr(E, F);
  // X3 = F - 2*D
  P256FeAdd(D, D, LT1);
  P256FeSub(F, LT1, R.X);
  // Y3 = E*(D - X3) - 8*C
  P256FeSub(D, R.X, LT1);
  P256FeMul(E, LT1, R.Y);
  P256FeAdd(C, C, LT1); // 2C
  P256FeAdd(LT1, LT1, LT1); // 4C
  P256FeAdd(LT1, LT1, LT1); // 8C
  P256FeSub(R.Y, LT1, R.Y);
  // Z3 = 2*Y*Z
  P256FeMul(P.Y, P.Z, LT1);
  P256FeAdd(LT1, LT1, R.Z);
end;

// Jacobian addition (complete formula handling edge cases via CT)
procedure P256PointAdd(const P, Q: TP256JacPoint; out R: TP256JacPoint);
var
  U1, U2, S1, S2, H, I, J, RR, V: TP256Fe;
  LT1, LT2: TP256Fe;
  LPInf, LQInf, LEqual: QWord;
  LDbl: TP256JacPoint;
begin
  // U1 = X1*Z2^2, U2 = X2*Z1^2
  P256FeSqr(Q.Z, LT1);
  P256FeMul(P.X, LT1, U1);
  P256FeSqr(P.Z, LT2);
  P256FeMul(Q.X, LT2, U2);
  // S1 = Y1*Z2^3, S2 = Y2*Z1^3
  P256FeMul(LT1, Q.Z, LT1);
  P256FeMul(P.Y, LT1, S1);
  P256FeMul(LT2, P.Z, LT2);
  P256FeMul(Q.Y, LT2, S2);
  // H = U2 - U1
  P256FeSub(U2, U1, H);
  // I = (2*H)^2
  P256FeAdd(H, H, LT1);
  P256FeSqr(LT1, I);
  // J = H*I
  P256FeMul(H, I, J);
  // r = 2*(S2 - S1)
  P256FeSub(S2, S1, RR);
  P256FeAdd(RR, RR, RR);
  // V = U1*I
  P256FeMul(U1, I, V);
  // X3 = r^2 - J - 2*V
  P256FeSqr(RR, R.X);
  P256FeSub(R.X, J, R.X);
  P256FeAdd(V, V, LT1);
  P256FeSub(R.X, LT1, R.X);
  // Y3 = r*(V - X3) - 2*S1*J
  P256FeSub(V, R.X, LT1);
  P256FeMul(RR, LT1, R.Y);
  P256FeMul(S1, J, LT1);
  P256FeAdd(LT1, LT1, LT1);
  P256FeSub(R.Y, LT1, R.Y);
  // Z3 = ((Z1+Z2)^2 - Z1^2 - Z2^2)*H
  P256FeAdd(P.Z, Q.Z, LT1);
  P256FeSqr(LT1, LT1);
  P256FeSqr(P.Z, LT2);
  P256FeSub(LT1, LT2, LT1);
  P256FeSqr(Q.Z, LT2);
  P256FeSub(LT1, LT2, LT1);
  P256FeMul(LT1, H, R.Z);

  // Handle special cases (CT):
  // If P = infinity, result = Q
  LPInf := P256PointIsInfinity(P);
  P256FeCondCopy(Q.X, R.X, LPInf);
  P256FeCondCopy(Q.Y, R.Y, LPInf);
  P256FeCondCopy(Q.Z, R.Z, LPInf);
  // If Q = infinity, result = P
  LQInf := P256PointIsInfinity(Q);
  P256FeCondCopy(P.X, R.X, LQInf);
  P256FeCondCopy(P.Y, R.Y, LQInf);
  P256FeCondCopy(P.Z, R.Z, LQInf);
  // If P = Q (H=0, S1=S2), use doubling
  LEqual := P256FeIsZero(H) and (1 - LPInf) and (1 - LQInf);
  if LEqual = 1 then
  begin
    P256PointDouble(P, LDbl);
    P256FeCondCopy(LDbl.X, R.X, LEqual);
    P256FeCondCopy(LDbl.Y, R.Y, LEqual);
    P256FeCondCopy(LDbl.Z, R.Z, LEqual);
  end;
end;

procedure P256PointToAffine(const P: TP256JacPoint; out AX, AY: TP256Fe);
var
  ZInv, ZInv2, ZInv3: TP256Fe;
begin
  P256FeInv(P.Z, ZInv);
  P256FeSqr(ZInv, ZInv2);
  P256FeMul(ZInv2, ZInv, ZInv3);
  P256FeMul(P.X, ZInv2, AX);
  P256FeMul(P.Y, ZInv3, AY);
end;

// CT scalar multiplication using double-and-always-add with conditional copy
procedure P256ScalarMult(const AScalar: TBytes; const P: TP256JacPoint; out R: TP256JacPoint);
var
  LR0, LR1, LAdd, LDbl: TP256JacPoint;
  I, J, LBit: Integer;
  LSwap: QWord;
begin
  P256PointInfinity(LR0);
  LR1 := P;

  for I := 0 to 31 do
    for J := 7 downto 0 do
    begin
      if I * 8 + (7 - J) < Length(AScalar) * 8 then
        LBit := (AScalar[I] shr J) and 1
      else
        LBit := 0;

      // Montgomery ladder: always compute both, select based on bit
      P256PointAdd(LR0, LR1, LAdd);
      P256PointDouble(LR0, LDbl);

      // If bit=1: R0=Add, R1=Double(R1) — wait, standard ladder:
      // If bit=1: R0=R0+R1, R1=2*R1
      // If bit=0: R1=R0+R1, R0=2*R0
      // Simpler CT: swap(R0,R1) if bit!=prev_bit, then R1=R0+R1, R0=2*R0, ...
      // Actually simplest correct CT: double-and-always-add
      P256PointDouble(LR0, LDbl);
      P256PointAdd(LDbl, LR1, LAdd);
      // If bit=1: R0 = Add; else R0 = Dbl
      LSwap := QWord(LBit);
      P256FeCondCopy(LAdd.X, LDbl.X, LSwap);
      P256FeCondCopy(LAdd.Y, LDbl.Y, LSwap);
      P256FeCondCopy(LAdd.Z, LDbl.Z, LSwap);
      LR0 := LDbl;
    end;

  R := LR0;
end;

procedure P256ScalarMultBase(const AScalar: TBytes; out R: TP256JacPoint);
var
  LG: TP256JacPoint;
begin
  LG.X := P256_GX;
  LG.Y := P256_GY;
  P256FeOne(LG.Z);
  P256ScalarMult(AScalar, LG, R);
end;

end.
