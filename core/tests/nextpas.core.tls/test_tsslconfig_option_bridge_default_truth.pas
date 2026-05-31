program test_tsslconfig_option_bridge_default_truth;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps option-bridge boolean
  coverage so the remaining TSSLConfig compatibility-write surface stays
  explicit while new code is steered toward Options. }

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib;

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
    raise Exception.Create('FreePascal library failed to initialize for option-bridge default truth test');
end;

procedure Test_FreePascalLibraryDefaultConfig_ProjectsOptionBridgeTruth;
var
  Lib: ISSLLibrary;
  Config: TSSLConfig;
begin
  TestHeader('FreePascal library default-config projects option-bridge truth');

  Lib := CreateFreePascalSSLLibrary;
  try
    Config := Lib.GetDefaultConfig;

    Assert(not Config.EnableCompression,
      'FreePascal library default config keeps EnableCompression = False');
    Assert(ssoDisableCompression in Config.Options,
      'FreePascal library default config keeps disable-compression in Options');
    Assert(Config.EnableSessionTickets,
      'FreePascal library default config keeps EnableSessionTickets = True');
    Assert(ssoEnableSessionTickets in Config.Options,
      'FreePascal library default config keeps session-ticket option enabled');
    Assert(not Config.EnableOCSPStapling,
      'FreePascal library default config keeps EnableOCSPStapling = False');
    Assert(not (ssoEnableOCSPStapling in Config.Options),
      'FreePascal library default config does not claim OCSP stapling in Options');
  finally
    Lib := nil;
  end;
end;

procedure Test_FreePascalDefaultConfig_RoundTripPreservesOptionBridgeTruth;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal SetDefaultConfig(GetDefaultConfig) preserves option-bridge truth');

  Lib := CreateInitializedLibrary;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    Lib.SetDefaultConfig(OriginalConfig);

    Ctx := Lib.CreateContext(sslCtxClient);

    Assert(ssoDisableCompression in Ctx.GetOptions,
      'FreePascal round-trip keeps disable-compression option on new client contexts');
    Assert(ssoEnableSessionTickets in Ctx.GetOptions,
      'FreePascal round-trip keeps session-ticket option on new client contexts');
    Assert(not (ssoEnableOCSPStapling in Ctx.GetOptions),
      'FreePascal round-trip keeps OCSP stapling disabled by default');
  finally
    Ctx := nil;
    Lib.Finalize;
  end;
end;

procedure Test_CreateDefaultConfig_WithFreePascalDefaultLibrary_KeepsOptionBridgeTruth;
var
  OriginalDefaultLibrary: TSSLLibraryType;
  DirectLib: ISSLLibrary;
  AutoLib: ISSLLibrary;
  DirectConfig: TSSLConfig;
  AutoConfig: TSSLConfig;
  Config: TSSLConfig;
begin
  TestHeader('CreateDefaultConfig under FreePascal default library keeps option-bridge truth');

  OriginalDefaultLibrary := TSSLFactory.GetDefaultLibrary;
  try
    TSSLFactory.SetDefaultLibrary(sslFreePascal);

    DirectLib := TSSLFactory.GetLibrary(sslFreePascal);
    Assert((DirectLib <> nil) and (DirectLib.GetLibraryType = sslFreePascal),
      'TSSLFactory.GetLibrary(sslFreePascal) returns the FreePascal backend');
    DirectConfig := DirectLib.GetDefaultConfig;
    Assert(DirectConfig.EnableSessionTickets,
      'factory-held FreePascal library default config keeps EnableSessionTickets = True');
    Assert(ssoEnableSessionTickets in DirectConfig.Options,
      'factory-held FreePascal library default config keeps session-ticket option enabled');

    AutoLib := TSSLFactory.GetLibrary(sslAutoDetect);
    Assert((AutoLib <> nil) and (AutoLib.GetLibraryType = sslFreePascal),
      'TSSLFactory.GetLibrary(sslAutoDetect) resolves to FreePascal after SetDefaultLibrary');
    AutoConfig := AutoLib.GetDefaultConfig;
    Assert(AutoConfig.EnableSessionTickets,
      'auto-detected library default config keeps EnableSessionTickets = True after SetDefaultLibrary');
    Assert(ssoEnableSessionTickets in AutoConfig.Options,
      'auto-detected library default config keeps session-ticket option after SetDefaultLibrary');

    Config := CreateDefaultConfig(sslCtxClient);

    Assert(not Config.EnableCompression,
      'CreateDefaultConfig keeps EnableCompression = False under FreePascal default library');
    Assert(ssoDisableCompression in Config.Options,
      'CreateDefaultConfig keeps disable-compression option under FreePascal default library');
    Assert(Config.EnableSessionTickets,
      'CreateDefaultConfig keeps EnableSessionTickets = True under FreePascal default library');
    Assert(ssoEnableSessionTickets in Config.Options,
      'CreateDefaultConfig keeps session-ticket option under FreePascal default library');
    Assert(not Config.EnableOCSPStapling,
      'CreateDefaultConfig keeps EnableOCSPStapling = False under FreePascal default library');
  finally
    TSSLFactory.SetDefaultLibrary(OriginalDefaultLibrary);
  end;
end;

begin
  try
    Test_FreePascalLibraryDefaultConfig_ProjectsOptionBridgeTruth;
    Test_FreePascalDefaultConfig_RoundTripPreservesOptionBridgeTruth;
    Test_CreateDefaultConfig_WithFreePascalDefaultLibrary_KeepsOptionBridgeTruth;

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
