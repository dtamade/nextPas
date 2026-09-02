function TToolchainPlan.ToolInvocationPlanJson(
  const APlanId: string;
  const AResolvedPath: string
): string;
var
  StepFields: string;
  PlanFields: string;
  StepJson: string;
  StepResolvedPath: string;
  StepIndex: SizeInt;
begin
  if (FSteps = nil) or (FSteps.Count = 0) then
    Exit('');

  StepJson := '';
  for StepIndex := 0 to SizeInt(FSteps.Count) - 1 do
  begin
    if StepJson <> '' then
      StepJson := StepJson + ',';

    StepFields := '';
    AppendJsonField(StepFields, 'stepId', JsonString(FSteps[StepIndex].StepId));
    AppendJsonField(
      StepFields,
      'logicalExecutable',
      JsonString(FSteps[StepIndex].LogicalExecutable)
    );
    if (StepIndex = 0) and (AResolvedPath <> '') then
      StepResolvedPath := AResolvedPath
    else
      StepResolvedPath := FSteps[StepIndex].ExecutableRef;
    if StepResolvedPath <> '' then
      AppendJsonField(StepFields, 'resolvedPath', JsonString(StepResolvedPath));
    AppendJsonField(StepFields, 'argv', BuildStringVecJson(FSteps[StepIndex].Argv));
    AppendJsonField(
      StepFields,
      'workingDirectory',
      JsonString(FSteps[StepIndex].WorkingDirectory)
    );
    AppendJsonField(
      StepFields,
      'inputs',
      BuildToolArtifactVecJson(FSteps[StepIndex].Inputs)
    );
    AppendJsonField(
      StepFields,
      'outputs',
      BuildToolArtifactVecJson(FSteps[StepIndex].Outputs)
    );
    AppendJsonField(
      StepFields,
      'sidecars',
      BuildToolSidecarVecJson(FSteps[StepIndex].Sidecars)
    );
    AppendJsonField(
      StepFields,
      'failureMapping',
      JsonString(FSteps[StepIndex].FailureMapping)
    );
    StepJson := StepJson + '{' + StepFields + '}';
  end;

  PlanFields := '';
  AppendJsonField(PlanFields, 'planKind', JsonString('tool-invocation'));
  if APlanId <> '' then
    AppendJsonField(PlanFields, 'planId', JsonString(APlanId));
  AppendJsonField(PlanFields, 'planFamily', JsonString(FPlanFamily));
  AppendJsonField(PlanFields, 'toolRole', JsonString(FToolRole));
  AppendJsonField(PlanFields, 'bindingId', JsonString(FBindingId));
  AppendJsonField(PlanFields, 'profileId', JsonString(FProfileId));
  AppendJsonField(PlanFields, 'hostId', JsonString(FHostId));
  AppendJsonField(PlanFields, 'targetId', JsonString(FTargetId));
  AppendJsonField(PlanFields, 'sysrootRef', JsonString(FSysrootRef));
  AppendJsonField(PlanFields, 'steps', '[' + StepJson + ']');
  Result := '{' + PlanFields + '}';
end;

function TToolchainPlan.LogicalLinkRequestJson: string;
var
  Fields: string;
begin
  Fields := '';
  AppendJsonField(Fields, 'requestKind', JsonString(FLogicalLinkRequest.RequestKind));
  AppendJsonField(Fields, 'status', JsonString(FLogicalLinkRequest.Status));
  AppendJsonField(Fields, 'bindingId', JsonString(FLogicalLinkRequest.BindingId));
  AppendJsonField(Fields, 'targetId', JsonString(FLogicalLinkRequest.TargetId));
  AppendJsonField(
    Fields,
    'linkerProfileId',
    JsonString(FLogicalLinkRequest.LinkerProfileId)
  );
  AppendJsonField(Fields, 'outputKind', JsonString(FLogicalLinkRequest.OutputKind));
  AppendJsonField(
    Fields,
    'primaryArtifactPath',
    JsonString(FLogicalLinkRequest.PrimaryArtifactPath)
  );
  AppendJsonField(
    Fields,
    'objectInputs',
    BuildToolArtifactVecJson(FLogicalLinkRequest.ObjectInputs)
  );
  AppendJsonField(
    Fields,
    'libraryRequests',
    BuildLogicalLibraryRequestVecJson(FLogicalLinkRequest.LibraryRequests)
  );
  AppendJsonField(
    Fields,
    'orderedSymbols',
    BuildStringVecJson(FLogicalLinkRequest.OrderedSymbols)
  );
  Result := '{' + Fields + '}';
end;

function TToolchainPlan.LlvmExecutableSetJson: string;
var
  Fields: string;
begin
  Fields := '';
  AppendJsonField(Fields, 'contractKind', JsonString(FLlvmExecutableContract.ContractKind));
  AppendJsonField(Fields, 'status', JsonString(FLlvmExecutableContract.Status));
  if FLlvmExecutableContract.Enabled then
    AppendJsonField(Fields, 'enabled', 'true')
  else
    AppendJsonField(Fields, 'enabled', 'false');
  AppendJsonField(
    Fields,
    'executableSetId',
    JsonString(FLlvmExecutableContract.ExecutableSetId)
  );
  AppendJsonField(
    Fields,
    'toolRootKind',
    JsonString(FLlvmExecutableContract.ToolRootKind)
  );
  AppendJsonField(
    Fields,
    'clangDriver',
    JsonString(FLlvmExecutableContract.ClangDriver)
  );
  AppendJsonField(Fields, 'llc', JsonString(FLlvmExecutableContract.Llc));
  AppendJsonField(Fields, 'opt', JsonString(FLlvmExecutableContract.Opt));
  AppendJsonField(Fields, 'lld', JsonString(FLlvmExecutableContract.Lld));
  AppendJsonField(Fields, 'llvmAr', JsonString(FLlvmExecutableContract.LlvmAr));
  AppendJsonField(
    Fields,
    'suffixPolicy',
    JsonString(FLlvmExecutableContract.SuffixPolicy)
  );
  AppendJsonField(
    Fields,
    'versionContract',
    JsonString(FLlvmExecutableContract.VersionContract)
  );
  Result := '{' + Fields + '}';
end;
