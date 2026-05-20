{
  lex_bench — minimum-throughput benchmark for np_lexer.

  Usage:
    lex_bench <path-to-source.pas> <min-mb-per-sec>

  Reads the source file once, then lexes it repeatedly until
  total bytes processed reach 16 MiB. Reports wall-clock time
  and computed MB/s (1 MB = 1_000_000 bytes for human-readable
  numbers). Exits 0 if measured MB/s >= min-mb-per-sec, else 1
  with a diagnostic line on stderr.

  Output (stdout):
    lex-bench-source-bytes=<n>
    lex-bench-iterations=<n>
    lex-bench-total-bytes=<n>
    lex-bench-elapsed-ms=<n>
    lex-bench-mb-per-sec=<floored-int>
    lex-bench-min-mb-per-sec=<arg>
    lex-bench-status=pass|fail
}
program lex_bench;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils, np_lexer;

const
  TARGET_BYTES: Int64 = 16 * 1024 * 1024;

procedure Die(const AMsg: string; const AExitCode: LongInt);
begin
  Writeln(StdErr, 'lex_bench: ', AMsg);
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
  Code: Integer;
begin
  if ParamCount <> 2 then
    Die('usage: lex_bench <path-to-source.pas> <min-mb-per-sec>', 2);
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
    Lex.Free;
    Inc(Iterations);
    TotalBytes := TotalBytes + Length(Source);
  end;
  EndTime := Now;

  ElapsedMs := MilliSecondsBetween(EndTime, StartTime);
  if ElapsedMs <= 0 then
    ElapsedMs := 1;
  MBPerSec := (TotalBytes * 1000) div (1000000 * ElapsedMs);

  Writeln('lex-bench-source-bytes=', Length(Source));
  Writeln('lex-bench-iterations=', Iterations);
  Writeln('lex-bench-total-bytes=', TotalBytes);
  Writeln('lex-bench-elapsed-ms=', ElapsedMs);
  Writeln('lex-bench-mb-per-sec=', MBPerSec);
  Writeln('lex-bench-min-mb-per-sec=', MinMBPerSec);

  if MBPerSec >= MinMBPerSec then
  begin
    Writeln('lex-bench-status=pass');
    Halt(0);
  end
  else
  begin
    Writeln('lex-bench-status=fail');
    Writeln(StdErr, 'lex_bench: throughput ', MBPerSec,
      ' MB/s below minimum ', MinMBPerSec, ' MB/s');
    Halt(1);
  end;
end.
