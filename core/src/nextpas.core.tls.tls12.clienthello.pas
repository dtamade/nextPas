unit nextpas.core.tls.tls12.clienthello;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base,
  nextpas.core.tls.tls12.ciphersuite;

type
  TTLS12ClientHelloOptions = record
    ServerName: string;
    ALPNProtocols: array of string;
    SupportEMS: Boolean;
    SessionID: TBytes;
    SessionTicket: TBytes;
    CipherSuites: TTLS12CipherSuiteList;
    RenegotiatedConnection: TBytes;
  end;

function BuildTLS12ClientHello(const AOptions: TTLS12ClientHelloOptions; const AClientRandom: TBytes): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.tls.tls12.wire;

procedure AppendBytes(var ADest: TBytes; const ASrc: TBytes);
var
  LOldLen: Integer;
begin
  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + Length(ASrc));
  if Length(ASrc) > 0 then
    Move(ASrc[0], ADest[LOldLen], Length(ASrc));
end;

procedure AppendByte(var ADest: TBytes; AValue: Byte);
var
  LOldLen: Integer;
begin
  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + 1);
  ADest[LOldLen] := AValue;
end;

procedure AppendUInt16(var ADest: TBytes; AValue: Word);
begin
  AppendByte(ADest, Byte(AValue shr 8));
  AppendByte(ADest, Byte(AValue));
end;

function StringToBytes(const AValue: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

function BuildSNIExtension(const AHostname: string): TBytes;
var
  LNameBytes: TBytes;
  LNameLen, LListLen: Integer;
begin
  Result := nil;
  if AHostname = '' then Exit;

  LNameBytes := StringToBytes(AHostname);
  LNameLen := Length(LNameBytes);
  LListLen := LNameLen + 3;

  AppendUInt16(Result, TLS12_EXT_SERVER_NAME);
  AppendUInt16(Result, Word(LListLen + 2));
  AppendUInt16(Result, Word(LListLen));
  AppendByte(Result, 0);
  AppendUInt16(Result, Word(LNameLen));
  AppendBytes(Result, LNameBytes);
end;

function BuildSupportedGroupsExtension: TBytes;
begin
  Result := nil;
  AppendUInt16(Result, TLS12_EXT_SUPPORTED_GROUPS);
  AppendUInt16(Result, 6);
  AppendUInt16(Result, 4);
  AppendUInt16(Result, TLS12_GROUP_X25519);
  AppendUInt16(Result, TLS12_GROUP_SECP256R1);
end;

function BuildECPointFormatsExtension: TBytes;
begin
  Result := nil;
  AppendUInt16(Result, TLS12_EXT_EC_POINT_FORMATS);
  AppendUInt16(Result, 2);
  AppendByte(Result, 1);
  AppendByte(Result, TLS12_EC_POINT_FORMAT_UNCOMPRESSED);
end;

function BuildSignatureAlgorithmsExtension: TBytes;
begin
  Result := nil;
  AppendUInt16(Result, TLS12_EXT_SIGNATURE_ALGORITHMS);
  AppendUInt16(Result, 8);
  AppendUInt16(Result, 6);
  AppendUInt16(Result, TLS12_SIG_RSA_PKCS1_SHA256);
  AppendUInt16(Result, TLS12_SIG_RSA_PKCS1_SHA384);
  AppendUInt16(Result, TLS12_SIG_ECDSA_SECP256R1_SHA256);
end;

function BuildEMSExtension: TBytes;
begin
  Result := nil;
  AppendUInt16(Result, TLS12_EXT_EXTENDED_MASTER_SECRET);
  AppendUInt16(Result, 0);
end;

function BuildRenegotiationInfoExtension(const ARenegotiatedConnection: TBytes): TBytes;
begin
  Result := nil;
  AppendUInt16(Result, TLS12_EXT_RENEGOTIATION_INFO);
  AppendUInt16(Result, Word(Length(ARenegotiatedConnection) + 1));
  AppendByte(Result, Byte(Length(ARenegotiatedConnection)));
  AppendBytes(Result, ARenegotiatedConnection);
end;

function BuildALPNExtension(const AProtocols: array of string): TBytes;
var
  LProtoList: TBytes;
  LProtoBytes: TBytes;
  I: Integer;
begin
  Result := nil;
  if Length(AProtocols) = 0 then Exit;

  SetLength(LProtoList, 0);
  for I := 0 to High(AProtocols) do
  begin
    LProtoBytes := StringToBytes(AProtocols[I]);
    AppendByte(LProtoList, Byte(Length(LProtoBytes)));
    AppendBytes(LProtoList, LProtoBytes);
  end;

  AppendUInt16(Result, TLS12_EXT_ALPN);
  AppendUInt16(Result, Word(Length(LProtoList) + 2));
  AppendUInt16(Result, Word(Length(LProtoList)));
  AppendBytes(Result, LProtoList);
end;

function BuildTLS12ClientHello(const AOptions: TTLS12ClientHelloOptions; const AClientRandom: TBytes): TBytes;
var
  LBody, LExtensions: TBytes;
  LCipherSuites: TBytes;
  I: Integer;
begin
  SetLength(LBody, 0);

  AppendByte(LBody, TLS12_VERSION_MAJOR);
  AppendByte(LBody, TLS12_VERSION_MINOR);

  if Length(AClientRandom) <> 32 then
    raise Exception.Create('ClientRandom must be 32 bytes');
  AppendBytes(LBody, AClientRandom);

  // Session ID
  if Length(AOptions.SessionID) > 0 then
  begin
    AppendByte(LBody, Byte(Length(AOptions.SessionID)));
    AppendBytes(LBody, AOptions.SessionID);
  end
  else
    AppendByte(LBody, 0);

  SetLength(LCipherSuites, 0);
  if Length(AOptions.CipherSuites) > 0 then
    for I := 0 to High(AOptions.CipherSuites) do
      AppendUInt16(LCipherSuites, AOptions.CipherSuites[I])
  else
  begin
    AppendUInt16(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256);
    AppendUInt16(LCipherSuites, TLS12_CIPHER_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256);
    AppendUInt16(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256);
    AppendUInt16(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384);
    AppendUInt16(LCipherSuites, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256);
    AppendUInt16(LCipherSuites, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384);
    AppendUInt16(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA256);
    AppendUInt16(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA384);
  end;
  AppendUInt16(LBody, Word(Length(LCipherSuites)));
  AppendBytes(LBody, LCipherSuites);

  AppendByte(LBody, 1);
  AppendByte(LBody, 0);

  SetLength(LExtensions, 0);
  AppendBytes(LExtensions, BuildSNIExtension(AOptions.ServerName));
  AppendBytes(LExtensions, BuildSupportedGroupsExtension);
  AppendBytes(LExtensions, BuildECPointFormatsExtension);
  AppendBytes(LExtensions, BuildSignatureAlgorithmsExtension);
  AppendBytes(LExtensions, BuildRenegotiationInfoExtension(AOptions.RenegotiatedConnection));
  if AOptions.SupportEMS then
    AppendBytes(LExtensions, BuildEMSExtension);
  if Length(AOptions.ALPNProtocols) > 0 then
    AppendBytes(LExtensions, BuildALPNExtension(AOptions.ALPNProtocols));

  // session_ticket extension: empty = request ticket, non-empty = resume with ticket
  AppendUInt16(LExtensions, TLS12_EXT_SESSION_TICKET);
  AppendUInt16(LExtensions, Word(Length(AOptions.SessionTicket)));
  if Length(AOptions.SessionTicket) > 0 then
    AppendBytes(LExtensions, AOptions.SessionTicket);

  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := TLS12BuildHandshakeHeader(TLS12_HANDSHAKE_CLIENT_HELLO, Length(LBody));
  AppendBytes(Result, LBody);
end;

end.
