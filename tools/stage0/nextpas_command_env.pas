unit nextpas_command_env;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nextpas_projection_types, nextpas_command_envelope,
  nextpas_projection_json, nextpas_projection_text, nextpas_projection_context,
  target_config;

procedure RunEnvStatus(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string
);

implementation

procedure RunEnvStatus(
  var AState: TNextPasState;
  const TargetName: string;
  const ToolchainBindingOverride: string
);
var
  TargetConfig: TTargetConfig;
begin
  AState.BuildContext.TargetName := TargetName;
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

end.
