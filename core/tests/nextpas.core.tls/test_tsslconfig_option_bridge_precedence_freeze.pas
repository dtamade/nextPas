program test_tsslconfig_option_bridge_precedence_freeze;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally freezes the remaining
  option-bridge boolean write precedence so the v1.x compatibility contract
  cannot silently drift back into an unspecified surface. }

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory;

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

procedure Test_NormalizeConfig_LegacyBooleansOverrideConflictingOptions;
var
  Config: TSSLConfig;
begin
  TestHeader('NormalizeConfig lets legacy booleans override conflicting option bits');

  Config := CreateDefaultConfig(sslCtxClient);
  Config.LibraryType := sslFreePascal;

  Include(Config.Options, ssoDisableCompression);
  Config.EnableCompression := True;
  TSSLFactory.NormalizeConfig(Config);
  Assert(not (ssoDisableCompression in Config.Options),
    'EnableCompression=True clears conflicting disable-compression option');
  Assert(Config.EnableCompression,
    'EnableCompression=True remains projected from final option truth');

  Config := CreateDefaultConfig(sslCtxClient);
  Config.LibraryType := sslFreePascal;
  Exclude(Config.Options, ssoEnableSessionTickets);
  Config.EnableSessionTickets := True;
  TSSLFactory.NormalizeConfig(Config);
  Assert(ssoEnableSessionTickets in Config.Options,
    'EnableSessionTickets=True restores conflicting session-ticket option');
  Assert(Config.EnableSessionTickets,
    'EnableSessionTickets=True remains projected from final option truth');

  Config := CreateDefaultConfig(sslCtxClient);
  Config.LibraryType := sslFreePascal;
  Include(Config.Options, ssoEnableOCSPStapling);
  Config.EnableOCSPStapling := False;
  TSSLFactory.NormalizeConfig(Config);
  Assert(not (ssoEnableOCSPStapling in Config.Options),
    'EnableOCSPStapling=False clears conflicting OCSP stapling option');
  Assert(not Config.EnableOCSPStapling,
    'EnableOCSPStapling=False remains projected from final option truth');
end;

procedure Test_FactoryOneShotContext_FollowsLegacyBooleanPrecedence;
var
  Config: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('Factory one-shot CreateContext follows legacy boolean precedence');

  Config := CreateDefaultConfig(sslCtxClient);
  Config.LibraryType := sslFreePascal;
  Exclude(Config.Options, ssoEnableSessionTickets);
  Config.EnableSessionTickets := True;
  Include(Config.Options, ssoEnableOCSPStapling);
  Config.EnableOCSPStapling := False;

  Ctx := TSSLFactory.CreateContext(Config);
  Assert(Ctx <> nil, 'TSSLFactory.CreateContext(const AConfig) returns a context');
  Assert(ssoEnableSessionTickets in Ctx.GetOptions,
    'one-shot factory context keeps session-ticket option from legacy boolean truth');
  Assert(not (ssoEnableOCSPStapling in Ctx.GetOptions),
    'one-shot factory context clears conflicting OCSP stapling option from legacy boolean truth');
end;

procedure Test_DirectLibraryDefaultConfig_FollowsLegacyBooleanPrecedence;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  ConflictingConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('Direct-library default config follows legacy boolean precedence');

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  try
    ConflictingConfig := OriginalConfig;
    Include(ConflictingConfig.Options, ssoDisableCompression);
    ConflictingConfig.EnableCompression := True;
    Exclude(ConflictingConfig.Options, ssoEnableSessionTickets);
    ConflictingConfig.EnableSessionTickets := True;
    Include(ConflictingConfig.Options, ssoEnableOCSPStapling);
    ConflictingConfig.EnableOCSPStapling := False;

    Lib.SetDefaultConfig(ConflictingConfig);
    ConflictingConfig := Lib.GetDefaultConfig;
    Assert(not (ssoDisableCompression in ConflictingConfig.Options),
      'SetDefaultConfig normalizes compression conflict to legacy boolean truth');
    Assert(ssoEnableSessionTickets in ConflictingConfig.Options,
      'SetDefaultConfig normalizes session-ticket conflict to legacy boolean truth');
    Assert(not (ssoEnableOCSPStapling in ConflictingConfig.Options),
      'SetDefaultConfig normalizes OCSP stapling conflict to legacy boolean truth');

    Ctx := Lib.CreateContext(sslCtxClient);
    Assert(Ctx <> nil, 'ISSLLibrary.CreateContext(AType) returns a context after conflicting defaults');
    Assert(not (ssoDisableCompression in Ctx.GetOptions),
      'direct-library context keeps compression truth from normalized legacy boolean');
    Assert(ssoEnableSessionTickets in Ctx.GetOptions,
      'direct-library context keeps session-ticket truth from normalized legacy boolean');
    Assert(not (ssoEnableOCSPStapling in Ctx.GetOptions),
      'direct-library context keeps OCSP stapling truth from normalized legacy boolean');
  finally
    Lib.SetDefaultConfig(OriginalConfig);
  end;
end;

begin
  try
    Test_NormalizeConfig_LegacyBooleansOverrideConflictingOptions;
    Test_FactoryOneShotContext_FollowsLegacyBooleanPrecedence;
    Test_DirectLibraryDefaultConfig_FollowsLegacyBooleanPrecedence;

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
