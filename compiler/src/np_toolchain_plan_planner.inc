procedure AssignToolchainStrings(
  const AVec: TToolchainStringVec;
  const AValues: TStringArray
);
var
  Index: LongInt;
begin
  if AVec = nil then
    Exit;
  AVec.Clear;
  for Index := 0 to Length(AValues) - 1 do
    AVec.Push(AValues[Index]);
end;

constructor TToolchainPlanner.Create(
  const ABackendPlan: TBackendPlan;
  const ATargetFacts: TTargetFactsView;
  const ASourcePath: string
);
begin
  inherited Create;
  FBackendPlan := ABackendPlan;
  FTargetFacts := ATargetFacts;
  FSourcePath := ASourcePath;
  FArtifactRootPath := '';
  FProjectUnitRoots := TToolchainStringVec.Create;
  FExplicitUnitRoots := TToolchainStringVec.Create;
  FAdditionalAssemblyBaseNames := TToolchainStringVec.Create;
  FPlan := TToolchainPlan.Create;
end;

constructor TToolchainPlanner.Create(
  const ABackendPlan: TBackendPlan;
  const ATargetFacts: TTargetFactsView;
  const ASourcePath: string;
  const AArtifactRootPath: string;
  const AProjectUnitRoots: TStringArray;
  const AExplicitUnitRoots: TStringArray;
  const AAdditionalAssemblyBaseNames: TStringArray
);
begin
  inherited Create;
  FBackendPlan := ABackendPlan;
  FTargetFacts := ATargetFacts;
  FSourcePath := ASourcePath;
  FArtifactRootPath := AArtifactRootPath;
  FProjectUnitRoots := TToolchainStringVec.Create;
  FExplicitUnitRoots := TToolchainStringVec.Create;
  FAdditionalAssemblyBaseNames := TToolchainStringVec.Create;
  AssignToolchainStrings(FProjectUnitRoots, AProjectUnitRoots);
  AssignToolchainStrings(FExplicitUnitRoots, AExplicitUnitRoots);
  AssignToolchainStrings(FAdditionalAssemblyBaseNames, AAdditionalAssemblyBaseNames);
  FPlan := TToolchainPlan.Create;
end;

destructor TToolchainPlanner.Destroy;
begin
  FPlan.Free;
  FProjectUnitRoots.Free;
  FProjectUnitRoots := nil;
  FExplicitUnitRoots.Free;
  FExplicitUnitRoots := nil;
  FAdditionalAssemblyBaseNames.Free;
  FAdditionalAssemblyBaseNames := nil;
  inherited Destroy;
end;

function TToolchainPlanner.BuildSysrootRef: string;
begin
  if (FTargetFacts.SysrootMode = '') or (FTargetFacts.RuntimeSdkId = '') then
    Exit('');
  Result := FTargetFacts.SysrootMode + ':' + FTargetFacts.RuntimeSdkId;
end;

function TToolchainPlanner.PrimaryArtifactPathOrDefault: string;
begin
  if (FBackendPlan <> nil) and (FBackendPlan.PrimaryArtifactPath <> '') then
    Exit(FBackendPlan.PrimaryArtifactPath);
  Result := ChangeFileExt(FSourcePath, '');
end;

function TToolchainPlanner.HostCompilerScratchRootPath: string;
begin
  if Trim(FArtifactRootPath) = '' then
    Exit(ExtractFileDir(ExpandFileName(FSourcePath)));

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(FArtifactRootPath) + 'cache' +
    DirectorySeparator + 'host-fpc' + DirectorySeparator + FTargetFacts.TargetId
  );
end;

function TToolchainPlanner.ToolProfileRootPath: string;
begin
  Result := ResolveToolProfileRoot(FTargetFacts.ConfigPath);
end;

function TToolchainPlanner.RepoRootPath: string;
begin
  if Trim(FTargetFacts.ConfigPath) = '' then
    Exit('');

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFileDir(FTargetFacts.ConfigPath)) + '..' +
    DirectorySeparator + '..'
  );
end;

function TToolchainPlanner.FindRuntimeLibrary(const ATargetId: string): string;
var
  EnvDir: string;
  RepoRoot: string;
  Candidate: string;
begin
  Result := '';
  // 1. 环境变量 NEXTPAS_RUNTIME_DIR
  EnvDir := GetEnvironmentVariable('NEXTPAS_RUNTIME_DIR');
  if EnvDir <> '' then
  begin
    Candidate := IncludeTrailingPathDelimiter(EnvDir) +
      'libnprt.a';
    if FsExists(Candidate) then
      Exit(Candidate);
  end;
  // 2. 项目根目录 build/runtime/<target>/
  RepoRoot := RepoRootPath;
  if RepoRoot <> '' then
  begin
    Candidate := IncludeTrailingPathDelimiter(RepoRoot) + 'build' +
      DirectorySeparator + 'runtime' + DirectorySeparator +
      ATargetId + DirectorySeparator + 'libnprt.a';
    if FsExists(Candidate) then
      Exit(Candidate);
  end;
end;

function TToolchainPlanner.DistributionRuntimeRootPath: string;
begin
  if Trim(FTargetFacts.RuntimeSdkId) = '' then
    Exit('');

  Result := ExpandFileName(
    IncludeTrailingPathDelimiter(RepoRootPath) + 'lib' + DirectorySeparator +
    'nextpas' + DirectorySeparator + 'runtime' + DirectorySeparator +
    FTargetFacts.RuntimeSdkId
  );
end;

function TToolchainPlanner.ResolveDirectLinkLibraries(
  out ARuntimeRootPath: string;
  out ASharedLibraryPath: string;
  out AHasResolvedLibrary: Boolean
): Boolean;
var
  Index: LongInt;
  LibraryPath: string;
  LibraryRequest: TBackendLogicalLibraryRequest;
  RuntimeRootPath: string;

  { Standard POSIX library group; on glibc 2.34+ pthread/dl/util/rt are merged
    into libc, so the SDK ships them as aliases of the same ld script. }
  function IsSupportedLogicalId(const AId: string): Boolean;
  begin
    Result := nextpas.core.text.SameText(AId, 'c') or
      nextpas.core.text.SameText(AId, 'pthread') or
      nextpas.core.text.SameText(AId, 'dl') or
      nextpas.core.text.SameText(AId, 'util') or
      nextpas.core.text.SameText(AId, 'rt');
  end;

begin
  ARuntimeRootPath := '';
  ASharedLibraryPath := '';
  AHasResolvedLibrary := False;

  if FBackendPlan = nil then
    Exit(True);

  RuntimeRootPath := DistributionRuntimeRootPath;
  for Index := 0 to FBackendPlan.LogicalLibraryRequestCount - 1 do
  begin
    LibraryRequest := FBackendPlan.LogicalLibraryRequestAt(Index);
    if not IsSupportedLogicalId(LibraryRequest.LogicalId) or
      not nextpas.core.text.SameText(LibraryRequest.LinkageKind, 'shared') then
    begin
      FPlan.MarkFailure(
        'toolchain.import-library-resolution-failed',
        'unsupported direct-link logical library request: logicalId=' +
        LibraryRequest.LogicalId + ' linkageKind=' + LibraryRequest.LinkageKind +
        ' strength=' + LibraryRequest.Strength + ' targetId=' +
        FTargetFacts.TargetId
      );
      Exit(False);
    end;

    LibraryPath := IncludeTrailingPathDelimiter(RuntimeRootPath) + 'lib' +
      LibraryRequest.LogicalId + '.so';
    if not nextpas.core.text.SameText(FTargetFacts.SysrootMode, 'runtime-sdk') or
      not nextpas.core.text.SameText(FTargetFacts.RuntimeRootKind, 'distribution-runtime-root') or
      (RuntimeRootPath = '') or not FsExists(LibraryPath) then
    begin
      FPlan.MarkFailure(
        'toolchain.c-library-not-found',
        'logicalId=' + LibraryRequest.LogicalId + ' targetId=' +
        FTargetFacts.TargetId + ' runtimeSdkId=' + FTargetFacts.RuntimeSdkId +
        ' runtimeRootKind=' + FTargetFacts.RuntimeRootKind + ' runtimeRoot=' +
        RuntimeRootPath + ' libraryPath=' + LibraryPath
      );
      Exit(False);
    end;

    ARuntimeRootPath := RuntimeRootPath;
    ASharedLibraryPath := LibraryPath;
    AHasResolvedLibrary := True;
  end;

  Result := True;
end;

procedure TToolchainPlanner.AppendUnitSearchRoots(
  const AStepIndex: LongInt;
  const AUnitsFlag: string
);
var
  AddedRoots: TStringArray;
  CandidateRoot: string;
  Index: LongInt;
  NextIndex: SizeInt;

  procedure AddUniqueRoot(const ARootPath: string);
  var
    SearchIndex: LongInt;
  begin
    if Trim(ARootPath) = '' then
      Exit;

    CandidateRoot := ExpandFileName(ARootPath);
    for SearchIndex := 0 to Length(AddedRoots) - 1 do
      if AddedRoots[SearchIndex] = CandidateRoot then
        Exit;

    NextIndex := Length(AddedRoots);
    SetLength(AddedRoots, NextIndex + 1);
    AddedRoots[NextIndex] := CandidateRoot;
    FPlan.AddStepArg(AStepIndex, AUnitsFlag + CandidateRoot);
  end;
begin
  SetLength(AddedRoots, 0);
  AddUniqueRoot(ExtractFileDir(ExpandFileName(FSourcePath)));
  if FProjectUnitRoots <> nil then
    for Index := 0 to LongInt(FProjectUnitRoots.Count) - 1 do
      AddUniqueRoot(FProjectUnitRoots[SizeUInt(Index)]);
  if FExplicitUnitRoots <> nil then
    for Index := 0 to LongInt(FExplicitUnitRoots.Count) - 1 do
      AddUniqueRoot(FExplicitUnitRoots[SizeUInt(Index)]);
  { Skip FTargetFacts.UnitsDir: FPC should use its own RTL units (System,
    SysUtils, BaseUnix, etc.) instead of the bridge stubs in the runtime
    SDK directory. The stubs are only needed for nextpas resolution. }
end;

function TToolchainPlanner.PrepareLlvmContract: Boolean;
var
  ExecutableSet: TLlvmExecutableSet;
begin
  if FTargetFacts.LlvmExecutableSetId = '' then
  begin
    if FTargetFacts.LlvmEnabled then
    begin
      ExecutableSet.Id := '';
      ExecutableSet.ToolRootKind := '';
      ExecutableSet.ClangDriver := '';
      ExecutableSet.Llc := '';
      ExecutableSet.Opt := '';
      ExecutableSet.Lld := '';
      ExecutableSet.LlvmAr := '';
      ExecutableSet.SuffixPolicy := '';
      ExecutableSet.VersionContract := '';
      FPlan.SetLlvmExecutableContract('failure', True, ExecutableSet);
      FPlan.MarkFailure(
        'backend.llvm-toolchain-missing',
        'missing llvm executable set id'
      );
      Exit(False);
    end;
    Result := True;
    Exit;
  end;

  if FTargetFacts.LlvmEnabled and (FTargetFacts.LlvmTriple = '') then
  begin
    ExecutableSet.Id := FTargetFacts.LlvmExecutableSetId;
    ExecutableSet.ToolRootKind := '';
    ExecutableSet.ClangDriver := '';
    ExecutableSet.Llc := '';
    ExecutableSet.Opt := '';
    ExecutableSet.Lld := '';
    ExecutableSet.LlvmAr := '';
    ExecutableSet.SuffixPolicy := '';
    ExecutableSet.VersionContract := '';
    FPlan.SetLlvmExecutableContract('failure', True, ExecutableSet);
    FPlan.MarkFailure(
      'backend.llvm-target-profile-missing',
      'missing llvm target triple'
    );
    Exit(False);
  end;

  if FTargetFacts.LlvmEnabled and (FTargetFacts.LlvmDataLayout = '') then
  begin
    ExecutableSet.Id := FTargetFacts.LlvmExecutableSetId;
    ExecutableSet.ToolRootKind := '';
    ExecutableSet.ClangDriver := '';
    ExecutableSet.Llc := '';
    ExecutableSet.Opt := '';
    ExecutableSet.Lld := '';
    ExecutableSet.LlvmAr := '';
    ExecutableSet.SuffixPolicy := '';
    ExecutableSet.VersionContract := '';
    FPlan.SetLlvmExecutableContract('failure', True, ExecutableSet);
    FPlan.MarkFailure(
      'backend.llvm-data-layout-missing',
      'missing llvm data layout'
    );
    Exit(False);
  end;

  try
    ExecutableSet := LoadLlvmExecutableSet(
      ToolProfileRootPath,
      FTargetFacts.LlvmExecutableSetId
    );
  except
    on E: EToolProfileError do
    begin
      ExecutableSet.Id := FTargetFacts.LlvmExecutableSetId;
      ExecutableSet.ToolRootKind := '';
      ExecutableSet.ClangDriver := '';
      ExecutableSet.Llc := '';
      ExecutableSet.Opt := '';
      ExecutableSet.Lld := '';
      ExecutableSet.LlvmAr := '';
      ExecutableSet.SuffixPolicy := '';
      ExecutableSet.VersionContract := '';
      FPlan.SetLlvmExecutableContract(
        'failure',
        FTargetFacts.LlvmEnabled,
        ExecutableSet
      );
      FPlan.MarkFailure('backend.llvm-toolchain-missing', E.Message);
      Exit(False);
    end;
  end;

  if FTargetFacts.LlvmEnabled then
    FPlan.SetLlvmExecutableContract('ready', True, ExecutableSet)
  else
    FPlan.SetLlvmExecutableContract('disabled', False, ExecutableSet);
  Result := True;
end;

procedure TToolchainPlanner.PreparePlanContext(
  const APlanFamily: string;
  const AToolRole: string;
  const AProfileId: string
);
begin
  FPlan.SetPlanFamily(APlanFamily);
  FPlan.SetToolProfileRoot(ToolProfileRootPath);
  FPlan.SetContext(
    AToolRole,
    AProfileId,
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.HostId,
    FTargetFacts.TargetId,
    BuildSysrootRef
  );
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    FTargetFacts.LinkerProfileId,
    'executable',
    PrimaryArtifactPathOrDefault
  );
end;

procedure TToolchainPlanner.AppendBackendLogicalLibraryRequests;
var
  Index: LongInt;
  LibraryRequest: TBackendLogicalLibraryRequest;
begin
  if FBackendPlan = nil then
    Exit;

  for Index := 0 to FBackendPlan.LogicalLibraryRequestCount - 1 do
  begin
    LibraryRequest := FBackendPlan.LogicalLibraryRequestAt(Index);
    FPlan.AddLogicalLibraryRequest(
      LibraryRequest.LogicalId,
      LibraryRequest.LinkageKind,
      LibraryRequest.Strength
    );
  end;
end;

procedure TToolchainPlanner.AppendDirectLinkLibraryArgs(
  const AStepIndex: LongInt
);
var
  Index: LongInt;
begin
  { Requests were validated by ResolveDirectLinkLibraries; duplicates are
    harmless to ld. }
  if FBackendPlan = nil then
    Exit;

  for Index := 0 to FBackendPlan.LogicalLibraryRequestCount - 1 do
    FPlan.AddStepArg(
      AStepIndex,
      '-l' + FBackendPlan.LogicalLibraryRequestAt(Index).LogicalId
    );
end;

procedure TToolchainPlanner.PlanFromBackend;
begin
  if (FBackendPlan = nil) or (FBackendPlan.Status <> 'ready') then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-plan-missing',
      'backend plan is not ready'
    );
    Exit;
  end;

  if nextpas.core.text.SameText(FBackendPlan.BackendFamily, 'llvm') then
    PlanLlvmIrOptObjectLink
  else
    PlanBootstrapNativeAssembleLink;
end;
