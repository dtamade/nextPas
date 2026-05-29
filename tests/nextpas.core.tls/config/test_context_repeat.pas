program test_context_repeat;
{$mode objfpc}{$H+}
uses
  SysUtils,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.base;
var
  Lib: ISSLLibrary;
  Ctx1, Ctx2, Ctx3: ISSLContext;
begin
  Lib := CreateOpenSSLLibrary;
  if not Lib.Initialize then Halt(1);
  WriteLn('OpenSSL initialized');
  
  WriteLn('Creating Context 1...');
  try
    Ctx1 := Lib.CreateContext(sslCtxClient);
    WriteLn('  Result: ', Ctx1 <> nil);
  except
    on E: Exception do
      WriteLn('  Exception: ', E.Message);
  end;
  
  WriteLn('Releasing Context 1...');
  Ctx1 := nil;
  WriteLn('  Done');
  
  WriteLn('Creating Context 2...');
  Ctx2 := Lib.CreateContext(sslCtxClient);
  WriteLn('  Result: ', Ctx2 <> nil);
  
  WriteLn('Creating Context 3 (without releasing 2)...');
  Ctx3 := Lib.CreateContext(sslCtxClient);
  WriteLn('  Result: ', Ctx3 <> nil);
end.
