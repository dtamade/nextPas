unit nextpas.core.respack.limits;

{** @desc respack 嵌入/打包阈值策略单源（S6 候选独立策略模块）。
  经验阈值 typed const 载体 <4MiB 集中于此，消除 embed 内两处硬编码重复；
  ResPackRequireIncSize 为前置拒绝单源（inline 零拷贝），与 writer 侧
  GetMem(Total)单次分配+分段 BytesCopy 文本组装同源收敛于 bytes.ops。
  owner 边界：仅依赖 L0 base/exception，不触 FS/writer/dirsource，业务以
  CONTRACT 为准、缺能力反哺 mem.memory_map。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  RESPACK_INC_MAX_BLOB_BYTES = 4 * 1024 * 1024; { 经验阈值：typed const 载体 <4MiB，大包走 .pack；提前拒绝避免超大临时分配 }
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = 16;

{ 取生效阈值：0 取默认 4MiB，便于 TResPackIncOptions.MaxBlobBytes 未显式配置时零值即默认 }
function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;

{ 阈值前置拒绝单源：>Limit 即 EResPackTooLarge，避免超大临时分配；inline 零拷贝转发至 exception 单源 }
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.respack.base,
  nextpas.core.text.conv;

function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  if AConfigured = 0 then
    Result := RESPACK_INC_MAX_BLOB_BYTES
  else
    Result := AConfigured;
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;
begin
  if ASize > ALimit then
    raise EResPackTooLarge.Create('respack.embed: blob too large for .inc ('
      + nextpas.core.text.conv.IntToStr(SizeInt(ASize)) + ' > '
      + nextpas.core.text.conv.IntToStr(SizeInt(ALimit)) + ', use .pack)');
end;

end.
