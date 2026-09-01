unit nextpas.core.zlib.libz;

{**
 * @desc nextpas.core.zlib.libz - libz 动态绑定实现（FFI 业务层）
 *
 * 承载原 nextpas.core.zlib.ffi 的业务类 TZlibLibzEncoder（兼容别名
 * TZlibFfiEncoder）及平台懒加载、Encode/Decode 单源逻辑。
 * 依赖 nextpas.core.zlib.ffi 仅获取 cdecl ABI，不含外联逻辑；
 * 容量增长复用 compress.base CompressNextCapacity 单源，
 * 字节拷贝遵循 bytes.ops 单次 SetLength+Move 零拷贝纪律。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.zlib.base,
  nextpas.core.zlib.intf;

type
  { FFI 编解码器：IEncoder+IDecoder 复用，Encode 走 compress2+bound，
    Decode 走 uncompress 扩容重试，Adler 复用 base 纯实现。 }
  TZlibLibzEncoder = class(TInterfacedObject, IZlibEncoder, IZlibDecoder)
  public
    function Encode(const AData: TBytes): TBytes;
    function EncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
    function TryEncode(const AData: TBytes; out AEncoded: TBytes): Boolean;
    function TryEncodeWithError(const AData: TBytes; out AEncoded: TBytes; out AError: string): Boolean;
    function TryEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel; out AEncoded: TBytes): Boolean;
    function TryEncodeWithLevelWithError(const AData: TBytes; const ALevel: TZlibLevel; out AEncoded: TBytes; out AError: string): Boolean;
    function Decode(const AData: TBytes): TBytes;
    function DecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
    function TryDecode(const AData: TBytes; out ADecoded: TBytes): Boolean;
    function TryDecodeWithError(const AData: TBytes; out ADecoded: TBytes; out AError: string): Boolean;
    function TryDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: TBytes): Boolean;
    function TryDecodeWithLimitWithError(const AData: TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: TBytes; out AError: string): Boolean;
    function Adler32(const AData: TBytes): LongWord;
    function Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
  end;

  { 兼容别名：历史对外名称，指向同一实现 }
  TZlibFfiEncoder = TZlibLibzEncoder;

function ZlibFfiAvailable: Boolean; inline;
function CreateZlibFfiEncoder: IZlibEncoder;
function CreateZlibFfiDecoder: IZlibDecoder;
function ZlibFfiVersion: PAnsiChar;
function NativeZlibVersion: PAnsiChar; inline;

function ZlibFfiEncode(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
function ZlibFfiEncodeRaw(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
function ZlibFfiDecode(const AData: TBytes): TBytes;
function ZlibFfiDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.platform.dl,
  nextpas.core.zlib.ffi,
  nextpas.core.compress.base,
  nextpas.core.bytes.ops;

var
  GOnceDone: LongInt = 0;
  GOnceLock: TRTLCriticalSection;
  GLibLoaded: Boolean = False;
  GLib: TPlatformLibrary;
  GCompressBound: TZCompressBound = nil;
  GCompress2: TZCompress2 = nil;
  GUncompress: TZUncompress = nil;
  GVersionFn: TZVersion = nil;

function LoadLib: Boolean;
var
  LNames: array[0..2] of PAnsiChar;
  LI: Integer;
  LLib: TPlatformLibrary;
  LSym: Pointer;
begin
  Result := False;
{$IFDEF NEXTPAS_USE_ZLIB_NATIVE}
  // 静态链接分支：符号已在链接期解析，直接视为可用
  GCompressBound := @zlib_compressBound;
  GCompress2 := @zlib_compress2;
  GUncompress := @zlib_uncompress;
  GVersionFn := @zlibVersionNative;
  Result := True;
  Exit;
{$ENDIF}
  LNames[0] := 'libz.so.1';
  LNames[1] := 'libz.so';
  LNames[2] := 'libz.so.1.0';
  for LI := 0 to High(LNames) do
  begin
    if platform_dl_open(LNames[LI], PLATFORM_DL_LAZY, LLib) = 0 then
    begin
      if (LLib.Sym('compressBound', LSym) = 0) and (LSym <> nil) then
        GCompressBound := TZCompressBound(LSym);
      if (LLib.Sym('compress2', LSym) = 0) and (LSym <> nil) then
        GCompress2 := TZCompress2(LSym);
      if (LLib.Sym('uncompress', LSym) = 0) and (LSym <> nil) then
        GUncompress := TZUncompress(LSym);
      if (LLib.Sym('zlibVersion', LSym) = 0) and (LSym <> nil) then
        GVersionFn := TZVersion(LSym);
      if Assigned(GCompressBound) and Assigned(GCompress2) and Assigned(GUncompress) and Assigned(GVersionFn) then
      begin
        GLib := LLib;
        Result := True;
      end
      else
      begin
        // 不完全则关闭，尝试下一个名字
        platform_dl_close(LLib);
        GCompressBound := nil;
        GCompress2 := nil;
        GUncompress := nil;
        GVersionFn := nil;
        Continue;
      end;
      Break;
    end;
  end;
end;

function ZlibFfiAvailable: Boolean;
begin
  if InterlockedCompareExchange(GOnceDone, 0, 0) <> 0 then Exit(GLibLoaded);
  EnterCriticalSection(GOnceLock);
  try
    if GOnceDone = 0 then
    begin
      GLibLoaded := LoadLib;
      InterlockedExchange(GOnceDone, 1);
    end;
  finally
    LeaveCriticalSection(GOnceLock);
  end;
  Result := GLibLoaded;
end;

function ZlibFfiVersion: PAnsiChar;
begin
  if not ZlibFfiAvailable then
    Result := nil
  else
    Result := GVersionFn();
end;

function NativeZlibVersion: PAnsiChar;
begin
  Result := ZlibFfiVersion;
  if Result = nil then
    Result := PAnsiChar('');
end;

procedure RaiseFfi(ACode: TZlibErrorCode; const AMsg: string); inline;
begin
  raise EZlibError.Create(ACode, AMsg);
end;

function DoEncode(const AData: TBytes; const ALevel: TZlibLevel; ARaw: Boolean): TBytes;
var
  LSrcLen, LDstLen: LongWord;
  LLevel: Integer;
  LRet: Integer;
  LBound: LongWord;
  LHeader: Word;
  LCmf, LFLevel, LFlg: Byte;
begin
  Result := nil;
  if ARaw then
    RaiseFfi(zecUnsupported, 'zlib ffi: raw not supported');
  if not ZlibFfiAvailable then
    RaiseFfi(zecUnsupported, 'libz not available');
  if Length(AData) = 0 then
  begin
    // 空输入内联生成 header+stored+adler，不依赖 pure/zlib888
    // perf: inline/zero-copy — 单次 SetLength(11) + 直接索引填充，无额外 Move/分配
    LCmf := $78;
    case ALevel of
      zlNone:    LFLevel := 0;
      zlFastest: LFLevel := 0;
      zlBest:    LFLevel := 3;
    else
      LFLevel := 2;
    end;
    LFlg := LFLevel shl 6;
    LFlg := LFlg or Byte((31 - ((Word(LCmf) shl 8 or LFlg) mod 31)) mod 31);
    LHeader := (Word(LCmf) shl 8) or Word(LFlg);
    SetLength(Result, 11);
    Result[0] := Byte(LHeader shr 8);
    Result[1] := Byte(LHeader and $FF);
    Result[2] := 1; Result[3] := 0; Result[4] := 0; Result[5] := $FF; Result[6] := $FF;
    Result[7] := 0; Result[8] := 0; Result[9] := 0; Result[10] := 1;
    Exit;
  end;
  LSrcLen := LongWord(Length(AData));
  LLevel := ZlibLevelToZlib(ALevel);
  LBound := GCompressBound(LSrcLen);
  if LBound = 0 then
    LBound := 64;
  // bytes.ops 单源纪律：单次 SetLength 到 bound，零拷贝指针直写（GCompress2 填充）
  SetLength(Result, LBound);
  LDstLen := LBound;
  // perf: zero-copy — 传入 PByte 指针，无索引喂 untyped 的 inline 膨胀
  if Length(AData) > 0 then
    LRet := GCompress2(PByte(Pointer(Result)), LDstLen, PByte(Pointer(AData)), LSrcLen, LLevel)
  else
    LRet := GCompress2(PByte(Pointer(Result)), LDstLen, nil, LSrcLen, LLevel);
  if LRet <> Z_OK then
    RaiseFfi(zecInternal, 'zlib ffi: compress2 failed (' + IntToStr(LRet) + ')');
  SetLength(Result, LDstLen);
end;

function DoDecode(const AData: TBytes; const AMax: SizeUInt): TBytes;
var
  LSrcLen: LongWord;
  LDstLen: LongWord;
  LCap, LNextCap: SizeUInt;
  LRet: Integer;
  LMax: SizeUInt;
begin
  Result := nil;
  if Length(AData) = 0 then
    Exit(nil);
  if not ZlibFfiAvailable then
    RaiseFfi(zecUnsupported, 'libz not available');
  LMax := AMax;
  if LMax = 0 then
    LMax := ZLIB_MAX_DECOMPRESS_BYTES;
  if LMax > ZLIB_MAX_DECOMPRESS_BYTES then
    LMax := ZLIB_MAX_DECOMPRESS_BYTES;
  LSrcLen := LongWord(Length(AData));
  // 初始容量：复用 compress.base 单源语义（输入*3 或 64，上限 LMax）
  LCap := SizeUInt(Length(AData)) * 3;
  if LCap < 64 then
    LCap := 64;
  if LCap > LMax then
    LCap := LMax;
  SetLength(Result, LCap);
  while True do
  begin
    LDstLen := LongWord(LCap);
    // perf: zero-copy PByte 指针直调，无临时拷贝
    if (Length(AData) > 0) and (Length(Result) > 0) then
      LRet := GUncompress(PByte(Pointer(Result)), LDstLen, PByte(Pointer(AData)), LSrcLen)
    else
      LRet := GUncompress(nil, LDstLen, PByte(Pointer(AData)), LSrcLen);
    if LRet = Z_OK then
    begin
      if SizeUInt(LDstLen) > LMax then
        RaiseFfi(zecLimitExceeded, 'zlib: decompressed size exceeds limit');
      SetLength(Result, LDstLen);
      Exit;
    end;
    if LRet = Z_BUF_ERROR then
    begin
      if LCap >= LMax then
        RaiseFfi(zecLimitExceeded, 'zlib: decompressed size exceeds limit');
      // 单源扩容：复用 compress.base CompressNextCapacity，避免分支漂移
      LNextCap := CompressNextCapacity(LCap, LMax);
      if LNextCap = 0 then
        RaiseFfi(zecLimitExceeded, 'zlib: decompressed size exceeds limit');
      if LNextCap > LMax then
        LNextCap := LMax;
      if LNextCap <= LCap then
        RaiseFfi(zecLimitExceeded, 'zlib: decompressed size exceeds limit');
      LCap := LNextCap;
      // bytes.ops 单源：SetLength 异常安全，无 header poke
      SetLength(Result, LCap);
      Continue;
    end;
    if LRet = Z_DATA_ERROR then
      RaiseFfi(zecCorruptStream, 'zlib: corrupt stream');
    if LRet = Z_MEM_ERROR then
      RaiseFfi(zecInternal, 'zlib: mem error');
    RaiseFfi(zecCorruptStream, 'zlib ffi: uncompress failed (' + IntToStr(LRet) + ')');
  end;
end;

function ZlibFfiEncode(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := DoEncode(AData, ALevel, False);
end;

function ZlibFfiEncodeRaw(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := DoEncode(AData, ALevel, True);
end;

function ZlibFfiDecode(const AData: TBytes): TBytes;
begin
  Result := DoDecode(AData, ZLIB_MAX_DECOMPRESS_BYTES);
end;

function ZlibFfiDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := DoDecode(AData, AMaxOutputSize);
end;

function CreateZlibFfiEncoder: IZlibEncoder;
begin
  if not ZlibFfiAvailable then
    RaiseFfi(zecUnsupported, 'libz not available');
  Result := TZlibLibzEncoder.Create;
end;

function CreateZlibFfiDecoder: IZlibDecoder;
begin
  if not ZlibFfiAvailable then
    RaiseFfi(zecUnsupported, 'libz not available');
  Result := TZlibLibzEncoder.Create;
end;

{ TZlibLibzEncoder }

function TZlibLibzEncoder.Encode(const AData: TBytes): TBytes;
begin
  Result := DoEncode(AData, zlDefault, False);
end;

function TZlibLibzEncoder.EncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
begin
  Result := DoEncode(AData, ALevel, False);
end;

function TZlibLibzEncoder.Decode(const AData: TBytes): TBytes;
begin
  Result := DoDecode(AData, ZLIB_MAX_DECOMPRESS_BYTES);
end;

function TZlibLibzEncoder.DecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
begin
  Result := DoDecode(AData, AMaxOutputSize);
end;

function TZlibLibzEncoder.TryEncode(const AData: TBytes; out AEncoded: TBytes): Boolean;
var LDummy: string;
begin
  Result := TryEncodeWithError(AData, AEncoded, LDummy);
end;

function TZlibLibzEncoder.TryEncodeWithError(const AData: TBytes; out AEncoded: TBytes; out AError: string): Boolean;
begin
  try
    AEncoded := Encode(AData);
    AError := '';
    Result := True;
  except on E: Exception do begin AEncoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibLibzEncoder.TryEncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel; out AEncoded: TBytes): Boolean;
var LDummy: string;
begin
  Result := TryEncodeWithLevelWithError(AData, ALevel, AEncoded, LDummy);
end;

function TZlibLibzEncoder.TryEncodeWithLevelWithError(const AData: TBytes; const ALevel: TZlibLevel; out AEncoded: TBytes; out AError: string): Boolean;
begin
  try
    AEncoded := EncodeWithLevel(AData, ALevel);
    AError := '';
    Result := True;
  except on E: Exception do begin AEncoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibLibzEncoder.TryDecode(const AData: TBytes; out ADecoded: TBytes): Boolean;
var LDummy: string;
begin
  Result := TryDecodeWithError(AData, ADecoded, LDummy);
end;

function TZlibLibzEncoder.TryDecodeWithError(const AData: TBytes; out ADecoded: TBytes; out AError: string): Boolean;
begin
  try
    ADecoded := Decode(AData);
    AError := '';
    Result := True;
  except on E: Exception do begin ADecoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibLibzEncoder.TryDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: TBytes): Boolean;
var LDummy: string;
begin
  Result := TryDecodeWithLimitWithError(AData, AMaxOutputSize, ADecoded, LDummy);
end;

function TZlibLibzEncoder.TryDecodeWithLimitWithError(const AData: TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: TBytes; out AError: string): Boolean;
begin
  try
    ADecoded := DecodeWithLimit(AData, AMaxOutputSize);
    AError := '';
    Result := True;
  except on E: Exception do begin ADecoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibLibzEncoder.Adler32(const AData: TBytes): LongWord;
begin
  Result := ZlibAdler32(AData);
end;

function TZlibLibzEncoder.Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
begin
  Result := ZlibAdlerUpdate(AAdler, AData, ALen);
end;

initialization
  InitCriticalSection(GOnceLock);
finalization
  // 稳定性：临界区可靠释放，不丢资源（GOnceLock 与 GLib 生命周期分离，GLib 由 OS 句柄管理）
  DoneCriticalSection(GOnceLock);
end.
