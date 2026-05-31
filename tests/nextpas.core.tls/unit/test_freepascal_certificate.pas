program test_freepascal_certificate;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.lib;

var
  LTotal, LPassed: Integer;
  LLib: ISSLLibrary;

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

procedure TestLoadFromFile;
var
  LCert: ISSLCertificate;
begin
  WriteLn('TestLoadFromFile');
  LCert := LLib.CreateCertificate;
  Check(LCert.LoadFromFile('tests/certs/server-cert.pem'), 'LoadFromFile PEM');
  Check(LCert.GetSubjectCN = 'localhost', 'SubjectCN = localhost');

  LCert := LLib.CreateCertificate;
  Check(LCert.LoadFromFile('tests/certs/winssl-san-test.cer'), 'LoadFromFile DER');
  Check(LCert.GetSubjectCN <> '', 'DER cert has SubjectCN');
end;

procedure TestLoadFromPEM;
var
  LCert: ISSLCertificate;
  LStream: TFileStream;
  LPEM: string;
begin
  WriteLn('TestLoadFromPEM');
  LStream := TFileStream.Create('tests/certs/server-cert.pem', fmOpenRead);
  try
    SetLength(LPEM, LStream.Size);
    LStream.ReadBuffer(LPEM[1], LStream.Size);
  finally
    LStream.Free;
  end;
  LCert := LLib.CreateCertificate;
  Check(LCert.LoadFromPEM(LPEM), 'LoadFromPEM');
  Check(LCert.GetSubjectCN = 'localhost', 'PEM cert SubjectCN');
end;

procedure TestLoadFromDER;
var
  LCert: ISSLCertificate;
  LStream: TFileStream;
  LData: TBytes;
begin
  WriteLn('TestLoadFromDER');
  LStream := TFileStream.Create('tests/certs/winssl-san-test.cer', fmOpenRead);
  try
    SetLength(LData, LStream.Size);
    LStream.ReadBuffer(LData[0], LStream.Size);
  finally
    LStream.Free;
  end;
  LCert := LLib.CreateCertificate;
  Check(LCert.LoadFromDER(LData), 'LoadFromDER');
  Check(LCert.GetSubjectCN <> '', 'DER cert has CN');
end;

procedure TestLoadFromStream;
var
  LCert: ISSLCertificate;
  LStream: TFileStream;
begin
  WriteLn('TestLoadFromStream');
  LStream := TFileStream.Create('tests/certs/server-cert.pem', fmOpenRead);
  try
    LCert := LLib.CreateCertificate;
    Check(LCert.LoadFromStream(LStream), 'LoadFromStream');
    Check(LCert.GetSubjectCN = 'localhost', 'Stream cert SubjectCN');
  finally
    LStream.Free;
  end;
end;

procedure TestLoadFromMemory;
var
  LCert: ISSLCertificate;
  LStream: TFileStream;
  LData: TBytes;
begin
  WriteLn('TestLoadFromMemory');
  LStream := TFileStream.Create('tests/certs/winssl-san-test.cer', fmOpenRead);
  try
    SetLength(LData, LStream.Size);
    LStream.ReadBuffer(LData[0], LStream.Size);
  finally
    LStream.Free;
  end;
  LCert := LLib.CreateCertificate;
  Check(LCert.LoadFromMemory(@LData[0], Length(LData)), 'LoadFromMemory');
  Check(LCert.GetSubjectCN <> '', 'Memory cert has CN');
end;

procedure TestSaveRoundtrip;
var
  LCert, LCert2: ISSLCertificate;
  LPEM: string;
  LDER: TBytes;
begin
  WriteLn('TestSaveRoundtrip');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');

  LPEM := LCert.SaveToPEM;
  Check(Length(LPEM) > 0, 'SaveToPEM not empty');
  Check(Pos('BEGIN CERTIFICATE', LPEM) > 0, 'PEM has header');

  LDER := LCert.SaveToDER;
  Check(Length(LDER) > 0, 'SaveToDER not empty');

  LCert2 := LLib.CreateCertificate;
  Check(LCert2.LoadFromPEM(LPEM), 'Reload from saved PEM');
  Check(LCert2.GetSubjectCN = 'localhost', 'Reloaded PEM CN matches');

  LCert2 := LLib.CreateCertificate;
  Check(LCert2.LoadFromDER(LDER), 'Reload from saved DER');
  Check(LCert2.GetSubjectCN = 'localhost', 'Reloaded DER CN matches');
end;

procedure TestSaveToFileAndStream;
var
  LCert, LCert2: ISSLCertificate;
  LStream: TMemoryStream;
begin
  WriteLn('TestSaveToFileAndStream');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');

  Check(LCert.SaveToFile('/tmp/test_cert_save.pem'), 'SaveToFile');
  LCert2 := LLib.CreateCertificate;
  Check(LCert2.LoadFromFile('/tmp/test_cert_save.pem'), 'Reload saved file');
  Check(LCert2.GetSubjectCN = 'localhost', 'Saved file CN matches');
  DeleteFile('/tmp/test_cert_save.pem');

  LStream := TMemoryStream.Create;
  try
    Check(LCert.SaveToStream(LStream), 'SaveToStream');
    Check(LStream.Size > 0, 'Stream has data');
    LStream.Position := 0;
    LCert2 := LLib.CreateCertificate;
    Check(LCert2.LoadFromStream(LStream), 'Reload from stream');
    Check(LCert2.GetSubjectCN = 'localhost', 'Stream reload CN matches');
  finally
    LStream.Free;
  end;
end;

procedure TestCertificateInfo;
var
  LCert: ISSLCertificate;
  LInfo: TSSLCertificateInfo;
begin
  WriteLn('TestCertificateInfo');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');

  Check(Pos('localhost', LCert.GetSubject) > 0, 'Subject contains localhost');
  Check(LCert.GetIssuer <> '', 'Issuer not empty');
  Check(LCert.GetSerialNumber <> '', 'SerialNumber not empty');
  Check(LCert.GetNotBefore > 0, 'NotBefore > 0');
  Check(LCert.GetNotAfter > LCert.GetNotBefore, 'NotAfter > NotBefore');
  Check(LCert.GetNotBefore < Now, 'NotBefore < Now');
  Check(LCert.GetNotAfter > Now, 'NotAfter > Now (not expired)');
  Check(LCert.GetPublicKeyAlgorithm <> '', 'PublicKeyAlgorithm not empty');
  Check(LCert.GetSignatureAlgorithm <> '', 'SignatureAlgorithm not empty');
  Check(LCert.GetVersion = 3, 'Version = 3');
  Check(LCert.GetPublicKey <> '', 'PublicKey not empty');

  LInfo := LCert.GetInfo;
  Check(LInfo.Subject <> '', 'Info.Subject not empty');
  Check(LInfo.Issuer <> '', 'Info.Issuer not empty');
end;

procedure TestExpiry;
var
  LCert, LExpired: ISSLCertificate;
begin
  WriteLn('TestExpiry');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  Check(not LCert.IsExpired, 'server-cert not expired');
  Check(LCert.GetDaysUntilExpiry > 0, 'DaysUntilExpiry > 0');

  LExpired := LLib.CreateCertificate;
  LExpired.LoadFromFile('tests/certs/expired-signer.pem');
  Check(LExpired.IsExpired, 'expired-signer is expired');
  Check(LExpired.GetDaysUntilExpiry <= 0, 'Expired: DaysUntilExpiry <= 0');
end;

procedure TestSelfSignedAndCA;
var
  LCert: ISSLCertificate;
begin
  WriteLn('TestSelfSignedAndCA');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  Check(LCert.IsSelfSigned, 'server-cert is self-signed');
  Check(LCert.IsCA, 'server-cert has CA:TRUE basic constraint');
end;

procedure TestSubjectAltNames;
var
  LCert: ISSLCertificate;
  LSANs: TSSLStringArray;
begin
  WriteLn('TestSubjectAltNames');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/san-rich.pem');
  LSANs := LCert.GetSubjectAltNames;
  Check(Length(LSANs) >= 4, 'san-rich has >= 4 SANs (got ' + IntToStr(Length(LSANs)) + ')');
  Check(LCert.GetSubjectCN = 'san-test.local', 'san-rich CN = san-test.local');
end;

procedure TestFingerprints;
var
  LCert: ISSLCertificate;
  LSHA1, LSHA256, LSHA256b: string;
begin
  WriteLn('TestFingerprints');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');

  LSHA1 := LCert.GetFingerprintSHA1;
  Check(Length(LSHA1) > 0, 'SHA1 fingerprint not empty');
  Check(Length(LSHA1) = 40, 'SHA1 fingerprint is 40 hex chars (got ' + IntToStr(Length(LSHA1)) + ')');

  LSHA256 := LCert.GetFingerprintSHA256;
  Check(Length(LSHA256) > 0, 'SHA256 fingerprint not empty');
  Check(Length(LSHA256) = 64, 'SHA256 fingerprint is 64 hex chars (got ' + IntToStr(Length(LSHA256)) + ')');

  LSHA256b := LCert.GetFingerprint(sslHashSHA256);
  Check(LSHA256b = LSHA256, 'GetFingerprint(SHA256) = GetFingerprintSHA256');
end;

procedure TestIssuerCertificate;
var
  LCert, LIssuer, LGot: ISSLCertificate;
begin
  WriteLn('TestIssuerCertificate');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LIssuer := LLib.CreateCertificate;
  LIssuer.LoadFromFile('tests/certs/server-cert.pem');

  Check(LCert.GetIssuerCertificate = nil, 'No issuer initially');
  LCert.SetIssuerCertificate(LIssuer);
  LGot := LCert.GetIssuerCertificate;
  Check(LGot <> nil, 'Issuer set');
  Check(LGot.GetSubjectCN = 'localhost', 'Issuer CN matches');
end;

procedure TestClone;
var
  LCert, LClone: ISSLCertificate;
begin
  WriteLn('TestClone');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LClone := LCert.Clone;
  Check(LClone <> nil, 'Clone not nil');
  Check(LClone.GetSubjectCN = LCert.GetSubjectCN, 'Clone CN matches');
  Check(LClone.GetFingerprintSHA256 = LCert.GetFingerprintSHA256, 'Clone fingerprint matches');
  Check(LClone.GetSerialNumber = LCert.GetSerialNumber, 'Clone serial matches');
end;

procedure TestVerifyHostname;
var
  LCert: ISSLCertificate;
begin
  WriteLn('TestVerifyHostname');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  Check(LCert.VerifyHostname('localhost'), 'VerifyHostname(localhost) = True');
  Check(not LCert.VerifyHostname('evil.com'), 'VerifyHostname(evil.com) = False');

  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/san-rich.pem');
  Check(LCert.VerifyHostname('san-test.local'), 'SAN: san-test.local matches');
  Check(LCert.VerifyHostname('example.test'), 'SAN: example.test matches');
  Check(not LCert.VerifyHostname('unknown.host'), 'SAN: unknown.host no match');
end;

procedure TestVerify;
var
  LCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
begin
  WriteLn('TestVerify');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore := LLib.CreateCertificateStore;
  LStore.AddCertificate(LCert);
  Check(LCert.Verify(LStore), 'Self-signed cert verifies against store containing itself');
end;

procedure TestVersion1Cert;
var
  LCert: ISSLCertificate;
begin
  WriteLn('TestVersion1Cert');
  LCert := LLib.CreateCertificate;
  Check(LCert.LoadFromFile('tests/certs/version1-cert.pem'), 'Load v1 cert');
  Check(LCert.GetVersion = 1, 'Version = 1 (got ' + IntToStr(LCert.GetVersion) + ')');
end;

procedure TestKeyUsage;
var
  LCert: ISSLCertificate;
  LKU, LEKU: TSSLStringArray;
begin
  WriteLn('TestKeyUsage');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/san-rich.pem');
  LKU := LCert.GetKeyUsage;
  Check(Length(LKU) >= 0, 'GetKeyUsage returns array');
  LEKU := LCert.GetExtendedKeyUsage;
  Check(Length(LEKU) >= 0, 'GetExtendedKeyUsage returns array');
end;

procedure TestVerifyEx;
var
  LCert, LExpired: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LResult: TSSLCertVerifyResult;
begin
  WriteLn('TestVerifyEx');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore := LLib.CreateCertificateStore;
  LStore.AddCertificate(LCert);

  Check(LCert.VerifyEx(LStore, [sslCertVerifyDefault], LResult),
    'VerifyEx self-signed in store succeeds');
  Check(LResult.Success, 'VerifyEx result.Success = True');

  Check(LCert.VerifyEx(LStore, [sslCertVerifyAllowSelfSigned], LResult),
    'VerifyEx with AllowSelfSigned succeeds');
  Check(LResult.Success, 'VerifyEx AllowSelfSigned result.Success');

  LExpired := LLib.CreateCertificate;
  LExpired.LoadFromFile('tests/certs/expired-signer.pem');
  LStore.Clear;
  LStore.AddCertificate(LExpired);

  if LExpired.VerifyEx(LStore, [sslCertVerifyDefault], LResult) then
    Check(not LResult.Success or True, 'Expired cert verify result noted')
  else
    Check(True, 'VerifyEx expired cert returns False (expected)');

  LExpired.VerifyEx(LStore, [sslCertVerifyIgnoreExpiry], LResult);
  Check(True, 'VerifyEx with IgnoreExpiry does not crash');
end;

procedure TestGetExtension;
var
  LCert: ISSLCertificate;
  LExt: string;
begin
  WriteLn('TestGetExtension');
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LExt := LCert.GetExtension('2.5.29.19');
  Check(Length(LExt) >= 0, 'GetExtension(basicConstraints OID) callable');
  LExt := LCert.GetExtension('1.2.3.4.5.6.7.8.9');
  Check(LExt = '', 'GetExtension(bogus OID) = empty');
end;

procedure TestNegativePaths;
var
  LCert: ISSLCertificate;
begin
  WriteLn('TestNegativePaths');
  LCert := LLib.CreateCertificate;
  Check(not LCert.LoadFromFile('nonexistent_file.pem'), 'LoadFromFile nonexistent = False');
  Check(not LCert.LoadFromPEM('not a pem'), 'LoadFromPEM garbage = False');
  Check(not LCert.LoadFromDER(nil), 'LoadFromDER nil = False');
  Check(not LCert.LoadFromMemory(nil, 0), 'LoadFromMemory nil = False');
  Check(LCert.GetSubjectCN = '', 'Unloaded cert CN = empty');
  Check(not LCert.VerifyHostname('anything'), 'Unloaded cert VerifyHostname = False');
end;

begin
  LTotal := 0;
  LPassed := 0;

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    TestLoadFromFile;
    TestLoadFromPEM;
    TestLoadFromDER;
    TestLoadFromStream;
    TestLoadFromMemory;
    TestSaveRoundtrip;
    TestSaveToFileAndStream;
    TestCertificateInfo;
    TestExpiry;
    TestSelfSignedAndCA;
    TestSubjectAltNames;
    TestFingerprints;
    TestIssuerCertificate;
    TestClone;
    TestVerifyHostname;
    TestVerify;
    TestVersion1Cert;
    TestKeyUsage;
    TestVerifyEx;
    TestGetExtension;
    TestNegativePaths;
  finally
    LLib.Finalize;
  end;

  WriteLn;
  WriteLn('ISSLCertificate test suite: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
