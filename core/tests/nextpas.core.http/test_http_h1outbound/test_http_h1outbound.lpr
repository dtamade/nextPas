program test_http_h1outbound;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.time.deadline,
  nextpas.core.http.impl.h1.outbound;

type
  TOverreportingWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TFakeRuntime = class(TInterfacedObject, ITcpStreamRuntime)
  private
    FResult: TTcpStreamIOResult;
    FWriteLimit: SizeUInt;
    FOverreport: Boolean;
    FWrittenData: string;
    FTryWriteCalls: Int32;
  public
    constructor Create(const AResult: TTcpStreamIOResult; const AWriteLimit: SizeUInt);
    constructor CreateOverreporting;
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    property WrittenData: string read FWrittenData;
    property TryWriteCalls: Int32 read FTryWriteCalls;
  end;

function TOverreportingWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount + 1;
end;

constructor TFakeRuntime.Create(const AResult: TTcpStreamIOResult;
  const AWriteLimit: SizeUInt);
begin
  inherited Create;
  FResult := AResult;
  FWriteLimit := AWriteLimit;
  FOverreport := False;
end;

constructor TFakeRuntime.CreateOverreporting;
begin
  inherited Create;
  FResult := tsiorOk;
  FWriteLimit := 0;
  FOverreport := True;
end;

function TFakeRuntime.NativeSocketHandle: PtrUInt;
begin
  Result := 0;
end;

procedure TFakeRuntime.SetBlocking(const ABlocking: Boolean);
begin
end;

function TFakeRuntime.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
begin
  ARead := 0;
  Result := tsiorWouldBlock;
end;

function TFakeRuntime.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LOld: SizeUInt;
begin
  Inc(FTryWriteCalls);
  AWritten := 0;
  Result := FResult;
  if Result <> tsiorOk then
    Exit;
  if FOverreport then
  begin
    AWritten := ACount + 1;
    Exit;
  end;
  AWritten := ACount;
  if AWritten > FWriteLimit then
    AWritten := FWriteLimit;
  if AWritten = 0 then
    Exit;
  LOld := SizeUInt(Length(FWrittenData));
  SetLength(FWrittenData, LOld + AWritten);
  Move(ABuf, FWrittenData[LOld + 1], AWritten);
end;

procedure WriteString(const ABuffer: IH1OutboundBuffer; const AValue: string);
begin
  if Length(AValue) > 0 then
    CheckEqual(Int64(Length(AValue)),
      Int64(ABuffer.Write(AValue[1], SizeUInt(Length(AValue)))),
      'write returns input byte count');
end;

procedure TestTryDrainWouldBlockDoesNotConsumePendingBytes;
var
  LBuffer: IH1OutboundBuffer;
  LRuntimeObj: TFakeRuntime;
  LRuntime: ITcpStreamRuntime;
  LWritten: SizeUInt;
  LResult: TTcpStreamIOResult;
begin
  LBuffer := NewH1OutboundBuffer;
  WriteString(LBuffer, 'abcdef');
  LRuntimeObj := TFakeRuntime.Create(tsiorWouldBlock, 0);
  LRuntime := LRuntimeObj as ITcpStreamRuntime;

  LResult := LBuffer.TryDrainTo(LRuntime, LWritten);

  CheckEqual(Int64(Ord(tsiorWouldBlock)), Int64(Ord(LResult)),
    'TryDrainTo returns would-block');
  CheckEqual(Int64(0), Int64(LWritten), 'would-block reports zero written');
  CheckEqual(Int64(6), Int64(LBuffer.PendingBytes),
    'would-block leaves pending bytes untouched');
  CheckEqual('', LRuntimeObj.WrittenData, 'would-block writes no bytes');
end;

procedure TestTryDrainPartialWriteConsumesOnlyWrittenBytes;
var
  LBuffer: IH1OutboundBuffer;
  LRuntimeObj: TFakeRuntime;
  LRuntime: ITcpStreamRuntime;
  LWritten: SizeUInt;
  LResult: TTcpStreamIOResult;
begin
  LBuffer := NewH1OutboundBuffer;
  WriteString(LBuffer, 'abcdef');
  LRuntimeObj := TFakeRuntime.Create(tsiorOk, 2);
  LRuntime := LRuntimeObj as ITcpStreamRuntime;

  LResult := LBuffer.TryDrainTo(LRuntime, LWritten);

  CheckEqual(Int64(Ord(tsiorOk)), Int64(Ord(LResult)),
    'partial write returns ok');
  CheckEqual(Int64(2), Int64(LWritten), 'partial write reports written bytes');
  CheckEqual('ab', LRuntimeObj.WrittenData, 'partial write forwards prefix');
  CheckEqual(Int64(4), Int64(LBuffer.PendingBytes),
    'partial write leaves only unwritten suffix pending');
end;

procedure TestTryDrainZeroProgressRaises;
var
  LBuffer: IH1OutboundBuffer;
  LRuntimeObj: TFakeRuntime;
  LRuntime: ITcpStreamRuntime;
  LWritten: SizeUInt;
  LCaught: Boolean;
begin
  LBuffer := NewH1OutboundBuffer;
  WriteString(LBuffer, 'abcdef');
  LRuntimeObj := TFakeRuntime.Create(tsiorOk, 0);
  LRuntime := LRuntimeObj as ITcpStreamRuntime;

  LCaught := False;
  try
    LBuffer.TryDrainTo(LRuntime, LWritten);
  except
    on E: EIOError do
      LCaught := True;
  end;

  Check(LCaught, 'ok + zero progress raises EIOError');
  CheckEqual(Int64(6), Int64(LBuffer.PendingBytes),
    'zero progress leaves pending bytes untouched');
end;

procedure TestDrainAllOverreportingWriterRaises;
var
  LBuffer: IH1OutboundBuffer;
  LWriter: TOverreportingWriter;
  LCaught: Boolean;
begin
  LBuffer := NewH1OutboundBuffer;
  WriteString(LBuffer, 'abcdef');
  LWriter := TOverreportingWriter.Create;

  LCaught := False;
  try
    LBuffer.DrainAllTo(LWriter as IWriter);
  except
    on E: EIOError do
      LCaught := True;
  end;

  Check(LCaught, 'over-reporting writer raises EIOError');
  CheckEqual(Int64(6), Int64(LBuffer.PendingBytes),
    'over-reporting writer leaves pending bytes untouched');
end;

procedure TestTryDrainOverreportingRuntimeRaises;
var
  LBuffer: IH1OutboundBuffer;
  LRuntimeObj: TFakeRuntime;
  LRuntime: ITcpStreamRuntime;
  LWritten: SizeUInt;
  LCaught: Boolean;
begin
  LBuffer := NewH1OutboundBuffer;
  WriteString(LBuffer, 'abcdef');
  LRuntimeObj := TFakeRuntime.CreateOverreporting;
  LRuntime := LRuntimeObj as ITcpStreamRuntime;

  LCaught := False;
  try
    LBuffer.TryDrainTo(LRuntime, LWritten);
  except
    on E: EIOError do
      LCaught := True;
  end;

  Check(LCaught, 'over-reporting runtime write raises EIOError');
  CheckEqual(Int64(6), Int64(LBuffer.PendingBytes),
    'over-reporting runtime leaves pending bytes untouched');
  CheckEqual('', LRuntimeObj.WrittenData,
    'over-reporting runtime does not append output bytes');
end;

var
  T: TTestRunner;
begin
  T := TTestRunner.Create('nextpas.core.http.h1outbound');
  T.Run('TryDrainTo would-block does not consume pending bytes',
    @TestTryDrainWouldBlockDoesNotConsumePendingBytes);
  T.Run('TryDrainTo partial write consumes only written bytes',
    @TestTryDrainPartialWriteConsumesOnlyWrittenBytes);
  T.Run('TryDrainTo zero progress raises',
    @TestTryDrainZeroProgressRaises);
  T.Run('DrainAllTo over-reporting writer raises',
    @TestDrainAllOverreportingWriterRaises);
  T.Run('TryDrainTo over-reporting runtime raises',
    @TestTryDrainOverreportingRuntimeRaises);
  T.Summary;
end.
