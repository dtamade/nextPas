program test_encrypted_private_key;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.pem,
  nextpas.core.tls.crypto.pkcs8;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then
  begin
    WriteLn('  PASS: ', AMsg);
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  FAIL: ', AMsg);
    Inc(GFailCount);
  end;
end;

function ReadFileToString(const AFileName: string): string;
var
  LStream: TFileStream;
  LBytes: TBytes;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead);
  try
    SetLength(LBytes, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LBytes[0], LStream.Size);
    Result := TEncoding.UTF8.GetString(LBytes);
  finally
    LStream.Free;
  end;
end;

procedure TestPKCS8Decryption;
var
  LReader: TPEMReader;
  LBlock: TPEMBlock;
  LDecrypted: TBytes;
  LError: string;
  LPEMText: string;
begin
  WriteLn('--- PKCS#8 Encrypted Private Key ---');

  LPEMText := ReadFileToString('tests/fixtures/test_pkcs8_enc.pem');
  LReader := TPEMReader.Create;
  try
    LReader.LoadFromString(LPEMText);
    Check(LReader.BlockCount = 1, 'PEM has 1 block');
    LBlock := LReader.GetBlock(0);
    Check(LBlock.BlockType = pemEncryptedPrivateKey, 'Block type is ENCRYPTED PRIVATE KEY');
    Check(Length(LBlock.Data) > 0, 'Block has DER data');

    Check(
      TryDecryptPKCS8EncryptedPrivateKey(LBlock.Data, 'testpass123', LDecrypted, LError),
      'Decryption succeeds with correct password'
    );
    Check(Length(LDecrypted) > 0, 'Decrypted data is non-empty');
    // PKCS#8 PrivateKeyInfo starts with SEQUENCE tag
    Check(LDecrypted[0] = $30, 'Decrypted data starts with SEQUENCE (0x30)');

    Check(
      not TryDecryptPKCS8EncryptedPrivateKey(LBlock.Data, 'wrongpass', LDecrypted, LError),
      'Decryption fails with wrong password'
    );
  finally
    LReader.Free;
  end;
end;

procedure TestTraditionalPEMDecryption;
var
  LReader: TPEMReader;
  LBlock: TPEMBlock;
  LDecrypted: TBytes;
  LError: string;
  LPEMText: string;
  LDEKInfo, LAlgorithm, LIVHex: string;
  LCommaPos: Integer;
  I: Integer;
begin
  WriteLn('--- Traditional OpenSSL Encrypted PEM ---');

  LPEMText := ReadFileToString('tests/fixtures/test_trad_enc.pem');
  LReader := TPEMReader.Create;
  try
    LReader.LoadFromString(LPEMText);
    Check(LReader.BlockCount = 1, 'PEM has 1 block');
    LBlock := LReader.GetBlock(0);
    Check(LBlock.BlockType = pemRSAPrivateKey, 'Block type is RSA PRIVATE KEY');
    Check(LBlock.IsEncrypted, 'Block is marked as encrypted');
    Check(LBlock.Headers <> nil, 'Block has headers');

    // Extract DEK-Info
    LDEKInfo := '';
    for I := 0 to LBlock.Headers.Count - 1 do
    begin
      if Pos('DEK-Info:', LBlock.Headers[I]) = 1 then
      begin
        LDEKInfo := Trim(Copy(LBlock.Headers[I], 10, Length(LBlock.Headers[I])));
        Break;
      end;
    end;
    Check(LDEKInfo <> '', 'DEK-Info header found');

    LCommaPos := Pos(',', LDEKInfo);
    LAlgorithm := Copy(LDEKInfo, 1, LCommaPos - 1);
    LIVHex := Copy(LDEKInfo, LCommaPos + 1, Length(LDEKInfo));
    Check(LAlgorithm = 'AES-256-CBC', 'Algorithm is AES-256-CBC');
    Check(Length(LIVHex) = 32, 'IV is 32 hex chars');

    Check(
      TryDecryptTraditionalPEMPrivateKey(LBlock.Data, LAlgorithm, LIVHex, 'testpass123', LDecrypted, LError),
      'Decryption succeeds with correct password'
    );
    Check(Length(LDecrypted) > 0, 'Decrypted data is non-empty');
    Check(LDecrypted[0] = $30, 'Decrypted data starts with SEQUENCE (0x30)');

    Check(
      not TryDecryptTraditionalPEMPrivateKey(LBlock.Data, LAlgorithm, LIVHex, 'wrongpass', LDecrypted, LError),
      'Decryption fails with wrong password'
    );
  finally
    LReader.Free;
  end;
end;

procedure TestPBKDF2RFC6070;
var
  LKey: TBytes;
  LExpected: string;
  LActual: string;
  I: Integer;
begin
  WriteLn('--- PBKDF2-HMAC-SHA256 RFC Vector ---');
  // RFC 7914 test: password="passwd", salt="salt", c=1, dkLen=64
  // We test a simpler case: password="password", salt="salt", c=1, dkLen=32
  LKey := PBKDF2_HMAC_SHA256(
    TEncoding.UTF8.GetBytes('password'),
    TEncoding.UTF8.GetBytes('salt'),
    1, 32
  );
  // Known vector from RFC 7914 / various test suites
  LExpected := '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b';
  LActual := '';
  for I := 0 to High(LKey) do
    LActual := LActual + LowerCase(IntToHex(LKey[I], 2));
  Check(LActual = LExpected, 'PBKDF2(password, salt, 1, 32) matches RFC vector');
end;

begin
  WriteLn('=== Encrypted Private Key Tests ===');
  TestPBKDF2RFC6070;
  TestPKCS8Decryption;
  TestTraditionalPEMDecryption;
  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
