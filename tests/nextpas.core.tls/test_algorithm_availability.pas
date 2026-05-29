program test_algorithm_availability;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

var
  TotalAlgs, AvailableAlgs: Integer;

procedure CheckAlgorithm(const AlgName, Category: string);
var
  md: PEVP_MD;
  cipher: PEVP_CIPHER;
  Available: Boolean;
begin
  Inc(TotalAlgs);
  Available := False;
  
  if Category = 'hash' then
  begin
    md := EVP_get_digestbyname(PAnsiChar(AlgName));
    Available := (md <> nil);
  end
  else if Category = 'cipher' then
  begin
    cipher := EVP_get_cipherbyname(PAnsiChar(AlgName));
    Available := (cipher <> nil);
  end;
  
  if Available then
  begin
    WriteLn('  [OK]   ', AlgName:25, ' (', Category, ')');
    Inc(AvailableAlgs);
  end
  else
    WriteLn('  [N/A]  ', AlgName:25, ' (', Category, ')');
end;

begin
  WriteLn('========================================');
  WriteLn('  Algorithm Availability Check');
  WriteLn('  (Quick Header Translation Verification)');
  WriteLn('========================================');
  WriteLn;
  
  try
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL');
      Halt(1);
    end;
    
    LoadEVP(GetCryptoLibHandle);
    WriteLn('OpenSSL loaded successfully');
    WriteLn;
    
    TotalAlgs := 0;
    AvailableAlgs := 0;
    
    WriteLn('Hash Algorithms:');
    WriteLn('----------------------------------------');
    CheckAlgorithm('md5', 'hash');
    CheckAlgorithm('sha1', 'hash');
    CheckAlgorithm('sha256', 'hash');
    CheckAlgorithm('sha512', 'hash');
    CheckAlgorithm('sha3-256', 'hash');
    CheckAlgorithm('sha3-512', 'hash');
    CheckAlgorithm('blake2b512', 'hash');
    CheckAlgorithm('blake2s256', 'hash');
    CheckAlgorithm('ripemd160', 'hash');
    CheckAlgorithm('whirlpool', 'hash');
    CheckAlgorithm('sm3', 'hash');
    WriteLn;
    
    WriteLn('Symmetric Ciphers:');
    WriteLn('----------------------------------------');
    CheckAlgorithm('aes-128-cbc', 'cipher');
    CheckAlgorithm('aes-256-cbc', 'cipher');
    CheckAlgorithm('aes-128-gcm', 'cipher');
    CheckAlgorithm('aes-256-gcm', 'cipher');
    CheckAlgorithm('chacha20', 'cipher');
    CheckAlgorithm('chacha20-poly1305', 'cipher');
    CheckAlgorithm('des-ede3-cbc', 'cipher');
    CheckAlgorithm('camellia-256-cbc', 'cipher');
    CheckAlgorithm('sm4-cbc', 'cipher');
    CheckAlgorithm('bf-cbc', 'cipher');
    CheckAlgorithm('cast5-cbc', 'cipher');
    CheckAlgorithm('rc4', 'cipher');
    WriteLn;
    
    WriteLn('========================================');
    WriteLn('Summary:');
    WriteLn('----------------------------------------');
    WriteLn('Total tested:    ', TotalAlgs);
    WriteLn('Available:       ', AvailableAlgs, ' (', 
            FormatFloat('0.0', (AvailableAlgs/TotalAlgs)*100), '%)');
    WriteLn('Not available:   ', TotalAlgs - AvailableAlgs);
    WriteLn('========================================');
    WriteLn;
    
    if AvailableAlgs >= 15 then  // Expect at least 15 modern algorithms
      WriteLn('SUCCESS: Core algorithms available!')
    else
      WriteLn('WARNING: Some core algorithms missing');
      
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.Message);
      Halt(1);
    end;
  end;
end.
