program test_openssl_v2;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.native_handle,
  nextpas.core.tls.openssl.api.core;

var
  TestsPassed, TestsFailed: Integer;

{ Helper function to check if object has native handle }
function HasNativeHandle(const AObject: IInterface): Boolean;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  Result := Supports(AObject, ISSLNativeHandleAccess, NativeAccess) and
            (NativeAccess.GetNativeHandle <> nil);
end;

procedure Test(const Name: string; Condition: Boolean; const Details: string = '');
begin
  Write('[', Name, '] ');
  if Condition then
  begin
    WriteLn('PASS');
    if Details <> '' then
      WriteLn('  -> ', Details);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('FAIL');
    if Details <> '' then
      WriteLn('  -> Error: ', Details);
    Inc(TestsFailed);
  end;
end;

procedure TestCoreLoading;
begin
  WriteLn;
  WriteLn('========== Test 1: Core Loading ==========');
  try
    LoadOpenSSLCore;
    Test('LoadOpenSSLCore', TOpenSSLLoader.IsModuleLoaded(osmCore));
    Test('GetCryptoLibHandle', GetCryptoLibHandle <> 0, 
         'Handle=' + IntToStr(PtrInt(GetCryptoLibHandle)));
    Test('GetSSLLibHandle', GetSSLLibHandle <> 0,
         'Handle=' + IntToStr(PtrInt(GetSSLLibHandle)));
    Test('GetOpenSSLVersionString', GetOpenSSLVersionString <> '',
         'Version=' + GetOpenSSLVersionString);
  except
    on E: Exception do
      Test('LoadOpenSSLCore', False, E.Message);
  end;
end;

procedure TestFactory;
var
  Lib: ISSLLibrary;
  Available: TSSLLibraryTypes;
begin
  WriteLn;
  WriteLn('========== Test 2: Factory ==========');
  try
    Available := TSSLFactory.GetAvailableLibraries;
    Test('GetAvailableLibraries', Available <> []);
    
    Test('IsLibraryAvailable(sslOpenSSL)', 
         TSSLFactory.IsLibraryAvailable(sslOpenSSL));
    
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    Test('GetLibraryInstance', Assigned(Lib));
    
    if Assigned(Lib) then
    begin
      Test('Library.IsInitialized', Lib.IsInitialized);
      Test('Library.GetVersionString', Lib.GetVersionString <> '',
           'Version=' + Lib.GetVersionString);
    end;
  except
    on E: Exception do
      Test('Factory', False, E.Message);
  end;
end;

procedure TestContext;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
begin
  WriteLn;
  WriteLn('========== Test 3: Context Creation ==========');
  try
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not Assigned(Lib) then
    begin
      Test('Context', False, 'Library not available');
      Exit;
    end;
    
    Ctx := Lib.CreateContext(sslCtxClient);
    Test('CreateContext(Client)', Assigned(Ctx));
    
    if Assigned(Ctx) then
    begin
      Test('Context.IsValid', Ctx.IsValid);
      Test('Context.GetNativeHandle', HasNativeHandle(Ctx));
    end;
    
    Ctx := nil;
    Ctx := Lib.CreateContext(sslCtxServer);
    Test('CreateContext(Server)', Assigned(Ctx));
  except
    on E: Exception do
      Test('Context', False, E.Message);
  end;
end;

procedure TestCertificate;
var
  Lib: ISSLLibrary;
  Cert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('========== Test 4: Certificate Creation ==========');
  try
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not Assigned(Lib) then
    begin
      Test('Certificate', False, 'Library not available');
      Exit;
    end;
    
    Cert := Lib.CreateCertificate;
    Test('CreateCertificate', Assigned(Cert));
    
    if Assigned(Cert) then
    begin
      Test('Certificate.GetNativeHandle', HasNativeHandle(Cert));
    end;
  except
    on E: Exception do
      Test('Certificate', False, E.Message);
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;
  
  WriteLn('OpenSSL Basic Validation Test v2');
  WriteLn('=================================');
  WriteLn('Date: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  
  TestCoreLoading;
  TestFactory;
  TestContext;
  TestCertificate;
  
  WriteLn;
  WriteLn('=================================');
  WriteLn('Results:');
  WriteLn('  Passed: ', TestsPassed);
  WriteLn('  Failed: ', TestsFailed);
  WriteLn('  Total:  ', TestsPassed + TestsFailed);
  WriteLn('=================================');
  
  if TestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('SUCCESS: All tests passed!');
    ExitCode := 0;
  end
  else
  begin
    WriteLn;
    WriteLn('FAILURE: Some tests failed.');
    ExitCode := 1;
  end;
end.
