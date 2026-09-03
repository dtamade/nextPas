program test_p256_point;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.p256.field,
  nextpas.core.crypto.p256.point,
  nextpas.core.test;

function BytesToHex(const D: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to Length(D)-1 do Result := Result + LowerCase(IntToHex(D[I],2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('p256_point');

  LSuite.Test('1*G = G', procedure
  var LScalar: TBytes; LR: TP256JacPoint; LX, LY: TP256Fe; LXB, LYB: TBytes;
  begin
    SetLength(LScalar, 32); FillChar(LScalar[0], 32, 0); LScalar[31] := 1;
    P256ScalarMultBase(LScalar, LR);
    P256PointToAffine(LR, LX, LY);
    P256FeToBytes(LX, LXB); P256FeToBytes(LY, LYB);
    CheckEqual('6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296', BytesToHex(LXB));
    CheckEqual('4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5', BytesToHex(LYB));
  end);

  LSuite.Test('2*G', procedure
  var LScalar: TBytes; LR: TP256JacPoint; LX, LY: TP256Fe; LXB, LYB: TBytes;
  begin
    SetLength(LScalar, 32); FillChar(LScalar[0], 32, 0); LScalar[31] := 2;
    P256ScalarMultBase(LScalar, LR);
    P256PointToAffine(LR, LX, LY);
    P256FeToBytes(LX, LXB); P256FeToBytes(LY, LYB);
    CheckTrue(P256PointIsInfinity(LR) = 0);
    CheckTrue(BytesToHex(LXB) <> '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296');
    CheckEqual('7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978', BytesToHex(LXB));
  end);

  LSuite.Test('Double(G) == Add(G,G)', procedure
  var LG, LDbl, LAdd: TP256JacPoint; LX1, LY1, LX2, LY2: TP256Fe; LX1B, LX2B: TBytes;
  begin
    LG.X[0] := QWord($F4A13945D898C296); LG.X[1] := QWord($77037D812DEB33A0);
    LG.X[2] := QWord($F8BCE6E563A440F2); LG.X[3] := QWord($6B17D1F2E12C4247);
    LG.Y[0] := QWord($CBB6406837BF51F5); LG.Y[1] := QWord($2BCE33576B315ECE);
    LG.Y[2] := QWord($8EE7EB4A7C0F9E16); LG.Y[3] := QWord($4FE342E2FE1A7F9B);
    P256FeOne(LG.Z);
    P256PointDouble(LG, LDbl); P256PointAdd(LG, LG, LAdd);
    P256PointToAffine(LDbl, LX1, LY1); P256PointToAffine(LAdd, LX2, LY2);
    P256FeToBytes(LX1, LX1B); P256FeToBytes(LX2, LX2B);
    CheckEqual(BytesToHex(LX1B), BytesToHex(LX2B));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.p256_point');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
