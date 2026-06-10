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
  nextpas.core.http.impl.h1;

var
  GClientFactories: array[THttpVersion] of THttpClientTransportFactory;
  GServerFactories: array[THttpVersion] of THttpServerTransportFactory;
  GDefaultClientVersion: THttpVersion;
  GDefaultServerVersion: THttpVersion;

function CreateH1ClientTransport(const AOptions: THttpClientOptions): IHttpTransport;
var
  LH1Options: TH1ClientTransportOptions;
begin
  LH1Options.Timeout := AOptions.Timeout;
  Result := NewH1ClientTransport(LH1Options);
end;

function CreateH1ServerTransport(
  const AOptions: THttpServerOptions): IHttpServerTransport;
var
  LH1Options: TH1ServerTransportOptions;
begin
  LH1Options.ReadTimeout := AOptions.ReadTimeout;
  LH1Options.WriteTimeout := AOptions.WriteTimeout;
  LH1Options.IdleTimeout := AOptions.IdleTimeout;
  LH1Options.MaxHeaderSize := AOptions.MaxHeaderSize;
  LH1Options.MaxBodySize := AOptions.MaxBodySize;
  Result := NewH1ServerTransport(LH1Options);
end;

{ Note: must be called before any concurrent HTTP client/server creation. }
procedure RegisterClientTransport(const AVersion: THttpVersion;
  const AFactory: THttpClientTransportFactory);
begin
  if not Assigned(AFactory) then
    raise EHttpError.Create('client transport factory must not be nil');
  GClientFactories[AVersion] := AFactory;
end;

{ Note: must be called before any concurrent HTTP client/server creation. }
procedure RegisterServerTransport(const AVersion: THttpVersion;
  const AFactory: THttpServerTransportFactory);
begin
  if not Assigned(AFactory) then
    raise EHttpError.Create('server transport factory must not be nil');
  GServerFactories[AVersion] := AFactory;
end;

procedure UnregisterClientTransport(const AVersion: THttpVersion);
begin
  GClientFactories[AVersion] := nil;
end;

procedure UnregisterServerTransport(const AVersion: THttpVersion);
begin
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
  if not HasClientTransport(AVersion) then
    raise EHttpError.Create('no client transport registered for ' +
      HttpVersionToStr(AVersion));
  GDefaultClientVersion := AVersion;
end;

procedure SetDefaultServerVersion(const AVersion: THttpVersion);
begin
  if not HasServerTransport(AVersion) then
    raise EHttpError.Create('no server transport registered for ' +
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

function ResolveClientTransport(const AVersion: THttpVersion;
  const AOptions: THttpClientOptions): IHttpTransport;
var
  LFactory: THttpClientTransportFactory;
begin
  if not TryGetClientTransportFactory(AVersion, LFactory) then
    raise EHttpError.Create('no client transport registered for ' +
      HttpVersionToStr(AVersion));
  Result := LFactory(AOptions);
end;

function ResolveServerTransport(const AVersion: THttpVersion;
  const AOptions: THttpServerOptions): IHttpServerTransport;
var
  LFactory: THttpServerTransportFactory;
begin
  if not TryGetServerTransportFactory(AVersion, LFactory) then
    raise EHttpError.Create('no server transport registered for ' +
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
  RegisterServerTransport(hvHttp10, @CreateH1ServerTransport);
  RegisterServerTransport(hvHttp11, @CreateH1ServerTransport);
  GDefaultClientVersion := hvHttp11;
  GDefaultServerVersion := hvHttp11;
end;

initialization
  RegisterBuiltins;

end.
