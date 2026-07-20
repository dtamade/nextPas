program bench_fs;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.io.intf,
  nextpas.core.fs.base, nextpas.core.fs.intf, nextpas.core.fs.stream,
  nextpas.core.fs.util;

var
  GTmpDir: string;
  GSink: UInt64;

procedure BenchSeqWrite64KB(const ACtx: IBenchContext);
var
  LF: IFile;
  LBuf: array[0..32767] of Byte;
  LRem, LChunk: SizeUInt;
begin
  FillChar(LBuf[0], SizeOf(LBuf), $AA);
  LF := FsCreate(GTmpDir + '/bench_write.bin');
  LRem := 65536;
  while LRem > 0 do
  begin
    if LRem > SizeOf(LBuf) then
      LChunk := SizeOf(LBuf)
    else
      LChunk := LRem;
    LF.Write(LBuf[0], LChunk);
    Dec(LRem, LChunk);
  end;
  LF.Close;
  ACtx.SetBytes(65536);
end;

procedure BenchSeqRead64KB(const ACtx: IBenchContext);
var
  LF: IFile;
  LBuf: array[0..32767] of Byte;
  LN: SizeUInt;
begin
  LF := FsOpen(GTmpDir + '/bench_write.bin', [fmRead]);
  repeat
    LN := LF.Read(LBuf[0], SizeOf(LBuf));
    GSink := GSink xor UInt64(LN);
  until LN = 0;
  LF.Close;
  ACtx.SetBytes(65536);
end;

procedure BenchFileExists(const ACtx: IBenchContext);
var
  LB: Boolean;
begin
  LB := FsExists(GTmpDir + '/bench_write.bin');
  GSink := GSink xor Byte(LB);
end;

procedure BenchFileSize(const ACtx: IBenchContext);
var
  LS: Int64;
begin
  LS := FsFileSize(GTmpDir + '/bench_write.bin');
  GSink := GSink xor UInt64(LS);
end;

procedure BenchReadAll64KB(const ACtx: IBenchContext);
var
  LData: TBytes;
begin
  LData := FsReadFile(GTmpDir + '/bench_write.bin');
  GSink := GSink xor UInt64(Length(LData));
  ACtx.SetBytes(Length(LData));
end;

procedure ScoreAligned;
var
  I: Integer;
  LStart: TInstant;
  LNs: Int64;
  LFile: IFile;
  LBuf64: array[0..65535] of Byte;
  LBuf1M: array of Byte;
  LPath64, LPath1M: string;
  LReadN: SizeUInt;
  LChunk: array[0..32767] of Byte;
begin
  WriteLn('=== nextpas FS scorecard aligned (host-linux) ===');
  FillChar(LBuf64[0], SizeOf(LBuf64), $AA);
  LPath64 := GTmpDir + '/align64.bin';
  LStart := TInstant.Now;
  for I := 1 to 200 do
  begin
    LFile := FsCreate(LPath64);
    LFile.Write(LBuf64[0], 65536);
    LFile.Close;
  end;
  LNs := TInstant.Now.DurationSince(LStart).AsNanoseconds;
  WriteLn('SeqWrite 64KB x200: ',
    FormatFloat('0.0', (65536.0 * 200.0) / (LNs / 1e9) / (1024.0 * 1024.0)), ' MB/s');
  LStart := TInstant.Now;
  for I := 1 to 200 do
  begin
    LFile := FsOpen(LPath64, [fmRead]);
    repeat
      LReadN := LFile.Read(LChunk[0], SizeOf(LChunk));
    until LReadN = 0;
    LFile.Close;
  end;
  LNs := TInstant.Now.DurationSince(LStart).AsNanoseconds;
  WriteLn('SeqRead  64KB x200: ',
    FormatFloat('0.0', (65536.0 * 200.0) / (LNs / 1e9) / (1024.0 * 1024.0)), ' MB/s');

  SetLength(LBuf1M, 1024 * 1024);
  for I := 0 to High(LBuf1M) do
    LBuf1M[I] := Byte(I mod 256);
  LPath1M := GTmpDir + '/align1m.bin';
  LStart := TInstant.Now;
  for I := 1 to 20 do
  begin
    LFile := FsCreate(LPath1M);
    LFile.Write(LBuf1M[0], Length(LBuf1M));
    LFile.Close;
  end;
  LNs := TInstant.Now.DurationSince(LStart).AsNanoseconds;
  WriteLn('SeqWrite 1MB x20:  ',
    FormatFloat('0.0', (1048576.0 * 20.0) / (LNs / 1e9) / (1024.0 * 1024.0)), ' MB/s');
  LStart := TInstant.Now;
  for I := 1 to 20 do
  begin
    LFile := FsOpen(LPath1M, [fmRead]);
    repeat
      LReadN := LFile.Read(LChunk[0], SizeOf(LChunk));
    until LReadN = 0;
    LFile.Close;
  end;
  LNs := TInstant.Now.DurationSince(LStart).AsNanoseconds;
  WriteLn('SeqRead  1MB x20:  ',
    FormatFloat('0.0', (1048576.0 * 20.0) / (LNs / 1e9) / (1024.0 * 1024.0)), ' MB/s');
end;

var
  LResults: IBenchResults;
begin
  GTmpDir := FsGetTempDir;
  GSink := 0;
  LResults := TBenchSuite.Create('fs')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('SeqWrite/64KB', @BenchSeqWrite64KB)
    .Add('SeqRead/64KB', @BenchSeqRead64KB)
    .Add('Meta/FileExists', @BenchFileExists)
    .Add('Meta/FileSize', @BenchFileSize)
    .Add('ReadAll/64KB', @BenchReadAll64KB)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-fs.json');
  ScoreAligned;
end.
