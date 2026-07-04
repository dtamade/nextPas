program bench_fs;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.io.intf, nextpas.core.io.buffer,
  nextpas.core.fs.base, nextpas.core.fs.intf, nextpas.core.fs.stream,
  nextpas.core.fs.util, nextpas.core.platform.files.base,
  nextpas.core.platform.files, nextpas.core.platform.fs;
var GTmpDir: string; GSink: UInt64;
procedure BenchSeqWrite64KB(const ACtx: IBenchContext);
var LF: IFile; LBuf: array[0..32767] of Byte; LRem, LChunk: SizeUInt;
begin
  FillChar(LBuf[0], SizeOf(LBuf), $AA);
  LF := FsCreate(GTmpDir + '/bench_write.bin');
  LRem := 65536;
  while LRem > 0 do begin if LRem > SizeOf(LBuf) then LChunk := SizeOf(LBuf) else LChunk := LRem; LF.Write(LBuf[0], LChunk); Dec(LRem, LChunk); end;
  LF.Close; ACtx.SetBytes(65536);
end;
procedure BenchSeqRead64KB(const ACtx: IBenchContext);
var LF: IFile; LBuf: array[0..32767] of Byte; LN: SizeUInt;
begin
  LF := FsOpen(GTmpDir + '/bench_write.bin');
  repeat LN := LF.Read(LBuf[0], SizeOf(LBuf)); GSink := GSink xor UInt64(LN); until LN = 0;
  LF.Close; ACtx.SetBytes(65536);
end;
procedure BenchFileExists(const ACtx: IBenchContext);
var LB: Boolean;
begin LB := FsExists(GTmpDir + '/bench_write.bin'); GSink := GSink xor Byte(LB); end;
procedure BenchFileSize(const ACtx: IBenchContext);
var LS: Int64;
begin LS := FsFileSize(GTmpDir + '/bench_write.bin'); GSink := GSink xor UInt64(LS); end;
procedure BenchReadAll64KB(const ACtx: IBenchContext);
var LData: TBytes;
begin LData := FsReadAll(GTmpDir + '/bench_write.bin'); GSink := GSink xor UInt64(Length(LData)); ACtx.SetBytes(Length(LData)); end;
procedure BenchMmapRead64KB(const ACtx: IBenchContext);
var LM: IMmapView; LByte: Byte;
begin
  LM := FsMmap(GTmpDir + '/bench_write.bin');
  if LM <> nil then begin LByte := LM.Data[0]; GSink := GSink xor LByte; ACtx.SetBytes(LM.Size); end;
end;
var LSuite: IBenchSuite;
begin
  GTmpDir := GetTempDir; GSink := 0;
  LSuite := TBenchSuite.Create('fs');
  LSuite.Add('SeqWrite/64KB', @BenchSeqWrite64KB).Add('SeqRead/64KB', @BenchSeqRead64KB)
    .Add('FileExists', @BenchFileExists).Add('FileSize', @BenchFileSize)
    .Add('ReadAll/64KB', @BenchReadAll64KB).Add('MmapRead/64KB', @BenchMmapRead64KB);
  WriteLn(LSuite.Run.PrintToConsole);
end.
