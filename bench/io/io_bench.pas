program io_bench;
{$mode objfpc}{$H+}

{
  File I/O Micro-Benchmark: Pascal vs Go vs Rust

  测试顺序读/写性能，文件大小 1MB 和 10MB。
  Pascal 用 nextpas.core.fs (直接 syscall)。
  使用 nextpas.core.bench 框架。
}

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  FILE_1MB  = 1024 * 1024;
  FILE_10MB = 10 * 1024 * 1024;

var
  GData1MB, GData10MB: TBytes;
  GTextData: string;
  GTempPath: string;

procedure InitData;
var I: Integer;
begin
  SetLength(GData1MB, FILE_1MB);
  for I := 0 to FILE_1MB - 1 do
    GData1MB[I] := Byte(I and $FF);

  SetLength(GData10MB, FILE_10MB);
  for I := 0 to FILE_10MB - 1 do
    GData10MB[I] := Byte(I and $FF);

  GTempPath := '/tmp/np_io_bench.dat';

  GTextData := '';
  for I := 1 to 10000 do
    GTextData := GTextData + 'Hello, World! This is a benchmark line. '#10;
end;

function CalcChecksum(const AData: TBytes): Byte;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(AData) do
    Result := Result xor AData[I];
end;

{ === Write 1MB === }

procedure BenchWrite1MB(const ACtx: IBenchContext);
begin
  WriteFile(GTempPath, GData1MB);
  ACtx.SetBytes(FILE_1MB);
end;

{ === Read 1MB === }

procedure BenchRead1MB(const ACtx: IBenchContext);
var LRead: TBytes;
begin
  LRead := ReadFile(GTempPath);
  ACtx.SetBytes(FILE_1MB);
end;

{ === Write 10MB === }

procedure BenchWrite10MB(const ACtx: IBenchContext);
begin
  WriteFile(GTempPath, GData10MB);
  ACtx.SetBytes(FILE_10MB);
end;

{ === Read 10MB === }

procedure BenchRead10MB(const ACtx: IBenchContext);
var LRead: TBytes;
begin
  LRead := ReadFile(GTempPath);
  ACtx.SetBytes(FILE_10MB);
end;

{ === WriteFileText (string write, ~430KB) === }

procedure BenchWriteText(const ACtx: IBenchContext);
begin
  WriteFileText(GTempPath + '.txt', GTextData);
  ACtx.SetBytes(Length(GTextData));
end;

{ === ReadFileText (string read) === }

procedure BenchReadText(const ACtx: IBenchContext);
var LText: string;
begin
  LText := ReadFileText(GTempPath + '.txt');
  ACtx.SetBytes(Length(GTextData));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('=== nextPas I/O Benchmark ===');
  WriteLn('Sequential read/write');
  WriteLn('Sizes: 1MB, 10MB, ~430KB text');
  WriteLn;

  InitData;

  { Prepare files for read benchmarks }
  WriteFile(GTempPath, GData1MB);
  WriteFileText(GTempPath + '.txt', GTextData);

  LSuite := TBenchSuite.Create('IO')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(1000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Write/1MB', @BenchWrite1MB);
  LSuite.Add('Read/1MB', @BenchRead1MB);
  LSuite.Add('Write/10MB', @BenchWrite10MB);
  LSuite.Add('Read/10MB', @BenchRead10MB);
  LSuite.Add('Write/Text', @BenchWriteText);
  LSuite.Add('Read/Text', @BenchReadText);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);

  { Cleanup }
  SysUtils.DeleteFile(GTempPath);
  SysUtils.DeleteFile(GTempPath + '.txt');
end.
