program test_cert_load_debug;
{$mode objfpc}{$H+}
uses
  SysUtils,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.base;

procedure TestDirectLoad;
var
  BIO: PBIO;
  X509: PX509;
begin
  WriteLn('=== Direct Certificate Load Test ===');
  WriteLn('API Functions:');
  WriteLn('  BIO_new_file: ', Assigned(BIO_new_file));
  WriteLn('  PEM_read_bio_X509: ', Assigned(PEM_read_bio_X509));
  WriteLn('  BIO_free: ', Assigned(BIO_free));
  WriteLn('  X509_free: ', Assigned(X509_free));
  
  if not Assigned(BIO_new_file) then begin
    WriteLn('❌ BIO_new_file not loaded!');
    Exit;
  end;
  
  WriteLn;
  WriteLn('Trying to load: /etc/ssl/certs/ACCVRAIZ1.pem');
  BIO := BIO_new_file('/etc/ssl/certs/ACCVRAIZ1.pem', 'r');
  if BIO = nil then begin
    WriteLn('❌ BIO_new_file returned nil');
    Exit;
  end;
  WriteLn('✓ BIO opened');
  
  X509 := PEM_read_bio_X509(BIO, nil, nil, nil);
  if X509 = nil then begin
    WriteLn('❌ PEM_read_bio_X509 returned nil');
    BIO_free(BIO);
    Exit;
  end;
  WriteLn('✓ Certificate loaded!');
  
  X509_free(X509);
  BIO_free(BIO);
end;

procedure TestStoreLoad;
var
  Lib: ISSLLibrary;
  Store: ISSLCertificateStore;
begin
  WriteLn;
  WriteLn('=== Store Load Test ===');
  Lib := CreateOpenSSLLibrary;
  if not Lib.Initialize then begin
    WriteLn('❌ Failed to initialize');
    Exit;
  end;
  WriteLn('✓ Initialized');
  
  Store := Lib.CreateCertificateStore;
  WriteLn('Before: Count = ', Store.GetCount);
  
  WriteLn('Calling LoadFromPath("/etc/ssl/certs")...');
  if Store.LoadFromPath('/etc/ssl/certs') then
    WriteLn('✓ SUCCESS: Count = ', Store.GetCount)
  else
    WriteLn('❌ FAILED: Count = ', Store.GetCount);
end;

var
  Lib: ISSLLibrary;
begin
  Lib := CreateOpenSSLLibrary;
  if not Lib.Initialize then begin
    WriteLn('FATAL: Cannot initialize OpenSSL');
    Halt(1);
  end;
  
  TestDirectLoad;
  TestStoreLoad;
end.
