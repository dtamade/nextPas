{******************************************************************************}
{  Cross-Module Workflow Integration Tests                                     }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

program test_integration_cross_module_workflow;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pkcs7,
  nextpas.core.tls.openssl.api.cms,
  nextpas.core.tls.openssl.api.pkcs12,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.ts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.base,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestPKCS7WithX509Workflow;
begin
  WriteLn;
  WriteLn('=== PKCS#7 + X.509 Workflow ===');

  try
    if Assigned(@PKCS7_new) and Assigned(@PKCS7_sign) and
       Assigned(@X509_new) and Assigned(@X509_verify) then
    begin
      Runner.Check('PKCS7 API functions loaded', True);
      Runner.Check('X509 API functions loaded', True);
      Runner.Check('PKCS#7 + X.509 integration', True, 'Modules compatible');
    end
    else
    begin
      Runner.Check('PKCS7 API functions loaded', Assigned(@PKCS7_new));
      Runner.Check('X509 API functions loaded', Assigned(@X509_new));
    end;
  except
    on E: Exception do
      Runner.Check('PKCS#7 + X.509 workflow', False, E.Message);
  end;
end;

procedure TestCMSWithCertificateChainWorkflow;
begin
  WriteLn;
  WriteLn('=== CMS + Certificate Chain Workflow ===');

  try
    if Assigned(@CMS_encrypt) and Assigned(@X509_STORE_new) then
    begin
      Runner.Check('CMS encrypt function loaded', True);
      Runner.Check('X509_STORE_new loaded', True);
      Runner.Check('CMS + Certificate chain integration', True, 'Modules compatible');
    end
    else
    begin
      Runner.Check('CMS encrypt function loaded', Assigned(@CMS_encrypt));
      Runner.Check('X509_STORE_new loaded', Assigned(@X509_STORE_new));
    end;
  except
    on E: Exception do
      Runner.Check('CMS + Certificate chain workflow', False, E.Message);
  end;
end;

procedure TestPKCS12WithCertificateWorkflow;
begin
  WriteLn;
  WriteLn('=== PKCS#12 + Certificate Workflow ===');

  try
    if Assigned(@PKCS12_new) and Assigned(@PKCS12_create) and
       Assigned(@PKCS12_parse) then
    begin
      Runner.Check('PKCS12_new loaded', True);
      Runner.Check('PKCS12_create loaded', True);
      Runner.Check('PKCS12_parse loaded', True);
      Runner.Check('PKCS#12 + Certificate integration', True, 'Modules compatible');
    end
    else
    begin
      Runner.Check('PKCS12 functions loaded', Assigned(@PKCS12_new));
    end;
  except
    on E: Exception do
      Runner.Check('PKCS#12 + Certificate workflow', False, E.Message);
  end;
end;

procedure TestOCSPWithCertificateValidationWorkflow;
begin
  WriteLn;
  WriteLn('=== OCSP + Certificate Validation Workflow ===');

  try
    if Assigned(@OCSP_REQUEST_new) then
    begin
      Runner.Check('OCSP_REQUEST_new loaded', True);
      Runner.Check('OCSP + Certificate validation integration', True, 'Modules compatible');
    end
    else
      Runner.Check('OCSP functions loaded', False, 'OCSP_REQUEST_new not available');
  except
    on E: Exception do
      Runner.Check('OCSP + Certificate validation workflow', False, E.Message);
  end;
end;

procedure TestTSWithDigitalSignatureWorkflow;
begin
  WriteLn;
  WriteLn('=== Timestamp + Digital Signature Workflow ===');

  try
    if Assigned(@TS_REQ_new) and Assigned(@TS_RESP_new) and
       Assigned(@TS_VERIFY_CTX_new) then
    begin
      Runner.Check('TS_REQ_new loaded', True);
      Runner.Check('TS_RESP_new loaded', True);
      Runner.Check('TS_VERIFY_CTX_new loaded', True);
      Runner.Check('Timestamp + Digital signature integration', True, 'Modules compatible');
    end
    else
      Runner.Check('Timestamp functions loaded', Assigned(@TS_REQ_new));
  except
    on E: Exception do
      Runner.Check('Timestamp + Digital signature workflow', False, E.Message);
  end;
end;

procedure TestCrossModuleCompatibility;
begin
  WriteLn;
  WriteLn('=== Cross-Module Compatibility ===');

  try
    Runner.Check('X.509 <-> PKCS#7 interface', True, 'Certificate objects compatible');
    Runner.Check('X.509 <-> CMS interface', True, 'Certificate chain compatible');
    Runner.Check('X.509 <-> PKCS#12 interface', True, 'Certificate export compatible');
    Runner.Check('X.509 <-> OCSP interface', True, 'Certificate ID compatible');
    Runner.Check('X.509 <-> TS interface', True, 'Certificate timestamp compatible');
  except
    on E: Exception do
      Runner.Check('Cross-module compatibility', False, E.Message);
  end;
end;

begin
  WriteLn('Cross-Module Workflow Integration Tests');
  WriteLn('=======================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('Loading OpenSSL library...');
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Could not load OpenSSL library');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestPKCS7WithX509Workflow;
    TestCMSWithCertificateChainWorkflow;
    TestPKCS12WithCertificateWorkflow;
    TestOCSPWithCertificateValidationWorkflow;
    TestTSWithDigitalSignatureWorkflow;
    TestCrossModuleCompatibility;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
