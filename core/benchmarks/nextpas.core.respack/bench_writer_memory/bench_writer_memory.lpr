program bench_writer_memory;
{$I nextpas.core.settings.inc}
{** @desc S4 基准：writer 内存上限（INV-R10，默认 512MB）实测。
    以指定总量的合成输入过一次 ResPackBuild，报告输出尺寸与进程峰值 RSS
    （VmHWM）。峰值含调用方 Contents 输入缓冲（512MB）+ Builder 输出 blob
    （536MB），故 1038MB≈2×属预期；Builder 自身开销仅 gap/对齐零散 Fill，
    <64MB 全量清零否则分段清零，内部峰值 1.15× 已在 writer.pas 落地。
    用法：bench_writer_memory [SIZE_MB]，默认 512。
    同机对照：FPC RTL TMemoryStream（本程序内先跑，VmHWM 精确峰值）；
    Go bytes.Buffer / Rust Vec<u8> 见 compare_go/compare_rust（端到端同口径，
    详见 benchmarks/nextpas.core.respack/RESULTS.md）；writer 零拷贝
    复用 bytes.ops.BytesConcatMany 单源，inline 证据见 writer.pas CmpPath/AlignUp。 }
uses
  Classes,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.os.procinfo,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.respack;

{ FPC 同机对照：同批输入逐块 WriteBuffer 进 TMemoryStream（调用方持有输入，
  与 packer 同口径），计时+RSS 直打。Classes 只为该对照组存在（servevfs/
  embed_startup 同先例），零拷贝主体仍走 owner 单源。 }
procedure RunFpcBaseline(const AContents: array of TBytes);
var
  MS: TMemoryStream;
  I: Integer;
  Total: SizeUInt;
  T0, T1: QWord;
begin
  Total := 0;
  for I := 0 to Length(AContents) - 1 do
    Total := Total + SizeUInt(Length(AContents[I]));
  MS := TMemoryStream.Create;
  try
    T0 := GetTickCount64;
    for I := 0 to Length(AContents) - 1 do
      if Length(AContents[I]) > 0 then
        MS.WriteBuffer(AContents[I][0], Length(AContents[I]));
    T1 := GetTickCount64;
    WriteLn('fpc-memstream: ', MS.Size, ' bytes in ', (T1 - T0),
      ' ms, rss ', ProcessPeakRssBytes div 1048576, ' MB');
  finally
    MS.Free;
  end;
end;

procedure RunOnce(const ATargetBytes: SizeUInt);
var
  Chunk: TBytes;
  Entries: array of TResPackInputEntry;
  Contents: array of TBytes;
  ChunkSize, Remaining: SizeUInt;
  I, N: Integer;
  Blob: TResPackBlob;
  T0, T1: QWord;
  FpcPeakMB, PackPeakMB: Int64;
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
  { 先跑 FPC 对照：此前无更大分配，此时 VmHWM 即 FPC 作业精确峰值；
    随后 packer 峰值取 max，两数齐全可逐项比（任一相等即另一方不超）。 }
  RunFpcBaseline(Contents);
  FpcPeakMB := ProcessPeakRssBytes div 1048576;
  T0 := GetTickCount64;
  Blob := ResPackBuild(Entries, ResPackDefaultOptions);
  T1 := GetTickCount64;
  try
    WriteLn('build ok: blob bytes = ', Blob.Size, ' in ', (T1 - T0), ' ms');
    PackPeakMB := ProcessPeakRssBytes div 1048576;
    WriteLn('peak rss after build : ', PackPeakMB, ' MB');
    WriteLn('throughput: ', (ATargetBytes div 1048576), ' MB pack, ratio blob/input=', (Blob.Size / ATargetBytes):0:3);
    { 单边门限：VmHWM 只增不减，packer 真峰值被 FPC 峰值掩盖时此门宽松（只抓总体膨胀，
      不抓 packer 缩小——缩小不是回归）。packer 相真实超 FPC 15% 即红灯。 }
    if PackPeakMB > (FpcPeakMB * 115) div 100 then
      raise Exception.Create('bench: packer peak RSS exceeds FPC peak by >15%');
    WriteLn('gate: packer peak ', PackPeakMB, ' MB within 1.15x FPC peak ', FpcPeakMB, ' MB');
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
