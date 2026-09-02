unit nextpas.core.respack.limits;

{** @desc respack 嵌入/打包阈值策略兼容转发（S6 已抽取至独立策略模块 nextpas.core.embed.limits）。
  本单元仅为兼容 re-export，策略单源已收敛至 embed.limits（L1 独立模块，供其他嵌入载体复用）；
  常量/函数均 inline 零拷贝转发至 embed.limits 单源（无堆分配，单次比较+转发），与 writer 侧
  GetMem(Total)单次分配+分段 BytesCopy 文本组装同源收敛于 bytes.ops。
  owner 边界：仅依赖 L1 embed.limits（自身仅依赖 L0 base/exception，不触 FS/writer/dirsource），业务以
  CONTRACT 为准、缺能力反哺 mem.memory_map。
  收敛说明：过渡期 EMBED_/RESPACK_ 双重别名已收敛——本单元仅保留 RESPACK_ 域别名，
  直接转发至 embed.limits 规范 EMBED_* 单源（消除 RESPACK->RESPACK 二重转发冗余），
  EMBED_ 域请直接使用 nextpas.core.embed / nextpas.core.embed.limits。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.embed.limits,
  nextpas.core.respack.base,
  nextpas.core.text.number;

const
  RESPACK_INC_MAX_BLOB_BYTES = nextpas.core.embed.limits.EMBED_INC_MAX_BLOB_BYTES;
  RESPACK_INC_DEFAULT_BYTES_PER_LINE = nextpas.core.embed.limits.EMBED_INC_DEFAULT_BYTES_PER_LINE;

{ 取生效阈值：0 取默认 4MiB，便于 TResPackIncOptions.MaxBlobBytes 未显式配置时零值即默认 }
function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;

{ 阈值前置拒绝单源：>Limit 即 EResPackTooLarge，避免超大临时分配；inline 零拷贝，text.number.UIntToBuffer+bytes.ops.BytesCopy 单源，owner 边界 respack.base 独立异常 }
procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;

implementation

function ResPackEffectiveIncLimit(const AConfigured: SizeUInt): SizeUInt; inline;
begin
  Result := nextpas.core.embed.limits.EmbedEffectiveIncLimit(AConfigured);
end;

procedure ResPackRequireIncSize(const ASize, ALimit: SizeUInt); inline;
var
  LBufS: array[0..20] of AnsiChar;
  LBufL: array[0..20] of AnsiChar;
  LLenS, LLenL: Int32;
  SStr, LStr: string;
begin
  if ASize > ALimit then
  begin
    { text.number.UIntToBuffer 单源 + bytes.ops.BytesCopy 单源 inline 零拷贝，与 embed.limits 同源，owner 边界 respack.base EResPackTooLarge，避免 EResPackTooLarge 重复定义越权 }
    LLenS := UIntToBuffer(UInt64(ASize), @LBufS[0]);
    LLenL := UIntToBuffer(UInt64(ALimit), @LBufL[0]);
    SetLength(SStr, LLenS);
    if LLenS > 0 then
      BytesCopy(PAnsiChar(SStr), @LBufS[0], SizeUInt(LLenS));
    SetLength(LStr, LLenL);
    if LLenL > 0 then
      BytesCopy(PAnsiChar(LStr), @LBufL[0], SizeUInt(LLenL));
    raise EResPackTooLarge.Create('respack.embed: blob too large for .inc ('
      + SStr + ' > ' + LStr + ', use .pack)');
  end;
end;

end.
