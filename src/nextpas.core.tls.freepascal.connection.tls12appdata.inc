function TFreePascalConnection.DoRead(var ABuffer; ACount: Integer): Integer;
var
  LFragment: TBytes;
  LCopyLen: Integer;
  LHeader: TBytes;
  LLen, LRead: Integer;
  LContentType: Byte;
  LRecvData, LDecrypted: TBytes;
  LDecError: string;
  LReadKey, LReadIV, LReadMACKey: TBytes;
  LReadSeqNum: PQWord;
begin
  if not FHandshakeComplete then
  begin
    MarkPrecondition('TLS read');
    Exit(-1);
  end;

  if ACount <= 0 then
    Exit(0);

  if FProtocolVersion = sslProtocolTLS12 then
  begin
    if FIsServerMode then
    begin
      LReadKey := FTLS12State.ClientWriteKey;
      LReadIV := FTLS12State.ClientWriteIV;
      LReadMACKey := FTLS12State.ClientWriteMACKey;
      LReadSeqNum := @FTLS12State.ClientSeqNum;
    end
    else
    begin
      LReadKey := FTLS12State.ServerWriteKey;
      LReadIV := FTLS12State.ServerWriteIV;
      LReadMACKey := FTLS12State.ServerWriteMACKey;
      LReadSeqNum := @FTLS12State.ServerSeqNum;
    end;

    while Length(FTLS12ReadBuffer) = 0 do
    begin
      SetLength(LHeader, 5);
      LRead := FStream.Read(LHeader[0], 5);
      if LRead < 5 then
        Exit(0);

      LContentType := LHeader[0];
      LLen := (Integer(LHeader[3]) shl 8) or Integer(LHeader[4]);

      if LContentType <> TLS12_CONTENT_APPLICATION_DATA then
        Exit(-1);
      if (LLen <= 0) or (LLen > TLS12_RECORD_MAX_LENGTH + 256) then
        Exit(-1);

      SetLength(LRecvData, LLen);
      LRead := FStream.Read(LRecvData[0], LLen);
      if LRead < LLen then
        Exit(-1);

      if Length(LReadMACKey) > 0 then
      begin
        if Length(LReadMACKey) > 32 then
        begin
          if not TLS12CBCDecrypt_SHA384(LReadKey, LReadMACKey,
            LReadSeqNum^, TLS12_CONTENT_APPLICATION_DATA, LRecvData, LDecrypted, LDecError) then
            Exit(-1);
        end
        else
        begin
          if not TLS12CBCDecrypt_SHA256(LReadKey, LReadMACKey,
            LReadSeqNum^, TLS12_CONTENT_APPLICATION_DATA, LRecvData, LDecrypted, LDecError) then
            Exit(-1);
        end;
      end
      else if Length(LReadIV) = 12 then
      begin
        if not TLS12ChaCha20Poly1305DecryptRecord(LReadKey, LReadIV,
          LReadSeqNum^, TLS12_CONTENT_APPLICATION_DATA, LRecvData, LDecrypted, LDecError) then
          Exit(-1);
      end
      else
      begin
        if not TLS12GCMDecryptRecord(LReadKey, LReadIV,
          LReadSeqNum^, TLS12_CONTENT_APPLICATION_DATA, LRecvData, LDecrypted, LDecError) then
          Exit(-1);
      end;
      if LReadSeqNum^ = High(QWord) then
        Exit(-1);
      Inc(LReadSeqNum^);

      if Length(LDecrypted) > 0 then
      begin
        FTLS12ReadBuffer := LDecrypted;
        FTLS12ReadOffset := 0;
      end;
    end;

    LCopyLen := ACount;
    if LCopyLen > Length(FTLS12ReadBuffer) - FTLS12ReadOffset then
      LCopyLen := Length(FTLS12ReadBuffer) - FTLS12ReadOffset;

    Move(FTLS12ReadBuffer[FTLS12ReadOffset], ABuffer, LCopyLen);
    Inc(FTLS12ReadOffset, LCopyLen);

    if FTLS12ReadOffset >= Length(FTLS12ReadBuffer) then
    begin
      SetLength(FTLS12ReadBuffer, 0);
      FTLS12ReadOffset := 0;
    end;

    Result := LCopyLen;
    Exit;
  end;

  while Length(FApplicationReadBuffer) = 0 do
  begin
    if (FStream <> nil) and (GetBufferedStreamBytesAvailable <= 0) then
      Exit(0);

    if not RecvApplicationDataFragment(LFragment) then
      Exit(-1);

    if Length(LFragment) > 0 then
    begin
      FApplicationReadBuffer := LFragment;
      FApplicationReadOffset := 0;
    end;
  end;

  LCopyLen := ACount;
  if LCopyLen > Length(FApplicationReadBuffer) - FApplicationReadOffset then
    LCopyLen := Length(FApplicationReadBuffer) - FApplicationReadOffset;

  Move(FApplicationReadBuffer[FApplicationReadOffset], ABuffer, LCopyLen);
  Inc(FApplicationReadOffset, LCopyLen);

  if FApplicationReadOffset >= Length(FApplicationReadBuffer) then
  begin
    SetLength(FApplicationReadBuffer, 0);
    FApplicationReadOffset := 0;
  end;

  Result := LCopyLen;
end;

function TFreePascalConnection.DoWrite(const ABuffer; ACount: Integer): Integer;
var
  LFragment: TBytes;
  LEncrypted: TBytes;
  LHeader: TBytes;
  LEncError: string;
  LCopyLen: Integer;
  LWriteKey, LWriteIV, LWriteMACKey: TBytes;
  LWriteSeqNum: PQWord;
begin
  if not FHandshakeComplete then
  begin
    MarkPrecondition('TLS write');
    Exit(-1);
  end;

  if ACount <= 0 then
    Exit(0);

  if FProtocolVersion = sslProtocolTLS12 then
  begin
    if FIsServerMode then
    begin
      LWriteKey := FTLS12State.ServerWriteKey;
      LWriteIV := FTLS12State.ServerWriteIV;
      LWriteMACKey := FTLS12State.ServerWriteMACKey;
      LWriteSeqNum := @FTLS12State.ServerSeqNum;
    end
    else
    begin
      LWriteKey := FTLS12State.ClientWriteKey;
      LWriteIV := FTLS12State.ClientWriteIV;
      LWriteMACKey := FTLS12State.ClientWriteMACKey;
      LWriteSeqNum := @FTLS12State.ClientSeqNum;
    end;

    Result := 0;
    while Result < ACount do
    begin
      LCopyLen := ACount - Result;
      if LCopyLen > TLS12_RECORD_MAX_LENGTH then
        LCopyLen := TLS12_RECORD_MAX_LENGTH;

      SetLength(LFragment, LCopyLen);
      Move(PByte(@ABuffer)[Result], LFragment[0], LCopyLen);

      if Length(LWriteMACKey) > 0 then
      begin
        if Length(LWriteMACKey) > 32 then
        begin
          if not TLS12CBCEncrypt_SHA384(LWriteKey, LWriteMACKey,
            LWriteSeqNum^, TLS12_CONTENT_APPLICATION_DATA, LFragment, LEncrypted, LEncError) then
            Exit(-1);
        end
        else
        begin
          if not TLS12CBCEncrypt_SHA256(LWriteKey, LWriteMACKey,
            LWriteSeqNum^, TLS12_CONTENT_APPLICATION_DATA, LFragment, LEncrypted, LEncError) then
            Exit(-1);
        end;
      end
      else if Length(LWriteIV) = 12 then
      begin
        if not TLS12ChaCha20Poly1305EncryptRecord(LWriteKey, LWriteIV,
          LWriteSeqNum^, TLS12_CONTENT_APPLICATION_DATA, LFragment, LEncrypted, LEncError) then
          Exit(-1);
      end
      else
      begin
        if not TLS12GCMEncryptRecord(LWriteKey, LWriteIV,
          LWriteSeqNum^, TLS12_CONTENT_APPLICATION_DATA, LFragment, LEncrypted, LEncError) then
          Exit(-1);
      end;
      if LWriteSeqNum^ = High(QWord) then
        Exit(-1);
      Inc(LWriteSeqNum^);

      SetLength(LHeader, 5);
      LHeader[0] := TLS12_CONTENT_APPLICATION_DATA;
      LHeader[1] := 3;
      LHeader[2] := 3;
      LHeader[3] := Byte(Length(LEncrypted) shr 8);
      LHeader[4] := Byte(Length(LEncrypted));
      FStream.WriteBuffer(LHeader[0], 5);
      FStream.WriteBuffer(LEncrypted[0], Length(LEncrypted));
      Inc(Result, LCopyLen);
    end;
    Exit;
  end;

  Result := 0;
  while Result < ACount do
  begin
    LCopyLen := ACount - Result;
    if LCopyLen > EffectivePeerApplicationFragmentLimit then
      LCopyLen := EffectivePeerApplicationFragmentLimit;

    SetLength(LFragment, LCopyLen);
    Move(PByte(@ABuffer)[Result], LFragment[0], LCopyLen);

    if not SendApplicationDataFragment(LFragment) then
      Exit(-1);

    Inc(Result, LCopyLen);
  end;
end;
