{
  parser_bench — minimum-throughput benchmark for np_green_tree parser.

  Usage:
    parser_bench <path-to-source.pas> <min-mb-per-sec>

  Reads the source file once, then lexes + parses it repeatedly until
  total bytes processed reach 16 MiB. Reports wall-clock time
  and computed MB/s (1 MB = 1_000_000 bytes for human-readable
  numbers). Exits 0 if measured MB/s >= min-mb-per-sec, else 1
  with a diagnostic line on stderr.

  Output (stdout):
    parser-bench-source-bytes=<n>
    parser-bench-iterations=<n>
    parser-bench-total-bytes=<n>
    parser-bench-elapsed-ms=<n>
    parser-bench-mb-per-sec=<floored-int>
    parser-bench-min-mb-per-sec=<arg>
    parser-bench-status=pass|fail
}
program parser_bench;

{$mode objfpc}{$H+}
{$UNITPATH ../../compiler/syntax}
{$UNITPATH ../../compiler/diagnostics}
{$UNITPATH ../../compiler/frontend}
{$UNITPATH ../../rtl/core/base}
{$UNITPATH ../../rtl/core/text}

uses
  SysUtils, Classes, DateUtils,
  np_lexer, np_green_tree, np_diagnostics_sink, np_source_database;

const
  TARGET_BYTES: Int64 = 16 * 1024 * 1024;

procedure Die(const AMsg: string; const AExitCode: LongInt);
begin
  Writeln(StdErr, 'parser_bench: ', AMsg);
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
  StartTime, EndTime: TDateTime;
  ElapsedMs: Int64;
  MBPerSec: Int64;
  Lex: TLexerResult;
  Tree: TGreenTree;
  Diag: TDiagnosticsSink;
  Code: Integer;
begin
  if ParamCount <> 2 then
    Die('usage: parser_bench <path-to-source.pas> <min-mb-per-sec>', 2);
  PathArg := ParamStr(1);
  Val(ParamStr(2), MinMBPerSec, Code);
  if Code <> 0 then
    Die('min-mb-per-sec must be an integer', 2);
  if not FileExists(PathArg) then
    Die('file not found: ' + PathArg, 2);

  Source := ReadEntireFile(PathArg);
  Iterations := 0;
  TotalBytes := 0;

  StartTime := Now;
  while TotalBytes < TARGET_BYTES do
  begin
    Lex := TLexerResult.Create(Source);
    Diag := TDiagnosticsSink.Create;
    Tree := ParseGreenTree(Lex, Diag, 1);
    Tree.Free;
    Diag.Free;
    Lex.Free;
    Inc(Iterations);
    TotalBytes := TotalBytes + Length(Source);
  end;
  EndTime := Now;

  ElapsedMs := MilliSecondsBetween(EndTime, StartTime);
  if ElapsedMs <= 0 then
    ElapsedMs := 1;
  MBPerSec := (TotalBytes * 1000) div (1000000 * ElapsedMs);

  Writeln('parser-bench-source-bytes=', Length(Source));
  Writeln('parser-bench-iterations=', Iterations);
  Writeln('parser-bench-total-bytes=', TotalBytes);
  Writeln('parser-bench-elapsed-ms=', ElapsedMs);
  Writeln('parser-bench-mb-per-sec=', MBPerSec);
  Writeln('parser-bench-min-mb-per-sec=', MinMBPerSec);

  if MBPerSec >= MinMBPerSec then
  begin
    Writeln('parser-bench-status=pass');
    Halt(0);
  end
  else
  begin
    Writeln('parser-bench-status=fail');
    Writeln(StdErr, 'parser_bench: throughput ', MBPerSec,
      ' MB/s below minimum ', MinMBPerSec, ' MB/s');
    Halt(1);
  end;
end.
