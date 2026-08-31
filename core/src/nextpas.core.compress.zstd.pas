unit nextpas.core.compress.zstd;

{**
 * @desc zstd 门面：one-shot 压缩/解压（libzstd ffi 路径）。
 * ZstdDecompress 优先用帧内声明的内容长度直接解；管道产物等无内容
 * 长度帧（CONTENTSIZE_UNKNOWN）自动回退 DStream 流式解。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.compress.zstd.ffi;

const
  { default clevel, mirrors ZSTD_CLEVEL_DEFAULT }
  ZSTD_DEFAULT_LEVEL = 3;

{ Compress AData at ALevel (1..22; library clamps out-of-range values) }
function ZstdCompress(const AData: TBytes;
  ALevel: Integer = ZSTD_DEFAULT_LEVEL): TBytes;

{ Decompress a complete zstd frame; raises EIOError on malformed input }
function ZstdDecompress(const AData: TBytes): TBytes;

{ Library-side worst-case bound for compressed size }
function ZstdCompressBound(const ASize: SizeUInt): SizeUInt;

{ Runtime libzstd version string (e.g. "1.5.7") }
function ZstdVersionString: string;

implementation

const
  { unsigned views of the sentinel frame-content sizes from zstd.h }
  CONTENTSIZE_UNKNOWN = QWord(Int64(-1));
  CONTENTSIZE_ERROR = QWord(Int64(-2));

function BytesToPtr(const AData: TBytes): Pointer;
begin
  if Length(AData) > 0 then
    Result := @AData[0]
  else
    Result := nil;
end;

procedure RaiseIfZstdError(ARawResult: SizeUInt; const AContext: string);
var
  ErrName: PAnsiChar;
begin
  if ZSTD_isError(ARawResult) <> 0 then
  begin
    ErrName := ZSTD_getErrorName(ARawResult);
    raise EIOError.Create('zstd: ' + AContext + ' failed: ' +
      string(PAnsiChar(ErrName)));
  end;
end;

function ZstdCompress(const AData: TBytes;
  ALevel: Integer = ZSTD_DEFAULT_LEVEL): TBytes;
var
  Bound: SizeUInt;
  Written: SizeUInt;
begin
  Result := nil;
  if Length(AData) = 0 then
  begin
    // zstd frames of empty input are legal but the one-shot API needs no
    // round trip for them; an empty byte set compresses to nothing here
    SetLength(Result, 0);
    Exit;
  end;
  Bound := ZSTD_compressBound(SizeUInt(Length(AData)));
  SetLength(Result, Bound);
  Written := ZSTD_compress(@Result[0], Bound,
    BytesToPtr(AData), SizeUInt(Length(AData)), ALevel);
  RaiseIfZstdError(Written, 'compress');
  SetLength(Result, Written);
end;

function DecompressWithKnownSize(const AData: TBytes;
  AFrameSize: QWord): TBytes;
var
  Written: SizeUInt;
begin
  if AFrameSize > QWord(High(SizeInt)) then
    raise EIOError.Create('zstd: declared content size exceeds addressable memory');
  SetLength(Result, AFrameSize);
  Written := ZSTD_decompress(@Result[0], SizeUInt(Length(Result)),
    BytesToPtr(AData), SizeUInt(Length(AData)));
  RaiseIfZstdError(Written, 'decompress');
  if Written <> SizeUInt(Length(Result)) then
    SetLength(Result, Written);
end;

type
  TDStreamPtr = PZSTDDStream;

function DecompressStreaming(const AData: TBytes): TBytes;
var
  Stream: TDStreamPtr;
  OutBuf: TZSTDOutBuffer;
  InBuf: TZSTDInBuffer;
  Chunk: UInt64;
  Total, LastPos, Ret: SizeUInt;
  Done: Boolean;
begin
  Result := nil;
  Total := 0;
  Stream := ZSTD_createDStream();
  if Stream = nil then
    raise EIOError.Create('zstd: cannot create decompression stream');
  try
    RaiseIfZstdError(ZSTD_initDStream(Stream), 'init stream');
    InBuf.src := BytesToPtr(AData);
    InBuf.size := SizeUInt(Length(AData));
    InBuf.pos := 0;
    repeat
      // grow by generous chunks; streaming is only hit when the producer
      // omitted the content size (pipes), so exact pre-sizing is impossible
      if Total = 0 then
        Chunk := 256 * 1024
      else
        Chunk := Total;
      SetLength(Result, Total + SizeInt(Chunk));
      OutBuf.dst := @Result[Total];
      OutBuf.size := Chunk;
      OutBuf.pos := 0;
      LastPos := InBuf.pos;
      Ret := ZSTD_decompressStream(Stream, @OutBuf, @InBuf);
      RaiseIfZstdError(Ret, 'stream decompress');
      Inc(Total, OutBuf.pos);
      Done := (Ret = 0) and (InBuf.pos >= InBuf.size);
      if (not Done) and (OutBuf.pos < Chunk) and (InBuf.pos = LastPos) then
        raise EIOError.Create('zstd: truncated or corrupt frame');
    until Done;
  finally
    ZSTD_freeDStream(Stream);
  end;
  SetLength(Result, Total);
end;

function ZstdDecompress(const AData: TBytes): TBytes;
var
  FrameSize: QWord;
begin
  Result := nil;
  if Length(AData) = 0 then
    raise EIOError.Create('zstd: empty input is not a valid frame');
  FrameSize := ZSTD_getFrameContentSize(BytesToPtr(AData),
    SizeUInt(Length(AData)));
  if (FrameSize = CONTENTSIZE_UNKNOWN) or (FrameSize = CONTENTSIZE_ERROR) then
    Result := DecompressStreaming(AData)
  else
    Result := DecompressWithKnownSize(AData, FrameSize);
end;

function ZstdCompressBound(const ASize: SizeUInt): SizeUInt;
begin
  Result := ZSTD_compressBound(ASize);
end;

function ZstdVersionString: string;
var
  S: PAnsiChar;
begin
  S := ZSTD_versionString();
  if S <> nil then
    Result := string(AnsiString(S))
  else
    Result := '';
end;

end.
