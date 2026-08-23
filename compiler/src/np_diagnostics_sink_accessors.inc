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
  Event: TDiagnosticRecord;
  SeverityName: string;
begin
  if FDiagnostics = nil then
    FDiagnostics := TDiagnosticRecordVec.Create;
  Event := Default(TDiagnosticRecord);
  Event.Id := BuildDiagnosticId(SizeInt(FDiagnostics.Count) + 1);
  Event.Code := ACode;
  Event.Phase := APhase;
  Event.PrimarySpan := BuildCoreSourceSpan(
    AFileId,
    AByteOffset,
    0
  );
  Event.MessageText := AMessageText;

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

  Event.Severity := SeverityName;
  FDiagnostics.Push(Event);
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
  { Must Default the whole payload: partial field init leaves Candidates garbage
    and FreeDiagnosticNestedTables AVs on sink Destroy. }
  EmptyPayload := Default(TDiagnosticPayload);
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
  Event: TDiagnosticRecord;
begin
  if FDiagnostics = nil then
    FDiagnostics := TDiagnosticRecordVec.Create;
  Event := Default(TDiagnosticRecord);
  Event.Id := BuildDiagnosticId(SizeInt(FDiagnostics.Count) + 1);
  Event.Code := ACode;
  Event.Phase := APhase;
  Event.Severity := 'error';
  Event.PrimarySpan := APrimarySpan;
  Event.MessageText := AMessageText;
  Event.Payload := APayload;
  FDiagnostics.Push(Event);
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
  Event: TDiagnosticRecord;
begin
  if FDiagnostics = nil then
    FDiagnostics := TDiagnosticRecordVec.Create;
  Event := Default(TDiagnosticRecord);
  Event.Id := BuildDiagnosticId(SizeInt(FDiagnostics.Count) + 1);
  Event.Code := ACode;
  Event.Phase := 'toolchain';
  Event.Severity := 'error';
  Event.PrimarySpan := BuildCoreSourceSpan(0, 0, 0);
  Event.MessageText := AMessageText;
  Event.BindingId := ABindingId;
  Event.ProfileId := AProfileId;
  Event.StepId := AStepId;
  Event.LogicalExecutable := ALogicalExecutable;
  Event.SysrootRef := ASysrootRef;
  Event.ResolvedPath := AResolvedPath;
  Event.PrimaryArtifactKind := APrimaryArtifactKind;
  Event.PrimaryArtifactPath := APrimaryArtifactPath;
  Event.ExitCode := AExitCode;
  Event.HasExitCode := AHasExitCode;
  FDiagnostics.Push(Event);
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
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.Id;
end;

function TDiagnosticsSink.LastDiagnosticCode: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.Code;
end;

function TDiagnosticsSink.LastDiagnosticPhase: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.Phase;
end;

function TDiagnosticsSink.LastDiagnosticMessage: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.MessageText;
end;

function TDiagnosticsSink.LastDiagnosticBindingId: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.BindingId;
end;

function TDiagnosticsSink.LastDiagnosticProfileId: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.ProfileId;
end;

function TDiagnosticsSink.LastDiagnosticStepId: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.StepId;
end;

function TDiagnosticsSink.LastDiagnosticLogicalExecutable: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.LogicalExecutable;
end;

function TDiagnosticsSink.LastDiagnosticSysrootRef: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.SysrootRef;
end;

function TDiagnosticsSink.LastDiagnosticResolvedPath: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.ResolvedPath;
end;

function TDiagnosticsSink.LastDiagnosticPrimaryArtifactKind: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.PrimaryArtifactKind;
end;

function TDiagnosticsSink.LastDiagnosticPrimaryArtifactPath: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('');

  Result := FDiagnostics.Last.PrimaryArtifactPath;
end;

function TDiagnosticsSink.LastDiagnosticExitCode: LongInt;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit(0);

  Result := FDiagnostics.Last.ExitCode;
end;

function TDiagnosticsSink.HasLastDiagnosticExitCode: Boolean;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit(False);

  Result := FDiagnostics.Last.HasExitCode;
end;
