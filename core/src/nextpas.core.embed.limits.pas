unit nextpas.core.embed.limits;

{** @desc embed 阈值策略常量载体（L1，S6 已抽取，L0 only，inline 零拷贝，bytes.ops 单源收敛）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

const
  EMBED_INC_MAX_BLOB_BYTES = 4 * 1024 * 1024;
  EMBED_INC_DEFAULT_BYTES_PER_LINE = 16;
  RESPACK_INC_MAX_BLOB_BYTES = EMBED_INC_MAX_BLOB_BYTES;
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = EMBED_INC_DEFAULT_BYTES_PER_LINE;

type
  EResPackTooLarge = class(EResourceExhaustedError);
  EEmbedTooLarge = EResPackTooLarge;

function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;

procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;

implementation

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
      + IntToStr(UInt64(ASize)) + ' > '
      + IntToStr(UInt64(ALimit)) + ', use .pack)');
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;
begin
  EmbedRequireIncSize(ASize, ALimit);
end;

end.
