program test_base_connection_time_metrics;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.connection.base;

type
  TMockBaseConnection = class(TBaseSSLConnection)
  private
    FConnectDelayMs: Int64;
    FAcceptDelayMs: Int64;
    FHandshakeDelayMs: Int64;
    FReadDelayMs: Int64;
    FReadPayload: AnsiString;
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
    constructor Create; reintroduce;
    procedure BackdateConnectTime(ASeconds: Int64);
    procedure EmitSyntheticError(ACode: TSSLErrorCode; const AMessage: string);
  end;

var
  GTotal: Integer = 0;
  GPassed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(GTotal);
  if not ACondition then
  begin
    WriteLn('[FAIL] ', AMessage);
    Halt(1);
  end;

  Inc(GPassed);
  WriteLn('[PASS] ', AMessage);
end;

{ TMockBaseConnection }

constructor TMockBaseConnection.Create;
begin
  inherited Create(nil);
  FConnectDelayMs := 15;
  FAcceptDelayMs := 12;
  FHandshakeDelayMs := 9;
  FReadDelayMs := 7;
  FReadPayload := 'ping';
end;

procedure TMockBaseConnection.BackdateConnectTime(ASeconds: Int64);
begin
  FConnectTime := DateTimeAddSeconds(DateTimeNow, -ASeconds);
end;

procedure TMockBaseConnection.EmitSyntheticError(ACode: TSSLErrorCode;
  const AMessage: string);
begin
  RecordError(ACode, AMessage);
end;

function TMockBaseConnection.DoRead(var ABuffer; ACount: Integer): Integer;
begin
  if FReadDelayMs > 0 then
    TSleep.ForDuration(TDuration.FromMilliseconds(FReadDelayMs));

  Result := Length(FReadPayload);
  if Result > ACount then
    Result := ACount;

  if Result > 0 then
    Move(Pointer(FReadPayload)^, ABuffer, Result);
end;

function TMockBaseConnection.DoWrite(const ABuffer; ACount: Integer): Integer;
begin
  Result := ACount;
end;

function TMockBaseConnection.DoConnect: Boolean;
begin
  if FConnectDelayMs > 0 then
    TSleep.ForDuration(TDuration.FromMilliseconds(FConnectDelayMs));
  Result := True;
end;

function TMockBaseConnection.DoAccept: Boolean;
begin
  if FAcceptDelayMs > 0 then
    TSleep.ForDuration(TDuration.FromMilliseconds(FAcceptDelayMs));
  Result := True;
end;

function TMockBaseConnection.DoHandshakeInternal: TSSLHandshakeState;
begin
  if FHandshakeDelayMs > 0 then
    TSleep.ForDuration(TDuration.FromMilliseconds(FHandshakeDelayMs));
  Result := sslHsCompleted;
end;

function TMockBaseConnection.DoShutdown: Boolean;
begin
  Result := True;
end;

procedure TMockBaseConnection.DoClose;
begin
end;

function TMockBaseConnection.DoRenegotiate: Boolean;
begin
  Result := True;
end;

function TMockBaseConnection.DoGetError(ARet: Integer): TSSLErrorCode;
begin
  Result := sslErrIO;
end;

function TMockBaseConnection.DoWantRead: Boolean;
begin
  Result := False;
end;

function TMockBaseConnection.DoWantWrite: Boolean;
begin
  Result := False;
end;

function TMockBaseConnection.DoGetProtocolVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolTLS12;
end;

function TMockBaseConnection.DoGetCipherName: string;
begin
  Result := 'TLS_AES_128_GCM_SHA256';
end;

function TMockBaseConnection.DoGetPeerCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockBaseConnection.DoGetPeerCertificateChain: TSSLCertificateArray;
begin
  Result := nil;
end;

function TMockBaseConnection.DoGetVerifyResult: Integer;
begin
  Result := 0;
end;

function TMockBaseConnection.DoGetVerifyResultString: string;
begin
  Result := 'ok';
end;

function TMockBaseConnection.DoGetSession: ISSLSession;
begin
  Result := nil;
end;

procedure TMockBaseConnection.DoSetSession(ASession: ISSLSession);
begin
end;

function TMockBaseConnection.DoIsSessionReused: Boolean;
begin
  Result := False;
end;

function TMockBaseConnection.DoGetSelectedALPNProtocol: string;
begin
  Result := 'h2';
end;

function TMockBaseConnection.DoGetState: string;
begin
  Result := 'mock';
end;

function TMockBaseConnection.DoGetNativeHandle: Pointer;
begin
  Result := nil;
end;

procedure TestConnectAndReadPopulateDiagnostics;
var
  LConn: TMockBaseConnection;
  LConnRef: ISSLConnection;
  LDiag: ISSLDiagnostics;
  LMetrics: TSSLPerformanceMetrics;
  LHealth: TSSLHealthStatus;
  LDiagInfo: TSSLDiagnosticInfo;
  LBuffer: array[0..15] of Byte;
begin
  WriteLn('=== connect/read diagnostics ===');
  LConn := TMockBaseConnection.Create;
  LConnRef := LConn;
  try
    Check(LConn.Connect, 'Connect succeeds');
    Check(Supports(LConnRef, ISSLDiagnostics, LDiag),
      'Mock connection exposes ISSLDiagnostics');
    Check(LConn.Read(LBuffer, SizeOf(LBuffer)) = 4,
      'Read returns expected payload length');
    Check(LConn.Write(LBuffer, 3) = 3,
      'Write returns requested byte count');

    LMetrics := LDiag.GetPerformanceMetrics;
    Check(LMetrics.HandshakeTime > 0,
      'HandshakeTime records delayed connect duration');
    Check(LMetrics.FirstByteTime > 0,
      'FirstByteTime records delayed first read');
    Check(LMetrics.TotalBytesTransferred = 7,
      'TotalBytesTransferred includes read and write counts');
    Check(not LMetrics.SessionReused,
      'SessionReused stays false for fresh mock connection');

    LConn.BackdateConnectTime(5);
    LHealth := LDiag.GetHealthStatus;
    Check(LHealth.IsConnected, 'Health reports connected state');
    Check(LHealth.HandshakeComplete, 'Health reports completed handshake');
    Check(LHealth.ConnectionAge >= 5,
      'ConnectionAge reports seconds derived from connect time');
    Check(LHealth.LastError = sslErrNone,
      'Health starts with no error after successful connect');

    LDiagInfo := LDiag.GetDiagnosticInfo;
    Check(LDiagInfo.HealthStatus.ConnectionAge >= 5,
      'DiagnosticInfo mirrors health connection age');
    Check(LDiagInfo.PerformanceMetrics.FirstByteTime > 0,
      'DiagnosticInfo mirrors first-byte metrics');
  finally
    LDiag := nil;
    LConnRef := nil;
  end;
end;

procedure TestAcceptAndHandshakePopulateTimingMetrics;
var
  LConn: TMockBaseConnection;
  LConnRef: ISSLConnection;
  LDiag: ISSLDiagnostics;
  LMetrics: TSSLPerformanceMetrics;
begin
  WriteLn('=== accept/handshake metrics ===');
  LConn := TMockBaseConnection.Create;
  LConnRef := LConn;
  try
    Check(LConn.Accept, 'Accept succeeds');
    Check(Supports(LConnRef, ISSLDiagnostics, LDiag),
      'Accepted mock connection exposes ISSLDiagnostics');

    LMetrics := LDiag.GetPerformanceMetrics;
    Check(LMetrics.HandshakeTime > 0,
      'Accept path records handshake duration');

    LConn.Close;
    Check(LConn.DoHandshake = sslHsCompleted,
      'DoHandshake completes successfully after close reset');

    LMetrics := LDiag.GetPerformanceMetrics;
    Check(LMetrics.HandshakeTime > 0,
      'Explicit DoHandshake records handshake duration');
  finally
    LDiag := nil;
    LConnRef := nil;
  end;
end;

procedure TestErrorHistoryTracksTimestamps;
var
  LConn: TMockBaseConnection;
  LConnRef: ISSLConnection;
  LDiag: ISSLDiagnostics;
  LHealth: TSSLHealthStatus;
  LDiagInfo: TSSLDiagnosticInfo;
begin
  WriteLn('=== error history timing ===');
  LConn := TMockBaseConnection.Create;
  LConnRef := LConn;
  try
    Check(LConn.Connect, 'Connect succeeds before synthetic error');
    Check(Supports(LConnRef, ISSLDiagnostics, LDiag),
      'Error-history probe exposes ISSLDiagnostics');

    LConn.EmitSyntheticError(sslErrIO, 'synthetic error');
    LHealth := LDiag.GetHealthStatus;
    Check(LHealth.LastError = sslErrIO,
      'Health reports latest synthetic error code');
    Check(LHealth.LastErrorTime > 0,
      'Health reports a non-zero latest error timestamp');

    LDiagInfo := LDiag.GetDiagnosticInfo;
    Check(Length(LDiagInfo.ErrorHistory) = 1,
      'DiagnosticInfo returns single synthetic error entry');
    Check(LDiagInfo.ErrorHistory[0].Timestamp > 0,
      'Error history stores non-zero timestamp');
    Check(LDiagInfo.ErrorHistory[0].ErrorMessage = 'synthetic error',
      'Error history preserves synthetic error message');
  finally
    LDiag := nil;
    LConnRef := nil;
  end;
end;

begin
  WriteLn('Base Connection Time Metrics Test');
  TestConnectAndReadPopulateDiagnostics;
  TestAcceptAndHandshakePopulateTimingMetrics;
  TestErrorHistoryTracksTimestamps;
  WriteLn;
  WriteLn('Tests: ', GPassed, '/', GTotal, ' passed');
end.
