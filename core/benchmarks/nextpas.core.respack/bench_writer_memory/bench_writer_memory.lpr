program bench_writer_memory;
{$I nextpas.core.settings.inc}
{** @desc S4 基准：writer 内存上限（INV-R10，默认 512MB）实测。
    以指定总量的合成输入过一次 ResPackBuild，报告输出尺寸与进程峰值 RSS
    （VmHWM）。用法：bench_writer_memory [SIZE_MB]，默认 512。 }
uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.os.procinfo,
  nextpas.core.text.conv,
  nextpas.core.respack;

procedure RunOnce(const ATargetBytes: SizeUInt);
var
  Chunk: TBytes;
  Entries: array of TResPackInputEntry;
  Contents: array of TBytes;
  ChunkSize, Remaining: SizeUInt;
  I, N: Integer;
  Blob: TResPackBlob;
begin
  { 单条目 8MB：条目数适中，内容缓冲占输入的绝对大头 }
  ChunkSize := SizeUInt(8) * 1024 * 1024;
  N := Integer(ATargetBytes div ChunkSize);
  SetLength(Contents, N);
  SetLength(Entries, N);
  SetLength(Chunk, SizeInt(ChunkSize));
  for I := 0 to N - 1 do
    FillChar(Chunk[0], ChunkSize, Byte(I mod 251));
  for I := 0 to N - 1 do
  begin
    SetLength(Contents[I], SizeInt(ChunkSize));
    Move(Chunk[0], Contents[I][0], ChunkSize);
    Entries[I].Path := 'chunk' + IntToStr(I) + '.bin';
    Entries[I].Data := @Contents[I][0];
    Entries[I].DataSize := ChunkSize;
    Entries[I].ModTime := 0;
  end;
  { 尾部零头：凑不满整块时用最后一块缩容 }
  Remaining := ATargetBytes - SizeUInt(N) * ChunkSize;
  if (Remaining > 0) and (N > 0) then
  begin
    SetLength(Contents[N - 1], SizeInt(Remaining));
    Entries[N - 1].DataSize := Remaining;
  end;

  WriteLn('input entries: ', Length(Entries), '  target bytes: ',
    ATargetBytes);
  WriteLn('peak rss before build: ', ProcessPeakRssBytes div 1048576, ' MB');
  Blob := ResPackBuild(Entries, ResPackDefaultOptions);
  try
    WriteLn('build ok: blob bytes = ', Blob.Size);
    WriteLn('peak rss after build : ', ProcessPeakRssBytes div 1048576, ' MB');
  finally
    ResPackFreeBlob(Blob);
  end;
end;

var
  TargetMB: Int64;
begin
  try
    TargetMB := 512;   { INV-R10 声明的上限 }
    if (ParamCount > 0) and not TryStrToInt(ParamStr(1), TargetMB) then
      TargetMB := 512;
    WriteLn('=== respack writer memory ceiling benchmark ===');
    RunOnce(SizeUInt(TargetMB) * 1024 * 1024);
    WriteLn('done.');
  except
    on E: Exception do
    begin
      WriteLn('bench: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
