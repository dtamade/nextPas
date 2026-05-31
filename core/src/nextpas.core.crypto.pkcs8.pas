unit nextpas.core.crypto.pkcs8;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function TryDecryptPKCS8EncryptedPrivateKey(
  const AEncryptedDER: TBytes;
  const APassword: string;
  out ADecryptedDER: TBytes;
  out AError: string
): Boolean;

function TryDecryptTraditionalPEMPrivateKey(
  const AEncryptedDER: TBytes;
  const AAlgorithm: string;
  const AIVHex: string;
  const APassword: string;
  out ADecryptedDER: TBytes;
  out AError: string
): Boolean;

function PBKDF2_HMAC_SHA256(
  const APassword, ASalt: TBytes;
  AIterations, AKeyLen: Integer
): TBytes;

implementation

uses
  Math,
  nextpas.core.tls.asn1,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.aescbc,
  nextpas.core.crypto.hash;

const
  OID_PBES2 = '1.2.840.113549.1.5.13';
  OID_PBKDF2 = '1.2.840.113549.1.5.12';
  OID_HMAC_SHA256 = '1.2.840.113549.2.9';
  OID_HMAC_SHA1 = '1.2.840.113549.2.7';
  OID_AES_128_CBC = '2.16.840.1.101.3.4.1.2';
  OID_AES_192_CBC = '2.16.840.1.101.3.4.1.22';
  OID_AES_256_CBC = '2.16.840.1.101.3.4.1.42';
  OID_DES_EDE3_CBC = '1.2.840.113549.3.7';

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function MD5Hash(const AData: TBytes): TBytes;
var
  LCtx: TMD5Context;
begin
  LCtx := TMD5Context.Create;
  try
    LCtx.Update(AData);
    Result := LCtx.Final;
  finally
    LCtx.Free;
  end;
end;

function HMAC_SHA1(const AKey, AData: TBytes): TBytes;
var
  LCtx: TSHA1Context;
  LKeyPad, LIPad, LOPad: TBytes;
  LActualKey: TBytes;
  I: Integer;
begin
  if Length(AKey) > 64 then
  begin
    LCtx := TSHA1Context.Create;
    try
      LCtx.Update(AKey);
      LActualKey := LCtx.Final;
    finally
      LCtx.Free;
    end;
  end
  else
    LActualKey := Copy(AKey);

  SetLength(LKeyPad, 64);
  FillChar(LKeyPad[0], 64, 0);
  if Length(LActualKey) > 0 then
    Move(LActualKey[0], LKeyPad[0], Length(LActualKey));

  SetLength(LIPad, 64);
  SetLength(LOPad, 64);
  for I := 0 to 63 do
  begin
    LIPad[I] := LKeyPad[I] xor $36;
    LOPad[I] := LKeyPad[I] xor $5C;
  end;

  LCtx := TSHA1Context.Create;
  try
    LCtx.Update(LIPad);
    LCtx.Update(AData);
    Result := LCtx.Final;
  finally
    LCtx.Free;
  end;

  LCtx := TSHA1Context.Create;
  try
    LCtx.Update(LOPad);
    LCtx.Update(Result);
    Result := LCtx.Final;
  finally
    LCtx.Free;
  end;
end;

function PBKDF2_HMAC_SHA256(
  const APassword, ASalt: TBytes;
  AIterations, AKeyLen: Integer
): TBytes;
var
  LBlockCount, LBlock, LIter, I: Integer;
  LInput, LU, LT: TBytes;
  LBlockIdx: array[0..3] of Byte;
begin
  SetLength(Result, AKeyLen);
  LBlockCount := (AKeyLen + 31) div 32;

  for LBlock := 1 to LBlockCount do
  begin
    LBlockIdx[0] := Byte(LBlock shr 24);
    LBlockIdx[1] := Byte(LBlock shr 16);
    LBlockIdx[2] := Byte(LBlock shr 8);
    LBlockIdx[3] := Byte(LBlock);

    SetLength(LInput, Length(ASalt) + 4);
    if Length(ASalt) > 0 then
      Move(ASalt[0], LInput[0], Length(ASalt));
    Move(LBlockIdx[0], LInput[Length(ASalt)], 4);

    LU := HMAC_SHA256(APassword, LInput);
    LT := Copy(LU);

    for LIter := 2 to AIterations do
    begin
      LU := HMAC_SHA256(APassword, LU);
      for I := 0 to 31 do
        LT[I] := LT[I] xor LU[I];
    end;

    for I := 0 to Min(32, AKeyLen - (LBlock - 1) * 32) - 1 do
      Result[(LBlock - 1) * 32 + I] := LT[I];
  end;
end;

function PBKDF2_HMAC_SHA1(
  const APassword, ASalt: TBytes;
  AIterations, AKeyLen: Integer
): TBytes;
var
  LBlockCount, LBlock, LIter, I: Integer;
  LInput, LU, LT: TBytes;
  LBlockIdx: array[0..3] of Byte;
begin
  SetLength(Result, AKeyLen);
  LBlockCount := (AKeyLen + 19) div 20;

  for LBlock := 1 to LBlockCount do
  begin
    LBlockIdx[0] := Byte(LBlock shr 24);
    LBlockIdx[1] := Byte(LBlock shr 16);
    LBlockIdx[2] := Byte(LBlock shr 8);
    LBlockIdx[3] := Byte(LBlock);

    SetLength(LInput, Length(ASalt) + 4);
    if Length(ASalt) > 0 then
      Move(ASalt[0], LInput[0], Length(ASalt));
    Move(LBlockIdx[0], LInput[Length(ASalt)], 4);

    LU := HMAC_SHA1(APassword, LInput);
    LT := Copy(LU);

    for LIter := 2 to AIterations do
    begin
      LU := HMAC_SHA1(APassword, LU);
      for I := 0 to 19 do
        LT[I] := LT[I] xor LU[I];
    end;

    for I := 0 to Min(20, AKeyLen - (LBlock - 1) * 20) - 1 do
      Result[(LBlock - 1) * 20 + I] := LT[I];
  end;
end;

function RemovePKCS7Padding(const AData: TBytes; out AResult: TBytes; out AError: string): Boolean;
var
  LPadLen: Integer;
  I: Integer;
  LBad: Byte;
begin
  Result := False;
  AError := '';

  if Length(AData) = 0 then
  begin
    AError := 'Empty data cannot have PKCS#7 padding';
    Exit;
  end;

  LPadLen := AData[High(AData)];
  if (LPadLen < 1) or (LPadLen > 16) or (LPadLen > Length(AData)) then
  begin
    AError := 'Invalid PKCS#7 padding value';
    Exit;
  end;

  LBad := 0;
  for I := Length(AData) - LPadLen to High(AData) do
    LBad := LBad or (AData[I] xor Byte(LPadLen));
  if LBad <> 0 then
  begin
    AError := 'Corrupted PKCS#7 padding';
    Exit;
  end;

  AResult := Copy(AData, 0, Length(AData) - LPadLen);
  Result := True;
end;

function TryDecryptPKCS8EncryptedPrivateKey(
  const AEncryptedDER: TBytes;
  const APassword: string;
  out ADecryptedDER: TBytes;
  out AError: string
): Boolean;
var
  LReader: TASN1Reader;
  LRoot, LAlgSeq, LPBES2Params, LKDFSeq, LKDFParams, LEncScheme: TASN1Node;
  LPRFNode: TASN1Node;
  LSalt, LIV, LEncData, LKey, LDecrypted: TBytes;
  LIterations, LKeyLen: Integer;
  LAlgOID, LKDFOID, LEncOID, LPRFOID: string;
  LPasswordBytes: TBytes;
  LUseSHA256: Boolean;
begin
  Result := False;
  SetLength(ADecryptedDER, 0);
  AError := '';

  LReader := TASN1Reader.Create(AEncryptedDER);
  LRoot := nil;
  try
    try
      LRoot := LReader.Parse;
    except
      on E: Exception do
      begin
        AError := 'Failed to parse EncryptedPrivateKeyInfo: ' + E.Message;
        Exit;
      end;
    end;

    if (LRoot = nil) or (not LRoot.IsSequence) or (LRoot.ChildCount < 2) then
    begin
      AError := 'EncryptedPrivateKeyInfo must be a SEQUENCE with at least 2 elements';
      LRoot.Free;
      Exit;
    end;

    LAlgSeq := LRoot.GetChild(0);
    if (not LAlgSeq.IsSequence) or (LAlgSeq.ChildCount < 2) then
    begin
      AError := 'encryptionAlgorithm must be a SEQUENCE';
      LRoot.Free;
      Exit;
    end;

    LAlgOID := LAlgSeq.GetChild(0).AsOID;
    if LAlgOID <> OID_PBES2 then
    begin
      AError := 'Unsupported encryption algorithm: ' + LAlgOID + ' (only PBES2 supported)';
      LRoot.Free;
      Exit;
    end;

    LPBES2Params := LAlgSeq.GetChild(1);
    if (not LPBES2Params.IsSequence) or (LPBES2Params.ChildCount < 2) then
    begin
      AError := 'PBES2-params must be a SEQUENCE with KDF and encryption scheme';
      LRoot.Free;
      Exit;
    end;

    // Parse KDF
    LKDFSeq := LPBES2Params.GetChild(0);
    if (not LKDFSeq.IsSequence) or (LKDFSeq.ChildCount < 2) then
    begin
      AError := 'keyDerivationFunc must be a SEQUENCE';
      LRoot.Free;
      Exit;
    end;

    LKDFOID := LKDFSeq.GetChild(0).AsOID;
    if LKDFOID <> OID_PBKDF2 then
    begin
      AError := 'Unsupported KDF: ' + LKDFOID + ' (only PBKDF2 supported)';
      LRoot.Free;
      Exit;
    end;

    LKDFParams := LKDFSeq.GetChild(1);
    if (not LKDFParams.IsSequence) or (LKDFParams.ChildCount < 2) then
    begin
      AError := 'PBKDF2-params must have salt and iteration count';
      LRoot.Free;
      Exit;
    end;

    LSalt := LKDFParams.GetChild(0).AsOctetString;
    LIterations := Integer(LKDFParams.GetChild(1).AsInteger);

    // Determine PRF (default is HMAC-SHA1)
    LUseSHA256 := False;
    if LKDFParams.ChildCount >= 4 then
    begin
      LPRFNode := LKDFParams.GetChild(LKDFParams.ChildCount - 1);
      if LPRFNode.IsSequence and (LPRFNode.ChildCount >= 1) then
      begin
        LPRFOID := LPRFNode.GetChild(0).AsOID;
        if LPRFOID = OID_HMAC_SHA256 then
          LUseSHA256 := True;
      end;
    end
    else if LKDFParams.ChildCount >= 3 then
    begin
      LPRFNode := LKDFParams.GetChild(2);
      if LPRFNode.IsSequence and (LPRFNode.ChildCount >= 1) then
      begin
        LPRFOID := LPRFNode.GetChild(0).AsOID;
        if LPRFOID = OID_HMAC_SHA256 then
          LUseSHA256 := True;
      end;
    end;

    // Parse encryption scheme
    LEncScheme := LPBES2Params.GetChild(1);
    if (not LEncScheme.IsSequence) or (LEncScheme.ChildCount < 2) then
    begin
      AError := 'encryptionScheme must be a SEQUENCE';
      LRoot.Free;
      Exit;
    end;

    LEncOID := LEncScheme.GetChild(0).AsOID;
    LIV := LEncScheme.GetChild(1).AsOctetString;

    if LEncOID = OID_AES_256_CBC then
      LKeyLen := 32
    else if LEncOID = OID_AES_128_CBC then
      LKeyLen := 16
    else if LEncOID = OID_AES_192_CBC then
      LKeyLen := 24
    else
    begin
      AError := 'Unsupported encryption scheme: ' + LEncOID;
      LRoot.Free;
      Exit;
    end;

    // Get encrypted data
    LEncData := LRoot.GetChild(1).AsOctetString;
    LRoot.Free;
    LRoot := nil;
  finally
    LReader.Free;
    if LRoot <> nil then
      LRoot.Free;
  end;

  // Derive key
  LPasswordBytes := TEncoding.UTF8.GetBytes(APassword);
  if LUseSHA256 then
    LKey := PBKDF2_HMAC_SHA256(LPasswordBytes, LSalt, LIterations, LKeyLen)
  else
    LKey := PBKDF2_HMAC_SHA1(LPasswordBytes, LSalt, LIterations, LKeyLen);

  // Decrypt
  if (Length(LEncData) = 0) or (Length(LEncData) mod 16 <> 0) then
  begin
    AError := 'Encrypted data length is not a multiple of AES block size';
    Exit;
  end;

  LDecrypted := AESCBCDecryptNoPadding(LKey, LIV, LEncData);

  if not RemovePKCS7Padding(LDecrypted, ADecryptedDER, AError) then
  begin
    AError := 'Decryption failed (wrong password?): ' + AError;
    Exit;
  end;

  Result := True;
end;


function EVP_BytesToKey_MD5(
  const APassword: string;
  const AIV: TBytes;
  AKeyLen: Integer
): TBytes;
var
  LPassBytes, LInput, LHash: TBytes;
  LOffset: Integer;
begin
  LPassBytes := TEncoding.UTF8.GetBytes(APassword);
  SetLength(Result, AKeyLen);
  LOffset := 0;

  SetLength(LInput, Length(LPassBytes) + 8);
  Move(LPassBytes[0], LInput[0], Length(LPassBytes));
  Move(AIV[0], LInput[Length(LPassBytes)], 8);
  LHash := MD5Hash(LInput);

  Move(LHash[0], Result[LOffset], Min(16, AKeyLen));
  Inc(LOffset, 16);

  while LOffset < AKeyLen do
  begin
    SetLength(LInput, 16 + Length(LPassBytes) + 8);
    Move(LHash[0], LInput[0], 16);
    Move(LPassBytes[0], LInput[16], Length(LPassBytes));
    Move(AIV[0], LInput[16 + Length(LPassBytes)], 8);
    LHash := MD5Hash(LInput);
    Move(LHash[0], Result[LOffset], Min(16, AKeyLen - LOffset));
    Inc(LOffset, 16);
  end;
end;

function TryDecryptTraditionalPEMPrivateKey(
  const AEncryptedDER: TBytes;
  const AAlgorithm: string;
  const AIVHex: string;
  const APassword: string;
  out ADecryptedDER: TBytes;
  out AError: string
): Boolean;
var
  LIV, LKey, LDecrypted: TBytes;
  LKeyLen: Integer;
  LAlgUpper: string;
begin
  Result := False;
  SetLength(ADecryptedDER, 0);
  AError := '';

  LAlgUpper := UpperCase(AAlgorithm);
  if LAlgUpper = 'AES-256-CBC' then
    LKeyLen := 32
  else if LAlgUpper = 'AES-128-CBC' then
    LKeyLen := 16
  else if LAlgUpper = 'AES-192-CBC' then
    LKeyLen := 24
  else
  begin
    AError := 'Unsupported DEK-Info algorithm: ' + AAlgorithm;
    Exit;
  end;

  if Length(AIVHex) <> 32 then
  begin
    AError := 'DEK-Info IV must be 32 hex characters (16 bytes)';
    Exit;
  end;

  try
    LIV := HexToBytes(AIVHex);
  except
    on E: Exception do
    begin
      AError := 'Invalid DEK-Info IV hex: ' + E.Message;
      Exit;
    end;
  end;

  if (Length(AEncryptedDER) = 0) or (Length(AEncryptedDER) mod 16 <> 0) then
  begin
    AError := 'Encrypted data length is not a multiple of AES block size';
    Exit;
  end;

  LKey := EVP_BytesToKey_MD5(APassword, LIV, LKeyLen);
  LDecrypted := AESCBCDecryptNoPadding(LKey, LIV, AEncryptedDER);

  if not RemovePKCS7Padding(LDecrypted, ADecryptedDER, AError) then
  begin
    AError := 'Decryption failed (wrong password?): ' + AError;
    Exit;
  end;

  Result := True;
end;

end.
