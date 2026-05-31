program test_context_builder_merge_advanced_option_snapshot_semantics;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps deprecated WithSNI
  merge semantics coverage for the compatibility-only builder surface. }

uses
  SysUtils,
  fpjson, jsonparser,
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

function ParseBuilderJSON(ABuilder: ISSLContextBuilder): TJSONObject;
begin
  Result := TJSONObject(GetJSON(ABuilder.ExportToJSON));
end;

function CreateJSONBuilder(AJSON: TJSONObject): ISSLContextBuilder;
begin
  Result := TSSLContextBuilder.Create.ImportFromJSON(AJSON.AsJSON);
end;

function HasOption(AJSON: TJSONObject; AOption: TSSLOption): Boolean;
var
  LOptions: TJSONArray;
  I: Integer;
begin
  Result := False;
  if AJSON.IndexOfName('options') < 0 then
    Exit;

  LOptions := AJSON.Arrays['options'];
  for I := 0 to LOptions.Count - 1 do
    if LOptions.Integers[I] = Ord(AOption) then
      Exit(True);
end;

procedure Test_Merge_EmptyServerNameClearsTargetField;
var
  LTarget, LSource: ISSLContextBuilder;
  LSourceJSON, LResultJSON: TJSONObject;
begin
  TestHeader('Test 1: Merge empty server_name clears target field');

  LSourceJSON := TJSONObject.Create;
  try
    LSourceJSON.Add('server_name', '');
    LSource := CreateJSONBuilder(LSourceJSON);
  finally
    LSourceJSON.Free;
  end;

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LTarget := TSSLContextBuilder.Create.WithSNI('target.example.com');
  {$POP}
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  try
    Assert(LResultJSON.Strings['server_name'] = '',
      'Empty server_name from source clears stale target server_name');
  finally
    LResultJSON.Free;
  end;
end;

procedure Test_Merge_EmptyALPNClearsTargetField;
var
  LTarget, LSource: ISSLContextBuilder;
  LSourceJSON, LResultJSON: TJSONObject;
begin
  TestHeader('Test 2: Merge empty alpn_protocols clears target field');

  LSourceJSON := TJSONObject.Create;
  try
    LSourceJSON.Add('alpn_protocols', '');
    LSource := CreateJSONBuilder(LSourceJSON);
  finally
    LSourceJSON.Free;
  end;

  LTarget := TSSLContextBuilder.Create.WithALPN('h2,http/1.1');
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  try
    Assert(LResultJSON.Strings['alpn_protocols'] = '',
      'Empty alpn_protocols from source clears stale target ALPN');
  finally
    LResultJSON.Free;
  end;
end;

procedure Test_Merge_ExplicitEmptyOptionsClearsTargetOptionSet;
var
  LTarget, LSource: ISSLContextBuilder;
  LSourceJSON, LResultJSON: TJSONObject;
begin
  TestHeader('Test 3: Merge options=[] clears target option set');

  LSourceJSON := TJSONObject.Create;
  try
    LSourceJSON.Add('options', TJSONArray.Create);
    LSource := CreateJSONBuilder(LSourceJSON);
  finally
    LSourceJSON.Free;
  end;

  LTarget := TSSLContextBuilder.Create
    .WithALPN('h2,http/1.1')
    .WithOption(ssoEnableSessionTickets);
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  try
    Assert(LResultJSON.Arrays['options'].Count = 0,
      'Explicit empty source options clear the target option array');
    Assert(not HasOption(LResultJSON, ssoEnableSNI),
      'Explicit empty source options remove stale SNI option');
    Assert(not HasOption(LResultJSON, ssoEnableALPN),
      'Explicit empty source options remove stale ALPN option');
  finally
    LResultJSON.Free;
  end;
end;

procedure Test_Merge_CopiesOCSPBooleansWhenClearingOptions;
var
  LTarget, LSource: ISSLContextBuilder;
  LSourceJSON, LResultJSON: TJSONObject;
begin
  TestHeader('Test 4: Merge copies OCSP booleans when source clears options');

  LSourceJSON := TJSONObject.Create;
  try
    LSourceJSON.Add('options', TJSONArray.Create);
    LSourceJSON.Add('ocsp_stapling_enabled', False);
    LSourceJSON.Add('ocsp_stapling_required', False);
    LSource := CreateJSONBuilder(LSourceJSON);
  finally
    LSourceJSON.Free;
  end;

  LTarget := TSSLContextBuilder.Create
    .WithOCSPStaplingRequired(True);
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  try
    Assert(not LResultJSON.Booleans['ocsp_stapling_enabled'],
      'Source ocsp_stapling_enabled=false clears stale enabled state');
    Assert(not LResultJSON.Booleans['ocsp_stapling_required'],
      'Source ocsp_stapling_required=false clears stale required state');
  finally
    LResultJSON.Free;
  end;
end;

procedure Test_Merge_CopiesOCSPRequiredStateFromSource;
var
  LTarget, LSource: ISSLContextBuilder;
  LSourceJSON, LResultJSON: TJSONObject;
begin
  TestHeader('Test 5: Merge copies source OCSP required state');

  LSourceJSON := TJSONObject.Create;
  try
    LSourceJSON.Add('ocsp_stapling_enabled', True);
    LSourceJSON.Add('ocsp_stapling_required', True);
    LSource := CreateJSONBuilder(LSourceJSON);
  finally
    LSourceJSON.Free;
  end;

  LTarget := TSSLContextBuilder.Create.WithOCSPStapling(False);
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  try
    Assert(LResultJSON.Booleans['ocsp_stapling_enabled'],
      'Source ocsp_stapling_enabled=true is preserved after merge');
    Assert(LResultJSON.Booleans['ocsp_stapling_required'],
      'Source ocsp_stapling_required=true is preserved after merge');
  finally
    LResultJSON.Free;
  end;
end;

procedure Test_Merge_CopiesCTRequiredFalseWhenClearingOptions;
var
  LTarget, LSource: ISSLContextBuilder;
  LSourceJSON, LResultJSON: TJSONObject;
begin
  TestHeader('Test 6: Merge copies CT required false when source clears options');

  LSourceJSON := TJSONObject.Create;
  try
    LSourceJSON.Add('options', TJSONArray.Create);
    LSourceJSON.Add('certificate_transparency_required', False);
    LSource := CreateJSONBuilder(LSourceJSON);
  finally
    LSourceJSON.Free;
  end;

  LTarget := TSSLContextBuilder.Create
    .WithCertificateTransparencyRequired(True);
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  try
    Assert(not LResultJSON.Booleans['certificate_transparency_required'],
      'Source certificate_transparency_required=false clears stale CT required state');
    Assert(not HasOption(LResultJSON, ssoRequireCertificateTransparency),
      'Source certificate_transparency_required=false clears stale CT required option');
  finally
    LResultJSON.Free;
  end;
end;

procedure Test_Merge_CopiesCTRequiredStateFromSource;
var
  LTarget, LSource: ISSLContextBuilder;
  LSourceJSON, LResultJSON: TJSONObject;
begin
  TestHeader('Test 7: Merge copies source CT required state');

  LSourceJSON := TJSONObject.Create;
  try
    LSourceJSON.Add('certificate_transparency_required', True);
    LSource := CreateJSONBuilder(LSourceJSON);
  finally
    LSourceJSON.Free;
  end;

  LTarget := TSSLContextBuilder.Create;
  LTarget.Merge(LSource);

  LResultJSON := ParseBuilderJSON(LTarget);
  try
    Assert(LResultJSON.Booleans['certificate_transparency_required'],
      'Source certificate_transparency_required=true is preserved after merge');
    Assert(HasOption(LResultJSON, ssoRequireCertificateTransparency),
      'Source certificate_transparency_required=true persists to the exported option set');
  finally
    LResultJSON.Free;
  end;
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
