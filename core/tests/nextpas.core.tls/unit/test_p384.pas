program test_p384;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.crypto.p384;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
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

procedure TestScalarMultBase;
var
  LScalar: TBytes;
  LResult: TP384Point;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestScalarMultBase');
  LScalar := HexToBytes('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001');
  LOk := TryP384ScalarMultBase(LScalar, LResult, LError);
  Check(LOk, 'ScalarMultBase(1) succeeds: ' + LError);
  Check(Length(LResult.X) > 0, 'Result X not empty');
  Check(Length(LResult.Y) > 0, 'Result Y not empty');
end;

procedure TestECDHEKeyPair;
var
  LPriv, LPub: TBytes;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestECDHEKeyPair');
  LOk := TryP384ECDHEKeyPair(LPriv, LPub, LError);
  Check(LOk, 'Key pair generation: ' + LError);
  Check(Length(LPriv) = 48, 'Private key 48 bytes');
  Check(Length(LPub) = 97, 'Public key 97 bytes (04 || X || Y)');
  Check(LPub[0] = $04, 'Public key starts with 04');
end;

procedure TestECDHESharedSecret;
var
  LPrivA, LPubA, LPrivB, LPubB: TBytes;
  LSecretA, LSecretB: TBytes;
  LError: string;
  LOk: Boolean;
  I: Integer;
  LMatch: Boolean;
begin
  WriteLn('TestECDHESharedSecret');
  LOk := TryP384ECDHEKeyPair(LPrivA, LPubA, LError);
  Check(LOk, 'KeyPair A: ' + LError);
  LOk := TryP384ECDHEKeyPair(LPrivB, LPubB, LError);
  Check(LOk, 'KeyPair B: ' + LError);

  LOk := TryP384ECDHE(LPrivA, LPubB, LSecretA, LError);
  Check(LOk, 'ECDHE A*B: ' + LError);
  LOk := TryP384ECDHE(LPrivB, LPubA, LSecretB, LError);
  Check(LOk, 'ECDHE B*A: ' + LError);

  Check(Length(LSecretA) = 48, 'Shared secret A = 48 bytes');
  Check(Length(LSecretB) = 48, 'Shared secret B = 48 bytes');

  LMatch := True;
  for I := 0 to 47 do
    if LSecretA[I] <> LSecretB[I] then
    begin
      LMatch := False;
      Break;
    end;
  Check(LMatch, 'Shared secrets match (ECDH commutativity)');
end;

procedure TestECDHEInvalidPubKey;
var
  LPriv, LPub, LSecret: TBytes;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestECDHEInvalidPubKey');
  TryP384ECDHEKeyPair(LPriv, LPub, LError);
  SetLength(LPub, 50);
  LOk := TryP384ECDHE(LPriv, LPub, LSecret, LError);
  Check(not LOk, 'Invalid pubkey rejected');
  Check(Pos('Invalid', LError) > 0, 'Error mentions invalid');
end;

procedure TestScalarZero;
var
  LScalar: TBytes;
  LResult: TP384Point;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestScalarZero');
  SetLength(LScalar, 48);
  FillChar(LScalar[0], 48, 0);
  LOk := TryP384ScalarMultBase(LScalar, LResult, LError);
  Check(not LOk, 'Scalar zero rejected');
  Check(Pos('zero', LError) > 0, 'Error mentions zero');
end;

procedure TestECDSAVerifyInvalidSig;
var
  LHash, LSig: TBytes;
  LPub: TP384Point;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestECDSAVerifyInvalidSig');
  SetLength(LHash, 48);
  FillChar(LHash[0], 48, $AA);

  SetLength(LSig, 3);
  LPub.X := HexToBytes('AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7');
  LPub.Y := HexToBytes('3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F');
  LOk := TryP384ECDSAVerify(LHash, LSig, LPub, LError);
  Check(not LOk, 'Too short signature rejected');
  Check(Pos('too short', LowerCase(LError)) > 0, 'Error mentions too short');
end;

procedure TestECDSAVerifyWrongSig;
var
  LHash, LSig: TBytes;
  LPub: TP384Point;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestECDSAVerifyWrongSig');
  SetLength(LHash, 48);
  FillChar(LHash[0], 48, $BB);

  SetLength(LSig, 96);
  FillChar(LSig[0], 48, $01);
  FillChar(LSig[48], 48, $02);

  LPub.X := HexToBytes('AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7');
  LPub.Y := HexToBytes('3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F');
  LOk := TryP384ECDSAVerify(LHash, LSig, LPub, LError);
  Check(not LOk, 'Wrong signature rejected');
end;

procedure TestECDSAVerifyDERNotSupported;
var
  LHash, LSig: TBytes;
  LPub: TP384Point;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestECDSAVerifyDERNotSupported');
  SetLength(LHash, 48);
  FillChar(LHash[0], 48, $CC);

  SetLength(LSig, 70);
  LSig[0] := $30; LSig[1] := $44;

  LPub.X := HexToBytes('AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7');
  LPub.Y := HexToBytes('3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F');
  LOk := TryP384ECDSAVerify(LHash, LSig, LPub, LError);
  Check(not LOk, 'DER format not accepted by raw verify');
  Check(Pos('der', LowerCase(LError)) > 0, 'Error mentions DER');
end;

begin
  
  LTotal := 0;
  LPassed := 0;

  TestScalarMultBase;
  TestECDHEKeyPair;
  TestECDHESharedSecret;
  TestECDHEInvalidPubKey;
  TestScalarZero;
  TestECDSAVerifyInvalidSig;
  TestECDSAVerifyWrongSig;
  TestECDSAVerifyDERNotSupported;

  WriteLn;
  WriteLn('P-384 tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
