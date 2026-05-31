program test_freepascal_certstore;

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

procedure TestAddRemoveClear;
var
  LStore: ISSLCertificateStore;
  LCert1, LCert2: ISSLCertificate;
begin
  WriteLn('TestAddRemoveClear');
  LStore := LLib.CreateCertificateStore;
  Check(LStore.GetCount = 0, 'Empty store count = 0');

  LCert1 := LLib.CreateCertificate;
  LCert1.LoadFromFile('tests/certs/server-cert.pem');
  Check(LStore.AddCertificate(LCert1), 'Add cert1');
  Check(LStore.GetCount = 1, 'Count = 1 after add');

  LCert2 := LLib.CreateCertificate;
  LCert2.LoadFromFile('tests/certs/san-rich.pem');
  Check(LStore.AddCertificate(LCert2), 'Add cert2');
  Check(LStore.GetCount = 2, 'Count = 2 after second add');

  Check(LStore.RemoveCertificate(LCert1), 'Remove cert1');
  Check(LStore.GetCount = 1, 'Count = 1 after remove');

  LStore.Clear;
  Check(LStore.GetCount = 0, 'Count = 0 after clear');
end;

procedure TestContains;
var
  LStore: ISSLCertificateStore;
  LCert1, LCert2: ISSLCertificate;
begin
  WriteLn('TestContains');
  LStore := LLib.CreateCertificateStore;
  LCert1 := LLib.CreateCertificate;
  LCert1.LoadFromFile('tests/certs/server-cert.pem');
  LCert2 := LLib.CreateCertificate;
  LCert2.LoadFromFile('tests/certs/san-rich.pem');

  LStore.AddCertificate(LCert1);
  Check(LStore.Contains(LCert1), 'Contains cert1 = True');
  Check(not LStore.Contains(LCert2), 'Contains cert2 = False');
end;

procedure TestGetCertificate;
var
  LStore: ISSLCertificateStore;
  LCert, LGot: ISSLCertificate;
begin
  WriteLn('TestGetCertificate');
  LStore := LLib.CreateCertificateStore;
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore.AddCertificate(LCert);

  LGot := LStore.GetCertificate(0);
  Check(LGot <> nil, 'GetCertificate(0) not nil');
  Check(LGot.GetSubjectCN = 'localhost', 'GetCertificate(0) CN = localhost');
end;

procedure TestDeduplication;
var
  LStore: ISSLCertificateStore;
  LCert1, LCert2: ISSLCertificate;
begin
  WriteLn('TestDeduplication');
  LStore := LLib.CreateCertificateStore;
  LCert1 := LLib.CreateCertificate;
  LCert1.LoadFromFile('tests/certs/server-cert.pem');
  LCert2 := LLib.CreateCertificate;
  LCert2.LoadFromFile('tests/certs/server-cert.pem');

  LStore.AddCertificate(LCert1);
  LStore.AddCertificate(LCert2);
  Check(LStore.GetCount = 1, 'Duplicate add does not increase count (got ' + IntToStr(LStore.GetCount) + ')');
end;

procedure TestLoadFromFile;
var
  LStore: ISSLCertificateStore;
begin
  WriteLn('TestLoadFromFile');
  LStore := LLib.CreateCertificateStore;
  Check(LStore.LoadFromFile('tests/certs/server-cert.pem'), 'LoadFromFile');
  Check(LStore.GetCount >= 1, 'Store has >= 1 cert after LoadFromFile');
end;

procedure TestFindBySubject;
var
  LStore: ISSLCertificateStore;
  LCert, LFound: ISSLCertificate;
begin
  WriteLn('TestFindBySubject');
  LStore := LLib.CreateCertificateStore;
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore.AddCertificate(LCert);

  LFound := LStore.FindBySubject('localhost');
  Check(LFound <> nil, 'FindBySubject(localhost) found');
  Check(LFound.GetSubjectCN = 'localhost', 'Found cert CN = localhost');

  LFound := LStore.FindBySubject('nonexistent');
  Check(LFound = nil, 'FindBySubject(nonexistent) = nil');
end;

procedure TestFindByIssuer;
var
  LStore: ISSLCertificateStore;
  LCert, LFound: ISSLCertificate;
begin
  WriteLn('TestFindByIssuer');
  LStore := LLib.CreateCertificateStore;
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore.AddCertificate(LCert);

  LFound := LStore.FindByIssuer('localhost');
  Check(LFound <> nil, 'FindByIssuer(localhost) found (self-signed)');
end;

procedure TestFindBySerialNumber;
var
  LStore: ISSLCertificateStore;
  LCert, LFound: ISSLCertificate;
  LSerial: string;
begin
  WriteLn('TestFindBySerialNumber');
  LStore := LLib.CreateCertificateStore;
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore.AddCertificate(LCert);
  LSerial := LCert.GetSerialNumber;

  LFound := LStore.FindBySerialNumber(LSerial);
  Check(LFound <> nil, 'FindBySerialNumber found');
  Check(LFound.GetSerialNumber = LSerial, 'Serial matches');

  LFound := LStore.FindBySerialNumber('DEADBEEF');
  Check(LFound = nil, 'FindBySerialNumber(bogus) = nil');
end;

procedure TestFindByFingerprint;
var
  LStore: ISSLCertificateStore;
  LCert, LFound: ISSLCertificate;
  LFP: string;
begin
  WriteLn('TestFindByFingerprint');
  LStore := LLib.CreateCertificateStore;
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore.AddCertificate(LCert);
  LFP := LCert.GetFingerprintSHA256;

  LFound := LStore.FindByFingerprint(LFP);
  Check(LFound <> nil, 'FindByFingerprint found');
  Check(LFound.GetFingerprintSHA256 = LFP, 'Fingerprint matches');

  LFound := LStore.FindByFingerprint('0000000000000000000000000000000000000000000000000000000000000000');
  Check(LFound = nil, 'FindByFingerprint(bogus) = nil');
end;

procedure TestVerifyCertificate;
var
  LStore: ISSLCertificateStore;
  LCert: ISSLCertificate;
begin
  WriteLn('TestVerifyCertificate');
  LStore := LLib.CreateCertificateStore;
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore.AddCertificate(LCert);
  Check(LStore.VerifyCertificate(LCert), 'Self-signed cert verifies in store');
end;

procedure TestBuildCertificateChain;
var
  LStore: ISSLCertificateStore;
  LCert: ISSLCertificate;
  LChain: TSSLCertificateArray;
begin
  WriteLn('TestBuildCertificateChain');
  LStore := LLib.CreateCertificateStore;
  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore.AddCertificate(LCert);

  LChain := LStore.BuildCertificateChain(LCert);
  Check(Length(LChain) >= 1, 'Chain has >= 1 cert (got ' + IntToStr(Length(LChain)) + ')');
end;

procedure TestLoadFromPath;
var
  LStore: ISSLCertificateStore;
begin
  WriteLn('TestLoadFromPath');
  LStore := LLib.CreateCertificateStore;
  Check(LStore.LoadFromPath('tests/certs'), 'LoadFromPath(tests/certs)');
  Check(LStore.GetCount >= 1, 'Store has certs after LoadFromPath (got ' + IntToStr(LStore.GetCount) + ')');
end;

procedure TestLoadSystemStore;
var
  LStore: ISSLCertificateStore;
begin
  WriteLn('TestLoadSystemStore');
  LStore := LLib.CreateCertificateStore;
  if LStore.LoadSystemStore then
    Check(LStore.GetCount > 0, 'System store has certs')
  else
    Check(True, 'LoadSystemStore returned False (no system certs dir, acceptable)');
end;

procedure TestNegativePaths;
var
  LStore: ISSLCertificateStore;
  LCert: ISSLCertificate;
begin
  WriteLn('TestNegativePaths');
  LStore := LLib.CreateCertificateStore;
  Check(not LStore.LoadFromFile('nonexistent.pem'), 'LoadFromFile nonexistent = False');
  Check(not LStore.LoadFromPath('/nonexistent/path'), 'LoadFromPath nonexistent = False');

  LCert := LLib.CreateCertificate;
  LCert.LoadFromFile('tests/certs/server-cert.pem');
  LStore.AddCertificate(LCert);
  Check(not LStore.RemoveCertificate(nil), 'RemoveCertificate(nil) = False');
  Check(not LStore.Contains(nil), 'Contains(nil) = False');
end;

begin
  LTotal := 0;
  LPassed := 0;

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    TestAddRemoveClear;
    TestContains;
    TestGetCertificate;
    TestDeduplication;
    TestLoadFromFile;
    TestFindBySubject;
    TestFindByIssuer;
    TestFindBySerialNumber;
    TestFindByFingerprint;
    TestVerifyCertificate;
    TestBuildCertificateChain;
    TestLoadFromPath;
    TestLoadSystemStore;
    TestNegativePaths;
  finally
    LLib.Finalize;
  end;

  WriteLn;
  WriteLn('ISSLCertificateStore test suite: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
