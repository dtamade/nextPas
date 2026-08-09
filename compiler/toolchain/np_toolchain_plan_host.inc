procedure TToolchainPlanner.PlanBootstrapHostCompiler;
var
  ArtifactPath: string;
  HostCompiler: THostCompilerProfile;
  ObjectArtifactPath: string;
  OutputKindValue: string;
  PrimaryArtifactKindValue: string;
  OutputDirectory: string;
  ScratchRoot: string;
  StepIndex: LongInt;
begin
  try
    HostCompiler := LoadHostCompilerProfile(
      ToolProfileRootPath,
      FTargetFacts.HostCompilerProfileId
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

  ArtifactPath := PrimaryArtifactPathOrDefault;
  OutputDirectory := ExtractFileDir(ArtifactPath);
  ScratchRoot := HostCompilerScratchRootPath;
  PreparePlanContext(
    'bootstrap-host-compiler',
    'host-compiler',
    HostCompiler.Id
  );
  OutputKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.OutputKind <> '') then
    OutputKindValue := FBackendPlan.OutputKind;
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    FTargetFacts.LinkerProfileId,
    OutputKindValue,
    ArtifactPath
  );
  ObjectArtifactPath := '';
  if FBackendPlan <> nil then
    ObjectArtifactPath := FBackendPlan.ArtifactPathByKind('object-file');
  if ObjectArtifactPath <> '' then
    FPlan.AddLogicalObjectInput(ObjectArtifactPath);
  AppendBackendLogicalLibraryRequests;
  StepIndex := FPlan.AddStep(
    'host-fpc-compile',
    FirstStringOrDefault(HostCompiler.DriverCandidates, FTargetFacts.CompilerExecutable),
    FTargetFacts.CompilerExecutable,
    ScratchRoot,
    'toolchain.host-compiler-exec-failed'
  );
  if OutputDirectory <> '' then
    FPlan.AddStepArg(
      StepIndex,
      '-FE' + ExpandFileName(OutputDirectory)
    );
  FPlan.AddStepArg(
    StepIndex,
    '-FU' + ExpandFileName(ScratchRoot)
  );
  AppendUnitSearchRoots(StepIndex, HostCompiler.UnitsFlag);
  FPlan.AddStepArg(StepIndex, ExpandFileName(FSourcePath));
  FPlan.AddStepInput(
    StepIndex,
    'pascal-source',
    ExpandFileName(FSourcePath)
  );
  PrimaryArtifactKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.PrimaryArtifactKind <> '') then
    PrimaryArtifactKindValue := FBackendPlan.PrimaryArtifactKind;
  FPlan.AddStepOutput(
    StepIndex,
    PrimaryArtifactKindValue,
    ArtifactPath
  );
  FPlan.MarkReady;
end;

procedure TToolchainPlanner.PlanNativeAssembleLink(
  const AAssemblyPath: string;
  const AObjectPath: string;
  const AOutputPath: string
);
var
  AssemblerProfile: TAssemblerProfile;
  HasResolvedLibrary: Boolean;
  LinkerProfile: TLinkerProfile;
  AssembleStep: LongInt;
  LinkStep: LongInt;
  ResponseFilePath: string;
  RuntimeRootPath: string;
  SharedLibraryPath: string;
begin
  try
    AssemblerProfile := LoadAssemblerProfile(
      ToolProfileRootPath,
      FTargetFacts.AssemblerProfileId
    );
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

  PreparePlanContext('native-assemble-link', 'native-build', LinkerProfile.Id);
  FPlan.ConfigureLogicalLinkRequest(
    'ready',
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    LinkerProfile.Id,
    'executable',
    AOutputPath
  );
  FPlan.AddLogicalObjectInput(AObjectPath);
  AppendBackendLogicalLibraryRequests;
  if not ResolveDirectLinkLibraries(
    RuntimeRootPath,
    SharedLibraryPath,
    HasResolvedLibrary
  ) then
    Exit;

  AssembleStep := FPlan.AddStep(
    'native-assemble',
    FirstStringOrDefault(AssemblerProfile.DriverCandidates, 'as'),
    FirstStringOrDefault(AssemblerProfile.DriverCandidates, 'as'),
    ExtractFileDir(ExpandFileName(AAssemblyPath)),
    'toolchain.assembler-exec-failed'
  );
  FPlan.SetStepContext(
    AssembleStep,
    'assembler',
    AssemblerProfile.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(AssembleStep, '-o');
  FPlan.AddStepArg(AssembleStep, ExpandFileName(AObjectPath));
  FPlan.AddStepArg(AssembleStep, ExpandFileName(AAssemblyPath));
  FPlan.AddStepInput(AssembleStep, 'assembly-text', AAssemblyPath);
  FPlan.AddStepOutput(AssembleStep, 'object-file', AObjectPath);

  LinkStep := FPlan.AddStep(
    'native-link',
    FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld'),
    FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld'),
    ExtractFileDir(ExpandFileName(AOutputPath)),
    'toolchain.linker-exec-failed'
  );
  FPlan.SetStepContext(
    LinkStep,
    'linker',
    LinkerProfile.Id,
    BuildSysrootRef
  );
  ResponseFilePath := AOutputPath + '.rsp';
  FPlan.AddStepArg(LinkStep, '-o');
  FPlan.AddStepArg(LinkStep, ExpandFileName(AOutputPath));
  FPlan.AddStepArg(LinkStep, '@' + ResponseFilePath);
  if HasResolvedLibrary then
  begin
    FPlan.AddStepArg(
      LinkStep,
      LinkerProfile.LibrarySearchFlag + ExpandFileName(RuntimeRootPath)
    );
    AppendDirectLinkLibraryArgs(LinkStep);
  end;
  FPlan.AddStepInput(LinkStep, 'object-file', AObjectPath);
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
  FPlan.AddStepOutput(LinkStep, 'executable', AOutputPath);
  FPlan.AddStepSidecar(
    LinkStep,
    'response-file',
    ResponseFilePath,
    'native-link',
    'before-step-exec',
    'delete-on-success'
  );
  FPlan.MarkReady;
end;

procedure TToolchainPlanner.PlanResourceCompile(
  const AResourcePath: string;
  const ABinaryResourcePath: string;
  const AObjectPath: string
);
var
  ListScriptPath: string;
  RcStep: LongInt;
  ResourceProfile: TResourceToolProfile;
  ResStep: LongInt;
begin
  try
    ResourceProfile := LoadResourceToolProfile(
      ToolProfileRootPath,
      FTargetFacts.ResourceToolProfileId
    );
  except
    on E: EToolProfileError do
    begin
      FPlan.MarkFailure('toolchain.profile-metadata-missing', E.Message);
      Exit;
    end;
  end;

  if ResourceProfile.PipelineKind = 'disabled' then
  begin
    FPlan.MarkFailure(
      'toolchain.resource-profile-disabled',
      'resource pipeline is disabled'
    );
    Exit;
  end;

  if not PrepareLlvmContract then
    Exit;

  PreparePlanContext('resource-compile', 'resource-compiler', ResourceProfile.Id);
  RcStep := FPlan.AddStep(
    'rc-to-res',
    FirstStringOrDefault(ResourceProfile.RcDriverCandidates, 'windres'),
    FirstStringOrDefault(ResourceProfile.RcDriverCandidates, 'windres'),
    ExtractFileDir(ExpandFileName(AResourcePath)),
    'toolchain.resource-exec-failed'
  );
  FPlan.AddStepArg(RcStep, '-O');
  FPlan.AddStepArg(RcStep, 'res');
  FPlan.AddStepArg(RcStep, '-o');
  FPlan.AddStepArg(RcStep, ExpandFileName(ABinaryResourcePath));
  FPlan.AddStepArg(RcStep, ExpandFileName(AResourcePath));
  FPlan.AddStepInput(RcStep, 'resource-script', AResourcePath);
  FPlan.AddStepOutput(
    RcStep,
    ResourceProfile.IntermediateAssetKind,
    ABinaryResourcePath
  );

  ResStep := FPlan.AddStep(
    'res-to-obj',
    FirstStringOrDefault(ResourceProfile.ResDriverCandidates, 'fpcres'),
    FirstStringOrDefault(ResourceProfile.ResDriverCandidates, 'fpcres'),
    ExtractFileDir(ExpandFileName(AObjectPath)),
    'toolchain.resource-exec-failed'
  );
  ListScriptPath := AObjectPath + '.reslst';
  FPlan.AddStepArg(ResStep, '@' + ListScriptPath);
  FPlan.AddStepArg(ResStep, '-o');
  FPlan.AddStepArg(ResStep, ExpandFileName(AObjectPath));
  FPlan.AddStepArg(ResStep, ExpandFileName(ABinaryResourcePath));
  FPlan.AddStepInput(ResStep, ResourceProfile.IntermediateAssetKind, ABinaryResourcePath);
  FPlan.AddStepOutput(ResStep, 'resource-object', AObjectPath);
  FPlan.AddStepSidecar(
    ResStep,
    'resource-list-script',
    ListScriptPath,
    'res-to-obj',
    'before-step-exec',
    'delete-on-success'
  );
  FPlan.MarkReady;
end;

procedure TToolchainPlanner.PlanArchiveBuild(
  const AArchivePath: string;
  const AObjectPaths: array of string
);
var
  ArchiveScriptPath: string;
  ArchiverProfile: TArchiverProfile;
  CreateStep: LongInt;
  Index: SizeInt;
  IndexStep: LongInt;
begin
  try
    ArchiverProfile := LoadArchiverProfile(
      ToolProfileRootPath,
      FTargetFacts.ArchiverProfileId
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

  PreparePlanContext('archive-build', 'archiver', ArchiverProfile.Id);
  CreateStep := FPlan.AddStep(
    'archive-create',
    FirstStringOrDefault(ArchiverProfile.DriverCandidates, 'ar'),
    FirstStringOrDefault(ArchiverProfile.DriverCandidates, 'ar'),
    ExtractFileDir(ExpandFileName(AArchivePath)),
    'toolchain.archiver-exec-failed'
  );
  ArchiveScriptPath := AArchivePath + '.mri';
  FPlan.AddStepArg(CreateStep, '-M');
  FPlan.AddStepArg(CreateStep, '@' + ArchiveScriptPath);
  for Index := 0 to High(AObjectPaths) do
    FPlan.AddStepInput(CreateStep, 'object-file', AObjectPaths[Index]);
  FPlan.AddStepOutput(CreateStep, 'static-library', AArchivePath);
  FPlan.AddStepSidecar(
    CreateStep,
    'archive-command-script',
    ArchiveScriptPath,
    'archive-create',
    'before-step-exec',
    'delete-on-success'
  );

  IndexStep := FPlan.AddStep(
    'archive-index',
    FirstStringOrDefault(ArchiverProfile.DriverCandidates, 'ar'),
    FirstStringOrDefault(ArchiverProfile.DriverCandidates, 'ar'),
    ExtractFileDir(ExpandFileName(AArchivePath)),
    'toolchain.archiver-exec-failed'
  );
  FPlan.AddStepArg(IndexStep, 's');
  FPlan.AddStepArg(IndexStep, ExpandFileName(AArchivePath));
  FPlan.AddStepInput(IndexStep, 'static-library', AArchivePath);
  FPlan.AddStepOutput(IndexStep, 'static-library', AArchivePath);
  FPlan.MarkReady;
end;
