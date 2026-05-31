program test_modules_quick_validation;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.err;

type
  TModuleTest = record
    Name: string;
    Available: Boolean;
    Note: string;
  end;

var
  Results: array of TModuleTest;

procedure AddResult(const Name: string; Available: Boolean; const Note: string = '');
begin
  SetLength(Results, Length(Results) + 1);
  Results[High(Results)].Name := Name;
  Results[High(Results)].Available := Available;
  Results[High(Results)].Note := Note;
end;

// Quick validation - just check if functions can be called
function TestBN: Boolean;
var
  bn: PBIGNUM;
begin
  Result := False;
  if not Assigned(BN_new) then Exit;
  bn := BN_new();
  if bn <> nil then
  begin
    BN_free(bn);
    Result := True;
  end;
end;


function TestBIO: Boolean;
var
  bio: PBIO;
begin
  Result := False;
  if not Assigned(BIO_new) then Exit;
  if not Assigned(BIO_s_mem) then Exit;
  bio := BIO_new(BIO_s_mem());
  if bio <> nil then
  begin
    BIO_free(bio);
    Result := True;
  end;
end;


function TestRAND: Boolean;
var
  buf: array[0..15] of Byte;
begin
  Result := False;
  if not Assigned(RAND_bytes) then Exit;
  Result := RAND_bytes(@buf[0], 16) = 1;
end;

function TestERR: Boolean;
begin
  Result := Assigned(ERR_get_error);
  if Result then
    ERR_clear_error(); // Clear any pending errors
end;


procedure RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('  Quick Module Validation');
  WriteLn('  (Header Translation Verification)');
  WriteLn('========================================');
  WriteLn;
  
  Write('BN (Big Number)... ');
  if TestBN then
  begin
    WriteLn('OK');
    AddResult('BN', True, 'Big number arithmetic');
  end
  else
  begin
    WriteLn('FAIL');
    AddResult('BN', False, 'Functions not available');
  end;
  
  Write('BIO... ');
  if TestBIO then
  begin
    WriteLn('OK');
    AddResult('BIO', True, 'Basic I/O abstraction');
  end
  else
  begin
    WriteLn('FAIL');
    AddResult('BIO', False, 'Functions not available');
  end;
  
  Write('RAND... ');
  if TestRAND then
  begin
    WriteLn('OK');
    AddResult('RAND', True, 'Random number generator');
  end
  else
  begin
    WriteLn('FAIL');
    AddResult('RAND', False, 'Functions not available');
  end;
  
  Write('ERR... ');
  if TestERR then
  begin
    WriteLn('OK');
    AddResult('ERR', True, 'Error handling');
  end
  else
  begin
    WriteLn('FAIL');
    AddResult('ERR', False, 'Functions not available');
  end;
end;

procedure PrintSummary;
var
  i, Available, Total: Integer;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('Summary');
  WriteLn('========================================');
  WriteLn;
  
  Available := 0;
  Total := Length(Results);
  
  for i := 0 to High(Results) do
    if Results[i].Available then
      Inc(Available);
  
  WriteLn('Modules tested: ', Total);
  WriteLn('Available: ', Available, ' (', FormatFloat('0.0', (Available/Total)*100), '%)');
  WriteLn('Not available: ', Total - Available);
  WriteLn;
  
  if Available = Total then
    WriteLn('SUCCESS: All module headers translated correctly!')
  else
    WriteLn('WARNING: Some modules have issues');
  
  WriteLn;
  WriteLn('Detailed Results:');
  WriteLn('----------------------------------------');
  for i := 0 to High(Results) do
  begin
    if Results[i].Available then
      WriteLn('  [OK]   ', Results[i].Name:15, ' - ', Results[i].Note)
    else
      WriteLn('  [FAIL] ', Results[i].Name:15, ' - ', Results[i].Note);
  end;
end;

begin
  try
    WriteLn('Loading OpenSSL...');
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      Halt(1);
    end;
    WriteLn('OpenSSL loaded successfully');
    WriteLn;

    // Load module functions - handled automatically by LoadOpenSSLLibrary
    LoadEVP(GetCryptoLibHandle);
    // LoadBN, LoadBIO, LoadRANDFunctions, LoadERRFunctions are deprecated

    RunAllTests;
    PrintSummary;
    
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
