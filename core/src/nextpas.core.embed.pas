unit nextpas.core.embed;

{** @desc 嵌入策略独立模块门面：纯 re-export，不含逻辑（design-conventions §2）。
  L1 阈值策略单源已收敛至 nextpas.core.embed.limits，供 respack/其他嵌入载体复用；
  本门面仅 inline 转发，零拷贝、零分配，性能与稳定性同源。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.embed.limits;

const
  EMBED_INC_MAX_BLOB_BYTES = nextpas.core.embed.limits.EMBED_INC_MAX_BLOB_BYTES;
  EMBED_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.embed.limits.EMBED_INC_DEFAULT_BYTES_PER_LINE;

function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;
RESPACK_INC_MAX_BLOB_BYTES = nextpas.core.embed.limits.RESPACK_INC_MAX_BLOB_BYTES;
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.embed.limits.RESPACK_INC_DEFAULT_BYTES_PER_LINE;

function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;

implementation

function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.embed.limits.EmbedEffectiveIncLimit(AConfigured);
end;

function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.embed.limits.ResPackEffectiveIncLimit(AConfigured);
end;

procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;
begin
  nextpas.core.embed.limits.EmbedRequireIncSize(ASize, ALimit);
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;
begin
  nextpas.core.embed.limits.ResPackRequireIncSize(ASize, ALimit);
end;

end.
