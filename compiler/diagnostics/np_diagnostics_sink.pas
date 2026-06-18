unit np_diagnostics_sink;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../../rtl/core/base}

interface

uses
  nextpas.core.text.conv, np_base_types, nextpas_json_helpers;

type
  TDiagnosticsPolicy = record
    Name: string;
    WarningAsError: Boolean;
  end;

  TRelatedInformation = record
    Span: TCoreSourceSpan;
    Message: string;
  end;

  TRelatedInformationArray = array of TRelatedInformation;

  TSuggestedFix = record
    Description: string;
    ReplacementSpan: TCoreSourceSpan;
    ReplacementText: string;
  end;

  TSuggestedFixArray = array of TSuggestedFix;

  TOverloadCandidate = record
    Name: string;
    ParamSignature: string;
    ParamCount: LongInt;
    DeclByteOffset: LongInt;
    MismatchReason: string;
  end;

  TOverloadCandidateArray = array of TOverloadCandidate;

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
    Candidates: TOverloadCandidateArray;
  end;

  TDiagnosticRecord = record
    Id: string;
    Code: string;
    Phase: string;
    Severity: string;
    PrimarySpan: TCoreSourceSpan;
    MessageText: string;
    RelatedInformation: TRelatedInformationArray;
    SuggestedFixes: TSuggestedFixArray;
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

  TDiagnosticsSink = class
  private
    FPolicy: TDiagnosticsPolicy;
    FErrorCount: LongInt;
    FWarningCount: LongInt;
    FDiagnostics: array of TDiagnosticRecord;
  public
    constructor CreateDefault;
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
  end;

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


constructor TDiagnosticsSink.CreateDefault;
begin
  inherited Create;
  FPolicy.Name := 'default';
  FPolicy.WarningAsError := False;
  FErrorCount := 0;
  FWarningCount := 0;
  SetLength(FDiagnostics, 0);
end;

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
  if Length(FDiagnostics) = 0 then
    Exit('[]');

  Result := '[';
  for Index := 0 to High(FDiagnostics) do
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
          for CI := 0 to High(FDiagnostics[Index].Payload.Candidates) do
          begin
            if CI > 0 then
              CandidateArray := CandidateArray + ',';
            CandidateFields := '';
            AppendJsonField(CandidateFields, 'name',
              JsonString(FDiagnostics[Index].Payload.Candidates[CI].Name));
            AppendJsonField(CandidateFields, 'paramCount',
              IntToStr(FDiagnostics[Index].Payload.Candidates[CI].ParamCount));
            AppendJsonField(CandidateFields, 'mismatchReason',
              JsonString(FDiagnostics[Index].Payload.Candidates[CI].MismatchReason));
            CandidateArray := CandidateArray + '{' + CandidateFields + '}';
          end;
          AppendJsonField(StructuredFields, 'candidates', '[' + CandidateArray + ']');
        end;
      end;
      AppendJsonField(DiagnosticFields, 'structured', '{' + StructuredFields + '}');
    end;
    if Length(FDiagnostics[Index].RelatedInformation) > 0 then
    begin
      RelatedArray := '';
      for RI := 0 to High(FDiagnostics[Index].RelatedInformation) do
      begin
        if RI > 0 then
          RelatedArray := RelatedArray + ',';
        RIFields := '';
        AppendJsonField(RIFields, 'message',
          JsonString(FDiagnostics[Index].RelatedInformation[RI].Message));
        if FDiagnostics[Index].RelatedInformation[RI].Span.FileId > 0 then
        begin
          AppendJsonField(RIFields, 'fileId',
            IntToStr(FDiagnostics[Index].RelatedInformation[RI].Span.FileId));
          AppendJsonField(RIFields, 'byteOffset',
            IntToStr(FDiagnostics[Index].RelatedInformation[RI].Span.ByteSpan.Offset));
        end;
        RelatedArray := RelatedArray + '{' + RIFields + '}';
      end;
      AppendJsonField(DiagnosticFields, 'relatedInformation', '[' + RelatedArray + ']');
    end;
    if Length(FDiagnostics[Index].SuggestedFixes) > 0 then
    begin
      FixArray := '';
      for FI := 0 to High(FDiagnostics[Index].SuggestedFixes) do
      begin
        if FI > 0 then
          FixArray := FixArray + ',';
        FixFields := '';
        AppendJsonField(FixFields, 'description',
          JsonString(FDiagnostics[Index].SuggestedFixes[FI].Description));
        AppendJsonField(FixFields, 'replacementText',
          JsonString(FDiagnostics[Index].SuggestedFixes[FI].ReplacementText));
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
  if Length(FDiagnostics) = 0 then
    Exit('none');

  Result := FDiagnostics[High(FDiagnostics)].Code;
end;

end.
