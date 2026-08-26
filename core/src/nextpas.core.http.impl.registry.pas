unit nextpas.core.http.impl.registry;
{**
 * @desc Default protocol registry for HTTP client/server transports.
 *       Owns version-to-factory resolution for built-in transports and
 *       provides a narrow seam for future H2/H3 registration.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  THttpClientTransportFactory = function(
    const AOptions: THttpClientOptions): IHttpTransport;
  THttpServerTransportFactory = function(
    const AOptions: THttpServerOptions): IHttpServerTransport;

procedure RegisterClientTransport(const AVersion: THttpVersion;
  const AFactory: THttpClientTransportFactory);
procedure RegisterServerTransport(const AVersion: THttpVersion;
  const AFactory: THttpServerTransportFactory);
procedure UnregisterClientTransport(const AVersion: THttpVersion);
procedure UnregisterServerTransport(const AVersion: THttpVersion);
function HasClientTransport(const AVersion: THttpVersion): Boolean;
function HasServerTransport(const AVersion: THttpVersion): Boolean;
function TryGetClientTransportFactory(const AVersion: THttpVersion;
  out AFactory: THttpClientTransportFactory): Boolean;
function TryGetServerTransportFactory(const AVersion: THttpVersion;
  out AFactory: THttpServerTransportFactory): Boolean;
procedure SetDefaultClientVersion(const AVersion: THttpVersion);
procedure SetDefaultServerVersion(const AVersion: THttpVersion);
function GetDefaultClientVersion: THttpVersion;
function GetDefaultServerVersion: THttpVersion;
{ Testing escape hatch: unfreeze registry to allow runtime modification.
  Only use in test setup; never call from production code. }
procedure UnfreezeRegistry;
function ResolveClientTransport(const AVersion: THttpVersion;
  const AOptions: THttpClientOptions): IHttpTransport;
function ResolveServerTransport(const AVersion: THttpVersion;
  const AOptions: THttpServerOptions): IHttpServerTransport;
function ResolveDefaultClientTransport(
  const AOptions: THttpClientOptions): IHttpTransport;
function ResolveDefaultServerTransport(
  const AOptions: THttpServerOptions): IHttpServerTransport;

implementation

uses
  nextpas.core.http.impl.h1,
  nextpas.core.http.impl.h1.tls,
  nextpas.core.http.impl.h2.client,
  nextpas.core.http.impl.h2.server,
  nextpas.core.http.impl.h2.tls,
  nextpas.core.http.impl.h2.types;

var
  GClientFactories: array[THttpVersion] of THttpClientTransportFactory;
  GServerFactories: array[THttpVersion] of THttpServerTransportFactory;
  GDefaultClientVersion: THttpVersion;
  GDefaultServerVersion: THttpVersion;
  GFrozen: Boolean;

function CreateH1ClientTransport(const AOptions: THttpClientOptions): IHttpTransport;
var
  LH1Options: TH1ClientTransportOptions;
begin
  LH1Options.Timeout := AOptions.Timeout;
  LH1Options.ConnectTimeout := AOptions.ConnectTimeout;
  LH1Options.MaxPoolSize := AOptions.MaxPoolSize;
  LH1Options.IdleTTL := AOptions.IdleTTL;
  LH1Options.ProxyUrl := AOptions.ProxyUrl;
  LH1Options.DialFunc := AOptions.DialFunc;
  LH1Options.TLSContext := AOptions.TLSContext;
  Result := NewH1ClientTransport(LH1Options);
end;

function CreateH2ClientTransport(const AOptions: THttpClientOptions): IHttpTransport;
var
  LH2Options: TH2ClientTransportOptions;
begin
  LH2Options := TH2ClientTransportOptions.Default;
  LH2Options.Timeout := AOptions.Timeout;
  LH2Options.ConnectTimeout := AOptions.ConnectTimeout;
  LH2Options.MaxPoolSize := AOptions.MaxPoolSize;
  LH2Options.IdleTTL := AOptions.IdleTTL;
  LH2Options.TLSContext := AOptions.TLSContext;
  Result := NewH2ClientTransport(LH2Options);
end;

function CreateH1ServerTransport(
  const AOptions: THttpServerOptions): IHttpServerTransport;
var
  LH1Options: TH1ServerTransportOptions;
  LInnerTransport: IHttpServerTransport;
begin
  LH1Options.ReadTimeout := AOptions.ReadTimeout;
  LH1Options.WriteTimeout := AOptions.WriteTimeout;
  LH1Options.IdleTimeout := AOptions.IdleTimeout;
  LH1Options.MaxHeaderSize := AOptions.MaxHeaderSize;
  LH1Options.MaxBodySize := AOptions.MaxBodySize;
  LH1Options.MaxRequestsPerConnection := AOptions.MaxRequestsPerConnection;
  { H1 native connection-scoped RequestArena (Reset per request). }
  LH1Options.RequestArena := AOptions.RequestArena;
  LH1Options.RequestArenaCapacity := AOptions.RequestArenaCapacity;
  { S1-1 scale default: reactor-inline handlers on poll-owned path.
    Products with blocking streaming handlers opt out via
    AOptions.PreferPollWorkerHandoff (streaming then runs on the worker pool
    so one slow upstream does not stall the readiness reactor). }
  LH1Options.PreferPollWorkerHandoff := AOptions.PreferPollWorkerHandoff;
  LH1Options.ReadAbortSink := AOptions.ReadAbortSink;
  LInnerTransport := NewH1ServerTransport(LH1Options);
  { Product H1 HTTPS: same TLS wrap pattern as H2 (ALPN http/1.1). }
  if AOptions.TLSContext <> nil then
    Result := NewH1TlsServerTransport(AOptions.TLSContext, LInnerTransport)
  else
    Result := LInnerTransport;
end;

function CreateH2ServerTransport(
  const AOptions: THttpServerOptions): IHttpServerTransport;
var
  LH2Options: TH2ServerTransportOptions;
  LInnerTransport: IHttpServerTransport;
begin
  LH2Options := TH2ServerTransportOptions.Default;
  LH2Options.ReadTimeout := AOptions.ReadTimeout;
  LH2Options.WriteTimeout := AOptions.WriteTimeout;
  LH2Options.IdleTimeout := AOptions.IdleTimeout;
  if AOptions.MaxHeaderSize > 0 then
    LH2Options.MaxHeaderListSize := UInt32(AOptions.MaxHeaderSize)
  else
    LH2Options.MaxHeaderListSize := 0;
  if AOptions.MaxBodySize > 0 then
    LH2Options.MaxBodySize := UInt32(AOptions.MaxBodySize)
  else
    LH2Options.MaxBodySize := 0;
  { H2 native connection-scoped RequestArena (Reset per stream request). }
  LH2Options.RequestArena := AOptions.RequestArena;
  LH2Options.RequestArenaCapacity := AOptions.RequestArenaCapacity;
  LInnerTransport := NewH2ServerTransport(LH2Options);
  if AOptions.TLSContext <> nil then
    Result := NewH2TlsServerTransport(AOptions.TLSContext, LInnerTransport)
  else
    Result := LInnerTransport;
end;

{ Note: must be called before any concurrent HTTP client/server creation.
  Raises EHttpError after registry is frozen (after initialization). }
procedure RegisterClientTransport(const AVersion: THttpVersion;
  const AFactory: THttpClientTransportFactory);
begin
  if GFrozen then
    raise EHttpError.Create(hekRegistry, 'registry frozen: cannot register after initialization');
  if not Assigned(AFactory) then
    raise EHttpError.Create(hekRegistry, 'client transport factory must not be nil');
  GClientFactories[AVersion] := AFactory;
end;

{ Note: must be called before any concurrent HTTP client/server creation.
  Raises EHttpError after registry is frozen (after initialization). }
procedure RegisterServerTransport(const AVersion: THttpVersion;
  const AFactory: THttpServerTransportFactory);
begin
  if GFrozen then
    raise EHttpError.Create(hekRegistry, 'registry frozen: cannot register after initialization');
  if not Assigned(AFactory) then
    raise EHttpError.Create(hekRegistry, 'server transport factory must not be nil');
  GServerFactories[AVersion] := AFactory;
end;

procedure UnregisterClientTransport(const AVersion: THttpVersion);
begin
  if GFrozen then
    raise EHttpError.Create(hekRegistry, 'registry frozen: cannot unregister after initialization');
  GClientFactories[AVersion] := nil;
end;

procedure UnregisterServerTransport(const AVersion: THttpVersion);
begin
  if GFrozen then
    raise EHttpError.Create(hekRegistry, 'registry frozen: cannot unregister after initialization');
  GServerFactories[AVersion] := nil;
end;

function HasClientTransport(const AVersion: THttpVersion): Boolean;
begin
  Result := Assigned(GClientFactories[AVersion]);
end;

function HasServerTransport(const AVersion: THttpVersion): Boolean;
begin
  Result := Assigned(GServerFactories[AVersion]);
end;

function TryGetClientTransportFactory(const AVersion: THttpVersion;
  out AFactory: THttpClientTransportFactory): Boolean;
begin
  AFactory := GClientFactories[AVersion];
  Result := Assigned(AFactory);
end;

function TryGetServerTransportFactory(const AVersion: THttpVersion;
  out AFactory: THttpServerTransportFactory): Boolean;
begin
  AFactory := GServerFactories[AVersion];
  Result := Assigned(AFactory);
end;

procedure SetDefaultClientVersion(const AVersion: THttpVersion);
begin
  if GFrozen then
    raise EHttpError.Create(hekRegistry, 'registry frozen: cannot change default after initialization');
  if not HasClientTransport(AVersion) then
    raise EHttpError.Create(hekRegistry, 'no client transport registered for ' +
      HttpVersionToStr(AVersion));
  GDefaultClientVersion := AVersion;
end;

procedure SetDefaultServerVersion(const AVersion: THttpVersion);
begin
  if GFrozen then
    raise EHttpError.Create(hekRegistry, 'registry frozen: cannot change default after initialization');
  if not HasServerTransport(AVersion) then
    raise EHttpError.Create(hekRegistry, 'no server transport registered for ' +
      HttpVersionToStr(AVersion));
  GDefaultServerVersion := AVersion;
end;

function GetDefaultClientVersion: THttpVersion;
begin
  Result := GDefaultClientVersion;
end;

function GetDefaultServerVersion: THttpVersion;
begin
  Result := GDefaultServerVersion;
end;

procedure UnfreezeRegistry;
begin
  GFrozen := False;
end;

function ResolveClientTransport(const AVersion: THttpVersion;
  const AOptions: THttpClientOptions): IHttpTransport;
var
  LFactory: THttpClientTransportFactory;
begin
  if not TryGetClientTransportFactory(AVersion, LFactory) then
    raise EHttpError.Create(hekRegistry, 'no client transport registered for ' +
      HttpVersionToStr(AVersion));
  Result := LFactory(AOptions);
end;

function ResolveServerTransport(const AVersion: THttpVersion;
  const AOptions: THttpServerOptions): IHttpServerTransport;
var
  LFactory: THttpServerTransportFactory;
begin
  if not TryGetServerTransportFactory(AVersion, LFactory) then
    raise EHttpError.Create(hekRegistry, 'no server transport registered for ' +
      HttpVersionToStr(AVersion));
  Result := LFactory(AOptions);
end;

function ResolveDefaultClientTransport(
  const AOptions: THttpClientOptions): IHttpTransport;
begin
  Result := ResolveClientTransport(GDefaultClientVersion, AOptions);
end;

function ResolveDefaultServerTransport(
  const AOptions: THttpServerOptions): IHttpServerTransport;
begin
  Result := ResolveServerTransport(GDefaultServerVersion, AOptions);
end;

procedure RegisterBuiltins;
begin
  RegisterClientTransport(hvHttp10, @CreateH1ClientTransport);
  RegisterClientTransport(hvHttp11, @CreateH1ClientTransport);
  RegisterClientTransport(hvHttp2, @CreateH2ClientTransport);
  RegisterServerTransport(hvHttp10, @CreateH1ServerTransport);
  RegisterServerTransport(hvHttp11, @CreateH1ServerTransport);
  RegisterServerTransport(hvHttp2, @CreateH2ServerTransport);
  GDefaultClientVersion := hvHttp11;
  GDefaultServerVersion := hvHttp11;
  GFrozen := True;
end;

initialization
  RegisterBuiltins;

end.
