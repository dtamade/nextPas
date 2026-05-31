program fuzz_openssl;

{$mode objfpc}{$H+}

{**
 * OpenSSL-specific Fuzz Testing
 *
 * Targets:
 * - PEM certificate parsing
 * - DER certificate parsing
 * - BIO memory operations
 *
 * Run: ./fuzz_openssl [iterations]
 * Default: 1000 iterations per target
 *
 * Note: Requires OpenSSL library to be available
 *}

uses
  SysUtils, Classes,
  fuzz_framework,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem;

var
  GOpenSSLReady: Boolean = False;

{ ============================================================================ }
{ Fuzz Targets                                                                  }
{ ============================================================================ }

procedure FuzzPEMDecode(const AInput: TBytes);
var
  BIO: PBIO;
  X509: PX509;
begin
  if not GOpenSSLReady then Exit;
  if Length(AInput) = 0 then Exit;
  if not Assigned(BIO_new_mem_buf) then Exit;
  if not Assigned(PEM_read_bio_X509) then Exit;

  BIO := BIO_new_mem_buf(@AInput[0], Length(AInput));
  if BIO = nil then Exit;

  try
    X509 := PEM_read_bio_X509(BIO, nil, nil, nil);
    if X509 <> nil then
    begin
      if Assigned(X509_free) then
        X509_free(X509);
    end;
  except
    // Expected for invalid PEM
  end;

  if Assigned(BIO_free) then
    BIO_free(BIO);
end;

procedure FuzzDERParse(const AInput: TBytes);
var
  Data: PByte;
  X509: PX509;
begin
  if not GOpenSSLReady then Exit;
  if Length(AInput) = 0 then Exit;
  if not Assigned(d2i_X509) then Exit;

  Data := @AInput[0];
  try
    X509 := d2i_X509(nil, @Data, Length(AInput));
    if X509 <> nil then
    begin
      if Assigned(X509_free) then
        X509_free(X509);
    end;
  except
    // Expected for invalid DER
  end;
end;

procedure FuzzBIOMemory(const AInput: TBytes);
var
  BIO: PBIO;
  Buffer: array[0..1023] of Byte;
  BytesRead: Integer;
begin
  if not GOpenSSLReady then Exit;
  if Length(AInput) = 0 then Exit;
  if not Assigned(BIO_new_mem_buf) then Exit;

  BIO := BIO_new_mem_buf(@AInput[0], Length(AInput));
  if BIO = nil then Exit;

  try
    if Assigned(BIO_read) then
      BytesRead := BIO_read(BIO, @Buffer[0], SizeOf(Buffer));
  except
    // Should not crash
  end;

  if Assigned(BIO_free) then
    BIO_free(BIO);
end;

{ ============================================================================ }
{ Main Program                                                                  }
{ ============================================================================ }

var
  Fuzzer: TFuzzer;
  Iterations: Integer;

begin
  WriteLn('================================================================');
  WriteLn('       fafafa.ssl OpenSSL Fuzz Testing Suite                    ');
  WriteLn('================================================================');
  WriteLn;

  // Parse iterations from command line
  if ParamCount >= 1 then
    Iterations := StrToIntDef(ParamStr(1), 1000)
  else
    Iterations := 1000;

  // Initialize OpenSSL
  Write('Initializing OpenSSL... ');
  try
    LoadOpenSSLCore;
    GOpenSSLReady := Assigned(BIO_new_mem_buf) and Assigned(BIO_free);
    if GOpenSSLReady then
      WriteLn('OK')
    else
    begin
      WriteLn('FAILED (required functions not available)');
      WriteLn('OpenSSL fuzz testing requires a working OpenSSL installation.');
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      WriteLn('FAILED: ', E.Message);
      WriteLn('OpenSSL fuzz testing requires a working OpenSSL installation.');
      Halt(1);
    end;
  end;
  WriteLn;

  // Create fuzzer
  Fuzzer := TFuzzer.Create;
  try
    Fuzzer.MaxInputSize := 4096;  // Certificate data can be larger
    Fuzzer.MinInputSize := 0;
    Fuzzer.Verbose := False;

    // Register targets
    WriteLn('Registering fuzz targets...');
    Fuzzer.RegisterTarget('pem_decode', @FuzzPEMDecode);
    Fuzzer.RegisterTarget('der_parse', @FuzzDERParse);
    Fuzzer.RegisterTarget('bio_memory', @FuzzBIOMemory);
    WriteLn;

    // Run fuzzing
    Fuzzer.Run(Iterations);

    // Save results
    Fuzzer.SaveStatsToFile('fuzz_openssl_results.txt');
    WriteLn('Results saved to: fuzz_openssl_results.txt');

  finally
    Fuzzer.Free;
  end;

  WriteLn;
  WriteLn('OpenSSL fuzz testing complete.');
end.
