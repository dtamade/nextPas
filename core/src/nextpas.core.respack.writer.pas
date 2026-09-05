unit nextpas.core.respack.writer;

{** @desc respack 打包器：条目 → 确定性 blob，布局单源 layout，组装复用 stream 零双驻留。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base,
  nextpas.core.respack.writer.layout;

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
  nextpas.core.respack.writer.stream;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
var
  L: TResPackLayout;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  { 单布局复用 Emit：排序/fnv/去重仅 1×，内存 Sink 经 stream 单源封装直填；布局由 stream 拥有 Clear 不丢资源。 }
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    Result := ResPackBuildLayoutBlob(AEntries, AOpts, L);
  finally
    ResPackLayoutClear(L);
  end;
end;

end.
