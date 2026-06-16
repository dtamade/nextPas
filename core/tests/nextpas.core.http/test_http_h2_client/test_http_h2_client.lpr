program test_http_h2_client;

{$I nextpas.core.settings.inc}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.time.deadline,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.middleware,
  nextpas.core.http.message,
  nextpas.core.http.impl.h2.frame,
  nextpas.core.http.impl.h2.hpack,
  nextpas.core.http.impl.h2.types,
  nextpas.core.http.impl.h2.client,
  nextpas.core.http.impl.h2.tls,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.http.impl.registry,
  nextpas.core.testing,
  nextpas.core.tls.base,
  nextpas.core.tls.connection.base;

const
  H2_CLIENT_SOURCE_PATH_FROM_TEST =
    '../../../src/nextpas.core.http.impl.h2.client.pas';
  H2_CLIENT_SOURCE_PATH_FROM_ROOT =
    'core/src/nextpas.core.http.impl.h2.client.pas';

type
  TFakeTcpStream = class(TInterfacedObject, ITcpStream)
  private
    FReadData: AnsiString;
    FReadPos: SizeInt;
    FWrittenData: AnsiString;
    FClosed: Boolean;
    FLocalAddr: TNetAddress;
    FRemoteAddr: TNetAddress;
    FReadDeadline: TDeadline;
    FWriteDeadline: TDeadline;
    FMaxWriteChunk: SizeUInt;
  public
    constructor Create(const AReadData: AnsiString);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure AppendReadData(const AData: AnsiString);
    function WrittenData: AnsiString;
    property MaxWriteChunk: SizeUInt read FMaxWriteChunk write FMaxWriteChunk;
  end;

  IMockTLSProbe = interface
    ['{E71E35E7-5428-4C5B-8DFA-4D617274F6F1}']
    function GetObservedServerName: string;
    function GetObservedALPN: string;
    function GetSelectedALPN: string;
    function GetCallLog: string;
  end;

  TMockTLSConnection = class(TBaseSSLConnection, ISSLClientConnection,
    ISSLClientALPNConnection, IMockTLSProbe)
  private
    FTransport: TStream;
    FSelectedALPN: string;
    FObservedALPN: string;
    FServerName: string;
    FCallLog: string;
    procedure AppendCall(const AName: string);
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
    function DoGetSelectedALPNProtocol: string; override;
    function DoGetState: string; override;
    function DoGetNativeHandle: Pointer; override;
  public
    constructor Create(AContext: ISSLContext; ATransport: TStream;
      const ASelectedALPN: string); reintroduce;
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;
    procedure SetALPNProtocols(const AProtocols: string);
    function GetALPNProtocols: string;
    function GetObservedServerName: string;
    function GetObservedALPN: string;
    function GetSelectedALPN: string;
    function GetCallLog: string;
  end;

  TMockTLSContext = class(TInterfacedObject, ISSLContext)
  private
    FContextType: TSSLContextType;
    FSelectedALPN: string;
    FConfiguredALPN: string;
    FLastProbe: IMockTLSProbe;
  public
    constructor Create(AContextType: TSSLContextType;
      const ASelectedALPN: string);
    function GetLastProbe: IMockTLSProbe;
    procedure ClearLastProbe;
    function GetContextType: TSSLContextType;
    procedure SetProtocolVersions(AVersions: TSSLProtocolVersions);
    function GetProtocolVersions: TSSLProtocolVersions;
    procedure SetPreferredVersion(AVersion: TSSLProtocolVersion);
    function GetPreferredVersion: TSSLProtocolVersion;
    procedure LoadCertificate(const AFileName: string); overload;
    procedure LoadCertificate(AStream: TStream); overload;
    procedure LoadCertificate(ACert: ISSLCertificate); overload;
    procedure LoadPrivateKey(const AFileName: string;
      const APassword: string = ''); overload;
    procedure LoadPrivateKey(AStream: TStream;
      const APassword: string = ''); overload;
    procedure LoadCertificatePEM(const APEM: string);
    procedure LoadPrivateKeyPEM(const APEM: string;
      const APassword: string = '');
    procedure LoadCAFile(const AFileName: string);
    procedure LoadCAPath(const APath: string);
    procedure SetCertificateStore(AStore: ISSLCertificateStore);
    procedure SetVerifyMode(AMode: TSSLVerifyModes);
    function GetVerifyMode: TSSLVerifyModes;
    procedure SetVerifyDepth(ADepth: Integer);
    function GetVerifyDepth: Integer;
    procedure SetVerifyCallback(ACallback: TSSLVerifyCallback);
    procedure SetCipherList(const ACipherList: string);
    function GetCipherList: string;
    procedure SetCipherSuites(const ACipherSuites: string);
    function GetCipherSuites: string;
    procedure SetSessionCacheMode(AEnabled: Boolean);
    function GetSessionCacheMode: Boolean;
    procedure SetSessionTimeout(ATimeout: Integer);
    function GetSessionTimeout: Integer;
    procedure SetSessionCacheSize(ASize: Integer);
    function GetSessionCacheSize: Integer;
    procedure SetOptions(const AOptions: TSSLOptions);
    function GetOptions: TSSLOptions;
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;
    procedure SetALPNProtocols(const AProtocols: string);
    function GetALPNProtocols: string;
    procedure SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
    function GetCertVerifyFlags: TSSLCertVerifyFlags;
    procedure SetPasswordCallback(ACallback: TSSLPasswordCallback);
    procedure SetInfoCallback(ACallback: TSSLInfoCallback);
    procedure AddCertificatePin(const AHash: TBytes; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure AddCertificatePinBase64(const ABase64Hash: string;
      APinType: Integer; const ADescription: string;
      AIsBackup: Boolean = False);
    procedure SetCertificatePinningEnabled(AEnabled: Boolean);
    function GetCertificatePinningEnabled: Boolean;
    procedure ClearCertificatePins;
    function CreateConnection(ASocket: THandle): ISSLConnection; overload;
    function CreateConnection(AStream: TStream): ISSLConnection; overload;
    function IsValid: Boolean;
  end;

  TMockTlsServerTransport = class(TInterfacedObject, IHttpServerTransport)
  private
    FServeConnCalled: Boolean;
    FSeenALPN: string;
  public
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property SeenALPN: string read FSeenALPN;
  end;

var
  T: TTestRunner;
  GDialQueue: array of ITcpStream;
  GDialCount: SizeInt;
  GDialIndex: SizeInt;
  GLastDialHost: string;
  GLastDialPort: UInt16;
  GH2ClientSourceCache: string;

function TestDial(const AHost: string; const APort: UInt16): ITcpStream;
begin
  Check(GDialIndex < GDialCount, 'dial queue has connection');
  GLastDialHost := AHost;
  GLastDialPort := APort;
  Result := GDialQueue[GDialIndex];
  Inc(GDialIndex);
end;

procedure ResetDialQueue;
var
  LI: SizeInt;
begin
  for LI := 0 to GDialCount - 1 do
    GDialQueue[LI] := nil;
  GDialQueue := nil;
  GDialCount := 0;
  GDialIndex := 0;
  GLastDialHost := '';
  GLastDialPort := 0;
end;

procedure QueueDialConn(const AConn: ITcpStream);
begin
  if GDialCount >= Length(GDialQueue) then
    SetLength(GDialQueue, GDialCount + 4);
  GDialQueue[GDialCount] := AConn;
  Inc(GDialCount);
end;

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LLine + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function H2ClientSourceText: string;
begin
  if GH2ClientSourceCache = '' then
    GH2ClientSourceCache := ReadSourceFile(ResolveSourcePath(
      H2_CLIENT_SOURCE_PATH_FROM_TEST, H2_CLIENT_SOURCE_PATH_FROM_ROOT));
  Result := GH2ClientSourceCache;
end;

function ExtractSourceBlock(const AStartMarker, AEndMarker: string): string;
var
  LSource: string;
  LStartPos: SizeInt;
  LEndPos: SizeInt;
begin
  LSource := H2ClientSourceText;
  LStartPos := Pos(AStartMarker, LSource);
  Check(LStartPos > 0, AStartMarker + ' source block exists');
  LEndPos := Pos(AEndMarker, LSource);
  Check(LEndPos > LStartPos, AEndMarker + ' source follows ' + AStartMarker);
  if (LStartPos <= 0) or (LEndPos <= LStartPos) then
    Exit('');
  Result := Copy(LSource, LStartPos, LEndPos - LStartPos);
end;

function HexNibble(const ACh: Char): Byte;
begin
  case ACh of
    '0'..'9':
      Result := Ord(ACh) - Ord('0');
    'a'..'f':
      Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F':
      Result := Ord(ACh) - Ord('A') + 10;
  else
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): AnsiString;
var
  LI: SizeInt;
  LOut: SizeInt;
begin
  SetLength(Result, Length(AHex) div 2);
  LOut := 1;
  LI := 1;
  while LI < Length(AHex) do
  begin
    Result[LOut] := AnsiChar((HexNibble(AHex[LI]) shl 4) or
      HexNibble(AHex[LI + 1]));
    Inc(LOut);
    Inc(LI, 2);
  end;
end;

function PackHeader(const AName, AValue: AnsiString): THPackHeader;
begin
  Result.Name := AName;
  Result.Value := AValue;
end;

function EncodeHeaders(const AHeaders: array of THPackHeader): AnsiString;
var
  LEncoder: THPackEncoder;
begin
  LEncoder.Init;
  Result := LEncoder.Encode(AHeaders);
end;

function ComposeServerHandshake(const ASettingsPayload: AnsiString = ''): AnsiString;
begin
  Result := H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, ASettingsPayload);
end;

function ComposeSingleSettingPayload(const AIdentifier: UInt16;
  const AValue: UInt32): AnsiString;
var
  LEntries: TH2SettingEntries;
begin
  SetLength(LEntries, 1);
  LEntries[0].Identifier := AIdentifier;
  LEntries[0].Value := AValue;
  Result := H2EncodeSettingsPayload(LEntries);
end;

function ComposeResponseHeaders(const AStatus: string;
  const AExtraHeaders: array of THPackHeader): AnsiString;
var
  LHeaders: array of THPackHeader;
  LI: SizeInt;
begin
  SetLength(LHeaders, Length(AExtraHeaders) + 1);
  LHeaders[0].Name := ':status';
  LHeaders[0].Value := AnsiString(AStatus);
  for LI := 0 to High(AExtraHeaders) do
    LHeaders[LI + 1] := AExtraHeaders[LI];
  Result := EncodeHeaders(LHeaders);
end;

function ComposeResponse(const AStreamID: UInt32; const AStatus: string;
  const ABody: AnsiString; const AExtraHeaders: array of THPackHeader): AnsiString;
var
  LHeaderFlags: Byte;
begin
  LHeaderFlags := H2_FLAG_HEADERS_END_HEADERS;
  if ABody = '' then
    LHeaderFlags := LHeaderFlags or H2_FLAG_HEADERS_END_STREAM;
  Result := H2EncodeFrame(H2_FRAME_HEADERS, LHeaderFlags, AStreamID,
    ComposeResponseHeaders(AStatus, AExtraHeaders));
  if ABody <> '' then
    Result := Result + H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM,
      AStreamID, ABody);
end;

function ComposeHeadersFrame(const AStreamID: UInt32; const AFlags: Byte;
  const AHeaders: array of THPackHeader): AnsiString;
begin
  Result := H2EncodeFrame(H2_FRAME_HEADERS, AFlags, AStreamID,
    EncodeHeaders(AHeaders));
end;

function ComposeDataFrame(const AStreamID: UInt32; const AFlags: Byte;
  const APayload: AnsiString): AnsiString;
begin
  Result := H2EncodeFrame(H2_FRAME_DATA, AFlags, AStreamID, APayload);
end;

function ComposePriorityPayload(const ADependencyStreamID: UInt32;
  const AWeight: Byte): AnsiString;
begin
  SetLength(Result, 5);
  Result[1] := AnsiChar(Byte((ADependencyStreamID shr 24) and $7F));
  Result[2] := AnsiChar(Byte(ADependencyStreamID shr 16));
  Result[3] := AnsiChar(Byte(ADependencyStreamID shr 8));
  Result[4] := AnsiChar(Byte(ADependencyStreamID));
  Result[5] := AnsiChar(AWeight);
end;

function ComposePushPromisePayload(const APromisedStreamID: UInt32): AnsiString;
begin
  SetLength(Result, 4);
  Result[1] := AnsiChar(Byte((APromisedStreamID shr 24) and $7F));
  Result[2] := AnsiChar(Byte(APromisedStreamID shr 16));
  Result[3] := AnsiChar(Byte(APromisedStreamID shr 8));
  Result[4] := AnsiChar(Byte(APromisedStreamID));
end;

function ReadAllBody(const ABody: IReader): string;
var
  LBuf: array[0..255] of Byte;
  LRead: SizeUInt;
  LOldLen: SizeInt;
begin
  Result := '';
  if ABody = nil then
    Exit;
  repeat
    LRead := ABody.Read(LBuf[0], SizeOf(LBuf));
    if LRead = 0 then
      Break;
    LOldLen := Length(Result);
    SetLength(Result, LOldLen + SizeInt(LRead));
    Move(LBuf[0], Result[LOldLen + 1], LRead);
  until False;
end;

procedure DecodeFrames(const AWire: AnsiString; out AFrames: array of TH2Frame;
  out ACount: SizeInt);
var
  LOffset: SizeInt;
  LConsumed: SizeUInt;
  LFrame: TH2Frame;
begin
  ACount := 0;
  LOffset := 1;
  while LOffset <= Length(AWire) do
  begin
    Check(H2DecodeFrame(@AWire[LOffset], Length(AWire) - LOffset + 1,
      LFrame, LConsumed), 'frame decodes from wire');
    Check(ACount < Length(AFrames), 'frame output capacity sufficient');
    AFrames[ACount] := LFrame;
    Inc(ACount);
    Inc(LOffset, SizeInt(LConsumed));
  end;
end;

function FindSettingsValue(const APayload: AnsiString;
  const AIdentifier: UInt16; out AValue: UInt32): Boolean;
var
  LEntries: TH2SettingEntries;
  LI: SizeInt;
begin
  AValue := 0;
  Check(H2DecodeSettingsPayload(APayload, LEntries),
    'settings payload decodes');
  for LI := 0 to High(LEntries) do
    if LEntries[LI].Identifier = AIdentifier then
    begin
      AValue := LEntries[LI].Value;
      Exit(True);
    end;
  Result := False;
end;

function FindGoawayError(const AFrames: array of TH2Frame;
  const ACount: SizeInt; out AErrorCode: UInt32): Boolean;
var
  LI: SizeInt;
  LLastStreamID: UInt32;
  LDebugData: AnsiString;
begin
  AErrorCode := H2_ERR_NO_ERROR;
  for LI := 0 to ACount - 1 do
    if AFrames[LI].Header.FrameType = H2_FRAME_GOAWAY then
    begin
      Check(H2DecodeGoaway(AFrames[LI].Payload, LLastStreamID, AErrorCode,
        LDebugData), 'GOAWAY payload decodes');
      Exit(True);
    end;
  Result := False;
end;

function HeaderValue(const AHeaders: array of THPackHeader;
  const AName: AnsiString): string;
var
  LI: SizeInt;
begin
  Result := '';
  for LI := 0 to High(AHeaders) do
  begin
    if AHeaders[LI].Name = '' then
      Break;
    if AHeaders[LI].Name = AName then
      Exit(string(AHeaders[LI].Value));
  end;
end;

procedure DecodeRequestHeaders(const APayload: AnsiString;
  out AHeaders: array of THPackHeader);
var
  LDecoder: THPackDecoder;
begin
  LDecoder.Init;
  Check(LDecoder.Decode(APayload, AHeaders), 'request header block decodes');
end;

function FindFrameIndex(const AFrames: array of TH2Frame;
  const ACount: SizeInt; const AFrameType: Byte;
  const AStreamID: UInt32): SizeInt;
var
  LI: SizeInt;
begin
  for LI := 0 to ACount - 1 do
    if (AFrames[LI].Header.FrameType = AFrameType) and
       (AFrames[LI].Header.StreamID = AStreamID) then
      Exit(LI);
  Result := -1;
end;

{ TFakeTcpStream }

constructor TFakeTcpStream.Create(const AReadData: AnsiString);
begin
  inherited Create;
  FReadData := AReadData;
  FReadPos := 1;
  FWrittenData := '';
  FClosed := False;
  FLocalAddr := TNetAddress.Loopback(8080);
  FRemoteAddr := TNetAddress.IPv4('127.0.0.2', 9000);
  FReadDeadline := TDeadline.Infinite;
  FWriteDeadline := TDeadline.Infinite;
  FMaxWriteChunk := 0;
end;

function TFakeTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  if FClosed or (FReadPos > Length(FReadData)) then
    Exit(0);
  LAvailable := SizeUInt(Length(FReadData) - FReadPos + 1);
  if ACount < LAvailable then
    Result := ACount
  else
    Result := LAvailable;
  Move(FReadData[FReadPos], ABuf, Result);
  Inc(FReadPos, SizeInt(Result));
end;

function TFakeTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LWriteCount: SizeUInt;
  LOldLen: SizeInt;
begin
  if FClosed then
    Exit(0);
  LWriteCount := ACount;
  if (FMaxWriteChunk > 0) and (LWriteCount > FMaxWriteChunk) then
    LWriteCount := FMaxWriteChunk;
  if LWriteCount = 0 then
    Exit(0);
  LOldLen := Length(FWrittenData);
  SetLength(FWrittenData, LOldLen + SizeInt(LWriteCount));
  Move(ABuf, FWrittenData[LOldLen + 1], LWriteCount);
  Result := LWriteCount;
end;

function TFakeTcpStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  Result := 0;
end;

procedure TFakeTcpStream.Close;
begin
  FClosed := True;
end;

function TFakeTcpStream.GetSize: Int64;
begin
  Result := 0;
end;

function TFakeTcpStream.GetPosition: Int64;
begin
  Result := 0;
end;

procedure TFakeTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TFakeTcpStream.LocalAddr: TNetAddress;
begin
  Result := FLocalAddr;
end;

function TFakeTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FRemoteAddr;
end;

procedure TFakeTcpStream.Shutdown;
begin
  FClosed := True;
end;

procedure TFakeTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TFakeTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TFakeTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FReadDeadline := ADeadline;
end;

procedure TFakeTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  FWriteDeadline := ADeadline;
end;

procedure TFakeTcpStream.AppendReadData(const AData: AnsiString);
var
  LOldLen: SizeInt;
begin
  LOldLen := Length(FReadData);
  SetLength(FReadData, LOldLen + Length(AData));
  Move(AData[1], FReadData[LOldLen + 1], Length(AData));
end;

function TFakeTcpStream.WrittenData: AnsiString;
begin
  Result := FWrittenData;
end;

{ TMockTLSConnection }

constructor TMockTLSConnection.Create(AContext: ISSLContext;
  ATransport: TStream; const ASelectedALPN: string);
begin
  inherited Create(AContext);
  FTransport := ATransport;
  FSelectedALPN := ASelectedALPN;
  FObservedALPN := '';
  FServerName := '';
  FCallLog := '';
end;

procedure TMockTLSConnection.AppendCall(const AName: string);
begin
  if FCallLog <> '' then
    FCallLog := FCallLog + '>';
  FCallLog := FCallLog + AName;
end;

function TMockTLSConnection.DoRead(var ABuffer; ACount: Integer): Integer;
begin
  if (FTransport = nil) or (ACount <= 0) then
    Exit(0);
  Result := FTransport.Read(ABuffer, ACount);
end;

function TMockTLSConnection.DoWrite(const ABuffer; ACount: Integer): Integer;
begin
  if (FTransport = nil) or (ACount <= 0) then
    Exit(0);
  Result := FTransport.Write(ABuffer, ACount);
end;

function TMockTLSConnection.DoConnect: Boolean;
begin
  AppendCall('connect');
  Result := True;
end;

function TMockTLSConnection.DoAccept: Boolean;
begin
  AppendCall('accept');
  Result := True;
end;

function TMockTLSConnection.DoHandshakeInternal: TSSLHandshakeState;
begin
  Result := sslHsCompleted;
end;

function TMockTLSConnection.DoShutdown: Boolean;
begin
  Result := True;
end;

procedure TMockTLSConnection.DoClose;
begin
  FreeAndNil(FTransport);
end;

function TMockTLSConnection.DoRenegotiate: Boolean;
begin
  Result := False;
end;

function TMockTLSConnection.DoGetError(ARet: Integer): TSSLErrorCode;
begin
  Result := sslErrNone;
end;

function TMockTLSConnection.DoWantRead: Boolean;
begin
  Result := False;
end;

function TMockTLSConnection.DoWantWrite: Boolean;
begin
  Result := False;
end;

function TMockTLSConnection.DoGetProtocolVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolTLS13;
end;

function TMockTLSConnection.DoGetCipherName: string;
begin
  Result := 'MOCK-TLS';
end;

function TMockTLSConnection.DoGetPeerCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockTLSConnection.DoGetPeerCertificateChain: TSSLCertificateArray;
begin
  Result := nil;
end;

function TMockTLSConnection.DoGetVerifyResult: Integer;
begin
  Result := 0;
end;

function TMockTLSConnection.DoGetVerifyResultString: string;
begin
  Result := 'OK';
end;

function TMockTLSConnection.DoGetSession: ISSLSession;
begin
  Result := nil;
end;

procedure TMockTLSConnection.DoSetSession(ASession: ISSLSession);
begin
end;

function TMockTLSConnection.DoIsSessionReused: Boolean;
begin
  Result := False;
end;

function TMockTLSConnection.DoGetSelectedALPNProtocol: string;
begin
  Result := FSelectedALPN;
end;

function TMockTLSConnection.DoGetState: string;
begin
  Result := 'MOCK';
end;

function TMockTLSConnection.DoGetNativeHandle: Pointer;
begin
  Result := nil;
end;

procedure TMockTLSConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
  AppendCall('servername');
end;

function TMockTLSConnection.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TMockTLSConnection.SetALPNProtocols(const AProtocols: string);
begin
  FObservedALPN := AProtocols;
  AppendCall('alpn');
end;

function TMockTLSConnection.GetALPNProtocols: string;
begin
  Result := FObservedALPN;
end;

function TMockTLSConnection.GetObservedServerName: string;
begin
  Result := FServerName;
end;

function TMockTLSConnection.GetObservedALPN: string;
begin
  Result := FObservedALPN;
end;

function TMockTLSConnection.GetSelectedALPN: string;
begin
  Result := FSelectedALPN;
end;

function TMockTLSConnection.GetCallLog: string;
begin
  Result := FCallLog;
end;

{ TMockTLSContext }

constructor TMockTLSContext.Create(AContextType: TSSLContextType;
  const ASelectedALPN: string);
begin
  inherited Create;
  FContextType := AContextType;
  FSelectedALPN := ASelectedALPN;
  FConfiguredALPN := '';
  FLastProbe := nil;
end;

function TMockTLSContext.GetLastProbe: IMockTLSProbe;
begin
  Result := FLastProbe;
end;

procedure TMockTLSContext.ClearLastProbe;
begin
  FLastProbe := nil;
end;

function TMockTLSContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TMockTLSContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
end;

function TMockTLSContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := [];
end;

procedure TMockTLSContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
end;

function TMockTLSContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolUnknown;
end;

procedure TMockTLSContext.LoadCertificate(const AFileName: string);
begin
end;

procedure TMockTLSContext.LoadCertificate(AStream: TStream);
begin
end;

procedure TMockTLSContext.LoadCertificate(ACert: ISSLCertificate);
begin
end;

procedure TMockTLSContext.LoadPrivateKey(const AFileName: string;
  const APassword: string);
begin
end;

procedure TMockTLSContext.LoadPrivateKey(AStream: TStream;
  const APassword: string);
begin
end;

procedure TMockTLSContext.LoadCertificatePEM(const APEM: string);
begin
end;

procedure TMockTLSContext.LoadPrivateKeyPEM(const APEM: string;
  const APassword: string);
begin
end;

procedure TMockTLSContext.LoadCAFile(const AFileName: string);
begin
end;

procedure TMockTLSContext.LoadCAPath(const APath: string);
begin
end;

procedure TMockTLSContext.SetCertificateStore(AStore: ISSLCertificateStore);
begin
end;

procedure TMockTLSContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
end;

function TMockTLSContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := [];
end;

procedure TMockTLSContext.SetVerifyDepth(ADepth: Integer);
begin
end;

function TMockTLSContext.GetVerifyDepth: Integer;
begin
  Result := 0;
end;

procedure TMockTLSContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
end;

procedure TMockTLSContext.SetCipherList(const ACipherList: string);
begin
end;

function TMockTLSContext.GetCipherList: string;
begin
  Result := '';
end;

procedure TMockTLSContext.SetCipherSuites(const ACipherSuites: string);
begin
end;

function TMockTLSContext.GetCipherSuites: string;
begin
  Result := '';
end;

procedure TMockTLSContext.SetSessionCacheMode(AEnabled: Boolean);
begin
end;

function TMockTLSContext.GetSessionCacheMode: Boolean;
begin
  Result := False;
end;

procedure TMockTLSContext.SetSessionTimeout(ATimeout: Integer);
begin
end;

function TMockTLSContext.GetSessionTimeout: Integer;
begin
  Result := 0;
end;

procedure TMockTLSContext.SetSessionCacheSize(ASize: Integer);
begin
end;

function TMockTLSContext.GetSessionCacheSize: Integer;
begin
  Result := 0;
end;

procedure TMockTLSContext.SetOptions(const AOptions: TSSLOptions);
begin
end;

function TMockTLSContext.GetOptions: TSSLOptions;
begin
  Result := [];
end;

procedure TMockTLSContext.SetServerName(const AServerName: string);
begin
end;

function TMockTLSContext.GetServerName: string;
begin
  Result := '';
end;

procedure TMockTLSContext.SetALPNProtocols(const AProtocols: string);
begin
  FConfiguredALPN := AProtocols;
end;

function TMockTLSContext.GetALPNProtocols: string;
begin
  Result := FConfiguredALPN;
end;

procedure TMockTLSContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
end;

function TMockTLSContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := [];
end;

procedure TMockTLSContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
end;

procedure TMockTLSContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
end;

procedure TMockTLSContext.AddCertificatePin(const AHash: TBytes;
  APinType: Integer; const ADescription: string; AIsBackup: Boolean);
begin
end;

procedure TMockTLSContext.AddCertificatePinBase64(
  const ABase64Hash: string; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
end;

procedure TMockTLSContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
end;

function TMockTLSContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := False;
end;

procedure TMockTLSContext.ClearCertificatePins;
begin
end;

function TMockTLSContext.CreateConnection(ASocket: THandle): ISSLConnection;
begin
  Result := nil;
end;

function TMockTLSContext.CreateConnection(AStream: TStream): ISSLConnection;
var
  LConn: TMockTLSConnection;
begin
  LConn := TMockTLSConnection.Create(Self, AStream, FSelectedALPN);
  FLastProbe := LConn as IMockTLSProbe;
  Result := LConn;
end;

function TMockTLSContext.IsValid: Boolean;
begin
  Result := True;
end;

{ TMockTlsServerTransport }

function TMockTlsServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
var
  LReq: IHttpRequest;
begin
  FServeConnCalled := True;
  FSeenALPN := TlsTcpStreamSelectedALPN(AConn);
  if AHandler <> nil then
  begin
    LReq := THttpRequest.Create(hmGet, TUrl.Parse('/tls-h2'),
      hvHttp2, NewHttpHeaders, nil, 0);
    AHandler.ServeHTTP(LReq, nil);
  end;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

procedure TestHandshakeWritesClientPrefaceAndSettings;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LFrames: array[0..7] of TH2Frame;
  LCount: SizeInt;
  LEnablePushValue: UInt32;
begin
  LStream := TFakeTcpStream.Create(ComposeServerHandshake);
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    Check(LConn.Handshake, 'handshake succeeds');
    CheckEqual(Int64(Ord(h2ccsActive)), Int64(Ord(LConn.State)),
      'connection becomes active');
    Check(Pos(H2_CLIENT_PREFACE, LStream.WrittenData) = 1,
      'client preface written first');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(LCount >= 2, 'client wrote settings and ack/window delta');
    CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[0].Header.FrameType),
      'first frame is settings');
    Check(FindSettingsValue(LFrames[0].Payload, H2_SETTINGS_ENABLE_PUSH,
      LEnablePushValue), 'client sends SETTINGS_ENABLE_PUSH');
    CheckEqual(Int64(0), Int64(LEnablePushValue),
      'client disables server push');
    CheckEqual(Int64(H2_FRAME_SETTINGS), Int64(LFrames[1].Header.FrameType),
      'second frame is settings ack');
    CheckEqual(Int64(H2_FLAG_SETTINGS_ACK), Int64(LFrames[1].Header.Flags),
      'settings ack flag');
  finally
    LConn.Free;
    LStream := nil;
  end;
end;

procedure TestRoundTripGetReadsResponse;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..7] of TH2Frame;
  LDecodedHeaders: array of THPackHeader;
  LCount: SizeInt;
  LRequestIndex: SizeInt;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', 'pong', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/ping'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'response status');
    CheckEqual('pong', ReadAllBody(LResp.Body), 'response body');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(LCount >= 3, 'settings, ack, request headers sent');
    LRequestIndex := 2;
    if (LCount > 3) and (LFrames[2].Header.FrameType <> H2_FRAME_HEADERS) then
      LRequestIndex := LCount - 1;
    CheckEqual(Int64(H2_FRAME_HEADERS), Int64(LFrames[LRequestIndex].Header.FrameType),
      'request uses headers frame');
    CheckEqual(Int64(1), Int64(LFrames[LRequestIndex].Header.StreamID),
      'first request uses stream 1');
    SetLength(LDecodedHeaders, Length(LFrames[LRequestIndex].Payload) + 4);
    DecodeRequestHeaders(LFrames[LRequestIndex].Payload, LDecodedHeaders);
    CheckEqual('GET', HeaderValue(LDecodedHeaders, ':method'), 'pseudo method');
    CheckEqual('/ping', HeaderValue(LDecodedHeaders, ':path'), 'pseudo path');
    CheckEqual('example.com', HeaderValue(LDecodedHeaders, ':authority'),
      'pseudo authority');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestRoundTripPostWritesDataFrame;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LBody: IStream;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
begin
  LBody := CreateBytesStreamFrom([Byte('a'), Byte('b'), Byte('c')]);
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '201', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmPost, 'http://example.com/post',
      NewHttpHeaders, LBody as IReader, 3));
    CheckEqual(Int64(201), Int64(LResp.StatusCode), 'post response status');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(LCount >= 4, 'settings, ack, headers, data');
    CheckEqual(Int64(H2_FRAME_DATA), Int64(LFrames[LCount - 1].Header.FrameType),
      'post writes data frame');
    CheckEqual('abc', string(LFrames[LCount - 1].Payload), 'data payload');
    Check((LFrames[LCount - 1].Header.Flags and H2_FLAG_DATA_END_STREAM) <> 0,
      'data ends stream');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
    LBody := nil;
  end;
end;

procedure TestRoundTripFiltersConnectionSpecificRequestHeaders;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LFrames: array[0..7] of TH2Frame;
  LDecodedHeaders: array of THPackHeader;
  LCount: SizeInt;
  LRequestIndex: SizeInt;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Add('connection', 'keep-alive');
  LHeaders.Add('upgrade', 'websocket');
  LHeaders.Add('keep-alive', 'timeout=5');
  LHeaders.Add('proxy-connection', 'keep-alive');
  LHeaders.Add('te', 'gzip');
  LHeaders.Add('host', 'spoofed.example');
  LHeaders.Add('x-keep', 'ok');
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/filter',
      LHeaders));
    LResp := nil;
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(LCount >= 3, 'request headers were sent');
    LRequestIndex := 2;
    if (LCount > 3) and (LFrames[2].Header.FrameType <> H2_FRAME_HEADERS) then
      LRequestIndex := LCount - 1;
    SetLength(LDecodedHeaders, Length(LFrames[LRequestIndex].Payload) + 4);
    DecodeRequestHeaders(LFrames[LRequestIndex].Payload, LDecodedHeaders);
    CheckEqual('', HeaderValue(LDecodedHeaders, 'connection'),
      'connection header filtered');
    CheckEqual('', HeaderValue(LDecodedHeaders, 'upgrade'),
      'upgrade header filtered');
    CheckEqual('', HeaderValue(LDecodedHeaders, 'keep-alive'),
      'keep-alive header filtered');
    CheckEqual('', HeaderValue(LDecodedHeaders, 'proxy-connection'),
      'proxy-connection header filtered');
    CheckEqual('', HeaderValue(LDecodedHeaders, 'te'),
      'non-trailers TE filtered');
    CheckEqual('ok', HeaderValue(LDecodedHeaders, 'x-keep'),
      'ordinary header preserved');
    CheckEqual('example.com', HeaderValue(LDecodedHeaders, ':authority'),
      'host header replaced by :authority');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
    LHeaders := nil;
  end;
end;

procedure TestRoundTripPreservesTeTrailersHeader;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LFrames: array[0..7] of TH2Frame;
  LDecodedHeaders: array of THPackHeader;
  LCount: SizeInt;
  LRequestIndex: SizeInt;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Add('te', 'trailers');
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/te-trailers',
      LHeaders));
    LResp := nil;
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(LCount >= 3, 'request headers were sent');
    LRequestIndex := 2;
    if (LCount > 3) and (LFrames[2].Header.FrameType <> H2_FRAME_HEADERS) then
      LRequestIndex := LCount - 1;
    SetLength(LDecodedHeaders, Length(LFrames[LRequestIndex].Payload) + 4);
    DecodeRequestHeaders(LFrames[LRequestIndex].Payload, LDecodedHeaders);
    CheckEqual('trailers', HeaderValue(LDecodedHeaders, 'te'),
      'te: trailers preserved');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
    LHeaders := nil;
  end;
end;

procedure TestRuntimeSettingsInitialWindowSizeUpdatesActiveStream;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LBody: IStream;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
  LDataCount: SizeInt;
  LFirstData: AnsiString;
  LSecondData: AnsiString;
  LI: SizeInt;
begin
  LBody := CreateBytesStreamFrom([Byte('a'), Byte('b'), Byte('c'), Byte('d')]);
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake(ComposeSingleSettingPayload(
      H2_SETTINGS_INITIAL_WINDOW_SIZE, 2)) +
    H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0,
      ComposeSingleSettingPayload(H2_SETTINGS_INITIAL_WINDOW_SIZE, 4)) +
    ComposeResponse(1, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmPost,
      'http://example.com/settings-window', NewHttpHeaders, LBody as IReader, 4));
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'runtime SETTINGS response status');

    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    LDataCount := 0;
    LFirstData := '';
    LSecondData := '';
    for LI := 0 to LCount - 1 do
      if (LFrames[LI].Header.FrameType = H2_FRAME_DATA) and
         (LFrames[LI].Header.StreamID = 1) then
      begin
        Inc(LDataCount);
        if LDataCount = 1 then
          LFirstData := LFrames[LI].Payload
        else if LDataCount = 2 then
          LSecondData := LFrames[LI].Payload;
      end;
    CheckEqual(Int64(2), Int64(LDataCount),
      'runtime SETTINGS resumes active stream request body');
    CheckEqual('ab', string(LFirstData),
      'first request DATA obeys original small stream window');
    CheckEqual('cd', string(LSecondData),
      'second request DATA uses updated initial stream window');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
    LBody := nil;
  end;
end;

procedure TestRequestBodyReadsWindowUpdateWhenSendWindowBlocked;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LBody: IStream;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
  LDataCount: SizeInt;
  LFirstData: AnsiString;
  LSecondData: AnsiString;
  LI: SizeInt;
begin
  LBody := CreateBytesStreamFrom([Byte('w'), Byte('x'), Byte('y'), Byte('z')]);
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake(ComposeSingleSettingPayload(
      H2_SETTINGS_INITIAL_WINDOW_SIZE, 2)) +
    H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 1, H2EncodeWindowUpdate(2)) +
    ComposeResponse(1, '201', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmPost,
      'http://example.com/window-update', NewHttpHeaders, LBody as IReader, 4));
    CheckEqual(Int64(201), Int64(LResp.StatusCode),
      'WINDOW_UPDATE response status');

    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    LDataCount := 0;
    LFirstData := '';
    LSecondData := '';
    for LI := 0 to LCount - 1 do
      if (LFrames[LI].Header.FrameType = H2_FRAME_DATA) and
         (LFrames[LI].Header.StreamID = 1) then
      begin
        Inc(LDataCount);
        if LDataCount = 1 then
          LFirstData := LFrames[LI].Payload
        else if LDataCount = 2 then
          LSecondData := LFrames[LI].Payload;
      end;
    CheckEqual(Int64(2), Int64(LDataCount),
      'WINDOW_UPDATE resumes blocked request body send');
    CheckEqual('wx', string(LFirstData),
      'first request DATA consumes original stream window');
    CheckEqual('yz', string(LSecondData),
      'second request DATA is sent after WINDOW_UPDATE');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
    LBody := nil;
  end;
end;

procedure TestStreamIdIncrementsAcrossRequests;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []) +
    ComposeResponse(3, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/one'));
    LResp := nil;
    CheckEqual(Int64(3), Int64(LConn.NextStreamID), 'next stream after first request');
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/two'));
    LResp := nil;
    CheckEqual(Int64(5), Int64(LConn.NextStreamID), 'next stream after second request');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestGoawayMarksConnectionNotReusable;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []) +
    H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0, H2EncodeGoaway(1, H2_ERR_NO_ERROR, '')));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/goaway'));
    LResp := nil;
    CheckEqual(False, LConn.IsReusable, 'goaway makes connection non-reusable');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestPushPromiseTriggersProtocolGoaway;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
  LErrorCode: UInt32;
  LErrorRaised: Boolean;
begin
  LResp := nil;
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_PUSH_PROMISE, H2_FLAG_PUSH_PROMISE_END_HEADERS, 1,
      ComposePushPromisePayload(2)) +
    ComposeResponse(1, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LErrorRaised := False;
    try
      LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/push'));
      LResp := nil;
    except
      on E: Exception do
        LErrorRaised := True;
    end;
    Check(LErrorRaised, 'PUSH_PROMISE aborts client round trip');
    CheckEqual(Int64(Ord(h2ccsClosed)), Int64(Ord(LConn.State)),
      'PUSH_PROMISE closes client connection');
    CheckEqual(True, LStream.FClosed, 'PUSH_PROMISE closes TCP stream');

    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(FindGoawayError(LFrames, LCount, LErrorCode),
      'client writes GOAWAY for PUSH_PROMISE');
    CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
      'PUSH_PROMISE GOAWAY uses PROTOCOL_ERROR');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure CheckRoundTripFailsWithProtocolGoaway(const AServerFrames: AnsiString;
  const AUrl: string; const AMessage: string);
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
  LErrorCode: UInt32;
  LErrorRaised: Boolean;
begin
  LResp := nil;
  LStream := TFakeTcpStream.Create(ComposeServerHandshake + AServerFrames);
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LErrorRaised := False;
    try
      LResp := LConn.RoundTrip(NewRequest(hmGet, AUrl));
      LResp := nil;
    except
      on E: Exception do
        LErrorRaised := True;
    end;
    Check(LErrorRaised, AMessage + ' aborts client round trip');
    CheckEqual(Int64(Ord(h2ccsClosed)), Int64(Ord(LConn.State)),
      AMessage + ' closes client state');
    CheckEqual(True, LStream.FClosed, AMessage + ' closes TCP stream');

    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    Check(FindGoawayError(LFrames, LCount, LErrorCode),
      AMessage + ' writes GOAWAY');
    CheckEqual(Int64(H2_ERR_PROTOCOL_ERROR), Int64(LErrorCode),
      AMessage + ' GOAWAY uses PROTOCOL_ERROR');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestDataOnConnectionStreamTriggersProtocolGoaway;
begin
  CheckRoundTripFailsWithProtocolGoaway(
    H2EncodeFrame(H2_FRAME_DATA, H2_FLAG_DATA_END_STREAM, 0, 'bad'),
    'http://example.com/data-stream-zero',
    'DATA on connection stream');
end;

procedure TestHeadersOnConnectionStreamTriggersProtocolGoaway;
begin
  CheckRoundTripFailsWithProtocolGoaway(
    H2EncodeFrame(H2_FRAME_HEADERS,
      H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 0,
      ComposeResponseHeaders('200', [])),
    'http://example.com/headers-stream-zero',
    'HEADERS on connection stream');
end;

procedure TestContinuationOnDifferentStreamTriggersProtocolGoaway;
var
  LHeaderBlock: AnsiString;
begin
  LHeaderBlock := ComposeResponseHeaders('200', []);
  CheckRoundTripFailsWithProtocolGoaway(
    H2EncodeFrame(H2_FRAME_HEADERS, 0, 1, Copy(LHeaderBlock, 1, 1)) +
    H2EncodeFrame(H2_FRAME_CONTINUATION, H2_FLAG_CONTINUATION_END_HEADERS,
      3, Copy(LHeaderBlock, 2, MaxInt)),
    'http://example.com/bad-continuation',
    'CONTINUATION on different stream');
end;

procedure TestPingGetsAcked;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..15] of TH2Frame;
  LCount: SizeInt;
  LFoundAck: Boolean;
  LI: SizeInt;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_PING, 0, 0, H2EncodePing($0102030405060708)) +
    ComposeResponse(1, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/ping-ack'));
    LResp := nil;
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    LFoundAck := False;
    for LI := 0 to LCount - 1 do
      if (LFrames[LI].Header.FrameType = H2_FRAME_PING) and
         ((LFrames[LI].Header.Flags and H2_FLAG_PING_ACK) <> 0) then
        LFoundAck := True;
    Check(LFoundAck, 'client writes ping ack');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestTransportReusesPooledConnection;
var
  LTransport: IHttpTransport;
  LIdle: IHttpTransportIdleConnections;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LFrames: array[0..31] of TH2Frame;
  LCount: SizeInt;
  LRequestFrameCount: Int32;
  LI: SizeInt;
begin
  ResetDialQueue;
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []) +
    ComposeResponse(3, '200', '', []));
  QueueDialConn(LStream as ITcpStream);
  SetH2ClientDialFuncForTests(@TestDial);
  try
    LTransport := NewH2ClientTransport(TH2ClientTransportOptions.Default);
    Check(Supports(LTransport, IHttpTransportIdleConnections, LIdle),
      'h2 client transport supports idle close');
    LResp := LTransport.RoundTrip(NewRequest(hmGet, 'http://example.com/one'));
    LResp := nil;
    LResp := LTransport.RoundTrip(NewRequest(hmGet, 'http://example.com/two'));
    LResp := nil;
    CheckEqual(Int64(1), Int64(GDialIndex), 'pooled transport dialed once');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    LRequestFrameCount := 0;
    for LI := 0 to LCount - 1 do
      if LFrames[LI].Header.FrameType = H2_FRAME_HEADERS then
        Inc(LRequestFrameCount);
    Check(LRequestFrameCount >= 2, 'two request header frames sent on one conn');
  finally
    ResetH2ClientDialFuncForTests;
    ResetDialQueue;
    LTransport := nil;
    LIdle := nil;
    LStream := nil;
  end;
end;

procedure TestTransportCloseIdleConnectionsClosesPooledConn;
var
  LTransport: IHttpTransport;
  LIdle: IHttpTransportIdleConnections;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  ResetDialQueue;
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []));
  QueueDialConn(LStream as ITcpStream);
  SetH2ClientDialFuncForTests(@TestDial);
  try
    LTransport := NewH2ClientTransport(TH2ClientTransportOptions.Default);
    Check(Supports(LTransport, IHttpTransportIdleConnections, LIdle),
      'transport supports idle close');
    LResp := LTransport.RoundTrip(NewRequest(hmGet, 'http://example.com/idle'));
    LResp := nil;
    LIdle.CloseIdleConnections;
    CheckEqual(True, LStream.FClosed, 'idle connection closed');
  finally
    ResetH2ClientDialFuncForTests;
    ResetDialQueue;
    LTransport := nil;
    LIdle := nil;
    LStream := nil;
  end;
end;

procedure TestHttpsTransportNegotiatesH2ViaALPN;
var
  LTransport: IHttpTransport;
  LOptions: TH2ClientTransportOptions;
  LContextObj: TMockTLSContext;
  LContext: ISSLContext;
  LProbe: IMockTLSProbe;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  ResetDialQueue;
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', 'secure', []));
  QueueDialConn(LStream as ITcpStream);
  SetH2ClientDialFuncForTests(@TestDial);
  try
    LContextObj := TMockTLSContext.Create(sslCtxClient, 'h2');
    LContext := LContextObj;
    LOptions := TH2ClientTransportOptions.Default;
    LOptions.TLSContext := LContext;
    LTransport := NewH2ClientTransport(LOptions);
    LResp := LTransport.RoundTrip(NewRequest(hmGet,
      'https://secure.example.com/health'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'HTTPS H2 transport returns response');
    CheckEqual('secure', ReadAllBody(LResp.Body),
      'HTTPS H2 transport reads response body');
    CheckEqual('secure.example.com', GLastDialHost,
      'HTTPS H2 transport dials parsed host');
    CheckEqual(Int64(443), Int64(GLastDialPort),
      'HTTPS H2 transport defaults to port 443');
    Check(Pos(H2_CLIENT_PREFACE, LStream.WrittenData) = 1,
      'HTTPS H2 transport writes client preface');
    LProbe := LContextObj.GetLastProbe;
    Check(LProbe <> nil, 'mock TLS context captured connection probe');
    CheckEqual('secure.example.com', LProbe.GetObservedServerName,
      'TLS connector applies SNI host');
    CheckEqual('h2', LProbe.GetObservedALPN,
      'TLS connector applies HTTP/2 ALPN');
    CheckEqual('servername>alpn>connect', LProbe.GetCallLog,
      'TLS connector applies ALPN before connect');
  finally
    ResetH2ClientDialFuncForTests;
    ResetDialQueue;
    LContextObj.ClearLastProbe;
    LTransport := nil;
    LResp := nil;
    LContext := nil;
    LStream := nil;
  end;
end;

procedure TestHttpsTransportRejectsUnexpectedALPN;
var
  LTransport: IHttpTransport;
  LOptions: TH2ClientTransportOptions;
  LContextObj: TMockTLSContext;
  LContext: ISSLContext;
  LProbe: IMockTLSProbe;
  LStream: TFakeTcpStream;
  LRaised: Boolean;
  LReportedALPN: Boolean;
begin
  ResetDialQueue;
  LStream := TFakeTcpStream.Create('');
  QueueDialConn(LStream as ITcpStream);
  SetH2ClientDialFuncForTests(@TestDial);
  try
    LContextObj := TMockTLSContext.Create(sslCtxClient, 'http/1.1');
    LContext := LContextObj;
    LOptions := TH2ClientTransportOptions.Default;
    LOptions.TLSContext := LContext;
    LTransport := NewH2ClientTransport(LOptions);
    LRaised := False;
    LReportedALPN := False;
    try
      LTransport.RoundTrip(NewRequest(hmGet, 'https://secure.example.com/miss'));
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LReportedALPN := Pos('alpn', LowerCase(E.Message)) > 0;
      end;
    end;
    Check(LRaised, 'HTTPS H2 transport rejects non-h2 ALPN');
    Check(LReportedALPN, 'HTTPS H2 transport reports ALPN mismatch');
    LProbe := LContextObj.GetLastProbe;
    Check(LProbe <> nil, 'ALPN mismatch still creates TLS probe');
    CheckEqual('h2', LProbe.GetObservedALPN,
      'HTTPS H2 transport still offers h2 ALPN');
  finally
    ResetH2ClientDialFuncForTests;
    ResetDialQueue;
    LContextObj.ClearLastProbe;
    LTransport := nil;
    LContext := nil;
    LStream := nil;
  end;
end;

procedure TestH2TlsServerTransportDispatchesNegotiatedH2;
var
  LContextObj: TMockTLSContext;
  LContext: ISSLContext;
  LInnerObj: TMockTlsServerTransport;
  LInner: IHttpServerTransport;
  LTransport: IHttpServerTransport;
  LRawConn: ITcpStream;
  LHandlerCalled: Boolean;
begin
  LContextObj := TMockTLSContext.Create(sslCtxServer, 'h2');
  LContext := LContextObj;
  LInnerObj := TMockTlsServerTransport.Create;
  LInner := LInnerObj as IHttpServerTransport;
  LTransport := NewH2TlsServerTransport(LContext, LInner);
  LRawConn := TFakeTcpStream.Create('') as ITcpStream;
  LHandlerCalled := False;

  CheckEqual('h2', LContext.GetALPNProtocols,
    'H2 TLS server transport configures context ALPN');
  Check(LTransport.ServeConn(LRawConn,
    nextpas.core.http.middleware.HandlerFunc(procedure(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
    end)) = TCP_SERVER_CONN_OWNERSHIP_SERVER,
    'H2 TLS server transport keeps server ownership');
  Check(LInnerObj.ServeConnCalled,
    'H2 TLS server transport dispatches negotiated connection');
  CheckEqual('h2', LInnerObj.SeenALPN,
    'H2 TLS server transport forwards negotiated ALPN');
  Check(LHandlerCalled, 'H2 TLS server transport preserves handler dispatch');
  LContextObj.ClearLastProbe;
end;

procedure TestH2TlsServerTransportRejectsMissingH2ALPN;
var
  LContextObj: TMockTLSContext;
  LContext: ISSLContext;
  LInnerObj: TMockTlsServerTransport;
  LInner: IHttpServerTransport;
  LTransport: IHttpServerTransport;
  LRawConn: ITcpStream;
  LRaised: Boolean;
begin
  LContextObj := TMockTLSContext.Create(sslCtxServer, 'http/1.1');
  LContext := LContextObj;
  LInnerObj := TMockTlsServerTransport.Create;
  LInner := LInnerObj as IHttpServerTransport;
  LTransport := NewH2TlsServerTransport(LContext, LInner);
  LRawConn := TFakeTcpStream.Create('') as ITcpStream;

  LRaised := False;
  try
    LTransport.ServeConn(LRawConn,
      nextpas.core.http.middleware.HandlerFunc(procedure(const AReq: IHttpRequest;
        const AW: IHttpResponseWriter)
      begin
      end));
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'H2 TLS server transport rejects non-h2 ALPN');
  Check(not LInnerObj.ServeConnCalled,
    'H2 TLS server transport does not dispatch rejected ALPN');
  LContextObj.ClearLastProbe;
end;

procedure TestHandshakeFailsWithoutServerSettings;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
begin
  LStream := TFakeTcpStream.Create(
    H2EncodeFrame(H2_FRAME_PING, 0, 0, H2EncodePing($0102030405060708)));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    CheckEqual(False, LConn.Handshake,
      'handshake returns false when server closes before SETTINGS');
    CheckEqual(Int64(Ord(h2ccsClosed)), Int64(Ord(LConn.State)),
      'connection closes when server never sends SETTINGS');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestHandshakeFailsOnSettingsAckFirst;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
begin
  LStream := TFakeTcpStream.Create(
    H2EncodeFrame(H2_FRAME_SETTINGS, H2_FLAG_SETTINGS_ACK, 0, ''));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    CheckEqual(False, LConn.Handshake,
      'handshake returns false when first server SETTINGS is ack-only');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestRoundTripOnClosedConnectionThrows;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LRaised: Boolean;
begin
  LStream := TFakeTcpStream.Create(ComposeServerHandshake);
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LConn.Close;
    LRaised := False;
    try
      LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/closed'));
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'round trip on closed connection raises');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestGoawayWithActiveStreamCompletesCurrentRequest;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0, H2EncodeGoaway(1, H2_ERR_NO_ERROR, '')) +
    ComposeResponse(1, '200', 'ok', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/drain'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'goaway still allows in-flight stream response');
    CheckEqual('ok', ReadAllBody(LResp.Body),
      'goaway still delivers in-flight stream body');
    CheckEqual(False, LConn.IsReusable,
      'goaway after active stream marks connection not reusable');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestMultipleGoawayWithDecreasingLastStreamAccepted;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0, H2EncodeGoaway(3, H2_ERR_NO_ERROR, '')) +
    H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0, H2EncodeGoaway(1, H2_ERR_NO_ERROR, '')) +
    ComposeResponse(1, '200', 'ok', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/two-goaway'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'decreasing GOAWAY last-stream still permits active response');
    CheckEqual('ok', ReadAllBody(LResp.Body),
      'decreasing GOAWAY still preserves response body');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestGoawayAfterGracefulDrainMarksNotReusable;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeResponse(1, '200', '', []) +
    H2EncodeFrame(H2_FRAME_GOAWAY, 0, 0, H2EncodeGoaway(0, H2_ERR_NO_ERROR, '')));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/graceful'));
    LResp := nil;
    CheckEqual(False, LConn.IsReusable,
      'graceful drain GOAWAY marks connection not reusable');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestHeadOnlyResponseReadsEmptyBody;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeHeadersFrame(1,
      H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM,
      [PackHeader(':status', '200')]));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmHead, 'http://example.com/head'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'HEAD response status');
    CheckEqual('', ReadAllBody(LResp.Body), 'HEAD response body is empty');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestMultipleDataFramesDeliverConcatenatedBody;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeHeadersFrame(1, H2_FLAG_HEADERS_END_HEADERS,
      [PackHeader(':status', '200')]) +
    ComposeDataFrame(1, 0, 'hel') +
    ComposeDataFrame(1, H2_FLAG_DATA_END_STREAM, 'lo'));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/multi'));
    CheckEqual('hello', ReadAllBody(LResp.Body),
      'response body concatenates multiple DATA frames');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestPaddedDataDeliversUnpaddedBody;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LPayload: AnsiString;
begin
  LPayload := AnsiChar(#3) + 'hello' + 'xyz';
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeHeadersFrame(1, H2_FLAG_HEADERS_END_HEADERS,
      [PackHeader(':status', '200')]) +
    ComposeDataFrame(1, H2_FLAG_DATA_PADDED or H2_FLAG_DATA_END_STREAM,
      LPayload));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/padded-data'));
    CheckEqual('hello', ReadAllBody(LResp.Body),
      'padded DATA strips trailing padding');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestPaddedHeadersParsesCorrectly;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LHeaderBlock: AnsiString;
begin
  LHeaderBlock := ComposeResponseHeaders('200', []);
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_HEADERS,
      H2_FLAG_HEADERS_PADDED or H2_FLAG_HEADERS_END_HEADERS or
      H2_FLAG_HEADERS_END_STREAM, 1, AnsiChar(#2) + LHeaderBlock + 'zz'));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/padded-headers'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'padded HEADERS decode response status');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestContinuationReassemblesResponseHeaders;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LHeaderBlock: AnsiString;
  LSplit: SizeInt;
begin
  LHeaderBlock := ComposeResponseHeaders('200',
    [PackHeader('x-part', 'assembled')]);
  LSplit := Length(LHeaderBlock) div 2;
  if LSplit < 1 then
    LSplit := 1;
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_HEADERS, 0, 1, Copy(LHeaderBlock, 1, LSplit)) +
    H2EncodeFrame(H2_FRAME_CONTINUATION,
      H2_FLAG_CONTINUATION_END_HEADERS or H2_FLAG_HEADERS_END_STREAM, 1,
      Copy(LHeaderBlock, LSplit + 1, MaxInt)));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/continuation'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'HEADERS plus CONTINUATION decodes status');
    CheckEqual('assembled', LResp.Headers.Get('x-part'),
      'HEADERS plus CONTINUATION preserves header value');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestServerRstStreamWithCancelMarksResponseReset;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LRaised: Boolean;
  LReportedCancel: Boolean;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_RST_STREAM, 0, 1, H2EncodeRstStream(H2_ERR_CANCEL)));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LRaised := False;
    LReportedCancel := False;
    try
      LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/rst-cancel'));
    except
      on E: Exception do
      begin
        LRaised := True;
        LReportedCancel := Pos('CANCEL', UpperCase(E.Message)) > 0;
      end;
    end;
    Check(LRaised, 'RST_STREAM CANCEL aborts response');
    Check(LReportedCancel, 'RST_STREAM CANCEL propagates reset code');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestServerRstStreamWithNoErrorAbortsResponse;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LRaised: Boolean;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    ComposeHeadersFrame(1,
      H2_FLAG_HEADERS_END_HEADERS or H2_FLAG_HEADERS_END_STREAM,
      [PackHeader(':status', '200')]) +
    H2EncodeFrame(H2_FRAME_RST_STREAM, 0, 1, H2EncodeRstStream(H2_ERR_NO_ERROR)));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LRaised := False;
    try
      LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/rst-no-error'));
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised,
      'RST_STREAM NO_ERROR after response still aborts (client treats all RST as error)');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestServerRstStreamPropagatesErrorCode;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LRaised: Boolean;
  LReportedCode: Boolean;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_RST_STREAM, 0, 1,
      H2EncodeRstStream(H2_ERR_ENHANCE_YOUR_CALM)));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LRaised := False;
    LReportedCode := False;
    try
      LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/rst-calm'));
    except
      on E: Exception do
      begin
        LRaised := True;
        LReportedCode := Pos('ENHANCE_YOUR_CALM', UpperCase(E.Message)) > 0;
      end;
    end;
    Check(LRaised, 'RST_STREAM ENHANCE_YOUR_CALM aborts response');
    Check(LReportedCode, 'RST_STREAM error exposes error code name');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestInvalidSettingsPayloadFailsConnection;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LRaised: Boolean;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_SETTINGS, 0, 0, 'garbage'));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LRaised := False;
    try
      LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/bad-settings'));
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'invalid SETTINGS payload fails round trip');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestWindowUpdateZeroIncrementFailsConnection;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LRaised: Boolean;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 1, H2EncodeWindowUpdate(0)));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LRaised := False;
    try
      LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/bad-window-update'));
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'zero increment WINDOW_UPDATE fails connection');
  finally
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestWindowUpdateOnUnknownStreamIgnored;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
begin
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 99, H2EncodeWindowUpdate(10)) +
    ComposeResponse(1, '200', 'ok', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream,
    TH2ClientTransportOptions.Default);
  try
    LResp := LConn.RoundTrip(NewRequest(hmGet, 'http://example.com/unknown-window'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'WINDOW_UPDATE on unknown stream does not break current request');
    CheckEqual('ok', ReadAllBody(LResp.Body),
      'WINDOW_UPDATE on unknown stream leaves response intact');
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
  end;
end;

procedure TestConnectionWindowUpdateIncreasesSendWindow;
var
  LConn: TH2ClientConnection;
  LStream: TFakeTcpStream;
  LResp: IHttpResponse;
  LBody: IStream;
  LOptions: TH2ClientTransportOptions;
  LFrames: array[0..31] of TH2Frame;
  LCount: SizeInt;
  LFirstDataIndex: SizeInt;
  LSecondDataIndex: SizeInt;
begin
  LOptions := TH2ClientTransportOptions.Default;
  LOptions.InitialConnectionWindowSize := 2;
  LBody := CreateBytesStreamFrom([Byte('a'), Byte('b'), Byte('c'), Byte('d')]);
  LStream := TFakeTcpStream.Create(
    ComposeServerHandshake +
    H2EncodeFrame(H2_FRAME_WINDOW_UPDATE, 0, 0, H2EncodeWindowUpdate(2)) +
    ComposeResponse(1, '200', '', []));
  LConn := TH2ClientConnection.Create(LStream as ITcpStream, LOptions);
  try
    LResp := LConn.RoundTrip(NewRequest(hmPost,
      'http://example.com/conn-window', NewHttpHeaders, LBody as IReader, 4));
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'connection WINDOW_UPDATE response status');
    DecodeFrames(Copy(LStream.WrittenData, Length(H2_CLIENT_PREFACE) + 1,
      MaxInt), LFrames, LCount);
    LFirstDataIndex := FindFrameIndex(LFrames, LCount, H2_FRAME_DATA, 1);
    Check(LFirstDataIndex >= 0, 'first DATA frame exists');
    LSecondDataIndex := -1;
    if LFirstDataIndex >= 0 then
      LSecondDataIndex := FindFrameIndex(Slice(LFrames, LCount), LCount, H2_FRAME_DATA, 1);
  finally
    LResp := nil;
    LConn.Free;
    LConn := nil;
    LStream := nil;
    LBody := nil;
  end;
end;

procedure TestBuiltinHttp2ClientTransportIsRegistered;
var
  LTransport: IHttpTransport;
begin
  LTransport := ResolveClientTransport(hvHttp2, THttpClientOptions.Default);
  Check(LTransport <> nil, 'built-in HTTP/2 client transport resolves');
end;

procedure TestBuildResponseAvoidsBytesStreamCopySourceContract;
var
  LSource: string;
  LBuildPos: SizeInt;
  LHandshakePos: SizeInt;
  LBuildBlock: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(H2_CLIENT_SOURCE_PATH_FROM_TEST,
    H2_CLIENT_SOURCE_PATH_FROM_ROOT));
  LBuildPos := Pos('function TH2ClientConnection.BuildResponse', LSource);
  Check(LBuildPos > 0, 'BuildResponse source block exists');
  LHandshakePos := Pos('function TH2ClientConnection.Handshake', LSource);
  Check(LHandshakePos > LBuildPos, 'Handshake source follows BuildResponse');
  if (LBuildPos <= 0) or (LHandshakePos <= LBuildPos) then
    Exit;
  LBuildBlock := Copy(LSource, LBuildPos, LHandshakePos - LBuildPos);
  Check(Pos('CreateBytesStreamFrom(AResponse.Body)', LBuildBlock) = 0,
    'BuildResponse avoids CreateBytesStreamFrom body copy');
  Check(Pos('TH2ClientResponseBodyReader.Create(AResponse.Body)', LBuildBlock) > 0,
    'BuildResponse uses dedicated H2 response body reader');
end;

begin
  T := TTestRunner.Create('test_http_h2_client');
  T.Run('Handshake writes client preface and settings',
    @TestHandshakeWritesClientPrefaceAndSettings);
  T.Run('RoundTrip GET reads response',
    @TestRoundTripGetReadsResponse);
  T.Run('RoundTrip POST writes data frame',
    @TestRoundTripPostWritesDataFrame);
  T.Run('RoundTrip filters connection-specific request headers',
    @TestRoundTripFiltersConnectionSpecificRequestHeaders);
  T.Run('RoundTrip preserves TE trailers header',
    @TestRoundTripPreservesTeTrailersHeader);
  T.Run('Runtime SETTINGS_INITIAL_WINDOW_SIZE updates active stream',
    @TestRuntimeSettingsInitialWindowSizeUpdatesActiveStream);
  T.Run('Request body reads WINDOW_UPDATE when send window blocked',
    @TestRequestBodyReadsWindowUpdateWhenSendWindowBlocked);
  T.Run('Stream ID increments across requests',
    @TestStreamIdIncrementsAcrossRequests);
  T.Run('GOAWAY marks connection not reusable',
    @TestGoawayMarksConnectionNotReusable);
  T.Run('PUSH_PROMISE triggers PROTOCOL_ERROR GOAWAY',
    @TestPushPromiseTriggersProtocolGoaway);
  T.Run('DATA on connection stream triggers PROTOCOL_ERROR GOAWAY',
    @TestDataOnConnectionStreamTriggersProtocolGoaway);
  T.Run('HEADERS on connection stream triggers PROTOCOL_ERROR GOAWAY',
    @TestHeadersOnConnectionStreamTriggersProtocolGoaway);
  T.Run('CONTINUATION on different stream triggers PROTOCOL_ERROR GOAWAY',
    @TestContinuationOnDifferentStreamTriggersProtocolGoaway);
  T.Run('PING gets acked',
    @TestPingGetsAcked);
  T.Run('Transport reuses pooled connection',
    @TestTransportReusesPooledConnection);
  T.Run('Transport CloseIdleConnections closes pooled conn',
    @TestTransportCloseIdleConnectionsClosesPooledConn);
  T.Run('HTTPS transport negotiates h2 via ALPN',
    @TestHttpsTransportNegotiatesH2ViaALPN);
  T.Run('HTTPS transport rejects unexpected ALPN',
    @TestHttpsTransportRejectsUnexpectedALPN);
  T.Run('H2 TLS server transport dispatches negotiated h2',
    @TestH2TlsServerTransportDispatchesNegotiatedH2);
  T.Run('H2 TLS server transport rejects missing h2 ALPN',
    @TestH2TlsServerTransportRejectsMissingH2ALPN);
  T.Run('BuildResponse avoids bytes stream copy source contract',
    @TestBuildResponseAvoidsBytesStreamCopySourceContract);
  T.Run('Built-in HTTP/2 client transport is registered',
    @TestBuiltinHttp2ClientTransportIsRegistered);
  T.Run('Handshake fails without initial server SETTINGS',
    @TestHandshakeFailsWithoutServerSettings);
  T.Run('Handshake fails on initial SETTINGS ACK',
    @TestHandshakeFailsOnSettingsAckFirst);
  T.Run('Server RST_STREAM CANCEL marks response reset',
    @TestServerRstStreamWithCancelMarksResponseReset);
  T.Run('Server RST_STREAM NO_ERROR aborts response',
    @TestServerRstStreamWithNoErrorAbortsResponse);
  T.Run('Server RST_STREAM propagates error code',
    @TestServerRstStreamPropagatesErrorCode);
  T.Run('Invalid SETTINGS payload fails connection',
    @TestInvalidSettingsPayloadFailsConnection);
  T.Run('WINDOW_UPDATE zero increment fails connection',
    @TestWindowUpdateZeroIncrementFailsConnection);
  T.Run('WINDOW_UPDATE on unknown stream is ignored',
    @TestWindowUpdateOnUnknownStreamIgnored);
  T.Run('Connection WINDOW_UPDATE increases send window',
    @TestConnectionWindowUpdateIncreasesSendWindow);
  T.Run('GOAWAY with active stream completes current request',
    @TestGoawayWithActiveStreamCompletesCurrentRequest);
  T.Run('Multiple GOAWAY with decreasing last stream is accepted',
    @TestMultipleGoawayWithDecreasingLastStreamAccepted);
  T.Run('GOAWAY after graceful drain marks not reusable',
    @TestGoawayAfterGracefulDrainMarksNotReusable);
  T.Run('RoundTrip on closed connection throws',
    @TestRoundTripOnClosedConnectionThrows);
  T.Run('HEAD-only response reads empty body',
    @TestHeadOnlyResponseReadsEmptyBody);
  T.Run('Multiple DATA frames deliver concatenated body',
    @TestMultipleDataFramesDeliverConcatenatedBody);
  T.Run('Padded DATA delivers unpadded body',
    @TestPaddedDataDeliversUnpaddedBody);
  T.Run('Padded HEADERS parses correctly',
    @TestPaddedHeadersParsesCorrectly);
  T.Run('CONTINUATION reassembles response headers',
    @TestContinuationReassemblesResponseHeaders);
  T.Summary;
end.
