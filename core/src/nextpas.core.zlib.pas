unit nextpas.core.zlib;

{**
 * @desc nextpas.core.zlib - 门面：四件套聚合（base/intf/pure/ffi）
 *
 * 依赖方向 base <- intf <- 具体实现 <- 门面；门面仅 re-export + inline
 * 转发，零逻辑。ZlibAuto 默认为纯 Pascal，FFI 可用时自动切换；
 * ZlibPure / ZlibFfi 供探针与回归直连。compress.deflate/gzip 保持薄转发
 * （仍经 paszlib），sevenz.coders 可经 IZlibEncoder/Decoder 复用本模块。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.zlib.base,
  nextpas.core.zlib.intf,
  nextpas.core.zlib.pure,
  nextpas.core.zlib.ffi;

type
  TZlibBackend = (zbAuto, zbPurePascal, zbFfi);

  TZlibLevelAlias = nextpas.core.zlib.base.TZlibLevel;
  EZlibErrorAlias = nextpas.core.zlib.base.EZlibError;
  TZlibErrorCodeAlias = nextpas.core.zlib.base.TZlibErrorCode;
  IZlibEncoderAlias = nextpas.core.zlib.intf.IZlibEncoder;
  IZlibDecoderAlias = nextpas.core.zlib.intf.IZlibDecoder;

const
  zbAutoConst = zbAuto;
  zbPure = zbPurePascal;
  zbFfiConst = zbFfi;

  // base 常量直转
  ZLIB_ADLER_INIT_ALIAS = ZLIB_ADLER_INIT;
  ZLIB_MAX_DECOMPRESS_BYTES_ALIAS = ZLIB_MAX_DECOMPRESS_BYTES;

{ 后端选择：Auto 按 FFI 可用性降级 }
procedure ZlibSetBackend(ABackend: TZlibBackend);
function ZlibRequestedBackend: TZlibBackend; inline;
function ZlibActiveBackend: TZlibBackend; inline;
function ZlibFfiIsAvailable: Boolean; inline;

{ 采集当前生效的编解码器 }
function ZlibAcquireEncoder: IZlibEncoder; inline;
function ZlibAcquireDecoder: IZlibDecoder; inline;
function ZlibAcquireEncoderWithBackend(ABackend: TZlibBackend): IZlibEncoder;
function ZlibAcquireDecoderWithBackend(ABackend: TZlibBackend): IZlibDecoder;

{ 一次性便捷：门面 inline 直达当前后端 }
function ZlibEncode(const AData: TBytes): TBytes; inline;
function ZlibEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes; inline;
function ZlibEncodeRaw(const AData: TBytes): TBytes; inline;
function ZlibEncodeRawWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes; inline;
function ZlibDecode(const AData: TBytes): TBytes; inline;
function ZlibDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes; inline;
function ZlibDecodeRaw(const AData: TBytes): TBytes; inline;
function ZlibDecodeRawWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes; inline;

{ Adler 便捷：复用 intf 无状态 helper }
function ZlibAdler(const AData: TBytes): LongWord; inline;
function ZlibAdlerOf(const ABuf; ALen: SizeUInt): LongWord; inline;
function ZlibAdlerUpdateWrap(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord; inline;

{ 直连纯/FFI 便于探针与回归 }
function ZlibPureEncode(const AData: TBytes): TBytes; inline;
function ZlibPureDecode(const AData: TBytes): TBytes; inline;
function ZlibFfiEncodeWrap(const AData: TBytes; const ALevel: TZlibLevel): TBytes; inline;
function ZlibFfiDecodeWrap(const AData: TBytes): TBytes; inline;

implementation

var
  GRequested: TZlibBackend = zbAuto;
  GPureEncoder: IZlibEncoder = nil;
  GPureDecoder: IZlibDecoder = nil;
  GFfiEncoder: IZlibEncoder = nil;
  GFfiDecoder: IZlibDecoder = nil;

procedure ZlibSetBackend(ABackend: TZlibBackend);
begin
  GRequested := ABackend;
end;

function ZlibRequestedBackend: TZlibBackend;
begin
  Result := GRequested;
end;

function ZlibFfiIsAvailable: Boolean;
begin
  Result := ZlibFfiAvailable;
end;

function ZlibActiveBackend: TZlibBackend;
begin
  case GRequested of
    zbPurePascal: Result := zbPurePascal;
    zbFfi:
      if ZlibFfiAvailable then
        Result := zbFfi
      else
        Result := zbPurePascal;
  else
    if ZlibFfiAvailable then
      Result := zbFfi
    else
      Result := zbPurePascal;
  end;
end;

function EnsurePureEncoder: IZlibEncoder; inline;
begin
  if GPureEncoder = nil then
    GPureEncoder := CreateZlibPureEncoder;
  Result := GPureEncoder;
end;

function EnsurePureDecoder: IZlibDecoder; inline;
begin
  if GPureDecoder = nil then
    GPureDecoder := CreateZlibPureDecoder;
  Result := GPureDecoder;
end;

function EnsureFfiEncoder: IZlibEncoder; inline;
begin
  if GFfiEncoder = nil then
    GFfiEncoder := CreateZlibFfiEncoder;
  Result := GFfiEncoder;
end;

function EnsureFfiDecoder: IZlibDecoder; inline;
begin
  if GFfiDecoder = nil then
    GFfiDecoder := CreateZlibFfiDecoder;
  Result := GFfiDecoder;
end;

function ZlibAcquireEncoder: IZlibEncoder;
begin
  case ZlibActiveBackend of
    zbFfi: Result := EnsureFfiEncoder;
  else
    Result := EnsurePureEncoder;
  end;
end;

function ZlibAcquireDecoder: IZlibDecoder;
begin
  case ZlibActiveBackend of
    zbFfi: Result := EnsureFfiDecoder;
  else
    Result := EnsurePureDecoder;
  end;
end;

function ZlibAcquireEncoderWithBackend(ABackend: TZlibBackend): IZlibEncoder;
begin
  case ABackend of
    zbFfi:
      if ZlibFfiAvailable then
        Result := EnsureFfiEncoder
      else
        Result := EnsurePureEncoder;
    zbPurePascal: Result := EnsurePureEncoder;
  else
    Result := ZlibAcquireEncoder;
  end;
end;

function ZlibAcquireDecoderWithBackend(ABackend: TZlibBackend): IZlibDecoder;
begin
  case ABackend of
    zbFfi:
      if ZlibFfiAvailable then
        Result := EnsureFfiDecoder
      else
        Result := EnsurePureDecoder;
    zbPurePascal: Result := EnsurePureDecoder;
  else
    Result := ZlibAcquireDecoder;
  end;
end;

function ZlibEncode(const AData: TBytes): TBytes;
begin
  Result := ZlibAcquireEncoder.Encode(AData);
end;

function ZlibEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := ZlibAcquireEncoder.EncodeWithLevel(AData, ALevel);
end;

function ZlibEncodeRaw(const AData: TBytes): TBytes;
begin
  Result := ZlibPureEncodeRaw(AData);
end;

function ZlibEncodeRawWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := ZlibPureEncodeRawWithLevel(AData, ALevel);
end;

function ZlibDecode(const AData: TBytes): TBytes;
begin
  Result := ZlibAcquireDecoder.Decode(AData);
end;

function ZlibDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := ZlibAcquireDecoder.DecodeWithLimit(AData, AMaxOutputSize);
end;

function ZlibDecodeRaw(const AData: TBytes): TBytes;
begin
  Result := ZlibPureDecodeRaw(AData);
end;

function ZlibDecodeRawWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := ZlibPureDecodeRawWithLimit(AData, AMaxOutputSize);
end;

function ZlibAdler(const AData: TBytes): LongWord;
begin
  Result := ZlibAdler32(AData);
end;

function ZlibAdlerOf(const ABuf; ALen: SizeUInt): LongWord;
begin
  Result := ZlibAdler32Of(ABuf, ALen);
end;

function ZlibAdlerUpdateWrap(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
begin
  Result := ZlibAdler32Update(AAdler, AData, ALen);
end;

function ZlibPureEncode(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.zlib.pure.ZlibPureEncodeWithLevel(AData, zlDefault);
end;

function ZlibPureDecode(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.zlib.pure.ZlibPureDecode(AData);
end;

function ZlibFfiEncodeWrap(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := nextpas.core.zlib.ffi.ZlibFfiEncode(AData, ALevel);
end;

function ZlibFfiDecodeWrap(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.zlib.ffi.ZlibFfiDecode(AData);
end;

end.
