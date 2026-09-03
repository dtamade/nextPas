program test_p384;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.p384,
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
  LSuite := TTestSuite.Create('p384');

  LSuite.Test('scalar mult base 1*G=G', procedure
  var LScalar: TBytes; LPoint: TP384Point; LError: string; LOk: Boolean;
  begin
    LScalar := HexToBytes('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001');
    LOk := TryP384ScalarMultBase(LScalar, LPoint, LError);
    CheckTrue(LOk);
    CheckEqual('aa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a385502f25dbf55296c3a545e3872760ab7', BytesToHex(LPoint.X));
    CheckEqual('3617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c00a60b1ce1d7e819d7a431d7c90ea0e5f', BytesToHex(LPoint.Y));
  end);

  LSuite.Test('ECDHE key pair', procedure
  var LPriv, LPub: TBytes; LError: string; LOk: Boolean;
  begin
    LOk := TryP384ECDHEKeyPair(LPriv, LPub, LError);
    CheckTrue(LOk);
    CheckEqual(48, Length(LPriv));
    CheckEqual(97, Length(LPub));
    CheckTrue(LPub[0] = $04);
  end);

  LSuite.Test('ECDHE roundtrip', procedure
  var LPrivA, LPubA, LPrivB, LPubB, LSharedAB, LSharedBA: TBytes;
    LError: string; LOk: Boolean;
  begin
    LOk := TryP384ECDHEKeyPair(LPrivA, LPubA, LError);
    CheckTrue(LOk);
    LOk := TryP384ECDHEKeyPair(LPrivB, LPubB, LError);
    CheckTrue(LOk);
    LOk := TryP384ECDHE(LPrivA, LPubB, LSharedAB, LError);
    CheckTrue(LOk);
    LOk := TryP384ECDHE(LPrivB, LPubA, LSharedBA, LError);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LSharedAB), BytesToHex(LSharedBA));
    CheckEqual(48, Length(LSharedAB));
  end);

  LSuite.Test('validate public key', procedure
  var LPriv, LPub, LBadPub: TBytes; LError: string; LOk: Boolean;
  begin
    TryP384ECDHEKeyPair(LPriv, LPub, LError);
    LOk := TryP384ValidatePublicKey(LPub, LError);
    CheckTrue(LOk);
    SetLength(LBadPub, 10);
    LOk := TryP384ValidatePublicKey(LBadPub, LError);
    CheckTrue(not LOk);
    SetLength(LBadPub, 97); LBadPub[0] := $04; FillChar(LBadPub[1], 96, $AA);
    LOk := TryP384ValidatePublicKey(LBadPub, LError);
    CheckTrue(not LOk);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.p384');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
