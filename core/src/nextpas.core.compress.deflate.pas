unit nextpas.core.compress.deflate;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.intf,
  nextpas.core.compress.base,
  nextpas.core.compress.intf;

function CreateDeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel = clDefault): ICompressWriter;
function CreateDeflateReader(const ASrc: IReader): IDecompressReader;

function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel = clDefault): TBytes;
function DeflateDecompress(const AData: TBytes): TBytes;

implementation

uses
  zlib, nextpas.core.errors;

function LevelToZlib(const ALevel: TCompressionLevel): Int32;
begin
  case ALevel of
    clNone: Result := Z_NO_COMPRESSION;
    clFastest: Result := Z_BEST_SPEED;
    clDefault: Result := Z_DEFAULT_COMPRESSION;
    clBest: Result := Z_BEST_COMPRESSION;
  else
    Result := Z_DEFAULT_COMPRESSION;
  end;
end;

type
  TDeflateWriter = class(TInterfacedObject, IWriter, ICompressWriter)
  private
    FDst: IWriter;
    FStream: z_stream;
    FBuf: array[0..COMPRESS_BUF_SIZE - 1] of Byte;
    FInitialized: Boolean;
    procedure FlushOutput(AFlush: Int32);
  public
    constructor Create(const ADst: IWriter; ALevel: Int32);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    procedure Close;
  end;

  TDeflateReader = class(TInterfacedObject, IReader, IDecompressReader)
  private
    FSrc: IReader;
    FStream: z_stream;
    FInBuf: array[0..COMPRESS_BUF_SIZE - 1] of Byte;
    FInitialized: Boolean;
    FDone: Boolean;
  public
    constructor Create(const ASrc: IReader);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

{ TDeflateWriter }

constructor TDeflateWriter.Create(const ADst: IWriter; ALevel: Int32);
begin
  inherited Create;
  FDst := ADst;
  FillChar(FStream, SizeOf(FStream), 0);
  if deflateInit(FStream, ALevel) <> Z_OK then
    raise EIOError.Create('deflateInit failed');
  FInitialized := True;
end;

destructor TDeflateWriter.Destroy;
begin
  if FInitialized then
  begin
    FlushOutput(Z_FINISH);
    deflateEnd(FStream);
  end;
  inherited;
end;

procedure TDeflateWriter.FlushOutput(AFlush: Int32);
var
  LHave: SizeUInt;
begin
  repeat
    FStream.next_out := @FBuf[0];
    FStream.avail_out := COMPRESS_BUF_SIZE;
    deflate(FStream, AFlush);
    LHave := COMPRESS_BUF_SIZE - FStream.avail_out;
    if LHave > 0 then
      FDst.Write(FBuf[0], LHave);
  until FStream.avail_out <> 0;
end;

function TDeflateWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then Exit(0);
  FStream.next_in := @ABuf;
  FStream.avail_in := ACount;
  FlushOutput(Z_NO_FLUSH);
  Result := ACount;
end;

procedure TDeflateWriter.Flush;
begin
  FlushOutput(Z_SYNC_FLUSH);
end;

procedure TDeflateWriter.Close;
begin
  if FInitialized then
  begin
    FlushOutput(Z_FINISH);
    deflateEnd(FStream);
    FInitialized := False;
  end;
end;

{ TDeflateReader }

constructor TDeflateReader.Create(const ASrc: IReader);
begin
  inherited Create;
  FSrc := ASrc;
  FillChar(FStream, SizeOf(FStream), 0);
  if inflateInit(FStream) <> Z_OK then
    raise EIOError.Create('inflateInit failed');
  FInitialized := True;
  FDone := False;
end;

destructor TDeflateReader.Destroy;
begin
  if FInitialized then
    inflateEnd(FStream);
  inherited;
end;

function TDeflateReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRet: Int32;
  LRead: SizeUInt;
begin
  if FDone or (ACount = 0) then Exit(0);
  FStream.next_out := @ABuf;
  FStream.avail_out := ACount;
  while FStream.avail_out > 0 do
  begin
    if FStream.avail_in = 0 then
    begin
      LRead := FSrc.Read(FInBuf[0], COMPRESS_BUF_SIZE);
      if LRead = 0 then
      begin
        FDone := True;
        Break;
      end;
      FStream.next_in := @FInBuf[0];
      FStream.avail_in := LRead;
    end;
    LRet := inflate(FStream, Z_NO_FLUSH);
    if LRet = Z_STREAM_END then
    begin
      FDone := True;
      Break;
    end;
    if (LRet <> Z_OK) and (LRet <> Z_BUF_ERROR) then
      raise EIOError.Create('inflate failed (' + IntToStr(LRet) + ')');
  end;
  Result := ACount - FStream.avail_out;
end;

procedure TDeflateReader.Close;
begin
  if FInitialized then
  begin
    inflateEnd(FStream);
    FInitialized := False;
  end;
end;

{ Factory }

function CreateDeflateWriter(const ADst: IWriter;
  const ALevel: TCompressionLevel): ICompressWriter;
begin
  Result := TDeflateWriter.Create(ADst, LevelToZlib(ALevel));
end;

function CreateDeflateReader(const ASrc: IReader): IDecompressReader;
begin
  Result := TDeflateReader.Create(ASrc);
end;

{ One-shot }

function DeflateCompress(const AData: TBytes;
  const ALevel: TCompressionLevel): TBytes;
var
  LDstLen: ULong;
begin
  if Length(AData) = 0 then
    Exit(nil);
  LDstLen := compressBound(Length(AData));
  SetLength(Result, LDstLen);
  if compress2(@Result[0], @LDstLen, @AData[0], Length(AData), LevelToZlib(ALevel)) <> Z_OK then
    raise EIOError.Create('deflate compress failed');
  SetLength(Result, LDstLen);
end;

function DeflateDecompress(const AData: TBytes): TBytes;
var
  LDstLen: ULong;
  LRet: Int32;
begin
  if Length(AData) = 0 then
    Exit(nil);
  LDstLen := Length(AData) * 4;
  repeat
    SetLength(Result, LDstLen);
    LRet := uncompress(@Result[0], @LDstLen, @AData[0], Length(AData));
    if LRet = Z_BUF_ERROR then
      LDstLen := LDstLen * 2
    else if LRet <> Z_OK then
      raise EIOError.Create('deflate decompress failed (' + IntToStr(LRet) + ')');
  until LRet = Z_OK;
  SetLength(Result, LDstLen);
end;

end.
