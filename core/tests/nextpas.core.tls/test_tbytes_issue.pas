program test_tbytes_issue;

{$mode objfpc}{$H+}

{
  测试TBytes参数传递问题
}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp;

// 使用TBytes参数
function TestWithTBytes(const AKey, AIV: TBytes): Boolean;
var
  LCipher: PEVP_CIPHER;
  LCtx: PEVP_CIPHER_CTX;
begin
  Result := False;
  
  WriteLn('In TestWithTBytes:');
  WriteLn('  AKey length: ', Length(AKey));
  WriteLn('  AIV length: ', Length(AIV));
  WriteLn('  AKey[0] addr: ', PtrUInt(@AKey[0]));
  

  WriteLn('  Getting cipher...');
  LCipher := EVP_aes_256_gcm();
  if LCipher = nil then
  begin
    WriteLn('  Cipher is nil!');
    Exit;
  end;
  WriteLn('  ✓ Cipher OK');
  
  WriteLn('  Creating context...');
  LCtx := EVP_CIPHER_CTX_new();
  if LCtx = nil then
  begin
    WriteLn('  Context is nil!');
    Exit;
  end;
  WriteLn('  ✓ Context OK');
  
  WriteLn('  Initializing...');
  if EVP_EncryptInit_ex(LCtx, LCipher, nil, @AKey[0], @AIV[0]) <> 1 then
  begin
    WriteLn('  Init failed!');
    EVP_CIPHER_CTX_free(LCtx);
    Exit;
  end;
  WriteLn('  ✓ Init OK');
  
  EVP_CIPHER_CTX_free(LCtx);
  Result := True;
end;

var
  LKey, LIV: TBytes;
begin
  WriteLn('=== TBytes Parameter Test ===');
  WriteLn;
  
  try
    LoadOpenSSLCore();
    LoadEVP(GetCryptoLibHandle);
    WriteLn('✓ OpenSSL loaded');
    WriteLn;
    
    SetLength(LKey, 32);
    SetLength(LIV, 12);
    FillChar(LKey[0], 32, $AA);
    FillChar(LIV[0], 12, $BB);
    
    WriteLn('Calling TestWithTBytes...');
    if TestWithTBytes(LKey, LIV) then
      WriteLn('✓ SUCCESS!')
    else
      WriteLn('✗ FAILED');
    
  except
    on E: Exception do
    begin
      WriteLn('✗ EXCEPTION: ', E.Message);
      Halt(1);
    end;
  end;
end.
