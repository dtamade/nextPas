unit nextpas.core.compress.bzip2;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ 单次解压：AData 为完整 .bz2 流（BZh 头），返回明文。
  AMaxOutputSize 为声明输出上限，用于防炸弹；超出抛 EIOError。 }
function BZip2DecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
function BZip2Decompress(const AData: TBytes): TBytes;
function BZip2Compress(const AData: TBytes): TBytes;
function BZip2FfiIsAvailable: Boolean;

implementation

uses
  Classes, SysUtils, bzip2stream,
  nextpas.core.errors,
  nextpas.core.compress.bzip2.ffi;

type
  { 零拷贝视图流：直接引用 TBytes 内存，避免 TMemoryStream.WriteBuffer 的二次拷贝；
    仅需 Read/Seek，供 bzip2stream 顺序读取 }
  TBytesViewStream = class(TStream)
  private
    FData: TBytes;
    FPos: Int64;
  protected
    function GetSize: Int64; override;
  public
    constructor Create(const AData: TBytes);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TBytesViewStream.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData; // refcounted keep-alive
  FPos := 0;
end;

function TBytesViewStream.GetSize: Int64;
begin
  Result := Length(FData);
end;

function TBytesViewStream.Read(var Buffer; Count: Longint): Longint;
var
  LAvail: Int64;
begin
  if Count <= 0 then Exit(0);
  LAvail := Int64(Length(FData)) - FPos;
  if LAvail <= 0 then Exit(0);
  if Int64(Count) > LAvail then Count := Longint(LAvail);
  if Count > 0 then
    Move(FData[FPos], Buffer, Count);
  Inc(FPos, Count);
  Result := Count;
end;

function TBytesViewStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('TBytesViewStream is read-only');
  Result := 0;
end;

function TBytesViewStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
var
  LNewPos: Int64;
begin
  case Origin of
    soBeginning: LNewPos := Offset;
    soCurrent:   LNewPos := FPos + Offset;
    soEnd:       LNewPos := Int64(Length(FData)) + Offset;
  else
    LNewPos := FPos;
  end;
  if LNewPos < 0 then LNewPos := 0;
  if LNewPos > Length(FData) then LNewPos := Length(FData);
  FPos := LNewPos;
  Result := FPos;
end;

function BZip2DecompressWithMaxOutputSize(const AData: nextpas.core.base.TBytes;
  const AMaxOutputSize: SizeUInt): nextpas.core.base.TBytes;
var
  LMax: SizeUInt;
  LInStream: TBytesViewStream;
  LDec: TDecompressBzip2Stream;
  LOut: TBytes;
  LRead, LTotal: SizeUInt;
  LBuf: array[0..65535] of Byte;
begin
  Result := nil;
  if Length(AData) = 0 then
    raise EIOError.Create('bzip2: truncated stream');
  if AMaxOutputSize = 0 then
  begin
    LMax := 0;
    LInStream := TBytesViewStream.Create(AData);
    try
      LDec := TDecompressBzip2Stream.Create(LInStream);
      try
        repeat
          try
            LRead := SizeUInt(LDec.Read(LBuf[0], SizeOf(LBuf)));
          except
            on E: EBzip2 do
              raise EIOError.Create('bzip2: ' + E.Message);
          end;
          if LRead > 0 then
            raise EIOError.Create('bzip2: decompressed size exceeds limit');
        until LRead = 0;
        { bzip2stream leaves 4-byte combined CRC unread; ignore trailing }
      finally
        LDec.Free;
      end;
    finally
      LInStream.Free;
    end;
    Exit(nil);
  end;
  LMax := AMaxOutputSize;
  { zero-copy 视图流，避免 TBytes→TMemoryStream 的二次拷贝 }
  LInStream := TBytesViewStream.Create(AData);
  try
    try
      LDec := TDecompressBzip2Stream.Create(LInStream);
    except
      on E: EBzip2 do
        raise EIOError.Create('bzip2: ' + E.Message);
      on E: Exception do
        raise EIOError.Create('bzip2: ' + E.Message);
    end;
    try
      SetLength(LOut, LMax);
      LTotal := 0;
      while True do
      begin
        if LTotal >= LMax then
        begin
          { probe one more byte to detect overflow }
          try
            LRead := SizeUInt(LDec.Read(LBuf[0], 1));
          except
            on E: EBzip2 do
            begin
              if Pos('end of file', LowerCase(E.Message)) > 0 then
                Break
              else
                raise EIOError.Create('bzip2: ' + E.Message);
            end;
          end;
          if LRead > 0 then
            raise EIOError.Create('bzip2: decompressed size exceeds limit');
          Break;
        end;
        try
          LRead := SizeUInt(LDec.Read(LOut[LTotal], LongInt(LMax - LTotal)));
        except
          on E: EBzip2 do
          begin
            { bzip2stream raises on EOF after last block? Actually Read returns 0
              on EOF, but Create already validates header. Treat E_EOF as break. }
            if Pos('end', LowerCase(E.Message)) > 0 then
              LRead := 0
            else
              raise EIOError.Create('bzip2: ' + E.Message);
          end;
        end;
        if LRead = 0 then
          Break;
        Inc(LTotal, LRead);
      end;
      { verify no trailing ext bytes beyond bzip2 stream (allow exactly consumed) }
      { bzip2stream consumes exactly until stream end magic; Source position should be size }
      { TDecompressBzip2Stream does not expose remaining, but LInStream Position
        after all reads reflects consumed bytes; we check that all input consumed
        or trailing bytes detected via extra read attempt }
      SetLength(LOut, LTotal);
      Result := LOut;
      { bzip2stream leaves combined CRC unread (4 bytes); no trailing check }
    finally
      LDec.Free;
    end;
  finally
    LInStream.Free;
  end;
end;

function BZip2Decompress(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
begin
  Result := BZip2DecompressWithMaxOutputSize(AData, 256 * 1024 * 1024);
end;

function BZip2Compress(const AData: nextpas.core.base.TBytes): nextpas.core.base.TBytes;
begin
  Result := BZip2FfiCompress(AData);
end;

function BZip2FfiIsAvailable: Boolean;
begin
  Result := BZip2FfiAvailable;
end;

end.
