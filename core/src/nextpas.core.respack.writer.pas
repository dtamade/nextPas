unit nextpas.core.respack.writer;

{** @desc respack 打包器：条目 → 确定性 blob，布局单源 layout，组装复用 stream 零双驻留。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base;

type
  { 排序后的内部视图，供测试断言布局使用 }
  TResPackLayoutInfo = record
    BlobTotal: UInt64;
    StringTableBase: UInt64;
    FirstDataOffset: UInt64;
  end;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.respack.writer.stream;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
var
  Total: UInt64;
  Buf: PByte;
  Off: SizeUInt;
  Sink: TResPackWriteProc;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 复用 stream 分段管线：Total 预取 + 分段直填 Buf，~1×+头（512MiB 1038→526MiB），INV-R5 同流式；Sink 单闭包分配/Build（~40B，相对 Total 可忽略），异常 FreeMem 不丢资源。 }
  Total := ResPackBuildStreamSize(AEntries, AOpts);
  if Total = 0 then Exit;
  if Total > High(SizeUInt) then
    raise EResPackTooLarge.Create('respack: blob too large for host SizeUInt');
  GetMem(Buf, SizeUInt(Total));
  Off := 0;
  Sink :=
    procedure(const AData: PByte; const ASize: SizeUInt)
    begin
      if ASize = 0 then Exit;
      BytesCopy(Buf + Off, AData, ASize);
      Inc(Off, ASize);
    end; { 单闭包/Build，堆分配一次，零每块分配 }
  try
    ResPackBuildStream(AEntries, AOpts, Sink);
    if Off <> SizeUInt(Total) then
      raise EResPackError.Create('respack: stream size mismatch');
    Result.Data := Buf;
    Result.Size := SizeUInt(Total);
    Result.Owned := True;
    Buf := nil;
  except
    if Buf <> nil then
      FreeMem(Buf);
    raise;
  end;
end;

end.
