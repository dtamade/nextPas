unit nextpas.compiler.diagnostics.sink;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../../rtl/core/base}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.collections.vec,
  np_base_types,
  nextpas_json_helpers;

type
  TDiagnosticsPolicy = record
    Name: string;
    WarningAsError: Boolean;
  end;

  TRelatedInformation = record
    Span: TCoreSourceSpan;
    Message: string;
  end;

  { Nested product tables owned by diagnostic entry (default heap). }
  TRelatedInformationVec = specialize TVec<TRelatedInformation>;

  TSuggestedFix = record
    Description: string;
    ReplacementSpan: TCoreSourceSpan;
    ReplacementText: string;
  end;

  TSuggestedFixVec = specialize TVec<TSuggestedFix>;

  TOverloadCandidate = record
    Name: string;
    ParamSignature: string;
    ParamCount: LongInt;
    DeclByteOffset: LongInt;
    MismatchReason: string;
  end;

  { Analyzer out-param build/discard path keeps managed dynarray. }
  TOverloadCandidateArray = array of TOverloadCandidate;
  { Nested product table owned by diagnostic payload (default heap). }
  TOverloadCandidateVec = specialize TVec<TOverloadCandidate>;

  TDiagnosticPayloadKind = (
    dpkNone,
    dpkTypeMismatch,
    dpkWrongArgumentCount,
    dpkOverloadCandidates
  );

  TDiagnosticPayload = record
    Kind: TDiagnosticPayloadKind;
    ExpectedType: string;
    ActualType: string;
    ArgIndex: LongInt;
    ExpectedCount: LongInt;
    ActualCount: LongInt;
    Candidates: TOverloadCandidateVec;
  end;

  TDiagnosticRecord = record
    Id: string;
    Code: string;
    Phase: string;
    Severity: string;
    PrimarySpan: TCoreSourceSpan;
    MessageText: string;
    RelatedInformation: TRelatedInformationVec;
    SuggestedFixes: TSuggestedFixVec;
    Payload: TDiagnosticPayload;
    BindingId: string;
    ProfileId: string;
    StepId: string;
    LogicalExecutable: string;
    SysrootRef: string;
    ResolvedPath: string;
    PrimaryArtifactKind: string;
    PrimaryArtifactPath: string;
    ExitCode: LongInt;
    HasExitCode: Boolean;
  end;

  TDiagnosticRecordVec = specialize TVec<TDiagnosticRecord>;

  TDiagnosticByteCountResolver = function(const AFileId: TCoreId; const AByteOffset: LongInt): LongInt of object;

  TDiagnosticsSink = class
  private
    FPolicy: TDiagnosticsPolicy;
    FErrorCount: LongInt;
    FWarningCount: LongInt;
    FDiagnostics: TDiagnosticRecordVec;
    FByteCountResolver: TDiagnosticByteCountResolver;
  public
    function ResolveByteCount(const AFileId: TCoreId; const AByteOffset: LongInt): LongInt;
    { Prefer CreateDefault; Create redirects so callers of bare Create do not AV. }
    constructor Create;
    constructor CreateDefault;
    destructor Destroy; override;
    procedure SetWarningAsError(const AValue: Boolean);
    procedure EmitError(
      const ACode: string;
      const APhase: string;
      const AFileId: TCoreId;
      const AByteOffset: LongInt;
      const AMessageText: string
    );
    procedure EmitWarning(
      const ACode: string;
      const APhase: string;
      const AFileId: TCoreId;
      const AByteOffset: LongInt;
      const AMessageText: string
    );
    procedure EmitErrorAtSpan(
      const ACode: string;
      const APhase: string;
      const APrimarySpan: TCoreSourceSpan;
      const AMessageText: string
    );
    procedure EmitErrorWithPayload(
      const ACode: string;
      const APhase: string;
      const APrimarySpan: TCoreSourceSpan;
      const AMessageText: string;
      const APayload: TDiagnosticPayload
    );
    procedure EmitToolchainError(
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
    function ErrorCount: LongInt;
    function HasErrors: Boolean;
    function TotalCount: LongInt;
    function WarningCount: LongInt;
    function PolicyName: string;
    function LastDiagnosticId: string;
    function LastDiagnosticCode: string;
    function LastDiagnosticPhase: string;
    function LastDiagnosticMessage: string;
    function LastDiagnosticBindingId: string;
    function LastDiagnosticProfileId: string;
    function LastDiagnosticStepId: string;
    function LastDiagnosticLogicalExecutable: string;
    function LastDiagnosticSysrootRef: string;
    function LastDiagnosticResolvedPath: string;
    function LastDiagnosticPrimaryArtifactKind: string;
    function LastDiagnosticPrimaryArtifactPath: string;
    function LastDiagnosticExitCode: LongInt;
    function HasLastDiagnosticExitCode: Boolean;
    function DiagnosticsJson: string;
    function Summary: string;
    { Adopts AFixes into the last diagnostic (takes ownership). }
    procedure AdoptSuggestedFixesOnLast(AFixes: TSuggestedFixVec);
    procedure BindByteCountResolver(const AResolver: TDiagnosticByteCountResolver);
  end;

{ Copy analyzer dynarray into entry-owned TVec (nil if empty). }
function CloneOverloadCandidatesFromArray(
  const ACandidates: TOverloadCandidateArray
): TOverloadCandidateVec;

implementation

function BuildDiagnosticId(const AOrdinal: SizeInt): string;
var
  NumericText: string;
begin
  NumericText := IntToStr(AOrdinal);
  while Length(NumericText) < 4 do
    NumericText := '0' + NumericText;

  Result := 'diag-' + NumericText;
end;

function CloneOverloadCandidatesFromArray(
  const ACandidates: TOverloadCandidateArray
): TOverloadCandidateVec;
var
  I: LongInt;
begin
  Result := nil;
  if Length(ACandidates) = 0 then
    Exit;
  Result := TOverloadCandidateVec.Create(SizeUInt(Length(ACandidates)));
  for I := 0 to High(ACandidates) do
    Result.Push(ACandidates[I]);
end;

procedure FreeDiagnosticNestedTables(var AEvent: TDiagnosticRecord);
begin
  AEvent.RelatedInformation.Free;
  AEvent.RelatedInformation := nil;
  AEvent.SuggestedFixes.Free;
  AEvent.SuggestedFixes := nil;
  AEvent.Payload.Candidates.Free;
  AEvent.Payload.Candidates := nil;
end;

constructor TDiagnosticsSink.Create;
begin
  CreateDefault;
end;

constructor TDiagnosticsSink.CreateDefault;
begin
  inherited Create;
  FPolicy.Name := 'default';
  FPolicy.WarningAsError := False;
  FErrorCount := 0;
  FWarningCount := 0;
  FDiagnostics := TDiagnosticRecordVec.Create;
end;

destructor TDiagnosticsSink.Destroy;
var
  I: SizeInt;
begin
  if FDiagnostics <> nil then
  begin
    for I := 0 to SizeInt(FDiagnostics.Count) - 1 do
      FreeDiagnosticNestedTables(FDiagnostics.GetPtr(SizeUInt(I))^);
    FDiagnostics.Free;
    FDiagnostics := nil;
  end;
  inherited Destroy;
end;

procedure TDiagnosticsSink.AdoptSuggestedFixesOnLast(AFixes: TSuggestedFixVec);
var
  P: ^TDiagnosticRecord;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
  begin
    AFixes.Free;
    Exit;
  end;
  P := FDiagnostics.GetPtr(FDiagnostics.Count - 1);
  P^.SuggestedFixes.Free;
  P^.SuggestedFixes := AFixes;
end;

procedure TDiagnosticsSink.BindByteCountResolver(const AResolver: TDiagnosticByteCountResolver);
begin
  FByteCountResolver := AResolver;
end;

function TDiagnosticsSink.ResolveByteCount(const AFileId: TCoreId; const AByteOffset: LongInt): LongInt;
begin
  if AFileId <= 0 then
    Exit(1);
  if Assigned(FByteCountResolver) then
  begin
    Result := FByteCountResolver(AFileId, AByteOffset);
    if Result < 1 then
      Result := 1;
    Exit;
  end;
  Result := 1;
end;

{--- inlined np_diagnostics_sink_accessors.inc ---}
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
    BuildCoreSourceSpan(AFileId, AByteOffset, ResolveByteCount(AFileId, AByteOffset)),
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
    ResolveByteCount(AFileId, AByteOffset)
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

{--- end ---}
function TDiagnosticsSink.DiagnosticsJson: string;
var
  ArtifactFields: string;
  CandidateArray: string;
  CandidateFields: string;
  CI: SizeInt;
  FixArray: string;
  FixFields: string;
  FI: SizeInt;
  Index: SizeInt;
  DiagnosticFields: string;
  RelatedArray: string;
  RI: SizeInt;
  RIFields: string;
  StructuredFields: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('[]');

  Result := '[';
  for Index := 0 to SizeInt(FDiagnostics.Count) - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    DiagnosticFields := '';
    AppendJsonField(DiagnosticFields, 'id', JsonString(FDiagnostics[Index].Id));
    AppendJsonField(DiagnosticFields, 'code', JsonString(FDiagnostics[Index].Code));
    AppendJsonField(DiagnosticFields, 'phase', JsonString(FDiagnostics[Index].Phase));
    AppendJsonField(
      DiagnosticFields,
      'severity',
      JsonString(FDiagnostics[Index].Severity)
    );
    if FDiagnostics[Index].PrimarySpan.FileId > 0 then
    begin
      AppendJsonField(
        DiagnosticFields,
        'fileId',
        IntToStr(FDiagnostics[Index].PrimarySpan.FileId)
      );
      AppendJsonField(
        DiagnosticFields,
        'byteOffset',
        IntToStr(FDiagnostics[Index].PrimarySpan.ByteSpan.Offset)
      );
      AppendJsonField(
        DiagnosticFields,
        'byteCount',
        IntToStr(FDiagnostics[Index].PrimarySpan.ByteSpan.Count)
      );
    end;
    if FDiagnostics[Index].BindingId <> '' then
      AppendJsonField(
        DiagnosticFields,
        'bindingId',
        JsonString(FDiagnostics[Index].BindingId)
      );
    if FDiagnostics[Index].ProfileId <> '' then
      AppendJsonField(
        DiagnosticFields,
        'profileId',
        JsonString(FDiagnostics[Index].ProfileId)
      );
    if FDiagnostics[Index].StepId <> '' then
      AppendJsonField(
        DiagnosticFields,
        'stepId',
        JsonString(FDiagnostics[Index].StepId)
      );
    if FDiagnostics[Index].LogicalExecutable <> '' then
      AppendJsonField(
        DiagnosticFields,
        'logicalExecutable',
        JsonString(FDiagnostics[Index].LogicalExecutable)
      );
    if FDiagnostics[Index].SysrootRef <> '' then
      AppendJsonField(
        DiagnosticFields,
        'sysrootRef',
        JsonString(FDiagnostics[Index].SysrootRef)
      );
    if FDiagnostics[Index].ResolvedPath <> '' then
      AppendJsonField(
        DiagnosticFields,
        'resolvedPath',
        JsonString(FDiagnostics[Index].ResolvedPath)
      );
    if FDiagnostics[Index].PrimaryArtifactPath <> '' then
    begin
      ArtifactFields := '';
      AppendJsonField(
        ArtifactFields,
        'kind',
        JsonString(FDiagnostics[Index].PrimaryArtifactKind)
      );
      AppendJsonField(
        ArtifactFields,
        'path',
        JsonString(FDiagnostics[Index].PrimaryArtifactPath)
      );
      AppendJsonField(
        DiagnosticFields,
        'primaryArtifact',
        '{' + ArtifactFields + '}'
      );
    end;
    if FDiagnostics[Index].HasExitCode then
      AppendJsonField(
        DiagnosticFields,
        'exitCode',
        IntToStr(FDiagnostics[Index].ExitCode)
      );
    AppendJsonField(
      DiagnosticFields,
      'message',
      JsonString(FDiagnostics[Index].MessageText)
    );
    if FDiagnostics[Index].Payload.Kind <> dpkNone then
    begin
      StructuredFields := '';
      case FDiagnostics[Index].Payload.Kind of
        dpkWrongArgumentCount:
        begin
          AppendJsonField(StructuredFields, 'kind', JsonString('wrong-argument-count'));
          AppendJsonField(StructuredFields, 'expectedCount',
            IntToStr(FDiagnostics[Index].Payload.ExpectedCount));
          AppendJsonField(StructuredFields, 'actualCount',
            IntToStr(FDiagnostics[Index].Payload.ActualCount));
        end;
        dpkTypeMismatch:
        begin
          AppendJsonField(StructuredFields, 'kind', JsonString('type-mismatch'));
          AppendJsonField(StructuredFields, 'expectedType',
            JsonString(FDiagnostics[Index].Payload.ExpectedType));
          AppendJsonField(StructuredFields, 'actualType',
            JsonString(FDiagnostics[Index].Payload.ActualType));
          AppendJsonField(StructuredFields, 'argIndex',
            IntToStr(FDiagnostics[Index].Payload.ArgIndex));
        end;
        dpkOverloadCandidates:
        begin
          AppendJsonField(StructuredFields, 'kind', JsonString('overload-candidates'));
          CandidateArray := '';
          if FDiagnostics[Index].Payload.Candidates <> nil then
            for CI := 0 to SizeInt(FDiagnostics[Index].Payload.Candidates.Count) - 1 do
            begin
              if CI > 0 then
                CandidateArray := CandidateArray + ',';
              CandidateFields := '';
              AppendJsonField(CandidateFields, 'name',
                JsonString(FDiagnostics[Index].Payload.Candidates[SizeUInt(CI)].Name));
              AppendJsonField(CandidateFields, 'paramCount',
                IntToStr(FDiagnostics[Index].Payload.Candidates[SizeUInt(CI)].ParamCount));
              AppendJsonField(CandidateFields, 'mismatchReason',
                JsonString(FDiagnostics[Index].Payload.Candidates[SizeUInt(CI)].MismatchReason));
              CandidateArray := CandidateArray + '{' + CandidateFields + '}';
            end;
          AppendJsonField(StructuredFields, 'candidates', '[' + CandidateArray + ']');
        end;
      end;
      AppendJsonField(DiagnosticFields, 'structured', '{' + StructuredFields + '}');
    end;
    if (FDiagnostics[Index].RelatedInformation <> nil) and
      (FDiagnostics[Index].RelatedInformation.Count > 0) then
    begin
      RelatedArray := '';
      for RI := 0 to SizeInt(FDiagnostics[Index].RelatedInformation.Count) - 1 do
      begin
        if RI > 0 then
          RelatedArray := RelatedArray + ',';
        RIFields := '';
        AppendJsonField(RIFields, 'message',
          JsonString(FDiagnostics[Index].RelatedInformation[SizeUInt(RI)].Message));
        if FDiagnostics[Index].RelatedInformation[SizeUInt(RI)].Span.FileId > 0 then
        begin
          AppendJsonField(RIFields, 'fileId',
            IntToStr(FDiagnostics[Index].RelatedInformation[SizeUInt(RI)].Span.FileId));
          AppendJsonField(RIFields, 'byteOffset',
            IntToStr(FDiagnostics[Index].RelatedInformation[SizeUInt(RI)].Span.ByteSpan.Offset));
        end;
        RelatedArray := RelatedArray + '{' + RIFields + '}';
      end;
      AppendJsonField(DiagnosticFields, 'relatedInformation', '[' + RelatedArray + ']');
    end;
    if (FDiagnostics[Index].SuggestedFixes <> nil) and
      (FDiagnostics[Index].SuggestedFixes.Count > 0) then
    begin
      FixArray := '';
      for FI := 0 to SizeInt(FDiagnostics[Index].SuggestedFixes.Count) - 1 do
      begin
        if FI > 0 then
          FixArray := FixArray + ',';
        FixFields := '';
        AppendJsonField(FixFields, 'description',
          JsonString(FDiagnostics[Index].SuggestedFixes[SizeUInt(FI)].Description));
        AppendJsonField(FixFields, 'replacementText',
          JsonString(FDiagnostics[Index].SuggestedFixes[SizeUInt(FI)].ReplacementText));
        FixArray := FixArray + '{' + FixFields + '}';
      end;
      AppendJsonField(DiagnosticFields, 'suggestedFixes', '[' + FixArray + ']');
    end;
    Result := Result + '{' + DiagnosticFields + '}';
  end;
  Result := Result + ']';
end;

function TDiagnosticsSink.Summary: string;
begin
  if (FDiagnostics = nil) or (FDiagnostics.Count = 0) then
    Exit('none');

  Result := FDiagnostics.Last.Code;
end;

end.
