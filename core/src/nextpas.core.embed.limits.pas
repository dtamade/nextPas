unit nextpas.core.embed.limits;

{** @desc 嵌入载体阈值策略独立模块（L1，S6 已落地抽取）。
  经验阈值 typed const 载体 <4MiB 集中于此，消除 embed 内两处硬编码重复；
  ResPackRequireIncSize 为前置拒绝单源（inline 零拷贝），与 writer 侧
  GetMem(Total)单次分配+分段 BytesCopy 文本组装同源收敛于 bytes.ops。
  原 respack.limits 已收敛至此独立策略模块，供 respack/其他嵌入载体复用；
  本单元为策略单源（L1，仅依赖 L0 base/exception，不触 FS/writer/dirsource），
  respack.limits 仅为兼容转发。
  业务以 CONTRACT 为准、缺能力反哺 mem.memory_map。
  性能：取阈值/前置拒绝均 inline 零拷贝（无堆分配，单次比较+转发），与 bytes.ops 单源收敛。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  EMBED_INC_MAX_BLOB_BYTES = 4 * 1024 * 1024; { 经验阈值：typed const 载体 <4MiB，大包走 .pack；提前拒绝避免超大临时分配 }
  EMBED_INC_DEFAULT_BYTES_PER_LINE = 16;
  { 兼容别名：respack 域历史名称，单源于 EMBED_*，供存量调用方平滑迁移 }
  RESPACK_INC_MAX_BLOB_BYTES = EMBED_INC_MAX_BLOB_BYTES;
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = EMBED_INC_DEFAULT_BYTES_PER_LINE;

{ 取生效阈值：0 取默认 4MiB，便于 TResPackIncOptions.MaxBlobBytes 未显式配置时零值即默认 }
function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;

{ 阈值前置拒绝单源：>Limit 即 EResPackTooLarge，避免超大临时分配；inline 零拷贝转发至 exception 单源 }
procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.respack.base,
  nextpas.core.text.conv;

function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  if AConfigured = 0 then
    Result := EMBED_INC_MAX_BLOB_BYTES
  else
    Result := AConfigured;
end;

function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  Result := EmbedEffectiveIncLimit(AConfigured);
end;

procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;
begin
  if ASize > ALimit then
    raise EResPackTooLarge.Create('respack.embed: blob too large for .inc ('
      + nextpas.core.text.conv.IntToStr(SizeInt(ASize)) + ' > '
      + nextpas.core.text.conv.IntToStr(SizeInt(ALimit)) + ', use .pack)');
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;
begin
  EmbedRequireIncSize(ASize, ALimit);
end;

end.
