unit nextpas.core.respack.writer;

{** @desc respack 打包器：条目 → 确定性 blob，布局单源 layout，组装复用 stream 零双驻留。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;

implementation

uses
  nextpas.core.respack.writer.stream;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
begin
  { 内存组装单源于 stream.ResPackBuildBlobFromEntries：Compute 1× + 直排 + Clear，零重复序列。 }
  Result := ResPackBuildBlobFromEntries(AEntries, AOpts);
end;

end.
