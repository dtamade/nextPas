{
  sema_bench — minimum-throughput benchmark for semantic analysis pipeline.

  Usage:
    sema_bench <path-to-source.pas> <min-mb-per-sec>

  Reads the source file once, then runs the full pipeline (lex + parse + sema)
  repeatedly until total bytes processed reach 16 MiB. Reports process CPU time
  and computed MB/s. Exits 0 if measured MB/s >= min-mb-per-sec, else 1.

  Output (stdout):
    sema-bench-source-bytes=<n>
    sema-bench-iterations=<n>
    sema-bench-total-bytes=<n>
    sema-bench-timing-source=process-cpu
    sema-bench-elapsed-ms=<n>
    sema-bench-mb-per-sec=<floored-int>
    sema-bench-min-mb-per-sec=<arg>
    sema-bench-status=pass|fail
}
program sema_bench;

{$mode objfpc}{$H+}
{$UNITPATH ../../compiler/syntax}
{$UNITPATH ../../compiler/diagnostics}
{$UNITPATH ../../compiler/frontend}
{$UNITPATH ../../compiler/sema}
{$UNITPATH ../../rtl/core/base}
{$UNITPATH ../../rtl/core/text}

uses
  SysUtils, Classes,
  np_lexer, np_green_tree, np_ast_facade,
  np_diagnostics_sink, np_source_database, np_unit_graph,
  np_semantic_analyzer, np_semantic_model, np_bench_timing;

const
  TARGET_BYTES: Int64 = 16 * 1024 * 1024;

procedure Die(const AMsg: string; const AExitCode: LongInt);
begin
  Writeln(StdErr, 'sema_bench: ', AMsg);
  Halt(AExitCode);
end;

function ReadEntireFile(const APath: string): string;
var
  Stream: TFileStream;
  Bytes: TBytes;
  Len: SizeInt;
begin
  Stream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Len := Stream.Size;
    SetLength(Bytes, Len);
    if Len > 0 then
      Stream.ReadBuffer(Bytes[0], Len);
    SetLength(Result, Len);
    if Len > 0 then
      Move(Bytes[0], Result[1], Len);
  finally
    Stream.Free;
  end;
end;

var
  PathArg: string;
  MinMBPerSec: LongInt;
  Source: string;
  Iterations: LongInt;
  TotalBytes: Int64;
  StartTime, EndTime: Int64;
  ElapsedMs: Int64;
  MBPerSec: Int64;
  Lex: TLexerResult;
  Tree: TGreenTree;
  Ast: TAstFacade;
  Diag: TDiagnosticsSink;
  UnitG: TUnitGraph;
  Analyzer: TSemanticAnalyzer;
  Model: TSemanticModel;
  Code: Integer;
begin
  if ParamCount <> 2 then
    Die('usage: sema_bench <path-to-source.pas> <min-mb-per-sec>', 2);
  PathArg := ParamStr(1);
  Val(ParamStr(2), MinMBPerSec, Code);
  if Code <> 0 then
    Die('min-mb-per-sec must be an integer', 2);
  if not FileExists(PathArg) then
    Die('file not found: ' + PathArg, 2);

  Source := ReadEntireFile(PathArg);
  Iterations := 0;
  TotalBytes := 0;

  if not TryReadProcessCpuNanoseconds(StartTime) then
    Die('process CPU timer unavailable', 2);
  while TotalBytes < TARGET_BYTES do
  begin
    Lex := TLexerResult.Create(Source);
    Diag := TDiagnosticsSink.Create;
    Tree := ParseGreenTree(Lex, Diag, 1);
    Ast := TAstFacade.Create(Tree);
    UnitG := TUnitGraph.Create;
    UnitG.SetRootName(Ast.DeclaredName);
    Analyzer := TSemanticAnalyzer.Create(Ast, UnitG, Diag, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;
    Model.Free;
    Analyzer.Free;
    UnitG.Free;
    Ast.Free;
    Tree.Free;
    Diag.Free;
    Lex.Free;
    Inc(Iterations);
    TotalBytes := TotalBytes + Length(Source);
  end;
  if not TryReadProcessCpuNanoseconds(EndTime) then
    Die('process CPU timer unavailable', 2);

  ElapsedMs := ElapsedMilliseconds(StartTime, EndTime);
  MBPerSec := (TotalBytes * 1000) div (1000000 * ElapsedMs);

  Writeln('sema-bench-source-bytes=', Length(Source));
  Writeln('sema-bench-iterations=', Iterations);
  Writeln('sema-bench-total-bytes=', TotalBytes);
  Writeln('sema-bench-timing-source=', BENCH_TIMING_SOURCE);
  Writeln('sema-bench-elapsed-ms=', ElapsedMs);
  Writeln('sema-bench-mb-per-sec=', MBPerSec);
  Writeln('sema-bench-min-mb-per-sec=', MinMBPerSec);

  if MBPerSec >= MinMBPerSec then
  begin
    Writeln('sema-bench-status=pass');
    Halt(0);
  end
  else
  begin
    Writeln('sema-bench-status=fail');
    Writeln(StdErr, 'sema_bench: throughput ', MBPerSec,
      ' MB/s below minimum ', MinMBPerSec, ' MB/s');
    Halt(1);
  end;
end.
