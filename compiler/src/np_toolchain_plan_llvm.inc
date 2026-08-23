procedure TToolchainPlanner.PlanLlvmIrOptObjectLink;
var
  ArtifactPath: string;
  BackendCacheRoot: string;
  BitcodeArtifactPath: string;
  ExecutableSet: TLlvmExecutableSet;
  HasResolvedLibrary: Boolean;
  IrArtifactPath: string;
  LinkStep: LongInt;
  LinkerProfile: TLinkerProfile;
  LlvmStep: LongInt;
  ObjectArtifactPath: string;
  OutputKindValue: string;
  PrimaryArtifactKindValue: string;
  RuntimeLibPath: string;
  RuntimeRootPath: string;
  SharedLibraryPath: string;
begin
  try
    LinkerProfile := LoadLinkerProfile(
      ToolProfileRootPath,
      FTargetFacts.LinkerProfileId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('toolchain.profile-metadata-missing', E.Message);
      Exit;
    end;
  end;

  if not PrepareLlvmContract then
    Exit;

  try
    ExecutableSet := LoadLlvmExecutableSet(
      ToolProfileRootPath,
      FTargetFacts.LlvmExecutableSetId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('backend.llvm-toolchain-missing', E.Message);
      Exit;
    end;
  end;

  ArtifactPath := PrimaryArtifactPathOrDefault;
  IrArtifactPath := FBackendPlan.ArtifactPathByKind('llvm-ir');
  BitcodeArtifactPath := FBackendPlan.ArtifactPathByKind('llvm-bitcode');
  ObjectArtifactPath := FBackendPlan.ArtifactPathByKind('object-file');
  if (IrArtifactPath = '') or (BitcodeArtifactPath = '') or
    (ObjectArtifactPath = '') then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-artifact-missing',
      'backend plan is missing llvm/object artifacts'
    );
    Exit;
  end;

  BackendCacheRoot := ExtractFileDir(ExpandFileName(IrArtifactPath));
  if BackendCacheRoot = '' then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-artifact-missing',
      'backend llvm ir artifact has no parent directory'
    );
    Exit;
  end;

  PreparePlanContext(
    'llvm-ir-opt-llc',
    'llvm-backend',
    ExecutableSet.Id
  );
  OutputKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.OutputKind <> '') then
    OutputKindValue := FBackendPlan.OutputKind;
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    LinkerProfile.Id,
    OutputKindValue,
    ArtifactPath
  );
  FPlan.AddLogicalObjectInput(ObjectArtifactPath);
  AppendBackendLogicalLibraryRequests;
  if not ResolveDirectLinkLibraries(
    RuntimeRootPath,
    SharedLibraryPath,
    HasResolvedLibrary
  ) then
    Exit;

  LlvmStep := FPlan.AddStep(
    'llvm-opt-bitcode',
    ExecutableSet.Opt,
    ExecutableSet.Opt,
    BackendCacheRoot,
    'toolchain.llvm-opt-exec-failed'
  );
  FPlan.SetStepContext(
    LlvmStep,
    'llvm-opt',
    ExecutableSet.Id,
    BuildSysrootRef
  );
  if FTargetFacts.LlvmOptLevel <> '' then
    FPlan.AddStepArg(LlvmStep, '-' + FTargetFacts.LlvmOptLevel);
  FPlan.AddStepArg(LlvmStep, '-o');
  FPlan.AddStepArg(LlvmStep, ExpandFileName(BitcodeArtifactPath));
  FPlan.AddStepArg(LlvmStep, ExpandFileName(IrArtifactPath));
  FPlan.AddStepInput(
    LlvmStep,
    'llvm-ir',
    ExpandFileName(IrArtifactPath)
  );
  FPlan.AddStepOutput(
    LlvmStep,
    'llvm-bitcode',
    ExpandFileName(BitcodeArtifactPath)
  );

  LlvmStep := FPlan.AddStep(
    'llvm-llc-object',
    ExecutableSet.Llc,
    ExecutableSet.Llc,
    BackendCacheRoot,
    'toolchain.llvm-llc-exec-failed'
  );
  FPlan.SetStepContext(
    LlvmStep,
    'llvm-codegen',
    ExecutableSet.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(LlvmStep, '-filetype=obj');
  if FTargetFacts.LlvmTriple <> '' then
    FPlan.AddStepArg(
      LlvmStep,
      '-mtriple=' + FTargetFacts.LlvmTriple
    );
  FPlan.AddStepArg(LlvmStep, '-o');
  FPlan.AddStepArg(LlvmStep, ExpandFileName(ObjectArtifactPath));
  FPlan.AddStepArg(LlvmStep, ExpandFileName(BitcodeArtifactPath));
  FPlan.AddStepInput(
    LlvmStep,
    'llvm-bitcode',
    ExpandFileName(BitcodeArtifactPath)
  );
  FPlan.AddStepOutput(
    LlvmStep,
    'object-file',
    ExpandFileName(ObjectArtifactPath)
  );

  { For object-file (unit) outputs, skip the link step: compilation stops at .o }
  if SameText(OutputKindValue, 'object-file') then
  begin
    FPlan.MarkReady;
    Exit;
  end;

  LinkStep := FPlan.AddStep(
    'llvm-link',
    FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld'),
    FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld'),
    ExtractFileDir(ExpandFileName(ArtifactPath)),
    'toolchain.linker-exec-failed'
  );
  FPlan.SetStepContext(
    LinkStep,
    'linker',
    LinkerProfile.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(LinkStep, '-o');
  FPlan.AddStepArg(LinkStep, ExpandFileName(ArtifactPath));
  FPlan.AddStepArg(LinkStep, ExpandFileName(ObjectArtifactPath));
  RuntimeLibPath := FindRuntimeLibrary(FTargetFacts.TargetId);
  if RuntimeLibPath <> '' then
    FPlan.AddStepArg(LinkStep, ExpandFileName(RuntimeLibPath));
  if HasResolvedLibrary then
  begin
    FPlan.AddStepArg(
      LinkStep,
      LinkerProfile.LibrarySearchFlag + ExpandFileName(RuntimeRootPath)
    );
    AppendDirectLinkLibraryArgs(LinkStep);
  end;
  FPlan.AddStepInput(
    LinkStep,
    'object-file',
    ExpandFileName(ObjectArtifactPath)
  );
  if HasResolvedLibrary then
  begin
    FPlan.AddStepInput(
      LinkStep,
      'runtime-library-root',
      ExpandFileName(RuntimeRootPath)
    );
    FPlan.AddStepInput(
      LinkStep,
      'shared-library',
      ExpandFileName(SharedLibraryPath)
    );
  end;
  PrimaryArtifactKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.PrimaryArtifactKind <> '') then
    PrimaryArtifactKindValue := FBackendPlan.PrimaryArtifactKind;
  FPlan.AddStepOutput(
    LinkStep,
    PrimaryArtifactKindValue,
    ExpandFileName(ArtifactPath)
  );
  FPlan.MarkReady;
end;
