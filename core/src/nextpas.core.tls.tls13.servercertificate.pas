{**
 * Unit: nextpas.core.tls.tls13.servercertificate
 * Purpose: TLS 1.3 Certificate（server）消息构建器（纯 Pascal）
 *
 * 输入支持：
 * - 单个 DER 证书二进制
 * - PEM 文本（可含多张 CERTIFICATE）
 *}

unit nextpas.core.tls.tls13.servercertificate;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types

interface

uses
  SysUtils;

type
  TTLS13CertificateArray = array of TBytes;
  TTLS13CertificateEntryInfo = record
    DER: TBytes;
    Extensions: TBytes;
    HasOCSPStapledResponse: Boolean;
    OCSPStapledResponse: TBytes;
    HasSignedCertificateTimestampList: Boolean;
    SignedCertificateTimestampList: TBytes;
    SignedCertificateTimestampCount: Integer;
  end;
  TTLS13CertificateEntryInfoArray = array of TTLS13CertificateEntryInfo;

  TTLS13ServerCertificateInfo = record
    Certificates: TTLS13CertificateArray;
    Entries: TTLS13CertificateEntryInfoArray;
    HasLeafOCSPStapledResponse: Boolean;
    LeafOCSPStapledResponse: TBytes;
    HasLeafSignedCertificateTimestampList: Boolean;
    LeafSignedCertificateTimestampList: TBytes;
    LeafSignedCertificateTimestampCount: Integer;
  end;

function TryParseCertificateBlob(
  const ACertificateBlob: TBytes;
  out ACertificates: TTLS13CertificateArray;
  out AError: string
): Boolean;

function TryExtractLeafCertificateDERFromBlob(
  const ACertificateBlob: TBytes;
  out ALeafCertificateDER: TBytes;
  out AError: string
): Boolean;

function TryParseTLS13ServerCertificateHandshake(
  const AHandshake: TBytes;
  out ACertificates: TTLS13CertificateArray;
  out AError: string
): Boolean;

function TryParseSignedCertificateTimestampList(
  const AData: TBytes;
  out ACount: Integer;
  out AError: string
): Boolean;

function TryParseTLS13ServerCertificateHandshakeInfo(
  const AHandshake: TBytes;
  out AInfo: TTLS13ServerCertificateInfo;
  out AError: string
): Boolean;

function TryBuildTLS13ServerCertificateHandshake(
  const ACertificateBlob: TBytes;
  out AHandshake: TBytes;
  out AError: string
): Boolean; overload;

function TryBuildTLS13ServerCertificateHandshakeWithStapledOCSP(
  const ACertificateBlob: TBytes;
  const AStapledOCSPResponse: TBytes;
  out AHandshake: TBytes;
  out AError: string
): Boolean;

implementation

uses
  nextpas.core.tls.pem,
  nextpas.core.tls.tls13.wire;

function BytesToAnsiString(const AData: TBytes): AnsiString;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
end;

function BlobLooksLikePEM(const ACertificateBlob: TBytes): Boolean;
var
  LText: AnsiString;
begin
  LText := BytesToAnsiString(ACertificateBlob);
  Result := Pos('-----BEGIN', string(LText)) > 0;
end;

function TryParseCertificateBlob(
  const ACertificateBlob: TBytes;
  out ACertificates: TTLS13CertificateArray;
  out AError: string
): Boolean;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
  I: Integer;
  LText: AnsiString;
begin
  SetLength(ACertificates, 0);
  AError := '';
  Result := False;

  if Length(ACertificateBlob) = 0 then
  begin
    AError := 'Certificate blob is empty';
    Exit;
  end;

  if BlobLooksLikePEM(ACertificateBlob) then
  begin
    LReader := TPEMReader.Create;
    try
      LText := BytesToAnsiString(ACertificateBlob);
      try
        LReader.LoadFromString(string(LText));
      except
        on E: Exception do
        begin
          AError := 'Failed to parse PEM certificate blob: ' + E.Message;
          Exit;
        end;
      end;

      LBlocks := LReader.GetCertificates;
      if Length(LBlocks) = 0 then
      begin
        AError := 'No CERTIFICATE block found in PEM blob';
        Exit;
      end;

      SetLength(ACertificates, Length(LBlocks));
      for I := 0 to High(LBlocks) do
      begin
        if Length(LBlocks[I].Data) = 0 then
        begin
          AError := Format('PEM certificate block #%d is empty', [I + 1]);
          Exit;
        end;
        ACertificates[I] := Copy(LBlocks[I].Data, 0, Length(LBlocks[I].Data));
      end;
    finally
      LReader.Free;
    end;
  end
  else
  begin
    SetLength(ACertificates, 1);
    ACertificates[0] := Copy(ACertificateBlob, 0, Length(ACertificateBlob));
  end;

  Result := True;
end;

function TryExtractLeafCertificateDERFromBlob(
  const ACertificateBlob: TBytes;
  out ALeafCertificateDER: TBytes;
  out AError: string
): Boolean;
var
  LCerts: TTLS13CertificateArray;
begin
  SetLength(ALeafCertificateDER, 0);
  Result := False;

  if not TryParseCertificateBlob(ACertificateBlob, LCerts, AError) then
    Exit;

  if Length(LCerts) = 0 then
  begin
    AError := 'No certificate found in blob';
    Exit;
  end;

  ALeafCertificateDER := Copy(LCerts[0], 0, Length(LCerts[0]));
  Result := True;
end;

function TryParseTLS13ServerCertificateHandshake(
  const AHandshake: TBytes;
  out ACertificates: TTLS13CertificateArray;
  out AError: string
): Boolean;
var
  LInfo: TTLS13ServerCertificateInfo;
begin
  SetLength(ACertificates, 0);
  Result := False;

  if not TryParseTLS13ServerCertificateHandshakeInfo(AHandshake, LInfo, AError) then
    Exit;

  ACertificates := Copy(LInfo.Certificates);
  Result := True;
end;

function TryParseStatusRequestExtension(
  const AData: TBytes;
  out AResponse: TBytes;
  out AError: string
): Boolean;
var
  LResponseLen: Integer;
begin
  SetLength(AResponse, 0);
  AError := '';
  Result := False;

  if Length(AData) < 4 then
  begin
    AError := 'status_request extension is too short';
    Exit;
  end;

  if AData[0] <> TLS_CERT_STATUS_TYPE_OCSP then
  begin
    AError := Format('Unsupported certificate status type %d', [AData[0]]);
    Exit;
  end;

  LResponseLen := Integer(ReadUInt24(AData, 1));
  if (LResponseLen <= 0) or (Length(AData) <> 4 + LResponseLen) then
  begin
    AError := 'status_request OCSP response length is invalid';
    Exit;
  end;

  SetLength(AResponse, LResponseLen);
  Move(AData[4], AResponse[0], LResponseLen);
  Result := True;
end;

function TryParseSignedCertificateTimestampList(
  const AData: TBytes;
  out ACount: Integer;
  out AError: string
): Boolean;
var
  LListLen: Integer;
  LOffset: Integer;
  LSCTLen: Integer;
begin
  ACount := 0;
  AError := '';
  Result := False;

  if Length(AData) < 2 then
  begin
    AError := 'signed_certificate_timestamp extension is too short';
    Exit;
  end;

  LListLen := ReadUInt16(AData, 0);
  if (LListLen <= 0) or (Length(AData) <> 2 + LListLen) then
  begin
    AError := 'signed_certificate_timestamp list length is invalid';
    Exit;
  end;

  LOffset := 2;
  while LOffset < Length(AData) do
  begin
    if LOffset + 2 > Length(AData) then
    begin
      AError := 'serialized SCT length is truncated';
      Exit;
    end;

    LSCTLen := ReadUInt16(AData, LOffset);
    Inc(LOffset, 2);
    if (LSCTLen <= 0) or (LOffset + LSCTLen > Length(AData)) then
    begin
      AError := 'serialized SCT length is invalid';
      Exit;
    end;

    Inc(ACount);
    Inc(LOffset, LSCTLen);
  end;

  Result := ACount > 0;
end;

function TryParseTLS13ServerCertificateHandshakeInfo(
  const AHandshake: TBytes;
  out AInfo: TTLS13ServerCertificateInfo;
  out AError: string
): Boolean;
var
  LBodyLen: Cardinal;
  LOffset: Integer;
  LContextLen: Integer;
  LListLen: Integer;
  LListEnd: Integer;
  LCertLen: Integer;
  LExtLen: Integer;
  LCount: Integer;
  LExtensionsEnd: Integer;
  LExtOffset: Integer;
  LExtType: Word;
  LExtBodyLen: Word;
  LExtData: TBytes;
begin
  FillChar(AInfo, SizeOf(AInfo), 0);
  SetLength(AInfo.Certificates, 0);
  SetLength(AInfo.Entries, 0);
  SetLength(AInfo.LeafOCSPStapledResponse, 0);
  SetLength(AInfo.LeafSignedCertificateTimestampList, 0);
  AError := '';
  Result := False;

  if Length(AHandshake) < 4 then
  begin
    AError := 'TLS 1.3 Certificate handshake is truncated';
    Exit;
  end;

  if AHandshake[0] <> TLS_HANDSHAKE_TYPE_CERTIFICATE then
  begin
    AError := Format('Handshake type %d is not Certificate', [AHandshake[0]]);
    Exit;
  end;

  LBodyLen := ReadUInt24(AHandshake, 1);
  if Length(AHandshake) <> 4 + Integer(LBodyLen) then
  begin
    AError := Format(
      'TLS 1.3 Certificate handshake length mismatch (expected=%d actual=%d)',
      [4 + Integer(LBodyLen), Length(AHandshake)]
    );
    Exit;
  end;

  LOffset := 4;
  if LOffset >= Length(AHandshake) then
  begin
    AError := 'TLS 1.3 Certificate handshake is missing certificate_request_context';
    Exit;
  end;

  LContextLen := AHandshake[LOffset];
  Inc(LOffset);
  if LOffset + LContextLen > Length(AHandshake) then
  begin
    AError := 'certificate_request_context exceeds Certificate handshake body';
    Exit;
  end;
  Inc(LOffset, LContextLen);

  if LOffset + 3 > Length(AHandshake) then
  begin
    AError := 'TLS 1.3 Certificate handshake is missing certificate_list length';
    Exit;
  end;

  LListLen := Integer(ReadUInt24(AHandshake, LOffset));
  Inc(LOffset, 3);
  if LOffset + LListLen <> Length(AHandshake) then
  begin
    AError := 'TLS 1.3 Certificate certificate_list length does not match body size';
    Exit;
  end;

  LListEnd := LOffset + LListLen;
  LCount := 0;
  while LOffset < LListEnd do
  begin
    if LOffset + 3 > LListEnd then
    begin
      AError := Format('Certificate entry #%d is missing DER length', [LCount + 1]);
      Exit;
    end;

    LCertLen := Integer(ReadUInt24(AHandshake, LOffset));
    Inc(LOffset, 3);
    if (LCertLen <= 0) or (LOffset + LCertLen > LListEnd) then
    begin
      AError := Format('Certificate entry #%d DER length is invalid', [LCount + 1]);
      Exit;
    end;

    SetLength(AInfo.Certificates, LCount + 1);
    SetLength(AInfo.Certificates[LCount], LCertLen);
    Move(AHandshake[LOffset], AInfo.Certificates[LCount][0], LCertLen);
    SetLength(AInfo.Entries, LCount + 1);
    AInfo.Entries[LCount].DER := Copy(AInfo.Certificates[LCount]);
    Inc(LOffset, LCertLen);

    if LOffset + 2 > LListEnd then
    begin
      AError := Format('Certificate entry #%d is missing extension length', [LCount + 1]);
      Exit;
    end;

    LExtLen := ReadUInt16(AHandshake, LOffset);
    Inc(LOffset, 2);
    if LOffset + LExtLen > LListEnd then
    begin
      AError := Format('Certificate entry #%d extensions exceed certificate_list', [LCount + 1]);
      Exit;
    end;

    SetLength(AInfo.Entries[LCount].Extensions, LExtLen);
    if LExtLen > 0 then
      Move(AHandshake[LOffset], AInfo.Entries[LCount].Extensions[0], LExtLen);

    LExtensionsEnd := LOffset + LExtLen;
    LExtOffset := LOffset;
    while LExtOffset < LExtensionsEnd do
    begin
      if LExtOffset + 4 > LExtensionsEnd then
      begin
        AError := Format('Certificate entry #%d extension header is truncated', [LCount + 1]);
        Exit;
      end;

      LExtType := ReadUInt16(AHandshake, LExtOffset);
      LExtBodyLen := ReadUInt16(AHandshake, LExtOffset + 2);
      Inc(LExtOffset, 4);
      if LExtOffset + Integer(LExtBodyLen) > LExtensionsEnd then
      begin
        AError := Format('Certificate entry #%d extension length exceeds boundary', [LCount + 1]);
        Exit;
      end;

      if LExtType = TLS_EXTENSION_STATUS_REQUEST then
      begin
        SetLength(LExtData, LExtBodyLen);
        if LExtBodyLen > 0 then
          Move(AHandshake[LExtOffset], LExtData[0], LExtBodyLen);
        if not TryParseStatusRequestExtension(
          LExtData,
          AInfo.Entries[LCount].OCSPStapledResponse,
          AError
        ) then
        begin
          AError := Format('Certificate entry #%d status_request is invalid: %s', [LCount + 1, AError]);
          Exit;
        end;
        AInfo.Entries[LCount].HasOCSPStapledResponse := True;
        if LCount = 0 then
        begin
          AInfo.HasLeafOCSPStapledResponse := True;
          AInfo.LeafOCSPStapledResponse := Copy(AInfo.Entries[LCount].OCSPStapledResponse);
        end;
      end
      else if LExtType = TLS_EXTENSION_SIGNED_CERTIFICATE_TIMESTAMP then
      begin
        SetLength(LExtData, LExtBodyLen);
        if LExtBodyLen > 0 then
          Move(AHandshake[LExtOffset], LExtData[0], LExtBodyLen);
        if not TryParseSignedCertificateTimestampList(
          LExtData,
          AInfo.Entries[LCount].SignedCertificateTimestampCount,
          AError
        ) then
        begin
          AError := Format(
            'Certificate entry #%d signed_certificate_timestamp is invalid: %s',
            [LCount + 1, AError]
          );
          Exit;
        end;
        AInfo.Entries[LCount].HasSignedCertificateTimestampList := True;
        AInfo.Entries[LCount].SignedCertificateTimestampList := Copy(LExtData);
        if LCount = 0 then
        begin
          AInfo.HasLeafSignedCertificateTimestampList := True;
          AInfo.LeafSignedCertificateTimestampList := Copy(LExtData);
          AInfo.LeafSignedCertificateTimestampCount :=
            AInfo.Entries[LCount].SignedCertificateTimestampCount;
        end;
      end;

      Inc(LExtOffset, Integer(LExtBodyLen));
    end;

    Inc(LOffset, LExtLen);
    Inc(LCount);
  end;

  if LCount = 0 then
  begin
    AError := 'TLS 1.3 Certificate handshake contains no certificate entries';
    Exit;
  end;

  Result := True;
end;

function TryBuildTLS13ServerCertificateHandshake(
  const ACertificateBlob: TBytes;
  const AStapledOCSPResponse: TBytes;
  out AHandshake: TBytes;
  out AError: string
): Boolean; overload;
var
  LCertificates: TTLS13CertificateArray;
  LCertificateList: TBytes;
  LEntry: TBytes;
  LBody: TBytes;
  LExtensions: TBytes;
  I: Integer;
  LCertLen: Integer;

  function BuildStatusRequestCertificateExtension(const AResponse: TBytes): TBytes;
  var
    LBody: TBytes;
  begin
    SetLength(LBody, 0);
    AppendByte(LBody, TLS_CERT_STATUS_TYPE_OCSP);
    AppendUInt24(LBody, Length(AResponse));
    AppendBytes(LBody, AResponse);

    SetLength(Result, 0);
    AppendUInt16(Result, TLS_EXTENSION_STATUS_REQUEST);
    AppendUInt16(Result, Length(LBody));
    AppendBytes(Result, LBody);
  end;
begin
  SetLength(AHandshake, 0);
  AError := '';
  Result := False;

  if not TryParseCertificateBlob(ACertificateBlob, LCertificates, AError) then
    Exit;

  if Length(AStapledOCSPResponse) > $FFFFFF then
  begin
    AError := 'Stapled OCSP response is too large for TLS 1.3';
    Exit;
  end;

  SetLength(LCertificateList, 0);
  for I := 0 to High(LCertificates) do
  begin
    LCertLen := Length(LCertificates[I]);
    if (LCertLen <= 0) or (LCertLen > $FFFFFF) then
    begin
      AError := Format('Certificate #%d length is invalid for TLS 1.3: %d', [I + 1, LCertLen]);
      Exit;
    end;

    SetLength(LExtensions, 0);
    if (I = 0) and (Length(AStapledOCSPResponse) > 0) then
      LExtensions := BuildStatusRequestCertificateExtension(AStapledOCSPResponse);

    SetLength(LEntry, 0);
    AppendUInt24(LEntry, LCertLen);
    AppendBytes(LEntry, LCertificates[I]);
    AppendUInt16(LEntry, Length(LExtensions));
    AppendBytes(LEntry, LExtensions);

    AppendBytes(LCertificateList, LEntry);
  end;

  if Length(LCertificateList) > $FFFFFF then
  begin
    AError := 'Certificate list is too large for TLS 1.3';
    Exit;
  end;

  SetLength(LBody, 0);
  AppendByte(LBody, 0); // certificate_request_context length = 0
  AppendUInt24(LBody, Length(LCertificateList));
  AppendBytes(LBody, LCertificateList);

  SetLength(AHandshake, 0);
  AppendByte(AHandshake, TLS_HANDSHAKE_TYPE_CERTIFICATE);
  AppendUInt24(AHandshake, Length(LBody));
  AppendBytes(AHandshake, LBody);

  Result := True;
end;

function TryBuildTLS13ServerCertificateHandshake(
  const ACertificateBlob: TBytes;
  out AHandshake: TBytes;
  out AError: string
): Boolean; overload;
begin
  Result := TryBuildTLS13ServerCertificateHandshake(
    ACertificateBlob,
    nil,
    AHandshake,
    AError
  );
end;

function TryBuildTLS13ServerCertificateHandshakeWithStapledOCSP(
  const ACertificateBlob: TBytes;
  const AStapledOCSPResponse: TBytes;
  out AHandshake: TBytes;
  out AError: string
): Boolean;
begin
  Result := TryBuildTLS13ServerCertificateHandshake(
    ACertificateBlob,
    AStapledOCSPResponse,
    AHandshake,
    AError
  );
end;

end.
