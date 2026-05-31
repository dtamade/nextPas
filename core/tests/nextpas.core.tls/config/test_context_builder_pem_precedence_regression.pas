program test_context_builder_pem_precedence_regression;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpjson,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.freepascal.lib;

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

function MakeMissingPath(const APrefix, AExtension: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    APrefix + '_' + FormatDateTime('yyyymmddhhnnsszzz', Now) + '_' +
    IntToStr(Random(1000000)) + AExtension;
end;

function ImportPEMOverrides(ABuilder: ISSLContextBuilder;
  const ACertificatePEM, APrivateKeyPEM: string): ISSLContextBuilder;
var
  LJSON: TJSONObject;
begin
  LJSON := TJSONObject.Create;
  try
    if ACertificatePEM <> '' then
      LJSON.Add('certificate_pem', ACertificatePEM);
    if APrivateKeyPEM <> '' then
      LJSON.Add('private_key_pem', APrivateKeyPEM);
    Result := ABuilder.ImportFromJSON(LJSON.AsJSON);
  finally
    LJSON.Free;
  end;
end;

function ImportFileOverridesJSON(ABuilder: ISSLContextBuilder;
  const ACertificateFile, APrivateKeyFile: string): ISSLContextBuilder;
var
  LJSON: TJSONObject;
begin
  LJSON := TJSONObject.Create;
  try
    if ACertificateFile <> '' then
      LJSON.Add('certificate_file', ACertificateFile);
    if APrivateKeyFile <> '' then
      LJSON.Add('private_key_file', APrivateKeyFile);
    Result := ABuilder.ImportFromJSON(LJSON.AsJSON);
  finally
    LJSON.Free;
  end;
end;

function ImportFileOverridesINI(ABuilder: ISSLContextBuilder;
  const ACertificateFile, APrivateKeyFile: string): ISSLContextBuilder;
var
  LINI: string;
begin
  LINI := '[main]' + LineEnding;
  if ACertificateFile <> '' then
    LINI := LINI + 'certificate_file=' + ACertificateFile + LineEnding;
  if APrivateKeyFile <> '' then
    LINI := LINI + 'private_key_file=' + APrivateKeyFile + LineEnding;
  Result := ABuilder.ImportFromINI(LINI);
end;

function ApplyFileOverrides(ABuilder: ISSLContextBuilder;
  const ACertificateFile, APrivateKeyFile: string): ISSLContextBuilder;
begin
  Result := ABuilder;
  if ACertificateFile <> '' then
    Result := Result.Override('certificate_file', ACertificateFile);
  if APrivateKeyFile <> '' then
    Result := Result.Override('private_key_file', APrivateKeyFile);
end;

function MergeFileOverrides(ABuilder: ISSLContextBuilder;
  const ACertificateFile, APrivateKeyFile: string): ISSLContextBuilder;
var
  LSource: ISSLContextBuilder;
begin
  LSource := TSSLContextBuilder.Create;
  if ACertificateFile <> '' then
    LSource := LSource.WithCertificate(ACertificateFile);
  if APrivateKeyFile <> '' then
    LSource := LSource.WithPrivateKey(APrivateKeyFile);
  Result := ABuilder.Merge(LSource);
end;

function ApplyPEMOverrides(ABuilder: ISSLContextBuilder;
  const ACertificatePEM, APrivateKeyPEM: string): ISSLContextBuilder;
begin
  Result := ABuilder;
  if ACertificatePEM <> '' then
    Result := Result.Override('certificate_pem', ACertificatePEM);
  if APrivateKeyPEM <> '' then
    Result := Result.Override('private_key_pem', APrivateKeyPEM);
end;

procedure LogBuildError(const LResult: TSSLOperationResult);
begin
  if LResult.IsErr then
    WriteLn('    Error: ', LResult.ErrorMessage);
end;

function ErrorMentionsMissingPath(const AErrorMessage, APath: string): Boolean;
var
  LLowerError: string;
  LLowerPath: string;
begin
  LLowerError := LowerCase(AErrorMessage);
  LLowerPath := LowerCase(APath);
  Result :=
    (Pos(LLowerPath, LLowerError) > 0) or
    (Pos(LowerCase(ExtractFileName(APath)), LLowerError) > 0) or
    (Pos('no such file', LLowerError) > 0) or
    (Pos('cannot open', LLowerError) > 0) or
    (Pos('not found', LLowerError) > 0);
end;

procedure Test_ClientCertificatePEMTakesPrecedence;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 1: Client certificate PEM wins over missing file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-cert.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificate(MakeMissingPath('client_cert_missing', '.crt'))
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ImportPEMOverrides(LBuilder, LCertPEM, '');

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Client build succeeds when certificate PEM is imported over missing file');
  LogBuildError(LResult);
  if LResult.IsOk then
    LContext := nil;
end;

procedure Test_ClientPrivateKeyPEMTakesPrecedence;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 2: Client private key PEM wins over missing file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-key.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKey(MakeMissingPath('client_key_missing', '.key'));
  LBuilder := ImportPEMOverrides(LBuilder, '', LKeyPEM);

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Client build succeeds when private key PEM is imported over missing file');
  LogBuildError(LResult);
  if LResult.IsOk then
    LContext := nil;
end;

procedure Test_ServerCertificatePEMTakesPrecedence;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 3: Server certificate PEM wins over missing file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-cert.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificate(MakeMissingPath('server_cert_missing', '.crt'))
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ImportPEMOverrides(LBuilder, LCertPEM, '');

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsOk, 'Server build succeeds when certificate PEM is imported over missing file');
  LogBuildError(LResult);
  if LResult.IsOk then
    LContext := nil;
end;

procedure Test_ServerPrivateKeyPEMTakesPrecedence;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 4: Server private key PEM wins over missing file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-key.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKey(MakeMissingPath('server_key_missing', '.key'));
  LBuilder := ImportPEMOverrides(LBuilder, '', LKeyPEM);

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsOk, 'Server build succeeds when private key PEM is imported over missing file');
  LogBuildError(LResult);
  if LResult.IsOk then
    LContext := nil;
end;

procedure Test_ClientCertificateFileImportClearsStalePEM_JSON;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingCertPath: string;
begin
  TestHeader('Test 5: JSON certificate_file import clears stale certificate PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-cert-file-json.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingCertPath := MakeMissingPath('client_cert_json_missing', '.crt');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ImportFileOverridesJSON(LBuilder, LMissingCertPath, '');

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsErr, 'Client build fails when JSON-imported certificate file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingCertPath),
    'Client build error reflects the imported JSON certificate file path');
end;

procedure Test_ClientPrivateKeyFileImportClearsStalePEM_JSON;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingKeyPath: string;
begin
  TestHeader('Test 6: JSON private_key_file import clears stale private key PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-key-file-json.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingKeyPath := MakeMissingPath('client_key_json_missing', '.key');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ImportFileOverridesJSON(LBuilder, '', LMissingKeyPath);

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsErr, 'Client build fails when JSON-imported private key file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingKeyPath),
    'Client build error reflects the imported JSON private key file path');
end;

procedure Test_ServerCertificateFileImportClearsStalePEM_INI;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingCertPath: string;
begin
  TestHeader('Test 7: INI certificate_file import clears stale certificate PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-cert-file-ini.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingCertPath := MakeMissingPath('server_cert_ini_missing', '.crt');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ImportFileOverridesINI(LBuilder, LMissingCertPath, '');

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Server build fails when INI-imported certificate file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingCertPath),
    'Server build error reflects the imported INI certificate file path');
end;

procedure Test_ServerPrivateKeyFileImportClearsStalePEM_INI;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingKeyPath: string;
begin
  TestHeader('Test 8: INI private_key_file import clears stale private key PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-key-file-ini.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingKeyPath := MakeMissingPath('server_key_ini_missing', '.key');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ImportFileOverridesINI(LBuilder, '', LMissingKeyPath);

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Server build fails when INI-imported private key file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingKeyPath),
    'Server build error reflects the imported INI private key file path');
end;

procedure Test_ClientCertificateFileOverrideClearsStalePEM;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingCertPath: string;
begin
  TestHeader('Test 9: Override certificate_file clears stale certificate PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-cert-file-override.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingCertPath := MakeMissingPath('client_cert_override_missing', '.crt');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ApplyFileOverrides(LBuilder, LMissingCertPath, '');

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsErr, 'Client build fails when overridden certificate file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingCertPath),
    'Client build error reflects the overridden certificate file path');
end;

procedure Test_ClientPrivateKeyFileOverrideClearsStalePEM;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingKeyPath: string;
begin
  TestHeader('Test 10: Override private_key_file clears stale private key PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-key-file-override.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingKeyPath := MakeMissingPath('client_key_override_missing', '.key');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ApplyFileOverrides(LBuilder, '', LMissingKeyPath);

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsErr, 'Client build fails when overridden private key file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingKeyPath),
    'Client build error reflects the overridden private key file path');
end;

procedure Test_ServerCertificateFileOverrideClearsStalePEM;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingCertPath: string;
begin
  TestHeader('Test 11: Override certificate_file clears stale server certificate PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-cert-file-override.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingCertPath := MakeMissingPath('server_cert_override_missing', '.crt');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ApplyFileOverrides(LBuilder, LMissingCertPath, '');

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Server build fails when overridden certificate file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingCertPath),
    'Server build error reflects the overridden certificate file path');
end;

procedure Test_ServerPrivateKeyFileOverrideClearsStalePEM;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingKeyPath: string;
begin
  TestHeader('Test 12: Override private_key_file clears stale server private key PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-key-file-override.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingKeyPath := MakeMissingPath('server_key_override_missing', '.key');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ApplyFileOverrides(LBuilder, '', LMissingKeyPath);

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Server build fails when overridden private key file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingKeyPath),
    'Server build error reflects the overridden private key file path');
end;

procedure Test_ClientCertificateFileMergeClearsStalePEM;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingCertPath: string;
begin
  TestHeader('Test 13: Merge certificate_file clears stale certificate PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-cert-file-merge.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingCertPath := MakeMissingPath('client_cert_merge_missing', '.crt');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := MergeFileOverrides(LBuilder, LMissingCertPath, '');

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsErr, 'Client build fails when merged certificate file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingCertPath),
    'Client build error reflects the merged certificate file path');
end;

procedure Test_ClientPrivateKeyFileMergeClearsStalePEM;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingKeyPath: string;
begin
  TestHeader('Test 14: Merge private_key_file clears stale private key PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-key-file-merge.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingKeyPath := MakeMissingPath('client_key_merge_missing', '.key');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := MergeFileOverrides(LBuilder, '', LMissingKeyPath);

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsErr, 'Client build fails when merged private key file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingKeyPath),
    'Client build error reflects the merged private key file path');
end;

procedure Test_ServerCertificateFileMergeClearsStalePEM;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingCertPath: string;
begin
  TestHeader('Test 15: Merge certificate_file clears stale server certificate PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-cert-file-merge.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingCertPath := MakeMissingPath('server_cert_merge_missing', '.crt');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := MergeFileOverrides(LBuilder, LMissingCertPath, '');

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Server build fails when merged certificate file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingCertPath),
    'Server build error reflects the merged certificate file path');
end;

procedure Test_ServerPrivateKeyFileMergeClearsStalePEM;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingKeyPath: string;
begin
  TestHeader('Test 16: Merge private_key_file clears stale server private key PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-key-file-merge.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LMissingKeyPath := MakeMissingPath('server_key_merge_missing', '.key');
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := MergeFileOverrides(LBuilder, '', LMissingKeyPath);

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Server build fails when merged private key file clears stale PEM');
  LogBuildError(LResult);
  Assert(ErrorMentionsMissingPath(LResult.ErrorMessage, LMissingKeyPath),
    'Server build error reflects the merged private key file path');
end;

procedure Test_ClientCertificatePEMOverrideClearsStaleFile;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 17: Override certificate_pem clears stale certificate file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-cert-pem-override.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificate(MakeMissingPath('client_cert_override_pem_missing', '.crt'))
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ApplyPEMOverrides(LBuilder, LCertPEM, '');

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Client build succeeds when override PEM clears stale certificate file');
  LogBuildError(LResult);
  if LResult.IsOk then
    LContext := nil;
end;

procedure Test_ClientPrivateKeyPEMOverrideClearsStaleFile;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 18: Override private_key_pem clears stale private key file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'client-key-pem-override.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKey(MakeMissingPath('client_key_override_pem_missing', '.key'));
  LBuilder := ApplyPEMOverrides(LBuilder, '', LKeyPEM);

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Client build succeeds when override PEM clears stale private key file');
  LogBuildError(LResult);
  if LResult.IsOk then
    LContext := nil;
end;

procedure Test_ServerCertificatePEMOverrideClearsStaleFile;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 19: Override certificate_pem clears stale server certificate file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-cert-pem-override.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificate(MakeMissingPath('server_cert_override_pem_missing', '.crt'))
    .WithPrivateKeyPEM(LKeyPEM);
  LBuilder := ApplyPEMOverrides(LBuilder, LCertPEM, '');

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsOk, 'Server build succeeds when override PEM clears stale certificate file');
  LogBuildError(LResult);
  if LResult.IsOk then
    LContext := nil;
end;

procedure Test_ServerPrivateKeyPEMOverrideClearsStaleFile;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 20: Override private_key_pem clears stale server private key file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'server-key-pem-override.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKey(MakeMissingPath('server_key_override_pem_missing', '.key'));
  LBuilder := ApplyPEMOverrides(LBuilder, '', LKeyPEM);

  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsOk, 'Server build succeeds when override PEM clears stale private key file');
  LogBuildError(LResult);
  if LResult.IsOk then
    LContext := nil;
end;

begin
  Randomize;

  WriteLn('╔════════════════════════════════════════════════════════════╗');
  WriteLn('║   Context Builder PEM Precedence Regression Tests         ║');
  WriteLn('╚════════════════════════════════════════════════════════════╝');

  try
    Test_ClientCertificatePEMTakesPrecedence;
    Test_ClientPrivateKeyPEMTakesPrecedence;
    Test_ServerCertificatePEMTakesPrecedence;
    Test_ServerPrivateKeyPEMTakesPrecedence;
    Test_ClientCertificateFileImportClearsStalePEM_JSON;
    Test_ClientPrivateKeyFileImportClearsStalePEM_JSON;
    Test_ServerCertificateFileImportClearsStalePEM_INI;
    Test_ServerPrivateKeyFileImportClearsStalePEM_INI;
    Test_ClientCertificateFileOverrideClearsStalePEM;
    Test_ClientPrivateKeyFileOverrideClearsStalePEM;
    Test_ServerCertificateFileOverrideClearsStalePEM;
    Test_ServerPrivateKeyFileOverrideClearsStalePEM;
    Test_ClientCertificateFileMergeClearsStalePEM;
    Test_ClientPrivateKeyFileMergeClearsStalePEM;
    Test_ServerCertificateFileMergeClearsStalePEM;
    Test_ServerPrivateKeyFileMergeClearsStalePEM;
    Test_ClientCertificatePEMOverrideClearsStaleFile;
    Test_ClientPrivateKeyPEMOverrideClearsStaleFile;
    Test_ServerCertificatePEMOverrideClearsStaleFile;
    Test_ServerPrivateKeyPEMOverrideClearsStaleFile;

    WriteLn;
    WriteLn('╔════════════════════════════════════════════════════════════╗');
    WriteLn(Format('║   Tests Passed: %-3d  Failed: %-3d                         ║',
      [GTestsPassed, GTestsFailed]));
    WriteLn('╚════════════════════════════════════════════════════════════╝');

    if GTestsFailed > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
