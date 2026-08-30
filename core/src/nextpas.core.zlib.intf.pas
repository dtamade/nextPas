unit nextpas.core.zlib.intf;

{**
 * @desc nextpas.core.zlib.intf - zlib 编解码接口契约
 *
 * 依赖 base 的 TZlibLevel/EZlibError，保持 base <- intf 方向。
 * IZlibEncoder/Decoder 暴露 Encode/Decode + Adler32，接口粒度与
 * compress.intf 的 ICompressWriter/IDecompressReader 对齐，零 paszlib
 * 拷贝；实现层再衔接 compress.zlib.ffi 或纯 Pascal 后端。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.zlib.base;

type
  { IZlibEncoder - zlib 流编码器（RFC1950 包装，头+deflate+Adler） }
  IZlibEncoder = interface
    ['{A1B2C3D4-E5F6-4A7B-9C8D-010203040501}']
    function Encode(const AData: TBytes): TBytes;
    function EncodeWithLevel(const AData: TBytes;
      const ALevel: TZlibLevel): TBytes;
    function Adler32(const AData: TBytes): LongWord;
    function Adler32Update(AAdler: LongWord; const AData: Pointer;
      ALen: SizeUInt): LongWord;
  end;

  { IZlibDecoder - zlib 流解码器，默认校验 Adler，超限抛 EZlibError }
  IZlibDecoder = interface
    ['{A1B2C3D4-E5F6-4A7B-9C8D-010203040502}']
    function Decode(const AData: TBytes): TBytes;
    function DecodeWithLimit(const AData: TBytes;
      const AMaxOutputSize: SizeUInt): TBytes;
    function Adler32(const AData: TBytes): LongWord;
    function Adler32Update(AAdler: LongWord; const AData: Pointer;
      ALen: SizeUInt): LongWord;
  end;

{ 独立 Adler-32 辅助：无状态复用，供流式与一次性路径共享 }
function ZlibAdler32(const AData: TBytes): LongWord;
function ZlibAdler32Of(const ABuf; ALen: SizeUInt): LongWord;
function ZlibAdler32Update(AAdler: LongWord; const AData: Pointer;
  ALen: SizeUInt): LongWord;

implementation

function ZlibAdler32(const AData: TBytes): LongWord;
begin
  if Length(AData) = 0 then
    Result := ZLIB_ADLER_INIT
  else
    Result := ZlibAdlerUpdate(ZLIB_ADLER_INIT, @AData[0], SizeUInt(Length(AData)));
end;

function ZlibAdler32Of(const ABuf; ALen: SizeUInt): LongWord;
begin
  if ALen = 0 then
    Result := ZLIB_ADLER_INIT
  else
    Result := ZlibAdlerUpdate(ZLIB_ADLER_INIT, @ABuf, ALen);
end;

function ZlibAdler32Update(AAdler: LongWord; const AData: Pointer;
  ALen: SizeUInt): LongWord;
begin
  Result := ZlibAdlerUpdate(AAdler, AData, ALen);
end;

end.
