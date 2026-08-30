unit nextpas.core.zlib.ffi;

{**
 * @desc nextpas.core.zlib.ffi - libz 动态绑定（可选后端）
 *
 * 通过 platform.dl 懒加载 libz.so(.1/.1.0)，零硬链接依赖。
 * 提供 IZlibEncoder/Decoder 的 FFI 实现；库不可用时
 * ZlibFfiAvailable 返回 False，上层自动回落纯 Pascal 后端。
 * 保留 NEXTPAS_USE_ZLIB_NATIVE 静态分支供编译期验证。
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
  TZlibFfiEncoder = class(TInterfacedObject, IZlibEncoder, IZlibDecoder)
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

function ZlibFfiAvailable: Boolean;
function CreateZlibFfiEncoder: IZlibEncoder;
function CreateZlibFfiDecoder: IZlibDecoder;
function ZlibFfiVersion: PAnsiChar;
function NativeZlibVersion: PAnsiChar;

function ZlibFfiEncode(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
function ZlibFfiEncodeRaw(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
function ZlibFfiDecode(const AData: TBytes): TBytes;
function ZlibFfiDecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.platform.dl,
  nextpas.core.zlib.pure;

const
  Z_OK = 0;
  Z_STREAM_END = 1;
  Z_DATA_ERROR = -3;
  Z_MEM_ERROR = -4;
  Z_BUF_ERROR = -5;

type
  TZCompressBound = function(sourceLen: LongWord): LongWord; cdecl;
  TZCompress2 = function(dest: PByte; var destLen: LongWord; source: PByte; sourceLen: LongWord; level: Integer): Integer; cdecl;
  TZUncompress = function(dest: PByte; var destLen: LongWord; source: PByte; sourceLen: LongWord): Integer; cdecl;
  TZVersion = function: PAnsiChar; cdecl;

var
  GOnceDone: LongInt = 0;
  GOnceLock: TRTLCriticalSection;
  GLibLoaded: Boolean = False;
  GLib: TPlatformLibrary;
  GCompressBound: TZCompressBound = nil;
  GCompress2: TZCompress2 = nil;
  GUncompress: TZUncompress = nil;
  GVersionFn: TZVersion = nil;

{$IFDEF NEXTPAS_USE_ZLIB_NATIVE}
function zlib_compressBound(sourceLen: LongWord): LongWord; cdecl; external 'z' name 'compressBound';
function zlib_compress2(dest: PByte; var destLen: LongWord; source: PByte; sourceLen: LongWord; level: Integer): Integer; cdecl; external 'z' name 'compress2';
function zlib_uncompress(dest: PByte; var destLen: LongWord; source: PByte; sourceLen: LongWord): Integer; cdecl; external 'z' name 'uncompress';
function zlibVersionNative: PAnsiChar; cdecl; external 'z' name 'zlibVersion';
{$ENDIF}

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

function DoEncode(const AData: nextpas.core.base.TBytes; const ALevel: TZlibLevel; ARaw: Boolean): nextpas.core.base.TBytes;
var
  LSrcLen, LDstLen: LongWord;
  LLevel: Integer;
  LRet: Integer;
  LBound: LongWord;
begin
  Result := nil;
  if ARaw then
    RaiseFfi(zecUnsupported, 'zlib ffi: raw not supported');
  if not ZlibFfiAvailable then
    RaiseFfi(zecUnsupported, 'libz not available');
  if Length(AData) = 0 then
  begin
    // 空输入仍需输出合法 zlib 流（header+empty block+adler）
    // 复用纯实现的空编码，避免 FFI 对零长边界差异
    Result := ZlibPureEncodeWithLevel(AData, ALevel);
    Exit;
  end;
  LSrcLen := LongWord(Length(AData));
  LLevel := ZlibLevelToZlib(ALevel);
  LBound := GCompressBound(LSrcLen);
  if LBound = 0 then
    LBound := 64;
  SetLength(Result, LBound);
  LDstLen := LBound;
  LRet := GCompress2(@Result[0], LDstLen, @AData[0], LSrcLen, LLevel);
  if LRet <> Z_OK then
    RaiseFfi(zecInternal, 'zlib ffi: compress2 failed (' + IntToStr(LRet) + ')');
  SetLength(Result, LDstLen);
end;

function DoDecode(const AData: nextpas.core.base.TBytes; const AMax: SizeUInt): nextpas.core.base.TBytes;
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
  // 初始容量：输入 3 倍或 64，最多 LMax
  LCap := SizeUInt(Length(AData)) * 3;
  if LCap < 64 then
    LCap := 64;
  if LCap > LMax then
    LCap := LMax;
  SetLength(Result, LCap);
  while True do
  begin
    LDstLen := LongWord(LCap);
    LRet := GUncompress(@Result[0], LDstLen, @AData[0], LSrcLen);
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
      if LCap > LMax div 2 then
        LNextCap := LMax
      else
        LNextCap := LCap shl 1;
      if LNextCap > LMax then
        LNextCap := LMax;
      if LNextCap <= LCap then
        RaiseFfi(zecLimitExceeded, 'zlib: decompressed size exceeds limit');
      LCap := LNextCap;
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

function ZlibFfiEncode(const AData: nextpas.core.base.TBytes; const ALevel: TZlibLevel): nextpas.core.base.TBytes;
begin
  Result := DoEncode(AData, ALevel, False);
end;

function ZlibFfiEncodeRaw(const AData: nextpas.core.base.TBytes; const ALevel: TZlibLevel): nextpas.core.base.TBytes;
begin
  Result := DoEncode(AData, ALevel, True);
end;

function ZlibFfiDecode(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
begin
  Result := DoDecode(AData, ZLIB_MAX_DECOMPRESS_BYTES);
end;

function ZlibFfiDecodeWithLimit(const AData: nextpas.core.base.TBytes; const AMaxOutputSize: SizeUInt): nextpas.core.base.TBytes;
begin
  Result := DoDecode(AData, AMaxOutputSize);
end;

function CreateZlibFfiEncoder: IZlibEncoder;
begin
  if not ZlibFfiAvailable then
    RaiseFfi(zecUnsupported, 'libz not available');
  Result := TZlibFfiEncoder.Create;
end;

function CreateZlibFfiDecoder: IZlibDecoder;
begin
  if not ZlibFfiAvailable then
    RaiseFfi(zecUnsupported, 'libz not available');
  Result := TZlibFfiEncoder.Create;
end;

{ TZlibFfiEncoder }

function TZlibFfiEncoder.Encode(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
begin
  Result := DoEncode(AData, zlDefault, False);
end;

function TZlibFfiEncoder.EncodeWithLevel(const AData: nextpas.core.base.TBytes; const ALevel: TZlibLevel): nextpas.core.base.TBytes;
begin
  Result := DoEncode(AData, ALevel, False);
end;

function TZlibFfiEncoder.Decode(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
begin
  Result := DoDecode(AData, ZLIB_MAX_DECOMPRESS_BYTES);
end;

function TZlibFfiEncoder.DecodeWithLimit(const AData: nextpas.core.base.TBytes; const AMaxOutputSize: SizeUInt): nextpas.core.base.TBytes;
begin
  Result := DoDecode(AData, AMaxOutputSize);
end;

function TZlibFfiEncoder.TryEncode(const AData: nextpas.core.base.TBytes; out AEncoded: nextpas.core.base.TBytes): Boolean;
var LDummy: string;
begin
  Result := TryEncodeWithError(AData, AEncoded, LDummy);
end;

function TZlibFfiEncoder.TryEncodeWithError(const AData: nextpas.core.base.TBytes; out AEncoded: nextpas.core.base.TBytes; out AError: string): Boolean;
begin
  try
    AEncoded := Encode(AData);
    AError := '';
    Result := True;
  except on E: Exception do begin AEncoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibFfiEncoder.TryEncodeWithLevel(const AData: nextpas.core.base.TBytes; const ALevel: TZlibLevel; out AEncoded: nextpas.core.base.TBytes): Boolean;
var LDummy: string;
begin
  Result := TryEncodeWithLevelWithError(AData, ALevel, AEncoded, LDummy);
end;

function TZlibFfiEncoder.TryEncodeWithLevelWithError(const AData: nextpas.core.base.TBytes; const ALevel: TZlibLevel; out AEncoded: nextpas.core.base.TBytes; out AError: string): Boolean;
begin
  try
    AEncoded := EncodeWithLevel(AData, ALevel);
    AError := '';
    Result := True;
  except on E: Exception do begin AEncoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibFfiEncoder.TryDecode(const AData: nextpas.core.base.TBytes; out ADecoded: nextpas.core.base.TBytes): Boolean;
var LDummy: string;
begin
  Result := TryDecodeWithError(AData, ADecoded, LDummy);
end;

function TZlibFfiEncoder.TryDecodeWithError(const AData: nextpas.core.base.TBytes; out ADecoded: nextpas.core.base.TBytes; out AError: string): Boolean;
begin
  try
    ADecoded := Decode(AData);
    AError := '';
    Result := True;
  except on E: Exception do begin ADecoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibFfiEncoder.TryDecodeWithLimit(const AData: nextpas.core.base.TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: nextpas.core.base.TBytes): Boolean;
var LDummy: string;
begin
  Result := TryDecodeWithLimitWithError(AData, AMaxOutputSize, ADecoded, LDummy);
end;

function TZlibFfiEncoder.TryDecodeWithLimitWithError(const AData: nextpas.core.base.TBytes; const AMaxOutputSize: SizeUInt; out ADecoded: nextpas.core.base.TBytes; out AError: string): Boolean;
begin
  try
    ADecoded := DecodeWithLimit(AData, AMaxOutputSize);
    AError := '';
    Result := True;
  except on E: Exception do begin ADecoded := nil; AError := E.ClassName + ': ' + E.Message; Result := False; end;
  end;
end;

function TZlibFfiEncoder.Adler32(const AData: nextpas.core.base.TBytes): LongWord;
begin
  Result := ZlibAdler32(AData);
end;

function TZlibFfiEncoder.Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
begin
  Result := ZlibAdlerUpdate(AAdler, AData, ALen);
end;



initialization
  InitCriticalSection(GOnceLock);
finalization
  DoneCriticalSection(GOnceLock);
end.
