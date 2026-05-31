program test_direct_library_early_data_replay_store_parity;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
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

function CreateInitializedLibrary: ISSLLibrary;
begin
  Result := CreateFreePascalSSLLibrary;
  if Result = nil then
    raise Exception.Create('CreateFreePascalSSLLibrary returned nil');

  if not Result.Initialize then
    raise Exception.Create('FreePascal library failed to initialize for direct-library early-data parity test');
end;

function BuildReplayStoreFilePath(const ALabel: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fafafa_ssl_' + ALabel + '_direct_library_replay_store.bin';
end;

function BuildReplayStoreDirectoryPath(const ALabel: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fafafa_ssl_' + ALabel + '_direct_library_replay_store_dir';
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

procedure AssertClientEarlyDataState(ACtx: ISSLContext; AEnabled: Boolean;
  const ALabel: string);
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

procedure Test_ClientContextReflectsClientEarlyDataDefaultConfig;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal direct-library client context reflects client early-data defaults');

  Lib := CreateInitializedLibrary;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.ClientEarlyDataEnabled := True;
    Lib.SetDefaultConfig(DefaultConfig);

    Ctx := Lib.CreateContext(sslCtxClient);
    AssertClientEarlyDataState(Ctx, True,
      'FreePascal direct-library client context');
  finally
    Ctx := nil;
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

procedure Test_ServerContextReflectsReplayStoreFileDefaultConfig;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Ctx1: ISSLContext;
  Ctx2: ISSLContext;
  ReplayStoreFile: string;
  ReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
begin
  TestHeader('FreePascal direct-library server context reflects replay-store file defaults');

  Lib := CreateInitializedLibrary;
  ReplayStoreFile := BuildReplayStoreFilePath('direct_library_file');
  CleanupReplayStoreFiles(ReplayStoreFile);
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
    DefaultConfig.ServerMaxEarlyDataSize := 11;
    DefaultConfig.ServerEarlyDataReplayStoreFile := ReplayStoreFile;
    Lib.SetDefaultConfig(DefaultConfig);

    Ctx1 := Lib.CreateContext(sslCtxServer);
    Ctx2 := Lib.CreateContext(sslCtxServer);
    AssertServerEarlyDataState(Ctx1, sslEarlyDataServerIssueOnly, 11,
      'First direct-library server context');
    AssertServerEarlyDataState(Ctx2, sslEarlyDataServerIssueOnly, 11,
      'Second direct-library server context');
    AssertReplayStoreRejectsCrossContextReplay(
      Ctx1,
      Ctx2,
      ReplayStoreFile,
      'Direct-library replay-store file config'
    );
  finally
    if Supports(Ctx1, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    if Supports(Ctx2, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayStoreFiles(ReplayStoreFile);
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

procedure Test_ServerContextReflectsReplayStoreDirectoryDefaultConfig;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Ctx1: ISSLContext;
  Ctx2: ISSLContext;
  ReplayStoreDirectory: string;
  ReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
begin
  TestHeader('FreePascal direct-library server context reflects replay-store directory defaults');

  Lib := CreateInitializedLibrary;
  ReplayStoreDirectory := BuildReplayStoreDirectoryPath('direct_library_directory');
  CleanupReplayStoreDirectory(ReplayStoreDirectory);
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
    DefaultConfig.ServerMaxEarlyDataSize := 11;
    DefaultConfig.ServerEarlyDataReplayStoreDirectory := ReplayStoreDirectory;
    Lib.SetDefaultConfig(DefaultConfig);

    Ctx1 := Lib.CreateContext(sslCtxServer);
    Ctx2 := Lib.CreateContext(sslCtxServer);
    AssertServerEarlyDataState(Ctx1, sslEarlyDataServerIssueOnly, 11,
      'First direct-library directory replay-store server context');
    AssertServerEarlyDataState(Ctx2, sslEarlyDataServerIssueOnly, 11,
      'Second direct-library directory replay-store server context');
    AssertReplayStoreDirectoryRejectsCrossContextReplay(
      Ctx1,
      Ctx2,
      ReplayStoreDirectory,
      'Direct-library replay-store directory config'
    );
  finally
    if Supports(Ctx1, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    if Supports(Ctx2, IFreePascalEarlyDataReplayLedgerAccess, ReplayAccess) then
      ReplayAccess.ResetEarlyDataReplayLedger;
    CleanupReplayStoreDirectory(ReplayStoreDirectory);
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

procedure Test_ClientContextRejectsReplayStoreFileDefaultConfig;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal direct-library client path rejects replay-store file defaults');

  Lib := CreateInitializedLibrary;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.ServerEarlyDataReplayStoreFile :=
      BuildReplayStoreFilePath('direct_library_client_reject');
    Lib.SetDefaultConfig(DefaultConfig);

    try
      Ctx := Lib.CreateContext(sslCtxClient);
      if Ctx <> nil then;
      Assert(False,
        'FreePascal direct-library client path should reject server_early_data_replay_store_file');
    except
      on E: ESSLConfigurationException do
      begin
        Assert(Pos('server_early_data_replay_store_file', E.Message) > 0,
          'Direct-library client replay-store file error names server_early_data_replay_store_file');
        Assert(Pos('TFreePascalSSLLibrary.CreateContext', E.Message) > 0,
          'Direct-library client replay-store file error identifies the library callsite');
      end;
      on E: Exception do
        Assert(False,
          'Direct-library client replay-store file should raise configuration exception: ' + E.Message);
    end;
  finally
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

procedure Test_ServerContextRejectsConflictingReplayStoreDefaults;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal direct-library server path rejects conflicting replay-store defaults');

  Lib := CreateInitializedLibrary;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.ServerEarlyDataReplayStoreFile :=
      BuildReplayStoreFilePath('direct_library_conflict_file');
    DefaultConfig.ServerEarlyDataReplayStoreDirectory :=
      BuildReplayStoreDirectoryPath('direct_library_conflict_dir');
    Lib.SetDefaultConfig(DefaultConfig);

    try
      Ctx := Lib.CreateContext(sslCtxServer);
      if Ctx <> nil then;
      Assert(False,
        'FreePascal direct-library server path should reject conflicting replay-store defaults');
    except
      on E: ESSLConfigurationException do
      begin
        Assert(Pos('server_early_data_replay_store_file', E.Message) > 0,
          'Conflicting direct-library replay-store error names server_early_data_replay_store_file');
        Assert(Pos('server_early_data_replay_store_directory', E.Message) > 0,
          'Conflicting direct-library replay-store error names server_early_data_replay_store_directory');
        Assert(Pos('not both', LowerCase(E.Message)) > 0,
          'Conflicting direct-library replay-store error explains mutual exclusion');
      end;
      on E: Exception do
        Assert(False,
          'Direct-library conflicting replay-store defaults should raise configuration exception: ' + E.Message);
    end;
  finally
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

begin
  try
    Test_ClientContextReflectsClientEarlyDataDefaultConfig;
    Test_ServerContextReflectsReplayStoreFileDefaultConfig;
    Test_ServerContextReflectsReplayStoreDirectoryDefaultConfig;
    Test_ClientContextRejectsReplayStoreFileDefaultConfig;
    Test_ServerContextRejectsConflictingReplayStoreDefaults;

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
