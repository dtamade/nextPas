unit nextpas_command_env;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, nextpas_projection_types, nextpas_command_envelope,
  nextpas_projection_json, nextpas_projection_text, nextpas_projection_context,
  np_workspace_model, target_config;

procedure RunEnvStatus(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);

procedure RunEnvUse(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);

procedure RunEnvSync(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
procedure RunEnvClean(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);

implementation

type
  TEnvSelectionSidecar = record
    TargetName: string;
    ToolchainBindingId: string;
  end;

function QuoteSidecarString(const Value: string): string;
begin
  Result := StringReplace(Value, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := '"' + Result + '"';
end;

function TrimSidecarString(const Value: string): string;
begin
  Result := Trim(Value);
  if (Length(Result) >= 2) and (Result[1] = '"') and
    (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function EnvSelectionDirectory(const ArtifactRootPath: string): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ArtifactRootPath) + 'env' +
    DirectorySeparator + 'selections'
  );
end;

function EnvSelectionPath(
  const ArtifactRootPath: string;
  const TargetName: string
): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(EnvSelectionDirectory(ArtifactRootPath)) +
    TargetName + '.toml'
  );
end;

function EnvResolutionDirectory(const ArtifactRootPath: string): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ArtifactRootPath) + 'env' +
    DirectorySeparator + 'resolution'
  );
end;

function EnvResolutionPath(
  const ArtifactRootPath: string;
  const TargetName: string
): string;
begin
  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(EnvResolutionDirectory(ArtifactRootPath)) +
    TargetName + '.toml'
  );
end;

function BoolSidecarString(const Value: Boolean): string;
begin
  if Value then
    Exit('true');

  Result := 'false';
end;

function RemoveFileIfExists(const FilePath: string): Boolean;
begin
  Result := False;
  if not FileExists(FilePath) then
    Exit(False);

  if not DeleteFile(FilePath) then
    raise Exception.Create('env-clean-remove-failed: ' + FilePath);

  Result := True;
end;

procedure CaptureWorkspaceSelectionContext(
  var AState: TNextPasState;
  const TargetName: string;
  const WorkspaceOverride: string
);
var
  WorkspaceRootPath: string;
begin
  if WorkspaceOverride = '' then
    Exit;

  WorkspaceRootPath := ExpandFileName(WorkspaceOverride);
  if not DirectoryExists(WorkspaceRootPath) then
    Fail(AState, 'invalid-workspace-root: ' + WorkspaceOverride);

  AState.BuildContext.WorkspaceRootPath := WorkspaceRootPath;
  AState.BuildContext.WorkspaceDiscoveryKind := 'explicit-workspace-override';
  AState.BuildContext.ArtifactRootPath := ResolveWorkspaceArtifactRootPath(
    WorkspaceRootPath
  );
  AState.EnvironmentProjection.SelectionPath := EnvSelectionPath(
    AState.BuildContext.ArtifactRootPath,
    TargetName
  );
  AState.EnvironmentProjection.SelectionTarget := TargetName;
end;

procedure ClearEnvSelectionSidecar(var AInfo: TEnvSelectionSidecar);
begin
  AInfo.TargetName := '';
  AInfo.ToolchainBindingId := '';
end;

procedure ParseEnvSelectionLine(
  var AInfo: TEnvSelectionSidecar;
  const Line: string
);
var
  Key: string;
  SeparatorIndex: SizeInt;
  TrimmedLine: string;
  Value: string;
begin
  TrimmedLine := Trim(Line);
  if TrimmedLine = '' then
    Exit;
  if TrimmedLine[1] = '#' then
    Exit;

  SeparatorIndex := Pos('=', TrimmedLine);
  if SeparatorIndex = 0 then
    Exit;

  Key := LowerCase(Trim(Copy(TrimmedLine, 1, SeparatorIndex - 1)));
  Value := TrimSidecarString(Copy(TrimmedLine, SeparatorIndex + 1, MaxInt));

  if Key = 'target' then
    AInfo.TargetName := Value
  else if Key = 'toolchain_binding' then
    AInfo.ToolchainBindingId := Value;
end;

function ReadEnvSelectionSidecar(
  const SelectionPath: string;
  out AInfo: TEnvSelectionSidecar
): Boolean;
var
  Index: Integer;
  Lines: TStringList;
begin
  ClearEnvSelectionSidecar(AInfo);
  if not FileExists(SelectionPath) then
    Exit(False);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(SelectionPath);
    for Index := 0 to Lines.Count - 1 do
      ParseEnvSelectionLine(AInfo, Lines[Index]);
  finally
    Lines.Free;
  end;

  Result := True;
end;

procedure ApplyWorkspaceSelection(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  out EffectiveToolchainBinding: string
);
var
  SelectionInfo: TEnvSelectionSidecar;
begin
  EffectiveToolchainBinding := ToolchainBindingOverride;
  if AState.EnvironmentProjection.SelectionPath = '' then
    Exit;

  if not ReadEnvSelectionSidecar(
    AState.EnvironmentProjection.SelectionPath,
    SelectionInfo
  ) then
  begin
    AState.EnvironmentProjection.SelectionStatus := 'missing';
    Exit;
  end;

  AState.EnvironmentProjection.SelectionToolchainBindingId :=
    SelectionInfo.ToolchainBindingId;
  if SelectionInfo.TargetName <> '' then
    AState.EnvironmentProjection.SelectionTarget := SelectionInfo.TargetName;

  if SelectionInfo.ToolchainBindingId = '' then
  begin
    AState.EnvironmentProjection.SelectionStatus := 'invalid';
    Exit;
  end;

  if (SelectionInfo.TargetName <> '') and
    (SelectionInfo.TargetName <> TargetName) then
  begin
    AState.EnvironmentProjection.SelectionStatus := 'target-mismatch';
    Exit;
  end;

  if ToolchainBindingOverride <> '' then
  begin
    AState.EnvironmentProjection.SelectionStatus := 'overridden';
    Exit;
  end;

  AState.EnvironmentProjection.SelectionStatus := 'ready';
  EffectiveToolchainBinding := SelectionInfo.ToolchainBindingId;
end;

procedure WriteEnvSelectionSidecar(
  const SelectionPath: string;
  const TargetConfig: TTargetConfig
);
var
  Lines: TStringList;
  SelectionDir: string;
begin
  SelectionDir := ExtractFileDir(SelectionPath);
  if not ForceDirectories(SelectionDir) then
    raise Exception.Create('env-selection-directory-create-failed: ' +
      SelectionDir);

  Lines := TStringList.Create;
  try
    Lines.Add('# nextPas workspace-local environment selection');
    Lines.Add('target = ' + QuoteSidecarString(TargetConfig.TargetId));
    Lines.Add(
      'toolchain_binding = ' +
      QuoteSidecarString(TargetConfig.ToolchainBindingId)
    );
    Lines.Add(
      'toolchain_binding_path = ' +
      QuoteSidecarString(TargetConfig.ToolchainBindingPath)
    );
    Lines.Add('backend_family = ' + QuoteSidecarString(TargetConfig.BackendFamily));
    Lines.Add('runtime_sdk = ' + QuoteSidecarString(TargetConfig.RuntimeSdkId));
    Lines.SaveToFile(SelectionPath);
  finally
    Lines.Free;
  end;
end;

procedure WriteEnvResolutionSidecar(
  const ResolutionPath: string;
  const TargetConfig: TTargetConfig;
  const EnvironmentContext: TEnvironmentProjectionContext;
  out SyncChange: string
);
var
  ExistedBefore: Boolean;
  ExistingLines: TStringList;
  Lines: TStringList;
begin
  ExistedBefore := FileExists(ResolutionPath);
  if not ForceDirectories(ExtractFileDir(ResolutionPath)) then
    raise Exception.Create('env-resolution-directory-create-failed: ' +
      ExtractFileDir(ResolutionPath));

  Lines := TStringList.Create;
  try
    Lines.Add('# nextPas workspace-local environment resolution');
    Lines.Add('target = ' + QuoteSidecarString(TargetConfig.TargetId));
    Lines.Add(
      'selection_path = ' + QuoteSidecarString(EnvironmentContext.SelectionPath)
    );
    Lines.Add(
      'selection_status = ' + QuoteSidecarString(EnvironmentContext.SelectionStatus)
    );
    Lines.Add(
      'selection_target = ' + QuoteSidecarString(EnvironmentContext.SelectionTarget)
    );
    Lines.Add(
      'selection_toolchain_binding_id = ' +
      QuoteSidecarString(EnvironmentContext.SelectionToolchainBindingId)
    );
    Lines.Add(
      'toolchain_binding_path = ' +
      QuoteSidecarString(EnvironmentContext.ToolchainBindingPath)
    );
    Lines.Add(
      'toolchain_binding_id = ' + QuoteSidecarString(TargetConfig.ToolchainBindingId)
    );
    Lines.Add('backend_family = ' + QuoteSidecarString(TargetConfig.BackendFamily));
    Lines.Add('runtime_sdk = ' + QuoteSidecarString(TargetConfig.RuntimeSdkId));
    Lines.Add(
      'distribution_bin_dir = ' +
      QuoteSidecarString(EnvironmentContext.DistributionBinDir)
    );
    Lines.Add(
      'distribution_lib_dir = ' +
      QuoteSidecarString(EnvironmentContext.DistributionLibDir)
    );
    Lines.Add(
      'distribution_share_dir = ' +
      QuoteSidecarString(EnvironmentContext.DistributionShareDir)
    );
    Lines.Add('runtime_root = ' + QuoteSidecarString(EnvironmentContext.RuntimeRootPath));
    Lines.Add('runtime_libc = ' + QuoteSidecarString(EnvironmentContext.RuntimeLibcPath));
    Lines.Add(
      'runtime_libc_present = ' + BoolSidecarString(EnvironmentContext.RuntimeLibcPresent)
    );
    Lines.Add(
      'environment_readiness = ' +
      QuoteSidecarString(EnvironmentContext.EnvironmentReadiness)
    );
    Lines.Add(
      'environment_status = ' + QuoteSidecarString(EnvironmentContext.EnvironmentStatus)
    );
    Lines.Add(
      'runtime_sdk_status = ' + QuoteSidecarString(EnvironmentContext.RuntimeSdkStatus)
    );
    Lines.Add(
      'toolchain_binding_status = ' +
      QuoteSidecarString(EnvironmentContext.ToolchainBindingStatus)
    );
    Lines.Add(
      'distribution_status = ' + QuoteSidecarString(EnvironmentContext.DistributionStatus)
    );

    if ExistedBefore then
    begin
      ExistingLines := TStringList.Create;
      try
        ExistingLines.LoadFromFile(ResolutionPath);
        if ExistingLines.Text = Lines.Text then
        begin
          SyncChange := 'unchanged';
          Exit;
        end;
      finally
        ExistingLines.Free;
      end;
    end;

    Lines.SaveToFile(ResolutionPath);
    if ExistedBefore then
      SyncChange := 'updated'
    else
      SyncChange := 'materialized';
  finally
    Lines.Free;
  end;
end;

procedure RunEnvStatus(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  EffectiveToolchainBinding: string;
  TargetConfig: TTargetConfig;
begin
  AState.BuildContext.TargetName := TargetName;
  CaptureWorkspaceSelectionContext(AState, TargetName, WorkspaceOverride);
  ApplyWorkspaceSelection(
    AState,
    TargetName,
    ToolchainBindingOverride,
    EffectiveToolchainBinding
  );

  try
    TargetConfig := LoadTargetConfig(
      TargetName,
      ParamStr(0),
      EffectiveToolchainBinding
    );
  except
    on E: ETargetConfigError do
      Fail(AState, E.Message);
  end;

  AState.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
  AState.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
  CaptureToolchainProjectionFromTargetConfig(
    AState.ToolchainProjection,
    TargetConfig
  );
  CaptureEnvironmentProjectionFromTargetConfig(
    AState.EnvironmentProjection,
    TargetConfig
  );

  if (AState.EnvironmentProjection.SelectionStatus = 'ready') and
    (AState.EnvironmentProjection.SelectionToolchainBindingId = '') then
    AState.EnvironmentProjection.SelectionToolchainBindingId :=
      TargetConfig.ToolchainBindingId;

  WriteLn('mode=env');
  WriteLn('command=env');
  WriteLn('selector=status');
  WriteLn('target=', TargetName);
  WriteLn('target-config=', TargetConfig.ConfigPath);
  WriteLn('compiler=', TargetConfig.CompilerExecutable);
  PrintBuildContextProjection(False, AState.BuildContext);
  PrintToolchainProjectionFields(False, AState.ToolchainProjection);
  PrintEnvironmentProjectionFields(False, AState.EnvironmentProjection);
  WriteLn('status=success');
  WriteLn('result=success');
  WriteLn('command-outcome=success');
  PrintCommandEnvelope(
    AState,
    ExitSuccessCode,
    'status',
    'success',
    'success',
    '',
    'environment status captured',
    False
  );
  WriteLn('human-summary=environment status captured');
end;

procedure RunEnvUse(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  TargetConfig: TTargetConfig;
begin
  AState.BuildContext.TargetName := TargetName;
  if WorkspaceOverride = '' then
    Fail(AState, 'missing-required-option: --workspace', True);
  if ToolchainBindingOverride = '' then
    Fail(AState, 'missing-required-option: --toolchain-binding', True);

  CaptureWorkspaceSelectionContext(AState, TargetName, WorkspaceOverride);
  try
    TargetConfig := LoadTargetConfig(
      TargetName,
      ParamStr(0),
      ToolchainBindingOverride
    );
    WriteEnvSelectionSidecar(
      AState.EnvironmentProjection.SelectionPath,
      TargetConfig
    );
  except
    on E: ETargetConfigError do
      Fail(AState, E.Message);
    on E: Exception do
      Fail(AState, 'env-selection-write-failed: ' + E.Message);
  end;

  AState.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
  AState.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
  CaptureToolchainProjectionFromTargetConfig(
    AState.ToolchainProjection,
    TargetConfig
  );
  CaptureEnvironmentProjectionFromTargetConfig(
    AState.EnvironmentProjection,
    TargetConfig
  );
  AState.EnvironmentProjection.SelectionStatus := 'updated';
  AState.EnvironmentProjection.SelectionTarget := TargetConfig.TargetId;
  AState.EnvironmentProjection.SelectionToolchainBindingId :=
    TargetConfig.ToolchainBindingId;

  WriteLn('mode=env');
  WriteLn('command=env');
  WriteLn('selector=use');
  WriteLn('target=', TargetName);
  WriteLn('target-config=', TargetConfig.ConfigPath);
  WriteLn('compiler=', TargetConfig.CompilerExecutable);
  PrintBuildContextProjection(False, AState.BuildContext);
  PrintToolchainProjectionFields(False, AState.ToolchainProjection);
  PrintEnvironmentProjectionFields(False, AState.EnvironmentProjection);
  WriteLn('status=success');
  WriteLn('result=success');
  WriteLn('command-outcome=success');
  PrintCommandEnvelope(
    AState,
    ExitSuccessCode,
    'use',
    'success',
    'success',
    '',
    'environment selection updated',
    False
  );
  WriteLn('human-summary=environment selection updated');
end;

procedure RunEnvSync(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  EffectiveToolchainBinding: string;
  TargetConfig: TTargetConfig;
begin
  AState.BuildContext.TargetName := TargetName;
  if WorkspaceOverride = '' then
    Fail(AState, 'missing-required-option: --workspace', True);

  CaptureWorkspaceSelectionContext(AState, TargetName, WorkspaceOverride);
  ApplyWorkspaceSelection(
    AState,
    TargetName,
    ToolchainBindingOverride,
    EffectiveToolchainBinding
  );

  try
    TargetConfig := LoadTargetConfig(
      TargetName,
      ParamStr(0),
      EffectiveToolchainBinding
    );
  except
    on E: ETargetConfigError do
      Fail(AState, E.Message);
    on E: Exception do
      Fail(AState, 'env-resolution-write-failed: ' + E.Message);
  end;

  AState.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
  AState.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
  CaptureToolchainProjectionFromTargetConfig(
    AState.ToolchainProjection,
    TargetConfig
  );
  CaptureEnvironmentProjectionFromTargetConfig(
    AState.EnvironmentProjection,
    TargetConfig
  );
  AState.EnvironmentProjection.ResolutionPath := EnvResolutionPath(
    AState.BuildContext.ArtifactRootPath,
    TargetName
  );
  try
    WriteEnvResolutionSidecar(
      AState.EnvironmentProjection.ResolutionPath,
      TargetConfig,
      AState.EnvironmentProjection,
      AState.EnvironmentProjection.SyncChange
    );
  except
    on E: Exception do
      Fail(AState, 'env-resolution-write-failed: ' + E.Message);
  end;
  AState.EnvironmentProjection.ResolutionStatus := 'ready';

  WriteLn('mode=env');
  WriteLn('command=env');
  WriteLn('selector=sync');
  WriteLn('target=', TargetName);
  WriteLn('target-config=', TargetConfig.ConfigPath);
  WriteLn('compiler=', TargetConfig.CompilerExecutable);
  PrintBuildContextProjection(False, AState.BuildContext);
  PrintToolchainProjectionFields(False, AState.ToolchainProjection);
  PrintEnvironmentProjectionFields(False, AState.EnvironmentProjection);
  WriteLn('status=success');
  WriteLn('result=success');
  WriteLn('command-outcome=success');
  PrintCommandEnvelope(
    AState,
    ExitSuccessCode,
    'sync',
    'success',
    'success',
    '',
    'environment synchronized',
    False
  );
  WriteLn('human-summary=environment synchronized');
end;

procedure RunEnvClean(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  TargetConfig: TTargetConfig;
  CleanSelectionPath: string;
  CleanResolutionPath: string;
  RemovedCount: LongInt;
  Summary: string;
begin
  AState.BuildContext.TargetName := TargetName;
  if WorkspaceOverride = '' then
    Fail(AState, 'missing-required-option: --workspace', True);
  if ToolchainBindingOverride <> '' then
    Fail(AState, 'unknown-option: --toolchain-binding', True);

  CaptureWorkspaceSelectionContext(AState, TargetName, WorkspaceOverride);

  try
    TargetConfig := LoadTargetConfig(
      TargetName,
      ParamStr(0)
    );
  except
    on E: ETargetConfigError do
      Fail(AState, E.Message);
  end;

  AState.BuildContext.TargetConfigPath := TargetConfig.ConfigPath;
  AState.BuildContext.CompilerName := TargetConfig.CompilerExecutable;
  CaptureToolchainProjectionFromTargetConfig(
    AState.ToolchainProjection,
    TargetConfig
  );
  CaptureEnvironmentProjectionFromTargetConfig(
    AState.EnvironmentProjection,
    TargetConfig
  );

  CleanSelectionPath := AState.EnvironmentProjection.SelectionPath;
  CleanResolutionPath := EnvResolutionPath(
    AState.BuildContext.ArtifactRootPath,
    TargetName
  );
  RemovedCount := 0;

  try
    if RemoveFileIfExists(CleanSelectionPath) then
      Inc(RemovedCount);
    if RemoveFileIfExists(CleanResolutionPath) then
      Inc(RemovedCount);
  except
    on E: Exception do
      Fail(AState, E.Message);
  end;

  AState.EnvironmentProjection.CleanSelectionPath := CleanSelectionPath;
  AState.EnvironmentProjection.CleanResolutionPath := CleanResolutionPath;
  AState.EnvironmentProjection.CleanStatus := 'ready';
  if RemovedCount > 0 then
    AState.EnvironmentProjection.CleanChange := 'removed'
  else
    AState.EnvironmentProjection.CleanChange := 'unchanged';
  AState.EnvironmentProjection.CleanRemovedCount := RemovedCount;
  AState.EnvironmentProjection.HasCleanRemovedCount := True;

  if RemovedCount > 0 then
    Summary := 'environment cache cleaned'
  else
    Summary := 'environment cache already clean';

  WriteLn('mode=env');
  WriteLn('command=env');
  WriteLn('selector=clean');
  WriteLn('target=', TargetName);
  WriteLn('target-config=', TargetConfig.ConfigPath);
  WriteLn('compiler=', TargetConfig.CompilerExecutable);
  PrintBuildContextProjection(False, AState.BuildContext);
  PrintToolchainProjectionFields(False, AState.ToolchainProjection);
  PrintEnvironmentProjectionFields(False, AState.EnvironmentProjection);
  WriteLn('status=success');
  WriteLn('result=success');
  WriteLn('command-outcome=success');
  PrintCommandEnvelope(
    AState,
    ExitSuccessCode,
    'clean',
    'success',
    'success',
    '',
    Summary,
    False
  );
  WriteLn('human-summary=', Summary);
end;

end.
