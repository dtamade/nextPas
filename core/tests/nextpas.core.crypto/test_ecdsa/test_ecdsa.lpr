program test_ecdsa;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.crypto.ecdsa,
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
  LRunner: TTestRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ecdsa');

  LSuite.Test('base point mult G*1=G', procedure
  var LScalar: TBytes; LPoint: TECPoint; LError: string; LOk: Boolean;
  begin
    LScalar := HexToBytes('0000000000000000000000000000000000000000000000000000000000000001');
    LOk := TryP256ScalarMultBase(LScalar, LPoint, LError);
    CheckTrue(LOk);
    CheckEqual('6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296', BytesToHex(LPoint.X));
    CheckEqual('4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5', BytesToHex(LPoint.Y));
  end);

  LSuite.Test('scalar mult base 2G', procedure
  var LScalar: TBytes; LPoint: TECPoint; LError: string; LOk: Boolean;
  begin
    LScalar := HexToBytes('0000000000000000000000000000000000000000000000000000000000000002');
    LOk := TryP256ScalarMultBase(LScalar, LPoint, LError);
    CheckTrue(LOk);
    CheckEqual('7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978', BytesToHex(LPoint.X));
    CheckEqual('07775510db8ed040293d9ac69f7430dbba7dade63ce982299e04b79d227873d1', BytesToHex(LPoint.Y));
  end);

  LSuite.Test('sign/verify roundtrip', procedure
  var LPrivKey, LMsgHash, LSig, LPubBytes: TBytes;
    LPubPoint: TECPoint; LError: string; LOk: Boolean;
  begin
    LPrivKey := HexToBytes('c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
    LMsgHash := HexToBytes('af2bdbe1aa9b6ec1e2ade1d694f41fc71a831d0268e9891562113d8a62add1bf');
    LOk := TryP256ScalarMultBase(LPrivKey, LPubPoint, LError);
    CheckTrue(LOk);
    LOk := TryECDSASignP256SHA256(LMsgHash, LPrivKey, LSig, LError);
    CheckTrue(LOk);
    CheckTrue((Length(LSig) > 0) and (LSig[0] = $30));
    SetLength(LPubBytes, 65); LPubBytes[0] := $04;
    Move(LPubPoint.X[0], LPubBytes[1], 32);
    Move(LPubPoint.Y[0], LPubBytes[33], 32);
    LOk := TryECDSAVerifyP256SHA256(LMsgHash, LPubBytes, LSig, LError);
    CheckTrue(LOk);
  end);

  LSuite.Test('tampered sig rejected', procedure
  var LPrivKey, LMsgHash, LSig, LPubBytes: TBytes;
    LPubPoint: TECPoint; LError: string; LOk: Boolean;
  begin
    LPrivKey := HexToBytes('c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
    LMsgHash := HexToBytes('af2bdbe1aa9b6ec1e2ade1d694f41fc71a831d0268e9891562113d8a62add1bf');
    TryP256ScalarMultBase(LPrivKey, LPubPoint, LError);
    TryECDSASignP256SHA256(LMsgHash, LPrivKey, LSig, LError);
    if Length(LSig) > 5 then LSig[5] := LSig[5] xor $FF;
    SetLength(LPubBytes, 65); LPubBytes[0] := $04;
    Move(LPubPoint.X[0], LPubBytes[1], 32);
    Move(LPubPoint.Y[0], LPubBytes[33], 32);
    LOk := TryECDSAVerifyP256SHA256(LMsgHash, LPubBytes, LSig, LError);
    CheckTrue(not LOk);
  end);

  LSuite.Test('point validation', procedure
  var LPoint: TECPoint; LError: string; LOk: Boolean;
  begin
    LPoint.X := HexToBytes('6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296');
    LPoint.Y := HexToBytes('4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5');
    LPoint.IsInfinity := False;
    LOk := TryValidateP256Point(LPoint, LError);
    CheckTrue(LOk);
    LPoint.X := HexToBytes('0000000000000000000000000000000000000000000000000000000000000001');
    LPoint.Y := HexToBytes('0000000000000000000000000000000000000000000000000000000000000001');
    LOk := TryValidateP256Point(LPoint, LError);
    CheckTrue(not LOk);
  end);

  LSuite.Test('parse uncompressed point', procedure
  var LPubBytes: TBytes; LPoint: TECPoint; LError: string; LOk: Boolean;
  begin
    LPubBytes := HexToBytes('046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2964fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5');
    LOk := TryParseP256PublicPoint(LPubBytes, LPoint, LError);
    CheckTrue(LOk);
    CheckEqual('6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296', BytesToHex(LPoint.X));
    CheckEqual('4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5', BytesToHex(LPoint.Y));
  end);

  LRunner := TTestRunner.Create('nextpas.core.crypto.ecdsa');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
