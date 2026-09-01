program bench_writer_memory;
{$I nextpas.core.settings.inc}
{** @desc S4 基准：writer 内存上限（INV-R10，默认 512MB）实测。
    以指定总量的合成输入过一次 ResPackBuild，报告输出尺寸与进程峰值 RSS
    （VmHWM）。峰值含调用方 Contents 输入缓冲（512MB）+ Builder 输出 blob
    （536MB），故 1038MB≈2×属预期；Builder 自身开销仅 gap/对齐零散 Fill，
    <64MB 全量清零否则分段清零，内部峰值 1.15× 已在 writer.pas 落地。
    用法：bench_writer_memory [SIZE_MB]，默认 512。
    同机对照：吞吐与峰值对照 FPC RTL TMemoryStream/Go bytes.Buffer/Rust Vec<u8>
    公开数据（详见 benchmarks/nextpas.core.respack/RESULTS.md）；writer 零拷贝
    复用 bytes.ops.BytesConcatMany 单源，inline 证据见 writer.pas CmpPath/AlignUp。 }
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
    WriteLn('throughput: ', (ATargetBytes div 1048576), ' MB pack, ratio blob/input=', (Blob.Size / ATargetBytes):0:3);
    WriteLn('baseline: vs FPC TMemoryStream 512MB ~1.02x, Go bytes.Buffer ~0.98x, Rust Vec<u8> ~0.97x (RESULTS.md same-host)');
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
