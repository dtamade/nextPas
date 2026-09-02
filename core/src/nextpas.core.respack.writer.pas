unit nextpas.core.respack.writer;

{** @desc respack 打包器：条目列表 → 单个确定性 blob。
  流程见 FORMAT.md「Writer 构造流程」；不变量见 CONTRACT.md INV-R5/R6/R8/R10。
  布局计算单源于 nextpas.core.respack.writer.layout（首遍排序/去重/对齐），
  组装复用 writer.stream 分段零拷贝管线达 ~1×+头零双驻留（RESULTS 512MiB 峰值 1038MiB→~526MiB）。 }

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
  { 复用 writer.stream 分段零拷贝管线：Total 预取零分配 + 分段 AWrite 直填最终 Buf，
    布局/头单源于 writer.layout/builder，间隙零填 4K 零页、data/digest 零拷贝 BytesCopy 单源 inline，
    峰值 ~1×+头（512MiB 由 2×+头 1038MiB 降至 ~526MiB），确定性 INV-R5 同流式；异常 FreeMem 不丢资源。 }
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
    end;
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
