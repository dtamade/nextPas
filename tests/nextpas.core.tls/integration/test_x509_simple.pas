program test_x509_simple;

{******************************************************************************}
{  X509 Module Simple Integration Tests                                        }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils, DynLibs, ctypes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader,
  test_openssl_base;

type
  { X.509 Basic Function Types }
  TX509_new = function: PX509; cdecl;
  TX509_free = procedure(x: PX509); cdecl;
  TX509_set_version = function(x: PX509; version: clong): Integer; cdecl;
  TX509_get_version = function(const x: PX509): clong; cdecl;
  TX509_set_serialNumber = function(x: PX509; serial: PASN1_INTEGER): Integer; cdecl;
  TX509_get_serialNumber = function(x: PX509): PASN1_INTEGER; cdecl;
  TX509_set_issuer_name = function(x: PX509; name: PX509_NAME): Integer; cdecl;
  TX509_get_issuer_name = function(const a: PX509): PX509_NAME; cdecl;
  TX509_set_subject_name = function(x: PX509; name: PX509_NAME): Integer; cdecl;
  TX509_get_subject_name = function(const a: PX509): PX509_NAME; cdecl;
  TX509_set_pubkey = function(x: PX509; pkey: PEVP_PKEY): Integer; cdecl;
  TX509_get_pubkey = function(x: PX509): PEVP_PKEY; cdecl;
  TX509_sign = function(x: PX509; pkey: PEVP_PKEY; const md: PEVP_MD): Integer; cdecl;
  TX509_verify = function(a: PX509; r: PEVP_PKEY): Integer; cdecl;
  TX509_dup = function(x: PX509): PX509; cdecl;
  TX509_cmp = function(const a: PX509; const b: PX509): Integer; cdecl;

  { X.509 Name Functions }
  TX509_NAME_new = function: PX509_NAME; cdecl;
  TX509_NAME_free = procedure(a: PX509_NAME); cdecl;
  TX509_NAME_add_entry_by_txt = function(name: PX509_NAME; const field: PAnsiChar; &type: Integer; const bytes: PByte; len: Integer; loc: Integer; &set: Integer): Integer; cdecl;
  TX509_NAME_oneline = function(const a: PX509_NAME; buf: PAnsiChar; size: Integer): PAnsiChar; cdecl;

  { ASN.1 Functions }
  TASN1_INTEGER_new = function: PASN1_INTEGER; cdecl;
  TASN1_INTEGER_free = procedure(a: PASN1_INTEGER); cdecl;
  TASN1_INTEGER_set = function(a: PASN1_INTEGER; v: clong): Integer; cdecl;
  TASN1_INTEGER_get = function(const a: PASN1_INTEGER): clong; cdecl;

  { EVP Functions }
  TEVP_PKEY_new = function: PEVP_PKEY; cdecl;
  TEVP_PKEY_free = procedure(pkey: PEVP_PKEY); cdecl;
  TEVP_PKEY_assign = function(pkey: PEVP_PKEY; &type: Integer; key: Pointer): Integer; cdecl;

  { RSA Functions for key generation }
  TRSA_new = function: Pointer; cdecl;
  TRSA_free = procedure(r: Pointer); cdecl;
  TRSA_generate_key_ex = function(rsa: Pointer; bits: Integer; e: PBIGNUM; cb: Pointer): Integer; cdecl;

  { BIGNUM Functions }
  TBN_new = function: PBIGNUM; cdecl;
  TBN_free = procedure(a: PBIGNUM); cdecl;
  TBN_set_word = function(a: PBIGNUM; w: culong): Integer; cdecl;

  { EVP_MD Functions }
  TEVP_sha256 = function: PEVP_MD; cdecl;

var
  Runner: TSimpleTestRunner;

  { Function pointers }
  X509_new: TX509_new = nil;
  X509_free: TX509_free = nil;
  X509_set_version: TX509_set_version = nil;
  X509_get_version: TX509_get_version = nil;
  X509_set_serialNumber: TX509_set_serialNumber = nil;
  X509_get_serialNumber: TX509_get_serialNumber = nil;
  X509_set_issuer_name: TX509_set_issuer_name = nil;
  X509_get_issuer_name: TX509_get_issuer_name = nil;
  X509_set_subject_name: TX509_set_subject_name = nil;
  X509_get_subject_name: TX509_get_subject_name = nil;
  X509_set_pubkey: TX509_set_pubkey = nil;
  X509_get_pubkey: TX509_get_pubkey = nil;
  X509_sign: TX509_sign = nil;
  X509_verify: TX509_verify = nil;
  X509_dup: TX509_dup = nil;
  X509_cmp: TX509_cmp = nil;

  X509_NAME_new: TX509_NAME_new = nil;
  X509_NAME_free: TX509_NAME_free = nil;
  X509_NAME_add_entry_by_txt: TX509_NAME_add_entry_by_txt = nil;
  X509_NAME_oneline: TX509_NAME_oneline = nil;

  ASN1_INTEGER_new: TASN1_INTEGER_new = nil;
  ASN1_INTEGER_free: TASN1_INTEGER_free = nil;
  ASN1_INTEGER_set: TASN1_INTEGER_set = nil;
  ASN1_INTEGER_get: TASN1_INTEGER_get = nil;

  EVP_PKEY_new: TEVP_PKEY_new = nil;
  EVP_PKEY_free: TEVP_PKEY_free = nil;
  EVP_PKEY_assign: TEVP_PKEY_assign = nil;

  RSA_new: TRSA_new = nil;
  RSA_free: TRSA_free = nil;
  RSA_generate_key_ex: TRSA_generate_key_ex = nil;

  BN_new: TBN_new = nil;
  BN_free: TBN_free = nil;
  BN_set_word: TBN_set_word = nil;

  EVP_sha256: TEVP_sha256 = nil;

function LoadX509Functions: Boolean;
var
  LibHandle: TLibHandle;
begin
  Result := False;
  LibHandle := GetCryptoLibHandle;
  if LibHandle = 0 then Exit;

  // Load X509 certificate functions
  X509_new := TX509_new(GetProcedureAddress(LibHandle, 'X509_new'));
  X509_free := TX509_free(GetProcedureAddress(LibHandle, 'X509_free'));
  X509_set_version := TX509_set_version(GetProcedureAddress(LibHandle, 'X509_set_version'));
  X509_get_version := TX509_get_version(GetProcedureAddress(LibHandle, 'X509_get_version'));
  X509_set_serialNumber := TX509_set_serialNumber(GetProcedureAddress(LibHandle, 'X509_set_serialNumber'));
  X509_get_serialNumber := TX509_get_serialNumber(GetProcedureAddress(LibHandle, 'X509_get_serialNumber'));
  X509_set_issuer_name := TX509_set_issuer_name(GetProcedureAddress(LibHandle, 'X509_set_issuer_name'));
  X509_get_issuer_name := TX509_get_issuer_name(GetProcedureAddress(LibHandle, 'X509_get_issuer_name'));
  X509_set_subject_name := TX509_set_subject_name(GetProcedureAddress(LibHandle, 'X509_set_subject_name'));
  X509_get_subject_name := TX509_get_subject_name(GetProcedureAddress(LibHandle, 'X509_get_subject_name'));
  X509_set_pubkey := TX509_set_pubkey(GetProcedureAddress(LibHandle, 'X509_set_pubkey'));
  X509_get_pubkey := TX509_get_pubkey(GetProcedureAddress(LibHandle, 'X509_get_pubkey'));
  X509_sign := TX509_sign(GetProcedureAddress(LibHandle, 'X509_sign'));
  X509_verify := TX509_verify(GetProcedureAddress(LibHandle, 'X509_verify'));
  X509_dup := TX509_dup(GetProcedureAddress(LibHandle, 'X509_dup'));
  X509_cmp := TX509_cmp(GetProcedureAddress(LibHandle, 'X509_cmp'));

  // Load X509_NAME functions
  X509_NAME_new := TX509_NAME_new(GetProcedureAddress(LibHandle, 'X509_NAME_new'));
  X509_NAME_free := TX509_NAME_free(GetProcedureAddress(LibHandle, 'X509_NAME_free'));
  X509_NAME_add_entry_by_txt := TX509_NAME_add_entry_by_txt(GetProcedureAddress(LibHandle, 'X509_NAME_add_entry_by_txt'));
  X509_NAME_oneline := TX509_NAME_oneline(GetProcedureAddress(LibHandle, 'X509_NAME_oneline'));

  // Load ASN1 functions
  ASN1_INTEGER_new := TASN1_INTEGER_new(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_new'));
  ASN1_INTEGER_free := TASN1_INTEGER_free(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_free'));
  ASN1_INTEGER_set := TASN1_INTEGER_set(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_set'));
  ASN1_INTEGER_get := TASN1_INTEGER_get(GetProcedureAddress(LibHandle, 'ASN1_INTEGER_get'));

  // Load EVP functions
  EVP_PKEY_new := TEVP_PKEY_new(GetProcedureAddress(LibHandle, 'EVP_PKEY_new'));
  EVP_PKEY_free := TEVP_PKEY_free(GetProcedureAddress(LibHandle, 'EVP_PKEY_free'));
  EVP_PKEY_assign := TEVP_PKEY_assign(GetProcedureAddress(LibHandle, 'EVP_PKEY_assign'));

  // Load RSA functions
  RSA_new := TRSA_new(GetProcedureAddress(LibHandle, 'RSA_new'));
  RSA_free := TRSA_free(GetProcedureAddress(LibHandle, 'RSA_free'));
  RSA_generate_key_ex := TRSA_generate_key_ex(GetProcedureAddress(LibHandle, 'RSA_generate_key_ex'));

  // Load BIGNUM functions
  BN_new := TBN_new(GetProcedureAddress(LibHandle, 'BN_new'));
  BN_free := TBN_free(GetProcedureAddress(LibHandle, 'BN_free'));
  BN_set_word := TBN_set_word(GetProcedureAddress(LibHandle, 'BN_set_word'));

  // Load EVP_MD functions
  EVP_sha256 := TEVP_sha256(GetProcedureAddress(LibHandle, 'EVP_sha256'));

  Result := Assigned(X509_new) and Assigned(X509_free);
end;

procedure TestX509CreateFree;
var
  cert: PX509;
begin
  WriteLn;
  WriteLn('=== X509 Certificate Creation and Destruction ===');

  cert := X509_new();
  Runner.Check('Create X509 certificate', cert <> nil);

  if cert <> nil then
  begin
    X509_free(cert);
    Runner.Check('Free X509 certificate', True);
  end;
end;

procedure TestX509Version;
var
  cert: PX509;
  version: clong;
begin
  WriteLn;
  WriteLn('=== X509 Version Operations ===');

  cert := X509_new();
  Runner.Check('Create certificate', cert <> nil);
  if cert = nil then Exit;

  Runner.Check('Set certificate version to 2 (X509v3)', X509_set_version(cert, 2) = 1);

  version := X509_get_version(cert);
  Runner.Check('Get certificate version', version = 2, Format('Version=%d', [version]));

  X509_free(cert);
end;

procedure TestX509SerialNumber;
var
  cert: PX509;
  serial: PASN1_INTEGER;
  retrieved_serial: PASN1_INTEGER;
  serial_value: clong;
begin
  WriteLn;
  WriteLn('=== X509 Serial Number Operations ===');

  cert := X509_new();
  Runner.Check('Create certificate', cert <> nil);
  if cert = nil then Exit;

  serial := ASN1_INTEGER_new();
  Runner.Check('Create ASN1_INTEGER', serial <> nil);
  if serial = nil then
  begin
    X509_free(cert);
    Exit;
  end;

  Runner.Check('Set serial number value to 12345', ASN1_INTEGER_set(serial, 12345) = 1);
  Runner.Check('Set certificate serial number', X509_set_serialNumber(cert, serial) = 1);

  retrieved_serial := X509_get_serialNumber(cert);
  Runner.Check('Get certificate serial number', retrieved_serial <> nil);

  if retrieved_serial <> nil then
  begin
    serial_value := ASN1_INTEGER_get(retrieved_serial);
    Runner.Check('Serial number value correct', serial_value = 12345,
            Format('Serial=%d', [serial_value]));
  end;

  ASN1_INTEGER_free(serial);
  X509_free(cert);
end;

procedure TestX509Name;
const
  MBSTRING_UTF8 = $1000 or 1;
var
  name: PX509_NAME;
  buf: array[0..255] of AnsiChar;
  name_str: PAnsiChar;
begin
  WriteLn;
  WriteLn('=== X509 Name Operations ===');

  name := X509_NAME_new();
  Runner.Check('Create X509_NAME', name <> nil);
  if name = nil then Exit;

  Runner.Check('Add CN (Common Name) entry',
          X509_NAME_add_entry_by_txt(name, 'CN', MBSTRING_UTF8,
            PByte(PAnsiChar('Test Certificate')), -1, -1, 0) = 1);

  Runner.Check('Add O (Organization) entry',
          X509_NAME_add_entry_by_txt(name, 'O', MBSTRING_UTF8,
            PByte(PAnsiChar('Test Organization')), -1, -1, 0) = 1);

  name_str := X509_NAME_oneline(name, @buf[0], SizeOf(buf));
  Runner.Check('Convert name to string', name_str <> nil);
  if name_str <> nil then
    WriteLn('  Name string: ', name_str);

  X509_NAME_free(name);
end;

procedure TestX509SubjectIssuer;
const
  MBSTRING_UTF8 = $1000 or 1;
var
  cert: PX509;
  subject, issuer: PX509_NAME;
  retrieved_subject, retrieved_issuer: PX509_NAME;
  buf: array[0..255] of AnsiChar;
begin
  WriteLn;
  WriteLn('=== X509 Subject and Issuer Names ===');

  cert := X509_new();
  Runner.Check('Create certificate', cert <> nil);
  if cert = nil then Exit;

  // Create subject name
  subject := X509_NAME_new();
  Runner.Check('Create subject name', subject <> nil);
  if subject = nil then
  begin
    X509_free(cert);
    Exit;
  end;
  X509_NAME_add_entry_by_txt(subject, 'CN', MBSTRING_UTF8, PByte(PAnsiChar('Subject CN')), -1, -1, 0);

  // Create issuer name
  issuer := X509_NAME_new();
  Runner.Check('Create issuer name', issuer <> nil);
  if issuer = nil then
  begin
    X509_NAME_free(subject);
    X509_free(cert);
    Exit;
  end;
  X509_NAME_add_entry_by_txt(issuer, 'CN', MBSTRING_UTF8, PByte(PAnsiChar('Issuer CN')), -1, -1, 0);

  Runner.Check('Set subject name', X509_set_subject_name(cert, subject) = 1);
  Runner.Check('Set issuer name', X509_set_issuer_name(cert, issuer) = 1);

  retrieved_subject := X509_get_subject_name(cert);
  Runner.Check('Retrieve subject name', retrieved_subject <> nil);
  if retrieved_subject <> nil then
    WriteLn('  Subject: ', X509_NAME_oneline(retrieved_subject, @buf[0], SizeOf(buf)));

  retrieved_issuer := X509_get_issuer_name(cert);
  Runner.Check('Retrieve issuer name', retrieved_issuer <> nil);
  if retrieved_issuer <> nil then
    WriteLn('  Issuer: ', X509_NAME_oneline(retrieved_issuer, @buf[0], SizeOf(buf)));

  X509_NAME_free(subject);
  X509_NAME_free(issuer);
  X509_free(cert);
end;

procedure TestX509Dup;
var
  cert1, cert2: PX509;
  serial: PASN1_INTEGER;
begin
  WriteLn;
  WriteLn('=== X509 Certificate Duplication ===');

  // Create and configure first certificate
  cert1 := X509_new();
  Runner.Check('Create certificate 1', cert1 <> nil);
  if cert1 = nil then Exit;

  X509_set_version(cert1, 2);
  serial := ASN1_INTEGER_new();
  ASN1_INTEGER_set(serial, 99999);
  X509_set_serialNumber(cert1, serial);
  ASN1_INTEGER_free(serial);

  // Duplicate certificate
  cert2 := X509_dup(cert1);
  Runner.Check('Duplicate certificate', cert2 <> nil);

  if cert2 <> nil then
  begin
    Runner.Check('Verify duplicated version', X509_get_version(cert2) = 2);
    Runner.Check('Verify duplicated serial',
            ASN1_INTEGER_get(X509_get_serialNumber(cert2)) = 99999);
    Runner.Check('Compare certificates', X509_cmp(cert1, cert2) = 0);
    X509_free(cert2);
  end;

  X509_free(cert1);
end;

begin
  WriteLn('X509 Module Simple Integration Test');
  WriteLn('====================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    // Load X509 functions
    if not LoadX509Functions then
    begin
      WriteLn('ERROR: Could not load X509 functions');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestX509CreateFree;
    TestX509Version;
    TestX509SerialNumber;
    TestX509Name;
    TestX509SubjectIssuer;
    TestX509Dup;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
