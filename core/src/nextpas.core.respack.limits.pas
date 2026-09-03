unit nextpas.core.respack.limits;

{** @desc respack 阈值兼容转发：常量/函数 inline 转发至 embed.limits 单源（L1，4MiB，仅 RESPACK_ 别名）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.embed.limits,
  nextpas.core.respack.base;

const
  RESPACK_INC_MAX_BLOB_BYTES = nextpas.core.embed.limits.EMBED_INC_MAX_BLOB_BYTES;
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.embed.limits.EMBED_INC_DEFAULT_BYTES_PER_LINE;

function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt);

implementation

function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.embed.limits.EmbedEffectiveIncLimit(AConfigured);
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt);
begin
  try
    nextpas.core.embed.limits.EmbedRequireIncSize(ASize, ALimit);
  except
    on LRespackWrapEx: EEmbedTooLarge do
      raise EResPackTooLarge.Create(LRespackWrapEx.Message);
  end;
end;

end.
