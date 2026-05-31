program test_ed25519_certverify;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.tls13.servercertverify, nextpas.core.tls.x509;

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

procedure TestEd25519WrongKeyType;
var
  LPubKeyInfo: TX509PublicKeyInfo;
  LInput, LSig: TBytes;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestEd25519WrongKeyType');
  FillChar(LPubKeyInfo, SizeOf(LPubKeyInfo), 0);
  LPubKeyInfo.KeyType := 'RSA';
  SetLength(LPubKeyInfo.PublicKey, 32);
  SetLength(LInput, 64);
  SetLength(LSig, 64);
  LError := '';
  LOk := TryVerifyTLS13CertificateVerifySignature($0807, LPubKeyInfo, LInput, LSig, LError);
  Check(not LOk, 'Wrong key type rejected');
  Check(Pos('key type', LowerCase(LError)) > 0, 'Error mentions key type');
end;

procedure TestEd25519WrongKeyLength;
var
  LPubKeyInfo: TX509PublicKeyInfo;
  LInput, LSig: TBytes;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestEd25519WrongKeyLength');
  FillChar(LPubKeyInfo, SizeOf(LPubKeyInfo), 0);
  LPubKeyInfo.KeyType := 'Ed25519';
  SetLength(LPubKeyInfo.PublicKey, 16);
  SetLength(LInput, 64);
  SetLength(LSig, 64);
  LError := '';
  LOk := TryVerifyTLS13CertificateVerifySignature($0807, LPubKeyInfo, LInput, LSig, LError);
  Check(not LOk, 'Wrong key length rejected');
  Check(Pos('length', LowerCase(LError)) > 0, 'Error mentions length');
end;

procedure TestEd25519InvalidSignature;
var
  LPubKeyInfo: TX509PublicKeyInfo;
  LInput, LSig: TBytes;
  LError: string;
  LOk: Boolean;
begin
  WriteLn('TestEd25519InvalidSignature');
  FillChar(LPubKeyInfo, SizeOf(LPubKeyInfo), 0);
  LPubKeyInfo.KeyType := 'Ed25519';
  SetLength(LPubKeyInfo.PublicKey, 32);
  FillChar(LPubKeyInfo.PublicKey[0], 32, $42);
  SetLength(LInput, 100);
  FillChar(LInput[0], 100, $AA);
  SetLength(LSig, 64);
  FillChar(LSig[0], 64, $BB);
  LError := '';
  LOk := TryVerifyTLS13CertificateVerifySignature($0807, LPubKeyInfo, LInput, LSig, LError);
  Check(not LOk, 'Invalid signature rejected');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestEd25519WrongKeyType;
  TestEd25519WrongKeyLength;
  TestEd25519InvalidSignature;

  WriteLn;
  WriteLn('Ed25519 CertVerify tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
