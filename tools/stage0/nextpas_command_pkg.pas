unit nextpas_command_pkg;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_command_envelope,
  nextpas_projection_json, nextpas_projection_text, nextpas_projection_context,
  np_package_workflow, np_workspace_model,
  target_config;

procedure RunPkgInspect(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);

implementation

procedure RunPkgInspect(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string;
  const WorkspaceOverride: string
);
var
  InspectionSourcePath: string;
  TargetConfig: TTargetConfig;
  WorkflowTruth: TPackageWorkflowTruth;
  WorkspaceModel: TWorkspaceModel;
  WorkspaceRoot: string;
begin
  AState.BuildContext.TargetName := TargetName;
  if WorkspaceOverride = '' then
    Fail(AState, 'missing-required-option: --workspace', True);

  WorkspaceRoot := ExpandFileName(WorkspaceOverride);
  if not DirectoryExists(WorkspaceRoot) then
    Fail(AState, 'invalid-workspace-root: ' + WorkspaceOverride, True);

  InspectionSourcePath := ResolvePackageInspectionSourcePath(WorkspaceRoot);
  WorkspaceModel := nil;
  try
    WorkspaceModel := ResolveWorkspaceModel(
      InspectionSourcePath,
      WorkspaceRoot,
      TargetName,
      ''
    );
    CaptureBuildCommandContext(AState, '', TargetName, WorkspaceModel);

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
    WorkflowTruth := BuildPackageWorkflowTruthFromWorkspaceModel(WorkspaceModel);
    CapturePackageProjectionFromWorkflowTruth(
      AState.PackageProjection,
      WorkflowTruth
    );

    WriteLn('mode=pkg');
    WriteLn('command=pkg');
    WriteLn('selector=inspect');
    WriteLn('target=', TargetName);
    WriteLn('target-config=', TargetConfig.ConfigPath);
    WriteLn('compiler=', TargetConfig.CompilerExecutable);
    PrintBuildContextProjection(False, AState.BuildContext);
    PrintToolchainProjectionFields(False, AState.ToolchainProjection);
    PrintPackageProjectionFields(False, AState.PackageProjection);
    WriteLn('status=success');
    WriteLn('result=success');
    WriteLn('command-outcome=success');
    PrintCommandEnvelope(
      AState,
      ExitSuccessCode,
      'inspect',
      'success',
      'success',
      '',
      'package inspection completed',
      False
    );
    WriteLn('human-summary=package inspection completed');
  finally
    WorkspaceModel.Free;
  end;
end;

end.
