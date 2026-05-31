program test_openssl_minimal;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

var
  Lib: ISSLLibrary;
begin
  WriteLn('Testing OpenSSL Backend (Minimal)');
  WriteLn('==================================');
  
  Lib := CreateOpenSSLLibrary;
  WriteLn('Library created:  ', (Lib <> nil));
  
  if Lib <> nil then
  begin
    WriteLn('Initializing...');
    if Lib.Initialize then
    begin
      WriteLn('Success!');
      WriteLn('Version: ', Lib.GetVersionString);
    end
    else
    begin
      WriteLn('Failed: ', Lib.GetLastErrorString);
    end;
  end;
end.
