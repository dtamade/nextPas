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
  nextpas.core.respack.writer.layout,
  nextpas.core.respack.writer.stream;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
var
  L: TResPackLayout;
  Total: UInt64;
  Buf: PByte;
  Off: SizeUInt;
  Sink: TResPackWriteProc;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 单布局复用 Emit：排序/fnv/去重仅 1×，BytesCopy 单源零拷贝直填；Sink 单闭包/Build，异常 FreeMem+Clear 不丢资源。 }
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    Total := L.Total;
    if Total = 0 then Exit;
    if Total > High(SizeUInt) then
      raise EResPackTooLarge.Create('respack: blob too large for host SizeUInt');
    Buf := nil;
    GetMem(Buf, SizeUInt(Total));
    Off := 0;
    Sink :=
      procedure(const AData: PByte; const ASize: SizeUInt)
      begin
        if ASize = 0 then Exit;
        BytesCopy(Buf + Off, AData, ASize);
        Inc(Off, ASize);
      end; { 单闭包/Build，堆分配一次，零每块分配；BytesCopy inline 快道 }
    try
      ResPackEmitLayout(AEntries, AOpts, L, Sink);
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
  finally
    ResPackLayoutClear(L);
  end;
end;

end.
