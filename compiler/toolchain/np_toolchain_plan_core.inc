function BuildStringArrayJson(const AValues: array of string): string;
var
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + JsonString(AValues[Index]);
  end;
  Result := '[' + Result + ']';
end;

function BuildToolArtifactArrayJson(const AValues: array of TToolArtifactRef): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildToolSidecarArrayJson(const AValues: array of TToolSidecarRef): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    AppendJsonField(EntryFields, 'ownerStepId', JsonString(AValues[Index].OwnerStepId));
    AppendJsonField(
      EntryFields,
      'materializationTiming',
      JsonString(AValues[Index].MaterializationTiming)
    );
    AppendJsonField(EntryFields, 'cleanupPolicy', JsonString(AValues[Index].CleanupPolicy));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildLogicalLibraryRequestJson(
  const AValues: array of TLogicalLibraryRequest
): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'logicalId', JsonString(AValues[Index].LogicalId));
    AppendJsonField(EntryFields, 'linkageKind', JsonString(AValues[Index].LinkageKind));
    AppendJsonField(EntryFields, 'strength', JsonString(AValues[Index].Strength));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

constructor TToolchainPlan.Create;
begin
  inherited Create;
  FStatus := 'deferred';
  FFailureCode := '';
  FFailureMessage := '';
  FPlanFamily := '';
  FToolProfileRoot := '';
  FToolRole := '';
  FProfileId := '';
  FBindingId := '';
  FHostId := '';
  FTargetId := '';
  FSysrootRef := '';
  SetLength(FSteps, 0);
  FLogicalLinkRequest.RequestKind := 'logical-link-request';
  FLogicalLinkRequest.Status := 'deferred';
  SetLength(FLogicalLinkRequest.ObjectInputs, 0);
  SetLength(FLogicalLinkRequest.LibraryRequests, 0);
  SetLength(FLogicalLinkRequest.OrderedSymbols, 0);
  FLlvmExecutableContract.ContractKind := 'llvm-executable-set';
  FLlvmExecutableContract.Status := 'deferred';
  FLlvmExecutableContract.Enabled := False;
end;

procedure TToolchainPlan.SetPlanFamily(const AValue: string);
begin
  FPlanFamily := AValue;
end;

procedure TToolchainPlan.SetToolProfileRoot(const AValue: string);
begin
  FToolProfileRoot := AValue;
end;

procedure TToolchainPlan.SetContext(
  const AToolRole: string;
  const AProfileId: string;
  const ABindingId: string;
  const AHostId: string;
  const ATargetId: string;
  const ASysrootRef: string
);
begin
  FToolRole := AToolRole;
  FProfileId := AProfileId;
  FBindingId := ABindingId;
  FHostId := AHostId;
  FTargetId := ATargetId;
  FSysrootRef := ASysrootRef;
end;

function TToolchainPlan.AddStep(
  const AStepId: string;
  const ALogicalExecutable: string;
  const AExecutableRef: string;
  const AWorkingDirectory: string;
  const AFailureMapping: string
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FSteps);
  SetLength(FSteps, NextIndex + 1);
  FSteps[NextIndex].StepId := AStepId;
  FSteps[NextIndex].ToolRole := FToolRole;
  FSteps[NextIndex].ProfileId := FProfileId;
  FSteps[NextIndex].SysrootRef := FSysrootRef;
  FSteps[NextIndex].LogicalExecutable := ALogicalExecutable;
  FSteps[NextIndex].ExecutableRef := AExecutableRef;
  FSteps[NextIndex].WorkingDirectory := AWorkingDirectory;
  FSteps[NextIndex].FailureMapping := AFailureMapping;
  SetLength(FSteps[NextIndex].Argv, 0);
  SetLength(FSteps[NextIndex].EnvDelta, 0);
  SetLength(FSteps[NextIndex].Inputs, 0);
  SetLength(FSteps[NextIndex].Outputs, 0);
  SetLength(FSteps[NextIndex].Sidecars, 0);
  Result := NextIndex;
end;

procedure TToolchainPlan.SetStepContext(
  const AStepIndex: LongInt;
  const AToolRole: string;
  const AProfileId: string;
  const ASysrootRef: string
);
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;

  FSteps[AStepIndex].ToolRole := AToolRole;
  FSteps[AStepIndex].ProfileId := AProfileId;
  FSteps[AStepIndex].SysrootRef := ASysrootRef;
end;

procedure TToolchainPlan.AddStepArg(const AStepIndex: LongInt; const AValue: string);
var
  NextIndex: SizeInt;
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;
  NextIndex := Length(FSteps[AStepIndex].Argv);
  SetLength(FSteps[AStepIndex].Argv, NextIndex + 1);
  FSteps[AStepIndex].Argv[NextIndex] := AValue;
end;

procedure TToolchainPlan.AddStepInput(
  const AStepIndex: LongInt;
  const AKind: string;
  const APath: string
);
var
  NextIndex: SizeInt;
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;
  NextIndex := Length(FSteps[AStepIndex].Inputs);
  SetLength(FSteps[AStepIndex].Inputs, NextIndex + 1);
  FSteps[AStepIndex].Inputs[NextIndex].Kind := AKind;
  FSteps[AStepIndex].Inputs[NextIndex].Path := APath;
end;

procedure TToolchainPlan.AddStepOutput(
  const AStepIndex: LongInt;
  const AKind: string;
  const APath: string
);
var
  NextIndex: SizeInt;
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;
  NextIndex := Length(FSteps[AStepIndex].Outputs);
  SetLength(FSteps[AStepIndex].Outputs, NextIndex + 1);
  FSteps[AStepIndex].Outputs[NextIndex].Kind := AKind;
  FSteps[AStepIndex].Outputs[NextIndex].Path := APath;
end;

procedure TToolchainPlan.AddStepSidecar(
  const AStepIndex: LongInt;
  const AKind: string;
  const APath: string;
  const AOwnerStepId: string;
  const AMaterializationTiming: string;
  const ACleanupPolicy: string
);
var
  NextIndex: SizeInt;
begin
  if (AStepIndex < 0) or (AStepIndex > High(FSteps)) then
    Exit;
  NextIndex := Length(FSteps[AStepIndex].Sidecars);
  SetLength(FSteps[AStepIndex].Sidecars, NextIndex + 1);
  FSteps[AStepIndex].Sidecars[NextIndex].Kind := AKind;
  FSteps[AStepIndex].Sidecars[NextIndex].Path := APath;
  FSteps[AStepIndex].Sidecars[NextIndex].OwnerStepId := AOwnerStepId;
  FSteps[AStepIndex].Sidecars[NextIndex].MaterializationTiming := AMaterializationTiming;
  FSteps[AStepIndex].Sidecars[NextIndex].CleanupPolicy := ACleanupPolicy;
end;

procedure TToolchainPlan.ConfigureLogicalLinkRequest(
  const AStatus: string;
  const ABindingId: string;
  const ATargetId: string;
  const ALinkerProfileId: string;
  const AOutputKind: string;
  const APrimaryArtifactPath: string
);
begin
  FLogicalLinkRequest.RequestKind := 'logical-link-request';
  FLogicalLinkRequest.Status := AStatus;
  FLogicalLinkRequest.BindingId := ABindingId;
  FLogicalLinkRequest.TargetId := ATargetId;
  FLogicalLinkRequest.LinkerProfileId := ALinkerProfileId;
  FLogicalLinkRequest.OutputKind := AOutputKind;
  FLogicalLinkRequest.PrimaryArtifactPath := APrimaryArtifactPath;
  SetLength(FLogicalLinkRequest.ObjectInputs, 0);
  SetLength(FLogicalLinkRequest.LibraryRequests, 0);
  SetLength(FLogicalLinkRequest.OrderedSymbols, 0);
end;

procedure TToolchainPlan.AddLogicalObjectInput(const APath: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FLogicalLinkRequest.ObjectInputs);
  SetLength(FLogicalLinkRequest.ObjectInputs, NextIndex + 1);
  FLogicalLinkRequest.ObjectInputs[NextIndex].Kind := 'object-file';
  FLogicalLinkRequest.ObjectInputs[NextIndex].Path := APath;
end;

procedure TToolchainPlan.AddLogicalLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FLogicalLinkRequest.LibraryRequests);
  SetLength(FLogicalLinkRequest.LibraryRequests, NextIndex + 1);
  FLogicalLinkRequest.LibraryRequests[NextIndex].LogicalId := ALogicalId;
  FLogicalLinkRequest.LibraryRequests[NextIndex].LinkageKind := ALinkageKind;
  FLogicalLinkRequest.LibraryRequests[NextIndex].Strength := AStrength;
end;

procedure TToolchainPlan.SetLlvmExecutableContract(
  const AStatus: string;
  const AEnabled: Boolean;
  const AExecutableSet: TLlvmExecutableSet
);
begin
  FLlvmExecutableContract.ContractKind := 'llvm-executable-set';
  FLlvmExecutableContract.Status := AStatus;
  FLlvmExecutableContract.Enabled := AEnabled;
  FLlvmExecutableContract.ExecutableSetId := AExecutableSet.Id;
  FLlvmExecutableContract.ToolRootKind := AExecutableSet.ToolRootKind;
  FLlvmExecutableContract.ClangDriver := AExecutableSet.ClangDriver;
  FLlvmExecutableContract.Llc := AExecutableSet.Llc;
  FLlvmExecutableContract.Opt := AExecutableSet.Opt;
  FLlvmExecutableContract.Lld := AExecutableSet.Lld;
  FLlvmExecutableContract.LlvmAr := AExecutableSet.LlvmAr;
  FLlvmExecutableContract.SuffixPolicy := AExecutableSet.SuffixPolicy;
  FLlvmExecutableContract.VersionContract := AExecutableSet.VersionContract;
end;

procedure TToolchainPlan.MarkReady;
begin
  if FStatus = 'failure' then
    Exit;
  FStatus := 'ready';
end;

procedure TToolchainPlan.MarkFailure(const ACode: string; const AMessage: string);
begin
  FStatus := 'failure';
  FFailureCode := ACode;
  FFailureMessage := AMessage;
end;

function TToolchainPlan.Status: string;
begin
  Result := FStatus;
end;

function TToolchainPlan.FailureCode: string;
begin
  Result := FFailureCode;
end;

function TToolchainPlan.FailureMessage: string;
begin
  Result := FFailureMessage;
end;

function TToolchainPlan.PlanFamily: string;
begin
  Result := FPlanFamily;
end;

function TToolchainPlan.ToolProfileRoot: string;
begin
  Result := FToolProfileRoot;
end;

function TToolchainPlan.ToolInvocationCount: LongInt;
begin
  Result := Length(FSteps);
end;

function TToolchainPlan.StepAt(const AIndex: LongInt): TToolInvocationStep;
begin
  if (AIndex < 0) or (AIndex > High(FSteps)) then
  begin
    Result.StepId := '';
    Result.LogicalExecutable := '';
    Result.ExecutableRef := '';
    Result.WorkingDirectory := '';
    Result.FailureMapping := '';
    SetLength(Result.Argv, 0);
    SetLength(Result.EnvDelta, 0);
    SetLength(Result.Inputs, 0);
    SetLength(Result.Outputs, 0);
    SetLength(Result.Sidecars, 0);
    Exit;
  end;

  Result := FSteps[AIndex];
end;

function TToolchainPlan.PrimaryToolRole: string;
begin
  Result := FToolRole;
end;

function TToolchainPlan.PrimaryToolProfileId: string;
begin
  Result := FProfileId;
end;

function TToolchainPlan.PrimaryToolStepId: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].StepId;
end;

function TToolchainPlan.PrimaryToolLogicalExecutable: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].LogicalExecutable;
end;

function TToolchainPlan.PrimaryToolExecutableRef: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].ExecutableRef;
end;

function TToolchainPlan.PrimaryToolSysrootRef: string;
begin
  Result := FSysrootRef;
end;

function TToolchainPlan.PrimaryToolFailureMapping: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].FailureMapping;
end;

function TToolchainPlan.PrimaryToolArgCount: LongInt;
begin
  if Length(FSteps) = 0 then
    Exit(0);
  Result := Length(FSteps[0].Argv);
end;

function TToolchainPlan.PrimaryToolArgValue(const AIndex: LongInt): string;
begin
  if (Length(FSteps) = 0) or (AIndex < 0) or (AIndex > High(FSteps[0].Argv)) then
    Exit('');
  Result := FSteps[0].Argv[AIndex];
end;

function TToolchainPlan.PrimaryToolWorkingDirectory: string;
begin
  if Length(FSteps) = 0 then
    Exit('');
  Result := FSteps[0].WorkingDirectory;
end;

function TToolchainPlan.LogicalLinkRequestStatus: string;
begin
  Result := FLogicalLinkRequest.Status;
end;

function TToolchainPlan.LogicalLinkRequestOutputKind: string;
begin
  Result := FLogicalLinkRequest.OutputKind;
end;

function TToolchainPlan.LogicalLibraryRequestCount: LongInt;
begin
  Result := Length(FLogicalLinkRequest.LibraryRequests);
end;

function TToolchainPlan.LlvmToolchainStatus: string;
begin
  Result := FLlvmExecutableContract.Status;
end;

function TToolchainPlan.LlvmExecutableSetId: string;
begin
  Result := FLlvmExecutableContract.ExecutableSetId;
end;
