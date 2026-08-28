unit nextpas.core.sevenz.lzma.ffi;

{**
 * nextpas.core.sevenz.lzma.ffi - liblzma 动态绑定（可选后端）
 *
 * 通过 platform.dl 懒加载 liblzma.so.5 / liblzma.so，零硬链接依赖。
 * 提供 ISevenZLzmaDecoder 的 FFI 实现；库不可用时 SevenZLzmaFfiAvailable
 * 返回 False，上层自动回落纯 Pascal 后端。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.intf;

type
  {** @desc liblzma 后端：ISevenZLzmaDecoder 实现 *}
  TSevenZLzmaDecoderFfi = class(TInterfacedObject, ISevenZLzmaDecoder)
  private
    function DecodeCommon(const AProps: TBytes; const APacked: TBytes;
      const AOutSize: SizeUInt; ALzma1: Boolean): TBytes;
  public
    function DecodeLzma2(const AProps: TBytes; const APacked: TBytes;
      const AOutSize: SizeUInt): TBytes;
    function DecodeLzma1(const AProps: TBytes; const APacked: TBytes;
      const AOutSize: SizeUInt): TBytes;
  end;

{ liblzma 是否已成功加载且符号齐备 }
function SevenZLzmaFfiAvailable: Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.platform.dl,
  nextpas.core.sevenz.base;

const
  { xz 过滤器 ID }
  LZMA_FILTER_LZMA1 = UInt64($4000000000000001);
  { 扩展 LZMA1：解码端需给定精确解压尺寸；
    7z 的 LZMA1 流通常无 EOS 结束标记，必须走这条路径 }
  LZMA_FILTER_LZMA1EXT = UInt64($4000000000000002);
  LZMA_FILTER_LZMA2 = UInt64($21);

  LZMA_OK        = 0;
  LZMA_STREAM_END = 1;
  { 过滤器选项不被支持（含旧库不认识 LZMA_FILTER_LZMA1EXT 的情形） }
  LZMA_OPTIONS_ERROR = 8;
  { 输入耗尽且无 EOS 标记、输出又未满时返回：
    容器自带精确解压尺寸，属正常收尾而非错误 }
  LZMA_BUF_ERROR = 10;

  { 允许流中带 EOPM 结束标记（7z 中罕见但合法） }
  LZMA_LZMA1EXT_ALLOW_EOPM = UInt32($01);

type
  { lzma_options_lzma 覆盖层：解码仅依赖前段字段；
    结构体按上游尺寸放大并整体清零，保证 ABI 兼容
    （ext_* 为 liblzma ≥5.3 的 LZMA_FILTER_LZMA1EXT 所需） }
  PLzmaOptions = ^TLzmaOptions;
  TLzmaOptions = record
    DictSize: UInt32;          { offset 0 }
    ReservedPad: UInt32;       { 对齐填充 }
    PresetDict: Pointer;       { offset 8 }
    PresetDictSize: UInt32;    { offset 16 }
    Lc: UInt32;                { offset 20 }
    Lp: UInt32;                { offset 24 }
    Pb: UInt32;                { offset 28 }
    Mode: UInt32;              { offset 32 }
    NiceLen: UInt32;           { offset 36 }
    MatchFinder: UInt32;       { offset 40 }
    Depth: UInt32;             { offset 44 }
    ExtFlags: UInt32;          { offset 48：LZMA_LZMA1EXT_ALLOW_EOPM 等 }
    ExtSizeLow: UInt32;        { offset 52：精确解压尺寸低 32 位 }
    ExtSizeHigh: UInt32;       { offset 56：高 32 位 }
    ReservedTail: array[0..12] of UInt32;
  end;

  TLzmaFilter = record
    Id: UInt64;
    Options: Pointer;
  end;
  PLzmaFilter = ^TLzmaFilter;

  TLzmaRawBufferDecode = function(AFilters: PLzmaFilter;
    AAllocator: Pointer; const AIn: PByte; var AInPos: SizeUInt;
    AInSize: SizeUInt; AOut: PByte; var AOutPos: SizeUInt;
    AOutSize: SizeUInt): Integer; cdecl;

var
  GOnceDone: Boolean = False;
  GLibLoaded: Boolean = False;
  GRawBufferDecode: TLzmaRawBufferDecode = nil;

function LoadLib: Boolean;
var
  LNames: array[0..2] of PAnsiChar;
  LI: Integer;
  LLib: TPlatformLibrary;
  LSym: Pointer;
begin
  Result := False;
  LNames[0] := 'liblzma.so.5';
  LNames[1] := 'liblzma.so';
  LNames[2] := 'liblzma.so.1';
  for LI := 0 to High(LNames) do
  begin
    if platform_dl_open(LNames[LI], PLATFORM_DL_LAZY, LLib) = 0 then
    begin
      if LLib.Sym('lzma_raw_buffer_decode', LSym) = 0 then
      begin
        GRawBufferDecode := TLzmaRawBufferDecode(LSym);
        Result := True;
      end;
      Break;
    end;
  end;
end;

function SevenZLzmaFfiAvailable: Boolean;
begin
  if not GOnceDone then
  begin
    GLibLoaded := LoadLib;
    GOnceDone := True;
  end;
  Result := GLibLoaded;
end;

procedure ParsePropsIntoOptions(const AProps: TBytes; ALzma1: Boolean;
  var AOpts: TLzmaOptions);
var
  LPbByte: Byte;
begin
  FillChar(AOpts, SizeOf(AOpts), 0);
  if ALzma1 then
  begin
    if Length(AProps) <> 5 then
      raise ESevenZError.Create('lzma1 props must be 5 bytes');
    LPbByte := AProps[0];
  end
  else
  begin
    if Length(AProps) <> 1 then
      raise ESevenZError.Create('lzma2 props must be 1 byte');
    LPbByte := AProps[0];
  end;
  if LPbByte >= 9 * 5 * 5 then
    raise ESevenZError.Create('props byte out of range');
  AOpts.Lc := LPbByte mod 9;
  AOpts.Lp := (LPbByte div 9) mod 5;
  AOpts.Pb := (LPbByte div 9) div 5;
  if ALzma1 then
    AOpts.DictSize := UInt32(AProps[1]) or (UInt32(AProps[2]) shl 8) or
      (UInt32(AProps[3]) shl 16) or (UInt32(AProps[4]) shl 24)
  else
    AOpts.DictSize := $1000000;  { 与 7-Zip 默认一致；解码端仅影响窗口声明 }
end;

function TSevenZLzmaDecoderFfi.DecodeLzma2(const AProps: TBytes;
  const APacked: TBytes; const AOutSize: SizeUInt): TBytes;
begin
  Result := DecodeCommon(AProps, APacked, AOutSize, False);
end;

function TSevenZLzmaDecoderFfi.DecodeLzma1(const AProps: TBytes;
  const APacked: TBytes; const AOutSize: SizeUInt): TBytes;
begin
  Result := DecodeCommon(AProps, APacked, AOutSize, True);
end;

function TSevenZLzmaDecoderFfi.DecodeCommon(const AProps: TBytes;
  const APacked: TBytes; const AOutSize: SizeUInt; ALzma1: Boolean): TBytes;
var
  LFilters: array[0..1] of TLzmaFilter;
  LOpts: TLzmaOptions;
  LInPos, LOutPos: SizeUInt;
  LRet: Integer;
  LOut: TBytes;

  function TryDecode: Integer;
  begin
    LInPos := 0;
    LOutPos := 0;
    Result := GRawBufferDecode(@LFilters[0], nil, @APacked[0], LInPos,
      SizeUInt(Length(APacked)), @LOut[0], LOutPos, AOutSize);
  end;

begin
  Result := nil;
  LOutPos := 0;
  if not SevenZLzmaFfiAvailable then
    raise ENotSupportedError.Create('liblzma not available');
  if AOutSize = 0 then
    Exit(nil);
  if Length(APacked) = 0 then
    raise ESevenZError.Create('empty lzma stream');
  SetLength(LOut, AOutSize);
  FillChar(LOut[0], AOutSize, 0);
  ParsePropsIntoOptions(AProps, ALzma1, LOpts);
  if ALzma1 then
  begin
    { 7z 的 LZMA1 流通常无 EOS 结束标记，容器以精确解压尺寸收尾：
      必须走 LZMA_FILTER_LZMA1EXT 并给定尺寸；ALLOW_EOPM 兼容带标记流。
      旧 liblzma 无此过滤器 ID 时回落普通 LZMA1（仅支持带标记流） }
    LFilters[0].Id := LZMA_FILTER_LZMA1EXT;
    LOpts.ExtFlags := LOpts.ExtFlags or LZMA_LZMA1EXT_ALLOW_EOPM;
    LOpts.ExtSizeLow := UInt32(SizeUInt(AOutSize) and $FFFFFFFF);
    LOpts.ExtSizeHigh := UInt32(SizeUInt(AOutSize) shr 32);
  end
  else
    LFilters[0].Id := LZMA_FILTER_LZMA2;
  LFilters[0].Options := @LOpts;
  LFilters[1].Id := UInt64($FFFFFFFFFFFFFFFF);  { LZMA_VLI_UNKNOWN 结束标记 }
  LFilters[1].Options := nil;
  LRet := TryDecode;
  if ALzma1 and (LRet = LZMA_OPTIONS_ERROR) then
  begin
    LFilters[0].Id := LZMA_FILTER_LZMA1;
    LOpts.ExtFlags := 0;
    LRet := TryDecode;
  end;
  { 容器契约以精确输出尺寸为准：
    - STREAM_END/OK 且凑满 → 成功
    - BUF_ERROR（无 EOS 流的正常收尾）凑满 → 成功
    - 其余返回码，或输出不足 → 抛错。
      凑满后残余输入（如 EOS 尾字节）不视为失败 }
  if (LRet <> LZMA_OK) and (LRet <> LZMA_STREAM_END) and
     (LRet <> LZMA_BUF_ERROR) then
    raise ESevenZError.CreateFmt('liblzma decode failed (code %d)', [LRet]);
  if LOutPos <> AOutSize then
    raise ESevenZError.Create('liblzma short decode');
  Result := LOut;
end;

end.
