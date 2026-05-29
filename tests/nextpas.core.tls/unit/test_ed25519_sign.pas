program test_ed25519_sign;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.crypto.ed25519;

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
var I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const B: TBytes): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(B) do
    Result := Result + LowerCase(IntToHex(B[I], 2));
end;

procedure TestPublicKeyDerivation;
var
  LPriv, LPub: TBytes;
begin
  WriteLn('TestPublicKeyDerivation');
  // RFC 8032 Test Vector 1
  LPriv := HexToBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  Check(Length(LPub) = 32, 'Public key is 32 bytes');
  Check(BytesToHex(LPub) = 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
    'RFC 8032 vector 1 public key derivation');
end;

procedure TestPublicKeyDerivationVector2;
var
  LPriv, LPub: TBytes;
begin
  WriteLn('TestPublicKeyDerivationVector2');
  // RFC 8032 Test Vector 2
  LPriv := HexToBytes('4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb');
  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  Check(BytesToHex(LPub) = '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
    'RFC 8032 vector 2 public key derivation');
end;

procedure TestSignVerifyRoundtrip;
var
  LPriv, LPub, LMsg, LSig: TBytes;
begin
  WriteLn('TestSignVerifyRoundtrip');
  LPriv := HexToBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  SetLength(LMsg, 5);
  LMsg[0] := Ord('h'); LMsg[1] := Ord('e'); LMsg[2] := Ord('l');
  LMsg[3] := Ord('l'); LMsg[4] := Ord('o');

  Check(Ed25519Sign(LPriv, LMsg, LSig), 'Sign succeeds');
  Check(Length(LSig) = 64, 'Signature is 64 bytes');
  Check(Ed25519Verify(LPub, LMsg, LSig), 'Verify own signature');
end;

procedure TestRFC8032Vector1Sign;
var
  LPriv, LPub, LMsg, LSig: TBytes;
begin
  WriteLn('TestRFC8032Vector1Sign');
  LPriv := HexToBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  SetLength(LMsg, 0); // empty message

  Check(Ed25519Sign(LPriv, LMsg, LSig), 'Sign empty message');
  Check(BytesToHex(LSig) =
    'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06' +
    '5224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
    'RFC 8032 vector 1 signature matches');
  Check(Ed25519Verify(LPub, LMsg, LSig), 'RFC 8032 vector 1 verify');
end;

procedure TestRFC8032Vector2Sign;
var
  LPriv, LPub, LMsg, LSig: TBytes;
begin
  WriteLn('TestRFC8032Vector2Sign');
  LPriv := HexToBytes('4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb');
  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  LMsg := TBytes.Create($72); // single byte 0x72

  Check(Ed25519Sign(LPriv, LMsg, LSig), 'Sign single byte');
  Check(BytesToHex(LSig) =
    '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da' +
    '085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
    'RFC 8032 vector 2 signature matches');
  Check(Ed25519Verify(LPub, LMsg, LSig), 'RFC 8032 vector 2 verify');
end;

procedure TestTamperedSignatureRejected;
var
  LPriv, LPub, LMsg, LSig: TBytes;
begin
  WriteLn('TestTamperedSignatureRejected');
  LPriv := HexToBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  LMsg := TBytes.Create($41, $42, $43);
  Ed25519Sign(LPriv, LMsg, LSig);
  LSig[10] := LSig[10] xor $FF;
  Check(not Ed25519Verify(LPub, LMsg, LSig), 'Tampered signature rejected');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestPublicKeyDerivation;
  TestPublicKeyDerivationVector2;
  TestSignVerifyRoundtrip;
  TestRFC8032Vector1Sign;
  TestRFC8032Vector2Sign;
  TestTamperedSignatureRejected;

  WriteLn;
  WriteLn('Ed25519 Sign tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
