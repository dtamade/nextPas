program test_api_check;
{$mode objfpc}{$H+}
uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.x509;
var
  Lib: ISSLLibrary;
begin
  Lib := CreateOpenSSLLibrary;
  Lib.Initialize;

  WriteLn('=== BIO API ===');
  WriteLn('BIO_new: ', Assigned(BIO_new));
  WriteLn('BIO_free: ', Assigned(BIO_free));
  WriteLn('BIO_s_mem: ', Assigned(BIO_s_mem));
  WriteLn('BIO_new_mem_buf: ', Assigned(BIO_new_mem_buf));
  WriteLn('BIO_new_file: ', Assigned(BIO_new_file));
  WriteLn('BIO_read: ', Assigned(BIO_read));
  WriteLn('BIO_write: ', Assigned(BIO_write));
  WriteLn('BIO_get_mem_data: True');  // Always available as function
  WriteLn('BIO_ctrl: ', Assigned(BIO_ctrl));

  WriteLn;
  WriteLn('=== X509 Name API ===');
  WriteLn('X509_get_subject_name: ', Assigned(X509_get_subject_name));
  WriteLn('X509_get_issuer_name: ', Assigned(X509_get_issuer_name));
  WriteLn('X509_NAME_oneline: ', Assigned(X509_NAME_oneline));
  WriteLn('X509_NAME_print_ex: ', Assigned(X509_NAME_print_ex));

  WriteLn;
  WriteLn('=== X509 Serial/Signature API ===');
  WriteLn('X509_get_serialNumber: ', Assigned(X509_get_serialNumber));
  WriteLn('ASN1_INTEGER_to_BN: ', Assigned(ASN1_INTEGER_to_BN));
  WriteLn('BN_bn2hex: ', Assigned(BN_bn2hex));
  WriteLn('X509_get_signature_nid: ', Assigned(X509_get_signature_nid));
end.
