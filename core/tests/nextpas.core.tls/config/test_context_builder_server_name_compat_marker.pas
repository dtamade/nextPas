program test_context_builder_server_name_compat_marker;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps deprecated WithSNI
  marker coverage for the compatibility-only builder surface. }

uses
  nextpas.core.system.sysutils,
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder;

const
  CCompatMarker = 'deprecated_context_sni';

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

procedure Test_JSONExportMarksDeprecatedContextSNI;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  TestHeader('JSON export marks deprecated context-level SNI');

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LBuilder := TSSLContextBuilder.Create
    .WithSNI('compat.example.com');
  {$POP}

  LJSON := LBuilder.ExportToJSON;
  LDoc.Init(DefaultAllocator);
  try
    Assert(LDoc.Parse(TStringView.FromStr(LJSON)), 'export JSON parses');
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Assert(LRoot.Get('server_name').AsStr.ToString = 'compat.example.com',
      'JSON export keeps server_name compatibility payload');
    Assert(LRoot.ObjectHas('server_name_mode') and
      (LRoot.Get('server_name_mode').AsStr.ToString = CCompatMarker),
      'JSON export marks server_name as deprecated context-level compatibility');
  finally
    LDoc.Done;
  end;
end;

procedure Test_INIExportMarksDeprecatedContextSNI;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
begin
  TestHeader('INI export marks deprecated context-level SNI');

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LBuilder := TSSLContextBuilder.Create
    .WithSNI('compat.example.com');
  {$POP}

  LINI := LBuilder.ExportToINI;
  Assert(Pos('server_name=compat.example.com', LINI) > 0,
    'INI export keeps server_name compatibility payload');
  Assert(Pos('server_name_mode=' + CCompatMarker, LINI) > 0,
    'INI export marks server_name as deprecated context-level compatibility');
end;

procedure Test_LegacyJSONImportUpgradesExportMarker;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  TestHeader('Legacy JSON import upgrades export marker');

  LJSON := '{' +
    '"server_name":"legacy.example.com",' +
    '"alpn_protocols":"h2"' +
    '}';

  LBuilder := TSSLContextBuilder.Create
    .ImportFromJSON(LJSON);

  LJSON := LBuilder.ExportToJSON;
  LDoc.Init(DefaultAllocator);
  try
    Assert(LDoc.Parse(TStringView.FromStr(LJSON)), 'export JSON parses');
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Assert(LRoot.Get('server_name').AsStr.ToString = 'legacy.example.com',
      'legacy JSON import preserves server_name value');
    Assert(LRoot.ObjectHas('server_name_mode') and
      (LRoot.Get('server_name_mode').AsStr.ToString = CCompatMarker),
      'legacy JSON import upgrades export with compatibility marker');
  finally
    LDoc.Done;
  end;
end;

procedure Test_LegacyINIImportUpgradesExportMarker;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
begin
  TestHeader('Legacy INI import upgrades export marker');

  LINI :=
    '[Advanced]' + LineEnding +
    'server_name=legacy.example.com' + LineEnding +
    'alpn_protocols=h2' + LineEnding;

  LBuilder := TSSLContextBuilder.Create
    .ImportFromINI(LINI);

  LINI := LBuilder.ExportToINI;
  Assert(Pos('server_name=legacy.example.com', LINI) > 0,
    'legacy INI import preserves server_name value');
  Assert(Pos('server_name_mode=' + CCompatMarker, LINI) > 0,
    'legacy INI import upgrades export with compatibility marker');
end;

begin
  try
    Test_JSONExportMarksDeprecatedContextSNI;
    Test_INIExportMarksDeprecatedContextSNI;
    Test_LegacyJSONImportUpgradesExportMarker;
    Test_LegacyINIImportUpgradesExportMarker;

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
