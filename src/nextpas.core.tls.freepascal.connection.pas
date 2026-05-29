{**
 * Unit: nextpas.core.tls.freepascal.connection
 * Purpose: 纯 FreePascal 后端连接实现（TLS 1.3 客户端握手探测骨架）
 *
 * 当前能力：
 * - 基于 socket/stream 的双向字节 I/O
 * - 发送真实 TLS 1.3 ClientHello
 * - 接收并解析 ServerHello
 * - 处理加密握手记录并校验 Server Finished
 * - 发送加密 Client Finished
 * - 派生应用流量密钥并实现应用数据记录收发（AES-128-GCM/CHACHA20-POLY1305）
 *
 * 当前限制：
 * - PSK / 会话复用等高级能力待补齐
 * - 对端证书验证链等高级能力待补齐
 *}

unit nextpas.core.tls.freepascal.connection;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  {$IFDEF WINDOWS}
  Windows, Winsock2,
  {$ELSE}
  Sockets,
  {$ENDIF}
  SysUtils, Classes, DateUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.connection.base,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.appschedule,
  nextpas.core.tls.tls13.posthandshake,
  nextpas.core.tls.tls12.client,
  nextpas.core.tls.tls12.wire,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.crypto.tls12record,
  nextpas.core.tls.tls12.chacha20record,
  nextpas.core.tls.x509;

type
  TFreePascalConnection = class(TBaseSSLConnection, ISSLClientConnection,
    ISSLEarlyDataConnection, ISSLOCSPStapling, ISSLCertificateTransparency,
    ISSLCertificateTransparencyValidation)
  private
    FSocket: THandle;
    FStream: TStream;
    FOwnsStream: Boolean;
    FReadTimeoutMs: Integer;
    FWriteTimeoutMs: Integer;
    FServerName: string;
    FProtocolVersion: TSSLProtocolVersion;
    FCipherName: string;
    FALPNProtocols: string;
    FSelectedALPNProtocol: string;
    FX25519PrivateKey: TBytes;
    FP256PrivateKey: TBytes;
    FP384PrivateKey: TBytes;
    FX25519PublicKey: TBytes;
    FHandshakeSharedSecret: TBytes;
    FEarlyDataSecrets: TTLS13EarlyDataSecrets;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FServerFinishedKey: TBytes;
    FClientFinishedKey: TBytes;
    FEarlyDataSeq: QWord;
    FServerHandshakeSeq: QWord;
    FClientHandshakeSeq: QWord;

    FApplicationSecrets: TTLS13ApplicationSecrets;
    FClientApplicationSeq: QWord;
    FServerApplicationSeq: QWord;
    FApplicationReadBuffer: TBytes;
    FApplicationReadOffset: Integer;
    FPostHandshakeBuffer: TBytes;
    FSessionTicketCount: Integer;
    FLastSessionTicket: TTLS13NewSessionTicket;
    FIsServerMode: Boolean;
    FClientCertRequested: Boolean;
    FCurrentSession: ISSLSession;
    FConfiguredSession: ISSLSession;
    FSessionReused: Boolean;
    FSessionBoundServerName: string;
    FPeerCertificate: ISSLCertificate;
    FPeerCertificateChain: TSSLCertificateArray;
    FOCSPResponse: TBytes;
    FOCSPResponseVerified: Boolean;
    FOCSPResponseStatus: string;
    FSignedCertificateTimestampList: TBytes;
    FSignedCertificateTimestampCount: Integer;
    FCertificateTransparencyStatus: string;
    FHasCertificateTransparencyValidationResult: Boolean;
    FCertificateTransparencyPolicySatisfied: Boolean;
    FCertificateTransparencyValidationStatus: string;
    FEarlyDataStatus: TSSLEarlyDataStatus;
    FEarlyDataLimit: Cardinal;
    FEarlyDataPayload: TBytes;
    FLocalRecordSizeLimit: Word;
    FPeerRecordSizeLimit: Word;

    // TLS 1.2 state
    FTLS12State: TTLS12ClientState;
    FTLS12ReadBuffer: TBytes;
    FTLS12ReadOffset: Integer;

    function SendData(const ABuffer; ASize: Integer): Integer;
    function RecvData(var ABuffer; ASize: Integer): Integer;
    function SendAll(const AData: TBytes): Boolean;
    function RecvExact(var AData: TBytes; ACount: Integer): Boolean;
    function RecvTLSRecord(out AHeader: TTLSRecordHeader; out APayload, ARecord: TBytes): Boolean;
    function EffectivePeerTLS13PlaintextLimit: Word;
    function EffectiveLocalTLS13PlaintextLimit: Word;
    function EffectivePeerApplicationFragmentLimit: Integer;
    function ValidateReceivedTLS13PlaintextLength(APlaintextLength: Integer): Boolean;
    function ProbeServerHello: Boolean;
    procedure SetHandshakeError(ACode: TSSLErrorCode; const AMessage: string);
    procedure InitializeState(AContext: ISSLContext);
    procedure SendPlaintextAlert(ALevel, ADescription: Byte);
    function ErrorCodeToAlertDescription(ACode: TSSLErrorCode): Byte;
    procedure AppendHandshakeBytes(var ADest: TBytes; const ASource: TBytes);
    function TryPopHandshakeMessage(var ABuffer: TBytes; out AMessage: TBytes): Boolean;
    function ProcessEncryptedServerFlight(ACipherSuite: Word; var ATranscriptData: TBytes): Boolean;
    function SendClientFinished(ACipherSuite: Word; var ATranscriptData: TBytes): Boolean;
    function SendClientEmptyCertificate(ACipherSuite: Word; var ATranscriptData: TBytes): Boolean;
    function SendClientCertificateAndVerify(ACipherSuite: Word; var ATranscriptData: TBytes): Boolean;
    function RecvApplicationDataFragment(
      out AFragment: TBytes;
      AAllowNoRecord: Boolean = False
    ): Boolean;
    function SendApplicationDataFragment(const AFragment: TBytes): Boolean;
    function ProcessPostHandshakeFragment(const AHandshakeFragment: TBytes): Boolean;
    function SendPostHandshakeKeyUpdate(ARequestPeerUpdate: Boolean): Boolean;
    function SendTLS12ProtectedRecord(AContentType: Byte; const APlaintext: TBytes): Boolean;
    function ReadTLS12ProtectedRecord(out AContentType: Byte; out APlaintext: TBytes; out AError: string): Boolean;
    function DoRenegotiateTLS12: Boolean;
    procedure MarkUnsupported(const AOperation: string);
    procedure MarkPrecondition(const AOperation: string);
    function SendClientEarlyDataRecord(ACipherSuite: Word): Boolean;
    function GetBufferedStreamBytesAvailable: Int64;
    function DrainBufferedApplicationRecords: Boolean;
    procedure ClearOCSPStaplingState;
    procedure ClearCertificateTransparencyState;
    procedure RefreshCertificateTransparencyValidationState;
    procedure ClearPeerCertificateCache;
    function TryCachePeerCertificatesFromHandshake(
      const AHandshakeMessage: TBytes;
      ACertificateTransparencyRequested: Boolean;
      out AError: string
    ): Boolean;
    function BuildPeerIntermediateStore: ISSLCertificateStore;
    function TryResolvePeerIssuerCertificate(
      out AIssuerCertificate: ISSLCertificate;
      out AError: string
    ): Boolean;
    function TryLoadOCSPSignedCertificateTimestampList(
      out ASignedCertificateTimestampList: TBytes;
      out ASignedCertificateTimestampCount: Integer;
      out AFound: Boolean;
      out AError: string
    ): Boolean;
    function TryBuildPeerOCSPCertificatePair(
      out ALeafCertificate, AIssuerCertificate: TX509Certificate;
      out AError: string
    ): Boolean;
    function ValidateClientPeerCertificateTrust: Boolean;
    function ValidateCertificatePinIfEnabled: Boolean;
    function ValidateClientPeerCertificateFlags: Boolean;
    function ValidateClientOCSPStapling: Boolean;
    function ValidateClientOnlineOCSP: Boolean;
    function ValidateClientCertificateTransparency: Boolean;
    function ValidateServerCertificateVerify(
      ACipherSuite: Word;
      const AHandshakeMessage: TBytes;
      const ATranscriptData: TBytes
    ): Boolean;
    function TLS12ServerSessionLookup(const ASessionID: TBytes;
      out AMasterSecret: TBytes; out ACipherSuite: Word): Boolean;
    function DoAcceptTLS12Fallback(const AClientHelloRecord: TBytes): Boolean;
    function DoConnectTLS12Fallback(const AServerHelloRecord: TBytes; const AClientHelloHandshake: TBytes): Boolean;
  protected
    function DoRead(var ABuffer; ACount: Integer): Integer; override;
    function DoWrite(const ABuffer; ACount: Integer): Integer; override;
    function DoConnect: Boolean; override;
    function DoAccept: Boolean; override;
    function DoHandshakeInternal: TSSLHandshakeState; override;
    function DoShutdown: Boolean; override;
    procedure DoClose; override;
    function DoRenegotiate: Boolean; override;
    function DoGetError(ARet: Integer): TSSLErrorCode; override;
    function DoWantRead: Boolean; override;
    function DoWantWrite: Boolean; override;
    function DoGetProtocolVersion: TSSLProtocolVersion; override;
    function DoGetCipherName: string; override;
    function DoGetPeerCertificate: ISSLCertificate; override;
    function DoGetPeerCertificateChain: TSSLCertificateArray; override;
    function DoGetVerifyResult: Integer; override;
    function DoGetVerifyResultString: string; override;
    function DoGetSession: ISSLSession; override;
    procedure DoSetSession(ASession: ISSLSession); override;
    function DoIsSessionReused: Boolean; override;
    function DoGetConnectionInfoServerName: string; override;
    function DoGetSelectedALPNProtocol: string; override;
    function DoGetState: string; override;
    function DoGetNativeHandle: Pointer; override;
    function DoGetOCSPStaplingEnabled: Boolean; override;
    function DoGetOCSPResponse: TBytes; override;
    function DoIsOCSPResponseVerified: Boolean; override;
    function DoGetOCSPResponseStatus: string; override;
    function DoGetCertificateTransparencyEnabled: Boolean; override;
    function DoGetSignedCertificateTimestampList: TBytes; override;
    function DoGetSignedCertificateTimestampCount: Integer; override;
    function DoGetCertificateTransparencyStatus: string; override;
    function DoHasCertificateTransparencyValidationResult: Boolean; override;
    function DoIsCertificateTransparencyPolicySatisfied: Boolean; override;
    function DoGetCertificateTransparencyValidationStatus: string; override;
  public
    constructor Create(AContext: ISSLContext; ASocket: THandle); overload;
    constructor Create(AContext: ISSLContext; AStream: TStream); overload;
    destructor Destroy; override;

    procedure SetServerName(const AServerName: string);
    function GetServerName: string;
    function SetEarlyData(const AData: TBytes): TSSLOperationResult;
    function GetEarlyDataStatus: TSSLEarlyDataStatus;
    function GetEarlyDataLimit: Cardinal;
    procedure SetReadTimeout(AMs: Integer);
    procedure SetWriteTimeout(AMs: Integer);
    property ReadTimeoutMs: Integer read FReadTimeoutMs write FReadTimeoutMs;
    property WriteTimeoutMs: Integer read FWriteTimeoutMs write FWriteTimeoutMs;
  end;

implementation

uses
  {$IFDEF UNIX}BaseUnix, Unix,{$ENDIF}
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.crypto.x25519,
  nextpas.core.tls.factory,
  nextpas.core.tls.tls13.servercertificate,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.tls.freepascal.session,
  nextpas.core.tls.freepascal.context.material,
  nextpas.core.tls.ocsp,
  nextpas.core.tls.ocsp.stapling,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.p384,
  nextpas.core.tls.tls12.server,
  nextpas.core.tls.tls12.ciphersuite,
  nextpas.core.tls.tls12.clienthello,
  nextpas.core.tls.tls12.parser,
  nextpas.core.tls.tls12.io,
  nextpas.core.tls.certchain,
  nextpas.core.tls.random,
  nextpas.core.tls.memutils,
  nextpas.core.crypto.constant_time,
  nextpas.core.tls.ct.sct,
  nextpas.core.tls.ct.logs,
  nextpas.core.tls.ct.pure,
  nextpas.core.tls.native_handle,
  nextpas.core.tls.net.hooks;

type
  TConcatStream = class(TStream)
  private
    FFirst: TStream;
    FSecond: TStream;
    FFirstDone: Boolean;
  public
    constructor Create(AFirst, ASecond: TStream);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TConcatStream.Create(AFirst, ASecond: TStream);
begin
  inherited Create;
  FFirst := AFirst;
  FSecond := ASecond;
  FFirstDone := False;
end;

function TConcatStream.Read(var Buffer; Count: Longint): Longint;
var
  LRead: Longint;
begin
  if not FFirstDone then
  begin
    LRead := FFirst.Read(Buffer, Count);
    if LRead > 0 then
      Exit(LRead);
    FFirstDone := True;
  end;
  Result := FSecond.Read(Buffer, Count);
end;

function TConcatStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := FSecond.Write(Buffer, Count);
end;

function TConcatStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := 0;
end;

const
  X509_EXTENSION_EMBEDDED_SIGNED_CERTIFICATE_TIMESTAMP = '1.3.6.1.4.1.11129.2.4.2';
  SCT_VALIDATION_STATUS_NOT_SET = 0;
  SCT_VALIDATION_STATUS_UNKNOWN_LOG = 1;
  SCT_VALIDATION_STATUS_VALID = 2;
  SCT_VALIDATION_STATUS_INVALID = 3;
  SCT_VALIDATION_STATUS_UNVERIFIED = 4;
  SCT_VALIDATION_STATUS_UNKNOWN_VERSION = 5;

function CopyCipherSuitesToTLS13(
  const ASource: TFreePascalCipherSuiteList
): TTLS13CipherSuiteList;
var
  I: Integer;
begin
  SetLength(Result, Length(ASource));
  for I := 0 to High(ASource) do
    Result[I] := ASource[I];
end;

function CopyCipherSuitesToTLS12(
  const ASource: TFreePascalCipherSuiteList
): TTLS12CipherSuiteList;
var
  I: Integer;
begin
  SetLength(Result, Length(ASource));
  for I := 0 to High(ASource) do
    Result[I] := ASource[I];
end;

function CountValidSignedCertificateTimestamps(
  const AResults: TSCTValidationResultArray
): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(AResults) do
    if AResults[I].IsValid then
      Inc(Result);
end;

function CheckCertificateTransparencyPolicy(
  const AResults: TSCTValidationResultArray;
  const AOptions: TSCTValidationOptions
): Boolean;
var
  LValidCount: Integer;
begin
  if Length(AResults) < AOptions.MinimumSCTCount then
    Exit(False);

  if AOptions.RequireValidSCTs then
  begin
    LValidCount := CountValidSignedCertificateTimestamps(AResults);
    Exit(LValidCount >= AOptions.MinimumSCTCount);
  end;

  Result := Length(AResults) >= AOptions.MinimumSCTCount;
end;

function ReadUInt16(const AData: TBytes; AOffset: Integer): Integer; inline;
begin
  Result := (Integer(AData[AOffset]) shl 8) or Integer(AData[AOffset + 1]);
end;

function TryCollectSignedCertificateTimestampValidationResults(
  const ASignedCertificateTimestampList: TBytes;
  ACertificate: ISSLCertificate;
  const AOptions: TSCTValidationOptions;
  out AResults: TSCTValidationResultArray;
  out AError: string
): Boolean;
var
  LListLength: Integer;
  LOffset: Integer;
  LSCTLength: Integer;
  LCount: Integer;
  I: Integer;
  LCertificateDER: TBytes;
  LSCTs: array[0..63] of TSignedCertificateTimestamp;
  LSCTCount: Integer;
  LVerifyResults: TSCTVerifyResultArray;
  LLog: TCTLogEntry;
begin
  SetLength(AResults, 0);
  AError := '';
  Result := False;

  if (Length(ASignedCertificateTimestampList) = 0) or (ACertificate = nil) then
  begin
    AError := 'CT validation inputs are incomplete';
    Exit;
  end;

  if Length(ASignedCertificateTimestampList) < 2 then
  begin
    AError := 'SignedCertificateTimestampList is too short';
    Exit;
  end;

  LListLength := ReadUInt16(ASignedCertificateTimestampList, 0);
  if (LListLength <= 0) or (Length(ASignedCertificateTimestampList) <> 2 + LListLength) then
  begin
    AError := 'SignedCertificateTimestampList length is invalid';
    Exit;
  end;

  if not TryParseSCTList(ASignedCertificateTimestampList, LSCTs, LSCTCount, AError) then
  begin
    if Trim(AError) = '' then
      AError := 'SignedCertificateTimestampList could not be parsed';
    Exit;
  end;

  LCertificateDER := ACertificate.SaveToDER;
  if Length(LCertificateDER) = 0 then
  begin
    AError := 'Certificate DER material is unavailable for SCT signature verification';
    Exit;
  end;

  LCount := 0;
  LOffset := 2;
  while LOffset < Length(ASignedCertificateTimestampList) do
  begin
    if LOffset + 2 > Length(ASignedCertificateTimestampList) then
    begin
      AError := 'Serialized SCT length is truncated';
      Exit;
    end;

    LSCTLength := ReadUInt16(ASignedCertificateTimestampList, LOffset);
    Inc(LOffset, 2);
    if (LSCTLength <= 0) or (LOffset + LSCTLength > Length(ASignedCertificateTimestampList)) then
    begin
      AError := 'Serialized SCT length is invalid';
      Exit;
    end;

    Inc(LCount);
    Inc(LOffset, LSCTLength);
  end;

  LVerifyResults := VerifySCTListWithLogs(ASignedCertificateTimestampList, LCertificateDER);
  if (Length(LVerifyResults) = 0) or (Length(LVerifyResults) <> LCount) or (LSCTCount <> LCount) then
  begin
    AError := 'Pure Pascal CT signature verifier returned no SCT results';
    Exit;
  end;

  SetLength(AResults, LCount);
  for I := 0 to LCount - 1 do
  begin
    AResults[I].IsValid := False;
    AResults[I].Status := SCT_VALIDATION_STATUS_NOT_SET;
    AResults[I].ErrorMessage := '';
    AResults[I].LogName := '';
    AResults[I].Timestamp := LSCTs[I].Timestamp;

    LLog := FindCTLogByID(LSCTs[I].LogID);
    if LLog.Found then
      AResults[I].LogName := LLog.Name;

    case LVerifyResults[I] of
      sctValid:
        begin
          AResults[I].IsValid := True;
          AResults[I].Status := SCT_VALIDATION_STATUS_VALID;
        end;
      sctUnknownLog:
        begin
          AResults[I].IsValid := AOptions.AllowUnknownLogs;
          AResults[I].Status := SCT_VALIDATION_STATUS_UNKNOWN_LOG;
          AResults[I].ErrorMessage := 'Unknown CT log';
        end;
      sctExpired:
        begin
          AResults[I].Status := SCT_VALIDATION_STATUS_INVALID;
          AResults[I].ErrorMessage := 'SCT timestamp is outside accepted time bounds';
        end;
    else
      AResults[I].Status := SCT_VALIDATION_STATUS_INVALID;
      AResults[I].ErrorMessage := 'Invalid SCT signature';
    end;
  end;

  Result := LCount > 0;
end;

function BuildCertificateTransparencyValidationStatus(
  const AResults: TSCTValidationResultArray;
  APolicySatisfied: Boolean
): string;
var
  I: Integer;
  LValidCount: Integer;
  LStatuses: string;
begin
  if Length(AResults) = 0 then
    Exit('Validation unavailable: validator returned no SCT results');

  LValidCount := CountValidSignedCertificateTimestamps(AResults);
  LStatuses := '';
  for I := 0 to High(AResults) do
  begin
    if LStatuses <> '' then
      LStatuses := LStatuses + ', ';
    LStatuses := LStatuses + GetSCTValidationStatusName(AResults[I].Status);
  end;

  if APolicySatisfied then
    Result := 'Policy satisfied'
  else
    Result := 'Policy failed';

  Result := Format(
    '%s (%d/%d valid SCTs; statuses=%s)',
    [Result, LValidCount, Length(AResults), LStatuses]
  );
end;

function TryLoadEmbeddedSignedCertificateTimestampList(
  ACertificate: ISSLCertificate;
  out ASignedCertificateTimestampList: TBytes;
  out ASignedCertificateTimestampCount: Integer;
  out AFound: Boolean;
  out AError: string
): Boolean; forward;

function SelectPreferredProtocol(const AContext: ISSLContext): TSSLProtocolVersion;
var
  LProtocols: TSSLProtocolVersions;
begin
  Result := AContext.GetPreferredVersion;
  if Result <> sslProtocolUnknown then
    Exit;

  LProtocols := AContext.GetProtocolVersions;
  if sslProtocolTLS13 in LProtocols then
    Exit(sslProtocolTLS13);
  if sslProtocolTLS12 in LProtocols then
    Exit(sslProtocolTLS12);
  if sslProtocolTLS11 in LProtocols then
    Exit(sslProtocolTLS11);
  if sslProtocolTLS10 in LProtocols then
    Exit(sslProtocolTLS10);

  Result := sslProtocolUnknown;
end;

function HashTLS13TranscriptForSuite(ACipherSuite: Word; const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));

  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));

  SetLength(Result, 0);
end;

function NormalizeHostForVerify(const S: string): string;
var
  LHost: string;
  P, PEnd: SizeInt;
  PortPart: string;
  I: Integer;
begin
  LHost := Trim(S);

  if (LHost <> '') and (LHost[1] = '[') then
  begin
    PEnd := Pos(']', LHost);
    if PEnd > 0 then
      LHost := Copy(LHost, 2, PEnd - 2);
  end;

  P := Pos('%', LHost);
  if P > 0 then
    LHost := Copy(LHost, 1, P - 1);

  if (Pos(':', LHost) > 0) and (Pos(':', LHost) = LastDelimiter(':', LHost)) then
  begin
    P := Pos(':', LHost);
    PortPart := Copy(LHost, P + 1, Length(LHost) - P);
    if PortPart <> '' then
    begin
      for I := 1 to Length(PortPart) do
        if not (PortPart[I] in ['0'..'9']) then
        begin
          PortPart := '';
          Break;
        end;
      if PortPart <> '' then
        LHost := Copy(LHost, 1, P - 1);
    end;
  end;

  Result := LHost;
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
begin
  Result := TConstantTime.CompareBytes(ALeft, ARight) = 1;
end;

function ClientHelloHasExtension(const AHandshake: TBytes; AExtensionType: Word): Boolean;
var
  LOffset: Integer;
  LBodyLen: Cardinal;
  LBodyEnd: Integer;
  LSessionIDLen: Integer;
  LCipherSuitesLen: Integer;
  LCompressionLen: Integer;
  LExtensionsLen: Integer;
  LExtensionsEnd: Integer;
  LExtType: Word;
  LExtLen: Word;
begin
  Result := False;

  if (Length(AHandshake) < 4) or (AHandshake[0] <> TLS_HANDSHAKE_TYPE_CLIENT_HELLO) then
    Exit;

  LBodyLen := ReadUInt24(AHandshake, 1);
  LBodyEnd := 4 + Integer(LBodyLen);
  if Length(AHandshake) <> LBodyEnd then
    Exit;

  LOffset := 4 + 2 + 32;
  if LOffset >= LBodyEnd then
    Exit;

  LSessionIDLen := AHandshake[LOffset];
  Inc(LOffset);
  Inc(LOffset, LSessionIDLen);
  if LOffset + 2 > LBodyEnd then
    Exit;

  LCipherSuitesLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2 + LCipherSuitesLen);
  if LOffset + 1 > LBodyEnd then
    Exit;

  LCompressionLen := AHandshake[LOffset];
  Inc(LOffset);
  Inc(LOffset, LCompressionLen);
  if LOffset + 2 > LBodyEnd then
    Exit;

  LExtensionsLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LExtensionsEnd := LOffset + LExtensionsLen;
  if LExtensionsEnd <> LBodyEnd then
    Exit;

  while LOffset + 4 <= LExtensionsEnd do
  begin
    LExtType := ReadUInt16(AHandshake, LOffset);
    LExtLen := ReadUInt16(AHandshake, LOffset + 2);
    Inc(LOffset, 4);
    if LOffset + Integer(LExtLen) > LExtensionsEnd then
      Exit(False);
    if LExtType = AExtensionType then
      Exit(True);
    Inc(LOffset, Integer(LExtLen));
  end;
end;

function CloneCertificateArray(const ASource: TSSLCertificateArray): TSSLCertificateArray;
var
  I: Integer;
begin
  SetLength(Result, Length(ASource));
  for I := 0 to High(ASource) do
    if ASource[I] <> nil then
      Result[I] := ASource[I].Clone
    else
      Result[I] := nil;
end;

{$WARN 6018 OFF}
function OCSPStaplingStateToString(
  AStatus: TOCSPStaplingStatus;
  const AErrorMessage: string
): string;
begin
  case AStatus of
    ossNotRequested:
      Result := 'Not Requested';
    ossRequested:
      Result := 'Requested';
    ossReceived:
      Result := 'Received';
    ossVerified:
      Result := 'Verified';
    ossVerificationFailed:
      Result := 'Verification Failed';
    ossNotProvided:
      Result := 'No OCSP Response';
    ossExpired:
      Result := 'Expired';
  else
    Result := 'Unknown';
  end;

  if Trim(AErrorMessage) <> '' then
    Result := Result + ': ' + Trim(AErrorMessage);
end;
{$WARN 6018 ON}

function BuildExtensionHeader(AType: Word; const AData: TBytes): TBytes;
begin
  Result := nil;
  AppendUInt16(Result, AType);
  AppendUInt16(Result, Word(Length(AData)));
  AppendBytes(Result, AData);
end;

function StringToAnsiBytes(const AValue: string): TBytes;
begin
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

function ParseALPNProtocolList(const AProtocols: string): TBytes;
var
  I: Integer;
  LStart: Integer;
  LStop: Integer;
  LValue: string;
  LProtocolBytes: TBytes;
begin
  SetLength(Result, 0);
  LStart := 1;

  for I := 1 to Length(AProtocols) + 1 do
  begin
    if (I <= Length(AProtocols)) and (AProtocols[I] <> ',') then
      Continue;

    LStop := I - 1;
    while (LStart <= LStop) and (AProtocols[LStart] <= ' ') do
      Inc(LStart);
    while (LStop >= LStart) and (AProtocols[LStop] <= ' ') do
      Dec(LStop);

    if LStop >= LStart then
    begin
      LValue := Copy(AProtocols, LStart, LStop - LStart + 1);
      LProtocolBytes := StringToAnsiBytes(LValue);
      if Length(LProtocolBytes) = 0 then
      begin
        SetLength(Result, 0);
        Exit;
      end;
      if Length(LProtocolBytes) > 255 then
        RaiseInvalidParameter('ALPNProtocolLength');
      AppendByte(Result, Byte(Length(LProtocolBytes)));
      AppendBytes(Result, LProtocolBytes);
    end;

    LStart := I + 1;
  end;
end;

function SelectALPNProtocol(
  const AClientHello: TTLS13ClientHelloInfo;
  const AServerALPNProtocols: string
): string;
var
  I: Integer;
  LStart: Integer;
  LStop: Integer;
  LCandidate: string;
begin
  Result := '';

  if Length(AClientHello.ALPNProtocols) = 0 then
    Exit;

  LStart := 1;
  for I := 1 to Length(AServerALPNProtocols) + 1 do
  begin
    if (I <= Length(AServerALPNProtocols)) and (AServerALPNProtocols[I] <> ',') then
      Continue;

    LStop := I - 1;
    while (LStart <= LStop) and (AServerALPNProtocols[LStart] <= ' ') do
      Inc(LStart);
    while (LStop >= LStart) and (AServerALPNProtocols[LStop] <= ' ') do
      Dec(LStop);

    if LStop >= LStart then
    begin
      LCandidate := Copy(AServerALPNProtocols, LStart, LStop - LStart + 1);
      if TLS13ClientHelloOffersALPNProtocol(AClientHello, LCandidate) then
        Exit(LCandidate);
    end;

    LStart := I + 1;
  end;
end;

function BuildTLS13EncryptedExtensionsHandshake(
  AAcceptEarlyData: Boolean;
  const ASelectedALPNProtocol: string;
  ARecordSizeLimit: Word
): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
  LALPNData: TBytes;
  LALPNList: TBytes;
begin
  SetLength(LExtensions, 0);
  if AAcceptEarlyData then
  begin
    AppendUInt16(LExtensions, TLS_EXTENSION_EARLY_DATA);
    AppendUInt16(LExtensions, 0);
  end;

  if (ARecordSizeLimit < TLS13_RECORD_SIZE_LIMIT_MIN) or
    (ARecordSizeLimit > TLS13_RECORD_SIZE_LIMIT_MAX) then
    RaiseInvalidParameter('TLS13RecordSizeLimit');

  AppendUInt16(LExtensions, TLS_EXTENSION_RECORD_SIZE_LIMIT);
  AppendUInt16(LExtensions, 2);
  AppendUInt16(LExtensions, ARecordSizeLimit);

  if ASelectedALPNProtocol <> '' then
  begin
    LALPNList := ParseALPNProtocolList(ASelectedALPNProtocol);
    if Length(LALPNList) = 0 then
      RaiseInvalidParameter('ALPNProtocol');

    SetLength(LALPNData, 0);
    AppendUInt16(LALPNData, Word(Length(LALPNList)));
    AppendBytes(LALPNData, LALPNList);
    LALPNData := BuildExtensionHeader(TLS_EXTENSION_ALPN, LALPNData);
    AppendBytes(LExtensions, LALPNData);
  end;

  SetLength(LBody, 0);
  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  SetLength(Result, 0);
  AppendByte(Result, TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

constructor TFreePascalConnection.Create(AContext: ISSLContext; ASocket: THandle);
begin
  inherited Create(AContext);
  FSocket := ASocket;
  FStream := nil;
  FOwnsStream := False;
  InitializeState(AContext);
end;

constructor TFreePascalConnection.Create(AContext: ISSLContext; AStream: TStream);
begin
  inherited Create(AContext);
  if AStream = nil then
    RaiseInvalidParameter('AStream');
  FSocket := -1;
  FStream := AStream;
  FOwnsStream := False;
  InitializeState(AContext);
end;

procedure TFreePascalConnection.InitializeState(AContext: ISSLContext);
begin
  FReadTimeoutMs := 30000;
  FWriteTimeoutMs := 30000;
  FServerName := '';
  FProtocolVersion := SelectPreferredProtocol(AContext);
  FCipherName := '';
  FALPNProtocols := AContext.GetALPNProtocols;
  FSelectedALPNProtocol := '';
  SetLength(FX25519PrivateKey, 0);
  SetLength(FX25519PublicKey, 0);
  SetLength(FHandshakeSharedSecret, 0);
  InitTLS13EarlyDataSecrets(FEarlyDataSecrets);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  SetLength(FServerFinishedKey, 0);
  SetLength(FClientFinishedKey, 0);
  FEarlyDataSeq := 0;
  FServerHandshakeSeq := 0;
  FClientHandshakeSeq := 0;
  InitTLS13ApplicationSecrets(FApplicationSecrets);
  FClientApplicationSeq := 0;
  FServerApplicationSeq := 0;
  SetLength(FApplicationReadBuffer, 0);
  SetLength(FPostHandshakeBuffer, 0);
  FSessionTicketCount := 0;
  InitTLS13NewSessionTicket(FLastSessionTicket);
  FIsServerMode := False;
  FCurrentSession := nil;
  FConfiguredSession := nil;
  FSessionReused := False;
  FSessionBoundServerName := '';
  FPeerCertificate := nil;
  SetLength(FPeerCertificateChain, 0);
  SetLength(FOCSPResponse, 0);
  FOCSPResponseVerified := False;
  FOCSPResponseStatus := 'Not Requested';
  SetLength(FSignedCertificateTimestampList, 0);
  FSignedCertificateTimestampCount := 0;
  FCertificateTransparencyStatus := 'Not Requested';
  FHasCertificateTransparencyValidationResult := False;
  FCertificateTransparencyPolicySatisfied := False;
  FCertificateTransparencyValidationStatus := 'Not Attempted';
  FEarlyDataStatus := sslEarlyDataNone;
  FEarlyDataLimit := 0;
  SetLength(FEarlyDataPayload, 0);
  FLocalRecordSizeLimit := TLS13_RECORD_SIZE_LIMIT_DEFAULT;
  FPeerRecordSizeLimit := TLS13_RECORD_SIZE_LIMIT_DEFAULT;
end;

destructor TFreePascalConnection.Destroy;
begin
  if FOwnsStream then
    FStream.Free;
  SecureZeroBytes(FX25519PrivateKey);
  SecureZeroBytes(FX25519PublicKey);
  SecureZeroBytes(FP256PrivateKey);
  SecureZeroBytes(FP384PrivateKey);
  SecureZeroBytes(FHandshakeSharedSecret);
  ClearTLS13EarlyDataSecrets(FEarlyDataSecrets);
  ClearTLS13HandshakeSecrets(FHandshakeSecrets);
  SecureZeroBytes(FServerFinishedKey);
  SecureZeroBytes(FClientFinishedKey);
  ClearTLS13ApplicationSecrets(FApplicationSecrets);
  SecureZeroBytes(FOCSPResponse);
  SecureZeroBytes(FEarlyDataPayload);
  SecureZeroBytes(FApplicationReadBuffer);
  SecureZeroBytes(FPostHandshakeBuffer);
  SecureZeroBytes(FTLS12ReadBuffer);
  SecureZeroBytes(FTLS12State.ClientWriteKey);
  SecureZeroBytes(FTLS12State.ServerWriteKey);
  SecureZeroBytes(FTLS12State.ClientWriteIV);
  SecureZeroBytes(FTLS12State.ServerWriteIV);
  SecureZeroBytes(FTLS12State.ClientWriteMACKey);
  SecureZeroBytes(FTLS12State.ServerWriteMACKey);
  SecureZeroBytes(FTLS12State.MasterSecret);
  inherited Destroy;
end;

function TFreePascalConnection.SendData(const ABuffer; ASize: Integer): Integer;
begin
  if FStream <> nil then
    Exit(FStream.Write(ABuffer, ASize));

  if FSocket < 0 then
    Exit(-1);

  {$IFDEF WINDOWS}
  Result := Winsock2.send(FSocket, ABuffer, ASize, 0);
  if Result = SOCKET_ERROR then
    Result := -1;
  {$ELSE}
  Result := fpSend(FSocket, @ABuffer, ASize, 0);
  {$ENDIF}
end;

function TFreePascalConnection.RecvData(var ABuffer; ASize: Integer): Integer;
{$IFDEF UNIX}
var
  LSet: TFDSet;
  LTimeout: TTimeVal;
  LRet: Integer;
{$ENDIF}
begin
  if FStream <> nil then
    Exit(FStream.Read(ABuffer, ASize));

  if FSocket < 0 then
    Exit(-1);

  {$IFDEF UNIX}
  if FReadTimeoutMs > 0 then
  begin
    fpFD_ZERO(LSet);
    fpFD_SET(FSocket, LSet);
    LTimeout.tv_sec := FReadTimeoutMs div 1000;
    LTimeout.tv_usec := (FReadTimeoutMs mod 1000) * 1000;
    LRet := fpSelect(FSocket + 1, @LSet, nil, nil, @LTimeout);
    if LRet <= 0 then
      Exit(-1);
  end;
  {$ENDIF}

  {$IFDEF WINDOWS}
  Result := Winsock2.recv(FSocket, ABuffer, ASize, 0);
  if Result = SOCKET_ERROR then
    Result := -1;
  {$ELSE}
  Result := fpRecv(FSocket, @ABuffer, ASize, 0);
  {$ENDIF}
end;

procedure TFreePascalConnection.SetReadTimeout(AMs: Integer);
begin
  FReadTimeoutMs := AMs;
  {$IFDEF WINDOWS}
  if FSocket >= 0 then
    setsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, @AMs, SizeOf(AMs));
  {$ENDIF}
end;

procedure TFreePascalConnection.SetWriteTimeout(AMs: Integer);
begin
  FWriteTimeoutMs := AMs;
  {$IFDEF WINDOWS}
  if FSocket >= 0 then
    setsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, @AMs, SizeOf(AMs));
  {$ENDIF}
end;

function TFreePascalConnection.SendAll(const AData: TBytes): Boolean;
var
  LOffset, LChunk, LTotal: Integer;
begin
  Result := False;
  LTotal := Length(AData);
  LOffset := 0;

  while LOffset < LTotal do
  begin
    LChunk := SendData(AData[LOffset], LTotal - LOffset);
    if LChunk <= 0 then
      Exit;
    Inc(LOffset, LChunk);
  end;

  Result := True;
end;

function TFreePascalConnection.RecvExact(var AData: TBytes; ACount: Integer): Boolean;
var
  LOffset, LChunk: Integer;
begin
  Result := False;
  if ACount < 0 then
    Exit;

  SetLength(AData, ACount);
  LOffset := 0;

  while LOffset < ACount do
  begin
    LChunk := RecvData(AData[LOffset], ACount - LOffset);
    if LChunk <= 0 then
      Exit;
    Inc(LOffset, LChunk);
  end;

  Result := True;
end;

function TFreePascalConnection.RecvTLSRecord(out AHeader: TTLSRecordHeader; out APayload, ARecord: TBytes): Boolean;
const
  TLS_MAX_CIPHERTEXT_LENGTH = 16384 + 256;
var
  LHeaderBytes: TBytes;
begin
  Result := False;
  SetLength(APayload, 0);
  SetLength(ARecord, 0);

  if not RecvExact(LHeaderBytes, 5) then
    Exit;

  if not ParseTLSRecordHeader(LHeaderBytes, AHeader) then
    Exit;

  if AHeader.Length > TLS_MAX_CIPHERTEXT_LENGTH then
    Exit;

  if not RecvExact(APayload, AHeader.Length) then
    Exit;

  SetLength(ARecord, 5 + Length(APayload));
  Move(LHeaderBytes[0], ARecord[0], 5);
  if Length(APayload) > 0 then
    Move(APayload[0], ARecord[5], Length(APayload));

  Result := True;
end;

function TFreePascalConnection.EffectivePeerTLS13PlaintextLimit: Word;
begin
  Result := FPeerRecordSizeLimit;
  if Result < TLS13_RECORD_SIZE_LIMIT_MIN then
    Result := TLS13_RECORD_SIZE_LIMIT_DEFAULT;
  if Result > TLS13_RECORD_SIZE_LIMIT_MAX then
    Result := TLS13_RECORD_SIZE_LIMIT_MAX;
end;

function TFreePascalConnection.EffectiveLocalTLS13PlaintextLimit: Word;
begin
  Result := FLocalRecordSizeLimit;
  if Result < TLS13_RECORD_SIZE_LIMIT_MIN then
    Result := TLS13_RECORD_SIZE_LIMIT_DEFAULT;
  if Result > TLS13_RECORD_SIZE_LIMIT_MAX then
    Result := TLS13_RECORD_SIZE_LIMIT_MAX;
end;

function TFreePascalConnection.EffectivePeerApplicationFragmentLimit: Integer;
begin
  Result := Integer(EffectivePeerTLS13PlaintextLimit) - 1;
  if Result < 1 then
    Result := 1;
end;

function TFreePascalConnection.ValidateReceivedTLS13PlaintextLength(APlaintextLength: Integer): Boolean;
var
  LLimit: Word;
begin
  Result := False;
  LLimit := EffectiveLocalTLS13PlaintextLimit;
  if APlaintextLength > Integer(LLimit) then
  begin
    SetHandshakeError(
      sslErrProtocol,
      Format('Received TLSInnerPlaintext exceeds record_size_limit (limit=%d actual=%d)',
        [Integer(LLimit), APlaintextLength])
    );
    Exit;
  end;

  Result := True;
end;

function TFreePascalConnection.GetBufferedStreamBytesAvailable: Int64;
begin
  Result := 0;
  if FStream = nil then
    Exit;

  try
    Result := FStream.Size - FStream.Position;
  except
    Result := 0;
  end;
  if Result < 0 then
    Result := 0;
end;

procedure TFreePascalConnection.SetHandshakeError(ACode: TSSLErrorCode; const AMessage: string);
begin
  FLastErrorCode := ACode;
  FLastErrorString := AMessage;
  RecordError(FLastErrorCode, FLastErrorString);
  SendPlaintextAlert(2, ErrorCodeToAlertDescription(ACode));
end;

function TFreePascalConnection.ErrorCodeToAlertDescription(ACode: TSSLErrorCode): Byte;
begin
  case ACode of
    sslErrProtocol: Result := 50;    // decode_error
    sslErrHandshake: Result := 40;   // handshake_failure
    sslErrCertificate: Result := 42; // bad_certificate
    sslErrUnsupported: Result := 71; // insufficient_security
    sslErrIO: Result := 80;          // internal_error
  else
    Result := 40; // handshake_failure (default)
  end;
end;

procedure TFreePascalConnection.SendPlaintextAlert(ALevel, ADescription: Byte);
var
  LRecord: TBytes;
begin
  // TLS record: ContentType(21=alert) + Version(0x0303) + Length(2) + Level + Description
  SetLength(LRecord, 7);
  LRecord[0] := 21; // alert
  LRecord[1] := $03; LRecord[2] := $03; // TLS 1.2 version
  LRecord[3] := 0; LRecord[4] := 2; // length = 2
  LRecord[5] := ALevel;
  LRecord[6] := ADescription;
  SendAll(LRecord);
end;

function TFreePascalConnection.SendTLS12ProtectedRecord(
  AContentType: Byte;
  const APlaintext: TBytes
): Boolean;
var
  LSuiteInfo: TTLS12CipherSuiteInfo;
  LEncrypted: TBytes;
  LError: string;
  LHeader: TBytes;
  LWriteKey, LWriteIV, LWriteMACKey: TBytes;
  LWriteSeqNum: PQWord;
begin
  Result := False;

  if FStream = nil then
  begin
    FLastErrorCode := sslErrInvalidParam;
    FLastErrorString := 'TLS 1.2 protected record send requires stream transport';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  if not TLS12GetCipherSuiteInfo(FTLS12State.CipherSuite, LSuiteInfo) then
  begin
    FLastErrorCode := sslErrUnsupported;
    FLastErrorString := Format(
      'Unsupported TLS 1.2 cipher suite for protected record: 0x%s',
      [IntToHex(FTLS12State.CipherSuite, 4)]
    );
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

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

  case LSuiteInfo.RecordMode of
    rmCBC:
      if LSuiteInfo.PRFHash = phSHA384 then
        Result := TLS12CBCEncrypt_SHA384(
          LWriteKey, LWriteMACKey, LWriteSeqNum^,
          AContentType, APlaintext, LEncrypted, LError
        )
      else
        Result := TLS12CBCEncrypt_SHA256(
          LWriteKey, LWriteMACKey, LWriteSeqNum^,
          AContentType, APlaintext, LEncrypted, LError
        );
    rmChaCha20Poly1305:
      Result := TLS12ChaCha20Poly1305EncryptRecord(
        LWriteKey, LWriteIV, LWriteSeqNum^,
        AContentType, APlaintext, LEncrypted, LError
      );
  else
    Result := TLS12GCMEncryptRecord(
      LWriteKey, LWriteIV, LWriteSeqNum^,
      AContentType, APlaintext, LEncrypted, LError
    );
  end;

  if not Result then
  begin
    FLastErrorCode := sslErrEncryptionFailed;
    FLastErrorString := 'TLS 1.2 protected record encryption failed: ' + LError;
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  if LWriteSeqNum^ = High(QWord) then
  begin
    FLastErrorCode := sslErrProtocol;
    FLastErrorString := 'TLS 1.2 sequence number overflow';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit(False);
  end;
  Inc(LWriteSeqNum^);
  LHeader := TLS12BuildRecordHeader(AContentType, Length(LEncrypted));
  try
    FStream.WriteBuffer(LHeader[0], Length(LHeader));
    if Length(LEncrypted) > 0 then
      FStream.WriteBuffer(LEncrypted[0], Length(LEncrypted));
  except
    on E: Exception do
    begin
      FLastErrorCode := sslErrIO;
      FLastErrorString := 'TLS 1.2 protected record write failed: ' + E.Message;
      RecordError(FLastErrorCode, FLastErrorString);
      Exit(False);
    end;
  end;

  Result := True;
end;

function TFreePascalConnection.ReadTLS12ProtectedRecord(
  out AContentType: Byte;
  out APlaintext: TBytes;
  out AError: string
): Boolean;
var
  LSuiteInfo: TTLS12CipherSuiteInfo;
  LEncrypted: TBytes;
  LDecryptError: string;
  LReadKey, LReadIV, LReadMACKey: TBytes;
  LReadSeqNum: PQWord;
begin
  Result := False;
  AContentType := 0;
  AError := '';
  SetLength(APlaintext, 0);

  if (FStream = nil) or not TLS12ReadRecord(FStream, AContentType, LEncrypted) then
  begin
    AError := 'Failed to read TLS 1.2 protected record';
    Exit;
  end;

  if not TLS12GetCipherSuiteInfo(FTLS12State.CipherSuite, LSuiteInfo) then
  begin
    AError := Format(
      'Unsupported TLS 1.2 cipher suite for protected record: 0x%s',
      [IntToHex(FTLS12State.CipherSuite, 4)]
    );
    Exit;
  end;

  // Read direction is the peer's write direction: a server reads with the
  // client's write keys, a client reads with the server's write keys.
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

  case LSuiteInfo.RecordMode of
    rmCBC:
      if LSuiteInfo.PRFHash = phSHA384 then
        Result := TLS12CBCDecrypt_SHA384(
          LReadKey, LReadMACKey, LReadSeqNum^,
          AContentType, LEncrypted, APlaintext, LDecryptError
        )
      else
        Result := TLS12CBCDecrypt_SHA256(
          LReadKey, LReadMACKey, LReadSeqNum^,
          AContentType, LEncrypted, APlaintext, LDecryptError
        );
    rmChaCha20Poly1305:
      Result := TLS12ChaCha20Poly1305DecryptRecord(
        LReadKey, LReadIV, LReadSeqNum^,
        AContentType, LEncrypted, APlaintext, LDecryptError
      );
  else
    Result := TLS12GCMDecryptRecord(
      LReadKey, LReadIV, LReadSeqNum^,
      AContentType, LEncrypted, APlaintext, LDecryptError
    );
  end;

  if not Result then
  begin
    AError := 'TLS 1.2 protected record decryption failed: ' + LDecryptError;
    Exit;
  end;

  if LReadSeqNum^ = High(QWord) then
  begin
    AError := 'TLS 1.2 sequence number overflow';
    Exit(False);
  end;
  Inc(LReadSeqNum^);
  Result := True;
end;

function TFreePascalConnection.DoRenegotiateTLS12: Boolean;
var
  LOptions: TTLS12ClientHelloOptions;
  LClientRandom: TBytes;
  LClientHello: TBytes;
  LAlert: TBytes;
  LContentType: Byte;
  LData: TBytes;
  LError: string;
  LBodyLen: Integer;
  LBody: TBytes;
  LServerHello: TTLS12ServerHello;
  LExpectedRenegotiationInfo: TBytes;
  LContextCipherSuites: IFreePascalContextCipherSuites;
  LProtoList: TStringArray;
  LProtocol: string;
  I: Integer;
begin
  Result := False;

  SetLength(LAlert, 2);
  LAlert[0] := TLS12_ALERT_LEVEL_WARNING;
  LAlert[1] := TLS12_ALERT_NO_RENEGOTIATION;

  if FStream = nil then
  begin
    MarkUnsupported('TLS 1.2 renegotiation requires TStream transport');
    Exit;
  end;

  if (not FTLS12State.SecureRenegotiationSupported) or
    (Length(FTLS12State.ClientVerifyData) <> 12) or
    (Length(FTLS12State.ServerVerifyData) <> 12) then
  begin
    SendTLS12ProtectedRecord(TLS12_CONTENT_ALERT, LAlert);
    FLastErrorCode := sslErrUnsupported;
    FLastErrorString := 'TLS 1.2 secure renegotiation was not negotiated in the initial handshake';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  LOptions.ServerName := FServerName;
  LOptions.SupportEMS := True;
  LOptions.RenegotiatedConnection := Copy(FTLS12State.ClientVerifyData);
  SetLength(LOptions.SessionID, 0);
  SetLength(LOptions.SessionTicket, 0);
  SetLength(LOptions.ALPNProtocols, 0);

  if Trim(FALPNProtocols) <> '' then
  begin
    LProtoList := FALPNProtocols.Split([',']);
    for I := 0 to High(LProtoList) do
    begin
      LProtocol := Trim(LProtoList[I]);
      if LProtocol = '' then
        Continue;
      SetLength(LOptions.ALPNProtocols, Length(LOptions.ALPNProtocols) + 1);
      LOptions.ALPNProtocols[High(LOptions.ALPNProtocols)] := LProtocol;
    end;
  end;

  if Supports(FContext, IFreePascalContextCipherSuites, LContextCipherSuites) then
    LOptions.CipherSuites := CopyCipherSuitesToTLS12(
      LContextCipherSuites.GetConfiguredCipherSuites12
    )
  else
    SetLength(LOptions.CipherSuites, 0);

  SetLength(LClientRandom, 32);
  SecureRandomBytes(@LClientRandom[0], 32);
  LClientHello := BuildTLS12ClientHello(LOptions, LClientRandom);

  if not SendTLS12ProtectedRecord(TLS12_CONTENT_HANDSHAKE, LClientHello) then
    Exit;

  if not ReadTLS12ProtectedRecord(LContentType, LData, LError) then
  begin
    FLastErrorCode := sslErrIO;
    FLastErrorString := 'TLS 1.2 renegotiation peer response was not readable: ' + LError;
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  if LContentType = TLS12_CONTENT_ALERT then
  begin
    if (Length(LData) >= 2) and (LData[1] = TLS12_ALERT_NO_RENEGOTIATION) then
    begin
      FLastErrorCode := sslErrUnsupported;
      FLastErrorString := 'TLS 1.2 renegotiation refused by peer with no_renegotiation alert';
      RecordError(FLastErrorCode, FLastErrorString);
      Exit;
    end;

    FLastErrorCode := sslErrProtocol;
    if Length(LData) >= 2 then
      FLastErrorString := Format(
        'TLS 1.2 renegotiation failed with alert level=%d desc=%d',
        [LData[0], LData[1]]
      )
    else
      FLastErrorString := 'TLS 1.2 renegotiation failed with malformed alert';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  if (LContentType <> TLS12_CONTENT_HANDSHAKE) or (Length(LData) < 4) or
    (LData[0] <> TLS12_HANDSHAKE_SERVER_HELLO) then
  begin
    SendTLS12ProtectedRecord(TLS12_CONTENT_ALERT, LAlert);
    FLastErrorCode := sslErrProtocol;
    FLastErrorString := 'TLS 1.2 renegotiation expected ServerHello handshake';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  LBodyLen := (Integer(LData[1]) shl 16) or (Integer(LData[2]) shl 8) or Integer(LData[3]);
  if Length(LData) < 4 + LBodyLen then
  begin
    SendTLS12ProtectedRecord(TLS12_CONTENT_ALERT, LAlert);
    FLastErrorCode := sslErrProtocol;
    FLastErrorString := 'TLS 1.2 renegotiation ServerHello is truncated';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  LBody := Copy(LData, 4, LBodyLen);
  if not TryParseTLS12ServerHello(LBody, 0, LServerHello, LError) then
  begin
    SendTLS12ProtectedRecord(TLS12_CONTENT_ALERT, LAlert);
    FLastErrorCode := sslErrProtocol;
    FLastErrorString := 'TLS 1.2 renegotiation ServerHello parse failed: ' + LError;
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  SetLength(LExpectedRenegotiationInfo, 0);
  AppendHandshakeBytes(LExpectedRenegotiationInfo, FTLS12State.ClientVerifyData);
  AppendHandshakeBytes(LExpectedRenegotiationInfo, FTLS12State.ServerVerifyData);

  if (not LServerHello.HasRenegotiationInfo) or
    (TConstantTime.CompareBytes(
      LServerHello.RenegotiatedConnection,
      LExpectedRenegotiationInfo
    ) <> 1) then
  begin
    SendTLS12ProtectedRecord(TLS12_CONTENT_ALERT, LAlert);
    FLastErrorCode := sslErrProtocol;
    FLastErrorString :=
      'TLS 1.2 renegotiation ServerHello failed RFC 5746 renegotiation_info validation';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  SendTLS12ProtectedRecord(TLS12_CONTENT_ALERT, LAlert);
  FLastErrorCode := sslErrUnsupported;
  FLastErrorString :=
    'TLS 1.2 secure renegotiation was accepted by peer; full handshake completion is not implemented';
  RecordError(FLastErrorCode, FLastErrorString);
end;

procedure TFreePascalConnection.AppendHandshakeBytes(var ADest: TBytes; const ASource: TBytes);
var
  LOldLen, LAppendLen: Integer;
begin
  LAppendLen := Length(ASource);
  if LAppendLen = 0 then
    Exit;

  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + LAppendLen);
  Move(ASource[0], ADest[LOldLen], LAppendLen);
end;

function TFreePascalConnection.TryPopHandshakeMessage(var ABuffer: TBytes; out AMessage: TBytes): Boolean;
var
  LMsgLen: Cardinal;
  LTotalLen: Integer;
  LRemainLen: Integer;
  LTemp: TBytes;
begin
  SetLength(AMessage, 0);
  Result := False;

  if Length(ABuffer) < 4 then
    Exit;

  LMsgLen := ReadUInt24(ABuffer, 1);
  if LMsgLen > Cardinal(High(Integer) - 4) then
    Exit;

  LTotalLen := 4 + Integer(LMsgLen);
  if Length(ABuffer) < LTotalLen then
    Exit;

  SetLength(AMessage, LTotalLen);
  Move(ABuffer[0], AMessage[0], LTotalLen);

  LRemainLen := Length(ABuffer) - LTotalLen;
  if LRemainLen > 0 then
  begin
    SetLength(LTemp, LRemainLen);
    Move(ABuffer[LTotalLen], LTemp[0], LRemainLen);
    ABuffer := LTemp;
  end
  else
    SetLength(ABuffer, 0);

  Result := True;
end;

function TFreePascalConnection.ProcessPostHandshakeFragment(const AHandshakeFragment: TBytes): Boolean;
var
  LMessage: TBytes;
  LType: Byte;
  LError: string;
  LTicket: TTLS13NewSessionTicket;
  LKeyUpdate: TTLS13KeyUpdateInfo;
  LResumptionPSK: TBytes;
  LSession: TFreePascalSession;
  LTimeout: Integer;
begin
  Result := False;

  if Length(AHandshakeFragment) = 0 then
  begin
    Result := True;
    Exit;
  end;

  AppendHandshakeBytes(FPostHandshakeBuffer, AHandshakeFragment);

  while TryPopHandshakeMessage(FPostHandshakeBuffer, LMessage) do
  begin
    if Length(LMessage) < 4 then
    begin
      SetHandshakeError(sslErrProtocol, 'Malformed post-handshake message header');
      Exit;
    end;

    LType := LMessage[0];
    case LType of
      TLS_HANDSHAKE_TYPE_NEW_SESSION_TICKET:
        begin
          if not TryParseTLS13NewSessionTicket(LMessage, LTicket, LError) then
          begin
            SetHandshakeError(sslErrProtocol, 'Invalid NewSessionTicket: ' + LError);
            Exit;
          end;

          if (not FApplicationSecrets.Valid) or
            (Length(FApplicationSecrets.MasterSecret) <> FApplicationSecrets.HashSize) or
            (Length(FApplicationSecrets.ResumptionTranscriptHash) <> FApplicationSecrets.HashSize) then
          begin
            SetHandshakeError(sslErrProtocol, 'Application transcript state is not ready for NewSessionTicket');
            Exit;
          end;

          LResumptionPSK := TLS13DeriveResumptionPSKFromTranscriptHash(
            FApplicationSecrets.CipherSuite,
            FApplicationSecrets.MasterSecret,
            FApplicationSecrets.ResumptionTranscriptHash,
            LTicket.TicketNonce
          );
          if Length(LResumptionPSK) <> FApplicationSecrets.HashSize then
          begin
            SetHandshakeError(sslErrProtocol, 'Failed to derive resumption PSK from NewSessionTicket');
            Exit;
          end;

          if LTicket.TicketLifetime > Cardinal(High(Integer)) then
            LTimeout := High(Integer)
          else
            LTimeout := Integer(LTicket.TicketLifetime);

          LSession := TFreePascalSession.Create;
          LSession.ConfigureResumption(
            FApplicationSecrets.CipherSuite,
            TLS13CipherSuiteToString(FApplicationSecrets.CipherSuite),
            LTicket.TicketNonce,
            LTicket.Ticket,
            LResumptionPSK,
            LTicket.TicketLifetime,
            LTicket.TicketAgeAdd,
            Now,
            LTimeout,
            LTicket.MaxEarlyDataSize
          );
          LSession.BoundServerName := FServerName;
          FCurrentSession := LSession;
          FLastSessionTicket := LTicket;
          Inc(FSessionTicketCount);
        end;

      TLS_HANDSHAKE_TYPE_KEY_UPDATE:
        begin
          if not TryParseTLS13KeyUpdate(LMessage, LKeyUpdate, LError) then
          begin
            SetHandshakeError(sslErrProtocol, 'Invalid KeyUpdate: ' + LError);
            Exit;
          end;

          if FIsServerMode then
          begin
            if not TryUpdateTLS13ClientApplicationReadKeys(FApplicationSecrets, LError) then
            begin
              SetHandshakeError(sslErrProtocol, 'Failed to rotate client application read key: ' + LError);
              Exit;
            end;
            FClientApplicationSeq := 0;
          end
          else
          begin
            if not TryUpdateTLS13ServerApplicationReadKeys(FApplicationSecrets, LError) then
            begin
              SetHandshakeError(sslErrProtocol, 'Failed to rotate server application read key: ' + LError);
              Exit;
            end;
            FServerApplicationSeq := 0;
          end;

          if LKeyUpdate.RequestUpdate then
          begin
            if not SendPostHandshakeKeyUpdate(False) then
              Exit;
          end;
        end;

    else
      begin
        SetHandshakeError(
          sslErrUnsupported,
          Format('Unsupported post-handshake message type %d', [LType])
        );
        Exit;
      end;
    end;
  end;

  if Length(FPostHandshakeBuffer) > 131072 then
  begin
    SetHandshakeError(sslErrProtocol, 'Post-handshake buffer exceeded limit');
    Exit;
  end;

  Result := True;
end;

function TFreePascalConnection.DrainBufferedApplicationRecords: Boolean;
var
  LFragment: TBytes;
begin
  Result := True;
  if FStream = nil then
    Exit;

  while GetBufferedStreamBytesAvailable > 0 do
  begin
    if not RecvApplicationDataFragment(LFragment, True) then
      Exit(False);
    if Length(LFragment) > 0 then
      AppendHandshakeBytes(FApplicationReadBuffer, LFragment);
  end;
end;

{$I nextpas.core.tls.freepascal.connection.validation.inc}

function TFreePascalConnection.SendPostHandshakeKeyUpdate(ARequestPeerUpdate: Boolean): Boolean;
var
  LHandshakeMessage: TBytes;
  LInnerPlaintext: TBytes;
  LAAD: TBytes;
  LNonce: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LError: string;
  LRequestValue: Byte;
begin
  Result := False;

  if not FApplicationSecrets.Valid then
  begin
    SetHandshakeError(sslErrProtocol, 'TLS 1.3 application secrets are not ready for KeyUpdate');
    Exit;
  end;

  if not TLS13AEADIsSupported(FApplicationSecrets.CipherSuite) then
  begin
    SetHandshakeError(
      sslErrUnsupported,
      Format('Cipher suite %s is unsupported for TLS 1.3 KeyUpdate',
        [TLS13CipherSuiteToString(FApplicationSecrets.CipherSuite)])
    );
    Exit;
  end;

  LRequestValue := 0;
  if ARequestPeerUpdate then
    LRequestValue := 1;

  SetLength(LHandshakeMessage, 0);
  AppendByte(LHandshakeMessage, TLS_HANDSHAKE_TYPE_KEY_UPDATE);
  AppendUInt24(LHandshakeMessage, 1);
  AppendByte(LHandshakeMessage, LRequestValue);

  LInnerPlaintext := BuildTLS13InnerPlaintext(LHandshakeMessage, TLS_CONTENT_TYPE_HANDSHAKE);

  if FIsServerMode then
  begin
    try
      LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, FServerApplicationSeq);
    except
      on E: Exception do
      begin
        SetHandshakeError(sslErrProtocol, 'Failed to build server application nonce for KeyUpdate: ' + E.Message);
        Exit;
      end;
    end;

    LAAD := BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FApplicationSecrets.CipherSuite)));
    if not TryTLS13AEADEncrypt(
      FApplicationSecrets.CipherSuite,
      FApplicationSecrets.ServerApplicationKey,
      LNonce,
      LAAD,
      LInnerPlaintext,
      LEncrypted,
      LError
    ) then
    begin
      SetHandshakeError(sslErrEncryptionFailed, 'Failed to encrypt TLS KeyUpdate record: ' + LError);
      Exit;
    end;

    LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
    if not SendAll(LRecord) then
    begin
      SetHandshakeError(sslErrIO, 'Failed to send TLS KeyUpdate record');
      Exit;
    end;

    if not IncrementTLS13Sequence(FServerApplicationSeq) then
    begin
      SetHandshakeError(sslErrProtocol, 'Server application sequence overflow during KeyUpdate');
      Exit;
    end;

    if not TryUpdateTLS13ServerApplicationWriteKeys(FApplicationSecrets, LError) then
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to rotate server application write key: ' + LError);
      Exit;
    end;

    FServerApplicationSeq := 0;
  end
  else
  begin
    try
      LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ClientApplicationIV, FClientApplicationSeq);
    except
      on E: Exception do
      begin
        SetHandshakeError(sslErrProtocol, 'Failed to build client application nonce for KeyUpdate: ' + E.Message);
        Exit;
      end;
    end;

    LAAD := BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FApplicationSecrets.CipherSuite)));
    if not TryTLS13AEADEncrypt(
      FApplicationSecrets.CipherSuite,
      FApplicationSecrets.ClientApplicationKey,
      LNonce,
      LAAD,
      LInnerPlaintext,
      LEncrypted,
      LError
    ) then
    begin
      SetHandshakeError(sslErrEncryptionFailed, 'Failed to encrypt TLS KeyUpdate record: ' + LError);
      Exit;
    end;

    LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
    if not SendAll(LRecord) then
    begin
      SetHandshakeError(sslErrIO, 'Failed to send TLS KeyUpdate record');
      Exit;
    end;

    if not IncrementTLS13Sequence(FClientApplicationSeq) then
    begin
      SetHandshakeError(sslErrProtocol, 'Client application sequence overflow during KeyUpdate');
      Exit;
    end;

    if not TryUpdateTLS13ClientApplicationWriteKeys(FApplicationSecrets, LError) then
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to rotate client application write key: ' + LError);
      Exit;
    end;

    FClientApplicationSeq := 0;
  end;

  Result := True;
end;

{$I nextpas.core.tls.freepascal.connection.tls13client.inc}

function TFreePascalConnection.RecvApplicationDataFragment(
  out AFragment: TBytes;
  AAllowNoRecord: Boolean
): Boolean;
var
  LHeader: TTLSRecordHeader;
  LPayloadBytes: TBytes;
  LRecordBytes: TBytes;
  LAAD: TBytes;
  LNonce: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LRecordIndex: Integer;
  LError: string;
  LAlertLevel: Byte;
  LAlertDescription: Byte;
begin
  SetLength(AFragment, 0);
  Result := False;

  if not FApplicationSecrets.Valid then
  begin
    SetHandshakeError(sslErrProtocol, 'TLS 1.3 application secrets are not ready');
    Exit;
  end;

  for LRecordIndex := 1 to 128 do
  begin
    if not RecvTLSRecord(LHeader, LPayloadBytes, LRecordBytes) then
    begin
      if AAllowNoRecord and (FStream <> nil) and (GetBufferedStreamBytesAvailable <= 0) then
      begin
        Result := True;
        Exit;
      end;
      SetHandshakeError(sslErrIO, 'Failed to receive TLS application record');
      Exit;
    end;

    case LHeader.ContentType of
      TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
        Continue;

      TLS_CONTENT_TYPE_ALERT:
        begin
          SetHandshakeError(sslErrHandshake, 'Peer returned plaintext TLS alert during application data phase');
          Exit;
        end;

      TLS_CONTENT_TYPE_APPLICATION_DATA:
        begin
          LAAD := BuildTLS13RecordAAD(LHeader.Length);

          if FIsServerMode then
          begin
            try
              LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ClientApplicationIV, FClientApplicationSeq);
            except
              on E: Exception do
              begin
                SetHandshakeError(sslErrProtocol, 'Failed to build client application nonce: ' + E.Message);
                Exit;
              end;
            end;

            if not IncrementTLS13Sequence(FClientApplicationSeq) then
            begin
              SetHandshakeError(sslErrProtocol, 'Client application sequence overflow');
              Exit;
            end;

            if not TryTLS13AEADDecrypt(
              FApplicationSecrets.CipherSuite,
              FApplicationSecrets.ClientApplicationKey,
              LNonce,
              LAAD,
              LPayloadBytes,
              LPlaintext,
              LError
            ) then
            begin
              SetHandshakeError(sslErrDecryptionFailed, 'Failed to decrypt TLS application record: ' + LError);
              Exit;
            end;
          end
          else
          begin
            try
              LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, FServerApplicationSeq);
            except
              on E: Exception do
              begin
                SetHandshakeError(sslErrProtocol, 'Failed to build server application nonce: ' + E.Message);
                Exit;
              end;
            end;

            if not IncrementTLS13Sequence(FServerApplicationSeq) then
            begin
              SetHandshakeError(sslErrProtocol, 'Server application sequence overflow');
              Exit;
            end;

            if not TryTLS13AEADDecrypt(
              FApplicationSecrets.CipherSuite,
              FApplicationSecrets.ServerApplicationKey,
              LNonce,
              LAAD,
              LPayloadBytes,
              LPlaintext,
              LError
            ) then
            begin
              SetHandshakeError(sslErrDecryptionFailed, 'Failed to decrypt TLS application record: ' + LError);
              Exit;
            end;
          end;

          if not ValidateReceivedTLS13PlaintextLength(Length(LPlaintext)) then
            Exit;

          if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
          begin
            SetHandshakeError(sslErrProtocol, 'Invalid TLSInnerPlaintext in application data phase');
            Exit;
          end;

          case LInnerContentType of
            TLS_CONTENT_TYPE_APPLICATION_DATA:
              begin
                AFragment := LInnerFragment;
                Result := True;
                Exit;
              end;

            TLS_CONTENT_TYPE_HANDSHAKE:
              begin
                if not ProcessPostHandshakeFragment(LInnerFragment) then
                  Exit;
                if AAllowNoRecord then
                begin
                  Result := True;
                  Exit;
                end;
                Continue;
              end;

            TLS_CONTENT_TYPE_ALERT:
              begin
                if Length(LInnerFragment) >= 2 then
                begin
                  LAlertLevel := LInnerFragment[0];
                  LAlertDescription := LInnerFragment[1];
                  SetHandshakeError(
                    sslErrHandshake,
                    Format('Peer sent encrypted alert (level=%d description=%d)', [LAlertLevel, LAlertDescription])
                  );
                end
                else
                  SetHandshakeError(sslErrHandshake, 'Peer sent malformed encrypted alert');
                Exit;
              end;

          else
            begin
              SetHandshakeError(
                sslErrProtocol,
                Format('Unexpected inner content type %d in application data phase', [LInnerContentType])
              );
              Exit;
            end;
          end;
        end;

    else
      begin
        SetHandshakeError(
          sslErrProtocol,
          Format('Unexpected TLS record type %d in application data phase', [LHeader.ContentType])
        );
        Exit;
      end;
    end;
  end;

  SetHandshakeError(sslErrProtocol, 'Application data record not received within processing budget');
end;

function TFreePascalConnection.SendApplicationDataFragment(const AFragment: TBytes): Boolean;
var
  LInnerPlaintext: TBytes;
  LAAD: TBytes;
  LNonce: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LError: string;
begin
  Result := False;

  if not FApplicationSecrets.Valid then
  begin
    SetHandshakeError(sslErrProtocol, 'TLS 1.3 application secrets are not ready');
    Exit;
  end;

  if not TLS13AEADIsSupported(FApplicationSecrets.CipherSuite) then
  begin
    SetHandshakeError(
      sslErrUnsupported,
      Format('Cipher suite %s is unsupported in pure FreePascal application data path',
        [TLS13CipherSuiteToString(FApplicationSecrets.CipherSuite)])
    );
    Exit;
  end;

  LInnerPlaintext := BuildTLS13InnerPlaintext(AFragment, TLS_CONTENT_TYPE_APPLICATION_DATA);
  if Length(LInnerPlaintext) > Integer(EffectivePeerTLS13PlaintextLimit) then
  begin
    SetHandshakeError(
      sslErrProtocol,
      Format('Application data fragment exceeds peer record_size_limit (limit=%d actual=%d)',
        [Integer(EffectivePeerTLS13PlaintextLimit), Length(LInnerPlaintext)])
    );
    Exit;
  end;

  if FIsServerMode then
  begin
    try
      LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, FServerApplicationSeq);
    except
      on E: Exception do
      begin
        SetHandshakeError(sslErrProtocol, 'Failed to build server application nonce: ' + E.Message);
        Exit;
      end;
    end;

    LAAD := BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FApplicationSecrets.CipherSuite)));
    if not TryTLS13AEADEncrypt(
      FApplicationSecrets.CipherSuite,
      FApplicationSecrets.ServerApplicationKey,
      LNonce,
      LAAD,
      LInnerPlaintext,
      LEncrypted,
      LError
    ) then
    begin
      SetHandshakeError(sslErrEncryptionFailed, 'Failed to encrypt TLS application record: ' + LError);
      Exit;
    end;

    LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
    if not SendAll(LRecord) then
    begin
      SetHandshakeError(sslErrIO, 'Failed to send TLS application record');
      Exit;
    end;

    if not IncrementTLS13Sequence(FServerApplicationSeq) then
    begin
      SetHandshakeError(sslErrProtocol, 'Server application sequence overflow');
      Exit;
    end;
  end
  else
  begin
    try
      LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ClientApplicationIV, FClientApplicationSeq);
    except
      on E: Exception do
      begin
        SetHandshakeError(sslErrProtocol, 'Failed to build client application nonce: ' + E.Message);
        Exit;
      end;
    end;

    LAAD := BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FApplicationSecrets.CipherSuite)));
    if not TryTLS13AEADEncrypt(
      FApplicationSecrets.CipherSuite,
      FApplicationSecrets.ClientApplicationKey,
      LNonce,
      LAAD,
      LInnerPlaintext,
      LEncrypted,
      LError
    ) then
    begin
      SetHandshakeError(sslErrEncryptionFailed, 'Failed to encrypt TLS application record: ' + LError);
      Exit;
    end;

    LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
    if not SendAll(LRecord) then
    begin
      SetHandshakeError(sslErrIO, 'Failed to send TLS application record');
      Exit;
    end;

    if not IncrementTLS13Sequence(FClientApplicationSeq) then
    begin
      SetHandshakeError(sslErrProtocol, 'Client application sequence overflow');
      Exit;
    end;
  end;

  Result := True;
end;

function TFreePascalConnection.ProbeServerHello: Boolean;
var
  LClientHelloHandshake: TBytes;
  LClientHelloRecord: TBytes;
  LPayloadBytes: TBytes;
  LRecordBytes: TBytes;
  LHeader: TTLSRecordHeader;
  LHandshake: TBytes;
  LServerHello: TTLS13ServerHelloInfo;
  LRecordIndex: Integer;
  LTranscriptData: TBytes;
  LKeyScheduleError: string;
  LConfiguredResumption: IFreePascalResumptionSession;
  LEarlyDataContext: ISSLEarlyDataContext;
  LUseConfiguredSession: Boolean;
  LPartialClientHello: TBytes;
  LSessionAgeMs: Int64;
  LWantEarlyData: Boolean;
  LWantOCSPStapling: Boolean;
  LWantCertificateTransparency: Boolean;
  LConfiguredCipherSuites: TTLS13CipherSuiteList;
  LContextCipherSuites: IFreePascalContextCipherSuites;
  LCH1Hash: TBytes;
  LMessageHash: TBytes;
  LHRRTranscript: TBytes;
  LHasHelloRetryRequest: Boolean;
  LP256PrivKey: TBytes;
  LP256PubKey: TBytes;
  LP256Point: TECPoint;
  LP256Error: string;
  LCH2Handshake: TBytes;
  LCH2Record: TBytes;
  LP256Peer: TECPoint;
  LP256Shared: TECPoint;
  LP256Err: string;
  LCookieExt: TBytes;
  LExtListLen: Integer;
  LPos: Integer;
  I: Integer;
begin
  Result := False;
  FSelectedALPNProtocol := '';
  ClearPeerCertificateCache;
  SetLength(FHandshakeSharedSecret, 0);
  InitTLS13EarlyDataSecrets(FEarlyDataSecrets);
  ClearTLS13HandshakeSecrets(FHandshakeSecrets);
  SetLength(FServerFinishedKey, 0);
  SetLength(FClientFinishedKey, 0);
  FEarlyDataSeq := 0;
  FServerHandshakeSeq := 0;
  FClientHandshakeSeq := 0;
  LHasHelloRetryRequest := False;
  FPeerRecordSizeLimit := TLS13_RECORD_SIZE_LIMIT_DEFAULT;

  ClearTLS13ApplicationSecrets(FApplicationSecrets);
  FClientApplicationSeq := 0;
  FServerApplicationSeq := 0;
  SetLength(FApplicationReadBuffer, 0);
  SetLength(FPostHandshakeBuffer, 0);
  FSessionTicketCount := 0;
  InitTLS13NewSessionTicket(FLastSessionTicket);
  FIsServerMode := False;
  FSessionReused := False;
  if FEarlyDataStatus <> sslEarlyDataQueued then
    FEarlyDataStatus := sslEarlyDataNone;

  try
    FX25519PrivateKey := GenerateX25519PrivateKey;
    FX25519PublicKey := X25519PublicKeyFromPrivate(FX25519PrivateKey);
  except
    on E: Exception do
    begin
      FLastErrorCode := sslErrHandshake;
      FLastErrorString := 'Failed to generate X25519 key share: ' + E.Message;
      RecordError(FLastErrorCode, FLastErrorString);
      Exit;
    end;
  end;

  LUseConfiguredSession :=
    Supports(FConfiguredSession, IFreePascalResumptionSession, LConfiguredResumption) and
    (FConfiguredSession <> nil) and
    FConfiguredSession.IsValid and
    FConfiguredSession.IsResumable and
    (Length(LConfiguredResumption.GetTicket) > 0) and
    (Length(LConfiguredResumption.GetResumptionPSK) > 0);
  FSessionReused := False;
  if LUseConfiguredSession then
    FEarlyDataLimit := LConfiguredResumption.GetMaxEarlyDataSize
  else
    FEarlyDataLimit := 0;

  LWantEarlyData :=
    (FEarlyDataStatus = sslEarlyDataQueued) and
    (Length(FEarlyDataPayload) > 0) and
    LUseConfiguredSession and
    (FEarlyDataLimit > 0) and
    Supports(FContext, ISSLEarlyDataContext, LEarlyDataContext) and
    LEarlyDataContext.GetClientEarlyDataEnabled;
  LWantOCSPStapling :=
    (FContext <> nil) and
    ((ssoEnableOCSPStapling in FContext.GetOptions) or
    (ssoRequireOCSPStapling in FContext.GetOptions));
  LWantCertificateTransparency :=
    (FContext <> nil) and
    (sslVerifyPeer in FContext.GetVerifyMode);


  if Supports(FContext, IFreePascalContextCipherSuites, LContextCipherSuites) then
    LConfiguredCipherSuites := CopyCipherSuitesToTLS13(
      LContextCipherSuites.GetConfiguredCipherSuites13
    )
  else
    SetLength(LConfiguredCipherSuites, 0);
  if LUseConfiguredSession then
  begin
    LSessionAgeMs := MilliSecondsBetween(Now, FConfiguredSession.GetCreationTime);
    if LSessionAgeMs < 0 then
      LSessionAgeMs := 0;

    LClientHelloHandshake := BuildTLS13ClientHelloHandshakeWithComputedPSKBinderAndCiphers(
      FServerName,
      FALPNProtocols,
      FX25519PublicKey,
      LConfiguredResumption.GetCipherSuite,
      LConfiguredResumption.GetTicket,
      Cardinal((QWord(LSessionAgeMs) + QWord(LConfiguredResumption.GetTicketAgeAdd)) and $FFFFFFFF),
      LConfiguredResumption.GetResumptionPSK,
      LConfiguredCipherSuites,
      LPartialClientHello,
      LWantEarlyData,
      LWantOCSPStapling,
      LWantCertificateTransparency
    );

    if Length(LClientHelloHandshake) = 0 then
    begin
      LUseConfiguredSession := False;
      LWantEarlyData := False;
    end
  end;

  if not LUseConfiguredSession then
    LClientHelloHandshake := BuildTLS13ClientHelloHandshakeWithCiphers(
      FServerName,
      FALPNProtocols,
      FX25519PublicKey,
      LConfiguredCipherSuites,
      LWantOCSPStapling,
      LWantCertificateTransparency
    );

  LClientHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LClientHelloHandshake);

  if not SendAll(LClientHelloRecord) then
  begin
    FLastErrorCode := sslErrIO;
    FLastErrorString := 'Failed to send TLS ClientHello';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  if LWantEarlyData then
  begin
    if not TryDeriveTLS13ClientEarlyDataSecrets(
      LConfiguredResumption.GetCipherSuite,
      LConfiguredResumption.GetResumptionPSK,
      LClientHelloHandshake,
      FEarlyDataSecrets,
      LKeyScheduleError
    ) then
    begin
      SetHandshakeError(
        sslErrUnsupported,
        'TLS 1.3 client early-data key schedule derivation failed: ' + LKeyScheduleError
      );
      Exit;
    end;

    if not SendClientEarlyDataRecord(LConfiguredResumption.GetCipherSuite) then
      Exit;
  end;

  for LRecordIndex := 1 to 8 do
  begin
    if not RecvTLSRecord(LHeader, LPayloadBytes, LRecordBytes) then
    begin
      FLastErrorCode := sslErrIO;
      FLastErrorString := 'Failed to receive TLS record during handshake';
      RecordError(FLastErrorCode, FLastErrorString);
      Exit;
    end;

    case LHeader.ContentType of
      TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
        Continue;

      TLS_CONTENT_TYPE_ALERT:
        begin
          FLastErrorCode := sslErrHandshake;
          if Length(LPayloadBytes) >= 2 then
            FLastErrorString := Format('Peer returned TLS alert: level=%d desc=%d', [LPayloadBytes[0], LPayloadBytes[1]])
          else
            FLastErrorString := 'Peer returned TLS alert after ClientHello';
          RecordError(FLastErrorCode, FLastErrorString);
          Exit;
        end;

      TLS_CONTENT_TYPE_HANDSHAKE:
        begin
          if not TryExtractHandshakePayloadFromRecord(LRecordBytes, LHandshake) then
          begin
            FLastErrorCode := sslErrProtocol;
            FLastErrorString := 'Peer handshake record format is invalid';
            RecordError(FLastErrorCode, FLastErrorString);
            Exit;
          end;

          if not TryParseServerHelloFromHandshake(LHandshake, LServerHello) then
            Continue;

          if LServerHello.SelectedVersion <> TLS13_VERSION then
          begin
            // Server negotiated TLS 1.2 — fall back to TLS 1.2 client path
            Result := DoConnectTLS12Fallback(LRecordBytes, LClientHelloHandshake);
            Exit;
          end;

          if not LServerHello.HasKeyShare then
          begin
            FLastErrorCode := sslErrProtocol;
            FLastErrorString := 'ServerHello missing key_share extension';
            RecordError(FLastErrorCode, FLastErrorString);
            Exit;
          end;

          // Check for HelloRetryRequest
          if CompareMem(@LServerHello.ServerRandom[0], @TLS13_HRR_RANDOM[0], 32) then
          begin
            // HRR: server wants a different key_share group
            // Construct message_hash transcript: replace CH1 with Hash(CH1)
            // RFC 8446 §4.4.1: message_hash = HandshakeType(254) || Length || Hash(CH1)
            // Hash function must match the cipher suite selected in HRR
            if TLS13CipherSuiteIsSHA384(LServerHello.SelectedCipherSuite) then
              LCH1Hash := SHA384(LClientHelloHandshake)
            else
              LCH1Hash := SHA256(LClientHelloHandshake);
            SetLength(LMessageHash, 4 + Length(LCH1Hash));
            LMessageHash[0] := 254; // message_hash type
            LMessageHash[1] := 0;
            LMessageHash[2] := 0;
            LMessageHash[3] := Byte(Length(LCH1Hash));
            Move(LCH1Hash[0], LMessageHash[4], Length(LCH1Hash));

            // Generate key pair for CH2 based on server's selected group
            if LServerHello.KeyShareGroup = TLS13_GROUP_SECP384R1 then
            begin
              if not TryP384ECDHEKeyPair(FP384PrivateKey, LP256PubKey, LP256Error) then
              begin
                FLastErrorCode := sslErrHandshake;
                FLastErrorString := 'P-384 key generation failed: ' + LP256Error;
                RecordError(FLastErrorCode, FLastErrorString);
                Exit;
              end;
            end
            else
            begin
              // Default: P-256
              SetLength(LP256PrivKey, 32);
              if not SecureRandomBytes(@LP256PrivKey[0], 32) then
              begin
                FLastErrorCode := sslErrHandshake;
                FLastErrorString := 'Failed to generate P-256 private key';
                RecordError(FLastErrorCode, FLastErrorString);
                Exit;
              end;
              if not TryP256ScalarMultBase(LP256PrivKey, LP256Point, LP256Error) then
              begin
                FLastErrorCode := sslErrHandshake;
                FLastErrorString := 'P-256 key generation failed: ' + LP256Error;
                RecordError(FLastErrorCode, FLastErrorString);
                Exit;
              end;
              SetLength(LP256PubKey, 65);
              LP256PubKey[0] := $04;
              Move(LP256Point.X[0], LP256PubKey[1], 32);
              Move(LP256Point.Y[0], LP256PubKey[33], 32);
              FP256PrivateKey := LP256PrivKey;
            end;

            // Build CH2 by patching CH1's key_share extension (RFC 8446 §4.1.2)
            LCH2Handshake := PatchClientHelloKeyShare(
              LClientHelloHandshake, LP256PubKey, LServerHello.KeyShareGroup);

            // If server sent cookie in HRR, add it to CH2 (RFC 8446 §4.2.2)
            if LServerHello.HasCookie and (Length(LServerHello.Cookie) > 0) then
            begin
              // Append cookie extension to CH2's extension list
              SetLength(LCookieExt, 4 + Length(LServerHello.Cookie));
              LCookieExt[0] := $00; LCookieExt[1] := $2C; // extension type = cookie
              LCookieExt[2] := Byte(Length(LServerHello.Cookie) shr 8);
              LCookieExt[3] := Byte(Length(LServerHello.Cookie));
              Move(LServerHello.Cookie[0], LCookieExt[4], Length(LServerHello.Cookie));

              // Insert before end of extensions
              SetLength(LCH2Handshake, Length(LCH2Handshake) + Length(LCookieExt));
              // Append at end (before any PSK binder which we don't have)
              Move(LCookieExt[0], LCH2Handshake[Length(LCH2Handshake) - Length(LCookieExt)], Length(LCookieExt));

              // Update extensions_length and handshake_length
              // Find extensions_length position (same scan as PatchClientHelloKeyShare)
              I := 38; // skip header(4) + version(2) + random(32)
              I := I + 1 + LCH2Handshake[I]; // skip session_id
              I := I + 2 + ((Integer(LCH2Handshake[I]) shl 8) or Integer(LCH2Handshake[I+1])); // skip ciphers
              I := I + 1 + LCH2Handshake[I]; // skip compression
              // I now points to extensions_length
              LExtListLen := ((Integer(LCH2Handshake[I]) shl 8) or Integer(LCH2Handshake[I+1])) + Length(LCookieExt);
              LCH2Handshake[I] := Byte(LExtListLen shr 8);
              LCH2Handshake[I+1] := Byte(LExtListLen);
              // Update handshake length
              LPos := Length(LCH2Handshake) - 4;
              LCH2Handshake[1] := Byte(LPos shr 16);
              LCH2Handshake[2] := Byte(LPos shr 8);
              LCH2Handshake[3] := Byte(LPos);
            end;

            LCH2Record := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LCH2Handshake);
            if not SendAll(LCH2Record) then
            begin
              FLastErrorCode := sslErrIO;
              FLastErrorString := 'Failed to send ClientHello2 after HRR';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;

            // Update transcript: message_hash + HRR + CH2
            SetLength(LHRRTranscript, Length(LMessageHash) + Length(LHandshake) + Length(LCH2Handshake));
            Move(LMessageHash[0], LHRRTranscript[0], Length(LMessageHash));
            Move(LHandshake[0], LHRRTranscript[Length(LMessageHash)], Length(LHandshake));
            Move(LCH2Handshake[0], LHRRTranscript[Length(LMessageHash) + Length(LHandshake)], Length(LCH2Handshake));

            // Replace ClientHello for transcript
            LClientHelloHandshake := LCH2Handshake;
            LHasHelloRetryRequest := True;

            // Continue to read the real ServerHello
            Continue;
          end;

          if (LServerHello.KeyShareGroup <> TLS13_GROUP_X25519) and
             (LServerHello.KeyShareGroup <> TLS13_GROUP_SECP256R1) and
             (LServerHello.KeyShareGroup <> TLS13_GROUP_SECP384R1) then
          begin
            FLastErrorCode := sslErrUnsupported;
            FLastErrorString := Format('Unsupported key_share group: 0x%s', [IntToHex(LServerHello.KeyShareGroup, 4)]);
            RecordError(FLastErrorCode, FLastErrorString);
            Exit;
          end;

          if LServerHello.KeyShareGroup = TLS13_GROUP_X25519 then
          begin
            if Length(LServerHello.PeerKeyShare) <> 32 then
            begin
              FLastErrorCode := sslErrProtocol;
              FLastErrorString := 'Invalid X25519 key_share length from server';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
            try
              FHandshakeSharedSecret := X25519ComputeSharedSecret(FX25519PrivateKey, LServerHello.PeerKeyShare);
            except
              on E: Exception do
              begin
                FLastErrorCode := sslErrHandshake;
                FLastErrorString := 'Failed to compute X25519 shared secret: ' + E.Message;
                RecordError(FLastErrorCode, FLastErrorString);
                Exit;
              end;
            end;
          end
          else if LServerHello.KeyShareGroup = TLS13_GROUP_SECP256R1 then
          begin
            if Length(LServerHello.PeerKeyShare) <> 65 then
            begin
              FLastErrorCode := sslErrProtocol;
              FLastErrorString := 'Invalid P-256 key_share length from server';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
            if Length(FP256PrivateKey) = 0 then
            begin
              FLastErrorCode := sslErrHandshake;
              FLastErrorString := 'P-256 private key not available (HRR flow required)';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
            // Reject invalid-curve / off-curve server points before scalar mult.
            if not TryParseP256PublicPoint(LServerHello.PeerKeyShare, LP256Peer, LP256Err) then
            begin
              FLastErrorCode := sslErrHandshake;
              FLastErrorString := 'P-256 server key_share rejected: ' + LP256Err;
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
            if not TryP256ScalarMult(FP256PrivateKey, LP256Peer, LP256Shared, LP256Err) then
            begin
              FLastErrorCode := sslErrHandshake;
              FLastErrorString := 'P-256 ECDHE failed: ' + LP256Err;
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
            if not TryToFixedLength32(LP256Shared.X, FHandshakeSharedSecret, LP256Err) then
            begin
              FLastErrorCode := sslErrHandshake;
              FLastErrorString := 'P-256 shared secret normalization failed: ' + LP256Err;
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
          end
          else // P-384
          begin
            if Length(LServerHello.PeerKeyShare) <> 97 then
            begin
              FLastErrorCode := sslErrProtocol;
              FLastErrorString := 'Invalid P-384 key_share length from server';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
            if Length(FP384PrivateKey) = 0 then
            begin
              FLastErrorCode := sslErrHandshake;
              FLastErrorString := 'P-384 private key not available';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
            if not TryP384ECDHE(FP384PrivateKey, LServerHello.PeerKeyShare, FHandshakeSharedSecret, LP256Err) then
            begin
              FLastErrorCode := sslErrHandshake;
              FLastErrorString := 'P-384 ECDHE failed: ' + LP256Err;
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
          end;

          if LHasHelloRetryRequest then
          begin
            // HRR transcript: message_hash(CH1) || HRR || CH2 || SH2
            SetLength(LTranscriptData, Length(LHRRTranscript) + Length(LHandshake));
            Move(LHRRTranscript[0], LTranscriptData[0], Length(LHRRTranscript));
            Move(LHandshake[0], LTranscriptData[Length(LHRRTranscript)], Length(LHandshake));
          end
          else
          begin
            SetLength(LTranscriptData, Length(LClientHelloHandshake) + Length(LHandshake));
            if Length(LClientHelloHandshake) > 0 then
              Move(LClientHelloHandshake[0], LTranscriptData[0], Length(LClientHelloHandshake));
            if Length(LHandshake) > 0 then
              Move(LHandshake[0], LTranscriptData[Length(LClientHelloHandshake)], Length(LHandshake));
          end;

          if LServerHello.HasPreSharedKey then
          begin
            if (not LUseConfiguredSession) or (LConfiguredResumption = nil) then
            begin
              FLastErrorCode := sslErrProtocol;
              FLastErrorString := 'Server selected pre_shared_key without a configured resumable session';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;

            if LServerHello.SelectedPSKIdentity <> 0 then
            begin
              FLastErrorCode := sslErrProtocol;
              FLastErrorString := 'Server selected unsupported PSK identity index';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;

            if not TLS13CipherSuitesShareHash(
              LServerHello.SelectedCipherSuite,
              LConfiguredResumption.GetCipherSuite
            ) then
            begin
              FLastErrorCode := sslErrProtocol;
              FLastErrorString := 'Server selected pre_shared_key with incompatible hash path';
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;

            if not TryDeriveTLS13HandshakeSecretsWithPSK(
              LServerHello.SelectedCipherSuite,
              FHandshakeSharedSecret,
              LTranscriptData,
              LConfiguredResumption.GetResumptionPSK,
              FHandshakeSecrets,
              LKeyScheduleError
            ) then
            begin
              FLastErrorCode := sslErrUnsupported;
              FLastErrorString := 'TLS 1.3 PSK key schedule derivation failed: ' + LKeyScheduleError;
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;

            FSessionReused := True;
            if (FConfiguredSession <> nil) and
              ((FConfiguredSession as TObject) is TFreePascalSession) then
              FSessionBoundServerName := (FConfiguredSession as TObject as TFreePascalSession).BoundServerName
            else
              FSessionBoundServerName := FServerName;
          end
          else
          begin
            if not TryDeriveTLS13HandshakeSecrets(
              LServerHello.SelectedCipherSuite,
              FHandshakeSharedSecret,
              LTranscriptData,
              FHandshakeSecrets,
              LKeyScheduleError
            ) then
            begin
              FLastErrorCode := sslErrUnsupported;
              FLastErrorString := 'TLS 1.3 key schedule derivation failed: ' + LKeyScheduleError;
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
          end;

          try
            FServerFinishedKey := TLS13FinishedKeyForCipherSuite(
              LServerHello.SelectedCipherSuite,
              FHandshakeSecrets.ServerHandshakeTrafficSecret
            );
            FClientFinishedKey := TLS13FinishedKeyForCipherSuite(
              LServerHello.SelectedCipherSuite,
              FHandshakeSecrets.ClientHandshakeTrafficSecret
            );
          except
            on E: Exception do
            begin
              FLastErrorCode := sslErrHandshake;
              FLastErrorString := 'TLS 1.3 finished-key derivation failed: ' + E.Message;
              RecordError(FLastErrorCode, FLastErrorString);
              Exit;
            end;
          end;

          FServerHandshakeSeq := 0;
          FClientHandshakeSeq := 0;

          if not ProcessEncryptedServerFlight(LServerHello.SelectedCipherSuite, LTranscriptData) then
            Exit;

          if not ValidateClientPeerCertificateTrust then
            Exit;

          if not ValidateClientPeerCertificateFlags then
            Exit;

          if not ValidateClientOCSPStapling then
            Exit;

          if not ValidateClientOnlineOCSP then
            Exit;

          if not ValidateClientCertificateTransparency then
            Exit;

          { Derive application secrets BEFORE SendClientFinished because
            RFC 8446 Section 7.1 requires Transcript-Hash(CH..SF) — the
            transcript must NOT include Client Finished. }
          if not TryDeriveTLS13ApplicationSecrets(
            LServerHello.SelectedCipherSuite,
            FHandshakeSecrets.HandshakeSecret,
            LTranscriptData,
            FApplicationSecrets,
            LKeyScheduleError
          ) then
          begin
            SetHandshakeError(sslErrUnsupported, 'TLS 1.3 application key schedule derivation failed: ' + LKeyScheduleError);
            Exit;
          end;

          if FClientCertRequested then
          begin
            if not SendClientCertificateAndVerify(LServerHello.SelectedCipherSuite, LTranscriptData) then
              Exit;
          end;

          if not SendClientFinished(LServerHello.SelectedCipherSuite, LTranscriptData) then
            Exit;

          { RFC 8446 Section 7.1: resumption_master_secret uses Hash(CH..CF) }
          FApplicationSecrets.ResumptionTranscriptHash := HashTLS13TranscriptForSuite(
            LServerHello.SelectedCipherSuite, LTranscriptData
          );

          FClientApplicationSeq := 0;
          FServerApplicationSeq := 0;
          SetLength(FApplicationReadBuffer, 0);
          SetLength(FPostHandshakeBuffer, 0);
          FSessionTicketCount := 0;
          InitTLS13NewSessionTicket(FLastSessionTicket);
          FIsServerMode := False;

          FProtocolVersion := sslProtocolTLS13;
          FCipherName := TLS13CipherSuiteToString(LServerHello.SelectedCipherSuite);
          if FSessionReused and (FConfiguredSession <> nil) then
            FCurrentSession := FConfiguredSession.Clone;
          if not DrainBufferedApplicationRecords then
            Exit;
          Result := True;
          Exit;
        end;
    end;
  end;

  FLastErrorCode := sslErrProtocol;
  FLastErrorString := 'ServerHello not received in expected handshake records';
  RecordError(FLastErrorCode, FLastErrorString);
end;

procedure TFreePascalConnection.MarkUnsupported(const AOperation: string);
begin
  FLastErrorCode := sslErrUnsupported;
  FLastErrorString := Format('%s is unsupported by FreePascal backend', [AOperation]);
  RecordError(FLastErrorCode, FLastErrorString);
end;

procedure TFreePascalConnection.MarkPrecondition(const AOperation: string);
begin
  FLastErrorCode := sslErrProtocol;
  FLastErrorString := Format('%s requires completed TLS handshake', [AOperation]);
  RecordError(FLastErrorCode, FLastErrorString);
end;

function TFreePascalConnection.SendClientEarlyDataRecord(ACipherSuite: Word): Boolean;
var
  LInnerPlaintext: TBytes;
  LNonce: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LError: string;
begin
  Result := False;

  if Length(FEarlyDataPayload) = 0 then
    Exit(True);

  if not FEarlyDataSecrets.Valid then
  begin
    SetHandshakeError(sslErrProtocol, 'Client early-data keys are not available');
    Exit;
  end;

  LInnerPlaintext := BuildTLS13InnerPlaintext(FEarlyDataPayload, TLS_CONTENT_TYPE_APPLICATION_DATA);

  try
    LNonce := BuildTLS13RecordNonce(FEarlyDataSecrets.ClientEarlyIV, FEarlyDataSeq);
  except
    on E: Exception do
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to build client early-data nonce: ' + E.Message);
      Exit;
    end;
  end;

  if not TryTLS13AEADEncrypt(
    ACipherSuite,
    FEarlyDataSecrets.ClientEarlyKey,
    LNonce,
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(ACipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
  begin
    SetHandshakeError(sslErrEncryptionFailed, 'Failed to encrypt client early-data record: ' + LError);
    Exit;
  end;

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  if not SendAll(LRecord) then
  begin
    SetHandshakeError(sslErrIO, 'Failed to send client early-data record');
    Exit;
  end;

  if not IncrementTLS13Sequence(FEarlyDataSeq) then
  begin
    SetHandshakeError(sslErrProtocol, 'Client early-data sequence overflow');
    Exit;
  end;

  Result := True;
end;

{$I nextpas.core.tls.freepascal.connection.tls12appdata.inc}

function TFreePascalConnection.TLS12ServerSessionLookup(const ASessionID: TBytes;
  out AMasterSecret: TBytes; out ACipherSuite: Word): Boolean;
var
  LCache: IFreePascalResumptionCache;
  LSession: ISSLSession;
  LTLS12: IFreePascalTLS12ResumptionSession;
begin
  Result := False;
  SetLength(AMasterSecret, 0);
  ACipherSuite := 0;
  if not Supports(FContext, IFreePascalResumptionCache, LCache) then
    Exit;
  if not LCache.TryGetResumptionSession(ASessionID, LSession) then
    Exit;
  if (LSession = nil) or (LSession.GetProtocolVersion <> sslProtocolTLS12) then
    Exit;
  if not Supports(LSession, IFreePascalTLS12ResumptionSession, LTLS12) then
    Exit;
  AMasterSecret := LTLS12.GetTLS12MasterSecret;
  ACipherSuite := LTLS12.GetTLS12CipherSuite;
  Result := (Length(AMasterSecret) > 0) and (ACipherSuite <> 0);
end;

function TryP256ECDHEServerKeyExchange(
  const APeerPublicKey: TBytes;
  out AServerPublicKey: TBytes;
  out ASharedSecret: TBytes;
  out AError: string
): Boolean;
var
  LPrivateKey: TBytes;
  LPubPoint, LPeerPoint, LSharedPoint: TECPoint;
  LPubX, LPubY, LSharedX: TBytes;
begin
  Result := False;
  AError := '';
  SetLength(ASharedSecret, 0);

  // Reject invalid-curve / off-curve peer points before any scalar mult.
  if not TryParseP256PublicPoint(APeerPublicKey, LPeerPoint, AError) then
    Exit;

  LPrivateKey := GenerateSecureRandomBytes(32);
  try
    if not TryP256ScalarMultBase(LPrivateKey, LPubPoint, AError) then Exit;
    if not TryToFixedLength32(LPubPoint.X, LPubX, AError) then Exit;
    if not TryToFixedLength32(LPubPoint.Y, LPubY, AError) then Exit;
    SetLength(AServerPublicKey, 65);
    AServerPublicKey[0] := $04;
    Move(LPubX[0], AServerPublicKey[1], 32);
    Move(LPubY[0], AServerPublicKey[33], 32);

    if not TryP256ScalarMult(LPrivateKey, LPeerPoint, LSharedPoint, AError) then Exit;
    if LSharedPoint.IsInfinity then
    begin
      AError := 'P-256 ECDHE produced point at infinity';
      Exit;
    end;
    if not TryToFixedLength32(LSharedPoint.X, LSharedX, AError) then Exit;
    ASharedSecret := LSharedX;
    Result := True;
  finally
    SecureZeroBytes(LPrivateKey);
  end;
end;

function TryP384ECDHEServerKeyExchange(
  const APeerPublicKey: TBytes;
  out AServerPublicKey: TBytes;
  out ASharedSecret: TBytes;
  out AError: string
): Boolean;
var
  LPrivateKey, LPubKey: TBytes;
begin
  Result := False;
  AError := '';
  if not TryP384ECDHEKeyPair(LPrivateKey, LPubKey, AError) then Exit;
  SetLength(AServerPublicKey, Length(LPubKey));
  Move(LPubKey[0], AServerPublicKey[0], Length(LPubKey));
  if not TryP384ECDHE(LPrivateKey, APeerPublicKey, ASharedSecret, AError) then
  begin
    SecureZeroBytes(LPrivateKey);
    Exit;
  end;
  SecureZeroBytes(LPrivateKey);
  Result := True;
end;

function TFreePascalConnection.DoAcceptTLS12Fallback(const AClientHelloRecord: TBytes): Boolean;
var
  LConfig: TTLS12ServerConfig;
  LState: TTLS12ServerState;
  LError: string;
  LContextMaterial: IFreePascalContextMaterial;
  LContextCipherSuites: IFreePascalContextCipherSuites;
  LResumptionCache: IFreePascalResumptionCache;
  LSocketStream: THandleStream;
  LPrefixStream: TMemoryStream;
  LCombined: TStream;
  LSuiteInfo: TTLS12CipherSuiteInfo;
  LNewSession: TFreePascalSession;
  LPrefixBuf: TBytes;
  LPrefixPos: Integer;
begin
  Result := False;

  if not Supports(FContext, IFreePascalContextMaterial, LContextMaterial) then
  begin
    SetHandshakeError(sslErrHandshake, 'TLS 1.2 server: no certificate material configured');
    Exit;
  end;

  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.CertificateDER := LContextMaterial.GetCertificateMaterial;
  LConfig.PrivateKeyDER := LContextMaterial.GetPrivateKeyMaterial;
  LConfig.SupportEMS := True;
  LConfig.ServerName := FServerName;
  LConfig.SessionCacheEnabled := (FContext.GetSessionCacheMode);
  if LConfig.SessionCacheEnabled then
    LConfig.SessionLookup := @TLS12ServerSessionLookup
  else
    LConfig.SessionLookup := nil;
  if Supports(FContext, IFreePascalContextCipherSuites, LContextCipherSuites) then
    LConfig.CipherSuites := CopyCipherSuitesToTLS12(
      LContextCipherSuites.GetConfiguredCipherSuites12
    )
  else
    SetLength(LConfig.CipherSuites, 0);
  LConfig.Certificate := TX509Certificate.Create;
  try
    LConfig.Certificate.LoadFromDER(LConfig.CertificateDER);
  except
  end;

  LSocketStream := THandleStream.Create(FSocket);
  try
    // Prepend already-read ClientHello record, then read rest from socket
    LPrefixStream := TMemoryStream.Create;
    try
      LPrefixStream.Write(AClientHelloRecord[0], Length(AClientHelloRecord));
      LPrefixStream.Position := 0;

      // Use a two-phase approach: first read from prefix, then from socket
      // TLS12ServerHandshake uses TLS12ReadRecord which calls AStream.Read
      // We create a combined stream that reads prefix first, then socket
      LCombined := TConcatStream.Create(LPrefixStream, LSocketStream);
      try
        if not TryTLS12ServerHandshake(LCombined, LConfig, LState, LError) then
        begin
          SetHandshakeError(sslErrHandshake, 'TLS 1.2 server handshake failed: ' + LError);
          Exit;
        end;

        FTLS12State.ClientWriteKey := LState.ClientWriteKey;
        FTLS12State.ServerWriteKey := LState.ServerWriteKey;
        FTLS12State.ClientWriteIV := LState.ClientWriteIV;
        FTLS12State.ServerWriteIV := LState.ServerWriteIV;
        FTLS12State.CipherSuite := LState.CipherSuite;
        FTLS12State.ClientSeqNum := 0;
        FTLS12State.ServerSeqNum := 0;
        FTLS12State.MasterSecret := LState.MasterSecret;
        FProtocolVersion := sslProtocolTLS12;
        FIsServerMode := True;
        FSelectedALPNProtocol := LState.ALPNProtocol;
        if TLS12GetCipherSuiteInfo(LState.CipherSuite, LSuiteInfo) then
          FCipherName := LSuiteInfo.Name
        else
          FCipherName := Format('TLS12_0x%s', [IntToHex(LState.CipherSuite, 4)]);
        if FStream = nil then
        begin
          FStream := THandleStream.Create(FSocket);
          FOwnsStream := True;
        end;

        if (Length(LState.SessionID) > 0) and (not LState.Resumed) then
        begin
          LNewSession := TFreePascalSession.Create;
          LNewSession.ConfigureTLS12Resumption(
            LState.CipherSuite, FCipherName,
            LState.SessionID, LState.MasterSecret,
            Now, SSL_DEFAULT_SESSION_TIMEOUT);
          LNewSession.BoundServerName := FServerName;
          FCurrentSession := LNewSession;
          if Supports(FContext, IFreePascalResumptionCache, LResumptionCache) then
            LResumptionCache.StoreResumptionSession(LNewSession);
        end;

        Result := True;
      finally
        LCombined.Free;
      end;
    finally
      LPrefixStream.Free;
    end;
  finally
    LSocketStream.Free;
    LConfig.Certificate.Free;
    SecureZeroBytes(LConfig.PrivateKeyDER);
  end;
end;

function TFreePascalConnection.DoConnectTLS12Fallback(const AServerHelloRecord: TBytes; const AClientHelloHandshake: TBytes): Boolean;
var
  LState: TTLS12ClientState;
  LError: string;
  LClientRandom: TBytes;
  LSocketStream: THandleStream;
  LSuiteInfo: TTLS12CipherSuiteInfo;
  LPrefixStream: TMemoryStream;
  LCombined: TStream;
  LNewSession: TFreePascalSession;
begin
  Result := False;

  if Length(AClientHelloHandshake) < 38 then
  begin
    SetHandshakeError(sslErrProtocol, 'ClientHello too short for TLS 1.2 fallback');
    Exit;
  end;

  // Extract ClientRandom from the TLS 1.3 ClientHello handshake (offset 6, 32 bytes)
  LClientRandom := Copy(AClientHelloHandshake, 6, 32);

  LSocketStream := THandleStream.Create(FSocket);
  try
    LPrefixStream := TMemoryStream.Create;
    try
      LPrefixStream.Write(AServerHelloRecord[0], Length(AServerHelloRecord));
      LPrefixStream.Position := 0;

      LCombined := TConcatStream.Create(LPrefixStream, LSocketStream);
      try
        if not TryTLS12ClientHandshakeFromFallback(
          LCombined,
          AClientHelloHandshake,
          LClientRandom,
          FServerName,
          LState,
          LError
        ) then
        begin
          SetHandshakeError(sslErrHandshake, 'TLS 1.2 fallback handshake failed: ' + LError);
          Exit;
        end;

        FTLS12State.ClientWriteKey := LState.ClientWriteKey;
        FTLS12State.ServerWriteKey := LState.ServerWriteKey;
        FTLS12State.ClientWriteIV := LState.ClientWriteIV;
        FTLS12State.ServerWriteIV := LState.ServerWriteIV;
        FTLS12State.CipherSuite := LState.CipherSuite;
        FTLS12State.ClientSeqNum := LState.ClientSeqNum;
        FTLS12State.ServerSeqNum := LState.ServerSeqNum;
        FTLS12State.MasterSecret := LState.MasterSecret;
        FProtocolVersion := sslProtocolTLS12;
        FIsServerMode := False;
        FSelectedALPNProtocol := LState.ALPNProtocol;
        FreeAndNil(LState.PeerCertificate);
        LState.PeerCertificatesDER := nil;
        if TLS12GetCipherSuiteInfo(LState.CipherSuite, LSuiteInfo) then
          FCipherName := LSuiteInfo.Name
        else
          FCipherName := Format('TLS12_0x%s', [IntToHex(LState.CipherSuite, 4)]);
        FStream := THandleStream.Create(FSocket);
        FOwnsStream := True;

        if LState.Resumed then
          FSessionReused := True;

        if Length(LState.SessionID) > 0 then
        begin
          LNewSession := TFreePascalSession.Create;
          LNewSession.ConfigureTLS12Resumption(
            LState.CipherSuite, FCipherName,
            LState.SessionID, LState.MasterSecret,
            Now, SSL_DEFAULT_SESSION_TIMEOUT);
          LNewSession.BoundServerName := FServerName;
          FCurrentSession := LNewSession;
        end;

        Result := True;
      finally
        LCombined.Free;
      end;
    finally
      LPrefixStream.Free;
    end;
  finally
    LSocketStream.Free;
  end;
end;

function TFreePascalConnection.DoConnect: Boolean;
var
  LError: string;
  LProtos: array of string;
  LProtoList: TStringArray;
  LCertificate: ISSLCertificate;
  LContextCipherSuites: IFreePascalContextCipherSuites;
  LConfiguredCipherSuites12: TTLS12CipherSuiteList;
  LSuiteInfo: TTLS12CipherSuiteInfo;
  LTLS12ResumeSession: IFreePascalTLS12ResumptionSession;
  LCachedSession: TTLS12SessionCache;
  LHandshakeOk: Boolean;
  LNewSession: TFreePascalSession;
  I: Integer;
begin
  Result := False;
  ClearPeerCertificateCache;

  if (FStream = nil) and (FSocket < 0) then
  begin
    FLastErrorCode := sslErrInvalidParam;
    FLastErrorString := 'No transport available for TLS connection';
    RecordError(FLastErrorCode, FLastErrorString);
    Exit;
  end;

  if FProtocolVersion = sslProtocolTLS12 then
  begin
    if FStream = nil then
    begin
      if FSocket < 0 then
      begin
        MarkUnsupported('TLS 1.2 requires transport (socket or stream)');
        Exit;
      end;
      FStream := THandleStream.Create(FSocket);
      FOwnsStream := True;
    end;

    if Trim(FALPNProtocols) <> '' then
    begin
      LProtoList := FALPNProtocols.Split([',']);
      SetLength(LProtos, 0);
      for I := 0 to High(LProtoList) do
        if Trim(LProtoList[I]) <> '' then
        begin
          SetLength(LProtos, Length(LProtos) + 1);
          LProtos[High(LProtos)] := Trim(LProtoList[I]);
        end;
    end
    else
      SetLength(LProtos, 0);

    if Supports(FContext, IFreePascalContextCipherSuites, LContextCipherSuites) then
      LConfiguredCipherSuites12 := CopyCipherSuitesToTLS12(
        LContextCipherSuites.GetConfiguredCipherSuites12
      )
    else
      SetLength(LConfiguredCipherSuites12, 0);

    if (FConfiguredSession <> nil) and
       (FConfiguredSession.GetProtocolVersion = sslProtocolTLS12) and
       Supports(FConfiguredSession, IFreePascalTLS12ResumptionSession, LTLS12ResumeSession) then
    begin
      LCachedSession.SessionID := LTLS12ResumeSession.GetTLS12SessionID;
      LCachedSession.MasterSecret := LTLS12ResumeSession.GetTLS12MasterSecret;
      LCachedSession.CipherSuite := LTLS12ResumeSession.GetTLS12CipherSuite;
      LCachedSession.ServerName := FServerName;

      if Length(LConfiguredCipherSuites12) > 0 then
        LHandshakeOk := TryTLS12ClientHandshakeWithResume(
          FStream, FServerName, LProtos, LConfiguredCipherSuites12,
          LCachedSession, FTLS12State, LError)
      else
        LHandshakeOk := TryTLS12ClientHandshakeWithResume(
          FStream, FServerName, LProtos,
          LCachedSession, FTLS12State, LError);
    end
    else
    begin
      LHandshakeOk := TryTLS12ClientHandshake(
        FStream, FServerName, LProtos, LConfiguredCipherSuites12,
        FTLS12State, LError);
    end;

    if not LHandshakeOk then
    begin
      FLastErrorCode := sslErrConnection;
      FLastErrorString := 'TLS 1.2 handshake failed: ' + LError;
      RecordError(FLastErrorCode, FLastErrorString);
      Exit;
    end;

    if FTLS12State.Resumed then
      FSessionReused := True;

    // Load peer certificate chain for verification
    SetLength(FPeerCertificateChain, Length(FTLS12State.PeerCertificatesDER));
    for I := 0 to High(FTLS12State.PeerCertificatesDER) do
    begin
      LCertificate := TSSLFactory.CreateCertificate(sslFreePascal);
      if (LCertificate = nil) or not LCertificate.LoadFromDER(FTLS12State.PeerCertificatesDER[I]) then
      begin
        FLastErrorCode := sslErrCertificate;
        FLastErrorString := Format('Failed to load peer certificate #%d', [I + 1]);
        RecordError(FLastErrorCode, FLastErrorString);
        ClearPeerCertificateCache;
        Exit;
      end;
      FPeerCertificateChain[I] := LCertificate;
    end;

    for I := 0 to High(FPeerCertificateChain) do
    begin
      if I < High(FPeerCertificateChain) then
        FPeerCertificateChain[I].SetIssuerCertificate(FPeerCertificateChain[I + 1])
      else
        FPeerCertificateChain[I].SetIssuerCertificate(nil);
    end;

    if Length(FPeerCertificateChain) > 0 then
      FPeerCertificate := FPeerCertificateChain[0];

    if not ValidateClientPeerCertificateTrust then
      Exit;
    if not ValidateClientPeerCertificateFlags then
      Exit;

    FSelectedALPNProtocol := FTLS12State.ALPNProtocol;
    FreeAndNil(FTLS12State.PeerCertificate);
    FTLS12State.PeerCertificatesDER := nil;
    if TLS12GetCipherSuiteInfo(FTLS12State.CipherSuite, LSuiteInfo) then
      FCipherName := LSuiteInfo.Name
    else
      FCipherName := Format('TLS12_0x%s', [IntToHex(FTLS12State.CipherSuite, 4)]);

    // Create session for future resumption
    if Length(FTLS12State.SessionID) > 0 then
    begin
      LNewSession := TFreePascalSession.Create;
      LNewSession.ConfigureTLS12Resumption(
        FTLS12State.CipherSuite, FCipherName,
        FTLS12State.SessionID, FTLS12State.MasterSecret,
        Now, SSL_DEFAULT_SESSION_TIMEOUT);
      LNewSession.BoundServerName := FServerName;
      FCurrentSession := LNewSession;
    end;

    Result := True;
    Exit;
  end;

  if FProtocolVersion <> sslProtocolTLS13 then
  begin
    MarkUnsupported('TLS 1.3-only handshake path (set PreferredVersion=TLS13)');
    Exit;
  end;

  if not ProbeServerHello then
  begin
    if FLastErrorCode = sslErrNone then
      MarkUnsupported('TLS 1.3 ServerHello negotiation');
    Exit;
  end;

  Result := True;
end;

{$I nextpas.core.tls.freepascal.connection.tls13server.inc}

function TFreePascalConnection.DoHandshakeInternal: TSSLHandshakeState;
begin
  if (FContext <> nil) and (FContext.GetContextType = sslCtxServer) then
  begin
    if DoAccept then
      Result := sslHsCompleted
    else
      Result := sslHsFailed;
  end
  else
  begin
    if DoConnect then
      Result := sslHsCompleted
    else
      Result := sslHsFailed;
  end;
end;

function TFreePascalConnection.DoShutdown: Boolean;
var
  LAlertPayload: TBytes;
  LInnerPlaintext: TBytes;
  LAAD: TBytes;
  LNonce: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LError: string;
  LHeader: TBytes;
begin
  Result := True;

  if FProtocolVersion = sslProtocolTLS12 then
  begin
    SetLength(LAlertPayload, 2);
    LAlertPayload[0] := 1; // warning level
    LAlertPayload[1] := 0; // close_notify

    if not SendTLS12ProtectedRecord(TLS12_CONTENT_ALERT, LAlertPayload) then
      Exit;
    Exit;
  end;

  if not FApplicationSecrets.Valid then
    Exit;

  if not TLS13AEADIsSupported(FApplicationSecrets.CipherSuite) then
    Exit;

  SetLength(LAlertPayload, 2);
  LAlertPayload[0] := 1; // warning level
  LAlertPayload[1] := 0; // close_notify

  LInnerPlaintext := BuildTLS13InnerPlaintext(LAlertPayload, TLS_CONTENT_TYPE_ALERT);

  try
    if FIsServerMode then
      LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, FServerApplicationSeq)
    else
      LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ClientApplicationIV, FClientApplicationSeq);
  except
    Exit;
  end;

  LAAD := BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FApplicationSecrets.CipherSuite)));

  if FIsServerMode then
  begin
    if not TryTLS13AEADEncrypt(
      FApplicationSecrets.CipherSuite,
      FApplicationSecrets.ServerApplicationKey,
      LNonce, LAAD, LInnerPlaintext, LEncrypted, LError) then
      Exit;
    IncrementTLS13Sequence(FServerApplicationSeq);
  end
  else
  begin
    if not TryTLS13AEADEncrypt(
      FApplicationSecrets.CipherSuite,
      FApplicationSecrets.ClientApplicationKey,
      LNonce, LAAD, LInnerPlaintext, LEncrypted, LError) then
      Exit;
    IncrementTLS13Sequence(FClientApplicationSeq);
  end;

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  SendAll(LRecord);
end;

procedure TFreePascalConnection.DoClose;
begin
  ClearPeerCertificateCache;
  SecureZeroBytes(FX25519PrivateKey);
  SecureZeroBytes(FX25519PublicKey);
  SecureZeroBytes(FP256PrivateKey);
  SecureZeroBytes(FP384PrivateKey);
  SecureZeroBytes(FHandshakeSharedSecret);
  ClearTLS13EarlyDataSecrets(FEarlyDataSecrets);
  ClearTLS13HandshakeSecrets(FHandshakeSecrets);
  SecureZeroBytes(FServerFinishedKey);
  SecureZeroBytes(FClientFinishedKey);
  FEarlyDataSeq := 0;
  FServerHandshakeSeq := 0;
  FClientHandshakeSeq := 0;

  ClearTLS13ApplicationSecrets(FApplicationSecrets);
  FClientApplicationSeq := 0;
  FServerApplicationSeq := 0;
  SecureZeroBytes(FApplicationReadBuffer);
  SecureZeroBytes(FPostHandshakeBuffer);
  FSessionTicketCount := 0;
  InitTLS13NewSessionTicket(FLastSessionTicket);
  FIsServerMode := False;
  FEarlyDataStatus := sslEarlyDataNone;
  FEarlyDataLimit := 0;
  SecureZeroBytes(FEarlyDataPayload);
  SecureZeroBytes(FTLS12ReadBuffer);
  SecureZeroBytes(FTLS12State.ClientWriteKey);
  SecureZeroBytes(FTLS12State.ServerWriteKey);
  SecureZeroBytes(FTLS12State.ClientWriteIV);
  SecureZeroBytes(FTLS12State.ServerWriteIV);
  SecureZeroBytes(FTLS12State.ClientWriteMACKey);
  SecureZeroBytes(FTLS12State.ServerWriteMACKey);
  SecureZeroBytes(FTLS12State.MasterSecret);
  FTLS12State.ClientSeqNum := 0;
  FTLS12State.ServerSeqNum := 0;
end;

function TFreePascalConnection.DoRenegotiate: Boolean;
begin
  if not FHandshakeComplete then
  begin
    MarkPrecondition('TLS renegotiate/key update');
    Exit(False);
  end;

  if FProtocolVersion = sslProtocolTLS12 then
    Exit(DoRenegotiateTLS12);

  if FProtocolVersion <> sslProtocolTLS13 then
  begin
    MarkUnsupported('Renegotiate/KeyUpdate on non-TLS1.3 connection');
    Exit(False);
  end;

  Result := SendPostHandshakeKeyUpdate(True);
end;

function TFreePascalConnection.DoGetError(ARet: Integer): TSSLErrorCode;
begin
  if ARet >= 0 then
    Exit(sslErrNone);

  if FLastErrorCode = sslErrNone then
    Result := sslErrGeneral
  else
    Result := FLastErrorCode;
end;

function TFreePascalConnection.DoWantRead: Boolean;
begin
  Result := False;
end;

function TFreePascalConnection.DoWantWrite: Boolean;
begin
  Result := False;
end;

function TFreePascalConnection.DoGetProtocolVersion: TSSLProtocolVersion;
begin
  Result := FProtocolVersion;
end;

function TFreePascalConnection.DoGetCipherName: string;
begin
  Result := FCipherName;
end;

function TFreePascalConnection.DoGetPeerCertificate: ISSLCertificate;
begin
  if FPeerCertificate <> nil then
    Result := FPeerCertificate.Clone
  else
    Result := nil;
end;

function TFreePascalConnection.DoGetPeerCertificateChain: TSSLCertificateArray;
begin
  Result := CloneCertificateArray(FPeerCertificateChain);
end;

function TFreePascalConnection.DoGetVerifyResult: Integer;
begin
  if FLastErrorCode <> sslErrNone then
    Exit(Ord(FLastErrorCode));

  if not FHandshakeComplete then
    Exit(-1);

  Result := 0;
end;

function TFreePascalConnection.DoGetVerifyResultString: string;
begin
  if FLastErrorString <> '' then
    Exit(FLastErrorString);

  if not FHandshakeComplete then
    Exit('Not verified');

  Result := 'OK';
end;

function TFreePascalConnection.DoGetSession: ISSLSession;
begin
  Result := FCurrentSession;
end;

procedure TFreePascalConnection.DoSetSession(ASession: ISSLSession);
var
  LResumptionSession: IFreePascalResumptionSession;
  LTLS12Session: IFreePascalTLS12ResumptionSession;
begin
  FConfiguredSession := nil;
  FSessionReused := False;
  FEarlyDataStatus := sslEarlyDataNone;
  FEarlyDataLimit := 0;
  SetLength(FEarlyDataPayload, 0);
  ClearTLS13EarlyDataSecrets(FEarlyDataSecrets);
  FEarlyDataSeq := 0;

  if (ASession = nil) or (not ASession.IsValid) or (not ASession.IsResumable) then
    Exit;

  if Supports(ASession, IFreePascalTLS12ResumptionSession, LTLS12Session) and
     (ASession.GetProtocolVersion = sslProtocolTLS12) then
  begin
    FConfiguredSession := ASession.Clone;
    Exit;
  end;

  if not Supports(ASession, IFreePascalResumptionSession, LResumptionSession) then
    Exit;

  FConfiguredSession := ASession.Clone;
  FEarlyDataLimit := LResumptionSession.GetMaxEarlyDataSize;
end;

function TFreePascalConnection.DoIsSessionReused: Boolean;
begin
  Result := FSessionReused;
end;

function TFreePascalConnection.DoGetConnectionInfoServerName: string;
begin
  Result := FServerName;
end;

function TFreePascalConnection.DoGetSelectedALPNProtocol: string;
begin
  Result := FSelectedALPNProtocol;
end;

function TFreePascalConnection.DoGetState: string;
begin
  if FHandshakeComplete then
    Result := 'CONNECTED'
  else if FCipherName <> '' then
    Result := 'SERVER_HELLO_NEGOTIATED'
  else if FConnected then
    Result := 'CONNECTING'
  else
    Result := 'DISCONNECTED';
end;

function TFreePascalConnection.DoGetNativeHandle: Pointer;
begin
  Result := nil;
end;

function TFreePascalConnection.DoGetOCSPStaplingEnabled: Boolean;
begin
  Result := Length(FOCSPResponse) > 0;
end;

function TFreePascalConnection.DoGetOCSPResponse: TBytes;
begin
  Result := Copy(FOCSPResponse);
end;

function TFreePascalConnection.DoIsOCSPResponseVerified: Boolean;
begin
  Result := FOCSPResponseVerified;
end;

function TFreePascalConnection.DoGetOCSPResponseStatus: string;
begin
  Result := FOCSPResponseStatus;
end;

function TFreePascalConnection.DoGetCertificateTransparencyEnabled: Boolean;
begin
  Result := Length(FSignedCertificateTimestampList) > 0;
end;

function TFreePascalConnection.DoGetSignedCertificateTimestampList: TBytes;
begin
  Result := Copy(FSignedCertificateTimestampList);
end;

function TFreePascalConnection.DoGetSignedCertificateTimestampCount: Integer;
begin
  Result := FSignedCertificateTimestampCount;
end;

function TFreePascalConnection.DoGetCertificateTransparencyStatus: string;
begin
  Result := FCertificateTransparencyStatus;
end;

function TFreePascalConnection.DoHasCertificateTransparencyValidationResult: Boolean;
begin
  Result := FHasCertificateTransparencyValidationResult;
end;

function TFreePascalConnection.DoIsCertificateTransparencyPolicySatisfied: Boolean;
begin
  Result := FCertificateTransparencyPolicySatisfied;
end;

function TFreePascalConnection.DoGetCertificateTransparencyValidationStatus: string;
begin
  Result := FCertificateTransparencyValidationStatus;
end;

procedure TFreePascalConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TFreePascalConnection.GetServerName: string;
begin
  Result := FServerName;
end;

function TFreePascalConnection.SetEarlyData(const AData: TBytes): TSSLOperationResult;
var
  LEarlyDataContext: ISSLEarlyDataContext;
  LResumptionSession: IFreePascalResumptionSession;
begin
  if (FContext = nil) or
    (not ContextTypeSupportsClientConnectionRole(FContext.GetContextType)) then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Early data is only available on client connections'));

  if not Supports(FContext, ISSLEarlyDataContext, LEarlyDataContext) then
    Exit(TSSLOperationResult.Err(sslErrUnsupported, 'Context does not expose early-data interface'));

  if not LEarlyDataContext.GetClientEarlyDataEnabled then
    Exit(TSSLOperationResult.Err(sslErrConfiguration, 'Client early data is disabled on the context'));

  if (FConfiguredSession = nil) or
    (not Supports(FConfiguredSession, IFreePascalResumptionSession, LResumptionSession)) or
    (not FConfiguredSession.IsValid) or
    (not FConfiguredSession.IsResumable) then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Early data requires a configured resumable session'));

  FEarlyDataLimit := LResumptionSession.GetMaxEarlyDataSize;
  if FEarlyDataLimit = 0 then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Configured session does not allow early data'));

  if Cardinal(Length(AData)) > FEarlyDataLimit then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Early data payload exceeds max_early_data_size'));

  FEarlyDataPayload := Copy(AData, 0, Length(AData));
  if Length(FEarlyDataPayload) = 0 then
    FEarlyDataStatus := sslEarlyDataNone
  else
    FEarlyDataStatus := sslEarlyDataQueued;
  ClearTLS13EarlyDataSecrets(FEarlyDataSecrets);
  FEarlyDataSeq := 0;
  Result := TSSLOperationResult.Ok;
end;

function TFreePascalConnection.GetEarlyDataStatus: TSSLEarlyDataStatus;
begin
  Result := FEarlyDataStatus;
end;

function TFreePascalConnection.GetEarlyDataLimit: Cardinal;
begin
  Result := FEarlyDataLimit;
end;

end.
