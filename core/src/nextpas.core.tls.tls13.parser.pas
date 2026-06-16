{**
 * Unit: nextpas.core.tls.tls13.parser
 * Purpose: TLS 1.3 ServerHello 解析器（纯 Pascal）
 *}

unit nextpas.core.tls.tls13.parser;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.tls.tls13.wire;

type
  TTLS13EncryptedExtensionsInfo = record
    Valid: Boolean;
    HasEarlyData: Boolean;
    HasALPN: Boolean;
    SelectedALPNProtocol: AnsiString;
    HasRecordSizeLimit: Boolean;
    RecordSizeLimit: Word;
  end;

  TTLS13ServerHelloInfo = record
    Valid: Boolean;
    LegacyVersion: Word;
    ServerRandom: TBytes;
    SelectedVersion: Word;
    SelectedCipherSuite: Word;
    HasPreSharedKey: Boolean;
    SelectedPSKIdentity: Word;
    HasKeyShare: Boolean;
    KeyShareGroup: Word;
    KeyShareLength: Word;
    PeerKeyShare: TBytes;
    HasCookie: Boolean;
    Cookie: TBytes;
  end;

function TryExtractHandshakePayloadFromRecord(const ARecord: TBytes; out AHandshake: TBytes): Boolean;
function TryParseServerHelloFromHandshake(const AHandshake: TBytes; out AInfo: TTLS13ServerHelloInfo): Boolean;
function TryParseTLS13EncryptedExtensions(
  const AHandshakeMessage: TBytes;
  out AInfo: TTLS13EncryptedExtensionsInfo;
  out AError: string
): Boolean;

implementation

procedure InitEncryptedExtensionsInfo(out AInfo: TTLS13EncryptedExtensionsInfo);
begin
  FillChar(AInfo, SizeOf(AInfo), 0);
  AInfo.RecordSizeLimit := TLS13_RECORD_SIZE_LIMIT_DEFAULT;
end;

procedure InitInfo(out AInfo: TTLS13ServerHelloInfo);
begin
  FillChar(AInfo, SizeOf(AInfo), 0);
  AInfo.SelectedVersion := TLS_LEGACY_VERSION;
  SetLength(AInfo.PeerKeyShare, 0);
end;

function TryExtractHandshakePayloadFromRecord(const ARecord: TBytes; out AHandshake: TBytes): Boolean;
var
  LHeader: TTLSRecordHeader;
  LLen: Integer;
begin
  SetLength(AHandshake, 0);
  Result := False;

  if not ParseTLSRecordHeader(ARecord, LHeader) then
    Exit;

  if LHeader.ContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    Exit;

  LLen := LHeader.Length;
  if Length(ARecord) < 5 + LLen then
    Exit;

  SetLength(AHandshake, LLen);
  if LLen > 0 then
    Move(ARecord[5], AHandshake[0], LLen);

  Result := True;
end;

function TryParseServerHelloFromHandshake(const AHandshake: TBytes; out AInfo: TTLS13ServerHelloInfo): Boolean;
var
  LOffset: Integer;
  LMsgType: Byte;
  LBodyLen: Cardinal;
  LSessionIdLen: Integer;
  LExtTotalLen: Integer;
  LExtEnd: Integer;
  LExtType, LExtLen: Word;
  LExtDataStart: Integer;
  LPeerShareLen: Integer;
begin
  InitInfo(AInfo);
  Result := False;

  if Length(AHandshake) < 4 then
    Exit;

  LMsgType := AHandshake[0];
  if LMsgType <> TLS_HANDSHAKE_TYPE_SERVER_HELLO then
    Exit;

  LBodyLen := ReadUInt24(AHandshake, 1);
  if Length(AHandshake) < 4 + Integer(LBodyLen) then
    Exit;

  LOffset := 4;

  // legacy_version
  if LOffset + 2 > Length(AHandshake) then
    Exit;
  AInfo.LegacyVersion := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);

  // random
  if LOffset + 32 > Length(AHandshake) then
    Exit;
  SetLength(AInfo.ServerRandom, 32);
  Move(AHandshake[LOffset], AInfo.ServerRandom[0], 32);
  Inc(LOffset, 32);

  // legacy_session_id_echo
  if LOffset + 1 > Length(AHandshake) then
    Exit;
  LSessionIdLen := AHandshake[LOffset];
  Inc(LOffset);
  if LOffset + LSessionIdLen > Length(AHandshake) then
    Exit;
  Inc(LOffset, LSessionIdLen);

  // cipher_suite
  if LOffset + 2 > Length(AHandshake) then
    Exit;
  AInfo.SelectedCipherSuite := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);

  // legacy_compression_method
  if LOffset + 1 > Length(AHandshake) then
    Exit;
  Inc(LOffset, 1);

  // extensions (optional in TLS 1.2)
  if LOffset >= Length(AHandshake) then
  begin
    AInfo.Valid := True;
    Result := True;
    Exit;
  end;
  if LOffset + 2 > Length(AHandshake) then
    Exit;
  LExtTotalLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LExtEnd := LOffset + LExtTotalLen;
  if LExtEnd > Length(AHandshake) then
    Exit;

  while LOffset + 4 <= LExtEnd do
  begin
    LExtType := ReadUInt16(AHandshake, LOffset);
    LExtLen := ReadUInt16(AHandshake, LOffset + 2);
    Inc(LOffset, 4);

    if LOffset + LExtLen > LExtEnd then
      Exit;

    LExtDataStart := LOffset;

    case LExtType of
      TLS_EXTENSION_SUPPORTED_VERSIONS:
        begin
          if LExtLen = 2 then
            AInfo.SelectedVersion := ReadUInt16(AHandshake, LExtDataStart)
          else
            Exit;
        end;

      TLS_EXTENSION_KEY_SHARE:
        begin
          AInfo.HasKeyShare := True;
          AInfo.KeyShareGroup := ReadUInt16(AHandshake, LExtDataStart);

          if LExtLen = 2 then
          begin
            // HRR: key_share contains only the selected group (no key data)
            AInfo.KeyShareLength := 0;
            SetLength(AInfo.PeerKeyShare, 0);
          end
          else if LExtLen >= 4 then
          begin
            AInfo.KeyShareLength := ReadUInt16(AHandshake, LExtDataStart + 2);
            LPeerShareLen := Integer(AInfo.KeyShareLength);
            if LPeerShareLen <> Integer(LExtLen) - 4 then
              Exit;
            SetLength(AInfo.PeerKeyShare, LPeerShareLen);
            if LPeerShareLen > 0 then
              Move(AHandshake[LExtDataStart + 4], AInfo.PeerKeyShare[0], LPeerShareLen);
          end
          else
            Exit;
        end;

      TLS_EXTENSION_PRE_SHARED_KEY:
        begin
          if LExtLen <> 2 then
            Exit;
          AInfo.HasPreSharedKey := True;
          AInfo.SelectedPSKIdentity := ReadUInt16(AHandshake, LExtDataStart);
        end;

      $002C: // cookie
        begin
          AInfo.HasCookie := True;
          SetLength(AInfo.Cookie, LExtLen);
          if LExtLen > 0 then
            Move(AHandshake[LExtDataStart], AInfo.Cookie[0], LExtLen);
        end;
    end;

    Inc(LOffset, LExtLen);
  end;

  if LOffset <> LExtEnd then
    Exit;

  AInfo.Valid := True;
  Result := True;
end;

function TryParseTLS13EncryptedExtensions(
  const AHandshakeMessage: TBytes;
  out AInfo: TTLS13EncryptedExtensionsInfo;
  out AError: string
): Boolean;
var
  LBodyLen: Cardinal;
  LOffset: Integer;
  LExtensionsLen: Integer;
  LExtensionsEnd: Integer;
  LExtType: Word;
  LExtLen: Word;
  LALPNListLen: Integer;
  LALPNNameLen: Integer;
begin
  InitEncryptedExtensionsInfo(AInfo);
  AError := '';
  Result := False;

  if Length(AHandshakeMessage) < 6 then
  begin
    AError := 'EncryptedExtensions handshake is too short';
    Exit;
  end;

  if AHandshakeMessage[0] <> TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS then
  begin
    AError := Format(
      'Unexpected handshake type %d for EncryptedExtensions parser',
      [AHandshakeMessage[0]]
    );
    Exit;
  end;

  LBodyLen := ReadUInt24(AHandshakeMessage, 1);
  if Length(AHandshakeMessage) <> 4 + Integer(LBodyLen) then
  begin
    AError := 'EncryptedExtensions length mismatch';
    Exit;
  end;

  LOffset := 4;
  LExtensionsLen := ReadUInt16(AHandshakeMessage, LOffset);
  Inc(LOffset, 2);
  LExtensionsEnd := LOffset + LExtensionsLen;
  if LExtensionsEnd <> Length(AHandshakeMessage) then
  begin
    AError := 'EncryptedExtensions extension block length mismatch';
    Exit;
  end;

  while LOffset + 4 <= LExtensionsEnd do
  begin
    LExtType := ReadUInt16(AHandshakeMessage, LOffset);
    LExtLen := ReadUInt16(AHandshakeMessage, LOffset + 2);
    Inc(LOffset, 4);

    if LOffset + Integer(LExtLen) > LExtensionsEnd then
    begin
      AError := 'EncryptedExtensions extension exceeds extension block';
      Exit;
    end;

    case LExtType of
      TLS_EXTENSION_EARLY_DATA:
        begin
          if LExtLen <> 0 then
          begin
            AError := 'EncryptedExtensions early_data extension must be empty';
            Exit;
          end;
          AInfo.HasEarlyData := True;
        end;

      TLS_EXTENSION_ALPN:
        begin
          if AInfo.HasALPN then
          begin
            AError := 'EncryptedExtensions ALPN extension must not appear more than once';
            Exit;
          end;

          if LExtLen < 3 then
          begin
            AError := 'EncryptedExtensions ALPN extension is too short';
            Exit;
          end;

          LALPNListLen := ReadUInt16(AHandshakeMessage, LOffset);
          if LALPNListLen <> Integer(LExtLen) - 2 then
          begin
            AError := 'EncryptedExtensions ALPN list length mismatch';
            Exit;
          end;

          LALPNNameLen := AHandshakeMessage[LOffset + 2];
          if LALPNNameLen = 0 then
          begin
            AError := 'EncryptedExtensions ALPN selected protocol must not be empty';
            Exit;
          end;

          if LALPNNameLen <> Integer(LExtLen) - 3 then
          begin
            AError := 'EncryptedExtensions ALPN selected protocol length mismatch';
            Exit;
          end;

          SetLength(AInfo.SelectedALPNProtocol, LALPNNameLen);
          if LALPNNameLen > 0 then
            Move(AHandshakeMessage[LOffset + 3], AInfo.SelectedALPNProtocol[1], LALPNNameLen);
          AInfo.HasALPN := True;
        end;

      TLS_EXTENSION_RECORD_SIZE_LIMIT:
        begin
          if AInfo.HasRecordSizeLimit then
          begin
            AError := 'EncryptedExtensions record_size_limit extension must not appear more than once';
            Exit;
          end;

          if LExtLen <> 2 then
          begin
            AError := 'EncryptedExtensions record_size_limit extension must be 2 bytes';
            Exit;
          end;

          AInfo.RecordSizeLimit := ReadUInt16(AHandshakeMessage, LOffset);
          if (AInfo.RecordSizeLimit < TLS13_RECORD_SIZE_LIMIT_MIN) or
            (AInfo.RecordSizeLimit > TLS13_RECORD_SIZE_LIMIT_MAX) then
          begin
            AError := 'EncryptedExtensions record_size_limit value is out of range';
            Exit;
          end;

          AInfo.HasRecordSizeLimit := True;
        end;
    end;

    Inc(LOffset, Integer(LExtLen));
  end;

  if LOffset <> LExtensionsEnd then
  begin
    AError := 'EncryptedExtensions extension block has trailing bytes';
    Exit;
  end;

  AInfo.Valid := True;
  Result := True;
end;

end.
