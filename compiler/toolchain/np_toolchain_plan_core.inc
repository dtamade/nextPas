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

function BuildStringVecJson(const AValues: TToolchainStringVec): string;
var
  Index: SizeInt;
begin
  Result := '';
  if AValues <> nil then
    for Index := 0 to SizeInt(AValues.Count) - 1 do
    begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + JsonString(AValues[SizeUInt(Index)]);
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

function BuildToolArtifactVecJson(const AValues: TToolArtifactRefVec): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  if AValues <> nil then
    for Index := 0 to SizeInt(AValues.Count) - 1 do
    begin
      if Result <> '' then
        Result := Result + ',';
      EntryFields := '';
      AppendJsonField(EntryFields, 'kind', JsonString(AValues[SizeUInt(Index)].Kind));
      AppendJsonField(EntryFields, 'path', JsonString(AValues[SizeUInt(Index)].Path));
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

function BuildToolSidecarVecJson(const AValues: TToolSidecarRefVec): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  if AValues <> nil then
    for Index := 0 to SizeInt(AValues.Count) - 1 do
    begin
      if Result <> '' then
        Result := Result + ',';
      EntryFields := '';
      AppendJsonField(EntryFields, 'kind', JsonString(AValues[SizeUInt(Index)].Kind));
      AppendJsonField(EntryFields, 'path', JsonString(AValues[SizeUInt(Index)].Path));
      AppendJsonField(EntryFields, 'ownerStepId', JsonString(AValues[SizeUInt(Index)].OwnerStepId));
      AppendJsonField(
        EntryFields,
        'materializationTiming',
        JsonString(AValues[SizeUInt(Index)].MaterializationTiming)
      );
      AppendJsonField(EntryFields, 'cleanupPolicy', JsonString(AValues[SizeUInt(Index)].CleanupPolicy));
      Result := Result + '{' + EntryFields + '}';
    end;
  Result := '[' + Result + ']';
end;

procedure FreeToolInvocationStepNested(var AStep: TToolInvocationStep);
begin
  AStep.Argv.Free;
  AStep.Argv := nil;
  AStep.EnvDelta.Free;
  AStep.EnvDelta := nil;
  AStep.Inputs.Free;
  AStep.Inputs := nil;
  AStep.Outputs.Free;
  AStep.Outputs := nil;
  AStep.Sidecars.Free;
  AStep.Sidecars := nil;
end;

procedure InitToolInvocationStepNested(var AStep: TToolInvocationStep);
begin
  AStep.Argv := TToolchainStringVec.Create;
  AStep.EnvDelta := TToolEnvDeltaVec.Create;
  AStep.Inputs := TToolArtifactRefVec.Create;
  AStep.Outputs := TToolArtifactRefVec.Create;
  AStep.Sidecars := TToolSidecarRefVec.Create;
end;

procedure ClearToolInvocationStepView(out AStep: TToolInvocationStep);
begin
  AStep := Default(TToolInvocationStep);
end;

function ToolchainArgvAsArray(const AArgv: TToolchainStringVec): TStringArray;
var
  Index: SizeInt;
begin
  if (AArgv = nil) or (AArgv.Count = 0) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, AArgv.Count);
  for Index := 0 to SizeInt(AArgv.Count) - 1 do
    Result[Index] := AArgv[SizeUInt(Index)];
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

function BuildLogicalLibraryRequestVecJson(
  const AValues: TLogicalLibraryRequestVec
): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  if AValues <> nil then
    for Index := 0 to SizeInt(AValues.Count) - 1 do
    begin
      if Result <> '' then
        Result := Result + ',';
      EntryFields := '';
      AppendJsonField(EntryFields, 'logicalId', JsonString(AValues[SizeUInt(Index)].LogicalId));
      AppendJsonField(EntryFields, 'linkageKind', JsonString(AValues[SizeUInt(Index)].LinkageKind));
      AppendJsonField(EntryFields, 'strength', JsonString(AValues[SizeUInt(Index)].Strength));
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
  FSteps := TToolInvocationStepVec.Create;
  FLogicalLinkRequest.RequestKind := 'logical-link-request';
  FLogicalLinkRequest.Status := 'deferred';
  FLogicalLinkRequest.ObjectInputs := TToolArtifactRefVec.Create;
  FLogicalLinkRequest.LibraryRequests := TLogicalLibraryRequestVec.Create;
  FLogicalLinkRequest.OrderedSymbols := TToolchainStringVec.Create;
  FLlvmExecutableContract.ContractKind := 'llvm-executable-set';
  FLlvmExecutableContract.Status := 'deferred';
  FLlvmExecutableContract.Enabled := False;
end;

destructor TToolchainPlan.Destroy;
var
  Index: LongInt;
  Step: PToolInvocationStep;
begin
  if FSteps <> nil then
    for Index := 0 to LongInt(FSteps.Count) - 1 do
    begin
      Step := FSteps.GetPtr(SizeUInt(Index));
      FreeToolInvocationStepNested(Step^);
    end;
  FSteps.Free;
  FSteps := nil;
  FLogicalLinkRequest.ObjectInputs.Free;
  FLogicalLinkRequest.ObjectInputs := nil;
  FLogicalLinkRequest.LibraryRequests.Free;
  FLogicalLinkRequest.LibraryRequests := nil;
  FLogicalLinkRequest.OrderedSymbols.Free;
  FLogicalLinkRequest.OrderedSymbols := nil;
  inherited Destroy;
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
  Step: TToolInvocationStep;
begin
  if FSteps = nil then
    FSteps := TToolInvocationStepVec.Create;
  Step := Default(TToolInvocationStep);
  Step.StepId := AStepId;
  Step.ToolRole := FToolRole;
  Step.ProfileId := FProfileId;
  Step.SysrootRef := FSysrootRef;
  Step.LogicalExecutable := ALogicalExecutable;
  Step.ExecutableRef := AExecutableRef;
  Step.WorkingDirectory := AWorkingDirectory;
  Step.FailureMapping := AFailureMapping;
  InitToolInvocationStepNested(Step);
  Result := LongInt(FSteps.Count);
  FSteps.Push(Step);
end;

procedure TToolchainPlan.SetStepContext(
  const AStepIndex: LongInt;
  const AToolRole: string;
  const AProfileId: string;
  const ASysrootRef: string
);
var
  Step: PToolInvocationStep;
begin
  if (FSteps = nil) or (AStepIndex < 0) or (AStepIndex >= LongInt(FSteps.Count)) then
    Exit;

  Step := FSteps.GetPtr(SizeUInt(AStepIndex));
  Step^.ToolRole := AToolRole;
  Step^.ProfileId := AProfileId;
  Step^.SysrootRef := ASysrootRef;
end;

procedure TToolchainPlan.AddStepArg(const AStepIndex: LongInt; const AValue: string);
var
  Step: PToolInvocationStep;
begin
  if (FSteps = nil) or (AStepIndex < 0) or (AStepIndex >= LongInt(FSteps.Count)) then
    Exit;
  Step := FSteps.GetPtr(SizeUInt(AStepIndex));
  if Step^.Argv = nil then
    Step^.Argv := TToolchainStringVec.Create;
  Step^.Argv.Push(AValue);
end;

procedure TToolchainPlan.AddStepInput(
  const AStepIndex: LongInt;
  const AKind: string;
  const APath: string
);
var
  Entry: TToolArtifactRef;
  Step: PToolInvocationStep;
begin
  if (FSteps = nil) or (AStepIndex < 0) or (AStepIndex >= LongInt(FSteps.Count)) then
    Exit;
  Step := FSteps.GetPtr(SizeUInt(AStepIndex));
  if Step^.Inputs = nil then
    Step^.Inputs := TToolArtifactRefVec.Create;
  Entry.Kind := AKind;
  Entry.Path := APath;
  Step^.Inputs.Push(Entry);
end;

procedure TToolchainPlan.AddStepOutput(
  const AStepIndex: LongInt;
  const AKind: string;
  const APath: string
);
var
  Entry: TToolArtifactRef;
  Step: PToolInvocationStep;
begin
  if (FSteps = nil) or (AStepIndex < 0) or (AStepIndex >= LongInt(FSteps.Count)) then
    Exit;
  Step := FSteps.GetPtr(SizeUInt(AStepIndex));
  if Step^.Outputs = nil then
    Step^.Outputs := TToolArtifactRefVec.Create;
  Entry.Kind := AKind;
  Entry.Path := APath;
  Step^.Outputs.Push(Entry);
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
  Entry: TToolSidecarRef;
  Step: PToolInvocationStep;
begin
  if (FSteps = nil) or (AStepIndex < 0) or (AStepIndex >= LongInt(FSteps.Count)) then
    Exit;
  Step := FSteps.GetPtr(SizeUInt(AStepIndex));
  if Step^.Sidecars = nil then
    Step^.Sidecars := TToolSidecarRefVec.Create;
  Entry.Kind := AKind;
  Entry.Path := APath;
  Entry.OwnerStepId := AOwnerStepId;
  Entry.MaterializationTiming := AMaterializationTiming;
  Entry.CleanupPolicy := ACleanupPolicy;
  Step^.Sidecars.Push(Entry);
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
  if FLogicalLinkRequest.ObjectInputs = nil then
    FLogicalLinkRequest.ObjectInputs := TToolArtifactRefVec.Create
  else
    FLogicalLinkRequest.ObjectInputs.Clear;
  if FLogicalLinkRequest.LibraryRequests = nil then
    FLogicalLinkRequest.LibraryRequests := TLogicalLibraryRequestVec.Create
  else
    FLogicalLinkRequest.LibraryRequests.Clear;
  if FLogicalLinkRequest.OrderedSymbols = nil then
    FLogicalLinkRequest.OrderedSymbols := TToolchainStringVec.Create
  else
    FLogicalLinkRequest.OrderedSymbols.Clear;
end;

procedure TToolchainPlan.AddLogicalObjectInput(const APath: string);
var
  Entry: TToolArtifactRef;
begin
  if FLogicalLinkRequest.ObjectInputs = nil then
    FLogicalLinkRequest.ObjectInputs := TToolArtifactRefVec.Create;
  Entry.Kind := 'object-file';
  Entry.Path := APath;
  FLogicalLinkRequest.ObjectInputs.Push(Entry);
end;

procedure TToolchainPlan.AddLogicalLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
);
var
  Entry: TLogicalLibraryRequest;
begin
  if FLogicalLinkRequest.LibraryRequests = nil then
    FLogicalLinkRequest.LibraryRequests := TLogicalLibraryRequestVec.Create;
  Entry.LogicalId := ALogicalId;
  Entry.LinkageKind := ALinkageKind;
  Entry.Strength := AStrength;
  FLogicalLinkRequest.LibraryRequests.Push(Entry);
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
  if FSteps = nil then
    Exit(0);
  Result := LongInt(FSteps.Count);
end;

function TToolchainPlan.StepAt(const AIndex: LongInt): TToolInvocationStep;
begin
  if (FSteps = nil) or (AIndex < 0) or (AIndex >= LongInt(FSteps.Count)) then
  begin
    ClearToolInvocationStepView(Result);
    Exit;
  end;

  Result := FSteps[SizeUInt(AIndex)];
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
  if (FSteps = nil) or (FSteps.Count = 0) then
    Exit('');
  Result := FSteps[0].StepId;
end;

function TToolchainPlan.PrimaryToolLogicalExecutable: string;
begin
  if (FSteps = nil) or (FSteps.Count = 0) then
    Exit('');
  Result := FSteps[0].LogicalExecutable;
end;

function TToolchainPlan.PrimaryToolExecutableRef: string;
begin
  if (FSteps = nil) or (FSteps.Count = 0) then
    Exit('');
  Result := FSteps[0].ExecutableRef;
end;

function TToolchainPlan.PrimaryToolSysrootRef: string;
begin
  Result := FSysrootRef;
end;

function TToolchainPlan.PrimaryToolFailureMapping: string;
begin
  if (FSteps = nil) or (FSteps.Count = 0) then
    Exit('');
  Result := FSteps[0].FailureMapping;
end;

function TToolchainPlan.PrimaryToolArgCount: LongInt;
begin
  if (FSteps = nil) or (FSteps.Count = 0) or (FSteps[0].Argv = nil) then
    Exit(0);
  Result := LongInt(FSteps[0].Argv.Count);
end;

function TToolchainPlan.PrimaryToolArgValue(const AIndex: LongInt): string;
begin
  if (FSteps = nil) or (FSteps.Count = 0) or (FSteps[0].Argv = nil) or
    (AIndex < 0) or (AIndex >= LongInt(FSteps[0].Argv.Count)) then
    Exit('');
  Result := FSteps[0].Argv[SizeUInt(AIndex)];
end;

function TToolchainPlan.PrimaryToolWorkingDirectory: string;
begin
  if (FSteps = nil) or (FSteps.Count = 0) then
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
  if FLogicalLinkRequest.LibraryRequests = nil then
    Exit(0);
  Result := LongInt(FLogicalLinkRequest.LibraryRequests.Count);
end;

function TToolchainPlan.LlvmToolchainStatus: string;
begin
  Result := FLlvmExecutableContract.Status;
end;

function TToolchainPlan.LlvmExecutableSetId: string;
begin
  Result := FLlvmExecutableContract.ExecutableSetId;
end;
