program test_real_usage;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.backed;

var
  SSLLib: ISSLLibrary;
  Context: ISSLContext;
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
  GPassed: Integer = 0;
  GFailed: Integer = 0;
  GSkipped: Integer = 0;

procedure RecordPass(const AName: string; const ADetail: string = '');
begin
  Inc(GPassed);
  if ADetail = '' then
    WriteLn('[PASS] ', AName)
  else
    WriteLn('[PASS] ', AName, ' - ', ADetail);
end;

procedure RecordFail(const AName: string; const ADetail: string = '');
begin
  Inc(GFailed);
  if ADetail = '' then
    WriteLn('[FAIL] ', AName)
  else
    WriteLn('[FAIL] ', AName, ' - ', ADetail);
end;

procedure RecordSkip(const AName: string; const AReason: string);
begin
  if Trim(AReason) = '' then
  begin
    Inc(GFailed);
    WriteLn('[FAIL] ', AName, ' - skip reason is required');
    Exit;
  end;

  Inc(GSkipped);
  WriteLn('[SKIP] ', AName, ' - ', AReason);
end;

procedure TestRealCertificateLoading;
var
  SerialNum, Subject, SigAlg: string;
  IsCA: Boolean;
begin
  WriteLn;
  WriteLn('=== Test 1: Real Certificate Loading ===');

  Store := SSLLib.CreateCertificateStore;
  if Store = nil then
  begin
    RecordFail('CreateCertificateStore', 'returned nil');
    Exit;
  end;
  RecordPass('CreateCertificateStore');

  if not Store.LoadSystemStore then
  begin
    if not Store.LoadFromPath('/etc/ssl/certs') then
    begin
      RecordFail('LoadSystemStore/LoadFromPath', 'cannot load any certificates');
      Exit;
    end;
    RecordPass('Load certificate store from fallback path', '/etc/ssl/certs');
  end
  else
    RecordPass('LoadSystemStore');

  if Store.GetCount = 0 then
  begin
    RecordFail('Certificate count', 'store is empty');
    Exit;
  end;
  RecordPass('Certificate count', IntToStr(Store.GetCount));

  Cert := Store.GetCertificate(0);
  if Cert = nil then
  begin
    RecordFail('GetCertificate(0)', 'returned nil');
    Exit;
  end;
  RecordPass('GetCertificate(0)');

  try
    Subject := Cert.GetSubject;
    if Subject <> '' then
      RecordPass('GetSubject', Copy(Subject, 1, 60))
    else
      RecordFail('GetSubject', 'empty subject');
  except
    on E: Exception do
      RecordFail('GetSubject', E.Message);
  end;

  try
    SerialNum := Cert.GetSerialNumber;
    if SerialNum <> '' then
      RecordPass('GetSerialNumber', Copy(SerialNum, 1, 40))
    else
      RecordSkip('GetSerialNumber non-empty', 'some backends/certs may not expose serial text');
  except
    on E: Exception do
      RecordFail('GetSerialNumber', E.Message);
  end;

  try
    SigAlg := Cert.GetSignatureAlgorithm;
    if SigAlg <> '' then
      RecordPass('GetSignatureAlgorithm', SigAlg)
    else
      RecordFail('GetSignatureAlgorithm', 'empty signature algorithm');
  except
    on E: Exception do
      RecordFail('GetSignatureAlgorithm', E.Message);
  end;

  try
    IsCA := Cert.IsCA;
    RecordPass('IsCA callable', BoolToStr(IsCA, True));
  except
    on E: Exception do
      RecordFail('IsCA', E.Message);
  end;
end;

procedure TestHTTPSConnectionContractWithoutSocket;
var
  LRaised: Boolean;
begin
  WriteLn;
  WriteLn('=== Test 2: HTTPS Connection Contract (No Socket) ===');

  Context := SSLLib.CreateContext(sslCtxClient);
  if Context = nil then
  begin
    RecordFail('CreateContext(client)', 'returned nil');
    Exit;
  end;
  RecordPass('CreateContext(client)');

  if Context.GetContextType = sslCtxClient then
    RecordPass('Context type is client')
  else
    RecordFail('Context type is client', 'unexpected context type');

  LRaised := False;
  try
    Context.CreateConnection(TStream(nil));
  except
    on E: ESSLException do
    begin
      LRaised := True;
      if Pos('nil', LowerCase(E.Message)) > 0 then
        RecordPass('CreateConnection(nil) guard', E.Message)
      else
        RecordPass('CreateConnection(nil) guard', E.ClassName);
    end;
    on E: Exception do
    begin
      LRaised := True;
      RecordPass('CreateConnection(nil) guard', E.ClassName);
    end;
  end;

  if not LRaised then
    RecordFail('CreateConnection(nil) guard', 'expected exception was not raised');
end;

procedure TestBasicAPI;
begin
  WriteLn;
  WriteLn('=== Test 3: Basic API Availability ===');

  try
    Context := SSLLib.CreateContext(sslCtxClient);
    if Context <> nil then
      RecordPass('CreateContext')
    else
      RecordFail('CreateContext', 'returned nil');
  except
    on E: Exception do
      RecordFail('CreateContext', E.Message);
  end;

  try
    Store := SSLLib.CreateCertificateStore;
    if Store <> nil then
      RecordPass('CreateCertificateStore')
    else
      RecordFail('CreateCertificateStore', 'returned nil');
  except
    on E: Exception do
      RecordFail('CreateCertificateStore', E.Message);
  end;

  try
    Cert := SSLLib.CreateCertificate;
    if Cert = nil then
      RecordPass('CreateCertificate(nil-by-design)')
    else
      RecordPass('CreateCertificate', 'backend supports direct creation');
  except
    on E: Exception do
      RecordFail('CreateCertificate', E.Message);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('REAL USAGE TEST - Deterministic Contract');
  WriteLn('========================================');

  try
    SSLLib := CreateOpenSSLLibrary;
    if SSLLib = nil then
    begin
      RecordFail('CreateOpenSSLLibrary', 'returned nil');
    end
    else if not SSLLib.Initialize then
    begin
      RecordFail('Initialize OpenSSL library', 'returned False');
    end
    else
    begin
      RecordPass('Initialize OpenSSL library', SSLLib.GetVersionString);

      TestBasicAPI;
      TestRealCertificateLoading;
      TestHTTPSConnectionContractWithoutSocket;
    end;
  except
    on E: Exception do
      RecordFail('Test fatal exception', E.Message);
  end;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed : ', GPassed);
  WriteLn('Failed : ', GFailed);
  WriteLn('Skipped: ', GSkipped);

  if GFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
