program test_p256_field;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.p256.field,
  nextpas.core.test;

function HexToBytes(const H: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(H) div 2);
  for I := 0 to Length(Result)-1 do Result[I] := StrToInt('$'+Copy(H,I*2+1,2));
end;

function BytesToHex(const D: TBytes): string;
var I: Integer;
begin Result := ''; for I := 0 to Length(D)-1 do Result := Result + LowerCase(IntToHex(D[I],2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('p256_field');

  LSuite.Test('add/sub', procedure
  var A, B, R, R2: TP256Fe;
  begin
    P256FeOne(A); P256FeOne(B);
    P256FeAdd(A, B, R);
    CheckTrue(R[0] = 2, '1+1=2 limb0');
    CheckTrue(R[1] = 0, '1+1=2 limb1');
    P256FeSub(R, B, R2);
    CheckTrue(R2[0] = 1, '2-1=1');
    P256FeZero(A); P256FeOne(B);
    P256FeSub(A, B, R);
    CheckTrue(R[0] = QWord($FFFFFFFFFFFFFFFE), '0-1 mod p limb0');
    CheckTrue(R[3] = QWord($FFFFFFFF00000001), '0-1 mod p limb3');
  end);

  LSuite.Test('mul by 1', procedure
  var A, One, R: TP256Fe; LBytes, LOut: TBytes;
  begin
    LBytes := HexToBytes('6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296');
    P256FeFromBytes(LBytes, A); P256FeOne(One);
    P256FeMul(A, One, R); P256FeToBytes(R, LOut);
    CheckEqual(BytesToHex(LBytes), BytesToHex(LOut));
  end);

  LSuite.Test('mul by 0', procedure
  var A, Zero, R: TP256Fe; LBytes: TBytes;
  begin
    LBytes := HexToBytes('6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296');
    P256FeFromBytes(LBytes, A); P256FeZero(Zero);
    P256FeMul(A, Zero, R);
    CheckTrue(P256FeIsZero(R) = 1, 'a*0 = 0');
  end);

  LSuite.Test('sqr vs mul', procedure
  var A, R, R2: TP256Fe; LBytes: TBytes;
  begin
    LBytes := HexToBytes('6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296');
    P256FeFromBytes(LBytes, A);
    P256FeSqr(A, R); P256FeMul(A, A, R2);
    CheckTrue((R[0]=R2[0]) and (R[1]=R2[1]) and (R[2]=R2[2]) and (R[3]=R2[3]));
  end);

  LSuite.Test('inverse', procedure
  var A, Inv, R: TP256Fe; LBytes: TBytes;
  begin
    LBytes := HexToBytes('6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296');
    P256FeFromBytes(LBytes, A); P256FeInv(A, Inv);
    P256FeMul(A, Inv, R);
    CheckTrue(R[0] = 1, 'a*a^-1 limb0=1');
    CheckTrue(R[1] = 0, 'a*a^-1 limb1=0');
    CheckTrue(R[2] = 0, 'a*a^-1 limb2=0');
    CheckTrue(R[3] = 0, 'a*a^-1 limb3=0');
  end);

  LSuite.Test('known mul (Gx*Gy)*Gy^-1=Gx', procedure
  var A, B, R: TP256Fe; LA, LB, LOut: TBytes;
  begin
    LA := HexToBytes('6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296');
    LB := HexToBytes('4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5');
    P256FeFromBytes(LA, A); P256FeFromBytes(LB, B);
    P256FeMul(A, B, R); P256FeToBytes(R, LOut);
    CheckEqual(32, Length(LOut));
    P256FeInv(B, B); P256FeMul(R, B, R); P256FeToBytes(R, LOut);
    CheckEqual(BytesToHex(LA), BytesToHex(LOut));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.p256_field');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
