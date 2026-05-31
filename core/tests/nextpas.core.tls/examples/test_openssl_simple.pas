program test_openssl_simple;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio;

procedure TestOpenSSLLoading;
var
  bio: PBIO;
begin
  WriteLn('Testing OpenSSL library loading...');
  
  try
    // Load OpenSSL libraries
    LoadOpenSSLCore;
    LoadOpenSSLBIO;
    
    if TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('OpenSSL libraries loaded successfully!');
      
      // Check version
      if Assigned(OpenSSL_version_num) then
      begin
        WriteLn('OpenSSL version number: $', IntToHex(OpenSSL_version_num(), 8));
      end;
      
      if Assigned(OpenSSL_version) then
      begin
        WriteLn('OpenSSL version string: ', OpenSSL_version(0));
      end;
      
      // Test BIO creation
      if Assigned(BIO_new) and Assigned(BIO_s_mem) then
      begin
        bio := BIO_new(BIO_s_mem());
        if bio <> nil then
        begin
          WriteLn('Successfully created memory BIO');
          if Assigned(BIO_free) then
            BIO_free(bio);
        end
        else
          WriteLn('Failed to create memory BIO');
      end
      else
        WriteLn('BIO functions not loaded');
      
      // Unload libraries
      UnloadOpenSSLCore;
      WriteLn('OpenSSL libraries unloaded');
    end
    else
      WriteLn('Failed to load OpenSSL libraries');
      
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
end;

begin
  WriteLn('OpenSSL Backend Test Program');
  WriteLn('============================');
  WriteLn;
  
  TestOpenSSLLoading;
  
  WriteLn;
  WriteLn('Test completed.');
  
  {$IFDEF WINDOWS}
  WriteLn('Press Enter to exit...');
  ReadLn;
  {$ENDIF}
end.