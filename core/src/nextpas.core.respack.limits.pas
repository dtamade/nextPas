unit nextpas.core.respack.limits;

{** @desc respack 嵌入/打包阈值策略兼容转发（S6 已抽取至独立策略模块 nextpas.core.embed.limits）。
  本单元仅为兼容 re-export，策略单源已收敛至 embed.limits（L1 独立模块，供其他嵌入载体复用）；
  常量/函数均 inline 零拷贝转发至 embed.limits 单源（无堆分配，单次比较+转发），与 writer 侧
  GetMem(Total)单次分配+分段 BytesCopy 文本组装同源收敛于 bytes.ops。
  owner 边界：仅依赖 L1 embed.limits（自身仅依赖 L0 base/exception，不触 FS/writer/dirsource），业务以
  CONTRACT 为准、缺能力反哺 mem.memory_map。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.embed.limits;

const
  RESPACK_INC_MAX_BLOB_BYTES = nextpas.core.embed.limits.RESPACK_INC_MAX_BLOB_BYTES;
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.embed.limits.RESPACK_INC_DEFAULT_BYTES_PER_LINE;
  EMBED_INC_MAX_BLOB_BYTES = nextpas.core.embed.limits.EMBED_INC_MAX_BLOB_BYTES;
  EMBED_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.embed.limits.EMBED_INC_DEFAULT_BYTES_PER_LINE;

{ 取生效阈值：0 取默认 4MiB，便于 TResPackIncOptions.MaxBlobBytes 未显式配置时零值即默认 }
function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;

{ 阈值前置拒绝单源：>Limit 即 EResPackTooLarge，避免超大临时分配；inline 零拷贝转发至 embed.limits 单源 }
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;
procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;

implementation

function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.embed.limits.ResPackEffectiveIncLimit(AConfigured);
end;

function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.embed.limits.EmbedEffectiveIncLimit(AConfigured);
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;
begin
  nextpas.core.embed.limits.ResPackRequireIncSize(ASize, ALimit);
end;

procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;
begin
  nextpas.core.embed.limits.EmbedRequireIncSize(ASize, ALimit);
end;

end.
