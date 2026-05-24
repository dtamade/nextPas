program nextpas;

{$mode objfpc}{$H+}
{$UNITPATH ../../compiler/backend}
{$UNITPATH ../../compiler/frontend}
{$UNITPATH ../../compiler/diagnostics}
{$UNITPATH ../../compiler/ir}
{$UNITPATH ../../compiler/sema}
{$UNITPATH ../../compiler/syntax}
{$UNITPATH ../../compiler/toolchain}
{$UNITPATH ../../compiler/targets}

uses
  SysUtils, nextpas_projection_types, nextpas_command_envelope,
  nextpas_command_build, nextpas_command_test, nextpas_command_env,
  nextpas_command_doctor, nextpas_command_query, nextpas_command_pkg,
  nextpas_projection_context;

var
  State: TNextPasState;
  CommandName: string;
  Index: LongInt;
  ListGroups: Boolean;
  SourcePath: string;
  TargetName: string;
  TestFilterName: string;
  ToolchainBindingOverride: string;
  UnitRootOverrides: TStringArray;
  WorkspaceOverride: string;
  OutDirOverride: string;
  OptionName: string;
  NoFold: Boolean;
  FoldSeen: Boolean;
  NoFoldSeen: Boolean;

begin
  State.CommandName := '';
  State.SelectorName := '';
  ClearBuildCommandContext(State);
  ClearSessionContext(State);

  if ParamCount = 0 then
    Fail(State, 'invalid-arguments', True);

  if (ParamCount = 1) and ((ParamStr(1) = '--help') or (ParamStr(1) = '-h')) then
  begin
    PrintUsage(State.CommandName);
    Halt(ExitSuccessCode);
  end;

  CommandName := ParamStr(1);
  State.CommandName := CommandName;

  if (CommandName <> 'build') and (CommandName <> 'test') and
    (CommandName <> 'env') and (CommandName <> 'doctor') and
    (CommandName <> 'query') and (CommandName <> 'pkg') then
    Fail(State, 'unsupported-command: ' + CommandName);

  if CommandName = 'test' then
  begin
    ListGroups := False;
    TestFilterName := '';
    WorkspaceOverride := '';
    Index := 2;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if OptionName = '--list-groups' then
      begin
        if ListGroups or (TestFilterName <> '') then
          Fail(State, 'invalid-arguments', True);
        ListGroups := True;
      end
      else if OptionName = '--filter' then
      begin
        if ListGroups or (TestFilterName <> '') then
          Fail(State, 'invalid-arguments', True);
        if Index = ParamCount then
          Fail(State, 'invalid-arguments', True);
        Inc(Index);
        TestFilterName := ParamStr(Index);
      end
      else if OptionName = '--workspace' then
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        if Index = ParamCount then
          Fail(State, 'invalid-arguments', True);
        Inc(Index);
        WorkspaceOverride := ParamStr(Index);
      end
      else
        Fail(State, 'unknown-option: ' + OptionName, True);

      Inc(Index);
    end;

    if not ListGroups and (TestFilterName = '') then
      Fail(State, 'invalid-arguments', True);

    RunTest(State, ListGroups, TestFilterName, WorkspaceOverride);
  end;

  if CommandName = 'env' then
  begin
    if ParamCount < 3 then
      Fail(State, 'invalid-arguments', True);
    if (ParamStr(2) <> 'status') and (ParamStr(2) <> 'use') and
      (ParamStr(2) <> 'sync') and (ParamStr(2) <> 'clean') then
      Fail(State, 'invalid-arguments', True);

    State.SelectorName := ParamStr(2);
    TargetName := '';
    ToolchainBindingOverride := '';
    WorkspaceOverride := '';
    Index := 3;
    if State.SelectorName = 'clean' then
    begin
      while Index <= ParamCount do
      begin
        OptionName := ParamStr(Index);
        if (OptionName <> '--target') and (OptionName <> '--workspace') then
          Fail(State, 'unknown-option: ' + OptionName, True);
        if Index = ParamCount then
          Fail(State, 'invalid-arguments', True);
        Inc(Index);
        if OptionName = '--target' then
        begin
          if TargetName <> '' then
            Fail(State, 'duplicate-option: --target', True);
          TargetName := ParamStr(Index);
        end
        else
        begin
          if WorkspaceOverride <> '' then
            Fail(State, 'duplicate-option: --workspace', True);
          WorkspaceOverride := ParamStr(Index);
        end;
        Inc(Index);
      end;
    end
    else
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') and
        (OptionName <> '--workspace') then
        Fail(State, 'unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else
      if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail(State, 'missing-required-option: --target', True);

    if State.SelectorName = 'status' then
      RunEnvStatus(
        State,
        TargetName,
        ToolchainBindingOverride,
        WorkspaceOverride
      )
    else if State.SelectorName = 'use' then
      RunEnvUse(
        State,
        TargetName,
        ToolchainBindingOverride,
        WorkspaceOverride
      )
    else if State.SelectorName = 'clean' then
      RunEnvClean(
        State,
        TargetName,
        ToolchainBindingOverride,
        WorkspaceOverride
      )
    else
      RunEnvSync(
        State,
        TargetName,
        ToolchainBindingOverride,
        WorkspaceOverride
      );
    Halt(ExitSuccessCode);
  end;

  if CommandName = 'doctor' then
  begin
    State.SelectorName := 'doctor';
    if ParamCount < 2 then
      Fail(State, 'invalid-arguments', True);

    TargetName := '';
    ToolchainBindingOverride := '';
    WorkspaceOverride := '';
    Index := 2;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') and
        (OptionName <> '--workspace') then
        Fail(State, 'unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail(State, 'missing-required-option: --target', True);

    RunDoctor(State, TargetName, ToolchainBindingOverride, WorkspaceOverride);
    Halt(ExitSuccessCode);
  end;

  if CommandName = 'query' then
  begin
    State.SelectorName := 'query';
    if ParamCount < 3 then
      Fail(State, 'invalid-arguments', True);
    if ParamStr(2) <> 'symbols' then
      Fail(State, 'invalid-arguments', True);

    State.SelectorName := 'symbols';
    SourcePath := ParamStr(3);
    TargetName := '';
    ToolchainBindingOverride := '';
    WorkspaceOverride := '';
    Index := 4;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') and
        (OptionName <> '--workspace') then
        Fail(State, 'unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail(State, 'missing-required-option: --target', True);

    RunQuerySymbols(
      State,
      SourcePath,
      TargetName,
      ToolchainBindingOverride,
      WorkspaceOverride
    );
    Halt(ExitSuccessCode);
  end;

  if CommandName = 'pkg' then
  begin
    State.SelectorName := 'pkg';
    if ParamCount < 3 then
      Fail(State, 'invalid-arguments', True);
    if (ParamStr(2) <> 'inspect') and (ParamStr(2) <> 'graph') then
      Fail(State, 'invalid-arguments', True);

    State.SelectorName := ParamStr(2);
    TargetName := '';
    ToolchainBindingOverride := '';
    WorkspaceOverride := '';
    Index := 3;
    while Index <= ParamCount do
    begin
      OptionName := ParamStr(Index);
      if (OptionName <> '--target') and
        (OptionName <> '--toolchain-binding') and
        (OptionName <> '--workspace') then
        Fail(State, 'unknown-option: ' + OptionName, True);
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);
      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end;
      Inc(Index);
    end;

    if TargetName = '' then
      Fail(State, 'missing-required-option: --target', True);

    if State.SelectorName = 'inspect' then
      RunPkgInspect(
        State,
        TargetName,
        ToolchainBindingOverride,
        WorkspaceOverride
      )
    else
      RunPkgGraph(
        State,
        TargetName,
        ToolchainBindingOverride,
        WorkspaceOverride
      );
    Halt(ExitSuccessCode);
  end;

  if ParamCount < 4 then
    Fail(State, 'invalid-arguments', True);

  SourcePath := ParamStr(2);
  TargetName := '';
  ToolchainBindingOverride := '';
  WorkspaceOverride := '';
  OutDirOverride := '';
  NoFold := True;
  FoldSeen := False;
  NoFoldSeen := False;
  SetLength(UnitRootOverrides, 0);

  Index := 3;
  while Index <= ParamCount do
  begin
    OptionName := ParamStr(Index);
    if OptionName = '--no-fold' then
    begin
      if NoFoldSeen then
        Fail(State, 'duplicate-option: --no-fold', True);
      if FoldSeen then
        Fail(State, 'conflicting-option: --no-fold after --fold', True);
      NoFoldSeen := True;
      NoFold := True;
    end
    else if OptionName = '--fold' then
    begin
      if FoldSeen then
        Fail(State, 'duplicate-option: --fold', True);
      if NoFoldSeen then
        Fail(State, 'conflicting-option: --fold after --no-fold', True);
      FoldSeen := True;
      NoFold := False;
    end
    else if (OptionName = '--target') or
      (OptionName = '--toolchain-binding') or
      (OptionName = '--workspace') or
      (OptionName = '--unit-root') or
      (OptionName = '--out-dir') then
    begin
      if Index = ParamCount then
        Fail(State, 'invalid-arguments', True);
      Inc(Index);

      if OptionName = '--target' then
      begin
        if TargetName <> '' then
          Fail(State, 'duplicate-option: --target', True);
        TargetName := ParamStr(Index);
      end
      else if OptionName = '--toolchain-binding' then
      begin
        if ToolchainBindingOverride <> '' then
          Fail(State, 'duplicate-option: --toolchain-binding', True);
        ToolchainBindingOverride := ParamStr(Index);
      end
      else if OptionName = '--workspace' then
      begin
        if WorkspaceOverride <> '' then
          Fail(State, 'duplicate-option: --workspace', True);
        WorkspaceOverride := ParamStr(Index);
      end
      else if OptionName = '--out-dir' then
      begin
        if OutDirOverride <> '' then
          Fail(State, 'duplicate-option: --out-dir', True);
        OutDirOverride := ParamStr(Index);
      end
      else
      begin
        SetLength(UnitRootOverrides, Length(UnitRootOverrides) + 1);
        UnitRootOverrides[Length(UnitRootOverrides) - 1] := ParamStr(Index);
      end;
    end
    else
      Fail(State, 'unknown-option: ' + OptionName, True);

    Inc(Index);
  end;

  if TargetName = '' then
    Fail(State, 'missing-required-option: --target', True);

  RunBuild(
    State,
    SourcePath,
    TargetName,
    ToolchainBindingOverride,
    WorkspaceOverride,
    UnitRootOverrides,
    OutDirOverride,
    NoFold
  );
end.
