program test_openssl_rand;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.err;

procedure PrintBytes(const Buf: array of Byte);
var
  I: Integer;
begin
  for I := Low(Buf) to High(Buf) do
  begin
    Write(IntToHex(Buf[I], 2));
    if (I + 1) mod 16 = 0 then
      WriteLn
    else
      Write(' ');
  end;
  WriteLn;
end;

var
  Buffer: array[0..31] of Byte;
  I: Integer;
begin
  WriteLn('OpenSSL Random Number Generation Test');
  WriteLn('======================================');
  WriteLn;
  
  // Load OpenSSL libraries
  Write('Loading OpenSSL libraries... ');
  try
    LoadOpenSSLCore;
    WriteLn('OK');
  except
    on E: Exception do
    begin
      WriteLn('FAILED!');
      WriteLn('Error: ', E.Message);
      Exit;
    end;
  end;
  
  WriteLn('OpenSSL version: ', OpenSSL_version(0));
  WriteLn;
  
  // Load RAND module
  Write('Loading RAND module... ');
  if not LoadOpenSSLRAND then
  begin
    WriteLn('FAILED!');
    WriteLn('Error: Could not load RAND functions');
    UnloadOpenSSLCore;
    Exit;
  end;
  WriteLn('OK');
  WriteLn;
  
  // Generate random bytes
  WriteLn('Generating 32 random bytes (5 times):');
  WriteLn;
  
  for I := 1 to 5 do
  begin
    WriteLn('Generation #', I, ':');
    if RAND_bytes(@Buffer[0], Length(Buffer)) = 1 then
    begin
      PrintBytes(Buffer);
    end
    else
    begin
      WriteLn('ERROR: RAND_bytes failed');
      Break;
    end;
    WriteLn;
  end;
  
  // Cleanup
  UnloadOpenSSLRAND;
  UnloadOpenSSLCore;
  
  WriteLn('Test completed successfully.');
end.
