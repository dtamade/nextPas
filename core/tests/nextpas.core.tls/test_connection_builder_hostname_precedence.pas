program test_connection_builder_hostname_precedence;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally seeds deprecated direct context
  ServerName state so the connection builder can prove it clears legacy
  fallback unless callers set an explicit hostname. }

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.connection.base,
  nextpas.core.tls.connection.builder;

type
  TMockCertificate = class(TInterfacedObject, ISSLCertificate)
  private
    FInfo: TSSLCertificateInfo;
    FIssuerCertificate: ISSLCertificate;
  public
    constructor Create(const ASubject, AIssuer, ASerial: string);

    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromStream(AStream: TStream): Boolean;
    function LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
    function LoadFromPEM(const APEM: string): Boolean;
    function LoadFromDER(const ADER: TBytes): Boolean;
    function SaveToFile(const AFileName: string): Boolean;
    function SaveToStream(AStream: TStream): Boolean;
    function SaveToPEM: string;
    function SaveToDER: TBytes;
    function GetInfo: TSSLCertificateInfo;
    function GetSubject: string;
    function GetIssuer: string;
    function GetSerialNumber: string;
    function GetNotBefore: TDateTime;
    function GetNotAfter: TDateTime;
    function GetPublicKey: string;
    function GetPublicKeyAlgorithm: string;
    function GetSignatureAlgorithm: string;
    function GetVersion: Integer;
    function Verify(ACAStore: ISSLCertificateStore): Boolean;
    function VerifyEx(ACAStore: ISSLCertificateStore;
      AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
    function VerifyHostname(const AHostname: string): Boolean;
    function IsExpired: Boolean;
    function IsSelfSigned: Boolean;
    function IsCA: Boolean;
    function GetDaysUntilExpiry: Integer;
    function GetSubjectCN: string;
    function GetExtension(const AOID: string): string;
    function GetSubjectAltNames: TSSLStringArray;
    function GetKeyUsage: TSSLStringArray;
    function GetExtendedKeyUsage: TSSLStringArray;
    function GetFingerprint(AHashType: TSSLHash): string;
    function GetFingerprintSHA1: string;
    function GetFingerprintSHA256: string;
    procedure SetIssuerCertificate(ACert: ISSLCertificate);
    function GetIssuerCertificate: ISSLCertificate;
    function Clone: ISSLCertificate;
  end;

  TMockSession = class(TInterfacedObject, ISSLSession)
  private
    FID: string;
    FPeerCertificate: ISSLCertificate;
  public
    constructor Create(const AID: string; APeerCertificate: ISSLCertificate = nil);

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

  TMockClientConnection = class(TBaseSSLConnection, ISSLClientConnection)
  private
    FServerName: string;
    FSession: ISSLSession;
    FCipherName: string;
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
  public
    constructor Create(AContext: ISSLContext); override;
    procedure SetNegotiatedCipherName(const ACipherName: string);

    { ISSLClientConnection }
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;
  end;

  TMockContext = class(TInterfacedObject, ISSLContext)
  private
    FContextType: TSSLContextType;
    FServerName: string;
    FNextCipherName: string;
  public
    constructor Create(AContextType: TSSLContextType);
    procedure SetNextCipherName(const ACipherName: string);

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
  Check(AExpected = AActual, AMessage + ' (expected="' + AExpected + '", actual="' + AActual + '")');
end;

function ReadConnectionInfo(AConn: ISSLConnection): TSSLConnectionInfo;
var
  LConnInfoAccess: ISSLConnectionInfo;
begin
  Check(Supports(AConn, ISSLConnectionInfo, LConnInfoAccess),
    'Connection supports ISSLConnectionInfo');
  Result := LConnInfoAccess.GetConnectionInfo;
end;

{ TMockSession }

{ TMockCertificate }

constructor TMockCertificate.Create(const ASubject, AIssuer, ASerial: string);
begin
  inherited Create;
  FillChar(FInfo, SizeOf(FInfo), 0);
  FInfo.Subject := ASubject;
  FInfo.Issuer := AIssuer;
  FInfo.SerialNumber := ASerial;
  FInfo.NotBefore := EncodeDate(2026, 1, 1);
  FInfo.NotAfter := EncodeDate(2030, 1, 1);
  FInfo.FingerprintSHA1 := 'mock-sha1';
  FInfo.FingerprintSHA256 := 'mock-sha256';
  FInfo.PublicKeyAlgorithm := 'RSA';
  FInfo.PublicKeySize := 2048;
  FInfo.SignatureAlgorithm := 'sha256WithRSAEncryption';
  FInfo.Version := 3;
  FInfo.IsCA := False;
  FInfo.PathLength := -1;
  FInfo.PathLenConstraint := -1;
  FInfo.KeyUsage := 0;
  SetLength(FInfo.SubjectAltNames, 1);
  FInfo.SubjectAltNames[0] := 'DNS:peer.example.com';
end;

function TMockCertificate.LoadFromFile(const AFileName: string): Boolean;
begin
  Result := False;
end;

function TMockCertificate.LoadFromStream(AStream: TStream): Boolean;
begin
  Result := False;
end;

function TMockCertificate.LoadFromMemory(const AData: Pointer; ASize: Integer): Boolean;
begin
  Result := False;
end;

function TMockCertificate.LoadFromPEM(const APEM: string): Boolean;
begin
  Result := False;
end;

function TMockCertificate.LoadFromDER(const ADER: TBytes): Boolean;
begin
  Result := False;
end;

function TMockCertificate.SaveToFile(const AFileName: string): Boolean;
begin
  Result := False;
end;

function TMockCertificate.SaveToStream(AStream: TStream): Boolean;
begin
  Result := False;
end;

function TMockCertificate.SaveToPEM: string;
begin
  Result := '';
end;

function TMockCertificate.SaveToDER: TBytes;
begin
  Result := nil;
end;

function TMockCertificate.GetInfo: TSSLCertificateInfo;
begin
  Result := FInfo;
end;

function TMockCertificate.GetSubject: string;
begin
  Result := FInfo.Subject;
end;

function TMockCertificate.GetIssuer: string;
begin
  Result := FInfo.Issuer;
end;

function TMockCertificate.GetSerialNumber: string;
begin
  Result := FInfo.SerialNumber;
end;

function TMockCertificate.GetNotBefore: TDateTime;
begin
  Result := FInfo.NotBefore;
end;

function TMockCertificate.GetNotAfter: TDateTime;
begin
  Result := FInfo.NotAfter;
end;

function TMockCertificate.GetPublicKey: string;
begin
  Result := FInfo.PublicKeyAlgorithm;
end;

function TMockCertificate.GetPublicKeyAlgorithm: string;
begin
  Result := FInfo.PublicKeyAlgorithm;
end;

function TMockCertificate.GetSignatureAlgorithm: string;
begin
  Result := FInfo.SignatureAlgorithm;
end;

function TMockCertificate.GetVersion: Integer;
begin
  Result := FInfo.Version;
end;

function TMockCertificate.Verify(ACAStore: ISSLCertificateStore): Boolean;
begin
  Result := False;
end;

function TMockCertificate.VerifyEx(ACAStore: ISSLCertificateStore;
  AFlags: TSSLCertVerifyFlags; out AResult: TSSLCertVerifyResult): Boolean;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  Result := False;
end;

function TMockCertificate.VerifyHostname(const AHostname: string): Boolean;
begin
  Result := False;
end;

function TMockCertificate.IsExpired: Boolean;
begin
  Result := False;
end;

function TMockCertificate.IsSelfSigned: Boolean;
begin
  Result := SameText(FInfo.Subject, FInfo.Issuer);
end;

function TMockCertificate.IsCA: Boolean;
begin
  Result := FInfo.IsCA;
end;

function TMockCertificate.GetDaysUntilExpiry: Integer;
begin
  Result := Trunc(FInfo.NotAfter - Date);
end;

function TMockCertificate.GetSubjectCN: string;
begin
  Result := FInfo.Subject;
end;

function TMockCertificate.GetExtension(const AOID: string): string;
begin
  Result := '';
end;

function TMockCertificate.GetSubjectAltNames: TSSLStringArray;
begin
  Result := FInfo.SubjectAltNames;
end;

function TMockCertificate.GetKeyUsage: TSSLStringArray;
begin
  Result := nil;
end;

function TMockCertificate.GetExtendedKeyUsage: TSSLStringArray;
begin
  Result := nil;
end;

function TMockCertificate.GetFingerprint(AHashType: TSSLHash): string;
begin
  case AHashType of
    sslHashSHA1:
      Result := FInfo.FingerprintSHA1;
    sslHashSHA256:
      Result := FInfo.FingerprintSHA256;
  else
    Result := '';
  end;
end;

function TMockCertificate.GetFingerprintSHA1: string;
begin
  Result := FInfo.FingerprintSHA1;
end;

function TMockCertificate.GetFingerprintSHA256: string;
begin
  Result := FInfo.FingerprintSHA256;
end;

procedure TMockCertificate.SetIssuerCertificate(ACert: ISSLCertificate);
begin
  FIssuerCertificate := ACert;
end;

function TMockCertificate.GetIssuerCertificate: ISSLCertificate;
begin
  Result := FIssuerCertificate;
end;

function TMockCertificate.Clone: ISSLCertificate;
var
  LClone: TMockCertificate;
begin
  LClone := TMockCertificate.Create(FInfo.Subject, FInfo.Issuer, FInfo.SerialNumber);
  LClone.FInfo := FInfo;
  LClone.FIssuerCertificate := FIssuerCertificate;
  Result := LClone;
end;

{ TMockSession }

constructor TMockSession.Create(const AID: string; APeerCertificate: ISSLCertificate);
begin
  inherited Create;
  FID := AID;
  FPeerCertificate := APeerCertificate;
end;

function TMockSession.GetID: string;
begin
  Result := FID;
end;

function TMockSession.GetCreationTime: TDateTime;
begin
  Result := 0;
end;

function TMockSession.GetTimeout: Integer;
begin
  Result := 0;
end;

procedure TMockSession.SetTimeout(ATimeout: Integer);
begin
  // no-op
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
  if FPeerCertificate <> nil then
    Result := FPeerCertificate.Clone
  else
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
  Result := TMockSession.Create(FID, FPeerCertificate);
end;

{ TMockClientConnection }

constructor TMockClientConnection.Create(AContext: ISSLContext);
begin
  inherited Create(AContext);
  FServerName := '';
  FSession := nil;
  FCipherName := 'ECDHE-RSA-AES128-GCM-SHA256';
end;

procedure TMockClientConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

procedure TMockClientConnection.SetNegotiatedCipherName(const ACipherName: string);
begin
  FCipherName := ACipherName;
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
  // no-op
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
  Result := FCipherName;
end;

function TMockClientConnection.DoGetPeerCertificate: ISSLCertificate;
begin
  if FSession <> nil then
    Result := FSession.GetPeerCertificate
  else
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
  Result := FSession;
end;

procedure TMockClientConnection.DoSetSession(ASession: ISSLSession);
begin
  FSession := ASession;
end;

function TMockClientConnection.DoIsSessionReused: Boolean;
begin
  Result := False;
end;

function TMockClientConnection.DoGetConnectionInfoServerName: string;
begin
  Result := FServerName;
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

{ TMockContext }

constructor TMockContext.Create(AContextType: TSSLContextType);
begin
  inherited Create;
  FContextType := AContextType;
  FServerName := '';
  FNextCipherName := 'ECDHE-RSA-AES128-GCM-SHA256';
end;

function TMockContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TMockContext.SetNextCipherName(const ACipherName: string);
begin
  FNextCipherName := ACipherName;
end;

procedure TMockContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
  // no-op
end;

function TMockContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := [];
end;

procedure TMockContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
  // no-op
end;

function TMockContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolUnknown;
end;

procedure TMockContext.LoadCertificate(const AFileName: string);
begin
  // no-op
end;

procedure TMockContext.LoadCertificate(AStream: TStream);
begin
  // no-op
end;

procedure TMockContext.LoadCertificate(ACert: ISSLCertificate);
begin
  // no-op
end;

procedure TMockContext.LoadPrivateKey(const AFileName: string; const APassword: string);
begin
  // no-op
end;

procedure TMockContext.LoadPrivateKey(AStream: TStream; const APassword: string);
begin
  // no-op
end;

procedure TMockContext.LoadCertificatePEM(const APEM: string);
begin
  // no-op
end;

procedure TMockContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string);
begin
  // no-op
end;

procedure TMockContext.LoadCAFile(const AFileName: string);
begin
  // no-op
end;

procedure TMockContext.LoadCAPath(const APath: string);
begin
  // no-op
end;

procedure TMockContext.SetCertificateStore(AStore: ISSLCertificateStore);
begin
  // no-op
end;

procedure TMockContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
  // no-op
end;

function TMockContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := [];
end;

procedure TMockContext.SetVerifyDepth(ADepth: Integer);
begin
  // no-op
end;

function TMockContext.GetVerifyDepth: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
  // no-op
end;

procedure TMockContext.SetCipherList(const ACipherList: string);
begin
  // no-op
end;

function TMockContext.GetCipherList: string;
begin
  Result := '';
end;

procedure TMockContext.SetCipherSuites(const ACipherSuites: string);
begin
  // no-op
end;

function TMockContext.GetCipherSuites: string;
begin
  Result := '';
end;

procedure TMockContext.SetSessionCacheMode(AEnabled: Boolean);
begin
  // no-op
end;

function TMockContext.GetSessionCacheMode: Boolean;
begin
  Result := False;
end;

procedure TMockContext.SetSessionTimeout(ATimeout: Integer);
begin
  // no-op
end;

function TMockContext.GetSessionTimeout: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetSessionCacheSize(ASize: Integer);
begin
  // no-op
end;

function TMockContext.GetSessionCacheSize: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetOptions(const AOptions: TSSLOptions);
begin
  // no-op
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
  // no-op
end;

function TMockContext.GetALPNProtocols: string;
begin
  Result := '';
end;

procedure TMockContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
  // no-op
end;

function TMockContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := [];
end;

procedure TMockContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
  // no-op
end;

procedure TMockContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
  // no-op
end;

procedure TMockContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
  // no-op
end;

procedure TMockContext.AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
  // no-op
end;

procedure TMockContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
  // no-op
end;

function TMockContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := False;
end;

procedure TMockContext.ClearCertificatePins;
begin
  // no-op
end;

function TMockContext.CreateConnection(ASocket: THandle): ISSLConnection;
var
  Conn: TMockClientConnection;
begin
  Conn := TMockClientConnection.Create(Self);
  Conn.SetServerName(FServerName); // simulate context default inheritance
  Conn.SetNegotiatedCipherName(FNextCipherName);
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

procedure RunCases;
var
  MockCtx: TMockContext;
  Ctx: ISSLContext;
  Builder: ISSLConnectionBuilder;
  Conn: ISSLConnection;
  Resumption: ISSLSessionResumption;
  Res: TSSLOperationResult;
  ClientConn: ISSLClientConnection;
  Info: TSSLConnectionInfo;
begin
  MockCtx := TMockContext.Create(sslCtxClient);
  Ctx := MockCtx;
  // INTENTIONAL_COMPAT: keep legacy direct-context input here so the builder
  // precedence contract can prove the client connection no longer inherits it.
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Ctx.SetServerName('ctx.example.com');
  {$POP}

  WriteLn('=== Case 1: no WithHostname clears context fallback ===');
  Builder := TSSLConnectionBuilder.Create
    .WithContext(Ctx)
    .WithSocket(THandle(1));
  Res := Builder.TryBuildClient(Conn);
  Check(Res.Success, 'TryBuildClient should succeed');
  Check(Supports(Conn, ISSLClientConnection, ClientConn), 'Connection supports ISSLClientConnection');
  CheckEqualsStr('ServerName no longer uses context fallback', '', ClientConn.GetServerName);

  WriteLn('=== Case 2: WithHostname overrides context fallback ===');
  Builder := TSSLConnectionBuilder.Create
    .WithContext(Ctx)
    .WithSocket(THandle(1))
    .WithHostname('conn.example.com');
  Res := Builder.TryBuildClient(Conn);
  Check(Res.Success, 'TryBuildClient should succeed');
  Check(Supports(Conn, ISSLClientConnection, ClientConn), 'Connection supports ISSLClientConnection');
  CheckEqualsStr('ServerName overridden', 'conn.example.com', ClientConn.GetServerName);

  WriteLn('=== Case 3: WithHostname(\"\") still clears context fallback ===');
  Builder := TSSLConnectionBuilder.Create
    .WithContext(Ctx)
    .WithSocket(THandle(1))
    .WithHostname('');
  Res := Builder.TryBuildClient(Conn);
  Check(Res.Success, 'TryBuildClient should succeed');
  Check(Supports(Conn, ISSLClientConnection, ClientConn), 'Connection supports ISSLClientConnection');
  CheckEqualsStr('ServerName cleared', '', ClientConn.GetServerName);

  WriteLn('=== Case 4: GetConnectionInfo derives shared cipher-suite id and crypto detail ===');
  MockCtx.SetNextCipherName('TLS_AES_128_GCM_SHA256');
  Builder := TSSLConnectionBuilder.Create
    .WithContext(Ctx)
    .WithSocket(THandle(1))
    .WithHostname('info.example.com');
  Res := Builder.TryBuildClient(Conn);
  Check(Res.Success, 'TryBuildClient should succeed');
  Info := ReadConnectionInfo(Conn);
  CheckEqualsStr('ConnectionInfo.ServerName mirrors ISSLClientConnection.GetServerName',
    'info.example.com', Info.ServerName);
  Check(Info.CipherSuiteId = $1301,
    'ConnectionInfo.CipherSuiteId is derived from the negotiated TLS 1.3 cipher-suite name');
  Check(Info.Cipher = sslCipherAES128GCM,
    'ConnectionInfo.Cipher is derived from the negotiated cipher-suite name');
  Check(Info.Hash = sslHashSHA256,
    'ConnectionInfo.Hash is derived from the negotiated cipher-suite name');
  Check(Info.KeySize = 128,
    'ConnectionInfo.KeySize is derived from the negotiated cipher-suite name');
  Check(Info.MacSize = 16,
    'ConnectionInfo.MacSize is derived as the AEAD tag length for TLS 1.3 GCM suites');

  WriteLn('=== Case 5: GetConnectionInfo preserves legacy key exchange, session identifier and peer certificate ===');
  MockCtx.SetNextCipherName('ECDHE-RSA-AES128-GCM-SHA256');
  Builder := TSSLConnectionBuilder.Create
    .WithContext(Ctx)
    .WithSocket(THandle(1))
    .WithHostname('peer.example.com');
  Res := Builder.TryBuildClient(Conn);
  Check(Res.Success, 'TryBuildClient should succeed');
  Check(Supports(Conn, ISSLSessionResumption, Resumption),
    'Connection supports ISSLSessionResumption');
  Resumption.SetSession(TMockSession.Create(
    'session-123',
    TMockCertificate.Create('CN=peer.example.com', 'CN=Mock Root CA', '01')
  ));
  Check(Conn.Connect, 'Mock connection connect should succeed before reading SessionId');
  Info := ReadConnectionInfo(Conn);
  Check(Info.KeyExchange = sslKexECDHE_RSA,
    'ConnectionInfo.KeyExchange is derived from the negotiated legacy cipher-suite name');
  Check(Info.MacSize = 16,
    'ConnectionInfo.MacSize is derived as the AEAD tag length for legacy GCM suites');
  CheckEqualsStr('ConnectionInfo.SessionId mirrors ISSLSession.GetID',
    'session-123', Info.SessionId);
  CheckEqualsStr('ConnectionInfo.PeerCertificate.Subject mirrors ISSLCertificate.GetInfo',
    'CN=peer.example.com', Info.PeerCertificate.Subject);
  CheckEqualsStr('ConnectionInfo.PeerCertificate.Issuer mirrors ISSLCertificate.GetInfo',
    'CN=Mock Root CA', Info.PeerCertificate.Issuer);

  WriteLn('=== Case 6: GetConnectionInfo does not guess legacy non-AEAD MAC sizes from hash names ===');
  MockCtx.SetNextCipherName('ECDHE-RSA-AES128-SHA256');
  Builder := TSSLConnectionBuilder.Create
    .WithContext(Ctx)
    .WithSocket(THandle(1))
    .WithHostname('legacy.example.com');
  Res := Builder.TryBuildClient(Conn);
  Check(Res.Success, 'TryBuildClient should succeed');
  Info := ReadConnectionInfo(Conn);
  Check(Info.Hash = sslHashSHA256,
    'ConnectionInfo.Hash still reflects the negotiated legacy cipher-suite name');
  Check(Info.MacSize = 0,
    'ConnectionInfo.MacSize stays unset for legacy non-AEAD suites without a stable shared truth source');
end;

begin
  WriteLn('[TEST] Connection builder hostname precedence');
  RunCases;

  WriteLn('---');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed = 0 then
    Halt(0);
  Halt(1);
end.
