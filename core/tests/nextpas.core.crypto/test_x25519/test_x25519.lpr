program test_x25519;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.x25519,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('x25519');

  LSuite.Test('RFC 7748 vector 1', procedure
  var LScalar, LU, LResult: TBytes;
  begin
    LScalar := HexToBytes('a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4');
    LU := HexToBytes('e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c');
    LResult := X25519ScalarMult(LScalar, LU);
    CheckEqual('c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552', BytesToHex(LResult));
  end);

  LSuite.Test('RFC 7748 vector 2', procedure
  var LScalar, LU, LResult: TBytes;
  begin
    LScalar := HexToBytes('4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d');
    LU := HexToBytes('e5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493');
    LResult := X25519ScalarMult(LScalar, LU);
    CheckEqual('95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957', BytesToHex(LResult));
  end);

  LSuite.Test('base point mult', procedure
  var LPriv, LExpectedPub, LResult: TBytes;
  begin
    LPriv := HexToBytes('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
    LExpectedPub := HexToBytes('8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a');
    LResult := X25519PublicKeyFromPrivate(LPriv);
    CheckEqual(BytesToHex(LExpectedPub), BytesToHex(LResult));
  end);

  LSuite.Test('ECDH roundtrip', procedure
  var LPrivA, LPubA, LPrivB, LPubB, LSharedAB, LSharedBA: TBytes;
  begin
    GenerateX25519KeyPair(LPrivA, LPubA);
    GenerateX25519KeyPair(LPrivB, LPubB);
    LSharedAB := X25519ComputeSharedSecret(LPrivA, LPubB);
    LSharedBA := X25519ComputeSharedSecret(LPrivB, LPubA);
    CheckEqual(BytesToHex(LSharedAB), BytesToHex(LSharedBA));
    CheckEqual(32, Length(LSharedAB));
  end);

  LSuite.Test('iterative 1000', procedure
  var LK, LU, LResult: TBytes; I: Integer;
  begin
    SetLength(LK, 32); SetLength(LU, 32);
    FillChar(LK[0], 32, 0); FillChar(LU[0], 32, 0);
    LK[0] := 9; LU[0] := 9;
    for I := 1 to 1000 do begin
      LResult := X25519ScalarMult(LK, LU);
      Move(LK[0], LU[0], 32); Move(LResult[0], LK[0], 32);
    end;
    CheckEqual('684cf59ba83309552800ef566f2f4d3c1c3887c49360e3875f2eb94d99532c51', BytesToHex(LK));
  end);

  LSuite.Test('Try API', procedure
  var LPriv, LPub, LResult: TBytes; LError: string; LOk: Boolean;
  begin
    LOk := TryGenerateX25519KeyPair(LPriv, LPub, LError);
    CheckTrue(LOk); CheckEqual(32, Length(LPriv)); CheckEqual(32, Length(LPub));
    LOk := TryX25519ComputeSharedSecret(LPriv, LPub, LResult, LError);
    CheckTrue(LOk); CheckEqual(32, Length(LResult));
    LOk := TryX25519ScalarMult(HexToBytes('0102'), LPub, LResult, LError);
    CheckTrue(not LOk); CheckTrue(Length(LError) > 0);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.x25519');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
