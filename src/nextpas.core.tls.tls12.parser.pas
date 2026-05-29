unit nextpas.core.tls.tls12.parser;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

type
  TTLS12ServerHello = record
    Version: Word;
    ServerRandom: TBytes;
    SessionID: TBytes;
    CipherSuite: Word;
    CompressionMethod: Byte;
    HasEMS: Boolean;
    ALPNProtocol: string;
    HasRenegotiationInfo: Boolean;
    RenegotiatedConnection: TBytes;
  end;

  TTLS12ServerKeyExchange = record
    CurveType: Byte;
    NamedCurve: Word;
    PublicKey: TBytes;
    SignatureScheme: Word;
    Signature: TBytes;
  end;

  TTLS12CertificateMessage = record
    Certificates: array of TBytes;
  end;

function TryParseTLS12ServerHello(const AData: TBytes; AOffset: Integer;
  out AServerHello: TTLS12ServerHello; out AError: string): Boolean;

function TryParseTLS12Certificate(const AData: TBytes; AOffset: Integer;
  out ACertMsg: TTLS12CertificateMessage; out AError: string): Boolean;

function TryParseTLS12ServerKeyExchange(const AData: TBytes; AOffset: Integer;
  out ASKE: TTLS12ServerKeyExchange; out AError: string): Boolean;

function TryParseTLS12Finished(const AData: TBytes; AOffset: Integer; ALength: Integer;
  out AVerifyData: TBytes; out AError: string): Boolean;

implementation

uses
  nextpas.core.tls.tls12.wire;

function ReadUInt16(const AData: TBytes; AOffset: Integer): Word; inline;
begin
  Result := (Word(AData[AOffset]) shl 8) or Word(AData[AOffset + 1]);
end;

function ReadUInt24(const AData: TBytes; AOffset: Integer): Integer; inline;
begin
  Result := (Integer(AData[AOffset]) shl 16) or (Integer(AData[AOffset+1]) shl 8) or Integer(AData[AOffset+2]);
end;

function TryParseTLS12ServerHello(const AData: TBytes; AOffset: Integer;
  out AServerHello: TTLS12ServerHello; out AError: string): Boolean;
var
  LPos, LSessionIDLen, LExtLen, LExtEnd: Integer;
  LExtType, LExtDataLen: Word;
  LProtoLen: Integer;
begin
  AError := '';
  Result := False;
  FillChar(AServerHello, SizeOf(AServerHello), 0);

  if AOffset + 38 > Length(AData) then
  begin
    AError := 'ServerHello too short';
    Exit;
  end;

  AServerHello.Version := ReadUInt16(AData, AOffset);
  Inc(AOffset, 2);

  SetLength(AServerHello.ServerRandom, 32);
  Move(AData[AOffset], AServerHello.ServerRandom[0], 32);
  Inc(AOffset, 32);

  LSessionIDLen := AData[AOffset];
  Inc(AOffset);
  if AOffset + LSessionIDLen + 3 > Length(AData) then
  begin
    AError := 'ServerHello session ID truncated';
    Exit;
  end;
  SetLength(AServerHello.SessionID, LSessionIDLen);
  if LSessionIDLen > 0 then
    Move(AData[AOffset], AServerHello.SessionID[0], LSessionIDLen);
  Inc(AOffset, LSessionIDLen);

  AServerHello.CipherSuite := ReadUInt16(AData, AOffset);
  Inc(AOffset, 2);

  AServerHello.CompressionMethod := AData[AOffset];
  Inc(AOffset);

  if AOffset >= Length(AData) then
  begin
    Result := True;
    Exit;
  end;

  if AOffset + 2 > Length(AData) then
  begin
    Result := True;
    Exit;
  end;

  LExtLen := ReadUInt16(AData, AOffset);
  Inc(AOffset, 2);
  LExtEnd := AOffset + LExtLen;

  if LExtEnd > Length(AData) then
  begin
    AError := 'ServerHello extensions truncated';
    Exit;
  end;

  while AOffset + 4 <= LExtEnd do
  begin
    LExtType := ReadUInt16(AData, AOffset);
    LExtDataLen := ReadUInt16(AData, AOffset + 2);
    Inc(AOffset, 4);

    if AOffset + LExtDataLen > LExtEnd then
    begin
      AError := 'ServerHello extension data truncated';
      Exit;
    end;

    case LExtType of
      TLS12_EXT_EXTENDED_MASTER_SECRET:
        AServerHello.HasEMS := True;
      TLS12_EXT_RENEGOTIATION_INFO:
        begin
          AServerHello.HasRenegotiationInfo := True;
          if LExtDataLen < 1 then
          begin
            AError := 'ServerHello renegotiation_info extension is empty';
            Exit;
          end;
          LProtoLen := AData[AOffset];
          if Integer(LExtDataLen) <> LProtoLen + 1 then
          begin
            AError := 'ServerHello renegotiation_info renegotiated_connection length mismatch';
            Exit;
          end;
          SetLength(AServerHello.RenegotiatedConnection, LProtoLen);
          if LProtoLen > 0 then
            Move(AData[AOffset + 1], AServerHello.RenegotiatedConnection[0], LProtoLen);
        end;
      TLS12_EXT_ALPN:
        if LExtDataLen >= 4 then
        begin
          LPos := AOffset + 2;
          if LPos < AOffset + Integer(LExtDataLen) then
          begin
            LProtoLen := AData[LPos];
            Inc(LPos);
            if LPos + LProtoLen <= AOffset + Integer(LExtDataLen) then
              AServerHello.ALPNProtocol := TEncoding.ASCII.GetString(AData, LPos, LProtoLen);
          end;
        end;
    end;

    Inc(AOffset, LExtDataLen);
  end;

  Result := True;
end;

function TryParseTLS12Certificate(const AData: TBytes; AOffset: Integer;
  out ACertMsg: TTLS12CertificateMessage; out AError: string): Boolean;
var
  LTotalLen, LCertLen, LEnd: Integer;
  LCount: Integer;
begin
  AError := '';
  Result := False;
  SetLength(ACertMsg.Certificates, 0);

  if AOffset + 3 > Length(AData) then
  begin
    AError := 'Certificate message too short';
    Exit;
  end;

  LTotalLen := ReadUInt24(AData, AOffset);
  Inc(AOffset, 3);
  LEnd := AOffset + LTotalLen;

  if LEnd > Length(AData) then
  begin
    AError := 'Certificate message truncated';
    Exit;
  end;

  LCount := 0;
  while AOffset + 3 <= LEnd do
  begin
    LCertLen := ReadUInt24(AData, AOffset);
    Inc(AOffset, 3);

    if AOffset + LCertLen > LEnd then
    begin
      AError := 'Certificate entry truncated';
      Exit;
    end;

    Inc(LCount);
    SetLength(ACertMsg.Certificates, LCount);
    SetLength(ACertMsg.Certificates[LCount - 1], LCertLen);
    Move(AData[AOffset], ACertMsg.Certificates[LCount - 1][0], LCertLen);
    Inc(AOffset, LCertLen);
  end;

  Result := True;
end;

function TryParseTLS12ServerKeyExchange(const AData: TBytes; AOffset: Integer;
  out ASKE: TTLS12ServerKeyExchange; out AError: string): Boolean;
var
  LPubKeyLen: Integer;
  LSigLen: Integer;
begin
  AError := '';
  Result := False;
  FillChar(ASKE, SizeOf(ASKE), 0);

  if AOffset + 4 > Length(AData) then
  begin
    AError := 'ServerKeyExchange too short';
    Exit;
  end;

  ASKE.CurveType := AData[AOffset];
  Inc(AOffset);

  if ASKE.CurveType <> 3 then
  begin
    AError := Format('Unsupported curve type: %d (expected named_curve=3)', [ASKE.CurveType]);
    Exit;
  end;

  ASKE.NamedCurve := ReadUInt16(AData, AOffset);
  Inc(AOffset, 2);

  LPubKeyLen := AData[AOffset];
  Inc(AOffset);

  if AOffset + LPubKeyLen > Length(AData) then
  begin
    AError := 'ServerKeyExchange public key truncated';
    Exit;
  end;

  SetLength(ASKE.PublicKey, LPubKeyLen);
  Move(AData[AOffset], ASKE.PublicKey[0], LPubKeyLen);
  Inc(AOffset, LPubKeyLen);

  if AOffset + 4 > Length(AData) then
  begin
    AError := 'ServerKeyExchange signature header truncated';
    Exit;
  end;

  ASKE.SignatureScheme := ReadUInt16(AData, AOffset);
  Inc(AOffset, 2);

  LSigLen := ReadUInt16(AData, AOffset);
  Inc(AOffset, 2);

  if AOffset + LSigLen > Length(AData) then
  begin
    AError := 'ServerKeyExchange signature truncated';
    Exit;
  end;

  SetLength(ASKE.Signature, LSigLen);
  Move(AData[AOffset], ASKE.Signature[0], LSigLen);

  Result := True;
end;

function TryParseTLS12Finished(const AData: TBytes; AOffset: Integer; ALength: Integer;
  out AVerifyData: TBytes; out AError: string): Boolean;
begin
  AError := '';
  Result := False;

  if ALength <> 12 then
  begin
    AError := Format('Finished verify_data must be 12 bytes, got %d', [ALength]);
    Exit;
  end;

  if AOffset + 12 > Length(AData) then
  begin
    AError := 'Finished message truncated';
    Exit;
  end;

  SetLength(AVerifyData, 12);
  Move(AData[AOffset], AVerifyData[0], 12);
  Result := True;
end;

end.
