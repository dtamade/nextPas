program test_p256_point;
{$mode ObjFPC}{$H+}{$Q-}{$R-}
uses SysUtils, nextpas.core.crypto.p256.field, nextpas.core.crypto.p256.point;

var GPass: Integer = 0; GFail: Integer = 0;

procedure Check(C: Boolean; const N: string);
begin if C then begin WriteLn('  [PASS] ', N); Inc(GPass); end else begin WriteLn('  [FAIL] ', N); Inc(GFail); end; end;

function HexToBytes(const H: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(H) div 2); for I := 0 to Length(Result)-1 do Result[I] := StrToInt('$'+Copy(H,I*2+1,2)); end;

function BytesToHex(const D: TBytes): string;
var I: Integer;
begin Result := ''; for I := 0 to Length(D)-1 do Result := Result + LowerCase(IntToHex(D[I],2)); end;

procedure TestScalarMultBaseOne;
var
  LScalar: TBytes;
  LR: TP256JacPoint;
  LX, LY: TP256Fe;
  LXBytes, LYBytes: TBytes;
begin
  WriteLn('--- 1*G = G ---');
  // scalar = 1 (big-endian 32 bytes)
  SetLength(LScalar, 32);
  FillChar(LScalar[0], 32, 0);
  LScalar[31] := 1;

  P256ScalarMultBase(LScalar, LR);
  P256PointToAffine(LR, LX, LY);
  P256FeToBytes(LX, LXBytes);
  P256FeToBytes(LY, LYBytes);

  Check(BytesToHex(LXBytes) = '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296',
    'Gx matches');
  Check(BytesToHex(LYBytes) = '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5',
    'Gy matches');
end;

procedure TestScalarMultBaseTwo;
var
  LScalar: TBytes;
  LR: TP256JacPoint;
  LX, LY: TP256Fe;
  LXBytes, LYBytes: TBytes;
begin
  WriteLn('--- 2*G ---');
  SetLength(LScalar, 32);
  FillChar(LScalar[0], 32, 0);
  LScalar[31] := 2;

  P256ScalarMultBase(LScalar, LR);
  P256PointToAffine(LR, LX, LY);
  P256FeToBytes(LX, LXBytes);
  P256FeToBytes(LY, LYBytes);

  // 2*G for P-256:
  // X = 7cf27b188d034f7e8a52380304b51ac3c90e3e7f1bb6e3e0e2e3e3e3e3e3... (need exact value)
  // From NIST: 2G.x = 7cf27b188d034f7e8a52380304b51ac3c90e3e7f1bb6e3e0e2e3e3e3...
  // Actually let's just verify it's not infinity and not G
  Check(P256PointIsInfinity(LR) = 0, '2*G is not infinity');
  Check(BytesToHex(LXBytes) <> '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296',
    '2*G != G');
  // Known value: 2G.x = 7cf27b188d034f7e8a52380304b51ac3c90e3e7f1bb6e3e0e2e3e3e3...
  // python3: from ecdsa import NIST256p; G=NIST256p.generator; P=2*G; hex(P.x())
  // = 0x7cf27b188d034f7e8a52380304b51ac3c90e3e7f1bb6e3e0e2e3e3e3e3e3e3e3 (placeholder)
  // Let's use the known value:
  Check(BytesToHex(LXBytes) = '7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978',
    '2G.x matches NIST');
end;

procedure TestDoubleEqualsAdd;
var
  LG, LDbl, LAdd: TP256JacPoint;
  LX1, LY1, LX2, LY2: TP256Fe;
  LX1B, LX2B: TBytes;
begin
  WriteLn('--- Double(G) == Add(G, G) ---');
  LG.X[0] := QWord($F4A13945D898C296); LG.X[1] := QWord($77037D812DEB33A0);
  LG.X[2] := QWord($F8BCE6E563A440F2); LG.X[3] := QWord($6B17D1F2E12C4247);
  LG.Y[0] := QWord($CBB6406837BF51F5); LG.Y[1] := QWord($2BCE33576B315ECE);
  LG.Y[2] := QWord($8EE7EB4A7C0F9E16); LG.Y[3] := QWord($4FE342E2FE1A7F9B);
  P256FeOne(LG.Z);

  P256PointDouble(LG, LDbl);
  P256PointAdd(LG, LG, LAdd);

  P256PointToAffine(LDbl, LX1, LY1);
  P256PointToAffine(LAdd, LX2, LY2);

  P256FeToBytes(LX1, LX1B);
  P256FeToBytes(LX2, LX2B);

  Check(BytesToHex(LX1B) = BytesToHex(LX2B), 'Double(G).x == Add(G,G).x');
end;

begin
  WriteLn('=== P-256 Point Arithmetic Tests ===');
  WriteLn;
  TestScalarMultBaseOne;
  TestScalarMultBaseTwo;
  TestDoubleEqualsAdd;
  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
