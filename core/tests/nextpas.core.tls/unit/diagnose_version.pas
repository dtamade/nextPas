program diagnose_version;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

var
  Version: string;
  i: Integer;

begin
  WriteLn('=== OpenSSL Version Diagnostic ===');
  WriteLn;
  
  LoadOpenSSLCore;
  
  if TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    WriteLn('OpenSSL loaded successfully');
    Version := GetOpenSSLVersionString;
    
    WriteLn('Version string: "', Version, '"');
    WriteLn('Length: ', Length(Version));
    WriteLn('Bytes: ');
    for i := 1 to Length(Version) do
      Write(IntToHex(Ord(Version[i]), 2), ' ');
    WriteLn;
    WriteLn;
    WriteLn('Contains "OpenSSL": ', Pos('OpenSSL', Version) > 0);
    WriteLn('Contains "openssl": ', Pos('openssl', Version) > 0);
    WriteLn('Contains "SSL": ', Pos('SSL', Version) > 0);
  end
  else
    WriteLn('Failed to load OpenSSL');
    
  ReadLn;
end.
