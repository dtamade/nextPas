{
  nextpas.core.tls.connection.builder - Fluent SSL Connection Builder
  
  Provides a modern, fluent API for SSL connection configuration, inspired by
  Rust's rustls ConnectionConfig pattern.
  
  Features:
  - Method chaining for readable code
  - Type-safe configuration
  - Safe defaults built-in
  - Separate client/server building
  
  Version: 1.0
  Created: 2025-12-12
}

unit nextpas.core.tls.connection.builder;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.safety;

type
  { Forward declarations }
  ISSLConnectionBuilder = interface;

  {**
   * ISSLConnectionBuilder - Fluent API for SSL connection configuration
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ISSLConnectionBuilder = interface
    ['{A8B9C0D1-E2F3-4567-8901-23456789ABCD}']
    
    // Context configuration
    function WithContext(AContext: ISSLContext): ISSLConnectionBuilder;
    
    // Socket configuration
    function WithSocket(ASocket: THandle): ISSLConnectionBuilder;
    function WithStream(AStream: TStream): ISSLConnectionBuilder;
    
    // Connection options
    function WithTimeout(AMs: Integer): ISSLConnectionBuilder; overload;
    function WithTimeout(const ATimeout: TTimeoutDuration): ISSLConnectionBuilder; overload;
    function WithBlocking(ABlocking: Boolean): ISSLConnectionBuilder;
    function WithHostname(const AHostname: string): ISSLConnectionBuilder;
    
    // Session management
    function WithSession(ASession: ISSLSession): ISSLConnectionBuilder;
    function WithSessionReuse(AEnabled: Boolean): ISSLConnectionBuilder;
    
    // Build methods
    function BuildClient: ISSLConnection;
    function BuildServer: ISSLConnection;
    
    // Try-pattern build methods (non-throwing)
    function TryBuildClient(out AConnection: ISSLConnection): TSSLOperationResult;
    function TryBuildServer(out AConnection: ISSLConnection): TSSLOperationResult;
  end;

  { Factory class for creating connection builders }
  TSSLConnectionBuilder = class
  public
    class function Create: ISSLConnectionBuilder; static;
    class function CreateWithContext(AContext: ISSLContext): ISSLConnectionBuilder; static;
  end;

implementation

uses
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions;

type
  { Internal builder implementation }
  TSSLConnectionBuilderImpl = class(TInterfacedObject, ISSLConnectionBuilder)
  private
    FContext: ISSLContext;
    FSocket: THandle;
    FStream: TStream;
    FTimeout: Integer;
    FBlocking: Boolean;
    FHostname: string;
    FHostnameSet: Boolean;
    FSession: ISSLSession;
    FSessionReuse: Boolean;
    FUseSocket: Boolean;
  public
    constructor Create;
    
    // ISSLConnectionBuilder
    function WithContext(AContext: ISSLContext): ISSLConnectionBuilder;
    function WithSocket(ASocket: THandle): ISSLConnectionBuilder;
    function WithStream(AStream: TStream): ISSLConnectionBuilder;
    function WithTimeout(AMs: Integer): ISSLConnectionBuilder; overload;
    function WithTimeout(const ATimeout: TTimeoutDuration): ISSLConnectionBuilder; overload;
    function WithBlocking(ABlocking: Boolean): ISSLConnectionBuilder;
    function WithHostname(const AHostname: string): ISSLConnectionBuilder;
    function WithSession(ASession: ISSLSession): ISSLConnectionBuilder;
    function WithSessionReuse(AEnabled: Boolean): ISSLConnectionBuilder;
    function BuildClient: ISSLConnection;
    function BuildServer: ISSLConnection;
    function TryBuildClient(out AConnection: ISSLConnection): TSSLOperationResult;
    function TryBuildServer(out AConnection: ISSLConnection): TSSLOperationResult;
  end;

function TimeoutDurationToConnectionTimeout(
  const ATimeout: TTimeoutDuration): Integer;
var
  LMilliseconds: Int64;
begin
  if ATimeout.IsInfinite then
    Exit(-1);

  LMilliseconds := ATimeout.ToMilliseconds;
  if (LMilliseconds < Low(Integer)) or (LMilliseconds > High(Integer)) then
    raise ESSLInvalidArgument.Create(
      'Timeout duration exceeds Integer millisecond range',
      sslErrInvalidParam
    );

  Result := Integer(LMilliseconds);
end;

procedure ReadConnectionVerificationSurface(
  AConnection: ISSLConnection;
  out AVerifyRes: Integer;
  out AVerifyStr: string
);
var
  LCertVerify: ISSLCertificateVerification;
begin
  AVerifyRes := 0;
  AVerifyStr := '';
  if AConnection = nil then
    Exit;

  if Supports(AConnection, ISSLCertificateVerification, LCertVerify) then
  begin
    AVerifyRes := LCertVerify.GetVerifyResult;
    AVerifyStr := LCertVerify.GetVerifyResultString;
  end
  else
  begin
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    AVerifyRes := AConnection.GetVerifyResult;
    AVerifyStr := AConnection.GetVerifyResultString;
    {$POP}
  end;
end;

procedure ApplyConnectionControlOverrides(
  AConnection: ISSLConnection;
  ATimeout: Integer;
  ABlocking: Boolean
);
var
  LConnectionControl: ISSLConnectionControl;
begin
  if AConnection = nil then
    Exit;

  if Supports(AConnection, ISSLConnectionControl, LConnectionControl) then
  begin
    LConnectionControl.SetTimeout(ATimeout);
    LConnectionControl.SetBlocking(ABlocking);
  end
  else
  begin
    AConnection.SetTimeout(ATimeout);
    AConnection.SetBlocking(ABlocking);
  end;
end;

{ TSSLConnectionBuilder }

class function TSSLConnectionBuilder.Create: ISSLConnectionBuilder;
begin
  Result := TSSLConnectionBuilderImpl.Create;
end;

class function TSSLConnectionBuilder.CreateWithContext(AContext: ISSLContext): ISSLConnectionBuilder;
begin
  Result := TSSLConnectionBuilderImpl.Create.WithContext(AContext);
end;

{ TSSLConnectionBuilderImpl }

constructor TSSLConnectionBuilderImpl.Create;
begin
  inherited Create;
  FContext := nil;
  FSocket := 0;
  FStream := nil;
  FTimeout := SSL_DEFAULT_HANDSHAKE_TIMEOUT;
  FBlocking := True;
  FHostname := '';
  FHostnameSet := False;
  FSession := nil;
  FSessionReuse := True;
  FUseSocket := True;
end;

function TSSLConnectionBuilderImpl.WithContext(AContext: ISSLContext): ISSLConnectionBuilder;
begin
  FContext := AContext;
  Result := Self;
end;

function TSSLConnectionBuilderImpl.WithSocket(ASocket: THandle): ISSLConnectionBuilder;
begin
  FSocket := ASocket;
  FStream := nil;
  FUseSocket := True;
  Result := Self;
end;

function TSSLConnectionBuilderImpl.WithStream(AStream: TStream): ISSLConnectionBuilder;
begin
  FStream := AStream;
  FSocket := 0;
  FUseSocket := False;
  Result := Self;
end;

function TSSLConnectionBuilderImpl.WithTimeout(AMs: Integer): ISSLConnectionBuilder;
begin
  FTimeout := AMs;
  Result := Self;
end;

function TSSLConnectionBuilderImpl.WithTimeout(
  const ATimeout: TTimeoutDuration): ISSLConnectionBuilder;
begin
  Result := WithTimeout(TimeoutDurationToConnectionTimeout(ATimeout));
end;

function TSSLConnectionBuilderImpl.WithBlocking(ABlocking: Boolean): ISSLConnectionBuilder;
begin
  FBlocking := ABlocking;
  Result := Self;
end;

function TSSLConnectionBuilderImpl.WithHostname(const AHostname: string): ISSLConnectionBuilder;
begin
  FHostname := AHostname;
  FHostnameSet := True;
  Result := Self;
end;

function TSSLConnectionBuilderImpl.WithSession(ASession: ISSLSession): ISSLConnectionBuilder;
begin
  FSession := ASession;
  Result := Self;
end;

function TSSLConnectionBuilderImpl.WithSessionReuse(AEnabled: Boolean): ISSLConnectionBuilder;
begin
  FSessionReuse := AEnabled;
  Result := Self;
end;

function TSSLConnectionBuilderImpl.BuildClient: ISSLConnection;
var
  LResult: TSSLOperationResult;
begin
  LResult := TryBuildClient(Result);
  if not LResult.Success then
    raise ESSLConnectionException.CreateWithContext(
      LResult.ErrorMessage,
      LResult.ErrorCode,
      'TSSLConnectionBuilder.BuildClient'
    );
end;

function TSSLConnectionBuilderImpl.BuildServer: ISSLConnection;
var
  LResult: TSSLOperationResult;
begin
  LResult := TryBuildServer(Result);
  if not LResult.Success then
    raise ESSLConnectionException.CreateWithContext(
      LResult.ErrorMessage,
      LResult.ErrorCode,
      'TSSLConnectionBuilder.BuildServer'
    );
end;

function TSSLConnectionBuilderImpl.TryBuildClient(out AConnection: ISSLConnection): TSSLOperationResult;
var
  VerifyRes: Integer;
  VerifyStr: string;
  ClientConn: ISSLClientConnection;
  SessionResumption: ISSLSessionResumption;
begin
  AConnection := nil;
  
  // Validate required fields
  if FContext = nil then
  begin
    Result := TSSLOperationResult.Err(sslErrInvalidParam, 'Context is required');
    Exit;
  end;
  
  if FUseSocket and (FSocket = 0) then
  begin
    Result := TSSLOperationResult.Err(sslErrInvalidParam, 'Socket is required');
    Exit;
  end;
  
  if not FUseSocket and (FStream = nil) then
  begin
    Result := TSSLOperationResult.Err(sslErrInvalidParam, 'Stream is required');
    Exit;
  end;
  
  try
    // Create connection
    if FUseSocket then
      AConnection := FContext.CreateConnection(FSocket)
    else
      AConnection := FContext.CreateConnection(FStream);
    
    if AConnection = nil then
    begin
      Result := TSSLOperationResult.Err(sslErrConnection, 'Failed to create connection');
      Exit;
    end;

    // Client builder path owns per-connection hostname state. If callers do not
    // provide one explicitly, clear any inherited context fallback instead of
    // silently preserving deprecated context-level SNI state.
    if Supports(AConnection, ISSLClientConnection, ClientConn) then
    begin
      if FHostnameSet then
        ClientConn.SetServerName(FHostname)
      else
        ClientConn.SetServerName('');
    end
    else if FHostnameSet then
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(sslErrUnsupported, 'Backend does not support per-connection server name');
      Exit;
    end;
    
    // Prefer the connection-control owner path when the backend exposes it.
    ApplyConnectionControlOverrides(AConnection, FTimeout, FBlocking);
    
    // Set session for reuse
    if FSessionReuse and (FSession <> nil) then
    begin
      if not Supports(AConnection, ISSLSessionResumption, SessionResumption) then
      begin
        AConnection := nil;
        Result := TSSLOperationResult.Err(sslErrUnsupported,
          'Backend does not expose ISSLSessionResumption for session reuse');
        Exit;
      end;
      SessionResumption.SetSession(FSession);
    end;
    
    // Perform client handshake
    if not AConnection.Connect then
    begin
      ReadConnectionVerificationSurface(AConnection, VerifyRes, VerifyStr);

      try
        AConnection.Close;
      except
        // best-effort cleanup
      end;

      AConnection := nil;
      if VerifyRes <> 0 then
        Result := TSSLOperationResult.Err(sslErrVerificationFailed, 'Client handshake failed: ' + VerifyStr)
      else
        Result := TSSLOperationResult.Err(sslErrHandshake, 'Client handshake failed: ' + VerifyStr);
      Exit;
    end;
    
    Result := TSSLOperationResult.Ok;
  except
    // 细化异常处理：捕获具体异常类型（Rust标准）
    on E: ESSLHandshakeException do
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(sslErrHandshake, 'Handshake failed: ' + E.Message);
    end;
    on E: ESSLCertificateVerificationException do
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(sslErrVerificationFailed, 'Certificate verification failed: ' + E.Message);
    end;
    on E: ESSLConnectionException do
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(sslErrConnection, 'Connection error: ' + E.Message);
    end;
    on E: ESSLException do  // 其他SSL异常
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(E.ErrorCode, 'SSL error: ' + E.Message);
    end;
    // 注意：不再捕获通用 Exception，让未知错误向上传播
  end;
end;

function TSSLConnectionBuilderImpl.TryBuildServer(out AConnection: ISSLConnection): TSSLOperationResult;
var
  VerifyRes: Integer;
  VerifyStr: string;
begin
  AConnection := nil;
  
  // Validate required fields
  if FContext = nil then
  begin
    Result := TSSLOperationResult.Err(sslErrInvalidParam, 'Context is required');
    Exit;
  end;
  
  if FUseSocket and (FSocket = 0) then
  begin
    Result := TSSLOperationResult.Err(sslErrInvalidParam, 'Socket is required');
    Exit;
  end;
  
  if not FUseSocket and (FStream = nil) then
  begin
    Result := TSSLOperationResult.Err(sslErrInvalidParam, 'Stream is required');
    Exit;
  end;
  
  try
    // Create connection
    if FUseSocket then
      AConnection := FContext.CreateConnection(FSocket)
    else
      AConnection := FContext.CreateConnection(FStream);
    
    if AConnection = nil then
    begin
      Result := TSSLOperationResult.Err(sslErrConnection, 'Failed to create connection');
      Exit;
    end;
    
    // Prefer the connection-control owner path when the backend exposes it.
    ApplyConnectionControlOverrides(AConnection, FTimeout, FBlocking);
    
    // Perform server accept
    if not AConnection.Accept then
    begin
      ReadConnectionVerificationSurface(AConnection, VerifyRes, VerifyStr);

      try
        AConnection.Close;
      except
        // best-effort cleanup
      end;

      AConnection := nil;
      if VerifyRes <> 0 then
        Result := TSSLOperationResult.Err(sslErrVerificationFailed, 'Server accept failed: ' + VerifyStr)
      else
        Result := TSSLOperationResult.Err(sslErrHandshake, 'Server accept failed: ' + VerifyStr);
      Exit;
    end;
    
    Result := TSSLOperationResult.Ok;
  except
    // 细化异常处理：捕获具体异常类型（Rust标准）
    on E: ESSLHandshakeException do
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(sslErrHandshake, 'Server accept failed: ' + E.Message);
    end;
    on E: ESSLCertificateVerificationException do
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(sslErrVerificationFailed, 'Client certificate verification failed: ' + E.Message);
    end;
    on E: ESSLConnectionException do
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(sslErrConnection, 'Connection error: ' + E.Message);
    end;
    on E: ESSLException do  // 其他SSL异常
    begin
      AConnection := nil;
      Result := TSSLOperationResult.Err(E.ErrorCode, 'SSL error: ' + E.Message);
    end;
    // 注意：不再捕获通用 Exception，让未知错误向上传播
  end;
end;

end.
