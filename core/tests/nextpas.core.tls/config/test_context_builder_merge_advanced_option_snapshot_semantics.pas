program test_context_builder_merge_advanced_option_snapshot_semantics;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps deprecated WithSNI
  merge semantics coverage for the compatibility-only builder surface. }

uses
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.json.builder,
  nextpas.core.exception,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

procedure TestHeader(const ATestName: string);
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  ', ATestName);
  WriteLn('═══════════════════════════════════════════════════════════');
end;

function ParseBuilderJSON(ABuilder: ISSLContextBuilder): string;
begin
  Result := ABuilder.ExportToJSON;
end;

function CreateJSONBuilder(const AJSON: string): ISSLContextBuilder;
begin
  Result := TSSLContextBuilder.Create.ImportFromJSON(AJSON);
end;

function JSONStr(const AJSON, AKey: string): string;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := '';
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Result := LRoot.Get(AKey).AsStr.ToString;
  finally
    LDoc.Done;
  end;
end;

function JSONBool(const AJSON, AKey: string): Boolean;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := False;
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Result := LRoot.Get(AKey).AsBool;
  finally
    LDoc.Done;
  end;
end;

function OptionCount(const AJSON: string): UInt32;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := 0;
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    if not LRoot.ObjectHas('options') then
      Exit;
    Result := LRoot.Get('options').ArrayLen;
  finally
    LDoc.Done;
  end;
end;

function HasOption(const AJSON: string; AOption: TSSLOption): Boolean;
var
  LDoc: TJsonDocument;
  LRoot, LOptions: TJsonValue;
  I: UInt32;
begin
  Result := False;
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    if not LRoot.ObjectHas('options') then
      Exit;
    LOptions := LRoot.Get('options');
    for I := 0 to LOptions.ArrayLen - 1 do
      if LOptions.ArrayGet(I).AsInt = Ord(AOption) then
        Exit(True);
  finally
    LDoc.Done;
  end;
end;

procedure Test_Merge_EmptyServerNameClearsTargetField;
var
  LTarget, LSource: ISSLContextBuilder;
  LBuild: IJsonBuilder;
  LResultJSON: string;
begin
  TestHeader('Test 1: Merge empty server_name clears target field');

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('server_name'); LBuild.Str('');
  LBuild.EndObject;
  LSource := CreateJSONBuilder(LBuild.ToString);

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LTarget := TSSLContextBuilder.Create.WithSNI('target.example.com');
  {$POP}
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  Assert(JSONStr(LResultJSON, 'server_name') = '',
    'Empty server_name from source clears stale target server_name');
end;

procedure Test_Merge_EmptyALPNClearsTargetField;
var
  LTarget, LSource: ISSLContextBuilder;
  LBuild: IJsonBuilder;
  LResultJSON: string;
begin
  TestHeader('Test 2: Merge empty alpn_protocols clears target field');

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('alpn_protocols'); LBuild.Str('');
  LBuild.EndObject;
  LSource := CreateJSONBuilder(LBuild.ToString);

  LTarget := TSSLContextBuilder.Create.WithALPN('h2,http/1.1');
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  Assert(JSONStr(LResultJSON, 'alpn_protocols') = '',
    'Empty alpn_protocols from source clears stale target ALPN');
end;

procedure Test_Merge_ExplicitEmptyOptionsClearsTargetOptionSet;
var
  LTarget, LSource: ISSLContextBuilder;
  LBuild: IJsonBuilder;
  LResultJSON: string;
begin
  TestHeader('Test 3: Merge options=[] clears target option set');

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('options'); LBuild.BeginArray; LBuild.EndArray;
  LBuild.EndObject;
  LSource := CreateJSONBuilder(LBuild.ToString);

  LTarget := TSSLContextBuilder.Create
    .WithALPN('h2,http/1.1')
    .WithOption(ssoEnableSessionTickets);
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  Assert(OptionCount(LResultJSON) = 0,
    'Explicit empty source options clear the target option array');
  Assert(not HasOption(LResultJSON, ssoEnableSNI),
    'Explicit empty source options remove stale SNI option');
  Assert(not HasOption(LResultJSON, ssoEnableALPN),
    'Explicit empty source options remove stale ALPN option');
end;

procedure Test_Merge_CopiesOCSPBooleansWhenClearingOptions;
var
  LTarget, LSource: ISSLContextBuilder;
  LBuild: IJsonBuilder;
  LResultJSON: string;
begin
  TestHeader('Test 4: Merge copies OCSP booleans when source clears options');

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('options'); LBuild.BeginArray; LBuild.EndArray;
  LBuild.Key('ocsp_stapling_enabled'); LBuild.Bool(False);
  LBuild.Key('ocsp_stapling_required'); LBuild.Bool(False);
  LBuild.EndObject;
  LSource := CreateJSONBuilder(LBuild.ToString);

  LTarget := TSSLContextBuilder.Create
    .WithOCSPStaplingRequired(True);
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  Assert(not JSONBool(LResultJSON, 'ocsp_stapling_enabled'),
    'Source ocsp_stapling_enabled=false clears stale enabled state');
  Assert(not JSONBool(LResultJSON, 'ocsp_stapling_required'),
    'Source ocsp_stapling_required=false clears stale required state');
end;

procedure Test_Merge_CopiesOCSPRequiredStateFromSource;
var
  LTarget, LSource: ISSLContextBuilder;
  LBuild: IJsonBuilder;
  LResultJSON: string;
begin
  TestHeader('Test 5: Merge copies source OCSP required state');

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('ocsp_stapling_enabled'); LBuild.Bool(True);
  LBuild.Key('ocsp_stapling_required'); LBuild.Bool(True);
  LBuild.EndObject;
  LSource := CreateJSONBuilder(LBuild.ToString);

  LTarget := TSSLContextBuilder.Create.WithOCSPStapling(False);
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  Assert(JSONBool(LResultJSON, 'ocsp_stapling_enabled'),
    'Source ocsp_stapling_enabled=true is preserved after merge');
  Assert(JSONBool(LResultJSON, 'ocsp_stapling_required'),
    'Source ocsp_stapling_required=true is preserved after merge');
end;

procedure Test_Merge_CopiesCTRequiredFalseWhenClearingOptions;
var
  LTarget, LSource: ISSLContextBuilder;
  LBuild: IJsonBuilder;
  LResultJSON: string;
begin
  TestHeader('Test 6: Merge copies CT required false when source clears options');

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('options'); LBuild.BeginArray; LBuild.EndArray;
  LBuild.Key('certificate_transparency_required'); LBuild.Bool(False);
  LBuild.EndObject;
  LSource := CreateJSONBuilder(LBuild.ToString);

  LTarget := TSSLContextBuilder.Create
    .WithCertificateTransparencyRequired(True);
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  Assert(not JSONBool(LResultJSON, 'certificate_transparency_required'),
    'Source certificate_transparency_required=false clears stale CT required state');
  Assert(not HasOption(LResultJSON, ssoRequireCertificateTransparency),
    'Source certificate_transparency_required=false clears stale CT required option');
end;

procedure Test_Merge_CopiesCTRequiredStateFromSource;
var
  LTarget, LSource: ISSLContextBuilder;
  LBuild: IJsonBuilder;
  LResultJSON: string;
begin
  TestHeader('Test 7: Merge copies source CT required state');

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('certificate_transparency_required'); LBuild.Bool(True);
  LBuild.EndObject;
  LSource := CreateJSONBuilder(LBuild.ToString);

  LTarget := TSSLContextBuilder.Create;
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  Assert(JSONBool(LResultJSON, 'certificate_transparency_required'),
    'Source certificate_transparency_required=true is preserved after merge');
  Assert(HasOption(LResultJSON, ssoRequireCertificateTransparency),
    'Source certificate_transparency_required=true persists to the exported option set');
end;

begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Context Builder Merge Advanced Option Snapshot Semantics');
  WriteLn('═══════════════════════════════════════════════════════════');

  try
    Test_Merge_EmptyServerNameClearsTargetField;
    Test_Merge_EmptyALPNClearsTargetField;
    Test_Merge_ExplicitEmptyOptionsClearsTargetOptionSet;
    Test_Merge_CopiesOCSPBooleansWhenClearingOptions;
    Test_Merge_CopiesOCSPRequiredStateFromSource;
    Test_Merge_CopiesCTRequiredFalseWhenClearingOptions;
    Test_Merge_CopiesCTRequiredStateFromSource;

    WriteLn;
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Test Summary');
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Tests Passed: ', GTestsPassed);
    WriteLn('  Tests Failed: ', GTestsFailed);
    WriteLn('  Total Tests:  ', GTestsPassed + GTestsFailed);
    WriteLn;

    if GTestsFailed = 0 then
    begin
      WriteLn('  ✓ ALL TESTS PASSED!');
      WriteLn;
      ExitCode := 0;
    end
    else
    begin
      WriteLn('  ✗ SOME TESTS FAILED!');
      WriteLn;
      ExitCode := 1;
    end;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('═══════════════════════════════════════════════════════════');
      WriteLn('  FATAL ERROR');
      WriteLn('═══════════════════════════════════════════════════════════');
      WriteLn('  Class: ', E.ClassName);
      WriteLn('  Message: ', E.Message);
      WriteLn;
      ExitCode := 2;
    end;
  end;
end.
