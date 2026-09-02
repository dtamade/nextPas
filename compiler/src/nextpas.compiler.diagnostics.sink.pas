unit nextpas.compiler.diagnostics.sink;

{$mode objfpc}{$H+}

interface

uses
  np_diagnostics_sink;

type
  TDiagnosticsPolicy = np_diagnostics_sink.TDiagnosticsPolicy;
  TRelatedInformation = np_diagnostics_sink.TRelatedInformation;
  TRelatedInformationVec = np_diagnostics_sink.TRelatedInformationVec;
  TSuggestedFix = np_diagnostics_sink.TSuggestedFix;
  TSuggestedFixVec = np_diagnostics_sink.TSuggestedFixVec;
  TOverloadCandidate = np_diagnostics_sink.TOverloadCandidate;
  TOverloadCandidateArray = np_diagnostics_sink.TOverloadCandidateArray;
  TOverloadCandidateVec = np_diagnostics_sink.TOverloadCandidateVec;
  TDiagnosticPayloadKind = np_diagnostics_sink.TDiagnosticPayloadKind;
  TDiagnosticPayload = np_diagnostics_sink.TDiagnosticPayload;
  TDiagnosticRecord = np_diagnostics_sink.TDiagnosticRecord;
  TDiagnosticRecordVec = np_diagnostics_sink.TDiagnosticRecordVec;
  TDiagnosticByteCountResolver = np_diagnostics_sink.TDiagnosticByteCountResolver;
  TDiagnosticsSink = np_diagnostics_sink.TDiagnosticsSink;

implementation

end.
