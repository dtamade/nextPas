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

end.
