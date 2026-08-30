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
  nextpas.core.bytes.ops,
  nextpas.core.tls.exceptions,
  nextpas.core.errors,
  nextpas.core.tls.tls12.wire;



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

  BytesAppendUInt16BE(Result, TLS12_EXT_SERVER_NAME);
  BytesAppendUInt16BE(Result, Word(LListLen + 2));
  BytesAppendUInt16BE(Result, Word(LListLen));
  BytesAppendByte(Result, 0);
  BytesAppendUInt16BE(Result, Word(LNameLen));
  BytesAppend(Result, LNameBytes);
end;

function BuildSupportedGroupsExtension: TBytes;
begin
  Result := nil;
  BytesAppendUInt16BE(Result, TLS12_EXT_SUPPORTED_GROUPS);
  BytesAppendUInt16BE(Result, 6);
  BytesAppendUInt16BE(Result, 4);
  BytesAppendUInt16BE(Result, TLS12_GROUP_X25519);
  BytesAppendUInt16BE(Result, TLS12_GROUP_SECP256R1);
end;

function BuildECPointFormatsExtension: TBytes;
begin
  Result := nil;
  BytesAppendUInt16BE(Result, TLS12_EXT_EC_POINT_FORMATS);
  BytesAppendUInt16BE(Result, 2);
  BytesAppendByte(Result, 1);
  BytesAppendByte(Result, TLS12_EC_POINT_FORMAT_UNCOMPRESSED);
end;

function BuildSignatureAlgorithmsExtension: TBytes;
begin
  Result := nil;
  BytesAppendUInt16BE(Result, TLS12_EXT_SIGNATURE_ALGORITHMS);
  BytesAppendUInt16BE(Result, 8);
  BytesAppendUInt16BE(Result, 6);
  BytesAppendUInt16BE(Result, TLS12_SIG_RSA_PKCS1_SHA256);
  BytesAppendUInt16BE(Result, TLS12_SIG_RSA_PKCS1_SHA384);
  BytesAppendUInt16BE(Result, TLS12_SIG_ECDSA_SECP256R1_SHA256);
end;

function BuildEMSExtension: TBytes;
begin
  Result := nil;
  BytesAppendUInt16BE(Result, TLS12_EXT_EXTENDED_MASTER_SECRET);
  BytesAppendUInt16BE(Result, 0);
end;

function BuildRenegotiationInfoExtension(const ARenegotiatedConnection: TBytes): TBytes;
begin
  Result := nil;
  BytesAppendUInt16BE(Result, TLS12_EXT_RENEGOTIATION_INFO);
  BytesAppendUInt16BE(Result, Word(Length(ARenegotiatedConnection) + 1));
  BytesAppendByte(Result, Byte(Length(ARenegotiatedConnection)));
  BytesAppend(Result, ARenegotiatedConnection);
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
    BytesAppendByte(LProtoList, Byte(Length(LProtoBytes)));
    BytesAppend(LProtoList, LProtoBytes);
  end;

  BytesAppendUInt16BE(Result, TLS12_EXT_ALPN);
  BytesAppendUInt16BE(Result, Word(Length(LProtoList) + 2));
  BytesAppendUInt16BE(Result, Word(Length(LProtoList)));
  BytesAppend(Result, LProtoList);
end;

function BuildTLS12ClientHello(const AOptions: TTLS12ClientHelloOptions; const AClientRandom: TBytes): TBytes;
var
  LBody, LExtensions: TBytes;
  LCipherSuites: TBytes;
  I: Integer;
begin
  SetLength(LBody, 0);

  BytesAppendByte(LBody, TLS12_VERSION_MAJOR);
  BytesAppendByte(LBody, TLS12_VERSION_MINOR);

  if Length(AClientRandom) <> 32 then
    raise ESSLInvalidArgument.Create('ClientRandom must be 32 bytes');
  BytesAppend(LBody, AClientRandom);

  // Session ID
  if Length(AOptions.SessionID) > 0 then
  begin
    BytesAppendByte(LBody, Byte(Length(AOptions.SessionID)));
    BytesAppend(LBody, AOptions.SessionID);
  end
  else
    BytesAppendByte(LBody, 0);

  SetLength(LCipherSuites, 0);
  if Length(AOptions.CipherSuites) > 0 then
    for I := 0 to High(AOptions.CipherSuites) do
      BytesAppendUInt16BE(LCipherSuites, AOptions.CipherSuites[I])
  else
  begin
    BytesAppendUInt16BE(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256);
    BytesAppendUInt16BE(LCipherSuites, TLS12_CIPHER_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256);
    BytesAppendUInt16BE(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256);
    BytesAppendUInt16BE(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384);
    BytesAppendUInt16BE(LCipherSuites, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256);
    BytesAppendUInt16BE(LCipherSuites, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384);
    BytesAppendUInt16BE(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA256);
    BytesAppendUInt16BE(LCipherSuites, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA384);
  end;
  BytesAppendUInt16BE(LBody, Word(Length(LCipherSuites)));
  BytesAppend(LBody, LCipherSuites);

  BytesAppendByte(LBody, 1);
  BytesAppendByte(LBody, 0);

  SetLength(LExtensions, 0);
  BytesAppend(LExtensions, BuildSNIExtension(AOptions.ServerName));
  BytesAppend(LExtensions, BuildSupportedGroupsExtension);
  BytesAppend(LExtensions, BuildECPointFormatsExtension);
  BytesAppend(LExtensions, BuildSignatureAlgorithmsExtension);
  BytesAppend(LExtensions, BuildRenegotiationInfoExtension(AOptions.RenegotiatedConnection));
  if AOptions.SupportEMS then
    BytesAppend(LExtensions, BuildEMSExtension);
  if Length(AOptions.ALPNProtocols) > 0 then
    BytesAppend(LExtensions, BuildALPNExtension(AOptions.ALPNProtocols));

  // session_ticket extension: empty = request ticket, non-empty = resume with ticket
  BytesAppendUInt16BE(LExtensions, TLS12_EXT_SESSION_TICKET);
  BytesAppendUInt16BE(LExtensions, Word(Length(AOptions.SessionTicket)));
  if Length(AOptions.SessionTicket) > 0 then
    BytesAppend(LExtensions, AOptions.SessionTicket);

  BytesAppendUInt16BE(LBody, Word(Length(LExtensions)));
  BytesAppend(LBody, LExtensions);

  Result := TLS12BuildHandshakeHeader(TLS12_HANDSHAKE_CLIENT_HELLO, Length(LBody));
  BytesAppend(Result, LBody);
end;

end.
