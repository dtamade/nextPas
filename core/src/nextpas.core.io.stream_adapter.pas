unit nextpas.core.io.stream_adapter;

{$I nextpas.core.settings.inc}

interface

uses
  Classes,
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.util;

type
  TCoreSeekOrigin = nextpas.core.io.base.TSeekOrigin;
  INextPasReader = nextpas.core.io.intf.IReader;
  INextPasWriter = nextpas.core.io.intf.IWriter;
  INextPasStream = nextpas.core.io.intf.IStream;
  INextPasByteReader = nextpas.core.io.intf.IByteReader;
  INextPasByteWriter = nextpas.core.io.intf.IByteWriter;

  TStreamWrapper = class(TInterfacedObject, INextPasReader, INextPasWriter,
    INextPasStream, INextPasByteReader, INextPasByteWriter)
  private
    FStream: TStream;
    FOwnsStream: Boolean;
  public
    constructor Create(AStream: TStream; AOwnsStream: Boolean = False);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TCoreSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function ReadByte: Byte;
    procedure WriteByte(const AValue: Byte);
    property InnerStream: TStream read FStream;
  end;

  TStreamFromIStream = class(TStream)
  private
    FInner: INextPasStream;
  protected
    function GetPosition: Int64; override;
    procedure SetPosition(const Pos: Int64); override;
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); override;
  public
    constructor Create(const AStream: INextPasStream);
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override; overload;
    function Seek(const Offset: Int64; Origin: Classes.TSeekOrigin): Int64; override; overload;
    function CopyFrom(Source: TStream; Count: Int64): Int64; reintroduce;
    function ReadByte: Byte; reintroduce;
    procedure WriteByte(b: Byte); reintroduce;
    property InnerStream: INextPasStream read FInner;
  end;

function WrapTStream(AStream: TStream; AOwnsStream: Boolean = False): INextPasStream;
function WrapIStream(AStream: INextPasStream): TStream;
function WrapReader(AStream: TStream): INextPasReader;
function WrapWriter(AStream: TStream): INextPasWriter;
function IoReadAllLimited(const ASrc: nextpas.core.io.intf.IReader;
  const AMaxSize: Int64): nextpas.core.base.TBytes;

implementation

uses
  SysUtils,
  nextpas.core.errors;

const
  STREAM_ADAPTER_COPY_BUF_SIZE = 32768;

function ToClassesSeekOrigin(const AOrigin: TCoreSeekOrigin): Classes.TSeekOrigin;
begin
  case AOrigin of
    nextpas.core.io.base.soBeginning: Result := Classes.soBeginning;
    nextpas.core.io.base.soCurrent: Result := Classes.soCurrent;
    nextpas.core.io.base.soEnd: Result := Classes.soEnd;
  end;
end;

function ToCoreSeekOrigin(const AOrigin: Classes.TSeekOrigin): TCoreSeekOrigin;
begin
  case AOrigin of
    Classes.soBeginning: Result := nextpas.core.io.base.soBeginning;
    Classes.soCurrent: Result := nextpas.core.io.base.soCurrent;
    Classes.soEnd: Result := nextpas.core.io.base.soEnd;
  end;
end;

function SeekOriginFromWord(const AOrigin: Word): Classes.TSeekOrigin;
begin
  case AOrigin of
    0: Result := Classes.soBeginning;
    1: Result := Classes.soCurrent;
    2: Result := Classes.soEnd;
  else
    raise EArgumentError.Create('TStreamFromIStream.Seek32: invalid origin');
  end;
end;

{ TStreamWrapper }

constructor TStreamWrapper.Create(AStream: TStream; AOwnsStream: Boolean);
begin
  inherited Create;
  FStream := AStream;
  FOwnsStream := AOwnsStream;
end;

destructor TStreamWrapper.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TStreamWrapper.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRead: LongInt;
begin
  if (FStream = nil) or (ACount = 0) then
    Exit(0);
  LRead := FStream.Read(ABuf, LongInt(ACount));
  if LRead <= 0 then
    Exit(0);
  Result := SizeUInt(LRead);
end;

function TStreamWrapper.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LWritten: LongInt;
begin
  if (FStream = nil) or (ACount = 0) then
    Exit(0);
  LWritten := FStream.Write(ABuf, LongInt(ACount));
  if LWritten <= 0 then
    Exit(0);
  Result := SizeUInt(LWritten);
end;

function TStreamWrapper.Seek(const AOffset: Int64;
  const AOrigin: TCoreSeekOrigin): Int64;
begin
  if FStream = nil then
    Exit(0);
  Result := FStream.Seek(AOffset, ToClassesSeekOrigin(AOrigin));
end;

procedure TStreamWrapper.Close;
var
  LStream: TStream;
begin
  if not FOwnsStream then
    Exit;
  LStream := FStream;
  FStream := nil;
  FOwnsStream := False;
  if LStream <> nil then
    FreeAndNil(LStream);
end;

function TStreamWrapper.GetSize: Int64;
begin
  if FStream = nil then
    Exit(0);
  Result := FStream.Size;
end;

function TStreamWrapper.GetPosition: Int64;
begin
  if FStream = nil then
    Exit(0);
  Result := FStream.Position;
end;

procedure TStreamWrapper.SetPosition(const AValue: Int64);
begin
  if FStream = nil then
    Exit;
  FStream.Position := AValue;
end;

function TStreamWrapper.ReadByte: Byte;
begin
  if FStream = nil then
    Exit(0);
  Result := FStream.ReadByte;
end;

procedure TStreamWrapper.WriteByte(const AValue: Byte);
begin
  if FStream = nil then
    Exit;
  FStream.WriteByte(AValue);
end;

{ TStreamFromIStream }

constructor TStreamFromIStream.Create(const AStream: INextPasStream);
begin
  inherited Create;
  FInner := AStream;
end;

function TStreamFromIStream.GetPosition: Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Position;
end;

procedure TStreamFromIStream.SetPosition(const Pos: Int64);
begin
  if FInner = nil then
    Exit;
  FInner.Position := Pos;
end;

function TStreamFromIStream.GetSize: Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Size;
end;

procedure TStreamFromIStream.SetSize(const NewSize: Int64);
begin
  raise ENotSupportedError.Create('TStreamFromIStream.SetSize: not supported');
end;

function TStreamFromIStream.Read(var Buffer; Count: Longint): Longint;
var
  LRead: SizeUInt;
begin
  if (FInner = nil) or (Count <= 0) then
    Exit(0);
  LRead := FInner.Read(Buffer, SizeUInt(Count));
  if LRead > SizeUInt(High(LongInt)) then
    Result := High(LongInt)
  else
    Result := LongInt(LRead);
end;

function TStreamFromIStream.Write(const Buffer; Count: Longint): Longint;
var
  LWritten: SizeUInt;
begin
  if (FInner = nil) or (Count <= 0) then
    Exit(0);
  LWritten := FInner.Write(Buffer, SizeUInt(Count));
  if LWritten > SizeUInt(High(LongInt)) then
    Result := High(LongInt)
  else
    Result := LongInt(LWritten);
end;

function TStreamFromIStream.Seek(Offset: Longint; Origin: Word): Longint;
var
  LPosition: Int64;
begin
  LPosition := Seek(Int64(Offset), SeekOriginFromWord(Origin));
  if (LPosition < Low(LongInt)) or (LPosition > High(LongInt)) then
    raise EIOError.Create('TStreamFromIStream.Seek32: result exceeds 32-bit range');
  Result := LongInt(LPosition);
end;

function TStreamFromIStream.Seek(const Offset: Int64;
  Origin: Classes.TSeekOrigin): Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Seek(Offset, ToCoreSeekOrigin(Origin));
end;

function TStreamFromIStream.CopyFrom(Source: TStream; Count: Int64): Int64;
var
  LBuf: array[0..STREAM_ADAPTER_COPY_BUF_SIZE - 1] of Byte;
  LRead: LongInt;
  LToRead: LongInt;
  LWrittenTotal: SizeUInt;
  LWrittenNow: SizeUInt;
begin
  Result := 0;
  if (FInner = nil) or (Source = nil) or (Count < 0) then
    Exit(0);
  if Count = 0 then
  begin
    Source.Position := 0;
    repeat
      LRead := Source.Read(LBuf[0], STREAM_ADAPTER_COPY_BUF_SIZE);
      if LRead <= 0 then
        Break;
      LWrittenTotal := 0;
      while LWrittenTotal < SizeUInt(LRead) do
      begin
        LWrittenNow := FInner.Write(LBuf[LWrittenTotal], SizeUInt(LRead) - LWrittenTotal);
        if LWrittenNow = 0 then
          raise EIOError.Create('TStreamFromIStream.CopyFrom: write returned 0');
        Inc(LWrittenTotal, LWrittenNow);
      end;
      Inc(Result, LRead);
    until False;
    Exit;
  end;
  while Count > 0 do
  begin
    if Count > STREAM_ADAPTER_COPY_BUF_SIZE then
      LToRead := STREAM_ADAPTER_COPY_BUF_SIZE
    else
      LToRead := LongInt(Count);
    Source.ReadBuffer(LBuf[0], LToRead);
    LWrittenTotal := 0;
    while LWrittenTotal < SizeUInt(LToRead) do
    begin
      LWrittenNow := FInner.Write(LBuf[LWrittenTotal], SizeUInt(LToRead) - LWrittenTotal);
      if LWrittenNow = 0 then
        raise EIOError.Create('TStreamFromIStream.CopyFrom: write returned 0');
      Inc(LWrittenTotal, LWrittenNow);
    end;
    Inc(Result, LToRead);
    Dec(Count, LToRead);
  end;
end;

function TStreamFromIStream.ReadByte: Byte;
var
  LByteReader: INextPasByteReader;
begin
  if (FInner <> nil) and Supports(FInner, INextPasByteReader, LByteReader) then
    Exit(LByteReader.ReadByte);
  Result := inherited ReadByte;
end;

procedure TStreamFromIStream.WriteByte(b: Byte);
var
  LByteWriter: INextPasByteWriter;
begin
  if (FInner <> nil) and Supports(FInner, INextPasByteWriter, LByteWriter) then
  begin
    LByteWriter.WriteByte(b);
    Exit;
  end;
  inherited WriteByte(b);
end;

function WrapTStream(AStream: TStream; AOwnsStream: Boolean): INextPasStream;
begin
  if AStream = nil then
    Exit(nil);
  Result := TStreamWrapper.Create(AStream, AOwnsStream);
end;

function WrapIStream(AStream: INextPasStream): TStream;
begin
  if AStream = nil then
    Exit(nil);
  Result := TStreamFromIStream.Create(AStream);
end;

function WrapReader(AStream: TStream): INextPasReader;
begin
  Result := WrapTStream(AStream, False);
end;

function WrapWriter(AStream: TStream): INextPasWriter;
begin
  if AStream = nil then
    Exit(nil);
  Result := TStreamWrapper.Create(AStream, False);
end;

function IoReadAllLimited(const ASrc: nextpas.core.io.intf.IReader;
  const AMaxSize: Int64): nextpas.core.base.TBytes;
var
  LBuf: array[0..STREAM_ADAPTER_COPY_BUF_SIZE - 1] of Byte;
  LRead, LToRead: SizeUInt;
  LCap: SizeUInt;
  LSize: Int64;
  LRemaining: Int64;
begin
  if ASrc = nil then
    Exit(nil);
  if AMaxSize < 0 then
    raise EArgumentError.Create('IoReadAllLimited: negative max size');

  Result := nil;
  LCap := 0;
  LSize := 0;
  while True do
  begin
    LRemaining := AMaxSize - LSize;
    if LRemaining > STREAM_ADAPTER_COPY_BUF_SIZE then
      LToRead := STREAM_ADAPTER_COPY_BUF_SIZE
    else if LRemaining > 0 then
      LToRead := SizeUInt(LRemaining)
    else
      LToRead := 1;

    LRead := ASrc.Read(LBuf[0], LToRead);
    if LRead = 0 then
      Break;
    if LSize + Int64(LRead) > AMaxSize then
      raise EIOError.Create('IoReadAllLimited: size limit exceeded');

    if Int64(LCap) < LSize + Int64(LRead) then
    begin
      if LCap = 0 then
        LCap := STREAM_ADAPTER_COPY_BUF_SIZE
      else
        LCap := LCap * 2;
      if Int64(LCap) < LSize + Int64(LRead) then
        LCap := SizeUInt(LSize + Int64(LRead));
      SetLength(Result, LCap);
    end;

    Move(LBuf[0], Result[LSize], LRead);
    Inc(LSize, Int64(LRead));
  end;

  SetLength(Result, LSize);
end;

end.
