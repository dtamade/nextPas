unit nextpas.core.tls.ct.pure;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, nextpas.core.tls.x509, nextpas.core.tls.ct.logs;

type
  TSCTVerifyResult = (sctValid, sctInvalidSignature, sctExpired, sctUnknownLog);

  TSCTVerifyResultArray = array of TSCTVerifyResult;

  TSignedCertificateTimestamp = record
    Version: Byte;
    LogID: TBytes;
    Timestamp: UInt64;
    Extensions: TBytes;
    HashAlgorithm: Byte;
    SignatureAlgorithm: Byte;
    Signature: TBytes;
  end;

function TryParseSCTList(const ASCTListData: TBytes; out ASCTs: array of TSignedCertificateTimestamp;
  out ACount: Integer; out AError: string): Boolean;

function TryParseSingleSCT(const AData: TBytes; AOffset: Integer;
  out ASCT: TSignedCertificateTimestamp; out ABytesConsumed: Integer): Boolean;

function VerifySCTCount(ACount: Integer; ACertType: string): Boolean;

function VerifySCTSignature(const ASCT: TSignedCertificateTimestamp;
  const ALeafCertDER: TBytes; const ALogPublicKey: TBytes;
  const ALogKeyType: string): TSCTVerifyResult;

function VerifySCTListWithLogs(const ASCTListData: TBytes;
  const ALeafCertDER: TBytes): TSCTVerifyResultArray;

implementation

uses
  nextpas.core.tls.crypto.hash, nextpas.core.tls.crypto.ecdsa, nextpas.core.tls.crypto.ed25519;

function TryParseSingleSCT(const AData: TBytes; AOffset: Integer;
  out ASCT: TSignedCertificateTimestamp; out ABytesConsumed: Integer): Boolean;
var
  LPos, LExtLen, LSigLen: Integer;
begin
  Result := False;
  ABytesConsumed := 0;
  FillChar(ASCT, SizeOf(ASCT), 0);

  LPos := AOffset;
  if LPos >= Length(AData) then Exit;

  ASCT.Version := AData[LPos]; Inc(LPos);
  if ASCT.Version <> 0 then Exit; // v1 only

  if LPos + 32 > Length(AData) then Exit;
  SetLength(ASCT.LogID, 32);
  Move(AData[LPos], ASCT.LogID[0], 32);
  Inc(LPos, 32);

  if LPos + 8 > Length(AData) then Exit;
  ASCT.Timestamp := (UInt64(AData[LPos]) shl 56) or (UInt64(AData[LPos+1]) shl 48) or
    (UInt64(AData[LPos+2]) shl 40) or (UInt64(AData[LPos+3]) shl 32) or
    (UInt64(AData[LPos+4]) shl 24) or (UInt64(AData[LPos+5]) shl 16) or
    (UInt64(AData[LPos+6]) shl 8) or UInt64(AData[LPos+7]);
  Inc(LPos, 8);

  if LPos + 2 > Length(AData) then Exit;
  LExtLen := (Integer(AData[LPos]) shl 8) or Integer(AData[LPos+1]);
  Inc(LPos, 2);
  if LPos + LExtLen > Length(AData) then Exit;
  SetLength(ASCT.Extensions, LExtLen);
  if LExtLen > 0 then
    Move(AData[LPos], ASCT.Extensions[0], LExtLen);
  Inc(LPos, LExtLen);

  if LPos + 2 > Length(AData) then Exit;
  ASCT.HashAlgorithm := AData[LPos]; Inc(LPos);
  ASCT.SignatureAlgorithm := AData[LPos]; Inc(LPos);

  if LPos + 2 > Length(AData) then Exit;
  LSigLen := (Integer(AData[LPos]) shl 8) or Integer(AData[LPos+1]);
  Inc(LPos, 2);
  if LPos + LSigLen > Length(AData) then Exit;
  SetLength(ASCT.Signature, LSigLen);
  if LSigLen > 0 then
    Move(AData[LPos], ASCT.Signature[0], LSigLen);
  Inc(LPos, LSigLen);

  ABytesConsumed := LPos - AOffset;
  Result := True;
end;

function TryParseSCTList(const ASCTListData: TBytes; out ASCTs: array of TSignedCertificateTimestamp;
  out ACount: Integer; out AError: string): Boolean;
var
  LPos, LListLen, LEntryLen, LConsumed: Integer;
  LSCT: TSignedCertificateTimestamp;
begin
  AError := '';
  ACount := 0;
  Result := False;

  if Length(ASCTListData) < 2 then
  begin
    AError := 'SCT list too short';
    Exit;
  end;

  LListLen := (Integer(ASCTListData[0]) shl 8) or Integer(ASCTListData[1]);
  LPos := 2;

  if LPos + LListLen > Length(ASCTListData) then
  begin
    AError := 'SCT list truncated';
    Exit;
  end;

  while (LPos < 2 + LListLen) and (ACount < Length(ASCTs)) do
  begin
    if LPos + 2 > Length(ASCTListData) then Break;
    LEntryLen := (Integer(ASCTListData[LPos]) shl 8) or Integer(ASCTListData[LPos+1]);
    Inc(LPos, 2);

    if LPos + LEntryLen > Length(ASCTListData) then Break;

    if TryParseSingleSCT(ASCTListData, LPos, LSCT, LConsumed) then
    begin
      ASCTs[ACount] := LSCT;
      Inc(ACount);
    end;
    Inc(LPos, LEntryLen);
  end;

  Result := ACount > 0;
end;

function VerifySCTCount(ACount: Integer; ACertType: string): Boolean;
begin
  if ACertType = 'EV' then
    Result := ACount >= 2
  else
    Result := ACount >= 1;
end;

function BuildSCTSignedData(const ASCT: TSignedCertificateTimestamp;
  const ALeafCertDER: TBytes): TBytes;
var
  LPos, LCertLen, LExtLen: Integer;
begin
  // RFC 6962 §3.2: signed struct for x509_entry
  LCertLen := Length(ALeafCertDER);
  LExtLen := Length(ASCT.Extensions);
  SetLength(Result, 1 + 1 + 8 + 2 + 3 + LCertLen + 2 + LExtLen);
  LPos := 0;

  Result[LPos] := ASCT.Version; Inc(LPos);       // sct_version
  Result[LPos] := 0; Inc(LPos);                   // signature_type = certificate_timestamp
  // timestamp (8 bytes big-endian)
  Result[LPos] := Byte(ASCT.Timestamp shr 56); Inc(LPos);
  Result[LPos] := Byte(ASCT.Timestamp shr 48); Inc(LPos);
  Result[LPos] := Byte(ASCT.Timestamp shr 40); Inc(LPos);
  Result[LPos] := Byte(ASCT.Timestamp shr 32); Inc(LPos);
  Result[LPos] := Byte(ASCT.Timestamp shr 24); Inc(LPos);
  Result[LPos] := Byte(ASCT.Timestamp shr 16); Inc(LPos);
  Result[LPos] := Byte(ASCT.Timestamp shr 8); Inc(LPos);
  Result[LPos] := Byte(ASCT.Timestamp); Inc(LPos);
  // entry_type = x509_entry (0x0000)
  Result[LPos] := 0; Inc(LPos);
  Result[LPos] := 0; Inc(LPos);
  // ASN1Cert length (3 bytes)
  Result[LPos] := Byte(LCertLen shr 16); Inc(LPos);
  Result[LPos] := Byte(LCertLen shr 8); Inc(LPos);
  Result[LPos] := Byte(LCertLen); Inc(LPos);
  // ASN1Cert data
  if LCertLen > 0 then
    Move(ALeafCertDER[0], Result[LPos], LCertLen);
  Inc(LPos, LCertLen);
  // extensions length (2 bytes)
  Result[LPos] := Byte(LExtLen shr 8); Inc(LPos);
  Result[LPos] := Byte(LExtLen); Inc(LPos);
  if LExtLen > 0 then
    Move(ASCT.Extensions[0], Result[LPos], LExtLen);
end;

function VerifySCTSignature(const ASCT: TSignedCertificateTimestamp;
  const ALeafCertDER: TBytes; const ALogPublicKey: TBytes;
  const ALogKeyType: string): TSCTVerifyResult;
var
  LSignedData, LHash: TBytes;
  LError: string;
begin
  Result := sctInvalidSignature;
  LSignedData := BuildSCTSignedData(ASCT, ALeafCertDER);

  if ALogKeyType = 'Ed25519' then
  begin
    if (Length(ALogPublicKey) = 32) and (Length(ASCT.Signature) = 64) then
    begin
      if Ed25519Verify(ALogPublicKey, LSignedData, ASCT.Signature) then
        Result := sctValid;
    end;
  end
  else if ALogKeyType = 'ECDSA' then
  begin
    // ECDSA-P256-SHA256
    LHash := SHA256(LSignedData);
    if TryECDSAVerifyP256SHA256(LHash, ALogPublicKey, ASCT.Signature, LError) then
      Result := sctValid;
  end;
end;

function VerifySCTListWithLogs(const ASCTListData: TBytes;
  const ALeafCertDER: TBytes): TSCTVerifyResultArray;
const
  MAX_SCT_LIST_ENTRIES = 64;
var
  LSCTs: array[0..MAX_SCT_LIST_ENTRIES - 1] of TSignedCertificateTimestamp;
  LSCTCount: Integer;
  LError: string;
  I: Integer;
  LLog: TCTLogEntry;
begin
  SetLength(Result, 0);

  if not TryParseSCTList(ASCTListData, LSCTs, LSCTCount, LError) then
    Exit;

  SetLength(Result, LSCTCount);
  for I := 0 to LSCTCount - 1 do
  begin
    LLog := FindCTLogByID(LSCTs[I].LogID);
    if not LLog.Found then
      Result[I] := sctUnknownLog
    else
      Result[I] := VerifySCTSignature(
        LSCTs[I],
        ALeafCertDER,
        LLog.PublicKey,
        LLog.KeyType
      );
  end;
end;

end.
