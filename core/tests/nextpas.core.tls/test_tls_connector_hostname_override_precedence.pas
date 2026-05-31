program test_tls_connector_hostname_override_precedence;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.connection.base,
  nextpas.core.tls.tls;

type
  TMockClientConnection = class(TBaseSSLConnection, ISSLClientConnection)
  private
    FServerName: string;
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

    procedure SetServerName(const AServerName: string);
    function GetServerName: string;
  end;

  TMockContext = class(TInterfacedObject, ISSLContext)
  private
    FContextType: TSSLContextType;
    FServerName: string;
  public
    constructor Create(AContextType: TSSLContextType);

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

constructor TMockClientConnection.Create(AContext: ISSLContext);
begin
  inherited Create(AContext);
  FServerName := '';
end;

procedure TMockClientConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TMockClientConnection.GetServerName: string;
begin
  Result := FServerName;
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
end;

function TMockClientConnection.DoIsSessionReused: Boolean;
begin
  Result := False;
end;

function TMockClientConnection.DoGetSelectedALPNProtocol: string;
begin
  Result := '';
end;

function TMockClientConnection.DoGetState: string;
begin
  Result := 'MOCK';
end;

function TMockClientConnection.DoGetNativeHandle: Pointer;
begin
  Result := nil;
end;

constructor TMockContext.Create(AContextType: TSSLContextType);
begin
  inherited Create;
  FContextType := AContextType;
  FServerName := '';
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

procedure TMockContext.LoadPrivateKey(const AFileName: string; const APassword: string);
begin
end;

procedure TMockContext.LoadPrivateKey(AStream: TStream; const APassword: string);
begin
end;

procedure TMockContext.LoadCertificatePEM(const APEM: string);
begin
end;

procedure TMockContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string);
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

procedure TMockContext.AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
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
  Conn := TMockClientConnection.Create(Self);
  Conn.SetServerName(FServerName);
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

procedure RunCase(const ACaseName, AInputHost, AExpectedServerName: string);
var
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  Transport: TMemoryStream;
  TLSStream: TSSLStream;
  ClientConn: ISSLClientConnection;
begin
  WriteLn('=== ', ACaseName, ' ===');
  Ctx := TMockContext.Create(sslCtxClient);
  Connector := TSSLConnector.FromContext(Ctx);
  Transport := TMemoryStream.Create;
  TLSStream := nil;
  try
    TLSStream := Connector.ConnectStream(Transport, AInputHost);
    Check(TLSStream <> nil, 'ConnectStream should succeed');
    Check(Supports(TLSStream.Connection, ISSLClientConnection, ClientConn),
      'Connection supports ISSLClientConnection');
    CheckEqualsStr('Connection server name matches precedence',
      AExpectedServerName, ClientConn.GetServerName);
  finally
    TLSStream.Free;
    Transport.Free;
  end;
end;

begin
  WriteLn('[TEST] TLS connector hostname override precedence');

  RunCase('Case 1: non-empty override wins', 'override.example', 'override.example');
  RunCase('Case 2: empty override remains empty', '', '');

  WriteLn('---');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed = 0 then
    Halt(0);
  Halt(1);
end.
