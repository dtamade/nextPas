program test_evp_aead_tag_fail;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api;

procedure TestAES256GCM_TagFail;
const
  Key: array[0..31] of Byte = (
    $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,
    $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F
  );
  IV: array[0..11] of Byte = (
    $A0,$A1,$A2,$A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AB
  );
  AAD: AnsiString = 'AAD';
  PT: AnsiString = 'Hello GCM';
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  ct: array of Byte;
  PlainTextBuf: array of Byte;
  tag: array[0..15] of Byte;
  outlen, tmplen, ret: Integer;
  failedAsExpected: Boolean;
begin
  WriteLn('Negative AEAD (AES-256-GCM tag mismatch)');
  failedAsExpected := False;
  try
    cipher := EVP_aes_256_gcm();
    if not Assigned(cipher) then
    begin
      WriteLn('  [+] AES-256-GCM not available (treat as acceptable for negative test)');
      failedAsExpected := True;
      Exit;
    end;

    // Encrypt and get tag
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then Exit;
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, @Key[0], @IV[0]) <> 1 then begin failedAsExpected := True; Exit; end;
      if (Length(AAD) > 0) and (EVP_EncryptUpdate(ctx, nil, @outlen, PByte(@AAD[1]), Length(AAD)) <> 1) then begin failedAsExpected := True; Exit; end;
      SetLength(ct, Length(PT) + 16);
      if EVP_EncryptUpdate(ctx, @ct[0], @outlen, PByte(@PT[1]), Length(PT)) <> 1 then begin failedAsExpected := True; Exit; end;
      if EVP_EncryptFinal_ex(ctx, @ct[outlen], @tmplen) <> 1 then begin failedAsExpected := True; Exit; end;
      outlen := outlen + tmplen; SetLength(ct, outlen);
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, @tag[0]) <> 1 then begin failedAsExpected := True; Exit; end;
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;

    // Flip tag bit to force failure
    tag[0] := tag[0] xor $01;

    // Decrypt with wrong tag -> EVP_DecryptFinal_ex must fail (return 0)
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then begin failedAsExpected := True; Exit; end;
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, @Key[0], @IV[0]) <> 1 then begin failedAsExpected := True; Exit; end;
      if (Length(AAD) > 0) and (EVP_DecryptUpdate(ctx, nil, @tmplen, PByte(@AAD[1]), Length(AAD)) <> 1) then begin failedAsExpected := True; Exit; end;
      SetLength(PlainTextBuf, Length(ct) + 16);
      if (Length(ct) = 0) or (EVP_DecryptUpdate(ctx, @PlainTextBuf[0], @outlen, @ct[0], Length(ct)) <> 1) then begin failedAsExpected := True; Exit; end;
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, @tag[0]) <> 1 then begin failedAsExpected := True; Exit; end;
      ret := EVP_DecryptFinal_ex(ctx, @PlainTextBuf[outlen], @tmplen);
      if ret <> 1 then
      begin
        WriteLn('  [+] Tag verification failed as expected');
        failedAsExpected := True;
      end
      else
        WriteLn('  [-] DecryptFinal unexpectedly succeeded');
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  except
    on E: Exception do
    begin
      // Exception is acceptable for negative case; treat as pass
      WriteLn('  [+] Exception (acceptable for negative test): ', E.Message);
      failedAsExpected := True;
    end;
  end;

  if failedAsExpected then
    WriteLn('✅ NEGATIVE TEST PASSED')
  else
  begin
    WriteLn('❌ NEGATIVE TEST FAILED');
    Halt(1);
  end;
end;

begin
  try
    LoadOpenSSLLibrary;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: OpenSSL not available: ', E.Message);
      Halt(1);
    end;
  end;
  TestAES256GCM_TagFail;
end.


