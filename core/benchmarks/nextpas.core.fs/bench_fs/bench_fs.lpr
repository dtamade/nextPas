program bench_fs;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.io.intf,
  nextpas.core.io.buffer,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.stream,
  nextpas.core.fs.util;

var
  GTmpDir: string;

procedure Bench(const AName: string; const ABytes: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
  LMBps: Double;
begin
  LNs := AElapsed.AsNanoseconds;
  if LNs > 0 then
    LMBps := (ABytes / (1024.0 * 1024.0)) / (LNs / 1000000000.0)
  else
    LMBps := 0;
  WriteLn(Format('  %-35s %10d bytes  %8.2f ms  %8.1f MB/s',
    [AName, ABytes, LNs / 1000000.0, LMBps]));
end;

procedure BenchSeqWrite(const ASize: SizeUInt);
var
  LF: IFile;
  LBuf: array[0..32767] of Byte;
  LRemaining, LChunk: SizeUInt;
  LStart: TInstant;
begin
  FillChar(LBuf[0], SizeOf(LBuf), $AA);
  LF := FsCreate(GTmpDir + '/bench_write.bin');
  LStart := TInstant.Now;
  LRemaining := ASize;
  while LRemaining > 0 do
  begin
    if LRemaining > SizeOf(LBuf) then
      LChunk := SizeOf(LBuf)
    else
      LChunk := LRemaining;
    LF.Write(LBuf[0], LChunk);
    Dec(LRemaining, LChunk);
  end;
  LF.Close;
  Bench('SeqWrite ' + IntToStr(ASize div 1024) + 'KB', Int64(ASize),
    LStart.Elapsed);
end;

procedure BenchSeqRead(const ASize: SizeUInt);
var
  LF: IFile;
  LBuf: array[0..32767] of Byte;
  LN: SizeUInt;
  LTotal: Int64;
  LStart: TInstant;
begin
  LF := FsOpen(GTmpDir + '/bench_write.bin', [fmRead]);
  LStart := TInstant.Now;
  LTotal := 0;
  repeat
    LN := LF.Read(LBuf[0], SizeOf(LBuf));
    Inc(LTotal, Int64(LN));
  until LN = 0;
  LF.Close;
  Bench('SeqRead ' + IntToStr(ASize div 1024) + 'KB', LTotal,
    LStart.Elapsed);
end;

procedure BenchReadFile(const ASize: SizeUInt);
var
  LData: TBytes;
  LStart: TInstant;
begin
  LStart := TInstant.Now;
  LData := FsReadFile(GTmpDir + '/bench_write.bin');
  Bench('ReadFile ' + IntToStr(ASize div 1024) + 'KB', Int64(Length(LData)),
    LStart.Elapsed);
end;

procedure BenchBufRead(const ASize: SizeUInt);
var
  LF: IFile;
  LBR: IReader;
  LBuf: array[0..32767] of Byte;
  LN: SizeUInt;
  LTotal: Int64;
  LStart: TInstant;
begin
  LF := FsOpen(GTmpDir + '/bench_write.bin', [fmRead]);
  LBR := CreateBufferedReader(LF as IReader, 4096);
  LStart := TInstant.Now;
  LTotal := 0;
  repeat
    LN := LBR.Read(LBuf[0], SizeOf(LBuf));
    Inc(LTotal, Int64(LN));
  until LN = 0;
  Bench('BufRead(4KB) ' + IntToStr(ASize div 1024) + 'KB', LTotal,
    LStart.Elapsed);
end;

procedure BenchCopyFile;
var
  LStart: TInstant;
  LCopied: Int64;
begin
  LStart := TInstant.Now;
  LCopied := FsCopyFile(GTmpDir + '/bench_write.bin', GTmpDir + '/bench_copy.bin');
  Bench('CopyFile 10240KB', LCopied, LStart.Elapsed);
end;

begin
  GTmpDir := '/tmp/nextpas_fs_bench_' + IntToStr(GetProcessID);
  ForceDirectories(GTmpDir);
  try
    WriteLn('=== nextpas.core.fs benchmarks ===');
    WriteLn;

    BenchSeqWrite(1024 * 1024);
    BenchSeqRead(1024 * 1024);
    BenchReadFile(1024 * 1024);
    BenchBufRead(1024 * 1024);

    BenchSeqWrite(10 * 1024 * 1024);
    BenchSeqRead(10 * 1024 * 1024);
    BenchReadFile(10 * 1024 * 1024);
    BenchBufRead(10 * 1024 * 1024);

    BenchCopyFile;

    WriteLn;
    WriteLn('Done.');
  finally
    // cleanup
    DeleteFile(GTmpDir + '/bench_write.bin');
    DeleteFile(GTmpDir + '/bench_copy.bin');
    RmDir(PAnsiChar(GTmpDir));
  end;
end.