unit nextpas.core.respack.limits;

{** @desc respack 阈值域适配：阈值单源于 embed.limits，域错误与 Op/Path 上下文归本单元。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.embed.limits,
  nextpas.core.respack.base;

const
  { 编译期别名，无运行时开销。 }
  RESPACK_INC_MAX_BLOB_BYTES = nextpas.core.embed.limits.EMBED_INC_MAX_BLOB_BYTES;
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.embed.limits.EMBED_INC_DEFAULT_BYTES_PER_LINE;

{ 有效阈值 inline 转发单源，零额外调用。 }
function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
{ 域校验：转译为 EResPackTooLarge 并附 Op/Path；含 try..except 故不 inline。 }
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); overload;
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt; const AOp, APath: string); overload;

implementation

function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.embed.limits.EmbedEffectiveIncLimit(AConfigured);
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); overload;
begin
  ResPackRequireIncSize(ASize, ALimit, 'respack.embed', '');
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt; const AOp, APath: string); overload;
begin
  try
    nextpas.core.embed.limits.EmbedRequireIncSize(ASize, ALimit);
  except
    on LRespackWrapEx: EEmbedTooLarge do
      raise EResPackTooLarge.CreateCtx(AOp, APath, LRespackWrapEx.Message);
  end;
end;

end.
