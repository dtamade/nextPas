program test_ecdsa;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.ecdsa;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestBasePointMult;
var
  LScalar: TBytes;
  LPoint: TECPoint;
  LError: string;
  LOk: Boolean;
begin
  // G * 1 = G (basepoint)
  LScalar := HexToBytes('0000000000000000000000000000000000000000000000000000000000000001');
  LOk := TryP256ScalarMultBase(LScalar, LPoint, LError);
  Check('ScalarMultBase(1) ok', LOk);
  if LOk then
  begin
    Check('ScalarMultBase(1) = Gx',
      BytesToHex(LPoint.X) = '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296');
    Check('ScalarMultBase(1) = Gy',
      BytesToHex(LPoint.Y) = '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5');
  end;
end;

procedure TestScalarMultBase_Known;
var
  LScalar: TBytes;
  LPoint: TECPoint;
  LError: string;
  LOk: Boolean;
begin
  // NIST P-256: scalar = 2, result = 2*G
  LScalar := HexToBytes('0000000000000000000000000000000000000000000000000000000000000002');
  LOk := TryP256ScalarMultBase(LScalar, LPoint, LError);
  Check('ScalarMultBase(2) ok', LOk);
  if LOk then
  begin
    Check('ScalarMultBase(2) = 2G.x',
      BytesToHex(LPoint.X) = '7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978');
    Check('ScalarMultBase(2) = 2G.y',
      BytesToHex(LPoint.Y) = '07775510db8ed040293d9ac69f7430dbba7dade63ce982299e04b79d227873d1');
  end;
end;

procedure TestSignVerifyRoundtrip;
var
  LPrivKey, LMsgHash, LSig, LPubBytes: TBytes;
  LPubPoint: TECPoint;
  LError: string;
  LOk: Boolean;
begin
  // Use a known private key
  LPrivKey := HexToBytes('c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
  LMsgHash := HexToBytes('af2bdbe1aa9b6ec1e2ade1d694f41fc71a831d0268e9891562113d8a62add1bf');

  LOk := TryP256ScalarMultBase(LPrivKey, LPubPoint, LError);
  Check('sign/verify: derive pubkey ok', LOk);
  if not LOk then Exit;

  LOk := TryECDSASignP256SHA256(LMsgHash, LPrivKey, LSig, LError);
  Check('sign/verify: sign ok', LOk);
  if not LOk then begin WriteLn('    Error: ', LError); Exit; end;

  Check('sign/verify: sig is DER', (Length(LSig) > 0) and (LSig[0] = $30));

  // Encode public key as uncompressed point (04 || X || Y)
  SetLength(LPubBytes, 65);
  LPubBytes[0] := $04;
  Move(LPubPoint.X[0], LPubBytes[1], 32);
  Move(LPubPoint.Y[0], LPubBytes[33], 32);

  LOk := TryECDSAVerifyP256SHA256(LMsgHash, LPubBytes, LSig, LError);
  Check('sign/verify: verify ok', LOk);
end;

procedure TestVerifyRejectTampered;
var
  LPrivKey, LMsgHash, LSig: TBytes;
  LPubPoint: TECPoint;
  LPubBytes: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LPrivKey := HexToBytes('c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721');
  LMsgHash := HexToBytes('af2bdbe1aa9b6ec1e2ade1d694f41fc71a831d0268e9891562113d8a62add1bf');

  TryP256ScalarMultBase(LPrivKey, LPubPoint, LError);
  TryECDSASignP256SHA256(LMsgHash, LPrivKey, LSig, LError);

  // Tamper with signature
  if Length(LSig) > 5 then
    LSig[5] := LSig[5] xor $FF;

  SetLength(LPubBytes, 65);
  LPubBytes[0] := $04;
  Move(LPubPoint.X[0], LPubBytes[1], 32);
  Move(LPubPoint.Y[0], LPubBytes[33], 32);

  LOk := TryECDSAVerifyP256SHA256(LMsgHash, LPubBytes, LSig, LError);
  Check('tampered sig rejected', not LOk);
end;

procedure TestPointValidation;
var
  LPoint: TECPoint;
  LError: string;
  LOk: Boolean;
begin
  // Valid point (basepoint)
  LPoint.X := HexToBytes('6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296');
  LPoint.Y := HexToBytes('4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5');
  LPoint.IsInfinity := False;
  LOk := TryValidateP256Point(LPoint, LError);
  Check('validate: basepoint is valid', LOk);

  // Invalid point (random bytes)
  LPoint.X := HexToBytes('0000000000000000000000000000000000000000000000000000000000000001');
  LPoint.Y := HexToBytes('0000000000000000000000000000000000000000000000000000000000000001');
  LOk := TryValidateP256Point(LPoint, LError);
  Check('validate: (1,1) is invalid', not LOk);
end;

procedure TestParseUncompressedPoint;
var
  LPubBytes: TBytes;
  LPoint: TECPoint;
  LError: string;
  LOk: Boolean;
begin
  // 04 || Gx || Gy
  LPubBytes := HexToBytes(
    '04' +
    '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296' +
    '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5');
  LOk := TryParseP256PublicPoint(LPubBytes, LPoint, LError);
  Check('parse uncompressed point ok', LOk);
  if LOk then
  begin
    Check('parse: X matches', BytesToHex(LPoint.X) = '6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296');
    Check('parse: Y matches', BytesToHex(LPoint.Y) = '4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5');
  end;
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== ECDSA P-256 Tests ===');
  WriteLn;

  TestBasePointMult;
  TestScalarMultBase_Known;
  TestSignVerifyRoundtrip;
  TestVerifyRejectTampered;
  TestPointValidation;
  TestParseUncompressedPoint;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
