program test_tls_connector_early_data_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.connection.base,
  nextpas.core.tls.tls,
  nextpas.core.tls.exceptions;

type
  IMockConnectorProbe = interface
    ['{E71E35E7-5428-4C5B-8DFA-4D617274F6F0}']
    function GetObservedCallLog: string;
    function GetObservedServerName: string;
    function GetObservedALPN: string;
    function GetObservedEarlyDataText: string;
    function GetObservedEarlyDataCalls: Integer;
    function WasSessionApplied: Boolean;
  end;

  TMockSession = class(TInterfacedObject, ISSLSession)
  private
    FID: string;
  public
    constructor Create(const AID: string);

    function GetID: string;
    function GetCreationTime: TDateTime;
    function GetTimeout: Integer;
    procedure SetTimeout(ATimeout: Integer);
    function IsValid: Boolean;
    function IsResumable: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
    function Serialize: TBytes;
    function Deserialize(const AData: TBytes): Boolean;
    function Clone: ISSLSession;
  end;

  TMockClientConnection = class(TBaseSSLConnection, ISSLClientConnection,
    ISSLClientALPNConnection, IMockConnectorProbe)
  private
    FServerName: string;
    FObservedALPN: string;
    FCallLog: string;
    FSessionApplied: Boolean;
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
    constructor Create(AContext: ISSLContext); override;

    procedure InheritServerNameWithoutObservation(const AServerName: string);
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;
    procedure SetALPNProtocols(const AProtocols: string);
    function GetALPNProtocols: string;

    function GetObservedCallLog: string;
    function GetObservedServerName: string;
    function GetObservedALPN: string;
    function GetObservedEarlyDataText: string; virtual;
    function GetObservedEarlyDataCalls: Integer; virtual;
    function WasSessionApplied: Boolean;
  end;

  TMockEarlyDataClientConnection = class(TMockClientConnection, ISSLEarlyDataConnection)
  private
    FEarlyDataText: string;
    FEarlyDataCalls: Integer;
  public
    function SetEarlyData(const AData: TBytes): TSSLOperationResult;
    function GetEarlyDataStatus: TSSLEarlyDataStatus;
    function GetEarlyDataLimit: Cardinal;

    function GetObservedEarlyDataText: string; override;
    function GetObservedEarlyDataCalls: Integer; override;
  end;

  TMockContext = class(TInterfacedObject, ISSLContext)
  private
    FContextType: TSSLContextType;
    FServerName: string;
    FSupportsEarlyData: Boolean;
    FLastProbe: IMockConnectorProbe;
  public
    constructor Create(AContextType: TSSLContextType; ASupportsEarlyData: Boolean);

    function GetLastProbe: IMockConnectorProbe;
    procedure ClearLastProbe;
    function GetContextType: TSSLContextType;

    procedure SetProtocolVersions(AVersions: TSSLProtocolVersions);
    function GetProtocolVersions: TSSLProtocolVersions;
    procedure SetPreferredVersion(AVersion: TSSLProtocolVersion);
    function GetPreferredVersion: TSSLProtocolVersion;

    procedure LoadCertificate(const AFileName: string); overload;
    procedure LoadCertificate(AStream: TStream); overload;
    procedure LoadCertificate(ACert: ISSLCertificate); overload;

    procedure LoadPrivateKey(const AFileName: string; const APassword: string = ''); overload;
    procedure LoadPrivateKey(AStream: TStream; const APassword: string = ''); overload;

    procedure LoadCertificatePEM(const APEM: string);
    procedure LoadPrivateKeyPEM(const APEM: string; const APassword: string = '');

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
    procedure AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure SetCertificatePinningEnabled(AEnabled: Boolean);
    function GetCertificatePinningEnabled: Boolean;
    procedure ClearCertificatePins;

    function CreateConnection(ASocket: THandle): ISSLConnection; overload;
    function CreateConnection(AStream: TStream): ISSLConnection; overload;
    function IsValid: Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure CheckEqualsStr(const AMessage, AExpected, AActual: string);
begin
  Check(AExpected = AActual,
    AMessage + ' (expected="' + AExpected + '", actual="' + AActual + '")');
end;

function BytesToText(const AData: TBytes): string;
begin
  if Length(AData) = 0 then
    Exit('');
  SetString(Result, PAnsiChar(@AData[0]), Length(AData));
end;

{ TMockSession }

constructor TMockSession.Create(const AID: string);
begin
  inherited Create;
  FID := AID;
end;

function TMockSession.GetID: string;
begin
  Result := FID;
end;

function TMockSession.GetCreationTime: TDateTime;
begin
  Result := Now;
end;

function TMockSession.GetTimeout: Integer;
begin
  Result := 300;
end;

procedure TMockSession.SetTimeout(ATimeout: Integer);
begin
end;

function TMockSession.IsValid: Boolean;
begin
  Result := True;
end;

function TMockSession.IsResumable: Boolean;
begin
  Result := True;
end;

function TMockSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolTLS13;
end;

function TMockSession.GetCipherName: string;
begin
  Result := 'MOCK-CIPHER';
end;

function TMockSession.GetPeerCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockSession.Serialize: TBytes;
begin
  Result := nil;
end;

function TMockSession.Deserialize(const AData: TBytes): Boolean;
begin
  Result := True;
end;

function TMockSession.Clone: ISSLSession;
begin
  Result := TMockSession.Create(FID);
end;

{ TMockClientConnection }

constructor TMockClientConnection.Create(AContext: ISSLContext);
begin
  inherited Create(AContext);
  FServerName := '';
  FObservedALPN := '';
  FCallLog := '';
  FSessionApplied := False;
end;

procedure TMockClientConnection.AppendCall(const AName: string);
begin
  if FCallLog <> '' then
    FCallLog := FCallLog + '>';
  FCallLog := FCallLog + AName;
end;

procedure TMockClientConnection.InheritServerNameWithoutObservation(
  const AServerName: string);
begin
  FServerName := AServerName;
end;

procedure TMockClientConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
  AppendCall('servername');
end;

function TMockClientConnection.GetServerName: string;
begin
  Result := FServerName;
end;

function TMockClientConnection.GetObservedCallLog: string;
begin
  Result := FCallLog;
end;

function TMockClientConnection.GetObservedServerName: string;
begin
  Result := FServerName;
end;

function TMockClientConnection.GetObservedALPN: string;
begin
  Result := FObservedALPN;
end;

procedure TMockClientConnection.SetALPNProtocols(const AProtocols: string);
begin
  FObservedALPN := AProtocols;
  AppendCall('alpn');
end;

function TMockClientConnection.GetALPNProtocols: string;
begin
  Result := FObservedALPN;
end;

function TMockClientConnection.GetObservedEarlyDataText: string;
begin
  Result := '';
end;

function TMockClientConnection.GetObservedEarlyDataCalls: Integer;
begin
  Result := 0;
end;

function TMockClientConnection.WasSessionApplied: Boolean;
begin
  Result := FSessionApplied;
end;

function TMockClientConnection.DoRead(var ABuffer; ACount: Integer): Integer;
begin
  Result := 0;
end;

function TMockClientConnection.DoWrite(const ABuffer; ACount: Integer): Integer;
begin
  Result := ACount;
end;

function TMockClientConnection.DoConnect: Boolean;
begin
  AppendCall('connect');
  Result := True;
end;

function TMockClientConnection.DoAccept: Boolean;
begin
  Result := True;
end;

function TMockClientConnection.DoHandshakeInternal: TSSLHandshakeState;
begin
  Result := sslHsCompleted;
end;

function TMockClientConnection.DoShutdown: Boolean;
begin
  Result := True;
end;

procedure TMockClientConnection.DoClose;
begin
end;

function TMockClientConnection.DoRenegotiate: Boolean;
begin
  Result := False;
end;

function TMockClientConnection.DoGetError(ARet: Integer): TSSLErrorCode;
begin
  Result := sslErrNone;
end;

function TMockClientConnection.DoWantRead: Boolean;
begin
  Result := False;
end;

function TMockClientConnection.DoWantWrite: Boolean;
begin
  Result := False;
end;

function TMockClientConnection.DoGetProtocolVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolTLS13;
end;

function TMockClientConnection.DoGetCipherName: string;
begin
  Result := 'MOCK-CIPHER';
end;

function TMockClientConnection.DoGetPeerCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockClientConnection.DoGetPeerCertificateChain: TSSLCertificateArray;
begin
  Result := nil;
end;

function TMockClientConnection.DoGetVerifyResult: Integer;
begin
  Result := 0;
end;

function TMockClientConnection.DoGetVerifyResultString: string;
begin
  Result := 'OK';
end;

function TMockClientConnection.DoGetSession: ISSLSession;
begin
  Result := nil;
end;

procedure TMockClientConnection.DoSetSession(ASession: ISSLSession);
begin
  FSessionApplied := ASession <> nil;
  AppendCall('session');
end;

function TMockClientConnection.DoIsSessionReused: Boolean;
begin
  Result := FSessionApplied;
end;

function TMockClientConnection.DoGetSelectedALPNProtocol: string;
begin
  Result := FObservedALPN;
end;

function TMockClientConnection.DoGetState: string;
begin
  Result := 'MOCK';
end;

function TMockClientConnection.DoGetNativeHandle: Pointer;
begin
  Result := nil;
end;

{ TMockEarlyDataClientConnection }

function TMockEarlyDataClientConnection.SetEarlyData(
  const AData: TBytes): TSSLOperationResult;
begin
  Inc(FEarlyDataCalls);
  FEarlyDataText := BytesToText(AData);
  AppendCall('earlydata');
  Result := TSSLOperationResult.Ok;
end;

function TMockEarlyDataClientConnection.GetEarlyDataStatus: TSSLEarlyDataStatus;
begin
  if FEarlyDataCalls > 0 then
    Result := sslEarlyDataQueued
  else
    Result := sslEarlyDataNone;
end;

function TMockEarlyDataClientConnection.GetEarlyDataLimit: Cardinal;
begin
  Result := 8;
end;

function TMockEarlyDataClientConnection.GetObservedEarlyDataText: string;
begin
  Result := FEarlyDataText;
end;

function TMockEarlyDataClientConnection.GetObservedEarlyDataCalls: Integer;
begin
  Result := FEarlyDataCalls;
end;

{ TMockContext }

constructor TMockContext.Create(AContextType: TSSLContextType;
  ASupportsEarlyData: Boolean);
begin
  inherited Create;
  FContextType := AContextType;
  FServerName := '';
  FSupportsEarlyData := ASupportsEarlyData;
  FLastProbe := nil;
end;

function TMockContext.GetLastProbe: IMockConnectorProbe;
begin
  Result := FLastProbe;
end;

procedure TMockContext.ClearLastProbe;
begin
  FLastProbe := nil;
end;

function TMockContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TMockContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
end;

function TMockContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := [];
end;

procedure TMockContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
end;

function TMockContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolUnknown;
end;

procedure TMockContext.LoadCertificate(const AFileName: string);
begin
end;

procedure TMockContext.LoadCertificate(AStream: TStream);
begin
end;

procedure TMockContext.LoadCertificate(ACert: ISSLCertificate);
begin
end;

procedure TMockContext.LoadPrivateKey(const AFileName: string;
  const APassword: string);
begin
end;

procedure TMockContext.LoadPrivateKey(AStream: TStream;
  const APassword: string);
begin
end;

procedure TMockContext.LoadCertificatePEM(const APEM: string);
begin
end;

procedure TMockContext.LoadPrivateKeyPEM(const APEM: string;
  const APassword: string);
begin
end;

procedure TMockContext.LoadCAFile(const AFileName: string);
begin
end;

procedure TMockContext.LoadCAPath(const APath: string);
begin
end;

procedure TMockContext.SetCertificateStore(AStore: ISSLCertificateStore);
begin
end;

procedure TMockContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
end;

function TMockContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := [];
end;

procedure TMockContext.SetVerifyDepth(ADepth: Integer);
begin
end;

function TMockContext.GetVerifyDepth: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
end;

procedure TMockContext.SetCipherList(const ACipherList: string);
begin
end;

function TMockContext.GetCipherList: string;
begin
  Result := '';
end;

procedure TMockContext.SetCipherSuites(const ACipherSuites: string);
begin
end;

function TMockContext.GetCipherSuites: string;
begin
  Result := '';
end;

procedure TMockContext.SetSessionCacheMode(AEnabled: Boolean);
begin
end;

function TMockContext.GetSessionCacheMode: Boolean;
begin
  Result := False;
end;

procedure TMockContext.SetSessionTimeout(ATimeout: Integer);
begin
end;

function TMockContext.GetSessionTimeout: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetSessionCacheSize(ASize: Integer);
begin
end;

function TMockContext.GetSessionCacheSize: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetOptions(const AOptions: TSSLOptions);
begin
end;

function TMockContext.GetOptions: TSSLOptions;
begin
  Result := [];
end;

procedure TMockContext.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TMockContext.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TMockContext.SetALPNProtocols(const AProtocols: string);
begin
end;

function TMockContext.GetALPNProtocols: string;
begin
  Result := '';
end;

procedure TMockContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
end;

function TMockContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := [];
end;

procedure TMockContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
end;

procedure TMockContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
end;

procedure TMockContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
end;

procedure TMockContext.AddCertificatePinBase64(const ABase64Hash: string;
  APinType: Integer; const ADescription: string; AIsBackup: Boolean);
begin
end;

procedure TMockContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
end;

function TMockContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := False;
end;

procedure TMockContext.ClearCertificatePins;
begin
end;

function TMockContext.CreateConnection(ASocket: THandle): ISSLConnection;
var
  Conn: TMockClientConnection;
begin
  if FSupportsEarlyData then
    Conn := TMockEarlyDataClientConnection.Create(Self)
  else
    Conn := TMockClientConnection.Create(Self);

  Conn.InheritServerNameWithoutObservation(FServerName);
  FLastProbe := Conn as IMockConnectorProbe;
  Result := Conn;
end;

function TMockContext.CreateConnection(AStream: TStream): ISSLConnection;
begin
  Result := CreateConnection(THandle(1));
end;

function TMockContext.IsValid: Boolean;
begin
  Result := True;
end;

procedure TestSupportedConnectorQueuesEarlyDataBeforeConnect;
var
  CtxObj: TMockContext;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  Transport: TMemoryStream;
  TLSStream: TSSLStream;
  Probe: IMockConnectorProbe;
begin
  WriteLn('=== Supported connector early-data queue ===');

  CtxObj := TMockContext.Create(sslCtxClient, True);
  Ctx := CtxObj;

  Connector := TSSLConnector.FromContext(Ctx)
    .WithSession(TMockSession.Create('connector-session'))
    .WithEarlyData(BytesOf('PING'));

  Transport := TMemoryStream.Create;
  TLSStream := nil;
  try
    TLSStream := Connector.ConnectStream(Transport, 'early.example.com');
    Check(TLSStream <> nil, 'ConnectStream should succeed when early-data interface is supported');

    Probe := TLSStream.Connection as IMockConnectorProbe;
    Check(Probe.WasSessionApplied, 'Connector should apply the configured session before connect');
    CheckEqualsStr('Connector should apply the explicit server name',
      'early.example.com', Probe.GetObservedServerName);
    CheckEqualsStr('Connector should queue early data before connect',
      'PING', Probe.GetObservedEarlyDataText);
    Check(Probe.GetObservedEarlyDataCalls = 1,
      'Connector should queue early data exactly once');
    CheckEqualsStr('Connector should preserve session -> servername -> earlydata -> connect ordering',
      'session>servername>earlydata>connect', Probe.GetObservedCallLog);
  finally
    CtxObj.ClearLastProbe;
    Ctx := nil;
    TLSStream.Free;
    Transport.Free;
  end;
end;

procedure TestEmptyEarlyDataDoesNotQueuePayload;
var
  CtxObj: TMockContext;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  Transport: TMemoryStream;
  TLSStream: TSSLStream;
  Probe: IMockConnectorProbe;
begin
  WriteLn('=== Empty connector early-data payload ===');

  CtxObj := TMockContext.Create(sslCtxClient, True);
  Ctx := CtxObj;
  Connector := TSSLConnector.FromContext(Ctx)
    .WithSession(TMockSession.Create('connector-empty'))
    .WithEarlyData(nil);

  Transport := TMemoryStream.Create;
  TLSStream := nil;
  try
    TLSStream := Connector.ConnectStream(Transport, 'empty.example.com');
    Check(TLSStream <> nil, 'ConnectStream should still succeed for empty early-data payload');

    Probe := TLSStream.Connection as IMockConnectorProbe;
    Check(Probe.GetObservedEarlyDataCalls = 0,
      'Empty early-data payload should not queue connector early data');
    CheckEqualsStr('Empty early-data payload should skip the earlydata step',
      'session>servername>connect', Probe.GetObservedCallLog);
  finally
    CtxObj.ClearLastProbe;
    Ctx := nil;
    TLSStream.Free;
    Transport.Free;
  end;
end;

procedure TestUnsupportedEarlyDataTryConnectFailsCleanly;
var
  CtxObj: TMockContext;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  Transport: TMemoryStream;
  TLSStream: TSSLStream;
  R: TSSLOperationResult;
begin
  WriteLn('=== Unsupported connector early-data try-connect ===');

  CtxObj := TMockContext.Create(sslCtxClient, False);
  Ctx := CtxObj;
  Connector := TSSLConnector.FromContext(Ctx)
    .WithSession(TMockSession.Create('connector-unsupported'))
    .WithEarlyData(BytesOf('PING'));

  Transport := TMemoryStream.Create;
  TLSStream := nil;
  try
    R := Connector.TryConnectStream(Transport, 'unsupported.example.com', TLSStream);
    Check(R.IsErr, 'TryConnectStream should fail when the connection does not expose early-data');
    Check(R.ErrorCode = sslErrUnsupported,
      'Unsupported connector early-data path should return sslErrUnsupported');
    Check(TLSStream = nil, 'TryConnectStream should not return a stream on early-data setup failure');
  finally
    CtxObj.ClearLastProbe;
    Ctx := nil;
    TLSStream.Free;
    Transport.Free;
  end;
end;

procedure TestUnsupportedEarlyDataConnectRaises;
var
  CtxObj: TMockContext;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  Transport: TMemoryStream;
  Raised: Boolean;
begin
  WriteLn('=== Unsupported connector early-data raising path ===');

  CtxObj := TMockContext.Create(sslCtxClient, False);
  Ctx := CtxObj;
  Connector := TSSLConnector.FromContext(Ctx)
    .WithSession(TMockSession.Create('connector-unsupported-raise'))
    .WithEarlyData(BytesOf('PING'));

  Transport := TMemoryStream.Create;
  try
    Raised := False;
    try
      Connector.ConnectStream(Transport, 'raise.example.com').Free;
    except
      on E: ESSLConnectionException do
        Raised := True;
    end;
    Check(Raised, 'ConnectStream should raise connection exception when early-data setup fails');
  finally
    CtxObj.ClearLastProbe;
    Ctx := nil;
    Transport.Free;
  end;
end;

procedure TestConnectorAppliesExplicitALPNBeforeConnect;
var
  CtxObj: TMockContext;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  Transport: TMemoryStream;
  TLSStream: TSSLStream;
  Probe: IMockConnectorProbe;
begin
  WriteLn('=== Connector explicit ALPN ===');

  CtxObj := TMockContext.Create(sslCtxClient, False);
  Ctx := CtxObj;
  Connector := TSSLConnector.FromContext(Ctx)
    .WithALPN('h2,http/1.1');

  Transport := TMemoryStream.Create;
  TLSStream := nil;
  try
    TLSStream := Connector.ConnectStream(Transport, 'alpn.example.com');
    Check(TLSStream <> nil, 'ConnectStream should succeed with explicit ALPN');

    Probe := TLSStream.Connection as IMockConnectorProbe;
    CheckEqualsStr('Connector should apply the explicit server name',
      'alpn.example.com', Probe.GetObservedServerName);
    CheckEqualsStr('Connector should apply explicit ALPN protocols',
      'h2,http/1.1', Probe.GetObservedALPN);
    CheckEqualsStr('Connector should apply servername -> alpn -> connect ordering',
      'servername>alpn>connect', Probe.GetObservedCallLog);
  finally
    CtxObj.ClearLastProbe;
    Ctx := nil;
    TLSStream.Free;
    Transport.Free;
  end;
end;

begin
  WriteLn('[TEST] TLS connector early-data convenience contract');

  TestSupportedConnectorQueuesEarlyDataBeforeConnect;
  TestEmptyEarlyDataDoesNotQueuePayload;
  TestUnsupportedEarlyDataTryConnectFailsCleanly;
  TestUnsupportedEarlyDataConnectRaises;
  TestConnectorAppliesExplicitALPNBeforeConnect;

  WriteLn('---');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed = 0 then
    Halt(0);
  Halt(1);
end.
