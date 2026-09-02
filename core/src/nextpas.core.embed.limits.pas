unit nextpas.core.embed.limits;

{** @desc embed 阈值策略常量载体（L1，S6 已抽取，L0 only，inline 零拷贝，bytes.ops 单源收敛）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.text.number;

const
  EMBED_INC_MAX_BLOB_BYTES = 4 * 1024 * 1024;
  EMBED_INC_DEFAULT_BYTES_PER_LINE = 16;

type
  EEmbedTooLarge = class(EResourceExhaustedError);

function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;

procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;

implementation

function EmbedEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  if AConfigured = 0 then
    Result := EMBED_INC_MAX_BLOB_BYTES
  else
    Result := AConfigured;
end;

procedure EmbedRequireIncSize(const ASize, ALimit: SizeUInt); inline;
var
  LBufS: array[0..20] of AnsiChar;
  LBufL: array[0..20] of AnsiChar;
  LLenS, LLenL: Int32;
  SStr, LStr: string;
begin
  if ASize > ALimit then
  begin
    { text.number.UIntToBuffer 单源（DIGIT_PAIRS 批量，零分配），显式 uses text.number；字符串物化经 bytes.ops.BytesCopy 单源 inline 零拷贝，禁裸 IntToStr 直引 }
    LLenS := UIntToBuffer(UInt64(ASize), @LBufS[0]);
    LLenL := UIntToBuffer(UInt64(ALimit), @LBufL[0]);
    SetLength(SStr, LLenS);
    if LLenS > 0 then
      BytesCopy(PAnsiChar(SStr), @LBufS[0], SizeUInt(LLenS));
    SetLength(LStr, LLenL);
    if LLenL > 0 then
      BytesCopy(PAnsiChar(LStr), @LBufL[0], SizeUInt(LLenL));
    raise EEmbedTooLarge.Create('respack.embed: blob too large for .inc ('
      + SStr + ' > ' + LStr + ', use .pack)');
  end;
end.
