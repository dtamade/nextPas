program test_factory_config_early_data_isolation;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.freepascal.session,
  nextpas.core.tls.tls13.wire;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  PASS: ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestHeader(const AName: string);
begin
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

function BuildReplayStoreFilePath(const ALabel: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fafafa_ssl_' + ALabel + '_replay_store.bin';
end;

function BuildReplayStoreDirectoryPath(const ALabel: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fafafa_ssl_' + ALabel + '_replay_store_dir';
end;

procedure CleanupReplayStoreFiles(const AFileName: string);
begin
  if FileExists(AFileName) then
    DeleteFile(AFileName);
  if FileExists(AFileName + '.tmp') then
    DeleteFile(AFileName + '.tmp');
end;

procedure RemovePathTree(const APath: string);
var
  LSearch: TSearchRec;
  LChildPath: string;
begin
  if not DirectoryExists(APath) then
  begin
    if FileExists(APath) then
      DeleteFile(APath);
    Exit;
  end;

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*', faAnyFile, LSearch) = 0 then
  begin
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then
        Continue;

      LChildPath := IncludeTrailingPathDelimiter(APath) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then
        RemovePathTree(LChildPath)
      else
        DeleteFile(LChildPath);
    until FindNext(LSearch) <> 0;
    FindClose(LSearch);
  end;

  RemoveDir(APath);
end;

procedure CleanupReplayStoreDirectory(const ADirectoryName: string);
begin
  RemovePathTree(ADirectoryName);
  RemovePathTree(ADirectoryName + '.tmpdir');
  RemovePathTree(ADirectoryName + '.bakdir');
  if FileExists(ADirectoryName + '.lock') then
    DeleteFile(ADirectoryName + '.lock');
end;

function BuildManualSession(const ALabel: AnsiString; AMaxEarlyDataSize: Cardinal): ISSLSession;
var
  LSession: TFreePascalSession;
  LTicket: TBytes;
  LPSK: TBytes;
begin
  LSession := TFreePascalSession.Create;
  LTicket := BytesOf('ticket-' + ALabel);
  LPSK := BytesOf('0123456789abcdef0123456789abcdef');
  LSession.ConfigureResumption(
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    'TLS_CHACHA20_POLY1305_SHA256',
    [$01, $02, $03],
    LTicket,
    LPSK,
    7200,
    $01020304,
    Now,
    7200,
    AMaxEarlyDataSize
  );
  Result := LSession;
end;

procedure AssertReplayStoreRejectsCrossContextReplay(
  ACtx1, ACtx2: ISSLContext;
  const AFileName: string;
  const ALabel: string
);
var
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger1: IFreePascalEarlyDataReplayLedger;
  LLedger2: IFreePascalEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  Assert(Supports(ACtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    ALabel + ' first context exposes replay-ledger access seam');
  Assert(Supports(ACtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    ALabel + ' second context exposes replay-ledger access seam');
  if not Supports(ACtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
    Exit;
  if not Supports(ACtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
    Exit;

  LLedger1 := LReplayAccess1.GetEarlyDataReplayLedger;
  LLedger2 := LReplayAccess2.GetEarlyDataReplayLedger;
  Assert(LLedger1 <> nil, ALabel + ' first context exposes an active replay ledger');
  Assert(LLedger2 <> nil, ALabel + ' second context exposes an active replay ledger');
  if (LLedger1 = nil) or (LLedger2 = nil) then
    Exit;

  LSession := BuildManualSession(AnsiString(ALabel), 8);
  Assert(LLedger1.TryAcquireEarlyDataSession(LSession),
    ALabel + ' first replay acquire succeeds');
  Assert(FileExists(AFileName),
    ALabel + ' first replay acquire materializes the configured replay store file');
  Assert(not LLedger2.TryAcquireEarlyDataSession(LSession),
    ALabel + ' second replay acquire rejects cross-context replay');
end;

procedure AssertReplayStoreDirectoryRejectsCrossContextReplay(
  ACtx1, ACtx2: ISSLContext;
  const ADirectoryName: string;
  const ALabel: string
);
var
  LReplayAccess1: IFreePascalEarlyDataReplayLedgerAccess;
  LReplayAccess2: IFreePascalEarlyDataReplayLedgerAccess;
  LLedger1: IFreePascalEarlyDataReplayLedger;
  LLedger2: IFreePascalEarlyDataReplayLedger;
  LSession: ISSLSession;
begin
  Assert(Supports(ACtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1),
    ALabel + ' first context exposes replay-ledger access seam');
  Assert(Supports(ACtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2),
    ALabel + ' second context exposes replay-ledger access seam');
  if not Supports(ACtx1, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess1) then
    Exit;
  if not Supports(ACtx2, IFreePascalEarlyDataReplayLedgerAccess, LReplayAccess2) then
    Exit;

  LLedger1 := LReplayAccess1.GetEarlyDataReplayLedger;
  LLedger2 := LReplayAccess2.GetEarlyDataReplayLedger;
  Assert(LLedger1 <> nil, ALabel + ' first context exposes an active replay ledger');
  Assert(LLedger2 <> nil, ALabel + ' second context exposes an active replay ledger');
  if (LLedger1 = nil) or (LLedger2 = nil) then
    Exit;

  LSession := BuildManualSession(AnsiString(ALabel), 8);
  Assert(LLedger1.TryAcquireEarlyDataSession(LSession),
    ALabel + ' first replay acquire succeeds');
  Assert(DirectoryExists(ADirectoryName),
    ALabel + ' first replay acquire materializes the configured replay store directory');
  Assert(not LLedger2.TryAcquireEarlyDataSession(LSession),
    ALabel + ' second replay acquire rejects cross-context replay');
end;

procedure AssertClientEarlyDataState(ACtx: ISSLContext; AEnabled: Boolean; const ALabel: string);
var
  LEarlyCtx: ISSLEarlyDataContext;
begin
  Assert(Supports(ACtx, ISSLEarlyDataContext, LEarlyCtx),
    ALabel + ' exposes ISSLEarlyDataContext');
  if Supports(ACtx, ISSLEarlyDataContext, LEarlyCtx) then
    Assert(LEarlyCtx.GetClientEarlyDataEnabled = AEnabled,
      ALabel + ' client early-data flag matches config');
end;

procedure AssertServerEarlyDataState(ACtx: ISSLContext;
  APolicy: TSSLEarlyDataServerPolicy; AMaxSize: Cardinal; const ALabel: string);
var
  LEarlyCtx: ISSLEarlyDataContext;
begin
  Assert(Supports(ACtx, ISSLEarlyDataContext, LEarlyCtx),
    ALabel + ' exposes ISSLEarlyDataContext');
  if Supports(ACtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    Assert(LEarlyCtx.GetServerEarlyDataPolicy = APolicy,
      ALabel + ' server early-data policy matches config');
    Assert(LEarlyCtx.GetServerMaxEarlyDataSize = AMaxSize,
      ALabel + ' server max early-data size matches config');
  end;
end;

procedure Test_ExplicitDefaultConfig_PersistsToDefaultPaths;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  ServerCtx1: ISSLContext;
  ServerCtx2: ISSLContext;
  ReplayStoreFile: string;
  ReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
begin
  TestHeader('Explicit SetDefaultConfig persists to default early-data paths');

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  ReplayStoreFile := BuildReplayStoreFilePath('factory_default_path');
  CleanupReplayStoreFiles(ReplayStoreFile);
  try
    DefaultConfig := OriginalConfig;
    DefaultConfig.ClientEarlyDataEnabled := True;
    DefaultConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
    DefaultConfig.ServerMaxEarlyDataSize := 11;
    DefaultConfig.ServerEarlyDataReplayStoreFile := ReplayStoreFile;
    Lib.SetDefaultConfig(DefaultConfig);

    ServerCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    ServerCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertServerEarlyDataState(ServerCtx1, sslEarlyDataServerIssueOnly, 11,
      'Default-path server context');
    AssertServerEarlyDataState(ServerCtx2, sslEarlyDataServerIssueOnly, 11,
      'Second default-path server context');
    AssertReplayStoreRejectsCrossContextReplay(
      ServerCtx1,
      ServerCtx2,
      ReplayStoreFile,
      'Default-path replay-store config'
    );

    try
      TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
      Assert(False,
        'Default-path client context should reject server-scoped replay-store config');
    except
      on E: ESSLConfigurationException do
      begin
        Assert(Pos('server_early_data_replay_store_file', E.Message) > 0,
          'Default-path client replay-store rejection should name server_early_data_replay_store_file');
      end;
      on E: Exception do
        Assert(False,
          'Default-path client replay-store rejection should raise configuration exception: ' + E.Message);
    end;
  finally
    if Supports(ServerCtx1, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    if Supports(ServerCtx2, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayStoreFiles(ReplayStoreFile);
    Lib.SetDefaultConfig(OriginalConfig);
  end;
end;

procedure Test_OneShotConfig_DoesNotLeakIntoSharedDefaults;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  BaselineConfig: TSSLConfig;
  OneShotConfig: TSSLConfig;
  OneShotCtx: ISSLContext;
  FreshClientCtx: ISSLContext;
  FreshServerCtx: ISSLContext;
  ReplayStoreFile: string;
  ReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  ReplayLedger: IFreePascalEarlyDataReplayLedger;
  Session: ISSLSession;
begin
  TestHeader('One-shot factory early-data config does not leak into shared defaults');

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  ReplayStoreFile := BuildReplayStoreFilePath('factory_one_shot');
  CleanupReplayStoreFiles(ReplayStoreFile);
  try
    BaselineConfig := OriginalConfig;
    BaselineConfig.ClientEarlyDataEnabled := False;
    BaselineConfig.ServerEarlyDataPolicy := sslEarlyDataServerReject;
    BaselineConfig.ServerMaxEarlyDataSize := 0;
    BaselineConfig.ServerEarlyDataReplayStoreFile := '';
    Lib.SetDefaultConfig(BaselineConfig);

    OneShotConfig := CreateDefaultConfig(sslCtxServer);
    OneShotConfig.LibraryType := sslFreePascal;
    OneShotConfig.ContextType := sslCtxServer;
    OneShotConfig.ClientEarlyDataEnabled := True;
    OneShotConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
    OneShotConfig.ServerMaxEarlyDataSize := 7;
    OneShotConfig.ServerEarlyDataReplayStoreFile := ReplayStoreFile;

    OneShotCtx := TSSLFactory.CreateContext(OneShotConfig);
    AssertClientEarlyDataState(OneShotCtx, False,
      'One-shot context');
    AssertServerEarlyDataState(OneShotCtx, sslEarlyDataServerIssueOnly, 7,
      'One-shot context');
    Assert(Supports(OneShotCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess),
      'One-shot context exposes replay-ledger access seam');
    if Supports(OneShotCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
    begin
      ReplayLedger := ReplayAccess.GetEarlyDataReplayLedger;
      Assert(ReplayLedger <> nil, 'One-shot context exposes an active replay ledger');
      if ReplayLedger <> nil then
      begin
        Session := BuildManualSession(
          AnsiString('factory-one-shot-' + FormatDateTime('yyyymmddhhnnsszzz', Now)),
          8
        );
        Assert(ReplayLedger.TryAcquireEarlyDataSession(Session),
          'One-shot context applies configured replay-store file');
        Assert(FileExists(ReplayStoreFile),
          'One-shot replay-store config materializes the configured file after first acquire');
      end;
    end;

    FreshClientCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
    AssertClientEarlyDataState(FreshClientCtx, False,
      'Fresh default-path client context');

    FreshServerCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertServerEarlyDataState(FreshServerCtx, sslEarlyDataServerReject, 0,
      'Fresh default-path server context');
    Assert(Supports(FreshServerCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess),
      'Fresh default-path server context exposes replay-ledger access seam');
    if Supports(FreshServerCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
    begin
      ReplayLedger := ReplayAccess.GetEarlyDataReplayLedger;
      Assert(ReplayLedger <> nil, 'Fresh default-path server context exposes an active replay ledger');
      if ReplayLedger <> nil then
        Assert(ReplayLedger.TryAcquireEarlyDataSession(Session),
          'Fresh default-path server context does not inherit one-shot replay-store state');
    end;
  finally
    if Supports(OneShotCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    if Supports(FreshServerCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayStoreFiles(ReplayStoreFile);
    Lib.SetDefaultConfig(OriginalConfig);
  end;
end;

procedure Test_ExplicitDefaultConfig_PersistsToDefaultDirectoryReplayStorePaths;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  ServerCtx1: ISSLContext;
  ServerCtx2: ISSLContext;
  ReplayStoreDirectory: string;
  ReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
begin
  TestHeader('Explicit SetDefaultConfig persists to default directory replay-store paths');

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  ReplayStoreDirectory := BuildReplayStoreDirectoryPath('factory_default_directory_path');
  CleanupReplayStoreDirectory(ReplayStoreDirectory);
  try
    DefaultConfig := OriginalConfig;
    DefaultConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
    DefaultConfig.ServerMaxEarlyDataSize := 11;
    DefaultConfig.ServerEarlyDataReplayStoreDirectory := ReplayStoreDirectory;
    Lib.SetDefaultConfig(DefaultConfig);

    ServerCtx1 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    ServerCtx2 := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertServerEarlyDataState(ServerCtx1, sslEarlyDataServerIssueOnly, 11,
      'Default-path directory replay-store server context');
    AssertServerEarlyDataState(ServerCtx2, sslEarlyDataServerIssueOnly, 11,
      'Second default-path directory replay-store server context');
    AssertReplayStoreDirectoryRejectsCrossContextReplay(
      ServerCtx1,
      ServerCtx2,
      ReplayStoreDirectory,
      'Default-path directory replay-store config'
    );
  finally
    if Supports(ServerCtx1, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    if Supports(ServerCtx2, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayStoreDirectory(ReplayStoreDirectory);
    Lib.SetDefaultConfig(OriginalConfig);
  end;
end;

procedure Test_OneShotDirectoryReplayStoreConfig_DoesNotLeakIntoSharedDefaults;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  BaselineConfig: TSSLConfig;
  OneShotConfig: TSSLConfig;
  OneShotCtx: ISSLContext;
  FreshServerCtx: ISSLContext;
  ReplayStoreDirectory: string;
  ReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  ReplayLedger: IFreePascalEarlyDataReplayLedger;
  Session: ISSLSession;
begin
  TestHeader('One-shot factory directory replay-store config does not leak into shared defaults');

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  ReplayStoreDirectory := BuildReplayStoreDirectoryPath('factory_one_shot_directory');
  CleanupReplayStoreDirectory(ReplayStoreDirectory);
  try
    BaselineConfig := OriginalConfig;
    BaselineConfig.ServerEarlyDataReplayStoreDirectory := '';
    Lib.SetDefaultConfig(BaselineConfig);

    OneShotConfig := CreateDefaultConfig(sslCtxServer);
    OneShotConfig.LibraryType := sslFreePascal;
    OneShotConfig.ContextType := sslCtxServer;
    OneShotConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
    OneShotConfig.ServerMaxEarlyDataSize := 7;
    OneShotConfig.ServerEarlyDataReplayStoreDirectory := ReplayStoreDirectory;

    OneShotCtx := TSSLFactory.CreateContext(OneShotConfig);
    AssertServerEarlyDataState(OneShotCtx, sslEarlyDataServerIssueOnly, 7,
      'One-shot directory replay-store context');
    Assert(Supports(OneShotCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess),
      'One-shot directory replay-store context exposes replay-ledger access seam');
    if Supports(OneShotCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
    begin
      ReplayLedger := ReplayAccess.GetEarlyDataReplayLedger;
      Assert(ReplayLedger <> nil, 'One-shot directory replay-store context exposes an active replay ledger');
      if ReplayLedger <> nil then
      begin
        Session := BuildManualSession(
          AnsiString('factory-one-shot-directory-' + FormatDateTime('yyyymmddhhnnsszzz', Now)),
          8
        );
        Assert(ReplayLedger.TryAcquireEarlyDataSession(Session),
          'One-shot context applies configured replay-store directory');
        Assert(DirectoryExists(ReplayStoreDirectory),
          'One-shot replay-store directory config materializes the configured directory after first acquire');
      end;
    end;

    FreshServerCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertServerEarlyDataState(FreshServerCtx, sslEarlyDataServerReject, 0,
      'Fresh default-path server context after one-shot directory replay-store config');
    Assert(Supports(FreshServerCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess),
      'Fresh default-path server context after one-shot directory config exposes replay-ledger access seam');
    if Supports(FreshServerCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
    begin
      ReplayLedger := ReplayAccess.GetEarlyDataReplayLedger;
      Assert(ReplayLedger <> nil,
        'Fresh default-path server context after one-shot directory config exposes an active replay ledger');
      if ReplayLedger <> nil then
        Assert(ReplayLedger.TryAcquireEarlyDataSession(Session),
          'Fresh default-path server context does not inherit one-shot directory replay-store state');
    end;
  finally
    if Supports(OneShotCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    if Supports(FreshServerCtx, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayStoreDirectory(ReplayStoreDirectory);
    Lib.SetDefaultConfig(OriginalConfig);
  end;
end;

procedure Test_OneShotConfig_RejectsConflictingReplayStoreFileAndDirectory;
var
  LConfig: TSSLConfig;
  LCtx: ISSLContext;
begin
  TestHeader('One-shot factory rejects conflicting replay-store file and directory config');

  LConfig := CreateDefaultConfig(sslCtxServer);
  LConfig.LibraryType := sslFreePascal;
  LConfig.ContextType := sslCtxServer;
  LConfig.ServerEarlyDataReplayStoreFile := BuildReplayStoreFilePath('factory_conflict_file');
  LConfig.ServerEarlyDataReplayStoreDirectory := BuildReplayStoreDirectoryPath('factory_conflict_dir');

  try
    LCtx := TSSLFactory.CreateContext(LConfig);
    Assert(False, 'Factory should reject conflicting replay-store file and directory config');
    if LCtx <> nil then;
  except
    on E: ESSLConfigurationException do
    begin
      Assert(Pos('server_early_data_replay_store_file', E.Message) > 0,
        'Conflicting factory replay-store config error names server_early_data_replay_store_file');
      Assert(Pos('server_early_data_replay_store_directory', E.Message) > 0,
        'Conflicting factory replay-store config error names server_early_data_replay_store_directory');
      Assert(Pos('not both', LowerCase(E.Message)) > 0,
        'Conflicting factory replay-store config error explains mutual exclusion');
    end;
    on E: Exception do
      Assert(False, 'Factory should raise configuration exception for conflicting replay-store config: ' + E.Message);
  end;
end;

begin
  try
    Test_ExplicitDefaultConfig_PersistsToDefaultPaths;
    Test_OneShotConfig_DoesNotLeakIntoSharedDefaults;
    Test_ExplicitDefaultConfig_PersistsToDefaultDirectoryReplayStorePaths;
    Test_OneShotDirectoryReplayStoreConfig_DoesNotLeakIntoSharedDefaults;
    Test_OneShotConfig_RejectsConflictingReplayStoreFileAndDirectory;

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.Message);
      Halt(1);
    end;
  end;
end.
