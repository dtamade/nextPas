unit nextpas_command_doctor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_command_envelope,
  nextpas_projection_json, nextpas_projection_text, nextpas_projection_context,
  target_config;

procedure RunDoctor(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);

implementation

procedure RunDoctor(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  TargetConfig: TTargetConfig;
  WorkspaceRoot: string;
begin
  AState.BuildContext.TargetName := TargetName;
  WorkspaceRoot := '';
  if WorkspaceOverride <> '' then
  begin
    WorkspaceRoot := ExpandFileName(WorkspaceOverride);
    if not DirectoryExists(WorkspaceRoot) then
      Fail(AState, 'invalid-workspace-root: ' + WorkspaceOverride, True);
    AState.BuildContext.WorkspaceRootPath := WorkspaceRoot;
    AState.BuildContext.WorkspaceDiscoveryKind := 'explicit-workspace-override';
  end;

  try
    TargetConfig := LoadTargetConfig(
      TargetName,
      ParamStr(0),
      ToolchainBindingOverride
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
  CaptureDoctorProjectionFromEnvironment(
    AState.DoctorProjection,
    AState.EnvironmentProjection,
    WorkspaceRoot
  );

  WriteLn('mode=doctor');
  WriteLn('command=doctor');
  WriteLn('selector=doctor');
  WriteLn('target=', TargetName);
  WriteLn('target-config=', TargetConfig.ConfigPath);
  WriteLn('compiler=', TargetConfig.CompilerExecutable);
  PrintBuildContextProjection(False, AState.BuildContext);
  PrintToolchainProjectionFields(False, AState.ToolchainProjection);
  PrintEnvironmentProjectionFields(False, AState.EnvironmentProjection);
  PrintDoctorProjectionFields(False, AState.DoctorProjection);
  WriteLn('status=success');
  WriteLn('result=success');
  WriteLn('command-outcome=success');
  PrintCommandEnvelope(
    AState,
    ExitSuccessCode,
    'doctor',
    'success',
    'success',
    '',
    'doctor inspection completed',
    False
  );
  WriteLn('human-summary=doctor inspection completed');
end;

end.
