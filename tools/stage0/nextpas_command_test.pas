unit nextpas_command_test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, process, nextpas_projection_types, nextpas_command_envelope;

procedure RunTest(
  var AState: TNextPasState;
  const AListGroups: Boolean;
  const AFilterName: string;
  const AWorkspaceOverride: string
);

implementation

procedure RunTest(
  var AState: TNextPasState;
  const AListGroups: Boolean;
  const AFilterName: string;
  const AWorkspaceOverride: string
);
var
  ExitCode: LongInt;
  HarnessScriptPath: string;
  Proc: TProcess;
  WorkspaceRoot: string;
begin
  if AWorkspaceOverride <> '' then
    WorkspaceRoot := ExpandFileName(AWorkspaceOverride)
  else
    WorkspaceRoot := ExpandFileName(GetCurrentDir);
  if not DirectoryExists(WorkspaceRoot) then
  begin
    if AWorkspaceOverride <> '' then
      Fail(AState, 'invalid-workspace-root: ' + AWorkspaceOverride, True);
    Fail(AState, 'invalid-workspace-root: ' + WorkspaceRoot, True);
  end;

  HarnessScriptPath := ExpandFileName(
    IncludeTrailingPathDelimiter(WorkspaceRoot) + 'tests' +
    DirectorySeparator + 'run_all_tests.sh'
  );
  if not FileExists(HarnessScriptPath) then
    Fail(AState, 'missing-harness-script: ' + HarnessScriptPath, True);

  Proc := TProcess.Create(nil);
  try
    Proc.Executable := '/usr/bin/env';
    Proc.CurrentDirectory := WorkspaceRoot;
    Proc.Options := [poWaitOnExit];
    Proc.Parameters.Add('NEXTPAS_STAGE0=' + ExpandFileName(ParamStr(0)));
    Proc.Parameters.Add('NEXTPAS_WORKSPACE_ROOT=' + WorkspaceRoot);
    Proc.Parameters.Add('NEXTPAS_REPO_ROOT=' + WorkspaceRoot);
    Proc.Parameters.Add(HarnessScriptPath);
    if AListGroups then
      Proc.Parameters.Add('--list-groups')
    else
    begin
      Proc.Parameters.Add('--filter');
      Proc.Parameters.Add(AFilterName);
    end;
    Proc.Execute;
    ExitCode := Proc.ExitStatus;
  finally
    Proc.Free;
  end;

  Halt(ExitCode);
end;

end.
