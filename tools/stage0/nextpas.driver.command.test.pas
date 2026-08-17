unit nextpas.driver.command.test;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.path, nextpas.core.fs, nextpas.core.process,
  nextpas_projection_types, nextpas_command_envelope;

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
  Cmd: ICommand;
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

  { Run the harness via nextpas.core.process instead of the FPC Process stub
    so the compile chain stops consuming it. EnvAdd injects NEXTPAS_* into
    the child environment (inherited by the shell script), equivalent to the
    old `env KEY=VALUE …` argv form. Status() keeps stdout/stderr inherited,
    same as TProcess with poWaitOnExit. }
  Cmd := Command('/usr/bin/env')
    .Dir(WorkspaceRoot)
    .EnvAdd('NEXTPAS_STAGE0', ExpandFileName(ParamStr(0)))
    .EnvAdd('NEXTPAS_WORKSPACE_ROOT', WorkspaceRoot)
    .EnvAdd('NEXTPAS_REPO_ROOT', WorkspaceRoot)
    .Arg(HarnessScriptPath);
  if AListGroups then
    Cmd := Cmd.Arg('--list-groups')
  else
    Cmd := Cmd.Args(['--filter', AFilterName]);
  ExitCode := Cmd.Status.ExitCode;

  Halt(ExitCode);
end;

end.
