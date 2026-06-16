program test_stream_adapter;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  Classes,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.io.stream_adapter;

type
  INextPasReader = nextpas.core.io.intf.IReader;
  INextPasWriter = nextpas.core.io.intf.IWriter;
  INextPasStream = nextpas.core.io.intf.IStream;
  INextPasByteReader = nextpas.core.io.intf.IByteReader;
  INextPasByteWriter = nextpas.core.io.intf.IByteWriter;

var
  T: TTestRunner;

type
  TObservedMemoryStream = class(TMemoryStream)
  private
    FDestroyedFlag: PBoolean;
  public
    constructor Create(ADestroyedFlag: PBoolean);
    destructor Destroy; override;
  end;

  TSeekTrackingStream = class(TMemoryStream)
  public
    UsedSeek32: Boolean;
    UsedSeek64: Boolean;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    function Seek(const Offset: Int64; Origin: Classes.TSeekOrigin): Int64; override;
  end;

  TTrackedIStream = class(TInterfacedObject, INextPasStream)
  protected
    FInner: INextPasStream;
  private
    FDestroyedFlag: PBoolean;
  public
    constructor Create(const AInner: INextPasStream; ADestroyedFlag: PBoolean = nil);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt; virtual;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt; virtual;
    function Seek(const AOffset: Int64;
      const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64; virtual;
    procedure Close; virtual;
    function GetSize: Int64; virtual;
    function GetPosition: Int64; virtual;
    procedure SetPosition(const AValue: Int64); virtual;
  end;

  TByteAwareStream = class(TTrackedIStream, INextPasByteReader, INextPasByteWriter)
  public
    ReadByteCalls: Integer;
    WriteByteCalls: Integer;
    function ReadByte: Byte;
    procedure WriteByte(const AValue: Byte);
  end;

  TFarSeekStream = class(TTrackedIStream)
  public
    function Seek(const AOffset: Int64;
      const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64; override;
  end;

constructor TObservedMemoryStream.Create(ADestroyedFlag: PBoolean);
begin
  inherited Create;
  FDestroyedFlag := ADestroyedFlag;
  if FDestroyedFlag <> nil then
    FDestroyedFlag^ := False;
end;

destructor TObservedMemoryStream.Destroy;
begin
  if FDestroyedFlag <> nil then
    FDestroyedFlag^ := True;
  inherited Destroy;
end;

function TSeekTrackingStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  UsedSeek32 := True;
  Result := inherited Seek(Offset, Origin);
end;

function TSeekTrackingStream.Seek(const Offset: Int64;
  Origin: Classes.TSeekOrigin): Int64;
begin
  UsedSeek64 := True;
  Result := inherited Seek(Offset, Origin);
end;

constructor TTrackedIStream.Create(const AInner: INextPasStream;
  ADestroyedFlag: PBoolean);
begin
  inherited Create;
  FInner := AInner;
  FDestroyedFlag := ADestroyedFlag;
  if FDestroyedFlag <> nil then
    FDestroyedFlag^ := False;
end;

destructor TTrackedIStream.Destroy;
begin
  if FDestroyedFlag <> nil then
    FDestroyedFlag^ := True;
  inherited Destroy;
end;

function TTrackedIStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Read(ABuf, ACount);
end;

function TTrackedIStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Write(ABuf, ACount);
end;

function TTrackedIStream.Seek(const AOffset: Int64;
  const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Seek(AOffset, AOrigin);
end;

procedure TTrackedIStream.Close;
begin
  if FInner <> nil then
    FInner.Close;
end;

function TTrackedIStream.GetSize: Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Size;
end;

function TTrackedIStream.GetPosition: Int64;
begin
  if FInner = nil then
    Exit(0);
  Result := FInner.Position;
end;

procedure TTrackedIStream.SetPosition(const AValue: Int64);
begin
  if FInner = nil then
    Exit;
  FInner.Position := AValue;
end;

function TByteAwareStream.ReadByte: Byte;
var
  LReader: INextPasByteReader;
begin
  Inc(ReadByteCalls);
  if Supports(FInner, INextPasByteReader, LReader) then
    Exit(LReader.ReadByte);
  Result := 0;
end;

procedure TByteAwareStream.WriteByte(const AValue: Byte);
var
  LWriter: INextPasByteWriter;
begin
  Inc(WriteByteCalls);
  if Supports(FInner, INextPasByteWriter, LWriter) then
    LWriter.WriteByte(AValue);
end;

function TFarSeekStream.Seek(const AOffset: Int64;
  const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64;
begin
  Result := Int64(High(LongInt)) + 1;
end;

procedure CheckBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
var
  LI: Integer;
begin
  CheckEqual(Int64(Length(AExpected)), Int64(Length(AActual)),
    AMessage + ': length');
  for LI := 0 to High(AExpected) do
    if AExpected[LI] <> AActual[LI] then
      Fail(Format('%s: byte %d expected %d got %d',
        [AMessage, LI, AExpected[LI], AActual[LI]]));
end;

function ReadBytesFromTStream(AStream: TStream): TBytes;
begin
  Result := nil;
  SetLength(Result, AStream.Size);
  AStream.Position := 0;
  if Length(Result) > 0 then
    AStream.ReadBuffer(Result[0], Length(Result));
end;

function ReadBytesFromIStream(const AStream: INextPasStream): TBytes;
begin
  Result := nil;
  SetLength(Result, AStream.Size);
  AStream.Position := 0;
  if Length(Result) > 0 then
    AStream.Read(Result[0], Length(Result));
end;

procedure TestWrapFactoriesHandleNil;
begin
  Check(WrapTStream(nil) = nil, 'WrapTStream(nil) returns nil');
  Check(WrapIStream(nil) = nil, 'WrapIStream(nil) returns nil');
  Check(WrapReader(nil) = nil, 'WrapReader(nil) returns nil');
  Check(WrapWriter(nil) = nil, 'WrapWriter(nil) returns nil');
end;

procedure TestWrapTStreamDelegatesReadWriteSeek;
var
  LStream: TMemoryStream;
  LWrapped: INextPasStream;
  LWriter: INextPasWriter;
  LReader: INextPasReader;
  LWriteBuf: TBytes;
  LReadBuf: TBytes;
begin
  LStream := TMemoryStream.Create;
  try
    LWrapped := WrapTStream(LStream);
    LWriter := WrapWriter(LStream);
    LReader := WrapReader(LStream);

    LWriteBuf := TBytes.Create(10, 20, 30, 40);
    CheckEqual(Int64(4), Int64(LWriter.Write(LWriteBuf[0], Length(LWriteBuf))),
      'WrapWriter write count');
    CheckEqual(Int64(4), LWrapped.Size, 'wrapped size');
    CheckEqual(Int64(4), LWrapped.Position, 'wrapped position');
    CheckEqual(Int64(4), LStream.Size, 'backing stream size');

    CheckEqual(Int64(0), LWrapped.Seek(0, nextpas.core.io.base.soBeginning),
      'seek to beginning');
    SetLength(LReadBuf, 4);
    CheckEqual(Int64(4), Int64(LReader.Read(LReadBuf[0], Length(LReadBuf))),
      'WrapReader read count');
    CheckBytesEqual(LWriteBuf, LReadBuf, 'WrapTStream roundtrip');
  finally
    LStream.Free;
  end;
end;

procedure TestWrapTStreamUses64BitSeek;
var
  LStream: TSeekTrackingStream;
  LWrapped: INextPasStream;
begin
  LStream := TSeekTrackingStream.Create;
  try
    LWrapped := WrapTStream(LStream);
    LWrapped.Seek(0, nextpas.core.io.base.soBeginning);
    Check(LStream.UsedSeek64, 'IStream.Seek uses 64-bit TStream.Seek');
    Check(not LStream.UsedSeek32, 'IStream.Seek avoids 32-bit TStream.Seek');
  finally
    LStream.Free;
  end;
end;

procedure TestWrapTStreamCloseDefaultDoesNotOwn;
var
  LDestroyed: Boolean;
  LStream: TObservedMemoryStream;
  LWrapped: INextPasStream;
  LValue: Byte;
begin
  LDestroyed := False;
  LStream := TObservedMemoryStream.Create(@LDestroyed);
  try
    LWrapped := WrapTStream(LStream);
    LWrapped.Close;
    Check(not LDestroyed, 'default Close must not free backing stream');
    LValue := $5A;
    CheckEqual(Int64(1), Int64(LStream.Write(LValue, 1)),
      'backing stream remains writable');
  finally
    LStream.Free;
  end;
  Check(LDestroyed, 'manual stream free should still happen');
end;

procedure TestWrapTStreamCloseOwnsBackingStream;
var
  LDestroyed: Boolean;
  LWrapped: INextPasStream;
  LStream: TObservedMemoryStream;
  LByte: Byte;
begin
  LDestroyed := False;
  LStream := TObservedMemoryStream.Create(@LDestroyed);
  LWrapped := WrapTStream(LStream, True);
  LWrapped.Close;
  Check(LDestroyed, 'owned Close must free backing stream');
  LByte := 0;
  CheckEqual(Int64(0), Int64(LWrapped.Read(LByte, 1)),
    'closed owned wrapper reads as empty');
  CheckEqual(Int64(0), LWrapped.Size, 'closed owned wrapper size is zero');
end;

procedure TestWrapIStreamDelegatesReadWriteSeek;
var
  LInner: INextPasStream;
  LWrapped: TStream;
  LData: TBytes;
  LReadBuf: TBytes;
begin
  LInner := CreateBytesStream(16);
  LWrapped := WrapIStream(LInner);
  try
    LData := TBytes.Create(1, 2, 3, 4);
    CheckEqual(Int64(4), Int64(LWrapped.Write(LData[0], Length(LData))),
      'TStream write count');
    CheckEqual(Int64(4), LInner.Size, 'IStream size');
    CheckEqual(Int64(4), LInner.Position, 'IStream position');

    CheckEqual(Int64(1), LWrapped.Seek(1, Word(Ord(Classes.soBeginning))),
      '32-bit seek delegates');
    CheckEqual(Int64(1), LWrapped.Position, 'wrapped position');

    SetLength(LReadBuf, 3);
    CheckEqual(Int64(3), Int64(LWrapped.Read(LReadBuf[0], Length(LReadBuf))),
      'TStream read count');
    CheckBytesEqual(TBytes.Create(2, 3, 4), LReadBuf, 'WrapIStream roundtrip');
  finally
    LWrapped.Free;
  end;
end;

procedure TestWrapIStreamCopyFromHonorsCountAndWholeSource;
var
  LInner: INextPasStream;
  LWrapped: TStreamFromIStream;
  LSource: TMemoryStream;
  LData: TBytes;
begin
  LInner := CreateBytesStream(16);
  LWrapped := TStreamFromIStream(WrapIStream(LInner));
  LSource := TMemoryStream.Create;
  try
    LData := TBytes.Create(9, 8, 7, 6);
    LSource.WriteBuffer(LData[0], Length(LData));
    LSource.Position := 1;
    CheckEqual(Int64(2), LWrapped.CopyFrom(LSource, 2),
      'CopyFrom fixed count');
    CheckBytesEqual(TBytes.Create(8, 7), ReadBytesFromIStream(LInner),
      'CopyFrom fixed count content');

    LWrapped.Position := 0;
    LInner.Close;
  finally
    LSource.Free;
    LWrapped.Free;
  end;

  LInner := CreateBytesStream(16);
  LWrapped := TStreamFromIStream(WrapIStream(LInner));
  LSource := TMemoryStream.Create;
  try
    LData := TBytes.Create(1, 2, 3);
    LSource.WriteBuffer(LData[0], Length(LData));
    LSource.Position := 2;
    CheckEqual(Int64(3), LWrapped.CopyFrom(LSource, 0),
      'CopyFrom zero count copies whole source');
    CheckBytesEqual(LData, ReadBytesFromIStream(LInner),
      'CopyFrom zero count content');
  finally
    LSource.Free;
    LWrapped.Free;
  end;
end;

procedure TestWrapIStreamReadByteWriteBytePreferByteInterfaces;
var
  LInner: TByteAwareStream;
  LWrapped: TStreamFromIStream;
  LValue: Byte;
begin
  LInner := TByteAwareStream.Create(CreateBytesStream(16));
  LWrapped := TStreamFromIStream(WrapIStream(LInner));
  try
    LWrapped.WriteByte($7B);
    CheckEqual(Int64(1), Int64(LInner.WriteByteCalls),
      'WriteByte uses IByteWriter');
    LWrapped.Position := 0;
    LValue := LWrapped.ReadByte;
    Check(LValue = $7B, 'ReadByte returns written value');
    CheckEqual(Int64(1), Int64(LInner.ReadByteCalls),
      'ReadByte uses IByteReader');
  finally
    LWrapped.Free;
  end;
end;

procedure TestWrapIStreamKeepsStrongReference;
var
  LDestroyed: Boolean;
  LInner: INextPasStream;
  LWrapped: TStream;
  LByte: Byte;
begin
  LDestroyed := False;
  LInner := TTrackedIStream.Create(CreateBytesStream(16), @LDestroyed);
  LWrapped := WrapIStream(LInner);
  LInner := nil;
  try
    Check(not LDestroyed, 'wrapper should hold strong reference');
    LByte := 42;
    CheckEqual(Int64(1), Int64(LWrapped.Write(LByte, 1)),
      'wrapped stream remains usable after interface release');
    Check(not LDestroyed, 'underlying stream still alive while wrapper exists');
  finally
    LWrapped.Free;
  end;
  Check(LDestroyed, 'underlying stream released after wrapper free');
end;

procedure TestWrapIStreamSeek32OverflowRaises;
var
  LWrapped: TStream;
  LRaised: Boolean;
begin
  LWrapped := WrapIStream(TFarSeekStream.Create(CreateBytesStream(16)));
  try
    LRaised := False;
    try
      LWrapped.Seek(0, Word(Ord(Classes.soEnd)));
    except
      on E: Exception do
        LRaised := Pos('32-bit range', E.Message) > 0;
    end;
    Check(LRaised, '32-bit Seek must reject Int64 overflow');
  finally
    LWrapped.Free;
  end;
end;

procedure TestIoReadAllLimitedHandlesNilAndBoundaries;
var
  LData: TBytes;
  LInner: INextPasStream;
  LRaised: Boolean;
begin
  LData := IoReadAllLimited(nil, 16);
  CheckEqual(Int64(0), Int64(Length(LData)), 'nil reader returns empty bytes');

  LInner := CreateBytesStreamFrom(TBytes.Create(1, 2, 3));
  LData := IoReadAllLimited(LInner, 3);
  CheckBytesEqual(TBytes.Create(1, 2, 3), LData, 'exact limit succeeds');

  LInner := CreateBytesStreamFrom(TBytes.Create(1, 2, 3, 4));
  LRaised := False;
  try
    IoReadAllLimited(LInner, 3);
  except
    on E: EIOError do
      LRaised := Pos('limit', LowerCase(E.Message)) > 0;
  end;
  Check(LRaised, 'overflow limit raises EIOError');
end;

begin
  T := TTestRunner.Create('nextpas.core.io.stream_adapter');
  T.Run('Wrap factories handle nil', @TestWrapFactoriesHandleNil);
  T.Run('WrapTStream delegates read/write/seek', @TestWrapTStreamDelegatesReadWriteSeek);
  T.Run('WrapTStream uses 64-bit seek', @TestWrapTStreamUses64BitSeek);
  T.Run('WrapTStream close default does not own', @TestWrapTStreamCloseDefaultDoesNotOwn);
  T.Run('WrapTStream close owns backing stream', @TestWrapTStreamCloseOwnsBackingStream);
  T.Run('WrapIStream delegates read/write/seek', @TestWrapIStreamDelegatesReadWriteSeek);
  T.Run('WrapIStream CopyFrom bridges TStream sources', @TestWrapIStreamCopyFromHonorsCountAndWholeSource);
  T.Run('WrapIStream ReadByte/WriteByte prefer byte interfaces',
    @TestWrapIStreamReadByteWriteBytePreferByteInterfaces);
  T.Run('WrapIStream keeps strong reference', @TestWrapIStreamKeepsStrongReference);
  T.Run('WrapIStream 32-bit seek overflow raises', @TestWrapIStreamSeek32OverflowRaises);
  T.Run('IoReadAllLimited handles nil and boundaries',
    @TestIoReadAllLimitedHandlesNilAndBoundaries);
  T.Summary;
end.
