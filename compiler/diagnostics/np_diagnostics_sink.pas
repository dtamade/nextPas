unit np_diagnostics_sink;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.diagnostics.sink;

type
  TDiagnosticsPolicy = nextpas.compiler.diagnostics.sink.TDiagnosticsPolicy;
  TRelatedInformation = nextpas.compiler.diagnostics.sink.TRelatedInformation;
  TRelatedInformationVec = nextpas.compiler.diagnostics.sink.TRelatedInformationVec;
  TSuggestedFix = nextpas.compiler.diagnostics.sink.TSuggestedFix;
  TSuggestedFixVec = nextpas.compiler.diagnostics.sink.TSuggestedFixVec;
  TOverloadCandidate = nextpas.compiler.diagnostics.sink.TOverloadCandidate;
  TOverloadCandidateArray = nextpas.compiler.diagnostics.sink.TOverloadCandidateArray;
  TOverloadCandidateVec = nextpas.compiler.diagnostics.sink.TOverloadCandidateVec;
  TDiagnosticPayloadKind = nextpas.compiler.diagnostics.sink.TDiagnosticPayloadKind;
  TDiagnosticPayload = nextpas.compiler.diagnostics.sink.TDiagnosticPayload;
  TDiagnosticRecord = nextpas.compiler.diagnostics.sink.TDiagnosticRecord;
  TDiagnosticRecordVec = nextpas.compiler.diagnostics.sink.TDiagnosticRecordVec;
  TDiagnosticByteCountResolver = nextpas.compiler.diagnostics.sink.TDiagnosticByteCountResolver;
  TDiagnosticsSink = nextpas.compiler.diagnostics.sink.TDiagnosticsSink;

const
  dpkNone = nextpas.compiler.diagnostics.sink.dpkNone;
  dpkTypeMismatch = nextpas.compiler.diagnostics.sink.dpkTypeMismatch;
  dpkWrongArgumentCount = nextpas.compiler.diagnostics.sink.dpkWrongArgumentCount;
  dpkOverloadCandidates = nextpas.compiler.diagnostics.sink.dpkOverloadCandidates;

function CloneOverloadCandidatesFromArray(const ACandidates: TOverloadCandidateArray): TOverloadCandidateVec;

implementation

function CloneOverloadCandidatesFromArray(const ACandidates: TOverloadCandidateArray): TOverloadCandidateVec;
begin
  Result := nextpas.compiler.diagnostics.sink.CloneOverloadCandidatesFromArray(ACandidates);
end;

end.