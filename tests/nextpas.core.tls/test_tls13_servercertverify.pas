program test_tls13_servercertverify;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  Classes,
  nextpas.core.tls.crypto.bigint,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.pem,
  nextpas.core.tls.tls13.servercertverify;

const
  TEST_TLS13_SIG_RSA_PKCS1_SHA384 = $0501;
  TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384 = $0805;
  TEST_TLS13_SIG_RSA_PSS_PSS_SHA384 = $080A;

function LoadFileBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function LoadFileText(const AFileName: string): string;
var
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(AFileName);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function TryReadDERLength(const AData: TBytes; var AOffset: Integer; out ALength: Integer): Boolean;
var
  LFirst: Byte;
  LCount: Integer;
  I: Integer;
begin
  ALength := 0;
  Result := False;

  if (AOffset < 0) or (AOffset >= Length(AData)) then
    Exit;

  LFirst := AData[AOffset];
  Inc(AOffset);

  if (LFirst and $80) = 0 then
  begin
    ALength := LFirst;
    Exit(True);
  end;

  LCount := LFirst and $7F;
  if (LCount <= 0) or (LCount > 4) or (AOffset + LCount > Length(AData)) then
    Exit;

  ALength := 0;
  for I := 1 to LCount do
  begin
    ALength := (ALength shl 8) or AData[AOffset];
    Inc(AOffset);
  end;

  Result := True;
end;

function TryLocatePKCS1IntegerFieldValue(
  const ADER: TBytes;
  AFieldIndex: Integer;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LSeqEnd: Integer;
  LCurrentField: Integer;
begin
  AValueOffset := -1;
  AValueLength := 0;
  Result := False;

  if (AFieldIndex < 0) or (Length(ADER) < 4) then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);

  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;

  LSeqEnd := LOffset + LSeqLength;
  if LSeqEnd > Length(ADER) then
    Exit;

  LCurrentField := 0;
  while LOffset < LSeqEnd do
  begin
    if ADER[LOffset] <> $02 then
      Exit;
    Inc(LOffset);

    if not TryReadDERLength(ADER, LOffset, AValueLength) then
      Exit;

    if (AValueLength < 0) or (LOffset + AValueLength > LSeqEnd) then
      Exit;

    if LCurrentField = AFieldIndex then
    begin
      AValueOffset := LOffset;
      Exit(True);
    end;

    Inc(LOffset, AValueLength);
    Inc(LCurrentField);
  end;
end;

function TryLocatePKCS1IntegerFieldTagOffset(
  const ADER: TBytes;
  AFieldIndex: Integer;
  out ATagOffset: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LSeqEnd: Integer;
  LCurrentField: Integer;
  LFieldLength: Integer;
begin
  ATagOffset := -1;
  Result := False;

  if (AFieldIndex < 0) or (Length(ADER) < 4) then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);

  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;

  LSeqEnd := LOffset + LSeqLength;
  if LSeqEnd > Length(ADER) then
    Exit;

  LCurrentField := 0;
  while LOffset < LSeqEnd do
  begin
    if ADER[LOffset] <> $02 then
      Exit;

    if LCurrentField = AFieldIndex then
    begin
      ATagOffset := LOffset;
      Exit(True);
    end;

    Inc(LOffset);
    if not TryReadDERLength(ADER, LOffset, LFieldLength) then
      Exit;
    if (LFieldLength < 0) or (LOffset + LFieldLength > LSeqEnd) then
      Exit;

    Inc(LOffset, LFieldLength);
    Inc(LCurrentField);
  end;
end;

function TryLocatePKCS1PrivateExponentValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
begin
  Result := TryLocatePKCS1IntegerFieldValue(ADER, 3, AValueOffset, AValueLength);
end;

function TryLocatePKCS1PrimePValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
begin
  Result := TryLocatePKCS1IntegerFieldValue(ADER, 4, AValueOffset, AValueLength);
end;

function TryLocatePKCS1PrimeQValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
begin
  Result := TryLocatePKCS1IntegerFieldValue(ADER, 5, AValueOffset, AValueLength);
end;

function TryLocatePKCS1DPValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
begin
  Result := TryLocatePKCS1IntegerFieldValue(ADER, 6, AValueOffset, AValueLength);
end;

function TryLocatePKCS1DQValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
begin
  Result := TryLocatePKCS1IntegerFieldValue(ADER, 7, AValueOffset, AValueLength);
end;

function TryLocatePKCS1QInvValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
begin
  Result := TryLocatePKCS1IntegerFieldValue(ADER, 8, AValueOffset, AValueLength);
end;

function TryMutatePKCS1FieldLSB(
  const ASourceDER: TBytes;
  AFieldIndex: Integer;
  AXorMask: Byte;
  AForceOdd: Boolean;
  out ADestDER: TBytes
): Boolean;
var
  LValueOffset: Integer;
  LValueLength: Integer;
begin
  SetLength(ADestDER, 0);
  Result := False;

  if not TryLocatePKCS1IntegerFieldValue(ASourceDER, AFieldIndex, LValueOffset, LValueLength) then
    Exit;
  if LValueLength <= 0 then
    Exit;

  ADestDER := Copy(ASourceDER, 0, Length(ASourceDER));
  ADestDER[LValueOffset + LValueLength - 1] := ADestDER[LValueOffset + LValueLength - 1] xor AXorMask;
  if AForceOdd then
    ADestDER[LValueOffset + LValueLength - 1] := ADestDER[LValueOffset + LValueLength - 1] or $01;

  Result := True;
end;

function TryMutatePKCS1FieldTag(
  const ASourceDER: TBytes;
  AFieldIndex: Integer;
  ATag: Byte;
  out ADestDER: TBytes
): Boolean;
var
  LTagOffset: Integer;
begin
  SetLength(ADestDER, 0);
  Result := False;

  if not TryLocatePKCS1IntegerFieldTagOffset(ASourceDER, AFieldIndex, LTagOffset) then
    Exit;

  ADestDER := Copy(ASourceDER, 0, Length(ASourceDER));
  ADestDER[LTagOffset] := ATag;
  Result := True;
end;

function TryMutatePKCS1FieldLengthByte(
  const ASourceDER: TBytes;
  AFieldIndex: Integer;
  ALengthByte: Byte;
  out ADestDER: TBytes
): Boolean;
var
  LTagOffset: Integer;
  LLengthOffset: Integer;
begin
  SetLength(ADestDER, 0);
  Result := False;

  if not TryLocatePKCS1IntegerFieldTagOffset(ASourceDER, AFieldIndex, LTagOffset) then
    Exit;

  LLengthOffset := LTagOffset + 1;
  if (LLengthOffset < 0) or (LLengthOffset >= Length(ASourceDER)) then
    Exit;

  ADestDER := Copy(ASourceDER, 0, Length(ASourceDER));
  ADestDER[LLengthOffset] := ALengthByte;
  Result := True;
end;

function TrySetPKCS1FieldToConstant(
  const ASourceDER: TBytes;
  AFieldIndex: Integer;
  AConstant: Byte;
  out ADestDER: TBytes
): Boolean;
var
  LValueOffset: Integer;
  LValueLength: Integer;
begin
  SetLength(ADestDER, 0);
  Result := False;

  if not TryLocatePKCS1IntegerFieldValue(ASourceDER, AFieldIndex, LValueOffset, LValueLength) then
    Exit;
  if LValueLength <= 0 then
    Exit;

  ADestDER := Copy(ASourceDER, 0, Length(ASourceDER));
  FillChar(ADestDER[LValueOffset], LValueLength, 0);
  ADestDER[LValueOffset + LValueLength - 1] := AConstant;

  Result := True;
end;

function TryCopyPKCS1FieldValue(
  const ASourceDER: TBytes;
  AFromFieldIndex: Integer;
  AToFieldIndex: Integer;
  out ADestDER: TBytes
): Boolean;
var
  LFromOffset: Integer;
  LFromLength: Integer;
  LToOffset: Integer;
  LToLength: Integer;
  LCopyLength: Integer;
begin
  SetLength(ADestDER, 0);
  Result := False;

  if not TryLocatePKCS1IntegerFieldValue(ASourceDER, AFromFieldIndex, LFromOffset, LFromLength) then
    Exit;
  if not TryLocatePKCS1IntegerFieldValue(ASourceDER, AToFieldIndex, LToOffset, LToLength) then
    Exit;
  if (LFromLength <= 0) or (LToLength <= 0) then
    Exit;

  ADestDER := Copy(ASourceDER, 0, Length(ASourceDER));
  FillChar(ADestDER[LToOffset], LToLength, 0);

  LCopyLength := LFromLength;
  if LCopyLength > LToLength then
    LCopyLength := LToLength;

  Move(
    ASourceDER[LFromOffset + LFromLength - LCopyLength],
    ADestDER[LToOffset + LToLength - LCopyLength],
    LCopyLength
  );

  Result := True;
end;

function TryMutatePKCS1PrivateExponent(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TryMutatePKCS1FieldLSB(ASourceDER, 3, $01, False, ADestDER);
end;

function TryMutatePKCS1PrimeP(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TryMutatePKCS1FieldLSB(ASourceDER, 4, $02, True, ADestDER);
end;

function TryMutatePKCS1PrimeQ(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TryMutatePKCS1FieldLSB(ASourceDER, 5, $02, True, ADestDER);
end;

function TryMutatePKCS1DP(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TryMutatePKCS1FieldLSB(ASourceDER, 6, $04, False, ADestDER);
end;

function TryMutatePKCS1DQ(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TryMutatePKCS1FieldLSB(ASourceDER, 7, $04, False, ADestDER);
end;

function TryMutatePKCS1QInv(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TryMutatePKCS1FieldLSB(ASourceDER, 8, $02, False, ADestDER);
end;

function TrySetPKCS1PrimePToOne(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TrySetPKCS1FieldToConstant(ASourceDER, 4, 1, ADestDER);
end;

function TrySetPKCS1PrimeQEqualPrimeP(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TryCopyPKCS1FieldValue(ASourceDER, 4, 5, ADestDER);
end;

function TrySetPKCS1DPToZero(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TrySetPKCS1FieldToConstant(ASourceDER, 6, 0, ADestDER);
end;

function TrySetPKCS1DQToZero(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TrySetPKCS1FieldToConstant(ASourceDER, 7, 0, ADestDER);
end;

function TrySetPKCS1QInvToZero(const ASourceDER: TBytes; out ADestDER: TBytes): Boolean;
begin
  Result := TrySetPKCS1FieldToConstant(ASourceDER, 8, 0, ADestDER);
end;

function TryLocatePKCS8PrivateKeyOctetStringValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LChildLength: Integer;
begin
  AValueOffset := -1;
  AValueLength := 0;
  Result := False;

  if Length(ADER) < 8 then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;
  if LOffset + LSeqLength > Length(ADER) then
    Exit;

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $02) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LChildLength) then
    Exit;
  Inc(LOffset, LChildLength);

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $30) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LChildLength) then
    Exit;
  Inc(LOffset, LChildLength);

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $04) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, AValueLength) then
    Exit;
  if LOffset + AValueLength > Length(ADER) then
    Exit;

  AValueOffset := LOffset;
  Result := True;
end;

function TryLocatePKCS8AlgorithmIdentifierTagOffset(
  const ADER: TBytes;
  out ATagOffset: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LVersionLength: Integer;
begin
  ATagOffset := -1;
  Result := False;

  if Length(ADER) < 8 then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;
  if LOffset + LSeqLength > Length(ADER) then
    Exit;

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $02) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LVersionLength) then
    Exit;
  Inc(LOffset, LVersionLength);
  if LOffset >= Length(ADER) then
    Exit;

  ATagOffset := LOffset;
  Result := True;
end;

function TryLocatePKCS8AlgorithmOIDValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer;
  out ATagOffset: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LVersionLength: Integer;
  LAlgSeqLength: Integer;
begin
  AValueOffset := -1;
  AValueLength := 0;
  ATagOffset := -1;
  Result := False;

  if Length(ADER) < 12 then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;
  if LOffset + LSeqLength > Length(ADER) then
    Exit;

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $02) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LVersionLength) then
    Exit;
  Inc(LOffset, LVersionLength);

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $30) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LAlgSeqLength) then
    Exit;

  ATagOffset := LOffset;
  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $06) then
    Exit;
  Inc(LOffset);

  if not TryReadDERLength(ADER, LOffset, AValueLength) then
    Exit;
  if (AValueLength <= 0) or (LOffset + AValueLength > Length(ADER)) then
    Exit;

  AValueOffset := LOffset;
  Result := True;
end;

function TryLocatePKCS8PrivateKeyTagOffset(
  const ADER: TBytes;
  out ATagOffset: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LChildLength: Integer;
begin
  ATagOffset := -1;
  Result := False;

  if Length(ADER) < 8 then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;
  if LOffset + LSeqLength > Length(ADER) then
    Exit;

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $02) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LChildLength) then
    Exit;
  Inc(LOffset, LChildLength);

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $30) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LChildLength) then
    Exit;
  Inc(LOffset, LChildLength);

  if LOffset >= Length(ADER) then
    Exit;
  ATagOffset := LOffset;
  Result := True;
end;

function TryExtractPKCS1FromPKCS8DER(const ADER: TBytes; out APKCS1DER: TBytes): Boolean;
var
  LOffset: Integer;
  LLength: Integer;
begin
  SetLength(APKCS1DER, 0);
  Result := False;

  if not TryLocatePKCS8PrivateKeyOctetStringValue(ADER, LOffset, LLength) then
    Exit;
  if (LLength <= 0) or (LOffset + LLength > Length(ADER)) then
    Exit;

  APKCS1DER := Copy(ADER, LOffset, LLength);
  Result := Length(APKCS1DER) > 0;
end;

function TryExtractFirstPrivateKeyDER(
  const APEMBlob: TBytes;
  out ADER: TBytes;
  out AType: TPEMType
): Boolean;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
  LText: string;
  I: Integer;
begin
  SetLength(ADER, 0);
  AType := pemUnknown;
  Result := False;

  LReader := TPEMReader.Create;
  try
    LText := AnsiString(TEncoding.ANSI.GetString(APEMBlob));
    LReader.LoadFromString(LText);
    LBlocks := LReader.GetPrivateKeys;
    for I := 0 to High(LBlocks) do
    begin
      if LBlocks[I].IsEncrypted then
        Continue;
      if not (LBlocks[I].BlockType in [pemPrivateKey, pemRSAPrivateKey]) then
        Continue;

      ADER := Copy(LBlocks[I].Data, 0, Length(LBlocks[I].Data));
      AType := LBlocks[I].BlockType;
      Exit(Length(ADER) > 0);
    end;
  finally
    LReader.Free;
  end;
end;

function BuildMutatedPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TryMutatePKCS1PrivateExponent(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TryMutatePKCS1PrivateExponent(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildMutatedPrimePPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TryMutatePKCS1PrimeP(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TryMutatePKCS1PrimeP(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildMutatedPrimePAndPrivateExponentPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LMutatedPKCS1B: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if not TryMutatePKCS1PrimeP(LDER, LMutatedPKCS1) then
          Exit;
        if not TryMutatePKCS1PrivateExponent(LMutatedPKCS1, LMutatedPKCS1B) then
          Exit;
        Result := LMutatedPKCS1B;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TryMutatePKCS1PrimeP(LInnerPKCS1, LMutatedPKCS1) then
          Exit;
        if not TryMutatePKCS1PrivateExponent(LMutatedPKCS1, LMutatedPKCS1B) then
          Exit;

        if Length(LMutatedPKCS1B) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1B[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function TryMutatePrivateExponentInAnyPKCS1DER(const ADER: TBytes; out AMutatedDER: TBytes): Boolean;
var
  LValueOffset: Integer;
  LValueLength: Integer;
begin
  SetLength(AMutatedDER, 0);
  Result := False;

  if not TryLocatePKCS1PrivateExponentValue(ADER, LValueOffset, LValueLength) then
    Exit;
  if LValueLength <= 0 then
    Exit;

  AMutatedDER := Copy(ADER, 0, Length(ADER));
  AMutatedDER[LValueOffset + LValueLength - 1] := AMutatedDER[LValueOffset + LValueLength - 1] xor $01;
  Result := True;
end;

function TryMutatePrivateExponentInDERKey(const ADERKeyBlob: TBytes; out AMutatedKeyDER: TBytes): Boolean;
var
  LPKCS1Offset: Integer;
  LPKCS1Length: Integer;
  LInnerPKCS1: TBytes;
  LMutatedPKCS1: TBytes;
begin
  SetLength(AMutatedKeyDER, 0);
  Result := False;

  if TryMutatePrivateExponentInAnyPKCS1DER(ADERKeyBlob, AMutatedKeyDER) then
    Exit(True);

  if not TryLocatePKCS8PrivateKeyOctetStringValue(ADERKeyBlob, LPKCS1Offset, LPKCS1Length) then
    Exit;

  LInnerPKCS1 := Copy(ADERKeyBlob, LPKCS1Offset, LPKCS1Length);
  if not TryMutatePrivateExponentInAnyPKCS1DER(LInnerPKCS1, LMutatedPKCS1) then
    Exit;
  if Length(LMutatedPKCS1) <> LPKCS1Length then
    Exit;

  AMutatedKeyDER := Copy(ADERKeyBlob, 0, Length(ADERKeyBlob));
  Move(LMutatedPKCS1[0], AMutatedKeyDER[LPKCS1Offset], LPKCS1Length);
  Result := True;
end;

function TryMutateModulusParityInAnyPKCS1DER(const ADER: TBytes; out AMutatedDER: TBytes): Boolean;
begin
  Result := TryMutatePKCS1FieldLSB(ADER, 1, $01, False, AMutatedDER);
end;

function TryMutateModulusParityInDERKey(const ADERKeyBlob: TBytes; out AMutatedKeyDER: TBytes): Boolean;
var
  LPKCS1Offset: Integer;
  LPKCS1Length: Integer;
  LInnerPKCS1: TBytes;
  LMutatedPKCS1: TBytes;
begin
  SetLength(AMutatedKeyDER, 0);
  Result := False;

  if TryMutateModulusParityInAnyPKCS1DER(ADERKeyBlob, AMutatedKeyDER) then
    Exit(True);

  if not TryLocatePKCS8PrivateKeyOctetStringValue(ADERKeyBlob, LPKCS1Offset, LPKCS1Length) then
    Exit;

  LInnerPKCS1 := Copy(ADERKeyBlob, LPKCS1Offset, LPKCS1Length);
  if not TryMutateModulusParityInAnyPKCS1DER(LInnerPKCS1, LMutatedPKCS1) then
    Exit;
  if Length(LMutatedPKCS1) <> LPKCS1Length then
    Exit;

  AMutatedKeyDER := Copy(ADERKeyBlob, 0, Length(ADERKeyBlob));
  Move(LMutatedPKCS1[0], AMutatedKeyDER[LPKCS1Offset], LPKCS1Length);
  Result := True;
end;

function BuildMutatedPrimeQPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TryMutatePKCS1PrimeQ(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TryMutatePKCS1PrimeQ(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildMutatedDPPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TryMutatePKCS1DP(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TryMutatePKCS1DP(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildMutatedDQPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TryMutatePKCS1DQ(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TryMutatePKCS1DQ(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildMutatedQInvPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TryMutatePKCS1QInv(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TryMutatePKCS1QInv(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildPrimePIsOnePrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TrySetPKCS1PrimePToOne(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TrySetPKCS1PrimePToOne(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildPrimeQEqualPrimePPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TrySetPKCS1PrimeQEqualPrimeP(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TrySetPKCS1PrimeQEqualPrimeP(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildDPZeroPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TrySetPKCS1DPToZero(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TrySetPKCS1DPToZero(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildDQZeroPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TrySetPKCS1DQToZero(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TrySetPKCS1DQToZero(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

function BuildQInvZeroPrivateKeyBlob(const APEMBlob: TBytes): TBytes;
var
  LDER: TBytes;
  LMutatedPKCS1: TBytes;
  LInnerPKCS1: TBytes;
  LType: TPEMType;
  LOffset: Integer;
  LLength: Integer;
begin
  Result := nil;

  if not TryExtractFirstPrivateKeyDER(APEMBlob, LDER, LType) then
    Exit;

  case LType of
    pemRSAPrivateKey:
      begin
        if TrySetPKCS1QInvToZero(LDER, Result) then
          Exit;
      end;

    pemPrivateKey:
      begin
        if not TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLength) then
          Exit;

        LInnerPKCS1 := Copy(LDER, LOffset, LLength);
        if not TrySetPKCS1QInvToZero(LInnerPKCS1, LMutatedPKCS1) then
          Exit;

        if Length(LMutatedPKCS1) <> LLength then
          Exit;

        Result := Copy(LDER, 0, Length(LDER));
        Move(LMutatedPKCS1[0], Result[LOffset], LLength);
      end;
  else
    Exit;
  end;
end;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualsWord(AExpected, AActual: Word; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=0x%.4x actual=0x%.4x)', [AMessage, AExpected, AActual]));
end;

procedure AssertEqualsInt(AExpected, AActual: Integer; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure AssertContains(const AText, ASubText, AMessage: string);
begin
  if Pos(ASubText, AText) <= 0 then
    Fail(AMessage + ' (missing: ' + ASubText + '; actual: ' + AText + ')');
end;

function TruncateBytesFromEnd(const AData: TBytes; ACutBytes: Integer): TBytes;
begin
  if (ACutBytes <= 0) or (ACutBytes >= Length(AData)) then
    Exit([]);
  Result := Copy(AData, 0, Length(AData) - ACutBytes);
end;

function CopyBytesWithMutation(const AData: TBytes; AOffset: Integer; AValue: Byte): TBytes;
begin
  if (AOffset < 0) or (AOffset >= Length(AData)) then
    Exit([]);

  Result := Copy(AData, 0, Length(AData));
  Result[AOffset] := AValue;
end;

function BuildPEMBlockWithType(const ATypeString: string; const ADERData: TBytes): TBytes;
var
  LWriter: TPEMWriter;
  LText: string;
begin
  LWriter := TPEMWriter.Create;
  try
    LText := LWriter.WriteBlockWithType(ATypeString, ADERData);
  finally
    LWriter.Free;
  end;

  Result := TEncoding.ASCII.GetBytes(UnicodeString(LText));
end;

procedure AssertPKCS1SignatureMatchesBaseline(
  const AKeyMaterial: TBytes;
  const ABaselineSig: TBytes;
  const AInput: TBytes;
  const ALabel: string
);
var
  LSig: TBytes;
  LErr: string;
  I: Integer;
  LDiff: Integer;
begin
  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      AKeyMaterial,
      AInput,
      LSig,
      LErr
    ),
    ALabel + ': signing should succeed: ' + LErr
  );

  AssertEqualsInt(Length(ABaselineSig), Length(LSig), ALabel + ': signature length mismatch');
  LDiff := 0;
  for I := 0 to Length(LSig) - 1 do
    if LSig[I] <> ABaselineSig[I] then
      Inc(LDiff);
  AssertEqualsInt(0, LDiff, ALabel + ': signature should match baseline output');
end;

procedure AssertMalformedDERRejected(
  const ADER: TBytes;
  const AInput: TBytes;
  const ALabel: string
);
var
  LSig: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      ADER,
      AInput,
      LSig,
      LErr
    ),
    ALabel + ': malformed DER should be rejected'
  );
  AssertContains(LErr, 'Unsupported DER private key format', ALabel + ': malformed DER error message mismatch');
end;

procedure AssertDEREitherRejectedOrFallbackSucceeds(
  const ADER: TBytes;
  const AInput: TBytes;
  const ALabel: string
);
var
  LSig: TBytes;
  LErr: string;
begin
  if TryBuildTLS13CertificateVerifySignature(
       TLS13_SIG_RSA_PKCS1_SHA256,
       ADER,
       AInput,
       LSig,
       LErr
     ) then
  begin
    AssertTrue(Length(LSig) > 0, ALabel + ': success path must produce non-empty signature');
    Exit;
  end;

  AssertContains(LErr, 'Unsupported DER private key format', ALabel + ': malformed DER rejection message mismatch');
end;

procedure AssertContainsAny(const AText: string; const ANeedles: array of string; const AMessage: string);
var
  I: Integer;
  LMatched: Boolean;
begin
  LMatched := False;
  for I := 0 to High(ANeedles) do
  begin
    if Pos(ANeedles[I], AText) > 0 then
    begin
      LMatched := True;
      Break;
    end;
  end;

  if not LMatched then
    Fail(AMessage + ' (actual: ' + AText + ')');
end;

function BuildDeterministicCertVerifyInput(ASeed: Byte): TBytes;
var
  LTranscriptHash: TBytes;
  I: Integer;
begin
  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte(ASeed + I);
  Result := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);
end;

procedure AssertSignerFailureContains(
  AScheme: Word;
  const AKeyMaterial: TBytes;
  const AInput: TBytes;
  const ANeedle: string;
  const ALabel: string
);
var
  LSig: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      AScheme,
      AKeyMaterial,
      AInput,
      LSig,
      LErr
    ),
    ALabel + ': operation should fail'
  );
  AssertContains(LErr, ANeedle, ALabel + ': error message mismatch');
end;

procedure AssertSignerFailureContainsAny(
  AScheme: Word;
  const AKeyMaterial: TBytes;
  const AInput: TBytes;
  const ANeedles: array of string;
  const ALabel: string
);
var
  LSig: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      AScheme,
      AKeyMaterial,
      AInput,
      LSig,
      LErr
    ),
    ALabel + ': operation should fail'
  );
  AssertContainsAny(LErr, ANeedles, ALabel + ': error message mismatch');
end;

procedure AssertSignerFailureNonEmptyError(
  AScheme: Word;
  const AKeyMaterial: TBytes;
  const AInput: TBytes;
  const ALabel: string
);
var
  LSig: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      AScheme,
      AKeyMaterial,
      AInput,
      LSig,
      LErr
    ),
    ALabel + ': operation should fail'
  );
  AssertTrue(Length(LErr) > 0, ALabel + ': error message should be non-empty');
end;

procedure AssertEqualsQWord(AExpected, AActual: QWord; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

function BytesToQWord(const AData: TBytes): QWord;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Length(AData) - 1 do
    Result := (Result shl 8) or QWord(AData[I]);
end;

function QWordToBytes(AValue: QWord): TBytes;
var
  LValue: QWord;
  LCount: Integer;
  I: Integer;
begin
  Result := nil;
  if AValue = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;

  LValue := AValue;
  LCount := 0;
  while LValue > 0 do
  begin
    Inc(LCount);
    LValue := LValue shr 8;
  end;

  SetLength(Result, LCount);
  LValue := AValue;
  for I := LCount - 1 downto 0 do
  begin
    Result[I] := Byte(LValue and $FF);
    LValue := LValue shr 8;
  end;
end;

function MulModQWord(ALeft, ARight, AModulus: QWord): QWord;
var
  LLeft: QWord;
  LRight: QWord;
  LResult: QWord;
begin
  if AModulus = 0 then
    Exit(0);

  LLeft := ALeft mod AModulus;
  LRight := ARight mod AModulus;
  LResult := 0;

  while LRight > 0 do
  begin
    if (LRight and 1) = 1 then
    begin
      if LResult >= AModulus - LLeft then
        LResult := LResult - (AModulus - LLeft)
      else
        LResult := LResult + LLeft;
    end;

    LRight := LRight shr 1;
    if LRight = 0 then
      Break;

    if LLeft >= AModulus - LLeft then
      LLeft := LLeft - (AModulus - LLeft)
    else
      LLeft := LLeft + LLeft;
  end;

  Result := LResult;
end;

function PowModQWord(ABase, AExponent, AModulus: QWord): QWord;
var
  LBase: QWord;
  LResult: QWord;
  LExponent: QWord;
begin
  if AModulus = 0 then
    Exit(0);

  LBase := ABase mod AModulus;
  LExponent := AExponent;
  LResult := 1 mod AModulus;

  while LExponent > 0 do
  begin
    if (LExponent and 1) = 1 then
      LResult := MulModQWord(LResult, LBase, AModulus);
    LBase := MulModQWord(LBase, LBase, AModulus);
    LExponent := LExponent shr 1;
  end;

  Result := LResult;
end;

procedure AssertBigIntModMatchesQWord(AValue, AModulus: QWord; const ALabel: string);
var
  LOut: TBytes;
  LErr: string;
  LExpected: QWord;
begin
  AssertTrue(
    TryBigIntModFromUnsignedBytes(QWordToBytes(AValue), QWordToBytes(AModulus), LOut, LErr),
    ALabel + ': mod operation failed: ' + LErr
  );
  LExpected := AValue mod AModulus;
  AssertEqualsQWord(LExpected, BytesToQWord(LOut), ALabel + ': mod result mismatch');
end;

procedure AssertBigIntModMulMatchesQWord(ALeft, ARight, AModulus: QWord; const ALabel: string);
var
  LOut: TBytes;
  LErr: string;
  LExpected: QWord;
begin
  AssertTrue(
    TryBigIntModMulFromUnsignedBytes(QWordToBytes(ALeft), QWordToBytes(ARight), QWordToBytes(AModulus), LOut, LErr),
    ALabel + ': modmul operation failed: ' + LErr
  );
  LExpected := MulModQWord(ALeft, ARight, AModulus);
  AssertEqualsQWord(LExpected, BytesToQWord(LOut), ALabel + ': modmul result mismatch');
end;

procedure AssertBigIntModExpMatchesQWord(ABase, AExponent, AModulus: QWord; const ALabel: string);
var
  LOut: TBytes;
  LErr: string;
  LExpected: QWord;
begin
  AssertTrue(
    TryBigIntModExpFromUnsignedBytes(QWordToBytes(ABase), QWordToBytes(AExponent), QWordToBytes(AModulus), LOut, LErr),
    ALabel + ': modexp operation failed: ' + LErr
  );
  LExpected := PowModQWord(ABase, AExponent, AModulus);
  AssertEqualsQWord(LExpected, BytesToQWord(LOut), ALabel + ': modexp result mismatch');
end;

procedure AssertBigIntSubModMatchesQWord(ALeft, ARight, AModulus: QWord; const ALabel: string);
var
  LOut: TBytes;
  LErr: string;
  LLeftReduced: QWord;
  LRightReduced: QWord;
  LExpected: QWord;
begin
  AssertTrue(
    TryBigIntSubtractModuloFromUnsignedBytes(QWordToBytes(ALeft), QWordToBytes(ARight), QWordToBytes(AModulus), LOut, LErr),
    ALabel + ': subtract-mod operation failed: ' + LErr
  );

  LLeftReduced := ALeft mod AModulus;
  LRightReduced := ARight mod AModulus;
  if LLeftReduced >= LRightReduced then
    LExpected := LLeftReduced - LRightReduced
  else
    LExpected := AModulus - (LRightReduced - LLeftReduced);

  AssertEqualsQWord(LExpected, BytesToQWord(LOut), ALabel + ': subtract-mod result mismatch');
end;

function BuildPKCS8WithContextAttribute(const ADER: TBytes): TBytes;
const
  ATTRS_TAIL: array[0..21] of Byte = (
    $A0, $14,
      $31, $12,
        $30, $10,
          $06, $09, $2A, $86, $48, $86, $F7, $0D, $01, $09, $14,
          $31, $03,
            $0C, $01, $41
  );
var
  LOffset: Integer;
  LSeqLen: Integer;
  LSeqLenBytes: Integer;
  LNewSeqLen: Integer;
  LNewLenBytes: Integer;
  LTmp: Integer;
  I: Integer;
  LPayloadOffset: Integer;
begin
  Result := nil;
  if Length(ADER) < 4 then
    Exit;
  if ADER[0] <> $30 then
    Exit;

  LOffset := 1;
  if not TryReadDERLength(ADER, LOffset, LSeqLen) then
    Exit;

  LSeqLenBytes := LOffset - 1;
  LNewSeqLen := LSeqLen + Length(ATTRS_TAIL);

  if LNewSeqLen < $80 then
    LNewLenBytes := 1
  else if LNewSeqLen <= $FF then
    LNewLenBytes := 2
  else if LNewSeqLen <= $FFFF then
    LNewLenBytes := 3
  else
    Exit;

  SetLength(Result, 1 + LNewLenBytes + LSeqLen + Length(ATTRS_TAIL));
  Result[0] := $30;

  if LNewLenBytes = 1 then
    Result[1] := Byte(LNewSeqLen)
  else
  begin
    Result[1] := $80 or Byte(LNewLenBytes - 1);
    LTmp := LNewSeqLen;
    for I := LNewLenBytes - 1 downto 1 do
    begin
      Result[1 + I] := Byte(LTmp and $FF);
      LTmp := LTmp shr 8;
    end;
  end;

  LPayloadOffset := 1 + LNewLenBytes;
  Move(ADER[1 + LSeqLenBytes], Result[LPayloadOffset], LSeqLen);
  Move(ATTRS_TAIL[0], Result[LPayloadOffset + LSeqLen], Length(ATTRS_TAIL));
end;

function BuildPEMPrivateKeyWithLeadingJunk(const APEMBlob: TBytes): TBytes;
const
  JUNK_PREFIX = 'random-header:ignore-me'#13#10'still-junk'#13#10;
var
  LJunkBytes: TBytes;
begin
  Result := nil;
  LJunkBytes := TEncoding.ASCII.GetBytes(JUNK_PREFIX);
  SetLength(Result, Length(LJunkBytes) + Length(APEMBlob));
  if Length(LJunkBytes) > 0 then
    Move(LJunkBytes[0], Result[0], Length(LJunkBytes));
  if Length(APEMBlob) > 0 then
    Move(APEMBlob[0], Result[Length(LJunkBytes)], Length(APEMBlob));
end;

function BuildPEMWithMultiplePrivateKeys(const APEMBlobA, APEMBlobB: TBytes): TBytes;
const
  SEP = LineEnding + LineEnding;
var
  LSepBytes: TBytes;
  LOffset: Integer;
begin
  Result := nil;
  LSepBytes := TEncoding.ASCII.GetBytes(SEP);
  SetLength(Result, Length(APEMBlobA) + Length(LSepBytes) + Length(APEMBlobB));
  LOffset := 0;
  if Length(APEMBlobA) > 0 then
  begin
    Move(APEMBlobA[0], Result[LOffset], Length(APEMBlobA));
    Inc(LOffset, Length(APEMBlobA));
  end;
  if Length(LSepBytes) > 0 then
  begin
    Move(LSepBytes[0], Result[LOffset], Length(LSepBytes));
    Inc(LOffset, Length(LSepBytes));
  end;
  if Length(APEMBlobB) > 0 then
    Move(APEMBlobB[0], Result[LOffset], Length(APEMBlobB));
end;

procedure TestSelectSchemeFromClientHello;
var
  LClientKeyShare: TBytes;
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LErr: string;
  LScheme: Word;
begin
  SetLength(LClientKeyShare, 32);
  FillChar(LClientKeyShare[0], 32, $33);

  LHandshake := BuildTLS13ClientHelloHandshake('localhost', '', LClientKeyShare);
  AssertTrue(TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LErr),
    'Parse ClientHello failed: ' + LErr);

  AssertTrue(TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'Scheme selection failed: ' + LErr);
  AssertEqualsWord(TLS13_SIG_RSA_PSS_RSAE_SHA256, LScheme,
    'Scheme selector should prioritize rsa_pss_rsae_sha256');
end;

procedure TestSelectSchemeMatrixWaveE;
var
  LInfo: TTLS13ClientHelloInfo;
  LScheme: Word;
  LErr: string;
begin
  FillChar(LInfo, SizeOf(LInfo), 0);
  SetLength(LInfo.SignatureAlgorithms, 0);
  LInfo.HasSignatureAlgorithms := False;
  AssertTrue(
    not TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-missing-extension should fail'
  );
  AssertContains(LErr, 'ClientHello missing signature_algorithms extension', 'scheme-wavee-missing-extension message mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  SetLength(LInfo.SignatureAlgorithms, 0);
  LInfo.HasSignatureAlgorithms := True;
  AssertTrue(
    not TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-empty-vector should fail'
  );
  AssertContains(LErr, 'No supported TLS 1.3 CertificateVerify signature scheme from client', 'scheme-wavee-empty-vector message mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_ED25519];
  AssertTrue(
    not TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-ed25519-only should fail'
  );
  AssertContains(LErr, 'No supported TLS 1.3 CertificateVerify signature scheme from client', 'scheme-wavee-ed25519-only message mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_ECDSA_SECP256R1_SHA256];
  AssertTrue(
    TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-ecdsa-only should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_ECDSA_SECP256R1_SHA256, LScheme, 'scheme-wavee-ecdsa-only mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_RSA_PKCS1_SHA256];
  AssertTrue(
    TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-pkcs1-only should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_RSA_PKCS1_SHA256, LScheme, 'scheme-wavee-pkcs1-only mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_RSA_PSS_PSS_SHA256];
  AssertTrue(
    TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-pss-pss-only should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_RSA_PSS_PSS_SHA256, LScheme, 'scheme-wavee-pss-pss-only mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_RSA_PKCS1_SHA256, TLS13_SIG_ECDSA_SECP256R1_SHA256];
  AssertTrue(
    TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-priority-ecdsa-over-pkcs1 should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_ECDSA_SECP256R1_SHA256, LScheme, 'scheme-wavee-priority-ecdsa-over-pkcs1 mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_RSA_PSS_PSS_SHA256, TLS13_SIG_RSA_PKCS1_SHA256];
  AssertTrue(
    TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-priority-pkcs1-over-pss-pss should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_RSA_PKCS1_SHA256, LScheme, 'scheme-wavee-priority-pkcs1-over-pss-pss mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_ED25519, TLS13_SIG_RSA_PSS_RSAE_SHA256];
  AssertTrue(
    TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-priority-pss-rsae should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_RSA_PSS_RSAE_SHA256, LScheme, 'scheme-wavee-priority-pss-rsae mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_ECDSA_SECP256R1_SHA256, TLS13_SIG_RSA_PSS_RSAE_SHA256];
  AssertTrue(
    TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
    'scheme-wavee-priority-pss-rsae-over-ecdsa should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_RSA_PSS_RSAE_SHA256, LScheme, 'scheme-wavee-priority-pss-rsae-over-ecdsa mismatch');
end;

procedure TestSelectSchemeMatrixWaveF;
var
  LInfo: TTLS13ClientHelloInfo;
  LScheme: Word;
  LErr: string;

  procedure SetAlgos(const AValues: array of Word);
  var
    I: Integer;
  begin
    SetLength(LInfo.SignatureAlgorithms, Length(AValues));
    for I := 0 to High(AValues) do
      LInfo.SignatureAlgorithms[I] := AValues[I];
  end;

  procedure AssertSelectSuccess(const AValues: array of Word; AExpected: Word; const ALabel: string);
  begin
    FillChar(LInfo, SizeOf(LInfo), 0);
    LInfo.HasSignatureAlgorithms := True;
    SetAlgos(AValues);
    AssertTrue(
      TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
      ALabel + ': selection should succeed: ' + LErr
    );
    AssertEqualsWord(AExpected, LScheme, ALabel + ': selected scheme mismatch');
  end;

  procedure AssertSelectFailure(const AValues: array of Word; const ALabel: string);
  begin
    FillChar(LInfo, SizeOf(LInfo), 0);
    LInfo.HasSignatureAlgorithms := True;
    SetAlgos(AValues);
    AssertTrue(
      not TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
      ALabel + ': selection should fail'
    );
    AssertContains(LErr, 'No supported TLS 1.3 CertificateVerify signature scheme from client', ALabel + ': failure message mismatch');
  end;

begin
  AssertSelectSuccess([TLS13_SIG_RSA_PSS_RSAE_SHA256, TLS13_SIG_RSA_PSS_RSAE_SHA256], TLS13_SIG_RSA_PSS_RSAE_SHA256, 'scheme-wavef-duplicate-pss-rsae');
  AssertSelectSuccess([TLS13_SIG_ECDSA_SECP256R1_SHA256, TLS13_SIG_ECDSA_SECP256R1_SHA256], TLS13_SIG_ECDSA_SECP256R1_SHA256, 'scheme-wavef-duplicate-ecdsa');
  AssertSelectSuccess([TLS13_SIG_RSA_PSS_PSS_SHA256, TLS13_SIG_ED25519, TLS13_SIG_RSA_PSS_PSS_SHA256], TLS13_SIG_RSA_PSS_PSS_SHA256, 'scheme-wavef-duplicate-pss-pss');
  AssertSelectSuccess([$0000, TLS13_SIG_RSA_PKCS1_SHA256], TLS13_SIG_RSA_PKCS1_SHA256, 'scheme-wavef-unknown-plus-pkcs1');
  AssertSelectSuccess([$FFFF, TLS13_SIG_ECDSA_SECP256R1_SHA256, TLS13_SIG_RSA_PSS_RSAE_SHA256], TLS13_SIG_RSA_PSS_RSAE_SHA256, 'scheme-wavef-priority-pss-rsae-with-unknown');
  AssertSelectSuccess([TLS13_SIG_RSA_PKCS1_SHA256, TLS13_SIG_RSA_PSS_RSAE_SHA256], TLS13_SIG_RSA_PSS_RSAE_SHA256, 'scheme-wavef-priority-pss-rsae-over-pkcs1');
  AssertSelectSuccess([TLS13_SIG_RSA_PSS_PSS_SHA256, TLS13_SIG_ECDSA_SECP256R1_SHA256], TLS13_SIG_ECDSA_SECP256R1_SHA256, 'scheme-wavef-priority-ecdsa-over-pss-pss');
  AssertSelectSuccess([TLS13_SIG_RSA_PKCS1_SHA256, TLS13_SIG_RSA_PSS_PSS_SHA256], TLS13_SIG_RSA_PKCS1_SHA256, 'scheme-wavef-priority-pkcs1-over-pss-pss');
  AssertSelectFailure([TLS13_SIG_ED25519, $1234, $0A0A], 'scheme-wavef-unsupported-only');
  AssertSelectSuccess([TLS13_SIG_RSA_PSS_PSS_SHA256, $1234, TLS13_SIG_RSA_PKCS1_SHA256], TLS13_SIG_RSA_PKCS1_SHA256, 'scheme-wavef-pss-pss-plus-pkcs1');
  AssertSelectSuccess([TLS13_SIG_ECDSA_SECP256R1_SHA256, TLS13_SIG_RSA_PSS_PSS_SHA256, TLS13_SIG_RSA_PSS_RSAE_SHA256], TLS13_SIG_RSA_PSS_RSAE_SHA256, 'scheme-wavef-priority-pss-rsae-over-all');
  AssertSelectSuccess([TLS13_SIG_RSA_PKCS1_SHA256, TLS13_SIG_ECDSA_SECP256R1_SHA256, TLS13_SIG_RSA_PSS_PSS_SHA256], TLS13_SIG_ECDSA_SECP256R1_SHA256, 'scheme-wavef-priority-ecdsa-over-pkcs1-and-psspss');
end;

procedure TestSelectSchemeMatrixWaveJ;
var
  LInfo: TTLS13ClientHelloInfo;
  LScheme: Word;
  LErr: string;

  procedure SetAlgos(const AValues: array of Word);
  var
    I: Integer;
  begin
    SetLength(LInfo.SignatureAlgorithms, Length(AValues));
    for I := 0 to High(AValues) do
      LInfo.SignatureAlgorithms[I] := AValues[I];
  end;

  procedure AssertSelectSuccess(const AValues: array of Word; AExpected: Word; const ALabel: string);
  begin
    FillChar(LInfo, SizeOf(LInfo), 0);
    LInfo.HasSignatureAlgorithms := True;
    SetAlgos(AValues);
    AssertTrue(
      TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
      ALabel + ': selection should succeed: ' + LErr
    );
    AssertEqualsWord(AExpected, LScheme, ALabel + ': selected scheme mismatch');
  end;

  procedure AssertSelectFailure(const AValues: array of Word; const ALabel: string);
  begin
    FillChar(LInfo, SizeOf(LInfo), 0);
    LInfo.HasSignatureAlgorithms := True;
    SetAlgos(AValues);
    AssertTrue(
      not TrySelectTLS13ServerCertificateVerifyScheme(LInfo, LScheme, LErr),
      ALabel + ': selection should fail'
    );
    AssertContains(LErr, 'No supported TLS 1.3 CertificateVerify signature scheme from client', ALabel + ': failure message mismatch');
  end;

begin
  AssertSelectSuccess([TLS13_SIG_RSA_PKCS1_SHA256, TLS13_SIG_RSA_PKCS1_SHA256, TLS13_SIG_RSA_PKCS1_SHA256], TLS13_SIG_RSA_PKCS1_SHA256, 'scheme-wavej-pkcs1-duplicates');
  AssertSelectSuccess([TLS13_SIG_RSA_PSS_RSAE_SHA256, TLS13_SIG_RSA_PSS_PSS_SHA256, TLS13_SIG_RSA_PKCS1_SHA256], TLS13_SIG_RSA_PSS_RSAE_SHA256, 'scheme-wavej-rsae-priority-full-rsa-set');
  AssertSelectSuccess([TLS13_SIG_RSA_PSS_PSS_SHA256, TLS13_SIG_ECDSA_SECP256R1_SHA256, TLS13_SIG_RSA_PSS_PSS_SHA256], TLS13_SIG_ECDSA_SECP256R1_SHA256, 'scheme-wavej-ecdsa-priority-over-psspss');
  AssertSelectSuccess([$BEEF, $CAFE, TLS13_SIG_ECDSA_SECP256R1_SHA256], TLS13_SIG_ECDSA_SECP256R1_SHA256, 'scheme-wavej-unknown-prefix-ecdsa');
  AssertSelectSuccess([$BEEF, TLS13_SIG_RSA_PSS_RSAE_SHA256, $CAFE], TLS13_SIG_RSA_PSS_RSAE_SHA256, 'scheme-wavej-rsae-between-unknowns');
  AssertSelectSuccess([TLS13_SIG_RSA_PSS_PSS_SHA256, TLS13_SIG_RSA_PKCS1_SHA256, TLS13_SIG_RSA_PSS_PSS_SHA256], TLS13_SIG_RSA_PKCS1_SHA256, 'scheme-wavej-pkcs1-priority-over-psspss-duplicates');
  AssertSelectSuccess([TLS13_SIG_ECDSA_SECP256R1_SHA256, TLS13_SIG_RSA_PKCS1_SHA256, TLS13_SIG_ECDSA_SECP256R1_SHA256], TLS13_SIG_ECDSA_SECP256R1_SHA256, 'scheme-wavej-ecdsa-priority-over-pkcs1-duplicates');
  AssertSelectSuccess([TLS13_SIG_ED25519, TLS13_SIG_RSA_PSS_PSS_SHA256, TLS13_SIG_ED25519], TLS13_SIG_RSA_PSS_PSS_SHA256, 'scheme-wavej-psspss-only-supported');
  AssertSelectFailure([TLS13_SIG_ED25519, $0707, $0808, $0909], 'scheme-wavej-all-unsupported');
  AssertSelectFailure([$0001, $0002, $0003, $0004], 'scheme-wavej-only-unknowns');
end;

procedure TestSelectSchemeByCertificateKeyType;
var
  LInfo: TTLS13ClientHelloInfo;
  LScheme: Word;
  LErr: string;
begin
  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [
    TLS13_SIG_ECDSA_SECP256R1_SHA256,
    TLS13_SIG_RSA_PKCS1_SHA256,
    TLS13_SIG_RSA_PSS_PSS_SHA256
  ];

  AssertTrue(
    TrySelectTLS13ServerCertificateVerifySchemeForKeyType(LInfo, 'RSA', LScheme, LErr),
    'keytype-rsa-mixed should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_RSA_PKCS1_SHA256, LScheme, 'keytype-rsa-mixed selected scheme mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_ECDSA_SECP256R1_SHA256];

  AssertTrue(
    TrySelectTLS13ServerCertificateVerifySchemeForKeyType(LInfo, 'ECDSA', LScheme, LErr),
    'keytype-ecdsa should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_ECDSA_SECP256R1_SHA256, LScheme,
    'keytype-ecdsa selected scheme mismatch');

  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [TLS13_SIG_RSA_PSS_RSAE_SHA256, TLS13_SIG_RSA_PKCS1_SHA256];

  AssertTrue(
    not TrySelectTLS13ServerCertificateVerifySchemeForKeyType(LInfo, 'Ed25519', LScheme, LErr),
    'keytype-unsupported should fail'
  );
  AssertContains(LErr, 'Unsupported leaf certificate key type for TLS 1.3 CertificateVerify',
    'keytype-unsupported message mismatch');
end;

procedure TestSelectSchemeByCertificateKeyTypeSupportsRSASHA384;
var
  LInfo: TTLS13ClientHelloInfo;
  LScheme: Word;
  LErr: string;
begin
  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [
    TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384,
    TEST_TLS13_SIG_RSA_PKCS1_SHA384,
    TEST_TLS13_SIG_RSA_PSS_PSS_SHA384
  ];

  AssertTrue(
    TrySelectTLS13ServerCertificateVerifySchemeForKeyType(LInfo, 'RSA', LScheme, LErr),
    'keytype-rsa-sha384-only should succeed: ' + LErr
  );
  AssertEqualsWord(TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384, LScheme,
    'keytype-rsa-sha384-only selected scheme mismatch');
end;

procedure TestSelectSchemeByCertificateKeyTypePrefersSuiteHashFamily;
var
  LInfo: TTLS13ClientHelloInfo;
  LScheme: Word;
  LErr: string;
begin
  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.HasSignatureAlgorithms := True;
  LInfo.SignatureAlgorithms := [
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384,
    TLS13_SIG_RSA_PKCS1_SHA256,
    TEST_TLS13_SIG_RSA_PKCS1_SHA384,
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    TEST_TLS13_SIG_RSA_PSS_PSS_SHA384
  ];

  AssertTrue(
    TrySelectTLS13ServerCertificateVerifySchemeForKeyTypeAndCipherSuite(
      LInfo,
      'RSA',
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LScheme,
      LErr
    ),
    'keytype-rsa-aes256-suite-aware should succeed: ' + LErr
  );
  AssertEqualsWord(TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384, LScheme,
    'keytype-rsa-aes256-suite-aware selected scheme mismatch');

  AssertTrue(
    TrySelectTLS13ServerCertificateVerifySchemeForKeyTypeAndCipherSuite(
      LInfo,
      'RSA',
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LScheme,
      LErr
    ),
    'keytype-rsa-chacha-suite-aware should succeed: ' + LErr
  );
  AssertEqualsWord(TLS13_SIG_RSA_PSS_RSAE_SHA256, LScheme,
    'keytype-rsa-chacha-suite-aware selected scheme mismatch');
end;

procedure TestBuildCertVerifyInput;
const
  CONTEXT = 'TLS 1.3, server CertificateVerify';
var
  LHash: TBytes;
  LInput: TBytes;
  I: Integer;
  LOffset: Integer;
begin
  SetLength(LHash, 32);
  for I := 0 to 31 do
    LHash[I] := Byte(I);

  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LHash);
  AssertEqualsInt(64 + Length(CONTEXT) + 1 + 32, Length(LInput), 'CertificateVerify input length mismatch');

  for I := 0 to 63 do
    AssertTrue(LInput[I] = $20, 'CertificateVerify input must start with 64 spaces');

  LOffset := 64;
  for I := 1 to Length(CONTEXT) do
    AssertTrue(LInput[LOffset + I - 1] = Byte(Ord(CONTEXT[I])), 'Context string byte mismatch');

  AssertTrue(LInput[64 + Length(CONTEXT)] = 0, 'Context separator must be 0x00');
  for I := 0 to 31 do
    AssertTrue(LInput[64 + Length(CONTEXT) + 1 + I] = LHash[I], 'Transcript hash bytes mismatch');
end;

procedure TestBuildCertVerifyInputAcceptsSHA384TranscriptHash;
const
  CONTEXT = 'TLS 1.3, server CertificateVerify';
var
  LHash: TBytes;
  LInput: TBytes;
  I: Integer;
  LOffset: Integer;
begin
  SetLength(LHash, 48);
  for I := 0 to 47 do
    LHash[I] := Byte($80 + I);

  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LHash);
  AssertEqualsInt(64 + Length(CONTEXT) + 1 + 48, Length(LInput),
    'SHA384 CertificateVerify input length mismatch');

  for I := 0 to 63 do
    AssertTrue(LInput[I] = $20, 'SHA384 CertificateVerify input must start with 64 spaces');

  LOffset := 64;
  for I := 1 to Length(CONTEXT) do
    AssertTrue(LInput[LOffset + I - 1] = Byte(Ord(CONTEXT[I])), 'SHA384 context string byte mismatch');

  AssertTrue(LInput[64 + Length(CONTEXT)] = 0, 'SHA384 context separator must be 0x00');
  for I := 0 to 47 do
    AssertTrue(LInput[64 + Length(CONTEXT) + 1 + I] = LHash[I],
      'SHA384 transcript hash bytes mismatch');
end;

procedure TestBuildCertificateVerifyHandshake;
var
  LSignature: TBytes;
  LHandshake: TBytes;
  LLen: Cardinal;
begin
  SetLength(LSignature, 16);
  FillChar(LSignature[0], 16, $AB);

  LHandshake := BuildTLS13CertificateVerifyHandshake(TLS13_SIG_RSA_PSS_RSAE_SHA256, LSignature);

  AssertTrue(Length(LHandshake) = 4 + 2 + 2 + 16, 'CertificateVerify handshake total length mismatch');
  AssertTrue(LHandshake[0] = TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY, 'Handshake type mismatch');

  LLen := ReadUInt24(LHandshake, 1);
  AssertEqualsInt(2 + 2 + 16, Integer(LLen), 'CertificateVerify body length mismatch');
  AssertEqualsWord(TLS13_SIG_RSA_PSS_RSAE_SHA256, ReadUInt16(LHandshake, 4), 'Signature scheme mismatch');
  AssertEqualsWord(16, ReadUInt16(LHandshake, 6), 'Signature length field mismatch');
end;

procedure TestPlaceholderSignature;
var
  LHash: TBytes;
  LSigA, LSigB: TBytes;
  I: Integer;
  LDiff: Integer;
begin
  SetLength(LHash, 32);
  for I := 0 to 31 do
    LHash[I] := Byte($90 + I);

  LSigA := BuildTLS13PlaceholderSignatureFromTranscriptHash(LHash, 64);
  LSigB := BuildTLS13PlaceholderSignatureFromTranscriptHash(LHash, 64);

  AssertEqualsInt(64, Length(LSigA), 'Placeholder signature length mismatch');
  AssertEqualsInt(64, Length(LSigB), 'Placeholder signature length mismatch');

  LDiff := 0;
  for I := 0 to 63 do
  begin
    if LSigA[I] <> LSigB[I] then
      Inc(LDiff);
  end;
  AssertEqualsInt(0, LDiff, 'Placeholder signature should be deterministic for same input');
end;

procedure TestRealRSASignature;
var
  LKeyBlob: TBytes;
  LTranscriptHash: TBytes;
  LTranscriptHash384: TBytes;
  LInput: TBytes;
  LInput384: TBytes;
  LSigPSSA, LSigPSSB: TBytes;
  LSigPKCS1A, LSigPKCS1B: TBytes;
  LSigPSS384: TBytes;
  LSigPKCS1384: TBytes;
  LErr: string;
  I, LDiff: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(Length(LKeyBlob) > 0, 'Signer key blob should not be empty');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($21 + I);

  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  SetLength(LTranscriptHash384, 48);
  for I := 0 to 47 do
    LTranscriptHash384[I] := Byte($61 + I);

  LInput384 := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash384);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_RSAE_SHA256,
      LKeyBlob,
      LInput,
      LSigPSSA,
      LErr
    ),
    'RSA-PSS signing failed: ' + LErr
  );
  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_RSAE_SHA256,
      LKeyBlob,
      LInput,
      LSigPSSB,
      LErr
    ),
    'RSA-PSS signing failed on second call: ' + LErr
  );
  AssertEqualsInt(256, Length(LSigPSSA), 'RSA-PSS signature length should match 2048-bit key');
  AssertEqualsInt(256, Length(LSigPSSB), 'RSA-PSS signature length should match 2048-bit key');

  LDiff := 0;
  for I := 0 to Length(LSigPSSA) - 1 do
    if LSigPSSA[I] <> LSigPSSB[I] then
      Inc(LDiff);
  AssertTrue(LDiff > 0, 'RSA-PSS signatures should vary because of randomized salt');

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LSigPKCS1A,
      LErr
    ),
    'RSA-PKCS1 signing failed: ' + LErr
  );
  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LSigPKCS1B,
      LErr
    ),
    'RSA-PKCS1 signing failed on second call: ' + LErr
  );
  AssertEqualsInt(256, Length(LSigPKCS1A), 'RSA-PKCS1 signature length should match 2048-bit key');
  AssertEqualsInt(256, Length(LSigPKCS1B), 'RSA-PKCS1 signature length should match 2048-bit key');

  LDiff := 0;
  for I := 0 to Length(LSigPKCS1A) - 1 do
    if LSigPKCS1A[I] <> LSigPKCS1B[I] then
      Inc(LDiff);
  AssertEqualsInt(0, LDiff, 'RSA-PKCS1 signatures should be deterministic for same input/key');

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384,
      LKeyBlob,
      LInput384,
      LSigPSS384,
      LErr
    ),
    'RSA-PSS SHA384 signing failed: ' + LErr
  );
  AssertEqualsInt(256, Length(LSigPSS384), 'RSA-PSS SHA384 signature length should match 2048-bit key');

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TEST_TLS13_SIG_RSA_PKCS1_SHA384,
      LKeyBlob,
      LInput384,
      LSigPKCS1384,
      LErr
    ),
    'RSA-PKCS1 SHA384 signing failed: ' + LErr
  );
  AssertEqualsInt(256, Length(LSigPKCS1384), 'RSA-PKCS1 SHA384 signature length should match 2048-bit key');
end;

procedure TestSignerUnitHasNoExternalBigIntDependency;
var
  LSource: string;
begin
  LSource := LowerCase(LoadFileText('src/nextpas.core.tls.tls13.servercertverify.pas'));

  AssertTrue(
    Pos('nextpas.core.tls.openssl', LSource) = 0,
    'TLS13 server CertificateVerify signer must not depend on OpenSSL units'
  );
  AssertTrue(
    Pos('gmp', LSource) = 0,
    'TLS13 server CertificateVerify signer must not depend on GMP'
  );
end;

procedure TestRSASignatureFallsBackWhenPrivateExponentCorrupted;
var
  LKeyBlob: TBytes;
  LMutatedKeyDER: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSigOriginal: TBytes;
  LSigMutated: TBytes;
  LErr: string;
  I: Integer;
  LDiff: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(Length(LKeyBlob) > 0, 'Signer key blob should not be empty');

  LMutatedKeyDER := BuildMutatedPrivateKeyBlob(LKeyBlob);
  AssertTrue(Length(LMutatedKeyDER) > 0, 'Failed to produce DER key with corrupted privateExponent');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($A0 + I);

  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LSigOriginal,
      LErr
    ),
    'RSA-PKCS1 signing with original key failed: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMutatedKeyDER,
      LInput,
      LSigMutated,
      LErr
    ),
    'RSA-PKCS1 signing with mutated key failed: ' + LErr
  );

  AssertEqualsInt(Length(LSigOriginal), Length(LSigMutated), 'Signature length mismatch');

  LDiff := 0;
  for I := 0 to Length(LSigOriginal) - 1 do
    if LSigOriginal[I] <> LSigMutated[I] then
      Inc(LDiff);

  AssertTrue(LDiff > 0,
    'Corrupted privateExponent should force exponent fallback and change RSA-PKCS1 signature');
end;

procedure TestRSASignatureFallsBackWhenCRTInconsistent;
var
  LKeyBlob: TBytes;
  LMutatedPKeyDER: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSigOriginal: TBytes;
  LSigMutated: TBytes;
  LErr: string;
  I: Integer;
  LDiff: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(Length(LKeyBlob) > 0, 'Signer key blob should not be empty');

  LMutatedPKeyDER := BuildMutatedPrimePPrivateKeyBlob(LKeyBlob);
  AssertTrue(Length(LMutatedPKeyDER) > 0, 'Failed to produce DER key with corrupted prime p');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($B0 + I);

  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LSigOriginal,
      LErr
    ),
    'RSA-PKCS1 signing with original key failed: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMutatedPKeyDER,
      LInput,
      LSigMutated,
      LErr
    ),
    'RSA-PKCS1 signing with CRT-inconsistent key should fallback and still succeed: ' + LErr
  );

  AssertEqualsInt(Length(LSigOriginal), Length(LSigMutated), 'Signature length mismatch');

  LDiff := 0;
  for I := 0 to Length(LSigOriginal) - 1 do
    if LSigOriginal[I] <> LSigMutated[I] then
      Inc(LDiff);

  AssertEqualsInt(0, LDiff,
    'Corrupted prime p should not change signature when signer falls back to private exponent path');
end;

procedure TestRSASignatureUsesCorruptedExponentWhenCRTBroken;
var
  LKeyBlob: TBytes;
  LMutatedBothDER: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSigOriginal: TBytes;
  LSig: TBytes;
  LErr: string;
  I: Integer;
  LDiff: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(Length(LKeyBlob) > 0, 'Signer key blob should not be empty');

  LMutatedBothDER := BuildMutatedPrimePAndPrivateExponentPrivateKeyBlob(LKeyBlob);
  AssertTrue(Length(LMutatedBothDER) > 0, 'Failed to produce DER key with corrupted prime p + private exponent');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($C0 + I);

  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LSigOriginal,
      LErr
    ),
    'RSA-PKCS1 signing with original key failed: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMutatedBothDER,
      LInput,
      LSig,
      LErr
    ),
    'Signing should still succeed via fallback exponent path: ' + LErr
  );

  AssertEqualsInt(Length(LSigOriginal), Length(LSig), 'Signature length mismatch');

  LDiff := 0;
  for I := 0 to Length(LSigOriginal) - 1 do
    if LSigOriginal[I] <> LSig[I] then
      Inc(LDiff);

  AssertTrue(LDiff > 0,
    'Corrupted private exponent should produce a different signature when CRT is broken and fallback is used');
end;

procedure AssertFallbackSignatureMatchesValid(
  const AMutatedKeyDER: TBytes;
  const ATestLabel: string
);
var
  LKeyBlob: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LValidSig: TBytes;
  LMutatedSig: TBytes;
  LErr: string;
  LDiff: Integer;
  I: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(Length(AMutatedKeyDER) > 0, ATestLabel + ': failed to build mutated key DER');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($4D + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LValidSig,
      LErr
    ),
    ATestLabel + ': baseline signing failed: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      AMutatedKeyDER,
      LInput,
      LMutatedSig,
      LErr
    ),
    ATestLabel + ': mutated signing should fallback and succeed: ' + LErr
  );

  AssertEqualsInt(Length(LValidSig), Length(LMutatedSig), ATestLabel + ': signature length mismatch');
  LDiff := 0;
  for I := 0 to Length(LValidSig) - 1 do
    if LValidSig[I] <> LMutatedSig[I] then
      Inc(LDiff);
  AssertEqualsInt(0, LDiff, ATestLabel + ': fallback signature should match valid signature');
end;

procedure AssertFallbackErrorContainsCRTReason(
  const AMutatedKeyDER: TBytes;
  const AExpectedReason: string;
  const ATestLabel: string
);
var
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  I: Integer;
begin
  AssertTrue(Length(AMutatedKeyDER) > 0, ATestLabel + ': failed to build mutated key DER');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($53 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      AMutatedKeyDER,
      LInput,
      LSig,
      LErr
    ),
    ATestLabel + ': expected fallback failure with structured diagnostic'
  );
  AssertContains(LErr, 'E_TLS13_SIGNER_FALLBACK_FAILED', ATestLabel + ': missing fallback error code');
  AssertContains(LErr, 'crt_reason=' + AExpectedReason, ATestLabel + ': missing CRT reason detail');
  AssertContains(LErr, 'exp_reason=', ATestLabel + ': missing exponent reason detail');
end;

procedure AssertFallbackRetainsCRTReasonInSuccessPath(
  const AMutatedKeyDER: TBytes;
  const AExpectedReason: string;
  const ATestLabel: string
);
var
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  I: Integer;
begin
  AssertTrue(Length(AMutatedKeyDER) > 0, ATestLabel + ': failed to build mutated key DER');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($58 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      AMutatedKeyDER,
      LInput,
      LSig,
      LErr
    ),
    ATestLabel + ': mutated signing should fallback and succeed: ' + LErr
  );
  AssertTrue(Length(LSig) > 0, ATestLabel + ': fallback-success signature should not be empty');
end;

procedure TestRSASignatureFallsBackWhenPrimeQInconsistent;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildMutatedPrimeQPrivateKeyBlob(LKeyBlob);
  AssertFallbackSignatureMatchesValid(LMutated, 'prime-q-inconsistent');
end;

procedure TestRSASignatureFallsBackWhenDPInconsistent;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildMutatedDPPrivateKeyBlob(LKeyBlob);
  AssertFallbackSignatureMatchesValid(LMutated, 'dp-inconsistent');
end;

procedure TestRSASignatureFallsBackWhenDQInconsistent;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildMutatedDQPrivateKeyBlob(LKeyBlob);
  AssertFallbackSignatureMatchesValid(LMutated, 'dq-inconsistent');
end;

procedure TestRSASignatureFallsBackWhenQInvInconsistent;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildMutatedQInvPrivateKeyBlob(LKeyBlob);
  AssertFallbackSignatureMatchesValid(LMutated, 'qinv-inconsistent');
end;

procedure TestRSASignatureFallbackErrorWhenPrimePIsOneAndExponentCorrupted;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildPrimePIsOnePrivateKeyBlob(LKeyBlob);
  AssertFallbackRetainsCRTReasonInSuccessPath(LMutated, 'RSA CRT validation failed: p/q must be > 1', 'prime-p-is-one');
end;

procedure TestRSASignatureFallbackErrorWhenPrimeQEqualsPrimePAndExponentCorrupted;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildPrimeQEqualPrimePPrivateKeyBlob(LKeyBlob);
  AssertFallbackRetainsCRTReasonInSuccessPath(LMutated, 'RSA CRT validation failed: p and q must be distinct', 'p-equals-q');
end;

procedure TestRSASignatureFallbackErrorWhenDPZeroAndExponentCorrupted;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildDPZeroPrivateKeyBlob(LKeyBlob);
  AssertFallbackRetainsCRTReasonInSuccessPath(LMutated, 'RSA CRT validation failed: dp/dq must be non-zero', 'dp-zero');
end;

procedure TestRSASignatureFallbackErrorWhenDQZeroAndExponentCorrupted;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildDQZeroPrivateKeyBlob(LKeyBlob);
  AssertFallbackRetainsCRTReasonInSuccessPath(LMutated, 'RSA CRT validation failed: dp/dq must be non-zero', 'dq-zero');
end;

procedure TestRSASignatureFallbackErrorWhenQInvZeroAndExponentCorrupted;
var
  LKeyBlob: TBytes;
  LMutated: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutated := BuildQInvZeroPrivateKeyBlob(LKeyBlob);
  AssertFallbackRetainsCRTReasonInSuccessPath(LMutated, 'RSA CRT validation failed: qInv is inconsistent with q mod p', 'qinv-zero');
end;

procedure TestFallbackStructuredErrorMatrixExtended;
var
  LKeyBlob: TBytes;
  LInput: TBytes;

  procedure AssertStructuredFallbackFor(const AMutatedDER: TBytes; const ALabel: string);
  var
    LEvenModulusDER: TBytes;
  begin
    AssertTrue(Length(AMutatedDER) > 0, ALabel + ': mutation output should not be empty');
    AssertTrue(
      TryMutateModulusParityInDERKey(AMutatedDER, LEvenModulusDER),
      ALabel + ': failed to force even modulus for fallback failure'
    );
    AssertFallbackErrorContainsCRTReason(
      LEvenModulusDER,
      'RSA CRT validation failed',
      ALabel
    );
  end;

  procedure AssertExponentPathFailureFor(const AMutatedDER: TBytes; const ALabel: string);
  var
    LEvenModulusDER: TBytes;
  begin
    AssertTrue(Length(AMutatedDER) > 0, ALabel + ': mutation output should not be empty');
    AssertTrue(
      TryMutateModulusParityInDERKey(AMutatedDER, LEvenModulusDER),
      ALabel + ': failed to force even modulus for exponent-path failure'
    );
    AssertSignerFailureContains(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LEvenModulusDER,
      LInput,
      'not coprime',
      ALabel
    );
  end;

  procedure AssertStructuredFallbackPSSFor(
    const AMutatedDER: TBytes;
    const AExpectedAny: array of string;
    const ALabel: string
  );
  var
    LEvenModulusDER: TBytes;
    LSig: TBytes;
    LErr: string;
  begin
    AssertTrue(Length(AMutatedDER) > 0, ALabel + ': mutation output should not be empty');
    AssertTrue(
      TryMutateModulusParityInDERKey(AMutatedDER, LEvenModulusDER),
      ALabel + ': failed to force even modulus for structured fallback'
    );

    AssertTrue(
      not TryBuildTLS13CertificateVerifySignature(
        TLS13_SIG_RSA_PSS_RSAE_SHA256,
        LEvenModulusDER,
        LInput,
        LSig,
        LErr
      ),
      ALabel + ': expected fallback failure'
    );
    AssertContains(LErr, 'E_TLS13_SIGNER_FALLBACK_FAILED', ALabel + ': missing structured fallback error code');
    AssertContainsAny(LErr, AExpectedAny, ALabel + ': missing expected crt_reason detail');
    AssertContains(LErr, 'exp_reason=', ALabel + ': missing exp_reason detail');
  end;

begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LInput := BuildDeterministicCertVerifyInput($D8);

  AssertStructuredFallbackFor(BuildMutatedPrimePPrivateKeyBlob(LKeyBlob), 'fallback-matrix-primep-inconsistent');
  AssertStructuredFallbackFor(BuildMutatedPrimeQPrivateKeyBlob(LKeyBlob), 'fallback-matrix-primeq-inconsistent');
  AssertStructuredFallbackFor(BuildMutatedDPPrivateKeyBlob(LKeyBlob), 'fallback-matrix-dp-inconsistent');
  AssertStructuredFallbackFor(BuildMutatedDQPrivateKeyBlob(LKeyBlob), 'fallback-matrix-dq-inconsistent');
  AssertStructuredFallbackFor(BuildMutatedQInvPrivateKeyBlob(LKeyBlob), 'fallback-matrix-qinv-inconsistent');

  AssertStructuredFallbackFor(BuildPrimePIsOnePrivateKeyBlob(LKeyBlob), 'fallback-matrix-primep-one');
  AssertStructuredFallbackFor(BuildPrimeQEqualPrimePPrivateKeyBlob(LKeyBlob), 'fallback-matrix-primeq-equals-primep');
  AssertExponentPathFailureFor(BuildDPZeroPrivateKeyBlob(LKeyBlob), 'fallback-matrix-dp-zero');
  AssertExponentPathFailureFor(BuildDQZeroPrivateKeyBlob(LKeyBlob), 'fallback-matrix-dq-zero');
  AssertExponentPathFailureFor(BuildQInvZeroPrivateKeyBlob(LKeyBlob), 'fallback-matrix-qinv-zero');
end;

procedure TestFallbackMessageMatrixWaveC;
var
  LKeyBlob: TBytes;
  LInput: TBytes;
  LEvenMutated: TBytes;

  procedure AssertStructuredFallbackPSSFor(
    const AMutatedDER: TBytes;
    const AExpectedAny: array of string;
    const ALabel: string
  );
  var
    LEvenModulusDER: TBytes;
    LSig: TBytes;
    LErr: string;
  begin
    AssertTrue(Length(AMutatedDER) > 0, ALabel + ': mutation output should not be empty');
    AssertTrue(
      TryMutateModulusParityInDERKey(AMutatedDER, LEvenModulusDER),
      ALabel + ': failed to force even modulus for structured fallback'
    );

    AssertTrue(
      not TryBuildTLS13CertificateVerifySignature(
        TLS13_SIG_RSA_PSS_RSAE_SHA256,
        LEvenModulusDER,
        LInput,
        LSig,
        LErr
      ),
      ALabel + ': expected fallback failure'
    );
    AssertContains(LErr, 'E_TLS13_SIGNER_FALLBACK_FAILED', ALabel + ': missing structured fallback error code');
    AssertContainsAny(LErr, AExpectedAny, ALabel + ': missing expected crt_reason detail');
    AssertContains(LErr, 'exp_reason=', ALabel + ': missing exp_reason detail');
  end;

  procedure AssertStructuredReasonFor(
    const AMutatedDER: TBytes;
    const AExpectedAny: array of string;
    const ALabel: string
  );
  var
    LEvenModulusDER: TBytes;
    LSig: TBytes;
    LErr: string;
  begin
    AssertTrue(Length(AMutatedDER) > 0, ALabel + ': mutation output should not be empty');
    AssertTrue(
      TryMutateModulusParityInDERKey(AMutatedDER, LEvenModulusDER),
      ALabel + ': failed to force even modulus for structured fallback'
    );

    AssertTrue(
      not TryBuildTLS13CertificateVerifySignature(
        TLS13_SIG_RSA_PKCS1_SHA256,
        LEvenModulusDER,
        LInput,
        LSig,
        LErr
      ),
      ALabel + ': expected fallback failure'
    );
    AssertContains(LErr, 'E_TLS13_SIGNER_FALLBACK_FAILED', ALabel + ': missing structured fallback error code');
    AssertContainsAny(LErr, AExpectedAny, ALabel + ': missing expected crt_reason detail');
    AssertContains(LErr, 'exp_reason=', ALabel + ': missing exp_reason detail');
  end;

begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LInput := BuildDeterministicCertVerifyInput($E1);

  AssertStructuredReasonFor(
    BuildMutatedPrimePPrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'RSA CRT validation failed'],
    'fallback-msg-primep-inconsistent'
  );
  AssertStructuredReasonFor(
    BuildMutatedPrimeQPrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'RSA CRT validation failed'],
    'fallback-msg-primeq-inconsistent'
  );
  AssertStructuredReasonFor(
    BuildMutatedDPPrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'dp is inconsistent with private exponent', 'dp is out of range for modulus p'],
    'fallback-msg-dp-inconsistent'
  );
  AssertStructuredReasonFor(
    BuildMutatedDQPrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'dq is inconsistent with private exponent', 'dq is out of range for modulus q'],
    'fallback-msg-dq-inconsistent'
  );
  AssertStructuredReasonFor(
    BuildMutatedQInvPrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'qInv is inconsistent with q mod p', 'qInv'],
    'fallback-msg-qinv-inconsistent'
  );

  AssertStructuredReasonFor(
    BuildPrimePIsOnePrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'p/q must be > 1'],
    'fallback-msg-primep-one'
  );
  AssertStructuredReasonFor(
    BuildPrimeQEqualPrimePPrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'p and q must be distinct'],
    'fallback-msg-primeq-equals-primep'
  );
  AssertStructuredReasonFor(
    BuildMutatedPrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'dp is inconsistent with private exponent', 'dq is inconsistent with private exponent'],
    'fallback-msg-privateexp-mutated'
  );
  AssertStructuredReasonFor(
    BuildMutatedPrimePAndPrivateExponentPrivateKeyBlob(LKeyBlob),
    ['p*q does not match modulus', 'p/q must be > 1', 'RSA CRT validation failed'],
    'fallback-msg-primep-plus-privateexp-mutated'
  );

  AssertTrue(
    TryMutateModulusParityInDERKey(BuildMutatedPrimePPrivateKeyBlob(LKeyBlob), LEvenMutated),
    'fallback-msg-even-modulus-only: failed to mutate modulus parity'
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    LEvenMutated,
    LInput,
    'Encoded message representative is not coprime to RSA modulus',
    'fallback-msg-even-modulus-only'
  );
end;

procedure TestFallbackPSSSuccessMatrixWaveE;
var
  LKeyBlob: TBytes;

  procedure AssertPSSFallbackSuccess(const AMutatedDER: TBytes; AScheme: Word; const ALabel: string);
  var
    LInput: TBytes;
    LSig: TBytes;
    LErr: string;
  begin
    AssertTrue(Length(AMutatedDER) > 0, ALabel + ': mutated key should not be empty');
    LInput := BuildDeterministicCertVerifyInput($E6);
    AssertTrue(
      TryBuildTLS13CertificateVerifySignature(
        AScheme,
        AMutatedDER,
        LInput,
        LSig,
        LErr
      ),
      ALabel + ': PSS fallback should succeed: ' + LErr
    );
    AssertEqualsInt(256, Length(LSig), ALabel + ': signature length mismatch');
  end;

begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');

  AssertPSSFallbackSuccess(BuildMutatedPrimeQPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_RSAE_SHA256, 'fallback-pss-primeq-rsae');
  AssertPSSFallbackSuccess(BuildMutatedPrimeQPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_PSS_SHA256, 'fallback-pss-primeq-pss');

  AssertPSSFallbackSuccess(BuildMutatedDPPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_RSAE_SHA256, 'fallback-pss-dp-rsae');
  AssertPSSFallbackSuccess(BuildMutatedDPPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_PSS_SHA256, 'fallback-pss-dp-pss');

  AssertPSSFallbackSuccess(BuildMutatedDQPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_RSAE_SHA256, 'fallback-pss-dq-rsae');
  AssertPSSFallbackSuccess(BuildMutatedDQPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_PSS_SHA256, 'fallback-pss-dq-pss');

  AssertPSSFallbackSuccess(BuildMutatedQInvPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_RSAE_SHA256, 'fallback-pss-qinv-rsae');
  AssertPSSFallbackSuccess(BuildMutatedQInvPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_PSS_SHA256, 'fallback-pss-qinv-pss');

  AssertPSSFallbackSuccess(BuildPrimeQEqualPrimePPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_RSAE_SHA256, 'fallback-pss-peq-rsae');
  AssertPSSFallbackSuccess(BuildPrimeQEqualPrimePPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_PSS_SHA256, 'fallback-pss-peq-pss');
end;

procedure TestFallbackStructuredErrorMatrixWaveF;
var
  LKeyBlob: TBytes;
  LInput: TBytes;

  procedure AssertStructuredFailure(
    const AMutatedDER: TBytes;
    AScheme: Word;
    const ALabel: string
  );
  var
    LEvenModulusDER: TBytes;
    LSig: TBytes;
    LErr: string;
  begin
    AssertTrue(Length(AMutatedDER) > 0, ALabel + ': mutation output should not be empty');
    AssertTrue(
      TryMutateModulusParityInDERKey(AMutatedDER, LEvenModulusDER),
      ALabel + ': failed to force even modulus for structured fallback'
    );

    AssertTrue(
      not TryBuildTLS13CertificateVerifySignature(
        AScheme,
        LEvenModulusDER,
        LInput,
        LSig,
        LErr
      ),
      ALabel + ': expected fallback failure'
    );
    AssertContains(LErr, 'E_TLS13_SIGNER_FALLBACK_FAILED', ALabel + ': missing structured fallback error code');
    AssertContains(LErr, 'crt_reason=', ALabel + ': missing crt_reason detail');
    AssertContains(LErr, 'exp_reason=', ALabel + ': missing exp_reason detail');
  end;

  procedure AssertStructuredOrCoprimeFailure(
    const AMutatedDER: TBytes;
    AScheme: Word;
    const ALabel: string
  );
  var
    LEvenModulusDER: TBytes;
    LSig: TBytes;
    LErr: string;
  begin
    AssertTrue(Length(AMutatedDER) > 0, ALabel + ': mutation output should not be empty');
    AssertTrue(
      TryMutateModulusParityInDERKey(AMutatedDER, LEvenModulusDER),
      ALabel + ': failed to force even modulus for structured fallback'
    );

    AssertTrue(
      not TryBuildTLS13CertificateVerifySignature(
        AScheme,
        LEvenModulusDER,
        LInput,
        LSig,
        LErr
      ),
      ALabel + ': expected failure'
    );

    AssertContainsAny(
      LErr,
      ['E_TLS13_SIGNER_FALLBACK_FAILED', 'Encoded message representative is not coprime to RSA modulus'],
      ALabel + ': expected structured fallback or non-coprime failure'
    );
  end;

begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LInput := BuildDeterministicCertVerifyInput($F6);

  AssertStructuredFailure(BuildMutatedPrimePPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PKCS1_SHA256, 'fallback-wavef-primep-pkcs1');
  AssertStructuredFailure(BuildMutatedPrimeQPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PKCS1_SHA256, 'fallback-wavef-primeq-pkcs1');
  AssertStructuredFailure(BuildMutatedDPPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PKCS1_SHA256, 'fallback-wavef-dp-pkcs1');
  AssertStructuredFailure(BuildMutatedDQPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PKCS1_SHA256, 'fallback-wavef-dq-pkcs1');
  AssertStructuredFailure(BuildMutatedQInvPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PKCS1_SHA256, 'fallback-wavef-qinv-pkcs1');
  AssertStructuredFailure(BuildPrimePIsOnePrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_RSAE_SHA256, 'fallback-wavef-primep-one-pss-rsae');
  AssertStructuredFailure(BuildPrimeQEqualPrimePPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_RSAE_SHA256, 'fallback-wavef-primeq-equal-pss-rsae');
  AssertStructuredOrCoprimeFailure(BuildDPZeroPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_PSS_SHA256, 'fallback-wavef-dp-zero-pss-pss');
  AssertStructuredOrCoprimeFailure(BuildDQZeroPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_PSS_SHA256, 'fallback-wavef-dq-zero-pss-pss');
  AssertStructuredOrCoprimeFailure(BuildQInvZeroPrivateKeyBlob(LKeyBlob), TLS13_SIG_RSA_PSS_RSAE_SHA256, 'fallback-wavef-qinv-zero-pss-rsae');
end;

procedure TestBigIntEvenModulusAndZeroExponent;
var
  LOut: TBytes;
  LErr: string;
begin
  AssertTrue(TryBigIntModExpFromUnsignedBytes([$0D], [$03], [$0A], LOut, LErr),
    'BigInt even modulus modexp fallback failed: ' + LErr);
  AssertEqualsInt(1, Length(LOut), 'BigInt even modulus modexp length mismatch');
  AssertEqualsInt(7, LOut[0], '13^3 mod 10 should be 7');

  AssertTrue(TryBigIntModMulFromUnsignedBytes([$07], [$09], [$0A], LOut, LErr),
    'BigInt even modulus modmul fallback failed: ' + LErr);
  AssertEqualsInt(1, Length(LOut), 'BigInt even modulus modmul length mismatch');
  AssertEqualsInt(3, LOut[0], '7*9 mod 10 should be 3');

  AssertTrue(TryBigIntModExpFromUnsignedBytes([$2A], [$00], [$01], LOut, LErr),
    'BigInt exp=0 reduction failed: ' + LErr);
  AssertEqualsInt(1, Length(LOut), 'BigInt exp=0 mod=1 length mismatch');
  AssertEqualsInt(0, LOut[0], 'base^0 mod 1 should be 0');
end;

procedure TestBigIntCrossByteVector;
var
  LOut: TBytes;
  LErr: string;
begin
  AssertTrue(TryBigIntModMulFromUnsignedBytes([$FF, $00, $01], [$02], [$01, $00, $01], LOut, LErr),
    'BigInt cross-byte vector multiply failed: ' + LErr);
  AssertEqualsInt(2, Length(LOut), 'BigInt cross-byte vector result length mismatch');
  AssertEqualsInt($FE, LOut[0], 'BigInt cross-byte vector high byte mismatch');
  AssertEqualsInt($05, LOut[1], 'BigInt cross-byte vector low byte mismatch');
end;

procedure TestBigIntQWordVectorSuite;
begin
  AssertBigIntModMatchesQWord($00, $11, 'mod-zero');
  AssertBigIntModMatchesQWord($10, $11, 'mod-less-than-modulus');
  AssertBigIntModMatchesQWord($11, $11, 'mod-equals-modulus');
  AssertBigIntModMatchesQWord($1234, $11, 'mod-small-divisor');
  AssertBigIntModMatchesQWord($123456, $10001, 'mod-rsa65537');
  AssertBigIntModMatchesQWord($FFFFFFFF, $7FFFFFFF, 'mod-32bit-max');
  AssertBigIntModMatchesQWord(High(QWord), $FFFFFFFF, 'mod-64bit-by-32bit');
  AssertBigIntModMatchesQWord(High(QWord) - QWord($0E), $FFFFFFFB, 'mod-prime-ish');
  AssertBigIntModMatchesQWord($123456789ABCDEF0, $100000000, 'mod-power-of-two');

  AssertBigIntModMulMatchesQWord($00, $1234, $11, 'modmul-zero-left');
  AssertBigIntModMulMatchesQWord($1234, $00, $11, 'modmul-zero-right');
  AssertBigIntModMulMatchesQWord($01, $1234, $11, 'modmul-one-left');
  AssertBigIntModMulMatchesQWord($1234, $01, $11, 'modmul-one-right');
  AssertBigIntModMulMatchesQWord($1234, $5678, $FFFF, 'modmul-16bit');
  AssertBigIntModMulMatchesQWord($123456, $654321, $10001, 'modmul-rsa65537');
  AssertBigIntModMulMatchesQWord($FFFFFFFF, $FFFFFFFD, $7FFFFFFF, 'modmul-32bit-max');
  AssertBigIntModMulMatchesQWord($ABCDEF01, $12345678, $FFFFFFFB, 'modmul-random-a');
  AssertBigIntModMulMatchesQWord(QWord($FFFFFFFF) shl 32, $00000000FFFFFFFF, $FFFFFFFF, 'modmul-crosslimb');

  AssertBigIntModExpMatchesQWord($02, $00, $11, 'modexp-exp-zero');
  AssertBigIntModExpMatchesQWord($00, $05, $11, 'modexp-base-zero');
  AssertBigIntModExpMatchesQWord($01, $1234, $11, 'modexp-base-one');
  AssertBigIntModExpMatchesQWord($02, $10, $11, 'modexp-power-two');
  AssertBigIntModExpMatchesQWord($1234, $03, $10001, 'modexp-rsa65537');
  AssertBigIntModExpMatchesQWord($DEADBEEF, $11, $FFFFFFFB, 'modexp-random-a');
  AssertBigIntModExpMatchesQWord($123456789, $12345, $7FFFFFFF, 'modexp-large-exp');
  AssertBigIntModExpMatchesQWord($FFFFFFFF, $FFFFFFFF, $FFFFFFFB, 'modexp-max-32');

  AssertBigIntSubModMatchesQWord($05, $03, $11, 'submod-no-wrap');
  AssertBigIntSubModMatchesQWord($03, $05, $11, 'submod-wrap');
  AssertBigIntSubModMatchesQWord($11, $01, $11, 'submod-left-equals-mod');
  AssertBigIntSubModMatchesQWord($1234, $5678, $10001, 'submod-rsa65537');
  AssertBigIntSubModMatchesQWord($FFFFFFFF, $FFFFFFFE, $7FFFFFFF, 'submod-32bit');
  AssertBigIntSubModMatchesQWord($ABCDEF01, $12345678, $FFFFFFFB, 'submod-random-a');
end;

procedure TestBigIntQWordVectorSuiteWaveD;
begin
  AssertBigIntModMatchesQWord(QWord($FFFFFFFFFFFFFFF1), QWord($FFFFFFFFFFFFFFC5), 'waved-mod-1');
  AssertBigIntModMatchesQWord(QWord($8000000000000001), QWord($7FFFFFFFFFFFFFFF), 'waved-mod-2');
  AssertBigIntModMatchesQWord(QWord($1234567890ABCDEF), QWord($1FFFFFFFF), 'waved-mod-3');

  AssertBigIntModMulMatchesQWord(QWord($FFFFFFFFFFFFFFFD), QWord($FFFFFFFFFFFFFFFB), QWord($FFFFFFFFFFFFFFC5), 'waved-modmul-1');
  AssertBigIntModMulMatchesQWord(QWord($0123456789ABCDEF), QWord($0FEDCBA987654321), QWord($7FFFFFFFFFFFFFFF), 'waved-modmul-2');
  AssertBigIntModMulMatchesQWord(QWord($123456789ABCDEF0), QWord($1111111111111111), QWord($1FFFFFFFF), 'waved-modmul-3');

  AssertBigIntModExpMatchesQWord(QWord($123456789ABCDEF0), QWord($123456), QWord($FFFFFFFFFFFFFFC5), 'waved-modexp-1');
  AssertBigIntModExpMatchesQWord(QWord($7FFFFFFFFFFFFFFE), QWord($2222), QWord($7FFFFFFFFFFFFFFF), 'waved-modexp-2');

  AssertBigIntSubModMatchesQWord(QWord($FFFFFFFFFFFFFFFE), QWord($123456789ABCDEF0), QWord($FFFFFFFFFFFFFFC5), 'waved-submod-1');
  AssertBigIntSubModMatchesQWord(QWord($0000000000000001), QWord($FFFFFFFFFFFFFFFE), QWord($7FFFFFFFFFFFFFFF), 'waved-submod-2');
end;

procedure TestBigIntQWordVectorSuiteWaveF;
begin
  AssertBigIntModMatchesQWord(QWord($0102030405060708), QWord($03), 'wavef-mod-1');
  AssertBigIntModMatchesQWord(QWord($FFFFFFFFFFFFFFFE), QWord($FF), 'wavef-mod-2');
  AssertBigIntModMatchesQWord(QWord($7FFFFFFFFFFFFFFF), QWord($0000000100000001), 'wavef-mod-3');
  AssertBigIntModMatchesQWord(QWord($AAAAAAAAAAAAAAAA), QWord($5555555555555557), 'wavef-mod-4');
  AssertBigIntModMatchesQWord(QWord($123456789ABCDEF0), QWord($11), 'wavef-mod-5');
  AssertBigIntModMatchesQWord(QWord($DEADBEEFCAFEBABE), QWord($FFFFFFFB), 'wavef-mod-6');
  AssertBigIntModMatchesQWord(QWord($8000000000000000), QWord($7FFFFFFFFFFFFFE7), 'wavef-mod-7');
  AssertBigIntModMatchesQWord(QWord($13579BDF2468ACE0), QWord($1000000000000001), 'wavef-mod-8');
  AssertBigIntModMatchesQWord(QWord($FEDCBA9876543210), QWord($1FFFFFFFFFFFFFFF), 'wavef-mod-9');
  AssertBigIntModMatchesQWord(QWord($1122334455667788), QWord($0101010101010101), 'wavef-mod-10');

  AssertBigIntModMulMatchesQWord(QWord($FFFFFFFFFFFFFFFD), QWord($FFFFFFFFFFFFFFFB), QWord($FFFFFFFFFFFFFFC5), 'wavef-modmul-1');
  AssertBigIntModMulMatchesQWord(QWord($8000000000000000), QWord($0000000000000002), QWord($7FFFFFFFFFFFFFFF), 'wavef-modmul-2');
  AssertBigIntModMulMatchesQWord(QWord($123456789ABCDEF0), QWord($0FEDCBA987654321), QWord($1FFFFFFFFFFFFFFF), 'wavef-modmul-3');
  AssertBigIntModMulMatchesQWord(QWord($DEADBEEFCAFEBABE), QWord($0000000100000001), QWord($FFFFFFFF00000001), 'wavef-modmul-4');
  AssertBigIntModMulMatchesQWord(QWord($AAAAAAAA55555555), QWord($1111111122222222), QWord($FFFFFFFB), 'wavef-modmul-5');
  AssertBigIntModMulMatchesQWord(QWord($0123456789ABCDEF), QWord($F0E1D2C3B4A59687), QWord($7FFFFFFFFFFFFFE7), 'wavef-modmul-6');
  AssertBigIntModMulMatchesQWord(QWord($00000000FFFFFFFF), QWord($FFFFFFFF00000000), QWord($FFFFFFFF), 'wavef-modmul-7');
  AssertBigIntModMulMatchesQWord(QWord($13579BDF2468ACE1), QWord($2468ACE113579BDF), QWord($100000000000003D), 'wavef-modmul-8');
  AssertBigIntModMulMatchesQWord(QWord($FFFFFFFFFFFFFFFE), QWord($FFFFFFFFFFFFFFFE), QWord($FFFFFFFFFFFFFFC5), 'wavef-modmul-9');
  AssertBigIntModMulMatchesQWord(QWord($1122334455667788), QWord($99AABBCCDDEEFF00), QWord($7FFFFFFFFFFFFFED), 'wavef-modmul-10');

  AssertBigIntModExpMatchesQWord(QWord($02), QWord($3F), QWord($7FFFFFFFFFFFFFFF), 'wavef-modexp-1');
  AssertBigIntModExpMatchesQWord(QWord($03), QWord($0400), QWord($FFFFFFFF00000001), 'wavef-modexp-2');
  AssertBigIntModExpMatchesQWord(QWord($123456789ABCDEF0), QWord($12345), QWord($FFFFFFFFFFFFFFC5), 'wavef-modexp-3');
  AssertBigIntModExpMatchesQWord(QWord($FEDCBA9876543210), QWord($2222), QWord($7FFFFFFFFFFFFFE7), 'wavef-modexp-4');
  AssertBigIntModExpMatchesQWord(QWord($AAAAAAAA55555555), QWord($10001), QWord($1FFFFFFFFFFFFFFF), 'wavef-modexp-5');
  AssertBigIntModExpMatchesQWord(QWord($DEADBEEFCAFEBABE), QWord($77), QWord($FFFFFFFFFFFFFFF1), 'wavef-modexp-6');
  AssertBigIntModExpMatchesQWord(QWord($0123456789ABCDEF), QWord($ABCDE), QWord($100000000000003D), 'wavef-modexp-7');
  AssertBigIntModExpMatchesQWord(QWord($0000000000000005), QWord($FFFFFFFF), QWord($FFFFFFFFFFFFFFC5), 'wavef-modexp-8');
  AssertBigIntModExpMatchesQWord(QWord($FFFFFFFF00000000), QWord($11111111), QWord($FFFFFFFB), 'wavef-modexp-9');
  AssertBigIntModExpMatchesQWord(QWord($13579BDF2468ACE1), QWord($87654321), QWord($7FFFFFFFFFFFFFED), 'wavef-modexp-10');

  AssertBigIntSubModMatchesQWord(QWord($FFFFFFFFFFFFFFFE), QWord($01), QWord($FFFFFFFFFFFFFFC5), 'wavef-submod-1');
  AssertBigIntSubModMatchesQWord(QWord($01), QWord($FFFFFFFFFFFFFFFE), QWord($FFFFFFFFFFFFFFC5), 'wavef-submod-2');
  AssertBigIntSubModMatchesQWord(QWord($123456789ABCDEF0), QWord($0FEDCBA987654321), QWord($1FFFFFFFFFFFFFFF), 'wavef-submod-3');
  AssertBigIntSubModMatchesQWord(QWord($0FEDCBA987654321), QWord($123456789ABCDEF0), QWord($1FFFFFFFFFFFFFFF), 'wavef-submod-4');
  AssertBigIntSubModMatchesQWord(QWord($AAAAAAAAAAAAAAAA), QWord($5555555555555555), QWord($7FFFFFFFFFFFFFFF), 'wavef-submod-5');
  AssertBigIntSubModMatchesQWord(QWord($5555555555555555), QWord($AAAAAAAAAAAAAAAA), QWord($7FFFFFFFFFFFFFFF), 'wavef-submod-6');
  AssertBigIntSubModMatchesQWord(QWord($DEADBEEFCAFEBABE), QWord($DEADBEEFCAFEBABE), QWord($FFFFFFFF00000001), 'wavef-submod-7');
  AssertBigIntSubModMatchesQWord(QWord($0000000000000000), QWord($0000000000000001), QWord($FFFFFFFFFFFFFFF1), 'wavef-submod-8');
  AssertBigIntSubModMatchesQWord(QWord($FFFFFFFF00000000), QWord($00000000FFFFFFFF), QWord($FFFFFFFB), 'wavef-submod-9');
  AssertBigIntSubModMatchesQWord(QWord($1122334455667788), QWord($99AABBCCDDEEFF00), QWord($7FFFFFFFFFFFFFED), 'wavef-submod-10');
end;

procedure TestBigIntQWordVectorSuiteWaveI;
begin
  AssertBigIntModMatchesQWord(QWord($0001000000000001), QWord($00000000FFFFFFFB), 'wavei-mod-1');
  AssertBigIntModMatchesQWord(QWord($0F0E0D0C0B0A0908), QWord($0000000100000001), 'wavei-mod-2');
  AssertBigIntModMatchesQWord(QWord($1020304050607080), QWord($00000000000000F1), 'wavei-mod-3');
  AssertBigIntModMatchesQWord(QWord($7FFF0000FFFF0001), QWord($00000000FFFF0001), 'wavei-mod-4');
  AssertBigIntModMatchesQWord(QWord($1111222233334444), QWord($000000010000003D), 'wavei-mod-5');
  AssertBigIntModMatchesQWord(QWord($89ABCDEF01234567), QWord($00000000FFFFFFC5), 'wavei-mod-6');
  AssertBigIntModMatchesQWord(QWord($2000000000000001), QWord($000000007FFFFFFF), 'wavei-mod-7');
  AssertBigIntModMatchesQWord(QWord($3333333333333333), QWord($0000000000000101), 'wavei-mod-8');
  AssertBigIntModMatchesQWord(QWord($4444555566667777), QWord($00000000FFFFFFFF), 'wavei-mod-9');
  AssertBigIntModMatchesQWord(QWord($5555666677778888), QWord($0000000100000000), 'wavei-mod-10');

  AssertBigIntModMulMatchesQWord(QWord($12345678), QWord($9ABCDEF0), QWord($00000000FFFFFFFB), 'wavei-modmul-1');
  AssertBigIntModMulMatchesQWord(QWord($0001000100010001), QWord($0002000200020002), QWord($000000010000003D), 'wavei-modmul-2');
  AssertBigIntModMulMatchesQWord(QWord($0F0E0D0C0B0A0908), QWord($0102030405060708), QWord($000000007FFFFFFF), 'wavei-modmul-3');
  AssertBigIntModMulMatchesQWord(QWord($1111111122222222), QWord($3333333344444444), QWord($00000000FFFFFFC5), 'wavei-modmul-4');
  AssertBigIntModMulMatchesQWord(QWord($777788889999AAAA), QWord($0000000100000001), QWord($0000000100000001), 'wavei-modmul-5');
  AssertBigIntModMulMatchesQWord(QWord($ABCDEFFF00000001), QWord($00000000FFFFFFFF), QWord($00000000FFFFFFFB), 'wavei-modmul-6');
  AssertBigIntModMulMatchesQWord(QWord($2000000000000000), QWord($0000000000000003), QWord($7FFFFFFFFFFFFFE7), 'wavei-modmul-7');
  AssertBigIntModMulMatchesQWord(QWord($0123456789ABCDEF), QWord($FEDCBA9876543210), QWord($1FFFFFFFFFFFFFFF), 'wavei-modmul-8');
  AssertBigIntModMulMatchesQWord(QWord($1111222233334444), QWord($5555666677778888), QWord($0000000100000000), 'wavei-modmul-9');
  AssertBigIntModMulMatchesQWord(QWord($00000000FFFFFFFF), QWord($00000000FFFFFFFF), QWord($0000000100000001), 'wavei-modmul-10');

  AssertBigIntModExpMatchesQWord(QWord($0000000000000002), QWord($0000000012345678), QWord($00000000FFFFFFFB), 'wavei-modexp-1');
  AssertBigIntModExpMatchesQWord(QWord($0000000000000003), QWord($0001000100010001), QWord($000000010000003D), 'wavei-modexp-2');
  AssertBigIntModExpMatchesQWord(QWord($0000000010203040), QWord($0000000011111111), QWord($000000007FFFFFFF), 'wavei-modexp-3');
  AssertBigIntModExpMatchesQWord(QWord($00000123456789AB), QWord($0000000000002222), QWord($00000000FFFFFFFF), 'wavei-modexp-4');
  AssertBigIntModExpMatchesQWord(QWord($0F0E0D0C0B0A0908), QWord($0000000000000077), QWord($00000000FFFFFFC5), 'wavei-modexp-5');
  AssertBigIntModExpMatchesQWord(QWord($0000000089ABCDEF), QWord($00000000000ABCDE), QWord($0000000100000001), 'wavei-modexp-6');
  AssertBigIntModExpMatchesQWord(QWord($4000000000000001), QWord($0000000000012345), QWord($1FFFFFFFFFFFFFFF), 'wavei-modexp-7');
  AssertBigIntModExpMatchesQWord(QWord($5555666677778888), QWord($0000000000010101), QWord($7FFFFFFFFFFFFFE7), 'wavei-modexp-8');
  AssertBigIntModExpMatchesQWord(QWord($1122334455667788), QWord($000000000000FFFF), QWord($0000000100000000), 'wavei-modexp-9');
  AssertBigIntModExpMatchesQWord(QWord($FFFFFFFF00000000), QWord($00000000001F1F1F), QWord($00000000FFFFFFFB), 'wavei-modexp-10');

  AssertBigIntSubModMatchesQWord(QWord($0000000000000000), QWord($0000000000000001), QWord($0000000000000011), 'wavei-submod-1');
  AssertBigIntSubModMatchesQWord(QWord($0000000012345678), QWord($000000009ABCDEF0), QWord($00000000FFFFFFFB), 'wavei-submod-2');
  AssertBigIntSubModMatchesQWord(QWord($0F0E0D0C0B0A0908), QWord($0102030405060708), QWord($000000007FFFFFFF), 'wavei-submod-3');
  AssertBigIntSubModMatchesQWord(QWord($1111222233334444), QWord($5555666677778888), QWord($000000010000003D), 'wavei-submod-4');
  AssertBigIntSubModMatchesQWord(QWord($5555666677778888), QWord($1111222233334444), QWord($000000010000003D), 'wavei-submod-5');
  AssertBigIntSubModMatchesQWord(QWord($89ABCDEF01234567), QWord($89ABCDEF01234567), QWord($00000000FFFFFFC5), 'wavei-submod-6');
  AssertBigIntSubModMatchesQWord(QWord($2000000000000001), QWord($0000000000000001), QWord($1FFFFFFFFFFFFFFF), 'wavei-submod-7');
  AssertBigIntSubModMatchesQWord(QWord($0000000000000001), QWord($2000000000000001), QWord($1FFFFFFFFFFFFFFF), 'wavei-submod-8');
  AssertBigIntSubModMatchesQWord(QWord($00000000FFFFFFFF), QWord($FFFFFFFF00000000), QWord($0000000100000000), 'wavei-submod-9');
  AssertBigIntSubModMatchesQWord(QWord($FFFFFFFF00000000), QWord($00000000FFFFFFFF), QWord($0000000100000000), 'wavei-submod-10');
end;

procedure TestBigIntNormalizationAndFixedLengthMatrixWaveJ;
var
  LOut: TBytes;
  LErr: string;
begin
  AssertBigIntModMatchesQWord(QWord($0000000000000000), QWord($0000000000000011), 'wavej-mod-1');
  AssertBigIntModMatchesQWord(QWord($0000000000000010), QWord($0000000000000011), 'wavej-mod-2');
  AssertBigIntModMatchesQWord(QWord($0000000012345678), QWord($0000000000000011), 'wavej-mod-3');
  AssertBigIntModMulMatchesQWord(QWord($0000000000000001), QWord($0000000000000001), QWord($0000000000000011), 'wavej-modmul-1');
  AssertBigIntModMulMatchesQWord(QWord($0000000000000000), QWord($0000000012345678), QWord($0000000000000011), 'wavej-modmul-2');
  AssertBigIntModExpMatchesQWord(QWord($0000000000000002), QWord($0000000000000008), QWord($0000000000000011), 'wavej-modexp-1');
  AssertBigIntModExpMatchesQWord(QWord($0000000000000003), QWord($0000000000000000), QWord($0000000000000011), 'wavej-modexp-2');
  AssertBigIntSubModMatchesQWord(QWord($0000000000000001), QWord($0000000000000002), QWord($0000000000000011), 'wavej-submod-1');
  AssertBigIntSubModMatchesQWord(QWord($0000000012345678), QWord($0000000000000001), QWord($0000000000000011), 'wavej-submod-2');
  AssertBigIntSubModMatchesQWord(QWord($0000000000000000), QWord($0000000000000000), QWord($0000000000000011), 'wavej-submod-3');

  AssertTrue(
    TryBigIntToFixedLengthFromUnsignedBytes([$00], 1, LOut, LErr),
    'wavej-fixed-1 should succeed: ' + LErr
  );
  AssertEqualsInt(1, Length(LOut), 'wavej-fixed-1 length mismatch');
  AssertEqualsInt(0, LOut[0], 'wavej-fixed-1 byte mismatch');

  AssertTrue(
    TryBigIntToFixedLengthFromUnsignedBytes([$00], 2, LOut, LErr),
    'wavej-fixed-2 should succeed: ' + LErr
  );
  AssertEqualsInt(2, Length(LOut), 'wavej-fixed-2 length mismatch');
  AssertEqualsInt(0, LOut[0], 'wavej-fixed-2 byte0 mismatch');
  AssertEqualsInt(0, LOut[1], 'wavej-fixed-2 byte1 mismatch');

  AssertTrue(
    TryBigIntToFixedLengthFromUnsignedBytes([$00, $01], 1, LOut, LErr),
    'wavej-fixed-leading-zero-trim should succeed: ' + LErr
  );
  AssertEqualsInt(1, Length(LOut), 'wavej-fixed-leading-zero-trim length mismatch');
  AssertEqualsInt(1, LOut[0], 'wavej-fixed-leading-zero-trim byte mismatch');

  AssertTrue(
    TryBigIntToFixedLengthFromUnsignedBytes([$01, $00], 2, LOut, LErr),
    'wavej-fixed-0100 should succeed: ' + LErr
  );
  AssertEqualsInt(2, Length(LOut), 'wavej-fixed-0100 length mismatch');
  AssertEqualsInt($01, LOut[0], 'wavej-fixed-0100 byte0 mismatch');
  AssertEqualsInt($00, LOut[1], 'wavej-fixed-0100 byte1 mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$01, $00], 1, LOut, LErr),
    'wavej-fixed-overflow-0100 should fail'
  );
  AssertContains(LErr, 'RSA output does not fit target length', 'wavej-fixed-overflow-0100 message mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$00, $01, $00], 1, LOut, LErr),
    'wavej-fixed-overflow-00100 should fail'
  );
  AssertContains(LErr, 'RSA output does not fit target length', 'wavej-fixed-overflow-00100 message mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$01], 0, LOut, LErr),
    'wavej-fixed-len-zero should fail'
  );
  AssertContains(LErr, 'RSA output length is invalid', 'wavej-fixed-len-zero message mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$01], -2, LOut, LErr),
    'wavej-fixed-len-negative should fail'
  );
  AssertContains(LErr, 'RSA output length is invalid', 'wavej-fixed-len-negative message mismatch');
end;

procedure TestBigIntQWordVectorSuiteWaveK;
begin
  AssertBigIntModMatchesQWord(QWord($0000000000000000), QWord($0000000000000013), 'wavek-mod-1');
  AssertBigIntModMatchesQWord(QWord($0000000012345678), QWord($0000000000000097), 'wavek-mod-2');
  AssertBigIntModMatchesQWord(QWord($00000000FFFFFFFF), QWord($000000000000FFFF), 'wavek-mod-3');
  AssertBigIntModMatchesQWord(QWord($0000FFFF0000FFFF), QWord($0000000000010001), 'wavek-mod-4');
  AssertBigIntModMatchesQWord(QWord($0123456789ABCDEF), QWord($00000000001FFFFF), 'wavek-mod-5');
  AssertBigIntModMatchesQWord(QWord($2222222222222222), QWord($0000000011111111), 'wavek-mod-6');
  AssertBigIntModMatchesQWord(QWord($3333333333333333), QWord($000000007FFFFFFF), 'wavek-mod-7');
  AssertBigIntModMatchesQWord(QWord($4444444444444444), QWord($000000010000003D), 'wavek-mod-8');
  AssertBigIntModMatchesQWord(QWord($5555555555555555), QWord($00000000FFFFFFFB), 'wavek-mod-9');
  AssertBigIntModMatchesQWord(QWord($6666666666666666), QWord($0000000100000000), 'wavek-mod-10');

  AssertBigIntModMulMatchesQWord(QWord($0000000012345678), QWord($0000000009ABCDEF), QWord($0000000000010001), 'wavek-modmul-1');
  AssertBigIntModMulMatchesQWord(QWord($0000000011111111), QWord($0000000022222222), QWord($000000007FFFFFFF), 'wavek-modmul-2');
  AssertBigIntModMulMatchesQWord(QWord($0000000033333333), QWord($0000000044444444), QWord($000000010000003D), 'wavek-modmul-3');
  AssertBigIntModMulMatchesQWord(QWord($0000000055555555), QWord($0000000066666666), QWord($00000000FFFFFFFB), 'wavek-modmul-4');
  AssertBigIntModMulMatchesQWord(QWord($0000000077777777), QWord($0000000012345678), QWord($0000000100000000), 'wavek-modmul-5');
  AssertBigIntModMulMatchesQWord(QWord($0000000123456789), QWord($00000000ABCDEF01), QWord($000000001FFFFFFF), 'wavek-modmul-6');
  AssertBigIntModMulMatchesQWord(QWord($000000001FFFFFFF), QWord($0000000000012345), QWord($000000007FFFFFFF), 'wavek-modmul-7');
  AssertBigIntModMulMatchesQWord(QWord($0123456789ABCDEF), QWord($0111111111111111), QWord($0000000100000000), 'wavek-modmul-8');
  AssertBigIntModMulMatchesQWord(QWord($0222222222222222), QWord($0333333333333333), QWord($000000010000003D), 'wavek-modmul-9');
  AssertBigIntModMulMatchesQWord(QWord($0444444444444444), QWord($0555555555555555), QWord($000000007FFFFFFF), 'wavek-modmul-10');

  AssertBigIntModExpMatchesQWord(QWord($0000000000000002), QWord($0000000000000010), QWord($0000000000010001), 'wavek-modexp-1');
  AssertBigIntModExpMatchesQWord(QWord($0000000000000003), QWord($0000000000003039), QWord($000000007FFFFFFF), 'wavek-modexp-2');
  AssertBigIntModExpMatchesQWord(QWord($0000000000012345), QWord($0000000000000222), QWord($000000010000003D), 'wavek-modexp-3');
  AssertBigIntModExpMatchesQWord(QWord($00000000000ABCDE), QWord($0000000000000111), QWord($00000000001FFFFF), 'wavek-modexp-4');
  AssertBigIntModExpMatchesQWord(QWord($000000000013579B), QWord($0000000000000333), QWord($00000000FFFFFFFB), 'wavek-modexp-5');
  AssertBigIntModExpMatchesQWord(QWord($0000000002468ACE), QWord($0000000000000555), QWord($000000007FFFFFFF), 'wavek-modexp-6');
  AssertBigIntModExpMatchesQWord(QWord($0000000033333333), QWord($0000000000000777), QWord($0000000100000000), 'wavek-modexp-7');
  AssertBigIntModExpMatchesQWord(QWord($0000000044444444), QWord($0000000000000999), QWord($0000000000010001), 'wavek-modexp-8');
  AssertBigIntModExpMatchesQWord(QWord($0000000055555555), QWord($0000000000000BBB), QWord($000000001FFFFFFF), 'wavek-modexp-9');
  AssertBigIntModExpMatchesQWord(QWord($0000000066666666), QWord($0000000000000DDD), QWord($00000000FFFFFFFB), 'wavek-modexp-10');

  AssertBigIntSubModMatchesQWord(QWord($0000000000000000), QWord($0000000000000001), QWord($0000000000000013), 'wavek-submod-1');
  AssertBigIntSubModMatchesQWord(QWord($0000000000000001), QWord($0000000000000000), QWord($0000000000000013), 'wavek-submod-2');
  AssertBigIntSubModMatchesQWord(QWord($0000000012345678), QWord($0000000009ABCDEF), QWord($0000000000010001), 'wavek-submod-3');
  AssertBigIntSubModMatchesQWord(QWord($0000000009ABCDEF), QWord($0000000012345678), QWord($0000000000010001), 'wavek-submod-4');
  AssertBigIntSubModMatchesQWord(QWord($0000000011111111), QWord($0000000011111111), QWord($000000007FFFFFFF), 'wavek-submod-5');
  AssertBigIntSubModMatchesQWord(QWord($0000000022222222), QWord($0000000033333333), QWord($000000010000003D), 'wavek-submod-6');
  AssertBigIntSubModMatchesQWord(QWord($0000000033333333), QWord($0000000022222222), QWord($000000010000003D), 'wavek-submod-7');
  AssertBigIntSubModMatchesQWord(QWord($0000000044444444), QWord($0000000055555555), QWord($00000000FFFFFFFB), 'wavek-submod-8');
  AssertBigIntSubModMatchesQWord(QWord($0000000055555555), QWord($0000000044444444), QWord($00000000FFFFFFFB), 'wavek-submod-9');
  AssertBigIntSubModMatchesQWord(QWord($0000000066666666), QWord($0000000077777777), QWord($0000000100000000), 'wavek-submod-10');
end;

procedure TestBigIntQWordVectorSuiteWaveL;
begin
  AssertBigIntModMatchesQWord(QWord($0000000000000001), QWord($0000000000000003), 'wavel-mod-1');
  AssertBigIntModMatchesQWord(QWord($00000000000000FF), QWord($0000000000000011), 'wavel-mod-2');
  AssertBigIntModMatchesQWord(QWord($00000000ABCDEF01), QWord($0000000000000101), 'wavel-mod-3');
  AssertBigIntModMatchesQWord(QWord($0000000100000001), QWord($00000000000000F1), 'wavel-mod-4');
  AssertBigIntModMatchesQWord(QWord($0000000111111111), QWord($0000000000010001), 'wavel-mod-5');
  AssertBigIntModMatchesQWord(QWord($0000000222222222), QWord($00000000000FFFF1), 'wavel-mod-6');
  AssertBigIntModMatchesQWord(QWord($0000000333333333), QWord($0000000000FFFFFF), 'wavel-mod-7');
  AssertBigIntModMatchesQWord(QWord($0000000444444444), QWord($0000000011111111), 'wavel-mod-8');
  AssertBigIntModMatchesQWord(QWord($0000000555555555), QWord($00000000FFFFFFFB), 'wavel-mod-9');
  AssertBigIntModMatchesQWord(QWord($0000000666666666), QWord($000000010000003D), 'wavel-mod-10');

  AssertBigIntModMulMatchesQWord(QWord($0000000000000002), QWord($0000000000000003), QWord($0000000000000011), 'wavel-modmul-1');
  AssertBigIntModMulMatchesQWord(QWord($00000000000000FF), QWord($00000000000000FE), QWord($0000000000000101), 'wavel-modmul-2');
  AssertBigIntModMulMatchesQWord(QWord($0000000012345678), QWord($0000000009ABCDEF), QWord($00000000000FFFF1), 'wavel-modmul-3');
  AssertBigIntModMulMatchesQWord(QWord($00000000ABCDEF01), QWord($0000000011111111), QWord($0000000000FFFFFF), 'wavel-modmul-4');
  AssertBigIntModMulMatchesQWord(QWord($0000000111111111), QWord($0000000122222222), QWord($0000000011111111), 'wavel-modmul-5');
  AssertBigIntModMulMatchesQWord(QWord($0000000222222222), QWord($0000000333333333), QWord($00000000FFFFFFFB), 'wavel-modmul-6');
  AssertBigIntModMulMatchesQWord(QWord($0000000333333333), QWord($0000000444444444), QWord($000000010000003D), 'wavel-modmul-7');
  AssertBigIntModMulMatchesQWord(QWord($0000000444444444), QWord($0000000555555555), QWord($000000007FFFFFFF), 'wavel-modmul-8');
  AssertBigIntModMulMatchesQWord(QWord($0000000555555555), QWord($0000000666666666), QWord($0000000100000000), 'wavel-modmul-9');
  AssertBigIntModMulMatchesQWord(QWord($0000000666666666), QWord($0000000777777777), QWord($000000001FFFFFFF), 'wavel-modmul-10');

  AssertBigIntModExpMatchesQWord(QWord($0000000000000002), QWord($0000000000000005), QWord($0000000000000011), 'wavel-modexp-1');
  AssertBigIntModExpMatchesQWord(QWord($0000000000000003), QWord($0000000000000007), QWord($0000000000000101), 'wavel-modexp-2');
  AssertBigIntModExpMatchesQWord(QWord($0000000000000005), QWord($000000000000000B), QWord($00000000000FFFF1), 'wavel-modexp-3');
  AssertBigIntModExpMatchesQWord(QWord($0000000000012345), QWord($0000000000000111), QWord($0000000000FFFFFF), 'wavel-modexp-4');
  AssertBigIntModExpMatchesQWord(QWord($00000000000ABCDE), QWord($0000000000000222), QWord($0000000011111111), 'wavel-modexp-5');
  AssertBigIntModExpMatchesQWord(QWord($0000000011111111), QWord($0000000000000333), QWord($00000000FFFFFFFB), 'wavel-modexp-6');
  AssertBigIntModExpMatchesQWord(QWord($0000000022222222), QWord($0000000000000444), QWord($000000010000003D), 'wavel-modexp-7');
  AssertBigIntModExpMatchesQWord(QWord($0000000033333333), QWord($0000000000000555), QWord($000000007FFFFFFF), 'wavel-modexp-8');
  AssertBigIntModExpMatchesQWord(QWord($0000000044444444), QWord($0000000000000666), QWord($0000000100000000), 'wavel-modexp-9');
  AssertBigIntModExpMatchesQWord(QWord($0000000055555555), QWord($0000000000000777), QWord($000000001FFFFFFF), 'wavel-modexp-10');

  AssertBigIntSubModMatchesQWord(QWord($0000000000000000), QWord($0000000000000001), QWord($0000000000000011), 'wavel-submod-1');
  AssertBigIntSubModMatchesQWord(QWord($0000000000000001), QWord($0000000000000000), QWord($0000000000000011), 'wavel-submod-2');
  AssertBigIntSubModMatchesQWord(QWord($00000000000000FF), QWord($00000000000000FE), QWord($0000000000000101), 'wavel-submod-3');
  AssertBigIntSubModMatchesQWord(QWord($0000000012345678), QWord($0000000009ABCDEF), QWord($00000000000FFFF1), 'wavel-submod-4');
  AssertBigIntSubModMatchesQWord(QWord($0000000009ABCDEF), QWord($0000000012345678), QWord($00000000000FFFF1), 'wavel-submod-5');
  AssertBigIntSubModMatchesQWord(QWord($00000000ABCDEF01), QWord($0000000011111111), QWord($0000000000FFFFFF), 'wavel-submod-6');
  AssertBigIntSubModMatchesQWord(QWord($0000000011111111), QWord($00000000ABCDEF01), QWord($0000000000FFFFFF), 'wavel-submod-7');
  AssertBigIntSubModMatchesQWord(QWord($0000000222222222), QWord($0000000333333333), QWord($00000000FFFFFFFB), 'wavel-submod-8');
  AssertBigIntSubModMatchesQWord(QWord($0000000333333333), QWord($0000000222222222), QWord($00000000FFFFFFFB), 'wavel-submod-9');
  AssertBigIntSubModMatchesQWord(QWord($0000000444444444), QWord($0000000555555555), QWord($000000010000003D), 'wavel-submod-10');
end;

procedure TestBigIntErrorSurface;
var
  LOut: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryBigIntModFromUnsignedBytes([$01], [$00], LOut, LErr),
    'mod zero modulus should fail'
  );
  AssertContains(LErr, 'Modulus is zero', 'mod zero-modulus message mismatch');

  AssertTrue(
    not TryBigIntModExpFromUnsignedBytes([$02], [$03], [$00], LOut, LErr),
    'modexp zero modulus should fail'
  );
  AssertContains(LErr, 'Modulus is zero', 'modexp zero-modulus message mismatch');

  AssertTrue(
    not TryBigIntModMulFromUnsignedBytes([$02], [$03], [$00], LOut, LErr),
    'modmul zero modulus should fail'
  );
  AssertContains(LErr, 'Modulus is zero', 'modmul zero-modulus message mismatch');

  AssertTrue(
    not TryBigIntSubtractModuloFromUnsignedBytes([$02], [$03], [$00], LOut, LErr),
    'submod zero modulus should fail'
  );
  AssertContains(LErr, 'Modulus is zero', 'submod zero-modulus message mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$01], 0, LOut, LErr),
    'fixed length zero should fail'
  );
  AssertContains(LErr, 'RSA output length is invalid', 'fixed-length invalid message mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$01], -1, LOut, LErr),
    'fixed length negative should fail'
  );
  AssertContains(LErr, 'RSA output length is invalid', 'fixed-length negative message mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$01, $00], 1, LOut, LErr),
    'fixed length overflow should fail'
  );
  AssertContains(LErr, 'RSA output does not fit target length', 'fixed-length overflow message mismatch');
end;

procedure TestBigIntStructuredErrorCodes;
var
  LOut: TBytes;
  LErr: string;
  LSig: TBytes;
begin
  AssertTrue(
    not TryBigIntModFromUnsignedBytes([$01], [$00], LOut, LErr),
    'structured-code mod zero modulus should fail'
  );
  AssertContains(LErr, 'E_TLS13_BIGINT_MODULUS_ZERO', 'structured-code mod zero-modulus code mismatch');

  AssertTrue(
    not TryBigIntModExpFromUnsignedBytes([$02], [$03], [$00], LOut, LErr),
    'structured-code modexp zero modulus should fail'
  );
  AssertContains(LErr, 'E_TLS13_BIGINT_MODULUS_ZERO', 'structured-code modexp zero-modulus code mismatch');

  AssertTrue(
    not TryBigIntModMulFromUnsignedBytes([$02], [$03], [$00], LOut, LErr),
    'structured-code modmul zero modulus should fail'
  );
  AssertContains(LErr, 'E_TLS13_BIGINT_MODULUS_ZERO', 'structured-code modmul zero-modulus code mismatch');

  AssertTrue(
    not TryBigIntSubtractModuloFromUnsignedBytes([$02], [$03], [$00], LOut, LErr),
    'structured-code submod zero modulus should fail'
  );
  AssertContains(LErr, 'E_TLS13_BIGINT_MODULUS_ZERO', 'structured-code submod zero-modulus code mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$01], 0, LOut, LErr),
    'structured-code fixed-length zero should fail'
  );
  AssertContains(LErr, 'E_TLS13_BIGINT_OUTPUT_LENGTH_INVALID', 'structured-code fixed-length invalid code mismatch');

  AssertTrue(
    not TryBigIntToFixedLengthFromUnsignedBytes([$01, $00], 1, LOut, LErr),
    'structured-code fixed-length overflow should fail'
  );
  AssertContains(LErr, 'E_TLS13_BIGINT_OUTPUT_OVERFLOW', 'structured-code fixed-length overflow code mismatch');

  AssertTrue(
    not TryRSAModExpSignPurePascal([$06], [$0C], [$03], LSig, LErr),
    'structured-code RSA non-coprime should fail'
  );
  AssertContains(LErr, 'E_TLS13_BIGINT_RSA_MESSAGE_NOT_COPRIME', 'structured-code RSA non-coprime code mismatch');

  AssertTrue(
    not TryRSAModExpSignPurePascal([$01], [$02], [$01], LSig, LErr),
    'structured-code RSA even modulus should fail'
  );
  AssertContains(LErr, 'E_TLS13_BIGINT_RSA_MODULUS_ODD_REQUIRED', 'structured-code RSA odd-required code mismatch');
end;

procedure TestBigIntLeadingZeroNormalization;
var
  LOut: TBytes;
  LErr: string;
begin
  AssertTrue(
    TryBigIntModFromUnsignedBytes([$00, $00, $01, $23], [$00, $00, $00, $10], LOut, LErr),
    'leading-zero mod should succeed: ' + LErr
  );
  AssertEqualsQWord($03, BytesToQWord(LOut), 'leading-zero mod mismatch');

  AssertTrue(
    TryBigIntModMulFromUnsignedBytes([$00, $00, $01], [$00, $02], [$00, $11], LOut, LErr),
    'leading-zero modmul should succeed: ' + LErr
  );
  AssertEqualsQWord($02, BytesToQWord(LOut), 'leading-zero modmul mismatch');

  AssertTrue(
    TryBigIntModExpFromUnsignedBytes([$00, $02], [$00, $04], [$00, $11], LOut, LErr),
    'leading-zero modexp should succeed: ' + LErr
  );
  AssertEqualsQWord($10, BytesToQWord(LOut), 'leading-zero modexp mismatch');

  AssertTrue(
    TryBigIntSubtractModuloFromUnsignedBytes([$00, $03], [$00, $05], [$00, $11], LOut, LErr),
    'leading-zero submod should succeed: ' + LErr
  );
  AssertEqualsQWord($0F, BytesToQWord(LOut), 'leading-zero submod mismatch');
end;

procedure TestBigIntFixedLengthExactFit;
var
  LOut: TBytes;
  LErr: string;
begin
  AssertTrue(
    TryBigIntToFixedLengthFromUnsignedBytes([$00, $00, $01, $23], 4, LOut, LErr),
    'fixed-length exact fit should succeed: ' + LErr
  );
  AssertEqualsInt(4, Length(LOut), 'fixed-length output length mismatch');
  AssertEqualsInt($00, LOut[0], 'fixed-length byte[0] mismatch');
  AssertEqualsInt($00, LOut[1], 'fixed-length byte[1] mismatch');
  AssertEqualsInt($01, LOut[2], 'fixed-length byte[2] mismatch');
  AssertEqualsInt($23, LOut[3], 'fixed-length byte[3] mismatch');

  AssertTrue(
    TryBigIntToFixedLengthFromUnsignedBytes([$01, $23], 4, LOut, LErr),
    'fixed-length left-pad should succeed: ' + LErr
  );
  AssertEqualsInt($00, LOut[0], 'fixed-length left-pad byte[0] mismatch');
  AssertEqualsInt($00, LOut[1], 'fixed-length left-pad byte[1] mismatch');
  AssertEqualsInt($01, LOut[2], 'fixed-length left-pad byte[2] mismatch');
  AssertEqualsInt($23, LOut[3], 'fixed-length left-pad byte[3] mismatch');
end;

procedure TestRSAModExpExponentGuard;
var
  LSig: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryRSAModExpSignPurePascal([$01], [$00, $11], [$01, $00, $00, $00, $00], LSig, LErr),
    'RSA oversized exponent should be rejected'
  );
  AssertContains(LErr, 'unreasonably large', 'RSA oversized exponent message mismatch');
end;

procedure TestBigIntRejectsNonCoprimeRSARepresentative;
var
  LSig: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryRSAModExpSignPurePascal([$06], [$0C], [$03], LSig, LErr),
    'RSA pure Pascal should reject non-coprime message representative'
  );
  AssertContains(LErr, 'not coprime', 'Expected coprime rejection message');
end;

procedure TestTinyModulusDefense;
var
  LSig: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryRSAModExpSignPurePascal([$01], [$02], [$01], LSig, LErr),
    'Tiny modulus input should be rejected'
  );
  AssertContains(LErr, 'must be odd', 'Tiny modulus defense should fail with odd-modulus validation error');
end;

procedure TestRSASignatureWithDERPrivateKey;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LType: TPEMType;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  I: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'Failed to extract DER from PEM private key');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($33 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LDER,
      LInput,
      LSig,
      LErr
    ),
    'RSA-PKCS1 signing with DER key failed: ' + LErr
  );
  AssertEqualsInt(256, Length(LSig), 'RSA-PKCS1 DER signature length should match 2048-bit key');
end;

procedure TestECDSASignatureWithECPrivateKey;
var
  LKeyBlob: TBytes;
  LRSAKeyBlob: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSigA: TBytes;
  LSigB: TBytes;
  LErr: string;
  I: Integer;
  LSeqLen: Integer;
  LOffset: Integer;
  LIntLen: Integer;
  LDiff: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_ecdsa_key.pem');
  AssertTrue(Length(LKeyBlob) > 0, 'ECDSA private key blob should not be empty');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($5A + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_ECDSA_SECP256R1_SHA256,
      LKeyBlob,
      LInput,
      LSigA,
      LErr
    ),
    'ECDSA P-256 signing failed: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_ECDSA_SECP256R1_SHA256,
      LKeyBlob,
      LInput,
      LSigB,
      LErr
    ),
    'ECDSA P-256 signing second call failed: ' + LErr
  );

  AssertTrue((Length(LSigA) >= 8) and (Length(LSigA) <= 72),
    'ECDSA signature DER length should be within [8,72]');
  AssertEqualsInt($30, LSigA[0], 'ECDSA signature must be DER sequence');

  LDiff := 0;
  AssertEqualsInt(Length(LSigA), Length(LSigB), 'ECDSA deterministic signature length mismatch');
  for I := 0 to Length(LSigA) - 1 do
    if LSigA[I] <> LSigB[I] then
      Inc(LDiff);
  AssertEqualsInt(0, LDiff, 'ECDSA deterministic signature mismatch for same key/input');

  LOffset := 1;
  AssertTrue(TryReadDERLength(LSigA, LOffset, LSeqLen), 'ECDSA DER sequence length parse failed');
  AssertEqualsInt(Length(LSigA) - LOffset, LSeqLen, 'ECDSA DER sequence length mismatch');

  AssertEqualsInt($02, LSigA[LOffset], 'ECDSA DER r INTEGER tag mismatch');
  Inc(LOffset);
  AssertTrue(TryReadDERLength(LSigA, LOffset, LIntLen), 'ECDSA DER r length parse failed');
  AssertTrue(LIntLen > 0, 'ECDSA DER r length should be > 0');
  Inc(LOffset, LIntLen);

  AssertEqualsInt($02, LSigA[LOffset], 'ECDSA DER s INTEGER tag mismatch');
  Inc(LOffset);
  AssertTrue(TryReadDERLength(LSigA, LOffset, LIntLen), 'ECDSA DER s length parse failed');
  AssertTrue(LIntLen > 0, 'ECDSA DER s length should be > 0');

  LRSAKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_ECDSA_SECP256R1_SHA256,
      LRSAKeyBlob,
      LInput,
      LSigA,
      LErr
    ),
    'ECDSA signing with RSA key should fail'
  );
  AssertContainsAny(LErr, ['not EC', 'No usable EC', 'algorithm/curve'], 'ECDSA signing with RSA key error mismatch');
end;

procedure TestRSASignatureWithPKCS8Attributes;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LMutatedDER: TBytes;
  LType: TPEMType;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSigA: TBytes;
  LSigB: TBytes;
  LErr: string;
  I: Integer;
  LDiff: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'Failed to extract DER from PEM private key');
  AssertTrue(LType = pemPrivateKey, 'Expected PKCS#8 PRIVATE KEY input');

  LMutatedDER := BuildPKCS8WithContextAttribute(LDER);
  AssertTrue(Length(LMutatedDER) > 0, 'Failed to build PKCS#8 key with context attribute');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($44 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LDER,
      LInput,
      LSigA,
      LErr
    ),
    'RSA-PKCS1 signing with original PKCS#8 DER failed: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMutatedDER,
      LInput,
      LSigB,
      LErr
    ),
    'RSA-PKCS1 signing with attributed PKCS#8 DER failed: ' + LErr
  );

  AssertEqualsInt(Length(LSigA), Length(LSigB), 'PKCS#8 attributed signature length mismatch');
  LDiff := 0;
  for I := 0 to Length(LSigA) - 1 do
    if LSigA[I] <> LSigB[I] then
      Inc(LDiff);
  AssertEqualsInt(0, LDiff, 'PKCS#8 attributes should not change RSA-PKCS1 signature result');
end;

procedure TestRSASignatureWithPEMLeadingJunk;
var
  LKeyBlob: TBytes;
  LMutatedPEM: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  I: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LMutatedPEM := BuildPEMPrivateKeyWithLeadingJunk(LKeyBlob);

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($73 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMutatedPEM,
      LInput,
      LSig,
      LErr
    ),
    'RSA-PKCS1 signing with leading PEM junk failed: ' + LErr
  );
  AssertEqualsInt(256, Length(LSig), 'PEM leading-junk signature length mismatch');
end;

procedure TestRSASignatureUsesFirstUsableRSAKeyBlock;
var
  LKeyBlobA: TBytes;
  LKeyBlobB: TBytes;
  LCombinedPEM: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSigA: TBytes;
  LSigCombined: TBytes;
  LErr: string;
  I: Integer;
  LDiff: Integer;
begin
  LKeyBlobA := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LKeyBlobB := LoadFileBytes('tests/certificate/test_certs/recipient_key.pem');
  LCombinedPEM := BuildPEMWithMultiplePrivateKeys(LKeyBlobA, LKeyBlobB);

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($77 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlobA,
      LInput,
      LSigA,
      LErr
    ),
    'RSA-PKCS1 signing with base key failed: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LCombinedPEM,
      LInput,
      LSigCombined,
      LErr
    ),
    'RSA-PKCS1 signing with multi-key PEM failed: ' + LErr
  );

  AssertEqualsInt(Length(LSigA), Length(LSigCombined), 'Multi-key PEM signature length mismatch');
  LDiff := 0;
  for I := 0 to Length(LSigA) - 1 do
    if LSigA[I] <> LSigCombined[I] then
      Inc(LDiff);
  AssertEqualsInt(0, LDiff, 'Signer should use first usable RSA key block in PEM material');
end;

procedure TestRSASignatureWith1024BitKeyLength;
var
  LKeyBlob: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  I: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key_1024.pem');
  AssertTrue(Length(LKeyBlob) > 0, 'Fixture 1024-bit key blob should not be empty');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($7A + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LSig,
      LErr
    ),
    'RSA-PKCS1 signing with generated 1024-bit key failed: ' + LErr
  );
  AssertEqualsInt(128, Length(LSig), 'Generated 1024-bit key should produce 128-byte signature');
end;

procedure TestRSASignatureRejectsPEMWithoutPrivateKeyBlock;
var
  LCertBlob: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  I: Integer;
begin
  LCertBlob := LoadFileBytes('tests/certificate/test_certs/signer_cert.pem');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($6A + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LCertBlob,
      LInput,
      LSig,
      LErr
    ),
    'PEM certificate blob should not be accepted as private key material'
  );
  AssertContains(LErr, 'No private key block found in PEM blob', 'Expected missing-private-key-block diagnostic');
end;

procedure TestRSASignatureErrorMessagesAreStable;
var
  LInput: TBytes;
begin
  LInput := BuildDeterministicCertVerifyInput($6A);

  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    [],
    LInput,
    'Private key material is empty',
    'stable-empty-key'
  );

  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    [$00, $01, $02],
    LInput,
    'Unsupported DER private key format',
    'stable-malformed-der'
  );
end;

procedure TestRSASignatureErrorSurfaceMatrix;
var
  LKeyBlob: TBytes;
  LInput: TBytes;
  LNoKeyPEM: TBytes;
  LEncryptedPEM: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LInput := BuildDeterministicCertVerifyInput($92);

  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LKeyBlob,
    [],
    'CertificateVerify input is empty',
    'matrix-empty-input'
  );

  AssertSignerFailureContainsAny(
    TLS13_SIG_ECDSA_SECP256R1_SHA256,
    LKeyBlob,
    LInput,
    [
      'not EC',
      'No usable EC',
      'algorithm/curve'
    ],
    'matrix-unsupported-scheme'
  );

  LNoKeyPEM := TEncoding.ASCII.GetBytes(
    '-----BEGIN CERTIFICATE-----' + LineEnding +
    'AQID' + LineEnding +
    '-----END CERTIFICATE-----' + LineEnding
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LNoKeyPEM,
    LInput,
    'No private key block found in PEM blob',
    'matrix-no-private-key-block'
  );

  LEncryptedPEM := TEncoding.ASCII.GetBytes(
    '-----BEGIN ENCRYPTED PRIVATE KEY-----' + LineEnding +
    'AQID' + LineEnding +
    '-----END ENCRYPTED PRIVATE KEY-----' + LineEnding
  );
  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LEncryptedPEM,
    LInput,
    [
      'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer',
      'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer'
    ],
    'matrix-encrypted-pem'
  );
end;

procedure TestRSASignatureBoundaryMatrixExtended;
var
  LKeyBlob: TBytes;
  LCertBlob: TBytes;
  LInput: TBytes;
  LMalformedPEM: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LCertBlob := LoadFileBytes('tests/certificate/test_certs/signer_cert.pem');
  LInput := BuildDeterministicCertVerifyInput($A8);

  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LKeyBlob,
    [],
    'CertificateVerify input is empty',
    'boundary-empty-input-pkcs1'
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    LKeyBlob,
    [],
    'CertificateVerify input is empty',
    'boundary-empty-input-pss-rsae'
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    LKeyBlob,
    [],
    'CertificateVerify input is empty',
    'boundary-empty-input-pss-pss'
  );

  AssertSignerFailureContainsAny(
    TLS13_SIG_ECDSA_SECP256R1_SHA256,
    LKeyBlob,
    LInput,
    [
      'not EC',
      'No usable EC',
      'algorithm/curve'
    ],
    'boundary-unsupported-ecdsa'
  );
  AssertSignerFailureContains(
    TLS13_SIG_ED25519,
    LKeyBlob,
    LInput,
    'Unsupported signature scheme for pure FreePascal signer',
    'boundary-unsupported-ed25519'
  );

  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    [],
    LInput,
    'Private key material is empty',
    'boundary-empty-key-pkcs1'
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    [],
    LInput,
    'Private key material is empty',
    'boundary-empty-key-pss-rsae'
  );

  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    [$00, $01, $02],
    LInput,
    'Unsupported DER private key format',
    'boundary-malformed-der-pss-pss'
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    LCertBlob,
    LInput,
    'No private key block found in PEM blob',
    'boundary-certificate-pem-not-key'
  );

  LMalformedPEM := TEncoding.ASCII.GetBytes(
    '-----BEGIN PRIVATE KEY-----' + LineEnding +
    '!!!!' + LineEnding +
    '-----END PRIVATE KEY-----' + LineEnding
  );
  AssertSignerFailureNonEmptyError(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMalformedPEM,
    LInput,
    'boundary-malformed-pem-nonempty-error'
  );
end;

procedure TestRSAPSSBoundaryMatrixWaveC;
var
  LKeyBlob: TBytes;
  LCertBlob: TBytes;
  LInput: TBytes;
  LSigA: TBytes;
  LSigB: TBytes;
  LEncryptedPEM: TBytes;
  LErr: string;
  LDiff: Integer;
  I: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LCertBlob := LoadFileBytes('tests/certificate/test_certs/signer_cert.pem');
  LInput := BuildDeterministicCertVerifyInput($B9);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_RSAE_SHA256,
      LKeyBlob,
      LInput,
      LSigA,
      LErr
    ),
    'pss-boundary-rsae-success should sign: ' + LErr
  );
  AssertEqualsInt(256, Length(LSigA), 'pss-boundary-rsae signature length mismatch');

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_PSS_SHA256,
      LKeyBlob,
      LInput,
      LSigA,
      LErr
    ),
    'pss-boundary-pss-success should sign: ' + LErr
  );
  AssertEqualsInt(256, Length(LSigA), 'pss-boundary-pss signature length mismatch');

  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    [],
    LInput,
    'Private key material is empty',
    'pss-boundary-empty-key-rsae'
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    [$00, $01, $02],
    LInput,
    'Unsupported DER private key format',
    'pss-boundary-malformed-der-pss'
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    LCertBlob,
    LInput,
    'No private key block found in PEM blob',
    'pss-boundary-cert-pem-not-key'
  );

  LEncryptedPEM := TEncoding.ASCII.GetBytes(
    '-----BEGIN ENCRYPTED PRIVATE KEY-----' + LineEnding +
    'AQID' + LineEnding +
    '-----END ENCRYPTED PRIVATE KEY-----' + LineEnding
  );
  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    LEncryptedPEM,
    LInput,
    [
      'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer',
      'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer'
    ],
    'pss-boundary-encrypted-pem'
  );
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    LKeyBlob,
    [],
    'CertificateVerify input is empty',
    'pss-boundary-empty-input-pss'
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_PSS_SHA256,
      LKeyBlob,
      LInput,
      LSigA,
      LErr
    ),
    'pss-boundary-randomness-run-a should sign: ' + LErr
  );
  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_PSS_SHA256,
      LKeyBlob,
      LInput,
      LSigB,
      LErr
    ),
    'pss-boundary-randomness-run-b should sign: ' + LErr
  );
  AssertEqualsInt(Length(LSigA), Length(LSigB), 'pss-boundary-randomness signature length mismatch');

  LDiff := 0;
  for I := 0 to Length(LSigA) - 1 do
    if LSigA[I] <> LSigB[I] then
      Inc(LDiff);
  AssertTrue(LDiff > 0, 'pss-boundary-randomness signatures should differ due to randomized salt');
end;

procedure TestRSASmallModulusBoundaryMatrixWaveD;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LPKCS1: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LMutated: TBytes;

  procedure AssertShortModulusError(
    AScheme: Word;
    AModulusConstant: Byte;
    const ANeedle: string;
    const ALabel: string
  );
  begin
    AssertTrue(
      TrySetPKCS1FieldToConstant(LPKCS1, 1, AModulusConstant, LMutated),
      ALabel + ': failed to set modulus constant'
    );
    AssertSignerFailureContains(
      AScheme,
      LMutated,
      LInput,
      ANeedle,
      ALabel
    );
  end;

begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'small-mod-waveD: failed to extract DER');

  if LType = pemPrivateKey then
    AssertTrue(TryExtractPKCS1FromPKCS8DER(LDER, LPKCS1), 'small-mod-waveD: failed to extract inner PKCS#1 DER')
  else
    LPKCS1 := Copy(LDER, 0, Length(LDER));

  LInput := BuildDeterministicCertVerifyInput($ED);

  AssertShortModulusError(TLS13_SIG_RSA_PKCS1_SHA256, 0, 'Unsupported DER private key format', 'small-mod-pkcs1-zero');
  AssertShortModulusError(TLS13_SIG_RSA_PKCS1_SHA256, 1, 'RSA modulus is too short for PKCS#1 v1.5 SHA-256 encoding', 'small-mod-pkcs1-one');
  AssertShortModulusError(TLS13_SIG_RSA_PKCS1_SHA256, 2, 'RSA modulus is too short for PKCS#1 v1.5 SHA-256 encoding', 'small-mod-pkcs1-two');
  AssertShortModulusError(TLS13_SIG_RSA_PKCS1_SHA256, 3, 'RSA modulus is too short for PKCS#1 v1.5 SHA-256 encoding', 'small-mod-pkcs1-three');

  AssertShortModulusError(TLS13_SIG_RSA_PSS_RSAE_SHA256, 1, 'RSA modulus bit length is invalid for PSS', 'small-mod-pss-rsae-one');
  AssertShortModulusError(TLS13_SIG_RSA_PSS_RSAE_SHA256, 2, 'RSA modulus too short for SHA-256 PSS encoding', 'small-mod-pss-rsae-two');
  AssertShortModulusError(TLS13_SIG_RSA_PSS_RSAE_SHA256, 3, 'RSA modulus too short for SHA-256 PSS encoding', 'small-mod-pss-rsae-three');

  AssertShortModulusError(TLS13_SIG_RSA_PSS_PSS_SHA256, 1, 'RSA modulus bit length is invalid for PSS', 'small-mod-pss-pss-one');
  AssertShortModulusError(TLS13_SIG_RSA_PSS_PSS_SHA256, 2, 'RSA modulus too short for SHA-256 PSS encoding', 'small-mod-pss-pss-two');
  AssertShortModulusError(TLS13_SIG_RSA_PSS_PSS_SHA256, 3, 'RSA modulus too short for SHA-256 PSS encoding', 'small-mod-pss-pss-three');
end;

procedure TestRSASignatureHandlesMalformedDERVariants;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LTruncated: TBytes;
  LMutated: TBytes;
  LAlgTagOffset: Integer;
  LErr: string;
  LSig: TBytes;
  I: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'Failed to extract DER for malformed-DER tests');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($88 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  LTruncated := TruncateBytesFromEnd(LDER, 1);
  AssertMalformedDERRejected(LTruncated, LInput, 'der-truncated-1');

  LTruncated := TruncateBytesFromEnd(LDER, 8);
  AssertMalformedDERRejected(LTruncated, LInput, 'der-truncated-8');

  LTruncated := TruncateBytesFromEnd(LDER, 32);
  AssertMalformedDERRejected(LTruncated, LInput, 'der-truncated-32');

  LMutated := CopyBytesWithMutation(LDER, 0, $31);
  AssertMalformedDERRejected(LMutated, LInput, 'der-root-not-sequence');

  LMutated := CopyBytesWithMutation(LDER, 1, $FF);
  AssertMalformedDERRejected(LMutated, LInput, 'der-invalid-length-byte');

  AssertTrue(
    TryLocatePKCS8AlgorithmIdentifierTagOffset(LDER, LAlgTagOffset),
    'Failed to locate PKCS#8 AlgorithmIdentifier tag offset'
  );
  LMutated := CopyBytesWithMutation(LDER, LAlgTagOffset, $31);
  AssertMalformedDERRejected(LMutated, LInput, 'der-alg-id-not-sequence');

  LMutated := CopyBytesWithMutation(LDER, LAlgTagOffset + 1, $00);
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMutated,
      LInput,
      LSig,
      LErr
    ),
    'der-alg-id-short-seq should be rejected'
  );
  AssertContains(LErr, 'Unsupported DER private key format', 'der-alg-id-short-seq rejection message mismatch');
end;

procedure TestRSASignatureRejectsExtendedDERMutations;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LPKCS1: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LMutated: TBytes;
  LTruncated: TBytes;
  LFieldTagOffset: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'Extended-DER: failed to extract DER');

  if LType = pemPrivateKey then
    AssertTrue(TryExtractPKCS1FromPKCS8DER(LDER, LPKCS1), 'Extended-DER: failed to extract inner PKCS#1 DER')
  else
    LPKCS1 := Copy(LDER, 0, Length(LDER));

  LInput := BuildDeterministicCertVerifyInput($B2);

  LTruncated := TruncateBytesFromEnd(LDER, 2);
  AssertMalformedDERRejected(LTruncated, LInput, 'der-ext-truncated-2');
  LTruncated := TruncateBytesFromEnd(LDER, 4);
  AssertMalformedDERRejected(LTruncated, LInput, 'der-ext-truncated-4');
  LTruncated := TruncateBytesFromEnd(LDER, 12);
  AssertMalformedDERRejected(LTruncated, LInput, 'der-ext-truncated-12');
  LTruncated := TruncateBytesFromEnd(LDER, 24);
  AssertMalformedDERRejected(LTruncated, LInput, 'der-ext-truncated-24');
  LTruncated := TruncateBytesFromEnd(LDER, 48);
  AssertMalformedDERRejected(LTruncated, LInput, 'der-ext-truncated-48');

  LMutated := CopyBytesWithMutation(LDER, 1, $00);
  AssertMalformedDERRejected(LMutated, LInput, 'der-ext-root-len-zero');
  LMutated := CopyBytesWithMutation(LDER, 1, $FE);
  AssertMalformedDERRejected(LMutated, LInput, 'der-ext-root-len-fe');

  LMutated := CopyBytesWithMutation(LPKCS1, 0, $31);
  AssertMalformedDERRejected(LMutated, LInput, 'der-ext-pkcs1-root-not-seq');

  AssertTrue(TryLocatePKCS1IntegerFieldTagOffset(LPKCS1, 1, LFieldTagOffset), 'Extended-DER: failed to locate modulus field tag');
  LMutated := CopyBytesWithMutation(LPKCS1, LFieldTagOffset, $05);
  AssertMalformedDERRejected(LMutated, LInput, 'der-ext-pkcs1-modulus-not-integer');

  AssertTrue(TryLocatePKCS1IntegerFieldTagOffset(LPKCS1, 3, LFieldTagOffset), 'Extended-DER: failed to locate privateExponent field tag');
  LMutated := CopyBytesWithMutation(LPKCS1, LFieldTagOffset, $05);
  AssertMalformedDERRejected(LMutated, LInput, 'der-ext-pkcs1-privateexp-not-integer');
end;

procedure TestRSASignatureSelectsRSAFromMixedPEMBlocks;
var
  LKeyBlob: TBytes;
  LBaselineSig: TBytes;
  LErr: string;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LRSAUnknown: TBytes;
  LUnknownRSA: TBytes;
  LECAndRSA: TBytes;
  LCertAndRSA: TBytes;
  LUnknownPEM: TBytes;
  LECPRIVATEPEM: TBytes;
  LCertPEM: TBytes;
  I: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LCertPEM := LoadFileBytes('tests/certificate/test_certs/signer_cert.pem');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($90 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LBaselineSig,
      LErr
    ),
    'baseline signing failed for mixed-PEM tests: ' + LErr
  );

  LUnknownPEM := BuildPEMBlockWithType('FAFAFA UNKNOWN KEY', [$01, $02, $03]);
  LECPRIVATEPEM := BuildPEMBlockWithType('EC PRIVATE KEY', [$01, $02, $03]);

  LRSAUnknown := BuildPEMWithMultiplePrivateKeys(LKeyBlob, LUnknownPEM);
  AssertPKCS1SignatureMatchesBaseline(LRSAUnknown, LBaselineSig, LInput, 'mixedpem-rsa-then-unknown');

  LUnknownRSA := BuildPEMWithMultiplePrivateKeys(LUnknownPEM, LKeyBlob);
  AssertPKCS1SignatureMatchesBaseline(LUnknownRSA, LBaselineSig, LInput, 'mixedpem-unknown-then-rsa');

  LECAndRSA := BuildPEMWithMultiplePrivateKeys(LECPRIVATEPEM, LKeyBlob);
  AssertPKCS1SignatureMatchesBaseline(LECAndRSA, LBaselineSig, LInput, 'mixedpem-ec-then-rsa');

  LCertAndRSA := BuildPEMWithMultiplePrivateKeys(LCertPEM, LKeyBlob);
  AssertPKCS1SignatureMatchesBaseline(LCertAndRSA, LBaselineSig, LInput, 'mixedpem-cert-then-rsa');
end;

procedure TestRSASignatureRejectsPEMWithoutUsableRSAKey;
var
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LErr: string;
  LSig: TBytes;
  LUnknownPEM: TBytes;
  LECPRIVATEPEM: TBytes;
  LPEMNoRSA: TBytes;
  LPEMOnlyUnknown: TBytes;
  I: Integer;
begin
  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($A0 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  LUnknownPEM := BuildPEMBlockWithType('FAFAFA UNKNOWN KEY', [$01, $02, $03]);
  LECPRIVATEPEM := BuildPEMBlockWithType('EC PRIVATE KEY', [$01, $02, $03]);
  LPEMNoRSA := BuildPEMWithMultiplePrivateKeys(LECPRIVATEPEM, LUnknownPEM);

  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LPEMNoRSA,
      LInput,
      LSig,
      LErr
    ),
    'PEM without usable RSA key should be rejected'
  );
  AssertTrue(
    (Pos('No usable RSA private key found in PEM material', LErr) > 0) or
    (Pos('PEM private key is not RSA', LErr) > 0),
    'no-rsa-pem error message mismatch'
  );

  LPEMOnlyUnknown := LUnknownPEM;
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LPEMOnlyUnknown,
      LInput,
      LSig,
      LErr
    ),
    'PEM with only unknown key block should be rejected'
  );
  AssertTrue(Length(LErr) > 0, 'unknown-only-pem should return a non-empty error message');
end;

procedure TestRSASignatureRejectsMalformedPEMEnvelopes;
var
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LErr: string;
  LSig: TBytes;
  LMissingEnd: TBytes;
  LMismatchedMarker: TBytes;
  LBrokenBase64: TBytes;
  I: Integer;
begin
  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($B0 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  LMissingEnd := TEncoding.ASCII.GetBytes(
    '-----BEGIN PRIVATE KEY-----' + LineEnding +
    'MIIEvQIBADANBgkq' + LineEnding
  );

  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMissingEnd,
      LInput,
      LSig,
      LErr
    ),
    'missing-end PEM should be rejected'
  );
  AssertContains(LErr, 'No private key block found in PEM blob', 'missing-end PEM error message mismatch');

  LMismatchedMarker := TEncoding.ASCII.GetBytes(
    '-----BEGIN PRIVATE KEY-----' + LineEnding +
    'AQID' + LineEnding +
    '-----END RSA PRIVATE KEY-----' + LineEnding
  );
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMismatchedMarker,
      LInput,
      LSig,
      LErr
    ),
    'mismatched-marker PEM should be rejected'
  );
  AssertContains(LErr, 'No private key block found in PEM blob', 'mismatched-marker PEM error message mismatch');

  LBrokenBase64 := TEncoding.ASCII.GetBytes(
    '-----BEGIN PRIVATE KEY-----' + LineEnding +
    '!!!!' + LineEnding +
    '-----END PRIVATE KEY-----' + LineEnding
  );
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LBrokenBase64,
      LInput,
      LSig,
      LErr
    ),
    'broken-base64 PEM should be rejected'
  );
  AssertTrue(Length(LErr) > 0, 'broken-base64 PEM should produce non-empty error message');
end;

procedure TestRSASignatureRejectsEncryptedPEMBlock;
var
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LErr: string;
  LSig: TBytes;
  LEncryptedLikePEM: TBytes;
  I: Integer;
begin
  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($C0 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  LEncryptedLikePEM := TEncoding.ASCII.GetBytes(
    '-----BEGIN ENCRYPTED PRIVATE KEY-----' + LineEnding +
    'AQID' + LineEnding +
    '-----END ENCRYPTED PRIVATE KEY-----' + LineEnding
  );

  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LEncryptedLikePEM,
      LInput,
      LSig,
      LErr
    ),
    'encrypted private key block should be rejected'
  );
  AssertContains(LErr, 'Encrypted PKCS#8 private keys are not supported', 'encrypted-key rejection message mismatch');
end;

procedure TestPEMMixedAndEncryptedMatrixWaveG;
var
  LKeyBlob: TBytes;
  LCertPEM: TBytes;
  LUnknownPEM: TBytes;
  LECPRIVATEPEM: TBytes;
  LEncryptedPEM: TBytes;
  LCombined: TBytes;
  LBaselineSig: TBytes;
  LInput: TBytes;
  LErr: string;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LCertPEM := LoadFileBytes('tests/certificate/test_certs/signer_cert.pem');
  LInput := BuildDeterministicCertVerifyInput($B6);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LBaselineSig,
      LErr
    ),
    'pem-waveg-baseline signing failed: ' + LErr
  );

  LUnknownPEM := BuildPEMBlockWithType('FAFAFA UNKNOWN KEY', [$01, $02, $03]);
  LECPRIVATEPEM := BuildPEMBlockWithType('EC PRIVATE KEY', [$01, $02, $03]);
  LEncryptedPEM := TEncoding.ASCII.GetBytes(
    '-----BEGIN ENCRYPTED PRIVATE KEY-----' + LineEnding +
    'AQID' + LineEnding +
    '-----END ENCRYPTED PRIVATE KEY-----' + LineEnding
  );

  LCombined := BuildPEMWithMultiplePrivateKeys(LEncryptedPEM, LKeyBlob);
  AssertPKCS1SignatureMatchesBaseline(LCombined, LBaselineSig, LInput, 'pem-waveg-encrypted-then-rsa');

  LCombined := BuildPEMWithMultiplePrivateKeys(LKeyBlob, LEncryptedPEM);
  AssertPKCS1SignatureMatchesBaseline(LCombined, LBaselineSig, LInput, 'pem-waveg-rsa-then-encrypted');

  LCombined := BuildPEMWithMultiplePrivateKeys(BuildPEMWithMultiplePrivateKeys(LEncryptedPEM, LUnknownPEM), LKeyBlob);
  AssertPKCS1SignatureMatchesBaseline(LCombined, LBaselineSig, LInput, 'pem-waveg-encrypted-unknown-rsa');

  LCombined := BuildPEMWithMultiplePrivateKeys(BuildPEMWithMultiplePrivateKeys(LUnknownPEM, LEncryptedPEM), LKeyBlob);
  AssertPKCS1SignatureMatchesBaseline(LCombined, LBaselineSig, LInput, 'pem-waveg-unknown-encrypted-rsa');

  LCombined := BuildPEMWithMultiplePrivateKeys(BuildPEMWithMultiplePrivateKeys(LCertPEM, LEncryptedPEM), LKeyBlob);
  AssertPKCS1SignatureMatchesBaseline(LCombined, LBaselineSig, LInput, 'pem-waveg-cert-encrypted-rsa');

  LCombined := BuildPEMWithMultiplePrivateKeys(BuildPEMWithMultiplePrivateKeys(LECPRIVATEPEM, LEncryptedPEM), LKeyBlob);
  AssertPKCS1SignatureMatchesBaseline(LCombined, LBaselineSig, LInput, 'pem-waveg-ec-encrypted-rsa');

  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LEncryptedPEM,
    LInput,
    [
      'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer',
      'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer'
    ],
    'pem-waveg-encrypted-only'
  );

  LCombined := BuildPEMWithMultiplePrivateKeys(LUnknownPEM, LEncryptedPEM);
  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LCombined,
    LInput,
    [
      'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer',
      'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer'
    ],
    'pem-waveg-unknown-encrypted-only'
  );

  LCombined := BuildPEMWithMultiplePrivateKeys(LECPRIVATEPEM, LEncryptedPEM);
  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LCombined,
    LInput,
    [
      'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer',
      'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer'
    ],
    'pem-waveg-ec-encrypted-only'
  );

  LCombined := BuildPEMWithMultiplePrivateKeys(LECPRIVATEPEM, LUnknownPEM);
  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LCombined,
    LInput,
    [
      'PEM private key is not RSA',
      'No usable RSA private key found in PEM material',
      'No private key block found in PEM blob'
    ],
    'pem-waveg-ec-unknown-only'
  );

  LCombined := BuildPEMWithMultiplePrivateKeys(LCertPEM, LUnknownPEM);
  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LCombined,
    LInput,
    [
      'PEM private key is not RSA',
      'No usable RSA private key found in PEM material',
      'No private key block found in PEM blob'
    ],
    'pem-waveg-cert-unknown-only'
  );

  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LUnknownPEM,
    LInput,
    [
      'PEM private key is not RSA',
      'No usable RSA private key found in PEM material',
      'No private key block found in PEM blob'
    ],
    'pem-waveg-unknown-only'
  );
end;

procedure TestErrorSurfaceCrossSchemeMatrixWaveG;
var
  LKeyBlob: TBytes;
  LCertBlob: TBytes;
  LInput: TBytes;
  LMalformedDER: TBytes;
  LEncryptedPEM: TBytes;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  LCertBlob := LoadFileBytes('tests/certificate/test_certs/signer_cert.pem');
  LInput := BuildDeterministicCertVerifyInput($C6);
  LMalformedDER := [$00, $01, $02];
  LEncryptedPEM := TEncoding.ASCII.GetBytes(
    '-----BEGIN ENCRYPTED PRIVATE KEY-----' + LineEnding +
    'AQID' + LineEnding +
    '-----END ENCRYPTED PRIVATE KEY-----' + LineEnding
  );

  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LKeyBlob, [], 'CertificateVerify input is empty', 'cross-waveg-empty-input-pkcs1');
  AssertSignerFailureContains(TLS13_SIG_RSA_PSS_RSAE_SHA256, LKeyBlob, [], 'CertificateVerify input is empty', 'cross-waveg-empty-input-pss-rsae');
  AssertSignerFailureContains(TLS13_SIG_RSA_PSS_PSS_SHA256, LKeyBlob, [], 'CertificateVerify input is empty', 'cross-waveg-empty-input-pss-pss');

  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, [], LInput, 'Private key material is empty', 'cross-waveg-empty-key-pkcs1');
  AssertSignerFailureContains(TLS13_SIG_RSA_PSS_RSAE_SHA256, [], LInput, 'Private key material is empty', 'cross-waveg-empty-key-pss-rsae');
  AssertSignerFailureContains(TLS13_SIG_RSA_PSS_PSS_SHA256, [], LInput, 'Private key material is empty', 'cross-waveg-empty-key-pss-pss');

  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LMalformedDER, LInput, 'Unsupported DER private key format', 'cross-waveg-malformed-der-pkcs1');
  AssertSignerFailureContains(TLS13_SIG_RSA_PSS_RSAE_SHA256, LMalformedDER, LInput, 'Unsupported DER private key format', 'cross-waveg-malformed-der-pss-rsae');
  AssertSignerFailureContains(TLS13_SIG_RSA_PSS_PSS_SHA256, LMalformedDER, LInput, 'Unsupported DER private key format', 'cross-waveg-malformed-der-pss-pss');

  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LCertBlob, LInput, 'No private key block found in PEM blob', 'cross-waveg-cert-pem-pkcs1');
  AssertSignerFailureContains(TLS13_SIG_RSA_PSS_RSAE_SHA256, LCertBlob, LInput, 'No private key block found in PEM blob', 'cross-waveg-cert-pem-pss-rsae');
  AssertSignerFailureContains(TLS13_SIG_RSA_PSS_PSS_SHA256, LCertBlob, LInput, 'No private key block found in PEM blob', 'cross-waveg-cert-pem-pss-pss');

  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LEncryptedPEM,
    LInput,
    [
      'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer',
      'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer'
    ],
    'cross-waveg-encrypted-pkcs1'
  );
  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PSS_RSAE_SHA256,
    LEncryptedPEM,
    LInput,
    [
      'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer',
      'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer'
    ],
    'cross-waveg-encrypted-pss-rsae'
  );
  AssertSignerFailureContainsAny(
    TLS13_SIG_RSA_PSS_PSS_SHA256,
    LEncryptedPEM,
    LInput,
    [
      'Encrypted PKCS#8 private keys are not supported in pure FreePascal TLS13 signer',
      'Encrypted PEM private keys are not supported in pure FreePascal TLS13 signer'
    ],
    'cross-waveg-encrypted-pss-pss'
  );
end;

procedure TestPKCS1VersionAndPublicExponentMutationMatrixWaveG;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LPKCS1: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LMutated: TBytes;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS1-waveg: failed to extract DER');

  if LType = pemPrivateKey then
    AssertTrue(TryExtractPKCS1FromPKCS8DER(LDER, LPKCS1), 'PKCS1-waveg: failed to extract inner PKCS#1 DER')
  else
    LPKCS1 := Copy(LDER, 0, Length(LDER));

  LInput := BuildDeterministicCertVerifyInput($D6);

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 0, $05, LMutated), 'PKCS1-waveg: mutate version tag null failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-version-tag-null');

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 0, $30, LMutated), 'PKCS1-waveg: mutate version tag sequence failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-version-tag-sequence');

  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 0, $00, LMutated), 'PKCS1-waveg: mutate version len=0 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-version-len-zero');

  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 0, $FF, LMutated), 'PKCS1-waveg: mutate version len=ff failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-version-len-ff');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 0, 1, LMutated), 'PKCS1-waveg: set version=1 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-version-one');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 0, 2, LMutated), 'PKCS1-waveg: set version=2 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-version-two');

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 2, $05, LMutated), 'PKCS1-waveg: mutate publicExponent tag null failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-publicexp-tag-null');

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 2, $04, LMutated), 'PKCS1-waveg: mutate publicExponent tag octet failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-publicexp-tag-octet');

  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 2, $00, LMutated), 'PKCS1-waveg: mutate publicExponent len=0 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-publicexp-len-zero');

  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 2, $FF, LMutated), 'PKCS1-waveg: mutate publicExponent len=ff failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-publicexp-len-ff');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 2, 1, LMutated), 'PKCS1-waveg: set publicExponent=1 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-publicexp-one');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 2, 3, LMutated), 'PKCS1-waveg: set publicExponent=3 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-waveg-publicexp-three');
end;

procedure TestRSASignatureRejectsPKCS8FieldShapeMutations;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LMutated: TBytes;
  LOffset: Integer;
  LLen: Integer;
  LTagOffset: Integer;
  I: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS8-shape: failed to extract DER');
  AssertTrue(LType = pemPrivateKey, 'PKCS8-shape: expected PKCS#8 key type');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($D0 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(TryLocatePKCS8AlgorithmIdentifierTagOffset(LDER, LTagOffset), 'PKCS8-shape: locate alg tag failed');
  LMutated := CopyBytesWithMutation(LDER, LTagOffset, $31);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-alg-not-sequence');

  AssertTrue(TryLocatePKCS8PrivateKeyTagOffset(LDER, LTagOffset), 'PKCS8-shape: locate privateKey tag failed');
  LMutated := CopyBytesWithMutation(LDER, LTagOffset, $05);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-privatekey-not-octetstring');

  AssertTrue(TryLocatePKCS8PrivateKeyOctetStringValue(LDER, LOffset, LLen), 'PKCS8-shape: locate privateKey octets failed');
  LMutated := Copy(LDER, 0, Length(LDER));
  FillChar(LMutated[LOffset], LLen, 0);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-empty-inner-pkcs1');
end;

procedure TestRSASignatureRejectsPKCS8AlgorithmOIDMutations;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LMutated: TBytes;
  LOIDOffset: Integer;
  LOIDLength: Integer;
  LOIDTagOffset: Integer;
  I: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS8-oid: failed to extract DER');
  AssertTrue(LType = pemPrivateKey, 'PKCS8-oid: expected PKCS#8 key type');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($E0 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryLocatePKCS8AlgorithmOIDValue(LDER, LOIDOffset, LOIDLength, LOIDTagOffset),
    'PKCS8-oid: failed to locate algorithm OID'
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDTagOffset, $02);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-oid-tag-not-oid');

  LMutated := Copy(LDER, 0, Length(LDER));
  FillChar(LMutated[LOIDOffset], LOIDLength, 0);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-oid-bytes-zeroed');

  LMutated := Copy(LDER, 0, Length(LDER));
  if LOIDLength > 0 then
    LMutated[LOIDOffset + LOIDLength - 1] := LMutated[LOIDOffset + LOIDLength - 1] xor $01;
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-oid-last-byte-flipped');
end;

procedure TestPKCS8LengthMutationMatrixWaveC;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LMutated: TBytes;
  LAlgTagOffset: Integer;
  LPrivateKeyTagOffset: Integer;
  LOIDOffset: Integer;
  LOIDLength: Integer;
  LOIDTagOffset: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS8-len: failed to extract DER');
  AssertTrue(LType = pemPrivateKey, 'PKCS8-len: expected PKCS#8 key type');

  LInput := BuildDeterministicCertVerifyInput($C8);

  AssertTrue(Length(LDER) > 3, 'PKCS8-len: DER too short for root length mutations');
  LMutated := CopyBytesWithMutation(LDER, 1, $00);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-root-zero');
  LMutated := CopyBytesWithMutation(LDER, 1, $01);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-root-one');
  LMutated := CopyBytesWithMutation(LDER, 1, $FF);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-root-ff');

  AssertTrue(TryLocatePKCS8AlgorithmIdentifierTagOffset(LDER, LAlgTagOffset), 'PKCS8-len: locate AlgorithmIdentifier failed');
  AssertTrue((LAlgTagOffset + 1) < Length(LDER), 'PKCS8-len: AlgorithmIdentifier length byte out of range');
  LMutated := CopyBytesWithMutation(LDER, LAlgTagOffset + 1, $00);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-alg-zero');
  LMutated := CopyBytesWithMutation(LDER, LAlgTagOffset + 1, $01);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-alg-one');
  LMutated := CopyBytesWithMutation(LDER, LAlgTagOffset + 1, $FF);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-alg-ff');

  AssertTrue(TryLocatePKCS8AlgorithmOIDValue(LDER, LOIDOffset, LOIDLength, LOIDTagOffset), 'PKCS8-len: locate OID failed');
  AssertTrue((LOIDTagOffset + 1) < Length(LDER), 'PKCS8-len: OID length byte out of range');
  LMutated := CopyBytesWithMutation(LDER, LOIDTagOffset + 1, $00);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-oid-zero');
  LMutated := CopyBytesWithMutation(LDER, LOIDTagOffset + 1, $FF);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-oid-ff');

  AssertTrue(TryLocatePKCS8PrivateKeyTagOffset(LDER, LPrivateKeyTagOffset), 'PKCS8-len: locate privateKey tag failed');
  AssertTrue((LPrivateKeyTagOffset + 1) < Length(LDER), 'PKCS8-len: privateKey length byte out of range');
  LMutated := CopyBytesWithMutation(LDER, LPrivateKeyTagOffset + 1, $00);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-privatekey-zero');
  LMutated := CopyBytesWithMutation(LDER, LPrivateKeyTagOffset + 1, $FF);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs8-len-privatekey-ff');
end;

procedure TestPKCS8OIDMatrixWaveE;
const
  OID_RSASSA_PSS: array[0..8] of Byte = ($2A, $86, $48, $86, $F7, $0D, $01, $01, $0A);
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  LMutated: TBytes;
  LOIDOffset: Integer;
  LOIDLength: Integer;
  LOIDTagOffset: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS8-oid-wavee: failed to extract DER');
  AssertTrue(LType = pemPrivateKey, 'PKCS8-oid-wavee: expected PKCS#8 key type');
  AssertTrue(
    TryLocatePKCS8AlgorithmOIDValue(LDER, LOIDOffset, LOIDLength, LOIDTagOffset),
    'PKCS8-oid-wavee: failed to locate algorithm OID'
  );
  AssertEqualsInt(9, LOIDLength, 'PKCS8-oid-wavee: unexpected OID byte length');

  LInput := BuildDeterministicCertVerifyInput($F2);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LDER,
      LInput,
      LSig,
      LErr
    ),
    'pkcs8-oid-wavee-baseline-rsa-oid should sign: ' + LErr
  );

  LMutated := Copy(LDER, 0, Length(LDER));
  Move(OID_RSASSA_PSS[0], LMutated[LOIDOffset], Length(OID_RSASSA_PSS));
  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LMutated,
      LInput,
      LSig,
      LErr
    ),
    'pkcs8-oid-wavee-rsassa-pss-oid should sign: ' + LErr
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDTagOffset, $02);
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMutated,
    LInput,
    'Unsupported DER private key format',
    'pkcs8-oid-wavee-tag-not-oid'
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDTagOffset + 1, $00);
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMutated,
    LInput,
    'Unsupported DER private key format',
    'pkcs8-oid-wavee-len-zero'
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDTagOffset + 1, $FF);
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMutated,
    LInput,
    'Unsupported DER private key format',
    'pkcs8-oid-wavee-len-ff'
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 0, LDER[LOIDOffset + 0] xor $01);
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMutated,
    LInput,
    'Unsupported DER private key format',
    'pkcs8-oid-wavee-byte0-flip'
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 2, LDER[LOIDOffset + 2] xor $01);
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMutated,
    LInput,
    'Unsupported DER private key format',
    'pkcs8-oid-wavee-byte2-flip'
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 4, LDER[LOIDOffset + 4] xor $01);
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMutated,
    LInput,
    'Unsupported DER private key format',
    'pkcs8-oid-wavee-byte4-flip'
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 7, LDER[LOIDOffset + 7] xor $01);
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMutated,
    LInput,
    'Unsupported DER private key format',
    'pkcs8-oid-wavee-byte7-flip'
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 8, $0B);
  AssertSignerFailureContains(
    TLS13_SIG_RSA_PKCS1_SHA256,
    LMutated,
    LInput,
    'Unsupported DER private key format',
    'pkcs8-oid-wavee-last-byte-unsupported'
  );
end;

procedure TestPKCS8OIDMatrixWaveF;
const
  OID_RSASSA_PSS: array[0..8] of Byte = ($2A, $86, $48, $86, $F7, $0D, $01, $01, $0A);
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  LMutated: TBytes;
  LOIDOffset: Integer;
  LOIDLength: Integer;
  LOIDTagOffset: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS8-oid-wavef: failed to extract DER');
  AssertTrue(LType = pemPrivateKey, 'PKCS8-oid-wavef: expected PKCS#8 key type');
  AssertTrue(
    TryLocatePKCS8AlgorithmOIDValue(LDER, LOIDOffset, LOIDLength, LOIDTagOffset),
    'PKCS8-oid-wavef: failed to locate algorithm OID'
  );
  AssertEqualsInt(9, LOIDLength, 'PKCS8-oid-wavef: unexpected OID length');

  LInput := BuildDeterministicCertVerifyInput($FA);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_RSAE_SHA256,
      LDER,
      LInput,
      LSig,
      LErr
    ),
    'pkcs8-oid-wavef-baseline-pss-rsae should sign: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_PSS_SHA256,
      LDER,
      LInput,
      LSig,
      LErr
    ),
    'pkcs8-oid-wavef-baseline-pss-pss should sign: ' + LErr
  );

  LMutated := Copy(LDER, 0, Length(LDER));
  Move(OID_RSASSA_PSS[0], LMutated[LOIDOffset], Length(OID_RSASSA_PSS));
  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_RSAE_SHA256,
      LMutated,
      LInput,
      LSig,
      LErr
    ),
    'pkcs8-oid-wavef-rsassa-pss-oid-rsae should sign: ' + LErr
  );

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PSS_PSS_SHA256,
      LMutated,
      LInput,
      LSig,
      LErr
    ),
    'pkcs8-oid-wavef-rsassa-pss-oid-pss should sign: ' + LErr
  );

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 1, LDER[LOIDOffset + 1] xor $01);
  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LMutated, LInput, 'Unsupported DER private key format', 'pkcs8-oid-wavef-byte1-flip');

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 3, LDER[LOIDOffset + 3] xor $01);
  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LMutated, LInput, 'Unsupported DER private key format', 'pkcs8-oid-wavef-byte3-flip');

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 5, LDER[LOIDOffset + 5] xor $01);
  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LMutated, LInput, 'Unsupported DER private key format', 'pkcs8-oid-wavef-byte5-flip');

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 6, LDER[LOIDOffset + 6] xor $01);
  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LMutated, LInput, 'Unsupported DER private key format', 'pkcs8-oid-wavef-byte6-flip');

  LMutated := CopyBytesWithMutation(LDER, LOIDOffset + 8, $02);
  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LMutated, LInput, 'Unsupported DER private key format', 'pkcs8-oid-wavef-last-byte-02');

  LMutated := CopyBytesWithMutation(LDER, LOIDTagOffset + 1, $08);
  AssertSignerFailureContains(TLS13_SIG_RSA_PKCS1_SHA256, LMutated, LInput, 'Unsupported DER private key format', 'pkcs8-oid-wavef-len-08');
end;

procedure TestRSASignatureRejectsPKCS1CoreFieldMutations;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LPKCS1: TBytes;
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LMutated: TBytes;
  LType: TPEMType;
  I: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS1-core: failed to extract DER');
  AssertTrue(TryExtractPKCS1FromPKCS8DER(LDER, LPKCS1), 'PKCS1-core: failed to extract inner PKCS#1 DER');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($F0 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 1, $05, LMutated), 'PKCS1-core: mutate modulus tag failed');
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-modulus-not-integer');

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 3, $05, LMutated), 'PKCS1-core: mutate exponent tag failed');
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-privateexp-not-integer');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 1, 0, LMutated), 'PKCS1-core: zero modulus failed');
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-modulus-zero');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 3, 0, LMutated), 'PKCS1-core: zero exponent failed');
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-exponent-zero');
end;

procedure TestRSASignatureRejectsPKCS1CRTFieldTagMutations;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LPKCS1: TBytes;
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LMutated: TBytes;
  LType: TPEMType;
  I: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS1-crt-tag: failed to extract DER');
  AssertTrue(TryExtractPKCS1FromPKCS8DER(LDER, LPKCS1), 'PKCS1-crt-tag: failed to extract inner PKCS#1 DER');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($60 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 4, $05, LMutated), 'PKCS1-crt-tag: mutate p tag failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-p-not-integer');

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 5, $05, LMutated), 'PKCS1-crt-tag: mutate q tag failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-q-not-integer');

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 6, $05, LMutated), 'PKCS1-crt-tag: mutate dp tag failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-dp-not-integer');

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 7, $05, LMutated), 'PKCS1-crt-tag: mutate dq tag failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-dq-not-integer');

  AssertTrue(TryMutatePKCS1FieldTag(LPKCS1, 8, $05, LMutated), 'PKCS1-crt-tag: mutate qinv tag failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-qinv-not-integer');
end;

procedure TestRSASignatureRejectsPKCS1CRTZeroValueMutations;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LPKCS1: TBytes;
  LInput: TBytes;
  LTranscriptHash: TBytes;
  LMutated: TBytes;
  LType: TPEMType;
  I: Integer;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS1-crt-zero: failed to extract DER');
  AssertTrue(TryExtractPKCS1FromPKCS8DER(LDER, LPKCS1), 'PKCS1-crt-zero: failed to extract inner PKCS#1 DER');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($70 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 4, 0, LMutated), 'PKCS1-crt-zero: zero p failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-p-zero');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 5, 0, LMutated), 'PKCS1-crt-zero: zero q failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-q-zero');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 6, 0, LMutated), 'PKCS1-crt-zero: zero dp failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-dp-zero');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 7, 0, LMutated), 'PKCS1-crt-zero: zero dq failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-dq-zero');

  AssertTrue(TrySetPKCS1FieldToConstant(LPKCS1, 8, 0, LMutated), 'PKCS1-crt-zero: zero qinv failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-crt-qinv-zero');
end;

procedure TestPKCS1LengthMutationMatrixWaveD;
var
  LPemBlob: TBytes;
  LDER: TBytes;
  LPKCS1: TBytes;
  LType: TPEMType;
  LInput: TBytes;
  LMutated: TBytes;
begin
  LPemBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LPemBlob, LDER, LType), 'PKCS1-len-waveD: failed to extract DER');

  if LType = pemPrivateKey then
    AssertTrue(TryExtractPKCS1FromPKCS8DER(LDER, LPKCS1), 'PKCS1-len-waveD: failed to extract inner PKCS#1 DER')
  else
    LPKCS1 := Copy(LDER, 0, Length(LDER));

  LInput := BuildDeterministicCertVerifyInput($F4);

  AssertTrue(Length(LPKCS1) > 3, 'PKCS1-len-waveD: PKCS#1 DER too short for root length mutations');
  LMutated := CopyBytesWithMutation(LPKCS1, 1, $00);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-len-root-zero');
  LMutated := CopyBytesWithMutation(LPKCS1, 1, $FF);
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-len-root-ff');

  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 1, $00, LMutated), 'PKCS1-len-waveD: mutate modulus len=0 failed');
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-len-modulus-zero');
  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 1, $FF, LMutated), 'PKCS1-len-waveD: mutate modulus len=ff failed');
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-len-modulus-ff');

  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 3, $00, LMutated), 'PKCS1-len-waveD: mutate exponent len=0 failed');
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-len-privateexp-zero');
  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 3, $FF, LMutated), 'PKCS1-len-waveD: mutate exponent len=ff failed');
  AssertMalformedDERRejected(LMutated, LInput, 'pkcs1-len-privateexp-ff');

  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 4, $00, LMutated), 'PKCS1-len-waveD: mutate p len=0 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-len-p-zero');
  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 5, $00, LMutated), 'PKCS1-len-waveD: mutate q len=0 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-len-q-zero');
  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 6, $00, LMutated), 'PKCS1-len-waveD: mutate dp len=0 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-len-dp-zero');
  AssertTrue(TryMutatePKCS1FieldLengthByte(LPKCS1, 8, $00, LMutated), 'PKCS1-len-waveD: mutate qinv len=0 failed');
  AssertDEREitherRejectedOrFallbackSucceeds(LMutated, LInput, 'pkcs1-len-qinv-zero');
end;

procedure TestRSASignatureKeySizeConsistency;
var
  LKeyBlob: TBytes;
  LTranscriptHash: TBytes;
  LInput: TBytes;
  LSig: TBytes;
  LErr: string;
  I: Integer;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');

  SetLength(LTranscriptHash, 32);
  for I := 0 to 31 do
    LTranscriptHash[I] := Byte($55 + I);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

  AssertTrue(
    TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      LKeyBlob,
      LInput,
      LSig,
      LErr
    ),
    'RSA-PKCS1 signing failed for key-size consistency check: ' + LErr
  );
  AssertEqualsInt(256, Length(LSig), 'Signer key must produce 256-byte signature for 2048-bit modulus');
end;

procedure TestFallbackErrorCodeOnDoubleFailure;
var
  LKeyBlob: TBytes;
  LDER: TBytes;
  LPKCS1: TBytes;
  LMutatedModulus: TBytes;
  LMutatedBothDER: TBytes;
  LType: TPEMType;
begin
  LKeyBlob := LoadFileBytes('tests/certificate/test_certs/signer_key.pem');
  AssertTrue(TryExtractFirstPrivateKeyDER(LKeyBlob, LDER, LType), 'Failed to extract private key DER for double-failure test');

  if LType = pemPrivateKey then
    AssertTrue(TryExtractPKCS1FromPKCS8DER(LDER, LPKCS1), 'Failed to extract inner PKCS#1 from PKCS#8 key')
  else
    LPKCS1 := Copy(LDER, 0, Length(LDER));

  AssertTrue(TryMutatePKCS1FieldLSB(LPKCS1, 1, $01, False, LMutatedModulus), 'Failed to mutate modulus parity for double-failure test');
  AssertTrue(TrySetPKCS1FieldToConstant(LMutatedModulus, 4, 1, LMutatedBothDER), 'Failed to set prime p = 1 for double-failure test');
  AssertTrue(Length(LMutatedBothDER) > 0, 'Failed to produce DER key with corrupted modulus parity + CRT component');

  AssertFallbackErrorContainsCRTReason(
    LMutatedBothDER,
    'RSA CRT validation failed:',
    'double-failure-error-shape'
  );
end;

procedure TestFallbackErrorCodeFromDirectSignerCall;
var
  LSig: TBytes;
  LErr: string;
begin
  AssertTrue(
    not TryBuildTLS13CertificateVerifySignature(
      TLS13_SIG_RSA_PKCS1_SHA256,
      [],
      [$01],
      LSig,
      LErr
    ),
    'Direct signer call with empty key should fail'
  );
  AssertContains(LErr, 'Private key material is empty', 'Expected private-key-empty diagnostic');
end;

begin
  WriteLn('Testing TLS 1.3 server CertificateVerify helpers...');

  TestSelectSchemeFromClientHello;
  TestSelectSchemeMatrixWaveE;
  TestSelectSchemeMatrixWaveF;
  TestSelectSchemeMatrixWaveJ;
  TestSelectSchemeByCertificateKeyType;
  TestSelectSchemeByCertificateKeyTypeSupportsRSASHA384;
  TestSelectSchemeByCertificateKeyTypePrefersSuiteHashFamily;
  TestBuildCertVerifyInput;
  TestBuildCertVerifyInputAcceptsSHA384TranscriptHash;
  TestBuildCertificateVerifyHandshake;
  TestPlaceholderSignature;
  TestSignerUnitHasNoExternalBigIntDependency;
  TestBigIntEvenModulusAndZeroExponent;
  TestBigIntCrossByteVector;
  TestBigIntQWordVectorSuite;
  TestBigIntQWordVectorSuiteWaveD;
  TestBigIntQWordVectorSuiteWaveF;
  TestBigIntQWordVectorSuiteWaveI;
  TestBigIntNormalizationAndFixedLengthMatrixWaveJ;
  TestBigIntQWordVectorSuiteWaveK;
  TestBigIntQWordVectorSuiteWaveL;
  TestBigIntErrorSurface;
  TestBigIntStructuredErrorCodes;
  TestBigIntLeadingZeroNormalization;
  TestBigIntFixedLengthExactFit;
  TestRSAModExpExponentGuard;
  TestBigIntRejectsNonCoprimeRSARepresentative;
  TestTinyModulusDefense;
  TestRSASignatureWithDERPrivateKey;
  TestECDSASignatureWithECPrivateKey;
  TestRSASignatureWithPKCS8Attributes;
  TestRSASignatureWithPEMLeadingJunk;
  TestRSASignatureUsesFirstUsableRSAKeyBlock;
  TestRSASignatureWith1024BitKeyLength;
  TestRSASignatureErrorMessagesAreStable;
  TestErrorSurfaceCrossSchemeMatrixWaveG;
  TestRSASignatureErrorSurfaceMatrix;
  TestRSASignatureBoundaryMatrixExtended;
  TestRSAPSSBoundaryMatrixWaveC;
  TestRSASmallModulusBoundaryMatrixWaveD;
  TestRSASignatureHandlesMalformedDERVariants;
  TestRSASignatureRejectsExtendedDERMutations;
  TestRSASignatureSelectsRSAFromMixedPEMBlocks;
  TestPEMMixedAndEncryptedMatrixWaveG;
  TestRSASignatureRejectsPEMWithoutUsableRSAKey;
  TestRSASignatureRejectsMalformedPEMEnvelopes;
  TestRSASignatureRejectsEncryptedPEMBlock;
  TestRSASignatureRejectsPKCS8FieldShapeMutations;
  TestRSASignatureRejectsPKCS8AlgorithmOIDMutations;
  TestPKCS8LengthMutationMatrixWaveC;
  TestPKCS8OIDMatrixWaveE;
  TestPKCS8OIDMatrixWaveF;
  TestRSASignatureRejectsPKCS1CoreFieldMutations;
  TestRSASignatureRejectsPKCS1CRTFieldTagMutations;
  TestRSASignatureRejectsPKCS1CRTZeroValueMutations;
  TestPKCS1LengthMutationMatrixWaveD;
  TestPKCS1VersionAndPublicExponentMutationMatrixWaveG;
  TestRSASignatureRejectsPEMWithoutPrivateKeyBlock;
  TestRSASignatureKeySizeConsistency;
  TestRSASignatureFallsBackWhenPrivateExponentCorrupted;
  TestRSASignatureFallsBackWhenCRTInconsistent;
  TestRSASignatureFallsBackWhenPrimeQInconsistent;
  TestRSASignatureFallsBackWhenDPInconsistent;
  TestRSASignatureFallsBackWhenDQInconsistent;
  TestRSASignatureFallsBackWhenQInvInconsistent;
  TestRSASignatureUsesCorruptedExponentWhenCRTBroken;
  TestRSASignatureFallbackErrorWhenPrimePIsOneAndExponentCorrupted;
  TestRSASignatureFallbackErrorWhenPrimeQEqualsPrimePAndExponentCorrupted;
  TestRSASignatureFallbackErrorWhenDPZeroAndExponentCorrupted;
  TestRSASignatureFallbackErrorWhenDQZeroAndExponentCorrupted;
  TestRSASignatureFallbackErrorWhenQInvZeroAndExponentCorrupted;
  TestFallbackStructuredErrorMatrixExtended;
  TestFallbackMessageMatrixWaveC;
  TestFallbackPSSSuccessMatrixWaveE;
  TestFallbackStructuredErrorMatrixWaveF;
  TestFallbackErrorCodeOnDoubleFailure;
  TestFallbackErrorCodeFromDirectSignerCall;
  TestRealRSASignature;

  WriteLn('✅ TLS 1.3 server CertificateVerify helper checks passed');
end.
