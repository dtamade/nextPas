unit nextpas.core.zlib.pure;

{**
 * @desc nextpas.core.zlib.pure - 薄兼容门面（转发至 zlib888）
 * 保留旧 uses 编译通过，真实实现位于 nextpas.core.zlib.zlib888
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.zlib.base,
  nextpas.core.zlib.intf,
  nextpas.core.zlib.zlib888;

type
  TZlibPureDecoder = nextpas.core.zlib.zlib888.TZlibPureDecoder;

function ZlibPureDecode(const AData: TBytes): TBytes; inline;
function ZlibPureDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes; inline;
function ZlibPureDecodeRaw(const AData: TBytes): TBytes; inline;
function ZlibPureDecodeRawWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes; inline;
function ZlibPureEncode(const AData: TBytes): TBytes; inline;
function ZlibPureEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes; inline;
function ZlibPureEncodeRaw(const AData: TBytes): TBytes; inline;
function ZlibPureEncodeRawWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes; inline;
function CreateZlibPureDecoder: IZlibDecoder; inline;
function CreateZlibPureEncoder: IZlibEncoder; inline;

implementation

function ZlibPureDecode(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.zlib.zlib888.ZlibPureDecode(AData);
end;

function ZlibPureDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.zlib.zlib888.ZlibPureDecodeWithLimit(AData, AMaxOutputSize);
end;

function ZlibPureDecodeRaw(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.zlib.zlib888.ZlibPureDecodeRaw(AData);
end;

function ZlibPureDecodeRawWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.zlib.zlib888.ZlibPureDecodeRawWithLimit(AData, AMaxOutputSize);
end;

function ZlibPureEncode(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.zlib.zlib888.ZlibPureEncode(AData);
end;

function ZlibPureEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := nextpas.core.zlib.zlib888.ZlibPureEncodeWithLevel(AData, ALevel);
end;

function ZlibPureEncodeRaw(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.zlib.zlib888.ZlibPureEncodeRaw(AData);
end;

function ZlibPureEncodeRawWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := nextpas.core.zlib.zlib888.ZlibPureEncodeRawWithLevel(AData, ALevel);
end;

function CreateZlibPureDecoder: IZlibDecoder;
begin
  Result := nextpas.core.zlib.zlib888.CreateZlibPureDecoder;
end;

function CreateZlibPureEncoder: IZlibEncoder;
begin
  Result := nextpas.core.zlib.zlib888.CreateZlibPureEncoder;
end;

end.
