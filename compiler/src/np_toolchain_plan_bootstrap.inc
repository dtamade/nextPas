procedure TToolchainPlanner.PlanBootstrapNativeAssembleLink;
var
  AdditionalAssemblyPath: string;
  AdditionalAssembleStep: LongInt;
  AdditionalBaseName: string;
  AdditionalObjectPath: string;
  ArtifactPath: string;
  AssemblerExecutable: string;
  AssemblerProfile: TAssemblerProfile;
  AssemblyArtifactPath: string;
  BackendCacheRoot: string;
  EmitAsmStep: LongInt;
  HostCompiler: THostCompilerProfile;
  Index: LongInt;
  LinkerExecutable: string;
  LinkerProfile: TLinkerProfile;
  LinkerScriptPath: string;
  LinkRequestStatus: string;
  ObjectArtifactPath: string;
  OutputKindValue: string;
  PrimaryArtifactKindValue: string;
  RequiresLink: Boolean;
  PlanFamilyId: string;
  StepIndex: LongInt;
begin
  try
    HostCompiler := LoadHostCompilerProfile(
      ToolProfileRootPath,
      FTargetFacts.HostCompilerProfileId
    );
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

  ArtifactPath := PrimaryArtifactPathOrDefault;
  AssemblyArtifactPath := FBackendPlan.ArtifactPathByKind('assembly-text');
  ObjectArtifactPath := FBackendPlan.ArtifactPathByKind('object-file');
  if (AssemblyArtifactPath = '') or (ObjectArtifactPath = '') then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-artifact-missing',
      'backend plan is missing assembly/object artifacts'
    );
    Exit;
  end;

  BackendCacheRoot := ExtractFileDir(ExpandFileName(AssemblyArtifactPath));
  if BackendCacheRoot = '' then
  begin
    FPlan.MarkFailure(
      'toolchain.backend-artifact-missing',
      'backend assembly artifact has no parent directory'
    );
    Exit;
  end;

  LinkerScriptPath := IncludeTrailingPathDelimiter(BackendCacheRoot) +
    ChangeFileExt(ExtractFileName(AssemblyArtifactPath), '') + '_link.res';
  OutputKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.OutputKind <> '') then
    OutputKindValue := FBackendPlan.OutputKind;
  RequiresLink := nextpas.core.text.SameText(OutputKindValue, 'executable');
  if RequiresLink then
  begin
    PlanFamilyId := 'bootstrap-native-assemble-link';
    LinkRequestStatus := 'ready';
  end
  else
  begin
    PlanFamilyId := 'bootstrap-native-assemble';
    LinkRequestStatus := 'deferred';
  end;
  PreparePlanContext(
    PlanFamilyId,
    'host-compiler',
    HostCompiler.Id
  );
  FPlan.ConfigureLogicalLinkRequest(
    LinkRequestStatus,
    FTargetFacts.ToolchainBindingId,
    FTargetFacts.TargetId,
    LinkerProfile.Id,
    OutputKindValue,
    ArtifactPath
  );
  if RequiresLink then
  begin
    FPlan.AddLogicalObjectInput(ObjectArtifactPath);
    AppendBackendLogicalLibraryRequests;
  end;

  EmitAsmStep := FPlan.AddStep(
    'host-fpc-emit-asm',
    FirstStringOrDefault(HostCompiler.DriverCandidates, FTargetFacts.CompilerExecutable),
    FTargetFacts.CompilerExecutable,
    BackendCacheRoot,
    'toolchain.host-compiler-exec-failed'
  );
  FPlan.AddStepArg(EmitAsmStep, '-st');
  FPlan.AddStepArg(EmitAsmStep, '-Aas');
  FPlan.AddStepArg(
    EmitAsmStep,
    '-FE' + ExpandFileName(BackendCacheRoot)
  );
  FPlan.AddStepArg(
    EmitAsmStep,
    '-FU' + ExpandFileName(BackendCacheRoot)
  );
  AppendUnitSearchRoots(EmitAsmStep, HostCompiler.UnitsFlag);
  FPlan.AddStepArg(EmitAsmStep, ExpandFileName(FSourcePath));
  FPlan.AddStepInput(
    EmitAsmStep,
    'pascal-source',
    ExpandFileName(FSourcePath)
  );
  FPlan.AddStepOutput(
    EmitAsmStep,
    'assembly-text',
    ExpandFileName(AssemblyArtifactPath)
  );
  FPlan.AddStepOutput(
    EmitAsmStep,
    'linker-script',
    ExpandFileName(LinkerScriptPath)
  );
  if FAdditionalAssemblyBaseNames <> nil then
    for Index := 0 to LongInt(FAdditionalAssemblyBaseNames.Count) - 1 do
    begin
      AdditionalBaseName := FAdditionalAssemblyBaseNames[SizeUInt(Index)];
      if Trim(AdditionalBaseName) = '' then
        Continue;
      if nextpas.core.text.SameText(AdditionalBaseName, ChangeFileExt(ExtractFileName(FSourcePath), '')) then
        Continue;
      AdditionalAssemblyPath := IncludeTrailingPathDelimiter(BackendCacheRoot) +
        AdditionalBaseName + '.s';
      FPlan.AddStepOutput(
        EmitAsmStep,
        'assembly-text',
        ExpandFileName(AdditionalAssemblyPath)
      );
    end;

  AssemblerExecutable := FirstStringOrDefault(AssemblerProfile.DriverCandidates, 'as');
  StepIndex := FPlan.AddStep(
    'native-assemble',
    AssemblerExecutable,
    AssemblerExecutable,
    BackendCacheRoot,
    'toolchain.assembler-exec-failed'
  );
  FPlan.SetStepContext(
    StepIndex,
    'assembler',
    AssemblerProfile.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(StepIndex, '--64');
  FPlan.AddStepArg(StepIndex, '-o');
  FPlan.AddStepArg(StepIndex, ExpandFileName(ObjectArtifactPath));
  FPlan.AddStepArg(StepIndex, ExpandFileName(AssemblyArtifactPath));
  FPlan.AddStepInput(
    StepIndex,
    'assembly-text',
    ExpandFileName(AssemblyArtifactPath)
  );
  FPlan.AddStepOutput(
    StepIndex,
    'object-file',
    ExpandFileName(ObjectArtifactPath)
  );
  if FAdditionalAssemblyBaseNames <> nil then
    for Index := 0 to LongInt(FAdditionalAssemblyBaseNames.Count) - 1 do
    begin
      AdditionalBaseName := FAdditionalAssemblyBaseNames[SizeUInt(Index)];
      if Trim(AdditionalBaseName) = '' then
        Continue;
      if nextpas.core.text.SameText(AdditionalBaseName, ChangeFileExt(ExtractFileName(FSourcePath), '')) then
        Continue;
      AdditionalAssemblyPath := IncludeTrailingPathDelimiter(BackendCacheRoot) +
        AdditionalBaseName + '.s';
      AdditionalObjectPath := IncludeTrailingPathDelimiter(BackendCacheRoot) +
        AdditionalBaseName + '.o';
      AdditionalAssembleStep := FPlan.AddStep(
        'native-assemble-' + LowerCase(AdditionalBaseName),
        AssemblerExecutable,
        AssemblerExecutable,
        BackendCacheRoot,
        'toolchain.assembler-exec-failed'
      );
      FPlan.SetStepContext(
        AdditionalAssembleStep,
        'assembler',
        AssemblerProfile.Id,
        BuildSysrootRef
      );
      FPlan.AddStepArg(AdditionalAssembleStep, '--64');
      FPlan.AddStepArg(AdditionalAssembleStep, '-o');
      FPlan.AddStepArg(
        AdditionalAssembleStep,
        ExpandFileName(AdditionalObjectPath)
      );
      FPlan.AddStepArg(
        AdditionalAssembleStep,
        ExpandFileName(AdditionalAssemblyPath)
      );
      FPlan.AddStepInput(
        AdditionalAssembleStep,
        'assembly-text',
        ExpandFileName(AdditionalAssemblyPath)
      );
      FPlan.AddStepOutput(
        AdditionalAssembleStep,
        'object-file',
        ExpandFileName(AdditionalObjectPath)
      );
      // Add dependent unit .o to linker inputs so multi-unit programs link correctly
      FPlan.AddLogicalObjectInput(ExpandFileName(AdditionalObjectPath));
    end;

  if not RequiresLink then
  begin
    FPlan.MarkReady;
    Exit;
  end;

  LinkerExecutable := FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld');
  if nextpas.core.text.SameText(LinkerProfile.ToolFlavor, 'gnu-ld') then
    LinkerExecutable := 'ld.bfd';
  StepIndex := FPlan.AddStep(
    'native-link',
    LinkerExecutable,
    LinkerExecutable,
    BackendCacheRoot,
    'toolchain.linker-exec-failed'
  );
  FPlan.SetStepContext(
    StepIndex,
    'linker',
    LinkerProfile.Id,
    BuildSysrootRef
  );
  FPlan.AddStepArg(StepIndex, '-b');
  FPlan.AddStepArg(StepIndex, 'elf64-x86-64');
  FPlan.AddStepArg(StepIndex, '-m');
  FPlan.AddStepArg(StepIndex, 'elf_x86_64');
  FPlan.AddStepArg(StepIndex, '-s');
  FPlan.AddStepArg(StepIndex, '-L.');
  FPlan.AddStepArg(StepIndex, '-lc');
  { Override FPC's default interpreter path (/lib/ld64.so.1) with the
    system's actual dynamic linker. FPC hardcodes /lib/ld64.so.1 for
    Linux x86_64, but many modern systems use /lib64/ld-linux-x86-64.so.2.
    Same default-interpreter hazard applies to direct `ld` links from the
    llvm binding (homebrew ld defaults to /lib/ld64.so.1 too) — shared
    helper keeps both link steps consistent. }
  AppendDynamicLinkerOverrideArg(StepIndex);
  FPlan.AddStepArg(StepIndex, '-o');
  FPlan.AddStepArg(StepIndex, ExpandFileName(ArtifactPath));
  FPlan.AddStepArg(StepIndex, '-T');
  FPlan.AddStepArg(StepIndex, ExpandFileName(LinkerScriptPath));
  FPlan.AddStepArg(StepIndex, '-e');
  FPlan.AddStepArg(StepIndex, '_start');
  FPlan.AddStepInput(
    StepIndex,
    'object-file',
    ExpandFileName(ObjectArtifactPath)
  );
  FPlan.AddStepInput(
    StepIndex,
    'linker-script',
    ExpandFileName(LinkerScriptPath)
  );
  PrimaryArtifactKindValue := 'executable';
  if (FBackendPlan <> nil) and (FBackendPlan.PrimaryArtifactKind <> '') then
    PrimaryArtifactKindValue := FBackendPlan.PrimaryArtifactKind;
  FPlan.AddStepOutput(
    StepIndex,
    PrimaryArtifactKindValue,
    ExpandFileName(ArtifactPath)
  );
  FPlan.MarkReady;
end;
