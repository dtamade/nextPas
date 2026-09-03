unit nextpas.core.sevenz.lzma.ffi.decoder;

{**
 * nextpas.core.sevenz.lzma.ffi.decoder - liblzma 动态后端实现
 *
 * 承载 dlopen 探测、符号绑定与 ISevenZLzmaDecoder 解码链。
 * FFI 缝（nextpas.core.sevenz.lzma.ffi）仅含 ABI 声明，本单元为唯一逻辑归属。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sevenz.intf;

type
  {** @desc liblzma 后端：ISevenZLzmaDecoder 实现（经 platform.dl 懒加载） *}
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

{ liblzma 是否已成功加载且符号齐备；首调触发懒探测 }
function SevenZLzmaFfiAvailable: Boolean; inline;

implementation

uses
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.platform.dl,
  nextpas.core.sevenz.base,
  nextpas.core.sevenz.lzma.ffi;

var
  GLib: TPlatformLibrary;
  GOnceDone: Boolean = False;
  GLibLoaded: Boolean = False;
  GRawBufferDecode: TLzmaRawBufferDecode = nil;

function LoadLib: Boolean;
var
  LI: Integer;
  LLib: TPlatformLibrary;
  LSym: Pointer;
begin
  Result := False;
  for LI := 0 to High(LIBLZMA_SO_NAMES) do
  begin
    if platform_dl_open(PAnsiChar(LIBLZMA_SO_NAMES[LI]), PLATFORM_DL_LAZY, LLib) = 0 then
    begin
      if LLib.Sym(LIBLZMA_PROBE_SYMBOL, LSym) = 0 then
      begin
        GRawBufferDecode := TLzmaRawBufferDecode(LSym);
        GLib := LLib;
        Result := True;
        Exit;
      end;
      { 符号缺失：释放句柄，试下一 so 名；避免句柄泄漏与误判 *}
      platform_dl_release(LLib);
    end;
  end;
end;

function SevenZLzmaFfiAvailable: Boolean; inline;
begin
  if not GOnceDone then
  begin
    GLibLoaded := LoadLib;
    GOnceDone := True;
  end;
  Result := GLibLoaded;
end;

{ 解析 7z coder props 为 liblzma 选项；零拷贝入参，单 FillChar 清零 }
procedure ParsePropsIntoOptions(const AProps: TBytes; ALzma1: Boolean;
  var AOpts: TLzmaOptions); inline;
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

  { perf: inline 局部 TryDecode 避免重复置位，复用栈上 LFilters/LOpts 零堆分配 }
  function TryDecode: Integer; inline;
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
  { perf: 单 SetLength + FillChar 预分配，零拷贝 Move 仅在 TryDecode 内由 liblzma 完成 }
  SetLength(LOut, AOutSize);
  FillChar(LOut[0], AOutSize, 0);
  ParsePropsIntoOptions(AProps, ALzma1, LOpts);
  if ALzma1 then
  begin
    { 7z 的 LZMA1 流通常无 EOS，须走 LZMA_FILTER_LZMA1EXT 并给定精确尺寸；ALLOW_EOPM 兼容带标记流 }
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
  { 容器契约以精确输出尺寸为准：STREAM_END/OK 凑满或 BUF_ERROR 凑满均成功 }
  if (LRet <> LZMA_OK) and (LRet <> LZMA_STREAM_END) and
     (LRet <> LZMA_BUF_ERROR) then
    raise ESevenZError.CreateFmt('liblzma decode failed (code %d)', [LRet]);
  if LOutPos <> AOutSize then
    raise ESevenZError.Create('liblzma short decode');
  Result := LOut;
end;

finalization
  { 稳定性：句柄 Close 幂等，进程退出与重复库探测不泄漏 dl 句柄 }
  platform_dl_release(GLib);

end.
