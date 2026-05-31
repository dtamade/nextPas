{
  OpenSSL API Types
  
  Common types and constants used across OpenSSL API modules.
}
unit nextpas.core.tls.openssl.api.types;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  // OpenSSL opaque types (pointers)
  PSSL = Pointer;
  PSSL_CTX = Pointer;
  PSSL_METHOD = Pointer;
  PX509 = Pointer;
  PX509_STORE = Pointer;
  PX509_STORE_CTX = Pointer;
  PEVP_PKEY = Pointer;
  PBIO = Pointer;
  PBIO_METHOD = Pointer;
  
  // OpenSSL result codes
  TSSLResult = Integer;
  
const
  // SSL result codes
  SSL_ERROR_NONE = 0;
  SSL_ERROR_SSL = 1;
  SSL_ERROR_WANT_READ = 2;
  SSL_ERROR_WANT_WRITE = 3;
  SSL_ERROR_WANT_X509_LOOKUP = 4;
  SSL_ERROR_SYSCALL = 5;
  SSL_ERROR_ZERO_RETURN = 6;
  SSL_ERROR_WANT_CONNECT = 7;
  SSL_ERROR_WANT_ACCEPT = 8;
  
  // Verification modes
  SSL_VERIFY_NONE = 0;
  SSL_VERIFY_PEER = 1;
  SSL_VERIFY_FAIL_IF_NO_PEER_CERT = 2;
  SSL_VERIFY_CLIENT_ONCE = 4;

implementation

end.
