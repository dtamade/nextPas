unit nextpas.core.tls.context.config;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.tls.base;

procedure ValidateContextReplayStoreConfigScope(const AConfig: TSSLConfig;
  AContextType: TSSLContextType; const ACallSite: string);
procedure ValidateDirectLibraryConnectionScope(const AConfig: TSSLConfig;
  const ACallSite: string);
procedure ApplyEarlyDataContextConfig(const AContext: ISSLContext;
  const AConfig: TSSLConfig);
procedure ApplyEarlyDataReplayStoreConfig(const AContext: ISSLContext;
  const AConfig: TSSLConfig; const ACallSite: string);

implementation

uses
  nextpas.core.tls.exceptions,
  nextpas.core.tls.freepascal.context.material;

function ContextTypeSupportsServerReplayStore(
  AContextType: TSSLContextType): Boolean;
begin
  Result := AContextType = sslCtxServer;
end;

function ContextTypeSupportsClientEarlyData(
  AContextType: TSSLContextType): Boolean;
begin
  Result := (AContextType = sslCtxClient) or (AContextType = sslCtxBoth);
end;

function ContextTypeSupportsServerEarlyData(
  AContextType: TSSLContextType): Boolean;
begin
  Result := ContextTypeSupportsServerReplayStore(AContextType) or
    (AContextType = sslCtxBoth);
end;

function ReplayStoreClientScopeMessage(const AFieldName,
  ACallSite: string): string;
begin
  Result := 'Configured ' + AFieldName +
    ' is server-context-scoped. Remove it from client creation path ' +
    ACallSite + ' or build a server context instead.';
end;

procedure ValidateContextReplayStoreConfigScope(const AConfig: TSSLConfig;
  AContextType: TSSLContextType; const ACallSite: string);
begin
  if ContextTypeSupportsServerReplayStore(AContextType) then
    Exit;

  if nextpas.core.text.conv.Trim(AConfig.ServerEarlyDataReplayStoreFile) <> '' then
    raise ESSLConfigurationException.CreateWithContext(
      ReplayStoreClientScopeMessage(
        'server_early_data_replay_store_file',
        ACallSite
      ),
      sslErrConfiguration,
      ACallSite,
      0,
      AConfig.LibraryType
    );

  if nextpas.core.text.conv.Trim(AConfig.ServerEarlyDataReplayStoreDirectory) <> '' then
    raise ESSLConfigurationException.CreateWithContext(
      ReplayStoreClientScopeMessage(
        'server_early_data_replay_store_directory',
        ACallSite
      ),
      sslErrConfiguration,
      ACallSite,
      0,
      AConfig.LibraryType
    );
end;

procedure ValidateDirectLibraryConnectionScope(const AConfig: TSSLConfig;
  const ACallSite: string);
begin
  if (AConfig.HandshakeTimeout <> 0) and
    (AConfig.HandshakeTimeout <> SSL_DEFAULT_HANDSHAKE_TIMEOUT) then
    raise ESSLConfigurationException.CreateWithContext(
      'HandshakeTimeout is connection-scoped. Use TSSLConnector.WithTimeout, ' +
      'TSSLAcceptor.WithTimeout, or ISSLConnectionControl.SetTimeout instead of ' + ACallSite + '.',
      sslErrConfiguration,
      ACallSite,
      0,
      AConfig.LibraryType
    );

  if (AConfig.BufferSize <> 0) and
    (AConfig.BufferSize <> SSL_DEFAULT_BUFFER_SIZE) then
    raise ESSLConfigurationException.CreateWithContext(
      'BufferSize is not a context-scoped direct-library option. Configure buffering in the surrounding ' +
      'transport/IO layer instead of ' + ACallSite + '.',
      sslErrConfiguration,
      ACallSite,
      0,
      AConfig.LibraryType
    );
end;

procedure ApplyEarlyDataContextConfig(const AContext: ISSLContext;
  const AConfig: TSSLConfig);
var
  LEarlyDataContext: ISSLEarlyDataContext;
begin
  if (AContext = nil) or
    (not Supports(AContext, ISSLEarlyDataContext, LEarlyDataContext)) then
    Exit;

  if ContextTypeSupportsClientEarlyData(AContext.GetContextType) and
    (LEarlyDataContext.GetClientEarlyDataEnabled <> AConfig.ClientEarlyDataEnabled) then
    LEarlyDataContext.SetClientEarlyDataEnabled(AConfig.ClientEarlyDataEnabled);

  if ContextTypeSupportsServerEarlyData(AContext.GetContextType) then
  begin
    if LEarlyDataContext.GetServerMaxEarlyDataSize <> AConfig.ServerMaxEarlyDataSize then
      LEarlyDataContext.SetServerMaxEarlyDataSize(AConfig.ServerMaxEarlyDataSize);

    if LEarlyDataContext.GetServerEarlyDataPolicy <> AConfig.ServerEarlyDataPolicy then
      LEarlyDataContext.SetServerEarlyDataPolicy(AConfig.ServerEarlyDataPolicy);
  end;
end;

procedure ApplyEarlyDataReplayStoreConfig(const AContext: ISSLContext;
  const AConfig: TSSLConfig; const ACallSite: string);
var
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LDirectoryInstaller: IFreePascalContextEarlyDataReplayDirectoryInstaller;
begin
  if (AContext = nil) or
    (not ContextTypeSupportsServerReplayStore(AContext.GetContextType)) then
    Exit;

  if (nextpas.core.text.conv.Trim(AConfig.ServerEarlyDataReplayStoreFile) <> '') and
    (nextpas.core.text.conv.Trim(AConfig.ServerEarlyDataReplayStoreDirectory) <> '') then
    raise ESSLConfigurationException.CreateWithContext(
      'Configured server_early_data_replay_store_file and ' +
      'server_early_data_replay_store_directory are mutually exclusive; configure not both',
      sslErrConfiguration,
      ACallSite,
      0,
      AConfig.LibraryType
    );

  if nextpas.core.text.conv.Trim(AConfig.ServerEarlyDataReplayStoreFile) <> '' then
  begin
    if not Supports(AContext, IFreePascalContextEarlyDataReplayInstaller, LInstaller) then
      raise ESSLConfigurationException.CreateWithContext(
        'Configured server_early_data_replay_store_file requires a backend that implements IFreePascalContextEarlyDataReplayInstaller',
        sslErrConfiguration,
        ACallSite,
        0,
        AConfig.LibraryType
      );

    if not LInstaller.InstallFileBackedReplayLedger(AConfig.ServerEarlyDataReplayStoreFile) then
      raise ESSLConfigurationException.CreateWithContext(
        'Configured server_early_data_replay_store_file could not install the requested replay store',
        sslErrConfiguration,
        ACallSite,
        0,
        AConfig.LibraryType
      );
  end;

  if nextpas.core.text.conv.Trim(AConfig.ServerEarlyDataReplayStoreDirectory) <> '' then
  begin
    if not Supports(AContext, IFreePascalContextEarlyDataReplayDirectoryInstaller,
      LDirectoryInstaller) then
      raise ESSLConfigurationException.CreateWithContext(
        'Configured server_early_data_replay_store_directory requires a backend that implements IFreePascalContextEarlyDataReplayDirectoryInstaller',
        sslErrConfiguration,
        ACallSite,
        0,
        AConfig.LibraryType
      );

    if not LDirectoryInstaller.InstallDirectoryBackedReplayLedger(
      AConfig.ServerEarlyDataReplayStoreDirectory
    ) then
      raise ESSLConfigurationException.CreateWithContext(
        'Configured server_early_data_replay_store_directory could not install the requested replay store',
        sslErrConfiguration,
        ACallSite,
        0,
        AConfig.LibraryType
      );
  end;
end;

end.
