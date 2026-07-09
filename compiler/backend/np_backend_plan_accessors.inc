function TBackendPlan.AddArtifact(const AKind: string; const APath: string): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FArtifacts);
  SetLength(FArtifacts, NextIndex + 1);
  FArtifacts[NextIndex].ArtifactId := NextIndex + 1;
  FArtifacts[NextIndex].Kind := AKind;
  FArtifacts[NextIndex].Path := APath;
  Result := FArtifacts[NextIndex].ArtifactId;
end;

function TBackendPlan.ArtifactCount: LongInt;
begin
  Result := Length(FArtifacts);
end;

function TBackendPlan.ArtifactAt(const AIndex: LongInt): TBackendArtifact;
begin
  if (AIndex < 0) or (AIndex > High(FArtifacts)) then
  begin
    Result.ArtifactId := 0;
    Result.Kind := '';
    Result.Path := '';
    Exit;
  end;

  Result := FArtifacts[AIndex];
end;

function TBackendPlan.ArtifactPathByKind(const AKind: string): string;
var
  Index: LongInt;
begin
  Result := '';
  for Index := 0 to High(FArtifacts) do
    if SameText(FArtifacts[Index].Kind, AKind) then
      Exit(FArtifacts[Index].Path);
end;

function TBackendPlan.ArtifactsJson: string;
var
  EntryFields: string;
  Index: LongInt;
begin
  Result := '';
  for Index := 0 to High(FArtifacts) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(
      EntryFields,
      'artifactId',
      IntToStr(FArtifacts[Index].ArtifactId)
    );
    AppendJsonField(EntryFields, 'kind', JsonString(FArtifacts[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(FArtifacts[Index].Path));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function TBackendPlan.AddLogicalLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
): LongInt;
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FLogicalLibraryRequests) - 1 do
    if SameText(FLogicalLibraryRequests[Index].LogicalId, ALogicalId) and
      SameText(FLogicalLibraryRequests[Index].LinkageKind, ALinkageKind) and
      SameText(FLogicalLibraryRequests[Index].Strength, AStrength) then
      Exit(FLogicalLibraryRequests[Index].RequestId);

  NextIndex := Length(FLogicalLibraryRequests);
  SetLength(FLogicalLibraryRequests, NextIndex + 1);
  FLogicalLibraryRequests[NextIndex].RequestId := NextIndex + 1;
  FLogicalLibraryRequests[NextIndex].LogicalId := ALogicalId;
  FLogicalLibraryRequests[NextIndex].LinkageKind := ALinkageKind;
  FLogicalLibraryRequests[NextIndex].Strength := AStrength;
  Result := FLogicalLibraryRequests[NextIndex].RequestId;
end;

function TBackendPlan.LogicalLibraryRequestCount: LongInt;
begin
  Result := Length(FLogicalLibraryRequests);
end;

function TBackendPlan.LogicalLibraryRequestAt(
  const AIndex: LongInt
): TBackendLogicalLibraryRequest;
begin
  if (AIndex < 0) or (AIndex > High(FLogicalLibraryRequests)) then
  begin
    Result.RequestId := 0;
    Result.LogicalId := '';
    Result.LinkageKind := '';
    Result.Strength := '';
    Exit;
  end;

  Result := FLogicalLibraryRequests[AIndex];
end;

procedure TBackendPlan.SetRootName(const AName: string);
begin
  FRootName := AName;
end;

function TBackendPlan.RootName: string;
begin
  Result := FRootName;
end;

procedure TBackendPlan.SetOutputKind(const AKind: string);
begin
  FOutputKind := AKind;
end;

function TBackendPlan.OutputKind: string;
begin
  Result := FOutputKind;
end;

procedure TBackendPlan.SetPrimaryArtifact(const AKind: string; const APath: string);
begin
  FPrimaryArtifactKind := AKind;
  FPrimaryArtifactPath := APath;
end;

function TBackendPlan.PrimaryArtifactKind: string;
begin
  Result := FPrimaryArtifactKind;
end;

function TBackendPlan.PrimaryArtifactPath: string;
begin
  Result := FPrimaryArtifactPath;
end;

procedure TBackendPlan.SetTargetMetadata(const ATargetFacts: TTargetFactsView);
begin
  FHostId := ATargetFacts.HostId;
  FToolchainBindingId := ATargetFacts.ToolchainBindingId;
  FHostCompilerProfileId := ATargetFacts.HostCompilerProfileId;
  FBackendFamily := ATargetFacts.BackendFamily;
  FAssemblerProfileId := ATargetFacts.AssemblerProfileId;
  FLinkerProfileId := ATargetFacts.LinkerProfileId;
  FArchiverProfileId := ATargetFacts.ArchiverProfileId;
  FResourceToolProfileId := ATargetFacts.ResourceToolProfileId;
  FObjectFormat := ATargetFacts.ObjectFormat;
  FAssemblerFlavor := ATargetFacts.AssemblerFlavor;
  FLinkerFlavor := ATargetFacts.LinkerFlavor;
  FRuntimeLayoutKey := ATargetFacts.RuntimeLayoutKey;
  FTargetCSymbolPrefix := ATargetFacts.CSymbolPrefix;
  FTargetCLibraryNaming := ATargetFacts.CLibraryNaming;
  FLlvmTriple := ATargetFacts.LlvmTriple;
  FLlvmDataLayout := ATargetFacts.LlvmDataLayout;
  FSysrootMode := ATargetFacts.SysrootMode;
  FRuntimeSdkId := ATargetFacts.RuntimeSdkId;
  FAllowHostFallback := ATargetFacts.AllowHostFallback;
  FToolRootKind := ATargetFacts.ToolRootKind;
  FRuntimeRootKind := ATargetFacts.RuntimeRootKind;
  FResponseFilePolicy := ATargetFacts.ResponseFilePolicy;
  FLinkScriptPolicy := ATargetFacts.LinkScriptPolicy;
  FLlvmEnabled := ATargetFacts.LlvmEnabled;
  FLlvmExecutableSetId := ATargetFacts.LlvmExecutableSetId;
end;

function TBackendPlan.HostId: string;
begin
  Result := FHostId;
end;

function TBackendPlan.ToolchainBindingId: string;
begin
  Result := FToolchainBindingId;
end;

function TBackendPlan.HostCompilerProfileId: string;
begin
  Result := FHostCompilerProfileId;
end;

function TBackendPlan.BackendFamily: string;
begin
  Result := FBackendFamily;
end;

function TBackendPlan.AssemblerProfileId: string;
begin
  Result := FAssemblerProfileId;
end;

function TBackendPlan.LinkerProfileId: string;
begin
  Result := FLinkerProfileId;
end;

function TBackendPlan.ArchiverProfileId: string;
begin
  Result := FArchiverProfileId;
end;

function TBackendPlan.ResourceToolProfileId: string;
begin
  Result := FResourceToolProfileId;
end;

function TBackendPlan.ObjectFormat: string;
begin
  Result := FObjectFormat;
end;

function TBackendPlan.AssemblerFlavor: string;
begin
  Result := FAssemblerFlavor;
end;

function TBackendPlan.LinkerFlavor: string;
begin
  Result := FLinkerFlavor;
end;

function TBackendPlan.RuntimeLayoutKey: string;
begin
  Result := FRuntimeLayoutKey;
end;

function TBackendPlan.TargetCSymbolPrefix: string;
begin
  Result := FTargetCSymbolPrefix;
end;

function TBackendPlan.TargetCLibraryNaming: string;
begin
  Result := FTargetCLibraryNaming;
end;

function TBackendPlan.LlvmTriple: string;
begin
  Result := FLlvmTriple;
end;

function TBackendPlan.LlvmDataLayout: string;
begin
  Result := FLlvmDataLayout;
end;

function TBackendPlan.SysrootMode: string;
begin
  Result := FSysrootMode;
end;

function TBackendPlan.RuntimeSdkId: string;
begin
  Result := FRuntimeSdkId;
end;

function TBackendPlan.AllowHostFallback: Boolean;
begin
  Result := FAllowHostFallback;
end;

function TBackendPlan.ToolRootKind: string;
begin
  Result := FToolRootKind;
end;

function TBackendPlan.RuntimeRootKind: string;
begin
  Result := FRuntimeRootKind;
end;

function TBackendPlan.ResponseFilePolicy: string;
begin
  Result := FResponseFilePolicy;
end;

function TBackendPlan.LinkScriptPolicy: string;
begin
  Result := FLinkScriptPolicy;
end;

function TBackendPlan.LlvmEnabled: Boolean;
begin
  Result := FLlvmEnabled;
end;

function TBackendPlan.LlvmExecutableSetId: string;
begin
  Result := FLlvmExecutableSetId;
end;

procedure TBackendPlan.MarkReady;
begin
  FStatus := 'ready';
end;

procedure TBackendPlan.MarkFailure;
begin
  FStatus := 'failure';
end;

function TBackendPlan.Status: string;
begin
  Result := FStatus;
end;

constructor TBackendPlanner.Create(
  const ASemaModel: TSemanticModel;
  const ATargetFacts: TTargetFactsView;
  const ASourcePath: string;
  const AArtifactRootPath: string;
  const AOutputDirPath: string;
  const ARootKindName: string;
  const ANoFold: Boolean;
  const AOptLevel: string
);
begin
  inherited Create;
  FSemaModel := ASemaModel;
  FTargetFacts := ATargetFacts;
  FSourcePath := ASourcePath;
  FArtifactRootPath := AArtifactRootPath;
  FOutputDirPath := AOutputDirPath;
  FRootKindName := ARootKindName;
  FNoFold := ANoFold;
  FOptLevel := AOptLevel;
  FPlan := TBackendPlan.Create;
end;

destructor TBackendPlanner.Destroy;
begin
  FPlan.Free;
  inherited Destroy;
end;

