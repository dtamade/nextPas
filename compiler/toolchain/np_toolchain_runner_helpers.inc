function IsAbsolutePath(const APath: string): Boolean;
begin
  if APath = '' then
    Exit(False);

  if APath[1] = DirectorySeparator then
    Exit(True);

  Result := (Length(APath) >= 2) and (APath[2] = ':');
end;

procedure EnsureFsIsDir(
  const AResolvedPath: string;
  const AFailureKind: string
);
begin
  if Trim(AResolvedPath) = '' then
    Exit;

  if FsExists(AResolvedPath) and not FsIsDir(AResolvedPath) then
    raise EToolchainRunnerError.Create(
      AFailureKind + ': ' + AResolvedPath
    );

  if FsIsDir(AResolvedPath) then
    Exit;

  { FsMkdirAll is procedure (INV-5): failure raises; re-wrap as toolchain error. }
  try
    FsMkdirAll(AResolvedPath);
  except
    raise EToolchainRunnerError.Create(
      AFailureKind + ': ' + AResolvedPath
    );
  end;
end;

procedure EnsureParentDirectory(
  const APath: string;
  const AFailureKind: string
);
var
  ParentPath: string;
begin
  ParentPath := ExtractFileDir(ExpandFileName(APath));
  if ParentPath <> '' then
    EnsureFsIsDir(ParentPath, AFailureKind);
end;

procedure WriteTextFile(const APath: string; const AText: string);
begin
  EnsureParentDirectory(APath, 'toolchain.sidecar-parent-invalid');
  WriteFileText(APath, AText);
end;

function LocalFileSearch(const AName, ASearchPath: string): string;
var
  Start, SepPos: LongInt;
  Candidate: string;
begin
  if (AName = '') or (ASearchPath = '') then
    Exit('');
  Start := 1;
  while Start <= Length(ASearchPath) do
  begin
    SepPos := Start;
    while (SepPos <= Length(ASearchPath)) and (ASearchPath[SepPos] <> PathSeparator) do
      Inc(SepPos);
    if SepPos > Start then
    begin
      Candidate := Copy(ASearchPath, Start, SepPos - Start) +
        DirectorySeparator + AName;
      if FsExists(Candidate) then
        Exit(Candidate);
    end;
    Start := SepPos + 1;
  end;
  Result := '';
end;

function ResolveExecutablePath(
  const AStep: TToolInvocationStep;
  const AExecutableSearchPath: string
): string;
var
  SearchName: string;
begin
  SearchName := AStep.ExecutableRef;
  if SearchName = '' then
    SearchName := AStep.LogicalExecutable;

  if SearchName = '' then
    raise EToolchainRunnerError.Create(
      'toolchain.missing-logical-executable: ' + AStep.StepId
    );

  if IsAbsolutePath(SearchName) then
  begin
    Result := ExpandFileName(SearchName);
    if not FsExists(Result) then
      raise EToolchainRunnerError.Create(
        'toolchain.missing-executable: ' + SearchName
      );
    Exit;
  end;

  if AExecutableSearchPath <> '' then
    Result := LocalFileSearch(SearchName, AExecutableSearchPath)
  else
    Result := LocalFileSearch(SearchName, GetEnvironmentVariable('PATH'));

  if Result = '' then
    raise EToolchainRunnerError.Create(
      'toolchain.missing-executable: ' + SearchName
    );
end;

function BuildResponseFileText(const AStep: TToolInvocationStep): string;
var
  InputIndex: LongInt;
begin
  Result := '';
  if AStep.Inputs = nil then
    Exit;
  for InputIndex := 0 to LongInt(AStep.Inputs.Count) - 1 do
    if AStep.Inputs[SizeUInt(InputIndex)].Kind = 'object-file' then
      Result := Result + ExpandFileName(AStep.Inputs[SizeUInt(InputIndex)].Path) +
        LineEnding;
end;

function BuildResourceListScriptText(const AStep: TToolInvocationStep): string;
var
  InputIndex: LongInt;
begin
  Result := '';
  if AStep.Inputs = nil then
    Exit;
  for InputIndex := 0 to LongInt(AStep.Inputs.Count) - 1 do
    Result := Result + ExpandFileName(AStep.Inputs[SizeUInt(InputIndex)].Path) +
      LineEnding;
end;

function BuildArchiveCommandScriptText(const AStep: TToolInvocationStep): string;
var
  ArchivePath: string;
  InputIndex: LongInt;
begin
  ArchivePath := '';
  if AStep.Outputs <> nil then
    for InputIndex := 0 to LongInt(AStep.Outputs.Count) - 1 do
      if AStep.Outputs[SizeUInt(InputIndex)].Kind = 'static-library' then
      begin
        ArchivePath := ExpandFileName(AStep.Outputs[SizeUInt(InputIndex)].Path);
        Break;
      end;

  Result := 'create ' + ArchivePath + LineEnding;
  if AStep.Inputs <> nil then
    for InputIndex := 0 to LongInt(AStep.Inputs.Count) - 1 do
      if AStep.Inputs[SizeUInt(InputIndex)].Kind = 'object-file' then
        Result := Result + 'addmod ' +
          ExpandFileName(AStep.Inputs[SizeUInt(InputIndex)].Path) + LineEnding;
  Result := Result + 'save' + LineEnding + 'end' + LineEnding;
end;

function BuildSidecarText(
  const AStep: TToolInvocationStep;
  const ASidecar: TToolSidecarRef
): string;
begin
  if ASidecar.Kind = 'response-file' then
    Exit(BuildResponseFileText(AStep));

  if ASidecar.Kind = 'resource-list-script' then
    Exit(BuildResourceListScriptText(AStep));

  if ASidecar.Kind = 'archive-command-script' then
    Exit(BuildArchiveCommandScriptText(AStep));

  raise EToolchainRunnerError.Create(
    'toolchain.unsupported-sidecar-kind: ' + ASidecar.Kind
  );
end;

function BuildExecutedSidecars(
  const AStep: TToolInvocationStep
): TToolchainExecutedSidecarArray;
var
  SidecarIndex: LongInt;
begin
  Result := nil;
  if (AStep.Sidecars = nil) or (AStep.Sidecars.Count = 0) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  SetLength(Result, AStep.Sidecars.Count);
  for SidecarIndex := 0 to LongInt(AStep.Sidecars.Count) - 1 do
  begin
    Result[SidecarIndex].Kind := AStep.Sidecars[SizeUInt(SidecarIndex)].Kind;
    Result[SidecarIndex].Path := AStep.Sidecars[SizeUInt(SidecarIndex)].Path;
    Result[SidecarIndex].OwnerStepId :=
      AStep.Sidecars[SizeUInt(SidecarIndex)].OwnerStepId;
    Result[SidecarIndex].MaterializationTiming :=
      AStep.Sidecars[SizeUInt(SidecarIndex)].MaterializationTiming;
    Result[SidecarIndex].CleanupPolicy :=
      AStep.Sidecars[SizeUInt(SidecarIndex)].CleanupPolicy;
    Result[SidecarIndex].Materialized := False;
    Result[SidecarIndex].CleanupStatus := 'not-requested';
  end;
end;

procedure MaterializeSidecars(
  const AStep: TToolInvocationStep;
  var AExecutedSidecars: TToolchainExecutedSidecarArray
);
var
  SidecarIndex: LongInt;
begin
  if AStep.Sidecars = nil then
    Exit;
  for SidecarIndex := 0 to LongInt(AStep.Sidecars.Count) - 1 do
    if AStep.Sidecars[SizeUInt(SidecarIndex)].MaterializationTiming =
      'before-step-exec' then
    begin
      WriteTextFile(
        AStep.Sidecars[SizeUInt(SidecarIndex)].Path,
        BuildSidecarText(AStep, AStep.Sidecars[SizeUInt(SidecarIndex)])
      );
      AExecutedSidecars[SidecarIndex].Materialized := True;
    end;
end;

procedure FinalizeUncleanedSidecars(
  var AExecutedSidecars: TToolchainExecutedSidecarArray
);
var
  SidecarIndex: LongInt;
begin
  for SidecarIndex := 0 to Length(AExecutedSidecars) - 1 do
    if AExecutedSidecars[SidecarIndex].Materialized then
      AExecutedSidecars[SidecarIndex].CleanupStatus := 'retained';
end;

procedure CleanupSidecars(
  var AExecutedSidecars: TToolchainExecutedSidecarArray
);
var
  SidecarIndex: LongInt;
  SidecarPath: string;
begin
  for SidecarIndex := 0 to Length(AExecutedSidecars) - 1 do
  begin
    if not AExecutedSidecars[SidecarIndex].Materialized then
      Continue;

    if AExecutedSidecars[SidecarIndex].CleanupPolicy = 'delete-on-success' then
    begin
      SidecarPath := ExpandFileName(AExecutedSidecars[SidecarIndex].Path);
      FsRemove(SidecarPath);
