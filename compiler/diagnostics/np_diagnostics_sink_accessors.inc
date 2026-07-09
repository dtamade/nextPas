procedure TDiagnosticsSink.SetWarningAsError(const AValue: Boolean);
begin
  FPolicy.WarningAsError := AValue;
  if AValue then
    FPolicy.Name := 'warning-as-error'
  else
    FPolicy.Name := 'default';
end;

procedure TDiagnosticsSink.EmitError(
  const ACode: string;
  const APhase: string;
  const AFileId: TCoreId;
  const AByteOffset: LongInt;
  const AMessageText: string
);
begin
  EmitErrorAtSpan(
    ACode,
    APhase,
    BuildCoreSourceSpan(AFileId, AByteOffset, 0),
    AMessageText
  );
end;

procedure TDiagnosticsSink.EmitWarning(
  const ACode: string;
  const APhase: string;
  const AFileId: TCoreId;
  const AByteOffset: LongInt;
  const AMessageText: string
);
var
  NextIndex: SizeInt;
  SeverityName: string;
begin
  NextIndex := Length(FDiagnostics);
  SetLength(FDiagnostics, NextIndex + 1);
  FDiagnostics[NextIndex].Id := BuildDiagnosticId(NextIndex + 1);
  FDiagnostics[NextIndex].Code := ACode;
  FDiagnostics[NextIndex].Phase := APhase;
  FDiagnostics[NextIndex].PrimarySpan := BuildCoreSourceSpan(
    AFileId,
    AByteOffset,
    0
  );
  FDiagnostics[NextIndex].MessageText := AMessageText;

  if FPolicy.WarningAsError then
  begin
    SeverityName := 'error';
    Inc(FErrorCount);
  end
  else
  begin
    SeverityName := 'warning';
    Inc(FWarningCount);
  end;

  FDiagnostics[NextIndex].Severity := SeverityName;
end;

procedure TDiagnosticsSink.EmitErrorAtSpan(
  const ACode: string;
  const APhase: string;
  const APrimarySpan: TCoreSourceSpan;
  const AMessageText: string
);
var
  EmptyPayload: TDiagnosticPayload;
begin
  EmptyPayload.Kind := dpkNone;
  EmitErrorWithPayload(ACode, APhase, APrimarySpan, AMessageText, EmptyPayload);
end;

procedure TDiagnosticsSink.EmitErrorWithPayload(
  const ACode: string;
  const APhase: string;
  const APrimarySpan: TCoreSourceSpan;
  const AMessageText: string;
  const APayload: TDiagnosticPayload
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FDiagnostics);
  SetLength(FDiagnostics, NextIndex + 1);
  FDiagnostics[NextIndex].Id := BuildDiagnosticId(NextIndex + 1);
  FDiagnostics[NextIndex].Code := ACode;
  FDiagnostics[NextIndex].Phase := APhase;
  FDiagnostics[NextIndex].Severity := 'error';
  FDiagnostics[NextIndex].PrimarySpan := APrimarySpan;
  FDiagnostics[NextIndex].MessageText := AMessageText;
  FDiagnostics[NextIndex].Payload := APayload;
  Inc(FErrorCount);
end;

procedure TDiagnosticsSink.EmitToolchainError(
  const ACode: string;
  const ABindingId: string;
  const AProfileId: string;
  const AStepId: string;
  const ALogicalExecutable: string;
  const ASysrootRef: string;
  const AResolvedPath: string;
  const APrimaryArtifactKind: string;
  const APrimaryArtifactPath: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt;
  const AMessageText: string
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FDiagnostics);
  SetLength(FDiagnostics, NextIndex + 1);
  FDiagnostics[NextIndex].Id := BuildDiagnosticId(NextIndex + 1);
  FDiagnostics[NextIndex].Code := ACode;
  FDiagnostics[NextIndex].Phase := 'toolchain';
  FDiagnostics[NextIndex].Severity := 'error';
  FDiagnostics[NextIndex].PrimarySpan := BuildCoreSourceSpan(0, 0, 0);
  FDiagnostics[NextIndex].MessageText := AMessageText;
  FDiagnostics[NextIndex].BindingId := ABindingId;
  FDiagnostics[NextIndex].ProfileId := AProfileId;
  FDiagnostics[NextIndex].StepId := AStepId;
  FDiagnostics[NextIndex].LogicalExecutable := ALogicalExecutable;
  FDiagnostics[NextIndex].SysrootRef := ASysrootRef;
  FDiagnostics[NextIndex].ResolvedPath := AResolvedPath;
  FDiagnostics[NextIndex].PrimaryArtifactKind := APrimaryArtifactKind;
  FDiagnostics[NextIndex].PrimaryArtifactPath := APrimaryArtifactPath;
  FDiagnostics[NextIndex].ExitCode := AExitCode;
  FDiagnostics[NextIndex].HasExitCode := AHasExitCode;
  Inc(FErrorCount);
end;

function TDiagnosticsSink.ErrorCount: LongInt;
begin
  Result := FErrorCount;
end;

function TDiagnosticsSink.HasErrors: Boolean;
begin
  Result := FErrorCount > 0;
end;

function TDiagnosticsSink.TotalCount: LongInt;
begin
  Result := FErrorCount + FWarningCount;
end;

function TDiagnosticsSink.WarningCount: LongInt;
begin
  Result := FWarningCount;
end;

function TDiagnosticsSink.PolicyName: string;
begin
  Result := FPolicy.Name;
end;

function TDiagnosticsSink.LastDiagnosticId: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].Id;
end;

function TDiagnosticsSink.LastDiagnosticCode: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].Code;
end;

function TDiagnosticsSink.LastDiagnosticPhase: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].Phase;
end;

function TDiagnosticsSink.LastDiagnosticMessage: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].MessageText;
end;

function TDiagnosticsSink.LastDiagnosticBindingId: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].BindingId;
end;

function TDiagnosticsSink.LastDiagnosticProfileId: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].ProfileId;
end;

function TDiagnosticsSink.LastDiagnosticStepId: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].StepId;
end;

function TDiagnosticsSink.LastDiagnosticLogicalExecutable: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].LogicalExecutable;
end;

function TDiagnosticsSink.LastDiagnosticSysrootRef: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].SysrootRef;
end;

function TDiagnosticsSink.LastDiagnosticResolvedPath: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].ResolvedPath;
end;

function TDiagnosticsSink.LastDiagnosticPrimaryArtifactKind: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].PrimaryArtifactKind;
end;

function TDiagnosticsSink.LastDiagnosticPrimaryArtifactPath: string;
begin
  if Length(FDiagnostics) = 0 then
    Exit('');

  Result := FDiagnostics[High(FDiagnostics)].PrimaryArtifactPath;
end;

function TDiagnosticsSink.LastDiagnosticExitCode: LongInt;
begin
  if Length(FDiagnostics) = 0 then
    Exit(0);

  Result := FDiagnostics[High(FDiagnostics)].ExitCode;
end;

function TDiagnosticsSink.HasLastDiagnosticExitCode: Boolean;
begin
  if Length(FDiagnostics) = 0 then
    Exit(False);

  Result := FDiagnostics[High(FDiagnostics)].HasExitCode;
end;

