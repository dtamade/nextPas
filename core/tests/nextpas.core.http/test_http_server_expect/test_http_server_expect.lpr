program test_http_server_expect;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server,
  nextpas.core.net.server.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.impl.h1,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.io.base,
  nextpas.core.platform.socket,
  nextpas.core.platform.thread;

var
  T: TTestSuite;

const
{$IFDEF NEXTPAS_LINUX}
  TEST_SOCKET_SO_RCVBUF = 8;
  TEST_SOCKET_SO_SNDBUF = 7;
{$ELSE}
  {$IFDEF NEXTPAS_DARWIN}
  TEST_SOCKET_SO_RCVBUF = $1002;
  TEST_SOCKET_SO_SNDBUF = $1001;
  {$ELSE}
    {$IFDEF NEXTPAS_FREEBSD}
  TEST_SOCKET_SO_RCVBUF = $1002;
  TEST_SOCKET_SO_SNDBUF = $1001;
    {$ELSE}
      {$IFDEF NEXTPAS_WINDOWS}
  TEST_SOCKET_SO_RCVBUF = $1002;
  TEST_SOCKET_SO_SNDBUF = $1001;
      {$ELSE}
  TEST_SOCKET_SO_RCVBUF = 8;
  TEST_SOCKET_SO_SNDBUF = 7;
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

  TInlineRuntimeTcpStream = class(TInterfacedObject, IReader, IWriter, IStream,
    ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime)
  private
    FInput: string;
    FInputPos: SizeInt;
    FOutput: string;
    FBlocking: Boolean;
    FSetBlockingCalls: Int32;
  public
    constructor Create(const AInput: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    property Output: string read FOutput;
    property SetBlockingCalls: Int32 read FSetBlockingCalls;
    property Blocking: Boolean read FBlocking;
  end;

  TWritableDrainRuntimeTcpStream = class(TInterfacedObject, IReader, IWriter,
    IStream, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime)
  private
    FInput: string;
    FInputPos: SizeInt;
    FOutput: string;
    FBlocking: Boolean;
    FSetBlockingCalls: Int32;
    FSyncWriteCalls: Int32;
    FTryWriteCalls: Int32;
    FWouldBlockCall: Int32;
    FMaxPerTryWrite: SizeUInt;
    FWriteDeadlineCalls: Int32;
    FLastWriteDeadline: TDeadline;
  public
    constructor Create(const AInput: string; const AWouldBlockCall: Int32;
      const AMaxPerTryWrite: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    property Output: string read FOutput;
    property SetBlockingCalls: Int32 read FSetBlockingCalls;
    property Blocking: Boolean read FBlocking;
    property SyncWriteCalls: Int32 read FSyncWriteCalls;
    property TryWriteCalls: Int32 read FTryWriteCalls;
    property WriteDeadlineCalls: Int32 read FWriteDeadlineCalls;
    property LastWriteDeadline: TDeadline read FLastWriteDeadline;
  end;

  TTimedDrainRuntimeTcpStream = class(TInterfacedObject, IReader, IWriter,
    IStream, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime)
  private
    FInput: string;
    FInputPos: SizeInt;
    FOutput: string;
    FBlocking: Boolean;
    FSetBlockingCalls: Int32;
    FSyncWriteCalls: Int32;
    FTryWriteCalls: Int32;
    FWriteDeadlineCalls: Int32;
    FLastWriteDeadline: TDeadline;
    FBytesBeforeWouldBlock: SizeUInt;
    FWrittenBeforeWouldBlock: SizeUInt;
  public
    constructor Create(const AInput: string;
      const ABytesBeforeWouldBlock: SizeUInt = 0);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    property Output: string read FOutput;
    property SetBlockingCalls: Int32 read FSetBlockingCalls;
    property Blocking: Boolean read FBlocking;
    property SyncWriteCalls: Int32 read FSyncWriteCalls;
    property TryWriteCalls: Int32 read FTryWriteCalls;
    property WriteDeadlineCalls: Int32 read FWriteDeadlineCalls;
    property LastWriteDeadline: TDeadline read FLastWriteDeadline;
  end;

  TIdleReadRuntimeTcpStream = class(TInterfacedObject, IReader, IWriter,
    IStream, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime)
  private
    FInput: string;
    FInputPos: SizeInt;
    FBlocking: Boolean;
    FSetBlockingCalls: Int32;
    FTryReadCalls: Int32;
    FReadDeadlineCalls: Int32;
    FLastReadDeadline: TDeadline;
  public
    constructor Create(const AInput: string = '');
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    property Blocking: Boolean read FBlocking;
    property SetBlockingCalls: Int32 read FSetBlockingCalls;
    property TryReadCalls: Int32 read FTryReadCalls;
    property ReadDeadlineCalls: Int32 read FReadDeadlineCalls;
    property LastReadDeadline: TDeadline read FLastReadDeadline;
  end;

  TZeroProgressTcpStream = class(TInterfacedObject, IReader, IWriter, IStream, ITcpStream)
  private
    FInput: string;
    FInputPos: SizeInt;
    FOutput: string;
    FReadCalls: Int32;
    FWriteCalls: Int32;
    FReadDeadlineCalls: Int32;
    FWriteDeadlineCalls: Int32;
  public
    constructor Create(const AInput: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
property Output: string read FOutput;
    property ReadCalls: Int32 read FReadCalls;
    property WriteCalls: Int32 read FWriteCalls;
    property ReadDeadlineCalls: Int32 read FReadDeadlineCalls;
    property WriteDeadlineCalls: Int32 read FWriteDeadlineCalls;
  end;

  TTimeoutWriteTcpStream = class(TInterfacedObject, IReader, IWriter, IStream, ITcpStream)
  private
    FInput: string;
    FInputPos: SizeInt;
    FOutput: string;
    FReadCalls: Int32;
    FWriteCalls: Int32;
    FReadDeadlineCalls: Int32;
    FWriteDeadlineCalls: Int32;
    FBytesBeforeFailure: SizeUInt;
    FWrittenBeforeFailure: SizeUInt;
    FFailureTriggered: Boolean;
    FAllowWritesAfterFailure: Boolean;
  public
    constructor Create(const AInput: string; const ABytesBeforeFailure: SizeUInt;
      const AAllowWritesAfterFailure: Boolean);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
property Output: string read FOutput;
    property ReadCalls: Int32 read FReadCalls;
    property WriteCalls: Int32 read FWriteCalls;
    property ReadDeadlineCalls: Int32 read FReadDeadlineCalls;
    property WriteDeadlineCalls: Int32 read FWriteDeadlineCalls;
  end;

  TSocketTuningServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory)
  private
    FInner: IHttpServerTransport;
    FSendBufferBytes: Int32;
    procedure TuneConn(const AConn: ITcpStream);
  public
    constructor Create(const AInner: IHttpServerTransport;
      const ASendBufferBytes: Int32);
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession;
  end;

  TMockWorkerHandoff = class(TInterfacedObject, ITcpServerWorkerHandoff)
  public
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
    procedure Shutdown;
  end;

  TInlineWorkerHandoff = class(TInterfacedObject, ITcpServerWorkerHandoff)
  private
    FSubmitCount: Int32;
  public
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
    procedure Shutdown;
    property SubmitCount: Int32 read FSubmitCount;
  end;

  TMockSessionContext = class(TInterfacedObject, ITcpServerSessionContext)
  private
    FWorkerHandoff: ITcpServerWorkerHandoff;
  public
    constructor Create(const AWorkerHandoff: ITcpServerWorkerHandoff);
    function WorkerHandoff: ITcpServerWorkerHandoff;
    function HandoffHijackedConn(const AConn: ITcpStream;
      const ANewSession: ITcpServerSession): Boolean;
    function SubmitHijackMigration: Boolean;
  end;

procedure CheckRaisesHekArgument(const ALabel: string; const AProbe: TProc);
var
  LRaised: Boolean;
  LWrongException: string;
begin
  LRaised := False;
  LWrongException := '';
  try
    AProbe();
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
    on E: Exception do
      LWrongException := E.ClassName + ': ' + E.Message;
  end;
  Check(LRaised, ALabel + ' raises EHttpError(hekArgument), got ' + LWrongException);
end;

constructor TInlineRuntimeTcpStream.Create(const AInput: string);
begin
  inherited Create;
  FInput := AInput;
  FInputPos := 1;
  FOutput := '';
  FBlocking := False;
  FSetBlockingCalls := 0;
end;

function TInlineRuntimeTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeUInt;
begin
  if (ACount = 0) or (FInputPos > Length(FInput)) then
    Exit(0);
  LRemaining := SizeUInt(Length(FInput) - FInputPos + 1);
  Result := ACount;
  if Result > LRemaining then
    Result := LRemaining;
  Move(FInput[FInputPos], ABuf, Result);
  Inc(FInputPos, SizeInt(Result));
end;

function TInlineRuntimeTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOldLen: SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  LOldLen := SizeUInt(Length(FOutput));
  SetLength(FOutput, LOldLen + ACount);
  Move(ABuf, FOutput[LOldLen + 1], ACount);
  Result := ACount;
end;

function TInlineRuntimeTcpStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
begin
  Result := -1;
end;

procedure TInlineRuntimeTcpStream.Close;
begin
end;

function TInlineRuntimeTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TInlineRuntimeTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TInlineRuntimeTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TInlineRuntimeTcpStream.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(8080);
end;

function TInlineRuntimeTcpStream.RemoteAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(65000);
end;

procedure TInlineRuntimeTcpStream.Shutdown;
begin
end;

procedure TInlineRuntimeTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TInlineRuntimeTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TInlineRuntimeTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
end;

procedure TInlineRuntimeTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
end;

procedure TInlineRuntimeTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
end;

function TInlineRuntimeTcpStream.NativeSocketHandle: PtrUInt;
begin
  Result := 42;
end;

procedure TInlineRuntimeTcpStream.SetBlocking(const ABlocking: Boolean);
begin
  FBlocking := ABlocking;
  Inc(FSetBlockingCalls);
end;

function TInlineRuntimeTcpStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
begin
  ARead := Read(ABuf, ACount);
  if ARead = 0 then
    Exit(tsiorClosed);
  Result := tsiorOk;
end;

function TInlineRuntimeTcpStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
begin
  AWritten := Write(ABuf, ACount);
  Result := tsiorOk;
end;

constructor TWritableDrainRuntimeTcpStream.Create(const AInput: string;
  const AWouldBlockCall: Int32; const AMaxPerTryWrite: SizeUInt);
begin
  inherited Create;
  FInput := AInput;
  FInputPos := 1;
  FOutput := '';
  FBlocking := False;
  FSetBlockingCalls := 0;
  FSyncWriteCalls := 0;
  FTryWriteCalls := 0;
  FWouldBlockCall := AWouldBlockCall;
  FMaxPerTryWrite := AMaxPerTryWrite;
  FWriteDeadlineCalls := 0;
  FLastWriteDeadline := TDeadline.Infinite;
end;

function TWritableDrainRuntimeTcpStream.Read(var ABuf;
  const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeUInt;
begin
  if (ACount = 0) or (FInputPos > Length(FInput)) then
    Exit(0);
  LRemaining := SizeUInt(Length(FInput) - FInputPos + 1);
  Result := ACount;
  if Result > LRemaining then
    Result := LRemaining;
  Move(FInput[FInputPos], ABuf, Result);
  Inc(FInputPos, SizeInt(Result));
end;

function TWritableDrainRuntimeTcpStream.Write(const ABuf;
  const ACount: SizeUInt): SizeUInt;
begin
  Inc(FSyncWriteCalls);
  raise EIOError.Create('poll-driven response must not use sync write path');
end;

function TWritableDrainRuntimeTcpStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
begin
  Result := -1;
end;

procedure TWritableDrainRuntimeTcpStream.Close;
begin
end;

function TWritableDrainRuntimeTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TWritableDrainRuntimeTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TWritableDrainRuntimeTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TWritableDrainRuntimeTcpStream.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(8080);
end;

function TWritableDrainRuntimeTcpStream.RemoteAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(65000);
end;

procedure TWritableDrainRuntimeTcpStream.Shutdown;
begin
end;

procedure TWritableDrainRuntimeTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TWritableDrainRuntimeTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TWritableDrainRuntimeTcpStream.SetReadDeadline(
  const ADeadline: TDeadline);
begin
end;

procedure TWritableDrainRuntimeTcpStream.SetWriteDeadline(
  const ADeadline: TDeadline);
begin
  Inc(FWriteDeadlineCalls);
  FLastWriteDeadline := ADeadline;
end;

procedure TWritableDrainRuntimeTcpStream.SetCancelToken(
  const AToken: INetCancelToken);
begin
end;

function TWritableDrainRuntimeTcpStream.NativeSocketHandle: PtrUInt;
begin
  Result := 43;
end;

procedure TWritableDrainRuntimeTcpStream.SetBlocking(const ABlocking: Boolean);
begin
  FBlocking := ABlocking;
  Inc(FSetBlockingCalls);
end;

function TWritableDrainRuntimeTcpStream.TryRead(var ABuf;
  const ACount: SizeUInt; out ARead: SizeUInt): TTcpStreamIOResult;
begin
  ARead := Read(ABuf, ACount);
  if ARead = 0 then
    Exit(tsiorClosed);
  Result := tsiorOk;
end;

function TWritableDrainRuntimeTcpStream.TryWrite(const ABuf;
  const ACount: SizeUInt; out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LOldLen: SizeUInt;
begin
  Inc(FTryWriteCalls);
  if FTryWriteCalls = FWouldBlockCall then
  begin
    AWritten := 0;
    Exit(tsiorWouldBlock);
  end;

  AWritten := ACount;
  if (FMaxPerTryWrite > 0) and (AWritten > FMaxPerTryWrite) then
    AWritten := FMaxPerTryWrite;
  if AWritten > 0 then
  begin
    LOldLen := SizeUInt(Length(FOutput));
    SetLength(FOutput, LOldLen + AWritten);
    Move(ABuf, FOutput[LOldLen + 1], AWritten);
  end;
  Result := tsiorOk;
end;

constructor TTimedDrainRuntimeTcpStream.Create(const AInput: string;
  const ABytesBeforeWouldBlock: SizeUInt);
begin
  inherited Create;
  FInput := AInput;
  FInputPos := 1;
  FOutput := '';
  FBlocking := False;
  FSetBlockingCalls := 0;
  FSyncWriteCalls := 0;
  FTryWriteCalls := 0;
  FWriteDeadlineCalls := 0;
  FLastWriteDeadline := TDeadline.Infinite;
  FBytesBeforeWouldBlock := ABytesBeforeWouldBlock;
  FWrittenBeforeWouldBlock := 0;
end;

function TTimedDrainRuntimeTcpStream.Read(var ABuf;
  const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeUInt;
begin
  if (ACount = 0) or (FInputPos > Length(FInput)) then
    Exit(0);
  LRemaining := SizeUInt(Length(FInput) - FInputPos + 1);
  Result := ACount;
  if Result > LRemaining then
    Result := LRemaining;
  Move(FInput[FInputPos], ABuf, Result);
  Inc(FInputPos, SizeInt(Result));
end;

function TTimedDrainRuntimeTcpStream.Write(const ABuf;
  const ACount: SizeUInt): SizeUInt;
begin
  Inc(FSyncWriteCalls);
  raise EIOError.Create('timed poll-driven response must not use sync write path');
end;

function TTimedDrainRuntimeTcpStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
begin
  Result := -1;
end;

procedure TTimedDrainRuntimeTcpStream.Close;
begin
end;

function TTimedDrainRuntimeTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TTimedDrainRuntimeTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TTimedDrainRuntimeTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TTimedDrainRuntimeTcpStream.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(8080);
end;

function TTimedDrainRuntimeTcpStream.RemoteAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(65000);
end;

procedure TTimedDrainRuntimeTcpStream.Shutdown;
begin
end;

procedure TTimedDrainRuntimeTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TTimedDrainRuntimeTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TTimedDrainRuntimeTcpStream.SetReadDeadline(
  const ADeadline: TDeadline);
begin
end;

procedure TTimedDrainRuntimeTcpStream.SetWriteDeadline(
  const ADeadline: TDeadline);
begin
  Inc(FWriteDeadlineCalls);
  FLastWriteDeadline := ADeadline;
end;

procedure TTimedDrainRuntimeTcpStream.SetCancelToken(
  const AToken: INetCancelToken);
begin
end;

function TTimedDrainRuntimeTcpStream.NativeSocketHandle: PtrUInt;
begin
  Result := 44;
end;

procedure TTimedDrainRuntimeTcpStream.SetBlocking(const ABlocking: Boolean);
begin
  FBlocking := ABlocking;
  Inc(FSetBlockingCalls);
end;

function TTimedDrainRuntimeTcpStream.TryRead(var ABuf;
  const ACount: SizeUInt; out ARead: SizeUInt): TTcpStreamIOResult;
begin
  ARead := Read(ABuf, ACount);
  if ARead = 0 then
    Exit(tsiorClosed);
  Result := tsiorOk;
end;

function TTimedDrainRuntimeTcpStream.TryWrite(const ABuf;
  const ACount: SizeUInt; out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LRemaining: SizeUInt;
  LOldLen: SizeUInt;
begin
  Inc(FTryWriteCalls);
  if FBytesBeforeWouldBlock = 0 then
  begin
    AWritten := 0;
    Exit(tsiorWouldBlock);
  end;

  if FWrittenBeforeWouldBlock >= FBytesBeforeWouldBlock then
  begin
    AWritten := 0;
    Exit(tsiorWouldBlock);
  end;

  LRemaining := FBytesBeforeWouldBlock - FWrittenBeforeWouldBlock;
  AWritten := ACount;
  if AWritten > LRemaining then
    AWritten := LRemaining;
  if AWritten > 0 then
  begin
    LOldLen := SizeUInt(Length(FOutput));
    SetLength(FOutput, LOldLen + AWritten);
    Move(ABuf, FOutput[LOldLen + 1], AWritten);
    Inc(FWrittenBeforeWouldBlock, AWritten);
  end;
  Result := tsiorOk;
end;

constructor TIdleReadRuntimeTcpStream.Create(const AInput: string);
begin
  inherited Create;
  FInput := AInput;
  FInputPos := 1;
  FBlocking := False;
  FSetBlockingCalls := 0;
  FTryReadCalls := 0;
  FReadDeadlineCalls := 0;
  FLastReadDeadline := TDeadline.Infinite;
end;

function TIdleReadRuntimeTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeUInt;
begin
  if (ACount = 0) or (FInputPos > Length(FInput)) then
    Exit(0);
  LRemaining := SizeUInt(Length(FInput) - FInputPos + 1);
  Result := ACount;
  if Result > LRemaining then
    Result := LRemaining;
  Move(FInput[FInputPos], ABuf, Result);
  Inc(FInputPos, SizeInt(Result));
end;

function TIdleReadRuntimeTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  raise EIOError.Create('idle read test stream must not use sync write path');
end;

function TIdleReadRuntimeTcpStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
begin
  Result := -1;
end;

procedure TIdleReadRuntimeTcpStream.Close;
begin
end;

function TIdleReadRuntimeTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TIdleReadRuntimeTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TIdleReadRuntimeTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TIdleReadRuntimeTcpStream.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(8080);
end;

function TIdleReadRuntimeTcpStream.RemoteAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(65000);
end;

procedure TIdleReadRuntimeTcpStream.Shutdown;
begin
end;

procedure TIdleReadRuntimeTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TIdleReadRuntimeTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TIdleReadRuntimeTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  Inc(FReadDeadlineCalls);
  FLastReadDeadline := ADeadline;
end;

procedure TIdleReadRuntimeTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
end;

procedure TIdleReadRuntimeTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
end;

function TIdleReadRuntimeTcpStream.NativeSocketHandle: PtrUInt;
begin
  Result := 45;
end;

procedure TIdleReadRuntimeTcpStream.SetBlocking(const ABlocking: Boolean);
begin
  FBlocking := ABlocking;
  Inc(FSetBlockingCalls);
end;

function TIdleReadRuntimeTcpStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
begin
  Inc(FTryReadCalls);
  ARead := Read(ABuf, ACount);
  if ARead = 0 then
    Exit(tsiorWouldBlock);
  Result := tsiorOk;
end;

function TIdleReadRuntimeTcpStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
begin
  AWritten := 0;
  raise EIOError.Create('idle read test stream must not use nonblocking write path');
end;

constructor TZeroProgressTcpStream.Create(const AInput: string);
begin
  inherited Create;
  FInput := AInput;
  FInputPos := 1;
  FOutput := '';
  FReadCalls := 0;
  FWriteCalls := 0;
  FReadDeadlineCalls := 0;
  FWriteDeadlineCalls := 0;
end;

function TZeroProgressTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeUInt;
begin
  Inc(FReadCalls);
  if (ACount = 0) or (FInputPos > Length(FInput)) then
    Exit(0);
  LRemaining := SizeUInt(Length(FInput) - FInputPos + 1);
  Result := ACount;
  if Result > LRemaining then
    Result := LRemaining;
  Move(FInput[FInputPos], ABuf, Result);
  Inc(FInputPos, SizeInt(Result));
end;

function TZeroProgressTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Inc(FWriteCalls);
  Result := 0;
end;

function TZeroProgressTcpStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
begin
  Result := -1;
end;

procedure TZeroProgressTcpStream.Close;
begin
end;

function TZeroProgressTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TZeroProgressTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TZeroProgressTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TZeroProgressTcpStream.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(8080);
end;

function TZeroProgressTcpStream.RemoteAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(65000);
end;

procedure TZeroProgressTcpStream.Shutdown;
begin
end;

procedure TZeroProgressTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TZeroProgressTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TZeroProgressTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  Inc(FReadDeadlineCalls);
end;

procedure TZeroProgressTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  Inc(FWriteDeadlineCalls);
end;

procedure TZeroProgressTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
end;

constructor TTimeoutWriteTcpStream.Create(const AInput: string;
  const ABytesBeforeFailure: SizeUInt; const AAllowWritesAfterFailure: Boolean);
begin
  inherited Create;
  FInput := AInput;
  FInputPos := 1;
  FOutput := '';
  FReadCalls := 0;
  FWriteCalls := 0;
  FReadDeadlineCalls := 0;
  FWriteDeadlineCalls := 0;
  FBytesBeforeFailure := ABytesBeforeFailure;
  FWrittenBeforeFailure := 0;
  FFailureTriggered := False;
  FAllowWritesAfterFailure := AAllowWritesAfterFailure;
end;

function TTimeoutWriteTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeUInt;
begin
  Inc(FReadCalls);
  if (ACount = 0) or (FInputPos > Length(FInput)) then
    Exit(0);
  LRemaining := SizeUInt(Length(FInput) - FInputPos + 1);
  Result := ACount;
  if Result > LRemaining then
    Result := LRemaining;
  Move(FInput[FInputPos], ABuf, Result);
  Inc(FInputPos, SizeInt(Result));
end;

function TTimeoutWriteTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemainingBeforeFailure: SizeUInt;
  LOldLen: SizeUInt;
begin
  Inc(FWriteCalls);

  if ACount = 0 then
    Exit(0);

  if not FFailureTriggered then
  begin
    if FWrittenBeforeFailure < FBytesBeforeFailure then
    begin
      LRemainingBeforeFailure := FBytesBeforeFailure - FWrittenBeforeFailure;
      Result := ACount;
      if Result > LRemainingBeforeFailure then
        Result := LRemainingBeforeFailure;
      LOldLen := SizeUInt(Length(FOutput));
      SetLength(FOutput, LOldLen + Result);
      Move(ABuf, FOutput[LOldLen + 1], Result);
      Inc(FWrittenBeforeFailure, Result);
      Exit;
    end;

    FFailureTriggered := True;
    raise ETimeoutError.Create('write deadline exceeded');
  end;

  if not FAllowWritesAfterFailure then
    raise ETimeoutError.Create('write deadline exceeded');

  LOldLen := SizeUInt(Length(FOutput));
  SetLength(FOutput, LOldLen + ACount);
  Move(ABuf, FOutput[LOldLen + 1], ACount);
  Result := ACount;
end;

function TTimeoutWriteTcpStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
begin
  Result := -1;
end;

procedure TTimeoutWriteTcpStream.Close;
begin
end;

function TTimeoutWriteTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TTimeoutWriteTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TTimeoutWriteTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TTimeoutWriteTcpStream.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(8080);
end;

function TTimeoutWriteTcpStream.RemoteAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(65000);
end;

procedure TTimeoutWriteTcpStream.Shutdown;
begin
end;

procedure TTimeoutWriteTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TTimeoutWriteTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TTimeoutWriteTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  Inc(FReadDeadlineCalls);
end;

procedure TTimeoutWriteTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  Inc(FWriteDeadlineCalls);
end;

procedure TTimeoutWriteTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
end;

constructor TSocketTuningServerTransport.Create(const AInner: IHttpServerTransport;
  const ASendBufferBytes: Int32);
begin
  inherited Create;
  FInner := AInner;
  FSendBufferBytes := ASendBufferBytes;
end;

procedure TSocketTuningServerTransport.TuneConn(const AConn: ITcpStream);
var
  LRuntime: ITcpSocketRuntime;
  LSocket: TPlatformSocket;
  LSize: Int32;
begin
  if FSendBufferBytes <= 0 then
    Exit;
  if not Supports(AConn, ITcpSocketRuntime, LRuntime) then
    Exit;
  LSocket := PLATFORM_INVALID_SOCKET;
{$IFDEF NEXTPAS_WINDOWS}
  LSocket.Value := LRuntime.NativeSocketHandle;
{$ELSE}
  LSocket.Value := Int32(LRuntime.NativeSocketHandle);
{$ENDIF}
  LSize := FSendBufferBytes;
  if platform_socket_setsockopt(LSocket, PLATFORM_SOL_SOCKET, TEST_SOCKET_SO_SNDBUF,
       @LSize, SizeOf(LSize)) <> 0 then
    raise EIOError.Create('server send buffer tuning failed');
end;

function TSocketTuningServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  TuneConn(AConn);
  Result := FInner.ServeConn(AConn, AHandler);
end;

function TSocketTuningServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
var
  LFactory: IHttpServerSessionFactory;
begin
  TuneConn(AConn);
  if not Supports(FInner, IHttpServerSessionFactory, LFactory) then
    raise EInvalidOperationError.Create('inner transport does not expose session factory');
  Result := LFactory.NewSession(AConn, AHandler);
end;

function TMockWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
begin
  Result := TCP_SERVER_HANDOFF_ACCEPTED;
end;

procedure TMockWorkerHandoff.Shutdown;
begin
end;

function TInlineWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
var
  LOwnership: TTcpServerConnOwnership;
begin
  Inc(FSubmitCount);
  Result := TCP_SERVER_HANDOFF_ACCEPTED;
  LOwnership := AWork.Execute;
  if ACompletion <> nil then
    ACompletion.Complete(TCP_SERVER_WORK_COMPLETED, LOwnership);
end;

procedure TInlineWorkerHandoff.Shutdown;
begin
end;

constructor TMockSessionContext.Create(
  const AWorkerHandoff: ITcpServerWorkerHandoff);
begin
  inherited Create;
  FWorkerHandoff := AWorkerHandoff;
end;

function TMockSessionContext.WorkerHandoff: ITcpServerWorkerHandoff;
begin
  Result := FWorkerHandoff;
end;

function TMockSessionContext.HandoffHijackedConn(const AConn: ITcpStream;
  const ANewSession: ITcpServerSession): Boolean;
begin
  { mock 不模拟 hijack 迁移：报告不可迁移。 }
  Result := False;
end;

function TMockSessionContext.SubmitHijackMigration: Boolean;
begin
  { mock 无在途迁移可提交。 }
  Result := False;
end;

function DefaultH1ServerTransportOptions(
  const AHttpOptions: THttpServerOptions): TH1ServerTransportOptions;
begin
  Result.ReadTimeout := AHttpOptions.ReadTimeout;
  Result.WriteTimeout := AHttpOptions.WriteTimeout;
  Result.IdleTimeout := AHttpOptions.IdleTimeout;
  Result.MaxHeaderSize := AHttpOptions.MaxHeaderSize;
  Result.MaxBodySize := AHttpOptions.MaxBodySize;
  Result.MaxRequestsPerConnection := AHttpOptions.MaxRequestsPerConnection;
  Result.RequestArena := AHttpOptions.RequestArena;
  Result.RequestArenaCapacity := AHttpOptions.RequestArenaCapacity;
  { Unit tests assert WorkerHandoff submit counts / completion wakes. }
  Result.PreferPollWorkerHandoff := True;
end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  Dispose(LCtx);
end;

function StartServer(const AHandler: IHttpHandler; out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, THttpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0; { OS picks a free port }
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  { Wait for server to start listening }
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000); { 5ms }
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

function StartServerWithOptions(const AHandler: IHttpHandler; const AOptions: THttpServerOptions;
  out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, AOptions);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

function StartServerWithTransportAndOptions(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport; const AOptions: THttpServerOptions;
  out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, ATransport, AOptions);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

{$IFDEF NEXTPAS_LINUX}
function StartEpollServer(const AHandler: IHttpHandler; out AServer: THttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  Result := StartServerWithOptions(AHandler, LOpts, AServer, APort);
end;
{$ENDIF}

procedure StopServer(var AServer: THttpServer; const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer.Free;
  AServer := nil;
end;

function SocketFromRuntime(const ARuntime: ITcpSocketRuntime): TPlatformSocket;
begin
  Result := PLATFORM_INVALID_SOCKET;
{$IFDEF NEXTPAS_WINDOWS}
  Result.Value := ARuntime.NativeSocketHandle;
{$ELSE}
  Result.Value := Int32(ARuntime.NativeSocketHandle);
{$ENDIF}
end;

procedure SetSocketRecvBuffer(const AConn: ITcpStream; const ASize: Int32);
var
  LRuntime: ITcpSocketRuntime;
  LSocket: TPlatformSocket;
  LSize: Int32;
begin
  Check(Supports(AConn, ITcpSocketRuntime, LRuntime),
    'tcp stream exposes runtime socket control for recvbuf tuning');
  LSocket := SocketFromRuntime(LRuntime);
  LSize := ASize;
  CheckEqual(Int64(0), Int64(platform_socket_setsockopt(LSocket,
    PLATFORM_SOL_SOCKET, TEST_SOCKET_SO_RCVBUF, @LSize, SizeOf(LSize))),
    'recv buffer tuning succeeds');
end;

function ReadUntilClosedOrDeadline(const AConn: ITcpStream;
  const AReadTimeoutMs: Int64; out AClosed: Boolean; out ATimedOut: Boolean): string;
var
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  AClosed := False;
  ATimedOut := False;
  AConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(AReadTimeoutMs)));
  repeat
    try
      LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    except
      on ENetworkError do
      begin
        ATimedOut := True;
        Break;
      end;
    end;
    if LN = 0 then
    begin
      AClosed := True;
      Break;
    end;
    SetLength(Result, Length(Result) + Int32(LN));
    Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
  until False;
end;

function SendRawRequest(const APort: UInt16; const ARequest: string): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    { Read response — read until connection closed or timeout }
    repeat
      try
        LN := LConn.Read(LBuf[0], 8192);
      except
        LN := 0;
      end;
      if LN > 0 then
      begin
        SetLength(Result, Length(Result) + Int32(LN));
        Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  finally
    LConn.Close;
  end;
end;

function SendRawRequestAndShutdownWrite(const APort: UInt16; const ARequest: string): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    if ARequest <> '' then
      LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    LConn.Shutdown;
    repeat
      try
        LN := LConn.Read(LBuf[0], 8192);
      except
        LN := 0;
      end;
      if LN > 0 then
      begin
        SetLength(Result, Length(Result) + Int32(LN));
        Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  finally
    LConn.Close;
  end;
end;

function SendRawRequestBytes(const APort: UInt16; const AData: PByte; ALen: SizeUInt): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    if ALen > 0 then
      LConn.Write(AData^, ALen);
    repeat
      try
        LN := LConn.Read(LBuf[0], 8192);
      except
        LN := 0;
      end;
      if LN > 0 then
      begin
        SetLength(Result, Length(Result) + Int32(LN));
        Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  finally
    LConn.Close;
  end;
end;

function CountSubstring(const AText, APattern: string): Int32;
var
  LSearchStart: Int32;
  LFoundAt: Int32;
begin
  Result := 0;
  if (AText = '') or (APattern = '') then
    Exit(0);
  LSearchStart := 1;
  repeat
    LFoundAt := Pos(APattern, Copy(AText, LSearchStart, MaxInt));
    if LFoundAt <= 0 then
      Exit;
    Inc(Result);
    Inc(LSearchStart, LFoundAt + Length(APattern) - 1);
  until False;
end;

{ Test 1: Server responds 200 to simple GET }
{ Q1-1: live SSE path — read until event body appears (keep-alive stream). }
{ Test 2: Server responds with custom body }
{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{ Test 3: Server responds 404 for unmatched route }
{ Test 4: Handler exception results in 500 }
type
  TCrashHandler = class(TInterfacedObject, IHttpHandler)
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

procedure TCrashHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  raise Exception.Create('intentional crash');
end;

procedure RunCommittedResponseExceptionDoesNotAppend500(
  const AUseEpoll: Boolean; const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/flush-crash', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'partial';
    AW.GetHeaders.SetHeader('content-length', '7');
    AW.GetHeaders.SetHeader('connection', 'close');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 7);
    AW.Flush;
    raise Exception.Create('crash after committed response');
  end);
  {$IFDEF NEXTPAS_LINUX}
  if AUseEpoll then
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort)
  else
  {$ENDIF}
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET /flush-crash HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) = 1,
      ALabel + ': committed response keeps original 200');
    Check(Pos('partial', LResp) > 0,
      ALabel + ': committed response body stays visible');
    Check(Pos('HTTP/1.1 500', LResp) = 0,
      ALabel + ': server does not append 500 after committed response');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

procedure RunPollDrivenMidRequestReadTimeout(
  const ALabel, AInput: string);
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactoryWithContext;
  LSession: ITcpServerSession;
  LPollSession: ITcpServerPollDrivenSession;
  LDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
  LStreamObj: TIdleReadRuntimeTcpStream;
  LStream: ITcpStream;
  LHandoffObj: TInlineWorkerHandoff;
  LHandoff: ITcpServerWorkerHandoff;
  LContext: ITcpServerSessionContext;
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
begin
  LHttpOpts := THttpServerOptions.Default;
  { PD-1B: mid-request partial body arms FReadMs (ReadTimeout). IdleTimeout alone
    no longer covers request-side stalls when Default RW is finite. }
  LHttpOpts.ReadTimeout := 20;
  LHttpOpts.IdleTimeout := 20;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    ALabel + ': h1 transport exposes context-aware session factory');

  LStreamObj := TIdleReadRuntimeTcpStream.Create(AInput);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    ALabel + ': context-aware h1 session exposes poll-driven seam');
  Check(Supports(LSession, ITcpServerPollDrivenSessionWithDeadline, LDeadlineSession),
    ALabel + ': mid-request timeout session exposes deadline seam');
  CheckEqual(Int64(1), Int64(LStreamObj.ReadDeadlineCalls),
    ALabel + ': request parse arms exactly one read deadline before first readable event');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    ALabel + ': partial request bytes keep the session active');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    ALabel + ': partial request bytes do not reach the handler');
  CheckEqual(Int64(0), Int64(LHandoffObj.SubmitCount),
    ALabel + ': partial request bytes do not submit worker work');
  Check(LNextEvents = [peReadable],
    ALabel + ': partial request bytes keep waiting for readable events');
  Check(not LDeadlineSession.WakeDeadline.IsInfinite,
    ALabel + ': partial request bytes preserve a finite wake deadline');
  CheckEqual(Int64(1), Int64(LStreamObj.ReadDeadlineCalls),
    ALabel + ': partial request progress does not re-arm the request deadline');

  platform_thread_sleep_ns(50000000);
  Check(LDeadlineSession.WakeDeadline.IsExpired,
    ALabel + ': request-side wake deadline eventually expires while stalled');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    ALabel + ': stalled partial request closes after idle timeout');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), ALabel + ': timeout close keeps server ownership');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    ALabel + ': timeout close still does not call handler');
  CheckEqual(Int64(0), Int64(LHandoffObj.SubmitCount),
    ALabel + ': timeout close still does not submit worker work');
  CheckEqual(Int64(2), Int64(LStreamObj.ReadDeadlineCalls),
    ALabel + ': timeout close clears the request read deadline exactly once');
  Check(LDeadlineSession.WakeDeadline.IsInfinite,
    ALabel + ': timeout close clears wake deadline');
end;

procedure RunPollDrivenQueuedFollowUpErrorPreservesWireOrder(
  const ALabel, AInput, AExpectedStatusLine: string;
  const AMaxHeaderSize: Int32; const AMaxBodySize: Int64);
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactoryWithContext;
  LSession: ITcpServerSession;
  LPollSession: ITcpServerPollDrivenSession;
  LStreamObj: TWritableDrainRuntimeTcpStream;
  LStream: ITcpStream;
  LHandoffObj: TInlineWorkerHandoff;
  LHandoff: ITcpServerWorkerHandoff;
  LContext: ITcpServerSessionContext;
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
  LFirstPath: string;
  LFirstStatusPos: SizeInt;
  LFollowStatusPos: SizeInt;
const
  BODY = 'ok';
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.MaxHeaderSize := AMaxHeaderSize;
  LHttpOpts.MaxBodySize := AMaxBodySize;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    ALabel + ': h1 transport exposes context-aware session factory');

  LStreamObj := TWritableDrainRuntimeTcpStream.Create(AInput, 1, 0);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LFirstPath := '';
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
      if LHandlerCalls = 1 then
        LFirstPath := AReq.Url.Path;
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(BODY[1], SizeUInt(Length(BODY)));
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    ALabel + ': context-aware h1 session exposes poll-driven seam');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    ALabel + ': first readable advance stays active while first request completes');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    ALabel + ': first request is handed off once');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    ALabel + ': only the first request reaches the handler');
  CheckEqual('/one', LFirstPath, ALabel + ': first request path captured');
  Check(LNextEvents = [], ALabel + ': first request handoff waits on completion wake');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    ALabel + ': completion wake queues follow-up error behind stalled drain');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    ALabel + ': follow-up error stays reactor-local without second worker handoff');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    ALabel + ': follow-up error does not enter the handler');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    ALabel + ': completion wake attempts exactly one stalled drain write');
  Check(LNextEvents = [peWritable],
    ALabel + ': stalled drain waits for writable wake');
  CheckEqual('', LStreamObj.Output,
    ALabel + ': stalled first drain writes no wire bytes');

  LResult := LPollSession.Advance([peWritable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    ALabel + ': writable wake drains original response then queued follow-up error');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), ALabel + ': session remains server-owned on close');
  CheckEqual(Int64(3), Int64(LStreamObj.TryWriteCalls),
    ALabel + ': writable wake performs one drain for 200 and one for queued error');
  CheckEqual(Int64(2), Int64(CountSubstring(LStreamObj.Output, 'HTTP/1.1 ')),
    ALabel + ': wire emits exactly two status lines');

  LFirstStatusPos := Pos('HTTP/1.1 200 OK', LStreamObj.Output);
  LFollowStatusPos := Pos(AExpectedStatusLine, LStreamObj.Output);
  Check(LFirstStatusPos > 0,
    ALabel + ': first response status line is present');
  Check(LFollowStatusPos > LFirstStatusPos,
    ALabel + ': queued follow-up error stays behind the first response on wire');
  Check(Pos(BODY, LStreamObj.Output) > LFirstStatusPos,
    ALabel + ': first response body is still written before queued error');
end;

procedure RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
  const ALabel, AInput, AExpectedStatusLine: string;
  const AMaxHeaderSize: Int32; const AMaxBodySize: Int64);
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactoryWithContext;
  LSession: ITcpServerSession;
  LPollSession: ITcpServerPollDrivenSession;
  LStreamObj: TWritableDrainRuntimeTcpStream;
  LStream: ITcpStream;
  LHandoffObj: TInlineWorkerHandoff;
  LHandoff: ITcpServerWorkerHandoff;
  LContext: ITcpServerSessionContext;
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := 20;
  LHttpOpts.MaxHeaderSize := AMaxHeaderSize;
  LHttpOpts.MaxBodySize := AMaxBodySize;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    ALabel + ': h1 transport exposes context-aware session factory');

  LStreamObj := TWritableDrainRuntimeTcpStream.Create(AInput, 1, 0);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    ALabel + ': context-aware h1 session exposes poll-driven seam');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    ALabel + ': first advance enters reactor-owned writable drain');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    ALabel + ': handler is not called');
  CheckEqual(Int64(0), Int64(LHandoffObj.SubmitCount),
    ALabel + ': no worker handoff occurs');
  CheckEqual(Int64(0), Int64(LStreamObj.SyncWriteCalls),
    ALabel + ': direct error path avoids sync socket write');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    ALabel + ': first advance attempts exactly one nonblocking drain');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteDeadlineCalls),
    ALabel + ': timed drain arms one write deadline before draining');
  Check(LNextEvents = [peWritable],
    ALabel + ': writable wake is subscribed after would-block');
  CheckEqual('', LStreamObj.Output,
    ALabel + ': no bytes are emitted before writable wake');

  LResult := LPollSession.Advance([peWritable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    ALabel + ': writable wake drains the direct error response');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), ALabel + ': connection remains server-owned');
  CheckEqual(Int64(0), Int64(LStreamObj.SyncWriteCalls),
    ALabel + ': writable wake still avoids sync socket write');
  CheckEqual(Int64(2), Int64(LStreamObj.TryWriteCalls),
    ALabel + ': writable wake resumes nonblocking drain once');
  Check(Pos(AExpectedStatusLine, LStreamObj.Output) > 0,
    ALabel + ': expected direct error status is written on wire');
end;

procedure RunPollDrivenStandaloneTimedDirectErrorPartialTimeoutPreservesStatus(
  const ALabel, AInput, AExpectedStatusLine: string;
  const AMaxHeaderSize: Int32; const AMaxBodySize: Int64);
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactoryWithContext;
  LSession: ITcpServerSession;
  LPollSession: ITcpServerPollDrivenSession;
  LDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
  LStreamObj: TTimedDrainRuntimeTcpStream;
  LStream: ITcpStream;
  LHandoffObj: TInlineWorkerHandoff;
  LHandoff: ITcpServerWorkerHandoff;
  LContext: ITcpServerSessionContext;
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
const
  FIRST_WRITE_BYTES = 64;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := 20;
  LHttpOpts.MaxHeaderSize := AMaxHeaderSize;
  LHttpOpts.MaxBodySize := AMaxBodySize;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    ALabel + ': h1 transport exposes context-aware session factory');

  LStreamObj := TTimedDrainRuntimeTcpStream.Create(AInput, FIRST_WRITE_BYTES);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    ALabel + ': context-aware h1 session exposes poll-driven seam');
  Check(Supports(LSession, ITcpServerPollDrivenSessionWithDeadline, LDeadlineSession),
    ALabel + ': timed direct-error session exposes deadline seam');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    ALabel + ': first advance enters timed partial direct-error drain');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    ALabel + ': handler is not called');
  CheckEqual(Int64(0), Int64(LHandoffObj.SubmitCount),
    ALabel + ': direct error stays reactor-local without worker handoff');
  CheckEqual(Int64(0), Int64(LStreamObj.SyncWriteCalls),
    ALabel + ': timed direct error still avoids sync socket write');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    ALabel + ': first advance attempts one nonblocking direct-error drain');
  CheckEqual(Int64(2), Int64(LStreamObj.WriteDeadlineCalls),
    ALabel + ': partial direct-error drain rearms write deadline after partial progress');
  CheckEqual(Int64(FIRST_WRITE_BYTES), Int64(Length(LStreamObj.Output)),
    ALabel + ': partial direct-error drain preserves first written bytes');
  Check(Pos(AExpectedStatusLine, LStreamObj.Output) > 0,
    ALabel + ': partial direct-error drain preserves expected status line');
  CheckEqual(Int64(1), Int64(CountSubstring(LStreamObj.Output, 'HTTP/1.1 ')),
    ALabel + ': partial direct-error drain still exposes only one status line');
  Check(LNextEvents = [peWritable],
    ALabel + ': partial direct-error drain waits for writable wake');
  Check(not LDeadlineSession.WakeDeadline.IsInfinite,
    ALabel + ': partial direct-error drain exposes finite wake deadline');

  LResult := LPollSession.Advance([peWritable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    ALabel + ': writable wake before deadline keeps partial direct-error drain waiting');
  CheckEqual(Int64(2), Int64(LStreamObj.TryWriteCalls),
    ALabel + ': writable wake retries partial direct-error drain exactly once');
  CheckEqual(Int64(2), Int64(LStreamObj.WriteDeadlineCalls),
    ALabel + ': would-block retry keeps prior direct-error deadline');
  CheckEqual(Int64(FIRST_WRITE_BYTES), Int64(Length(LStreamObj.Output)),
    ALabel + ': would-block retry writes no extra direct-error bytes');
  Check(Pos('HTTP/1.1 500', LStreamObj.Output) = 0,
    ALabel + ': partial direct-error drain does not append synthetic 500 before timeout');

  platform_thread_sleep_ns(50000000);
  Check(LDeadlineSession.WakeDeadline.IsExpired,
    ALabel + ': direct-error wake deadline eventually expires');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    ALabel + ': deadline wake closes partial direct-error drain');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), ALabel + ': connection remains server-owned on timeout close');
  CheckEqual(Int64(2), Int64(LStreamObj.TryWriteCalls),
    ALabel + ': deadline wake closes partial direct-error drain without extra write retry');
  CheckEqual(Int64(2), Int64(LStreamObj.WriteDeadlineCalls),
    ALabel + ': timeout close preserves last direct-error deadline without further reset');
  CheckEqual(Int64(1), Int64(CountSubstring(LStreamObj.Output, 'HTTP/1.1 ')),
    ALabel + ': timeout close still leaves only one direct-error status line on wire');
  Check(Pos('HTTP/1.1 500', LStreamObj.Output) = 0,
    ALabel + ': timeout close does not append synthetic 500');
  Check(LDeadlineSession.WakeDeadline.IsInfinite,
    ALabel + ': timeout close clears partial direct-error wake deadline');
end;

procedure TestH1PollDrivenSessionQueuesFollowUpExpectationFailedBehindActiveDrain;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /unsupported-expect HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue, fancy'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunPollDrivenQueuedFollowUpErrorPreservesWireOrder(
    'queued follow-up 417', REQ, 'HTTP/1.1 417 Expectation Failed', 0, 0);
end;

procedure TestH1PollDrivenStandaloneUnsupportedExpectDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10 +
        'Expect: 100-continue, fancy'#13#10 +
        'Connection: close'#13#10#13#10;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll unsupported expect rejection', REQ,
    'HTTP/1.1 417 Expectation Failed', 0, 0);
end;

procedure TestH1PollDrivenStandaloneUnsupportedExpectPartialTimeoutPreservesStatus;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10 +
        'Expect: 100-continue, fancy'#13#10 +
        'Connection: close'#13#10#13#10;
begin
  RunPollDrivenStandaloneTimedDirectErrorPartialTimeoutPreservesStatus(
    'standalone poll unsupported expect partial-timeout', REQ,
    'HTTP/1.1 417 Expectation Failed', 0, 0);
end;

procedure RunDirectErrorResponseWriteTimeoutOnRejectedRequest(
  const ALabel, AReq, AExpectedStatusLine: string;
  const AMaxBodySize, AMaxHeaderSize: Int64; const ABytesBeforeFailure: SizeUInt);
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactory;
  LSession: ITcpServerSession;
  LStreamObj: TTimeoutWriteTcpStream;
  LStream: ITcpStream;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := 250;
  if AMaxBodySize > 0 then
    LHttpOpts.MaxBodySize := AMaxBodySize;
  if AMaxHeaderSize > 0 then
    LHttpOpts.MaxHeaderSize := AMaxHeaderSize;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactory, LFactory),
    ALabel + ': h1 transport exposes session factory for direct error write-timeout proof');

  LStreamObj := TTimeoutWriteTcpStream.Create(AReq, ABytesBeforeFailure, True);
  LStream := LStreamObj as ITcpStream;
  LHandlerCalls := 0;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
    end));

  LOwnership := LSession.Run;

  Check(LOwnership = TCP_SERVER_CONN_OWNERSHIP_SERVER,
    ALabel + ': server keeps ownership when direct error write times out');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    ALabel + ': direct error does not enter handler');
  CheckEqual(Int64(1), Int64(LStreamObj.ReadCalls),
    ALabel + ': direct error consumes one request read');
  Check(LStreamObj.WriteCalls > 0,
    ALabel + ': direct error still attempts to write an error response');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteDeadlineCalls),
    ALabel + ': direct error arms write deadline before direct error response');
  CheckEqual(Int64(ABytesBeforeFailure), Int64(Length(LStreamObj.Output)),
    ALabel + ': direct error preserves exactly the bytes written before timeout');
  if AExpectedStatusLine <> '' then
    Check(Pos(AExpectedStatusLine, LStreamObj.Output) > 0,
      ALabel + ': direct error preserves the original status line bytes');
  if ABytesBeforeFailure > 0 then
    CheckEqual(Int64(1), Int64(CountSubstring(LStreamObj.Output, 'HTTP/1.1 ')),
      ALabel + ': direct error partial-timeout still exposes only one status line');
  Check(Pos('HTTP/1.1 500', LStreamObj.Output) = 0,
    ALabel + ': direct error timeout does not append synthetic 500');
end;

procedure RunDirectErrorResponseArmsWriteTimeoutOnRejectedRequest(
  const ALabel, AReq: string; const AMaxBodySize, AMaxHeaderSize: Int64);
const
  BYTES_BEFORE_FAILURE = 0;
begin
  RunDirectErrorResponseWriteTimeoutOnRejectedRequest(ALabel, AReq, '',
    AMaxBodySize, AMaxHeaderSize, BYTES_BEFORE_FAILURE);
end;

procedure TestDirectErrorResponseArmsWriteTimeoutOnUnsupportedExpectRequest;
const
  REQ =
    'POST /unsupported-expect HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue, fancy'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunDirectErrorResponseArmsWriteTimeoutOnRejectedRequest(
    'unsupported expect direct 417', REQ, 0, 0);
end;

procedure RunDirectErrorResponsePartialWriteTimeoutOnRejectedRequest(
  const ALabel, AReq, AExpectedStatusLine: string;
  const AMaxBodySize, AMaxHeaderSize: Int64);
const
  BYTES_BEFORE_FAILURE = 64;
begin
  RunDirectErrorResponseWriteTimeoutOnRejectedRequest(ALabel, AReq,
    AExpectedStatusLine, AMaxBodySize, AMaxHeaderSize, BYTES_BEFORE_FAILURE);
end;

procedure TestDirectErrorResponsePartialWriteTimeoutOnUnsupportedExpectRequest;
const
  REQ =
    'POST /unsupported-expect HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue, fancy'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunDirectErrorResponsePartialWriteTimeoutOnRejectedRequest(
    'unsupported expect direct 417 partial-timeout', REQ,
    'HTTP/1.1 417 Expectation Failed', 0, 0);
end;

procedure RunRealSocketWriteTimeoutDoesNotExpireDuringSlowBufferedHandler(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
  LHandlerCalls: Int32;
const
  WRITE_TIMEOUT_MS = 50;
  HANDLER_SLEEP_NS = 150000000;
  READ_WAIT_MS = 2000;
  REQ =
    'GET /slow HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10#13#10;
  BODY = 'slow-ok';
begin
  CheckEqual(Int64(WRITE_TIMEOUT_MS), AHttpOpts.WriteTimeout,
    ABackendName + ' slow buffered handler proof expects the configured write timeout');
  LHandlerCalls := 0;

  LRouter := THttpRouter.Create;
  LRouter.Get('/slow', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    Inc(LHandlerCalls);
    platform_thread_sleep_ns(HANDLER_SLEEP_NS);
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(BODY))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(BODY[1], SizeUInt(Length(BODY)));
  end);

  LHandle := StartServerWithOptions(LRouter as IHttpHandler, AHttpOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadUntilClosedOrDeadline(LConn, READ_WAIT_MS, LClosed, LTimedOut);

      CheckEqual(Int64(1), Int64(LHandlerCalls),
        ABackendName + ' slow buffered handler still runs exactly once');
      Check(LClosed,
        ABackendName + ' slow buffered handler response closes cleanly on Connection: close');
      Check(not LTimedOut,
        ABackendName + ' slow buffered handler response arrives before read deadline');
      Check(Pos('HTTP/1.1 200 OK', LResp) > 0,
        ABackendName + ' slow buffered handler still emits 200 response');
      Check(Pos(BODY, LResp) > 0,
        ABackendName + ' slow buffered handler body reaches the client');
      Check(Pos('HTTP/1.1 500', LResp) = 0,
        ABackendName + ' slow buffered handler path does not append synthetic 500');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

procedure RunRealSocketWriteTimeoutBackpressureStopsPipeline(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LTransport: IHttpServerTransport;
  LH1Opts: TH1ServerTransportOptions;
  LResp: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
  LFirstCalls: Int32;
  LSecondCalls: Int32;
  LCompletedBodyWrites: Int32;
  LHandlerReturned: Boolean;
  LBodyChunk: string;
  LTotalBodyLen: Int64;
const
  WRITE_TIMEOUT_MS = 50;
  RECV_BUFFER_BYTES = 1024;
  SEND_BUFFER_BYTES = 1024;
  BACKPRESSURE_WAIT_NS = 500000000;
  { Real TCP buffering can outlive the 50ms deadline; this window only proves eventual safe-close. }
  CLOSE_WAIT_MS = 5000;
  BODY_CHUNK_LEN = 8192;
  BODY_CHUNK_COUNT = 2048; { 16 MiB total payload intent }
  PIPELINED_REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /after HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10;
begin
  LFirstCalls := 0;
  LSecondCalls := 0;
  LCompletedBodyWrites := 0;
  LHandlerReturned := False;
  SetLength(LBodyChunk, BODY_CHUNK_LEN);
  FillChar(LBodyChunk[1], BODY_CHUNK_LEN, Ord('a'));
  LTotalBodyLen := Int64(BODY_CHUNK_LEN) * BODY_CHUNK_COUNT;

  LRouter := THttpRouter.Create;
  LRouter.Get('/block', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LI: Int32;
  begin
    Inc(LFirstCalls);
    AW.GetHeaders.SetHeader('content-length', IntToStr(LTotalBodyLen));
    AW.WriteHeader(HTTP_STATUS_OK);
    for LI := 1 to BODY_CHUNK_COUNT do
    begin
      AW.Write(LBodyChunk[1], SizeUInt(Length(LBodyChunk)));
      Inc(LCompletedBodyWrites);
    end;
    LHandlerReturned := True;
  end);
  LRouter.Get('/after', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    Inc(LSecondCalls);
    LBody := 'after';
    AW.GetHeaders.SetHeader('content-length', '5');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 5);
  end);

  LH1Opts := DefaultH1ServerTransportOptions(AHttpOpts);
  LTransport := TSocketTuningServerTransport.Create(
    NewH1ServerTransport(LH1Opts), SEND_BUFFER_BYTES);
  LHandle := StartServerWithTransportAndOptions(LRouter as IHttpHandler,
    LTransport, AHttpOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      SetSocketRecvBuffer(LConn, RECV_BUFFER_BYTES);
      LConn.Write(PIPELINED_REQ[1], SizeUInt(Length(PIPELINED_REQ)));
      platform_thread_sleep_ns(BACKPRESSURE_WAIT_NS);

      LResp := ReadUntilClosedOrDeadline(LConn, CLOSE_WAIT_MS, LClosed, LTimedOut);

      Check(LClosed,
        ABackendName + ' real socket backpressure path closes connection after write timeout' +
        ' (timedOut=' + BoolToStr(LTimedOut) +
        ', respLen=' + IntToStr(Int64(Length(LResp))) +
        ', firstCalls=' + IntToStr(Int64(LFirstCalls)) +
        ', secondCalls=' + IntToStr(Int64(LSecondCalls)) + ')');
      Check(not LTimedOut,
        ABackendName + ' real socket backpressure path does not stay open past the close wait' +
        ' (respLen=' + IntToStr(Int64(Length(LResp))) +
        ', firstCalls=' + IntToStr(Int64(LFirstCalls)) +
        ', secondCalls=' + IntToStr(Int64(LSecondCalls)) + ')');
      CheckEqual(Int64(1), Int64(LFirstCalls),
        ABackendName + ' real socket backpressure handles the first request once');
      CheckEqual(Int64(0), Int64(LSecondCalls),
        ABackendName + ' real socket backpressure does not process later pipelined requests');
      Check(LHandlerReturned,
        ABackendName + ' real socket backpressure may finish handler-side production before timeout close');
      CheckEqual(Int64(BODY_CHUNK_COUNT), Int64(LCompletedBodyWrites),
        ABackendName + ' real socket backpressure completes every handler-side body write before timeout close');
      Check(Pos('HTTP/1.1 500', LResp) = 0,
        ABackendName + ' real socket backpressure does not append synthetic 500');
      Check(Pos('after', LResp) = 0,
        ABackendName + ' real socket backpressure does not emit the second response body');
      Check(Pos('HTTP/1.1 200', LResp) > 0,
        ABackendName + ' real socket backpressure still begins the first response before timing out');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

procedure RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUpError(
  const ABackendName, ALabel, APipelinedReq, AUnexpectedStatusLine: string;
  const AHttpOpts: THttpServerOptions);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LTransport: IHttpServerTransport;
  LH1Opts: TH1ServerTransportOptions;
  LResp: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
  LFirstCalls: Int32;
  LTotalBodyLen: Int64;
  LBodyChunk: string;
const
  WRITE_TIMEOUT_MS = 50;
  RECV_BUFFER_BYTES = 1024;
  SEND_BUFFER_BYTES = 1024;
  BACKPRESSURE_WAIT_NS = 500000000;
  CLOSE_WAIT_MS = 5000;
  BODY_CHUNK_LEN = 8192;
  BODY_CHUNK_COUNT = 2048;
begin
  LFirstCalls := 0;
  SetLength(LBodyChunk, BODY_CHUNK_LEN);
  FillChar(LBodyChunk[1], BODY_CHUNK_LEN, Ord('b'));
  LTotalBodyLen := Int64(BODY_CHUNK_LEN) * BODY_CHUNK_COUNT;

  LRouter := THttpRouter.Create;
  LRouter.Get('/block', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LI: Int32;
  begin
    Inc(LFirstCalls);
    AW.GetHeaders.SetHeader('content-length', IntToStr(LTotalBodyLen));
    AW.WriteHeader(HTTP_STATUS_OK);
    for LI := 1 to BODY_CHUNK_COUNT do
      AW.Write(LBodyChunk[1], SizeUInt(Length(LBodyChunk)));
  end);

  LH1Opts := DefaultH1ServerTransportOptions(AHttpOpts);
  LTransport := TSocketTuningServerTransport.Create(
    NewH1ServerTransport(LH1Opts), SEND_BUFFER_BYTES);
  LHandle := StartServerWithTransportAndOptions(LRouter as IHttpHandler,
    LTransport, AHttpOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      SetSocketRecvBuffer(LConn, RECV_BUFFER_BYTES);
      LConn.Write(APipelinedReq[1], SizeUInt(Length(APipelinedReq)));
      platform_thread_sleep_ns(BACKPRESSURE_WAIT_NS);

      LResp := ReadUntilClosedOrDeadline(LConn, CLOSE_WAIT_MS, LClosed, LTimedOut);

      Check(LClosed,
        ALabel + ' still closes the connection');
      Check(not LTimedOut,
        ALabel + ' does not outlive close window');
      CheckEqual(Int64(1), Int64(LFirstCalls),
        ALabel + ' still handles the first request once');
      Check(Pos('HTTP/1.1 200', LResp) > 0,
        ALabel + ' still begins the first response');
      Check(Pos(AUnexpectedStatusLine, LResp) = 0,
        ALabel + ' does not emit the follow-up error');
      CheckEqual(Int64(1), Int64(CountSubstring(LResp, 'HTTP/1.1 ')),
        ALabel + ' emits only one status line');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp400(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  PIPELINED_REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'BROKEN /after HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10;
begin
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUpError(
    ABackendName,
    ABackendName + ' malformed follow-up backpressure',
    PIPELINED_REQ,
    'HTTP/1.1 400',
    AHttpOpts);
end;

{$IFDEF NEXTPAS_LINUX}
procedure RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp501(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  PIPELINED_REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /unsupported HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUpError(
    ABackendName,
    ABackendName + ' unsupported transfer-coding backpressure',
    PIPELINED_REQ,
    'HTTP/1.1 501',
    AHttpOpts);
end;

procedure RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp413(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  PIPELINED_REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /too-large HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 3'#13#10 +
    'Connection: close'#13#10#13#10 +
    'abc';
begin
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUpError(
    ABackendName,
    ABackendName + ' payload-too-large follow-up backpressure',
    PIPELINED_REQ,
    'HTTP/1.1 413',
    AHttpOpts);
end;

procedure RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp431(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  PIPELINED_REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /too-many-headers HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'X-Long: 0123456789012345678901234567890123456789'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUpError(
    ABackendName,
    ABackendName + ' header-too-large follow-up backpressure',
    PIPELINED_REQ,
    'HTTP/1.1 431',
    AHttpOpts);
end;

procedure RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp417(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  PIPELINED_REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /unsupported-expect HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue, fancy'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUpError(
    ABackendName,
    ABackendName + ' unsupported Expect follow-up backpressure',
    PIPELINED_REQ,
    'HTTP/1.1 417',
    AHttpOpts);
end;

procedure RunRealSocketQueuedFollowUpErrorPreservesWireOrder(
  const ALabel, ARequest, AExpectedStatusLine: string;
  const AHttpOpts: THttpServerOptions);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LTransport: IHttpServerTransport;
  LH1Opts: TH1ServerTransportOptions;
  LHttpOpts: THttpServerOptions;
  LResp: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
  LFirstCalls: Int32;
  LBodyChunk: string;
  LBodyPrefix: string;
  LBodyLen: Int64;
  LFirstStatusPos: SizeInt;
  LFirstBodyPos: SizeInt;
  LFollowStatusPos: SizeInt;
const
  RECV_BUFFER_BYTES = 1024;
  SEND_BUFFER_BYTES = 1024;
  BACKPRESSURE_WAIT_NS = 500000000;
  CLOSE_WAIT_MS = 5000;
  BODY_CHUNK_LEN = 8192;
  BODY_CHUNK_COUNT = 8;
begin
  LHttpOpts := AHttpOpts;
  LFirstCalls := 0;
  LBodyPrefix := 'queued-order-prefix:';
  SetLength(LBodyChunk, BODY_CHUNK_LEN);
  FillChar(LBodyChunk[1], BODY_CHUNK_LEN, Ord('q'));
  LBodyLen := Int64(Length(LBodyPrefix)) +
    (Int64(BODY_CHUNK_LEN) * BODY_CHUNK_COUNT);

  LRouter := THttpRouter.Create;
  LRouter.Get('/block', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LI: Int32;
  begin
    Inc(LFirstCalls);
    AW.GetHeaders.SetHeader('content-length', IntToStr(LBodyLen));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBodyPrefix[1], SizeUInt(Length(LBodyPrefix)));
    for LI := 1 to BODY_CHUNK_COUNT do
      AW.Write(LBodyChunk[1], SizeUInt(Length(LBodyChunk)));
  end);

  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);
  LTransport := TSocketTuningServerTransport.Create(
    NewH1ServerTransport(LH1Opts), SEND_BUFFER_BYTES);
  LHandle := StartServerWithTransportAndOptions(LRouter as IHttpHandler,
    LTransport, LHttpOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      SetSocketRecvBuffer(LConn, RECV_BUFFER_BYTES);
      LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
      platform_thread_sleep_ns(BACKPRESSURE_WAIT_NS);

      LResp := ReadUntilClosedOrDeadline(LConn, CLOSE_WAIT_MS, LClosed, LTimedOut);

      Check(LClosed,
        ALabel + ': closes the connection' +
        ' (timedOut=' + BoolToStr(LTimedOut) +
        ', respLen=' + IntToStr(Int64(Length(LResp))) + ')');
      Check(not LTimedOut,
        ALabel + ': finishes within close window' +
        ' (respLen=' + IntToStr(Int64(Length(LResp))) + ')');
      CheckEqual(Int64(1), Int64(LFirstCalls),
        ALabel + ': handles the first request once');
      Check(Pos('HTTP/1.1 500', LResp) = 0,
        ALabel + ': does not append synthetic 500');
      CheckEqual(Int64(2), Int64(CountSubstring(LResp, 'HTTP/1.1 ')),
        ALabel + ': emits exactly two status lines');

      LFirstStatusPos := Pos('HTTP/1.1 200 OK', LResp);
      LFirstBodyPos := Pos(LBodyPrefix, LResp);
      LFollowStatusPos := Pos(AExpectedStatusLine, LResp);
      Check(LFirstStatusPos > 0,
        ALabel + ': emits the first 200 status line');
      Check(LFirstBodyPos > LFirstStatusPos,
        ALabel + ': emits first response body bytes');
      Check(LFollowStatusPos > LFirstBodyPos,
        ALabel + ': keeps follow-up error behind the first response body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunRealSocketQueuedFollowUp400PreservesWireOrder(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /bad HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 1'#13#10 +
    'Content-Length: 2'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunRealSocketQueuedFollowUpErrorPreservesWireOrder(
    ABackendName + ' queued follow-up 400 live path', REQ,
    'HTTP/1.1 400 Bad Request', AHttpOpts);
end;

procedure RunRealSocketQueuedFollowUp413PreservesWireOrder(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /too-large HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 3'#13#10 +
    'Connection: close'#13#10#13#10 +
    'abc';
begin
  RunRealSocketQueuedFollowUpErrorPreservesWireOrder(
    ABackendName + ' queued follow-up 413 live path', REQ,
    'HTTP/1.1 413 Payload Too Large', AHttpOpts);
end;

procedure RunRealSocketQueuedFollowUp431PreservesWireOrder(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /too-many-headers HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'X-Long: 0123456789012345678901234567890123456789'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunRealSocketQueuedFollowUpErrorPreservesWireOrder(
    ABackendName + ' queued follow-up 431 live path', REQ,
    'HTTP/1.1 431 Request Header Fields Too Large', AHttpOpts);
end;

procedure RunRealSocketQueuedFollowUp501PreservesWireOrder(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /unsupported HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunRealSocketQueuedFollowUpErrorPreservesWireOrder(
    ABackendName + ' queued follow-up 501 live path', REQ,
    'HTTP/1.1 501 Not Implemented', AHttpOpts);
end;

procedure RunRealSocketQueuedFollowUp417PreservesWireOrder(
  const ABackendName: string; const AHttpOpts: THttpServerOptions);
const
  REQ =
    'GET /block HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /unsupported-expect HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue, fancy'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunRealSocketQueuedFollowUpErrorPreservesWireOrder(
    ABackendName + ' queued follow-up 417 live path', REQ,
    'HTTP/1.1 417 Expectation Failed', AHttpOpts);
end;

{$ENDIF}

{ Test 5: Shutdown stops accepting }
{ Test 6: POST request with body }
{ Helper: read a single HTTP response from a connection (reads headers + content-length body) }
function ReadOneResponse(const AConn: ITcpStream): string;
var
  LBuf: array[0..0] of Byte;
  LN: SizeUInt;
  LHeaderEnd: Int32;
  LContentLength: Int32;
  LClPos, LClEnd: Int32;
  LClStr: string;
  LBodyRead: Int32;
begin
  Result := '';
  { Read byte-by-byte until we see CRLFCRLF (header end) }
  repeat
    try
      LN := AConn.Read(LBuf[0], 1);
    except
      LN := 0;
    end;
    if LN = 0 then Exit;
    Result := Result + Chr(LBuf[0]);
    LHeaderEnd := Pos(#13#10#13#10, Result);
  until LHeaderEnd > 0;

  { Parse content-length from headers }
  LContentLength := 0;
  LClPos := Pos('content-length: ', Result);
  if LClPos > 0 then
  begin
    LClPos := LClPos + 16; { length of 'content-length: ' }
    LClEnd := LClPos;
    while (LClEnd <= Length(Result)) and (Result[LClEnd] >= '0') and (Result[LClEnd] <= '9') do
      Inc(LClEnd);
    LClStr := Copy(Result, LClPos, LClEnd - LClPos);
    LContentLength := Int32(StrToInt(LClStr));
  end;

  { Read body bytes }
  LBodyRead := Length(Result) - (LHeaderEnd + 3); { bytes after CRLFCRLF already in buffer }
  while LBodyRead < LContentLength do
  begin
    try
      LN := AConn.Read(LBuf[0], 1);
    except
      LN := 0;
    end;
    if LN = 0 then Exit;
    Result := Result + Chr(LBuf[0]);
    Inc(LBodyRead);
  end;
end;

{ Test 7: Keep-alive — two requests on same connection }
{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

procedure RunExpectContinueSendsInterimResponse(const AUseEpoll: Boolean;
  const ALabel, AExpectValue: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LReqHeaders, LResp1, LResp2: string;
  LSeenEcho: Boolean;
  LGotBody: string;
const
  REQ_HEADERS =
    'POST /echo HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: %EXPECT%'#13#10#13#10;
  REQ_BODY = 'hello';
begin
  LSeenEcho := False;
  LGotBody := '';
  LReqHeaders := StringReplace(REQ_HEADERS, '%EXPECT%', AExpectValue, True);
  LRouter := THttpRouter.Create;
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenEcho := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'echo:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  if AUseEpoll then
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort)
  else
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
      LConn.Write(LReqHeaders[1], SizeUInt(Length(LReqHeaders)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 100 Continue', LResp1) > 0,
        ALabel + ': interim 100 continue returned');
      Check(not LSeenEcho, ALabel + ': handler not called before body send');

      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ_BODY[1], SizeUInt(Length(REQ_BODY)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200 OK', LResp2) > 0,
        ALabel + ': final response 200');
      Check(Pos('echo:hello', LResp2) > 0,
        ALabel + ': final body preserved');
      Check(LSeenEcho, ALabel + ': handler called after body send');
      CheckEqual('hello', LGotBody, ALabel + ': handler sees full request body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestExpectContinueSendsInterimResponse;
begin
  RunExpectContinueSendsInterimResponse(False, 'expect-continue threaded',
    '100-continue');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueSendsInterimResponseEpollBackend;
begin
  RunExpectContinueSendsInterimResponse(True, 'expect-continue epoll',
    '100-continue');
end;
{$ENDIF}

procedure TestExpectContinueDuplicateMembersStillSendInterimResponse;
begin
  RunExpectContinueSendsInterimResponse(False,
    'expect-continue duplicate members threaded',
    '100-continue, 100-continue');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueDuplicateMembersStillSendInterimResponseEpollBackend;
begin
  RunExpectContinueSendsInterimResponse(True,
    'expect-continue duplicate members epoll',
    '100-continue, 100-continue');
end;
{$ENDIF}

procedure RunExpectContinueDeclaredOversizeRejectsEarly(const AUseEpoll: Boolean;
  const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LHandlerCalled: Boolean;
  LOpts: THttpServerOptions;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 2048'#13#10 +
    'Expect: 100-continue'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LReply: string;
  begin
    LHandlerCalled := True;
    LReply := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);

  LOpts := THttpServerOptions.Default;
  LOpts.MaxBodySize := 1024;
  if AUseEpoll then
    LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
      LConn.Write(REQ_HEADERS[1], SizeUInt(Length(REQ_HEADERS)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 413 Payload Too Large', LResp) > 0,
        ALabel + ': declared oversize rejected with final 413');
      Check(Pos('HTTP/1.1 100 Continue', LResp) = 0,
        ALabel + ': no interim 100 for declared oversize body');
      Check(Pos('connection: close', LResp) > 0,
        ALabel + ': declared oversize closes connection');
      Check(not LHandlerCalled,
        ALabel + ': handler not called before any body bytes arrive');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestExpectContinueDeclaredOversizeRejectsEarly;
begin
  RunExpectContinueDeclaredOversizeRejectsEarly(False,
    'expect-continue oversize threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueDeclaredOversizeRejectsEarlyEpollBackend;
begin
  RunExpectContinueDeclaredOversizeRejectsEarly(True,
    'expect-continue oversize epoll');
end;
{$ENDIF}

procedure RunUnsupportedExpectRejectsEarly(const AUseEpoll: Boolean;
  const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue, fancy'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LReply: string;
  begin
    LHandlerCalled := True;
    LReply := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);

  if AUseEpoll then
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort)
  else
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
      LConn.Write(REQ_HEADERS[1], SizeUInt(Length(REQ_HEADERS)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 417 Expectation Failed', LResp) > 0,
        ALabel + ': unsupported expect rejected with final 417');
      Check(Pos('HTTP/1.1 100 Continue', LResp) = 0,
        ALabel + ': unsupported expect does not emit interim 100');
      Check(Pos('connection: close', LResp) > 0,
        ALabel + ': unsupported expect closes connection');
      Check(not LHandlerCalled,
        ALabel + ': handler not called before any body bytes arrive');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestUnsupportedExpectRejectsEarly;
begin
  RunUnsupportedExpectRejectsEarly(False, 'unsupported expect threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestUnsupportedExpectRejectsEarlyEpollBackend;
begin
  RunUnsupportedExpectRejectsEarly(True, 'unsupported expect epoll');
end;
{$ENDIF}

procedure RunRepeatedExpectHeaderUnsupportedMemberRejectsEarly(
  const AUseEpoll: Boolean; const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Expect: fancy'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LReply: string;
  begin
    LHandlerCalled := True;
    LReply := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);

  if AUseEpoll then
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort)
  else
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
      LConn.Write(REQ_HEADERS[1], SizeUInt(Length(REQ_HEADERS)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 417 Expectation Failed', LResp) > 0,
        ALabel + ': repeated expect headers with unsupported member reject with final 417');
      Check(Pos('HTTP/1.1 100 Continue', LResp) = 0,
        ALabel + ': repeated expect headers do not emit interim 100');
      Check(Pos('connection: close', LResp) > 0,
        ALabel + ': repeated expect headers close connection');
      Check(not LHandlerCalled,
        ALabel + ': handler not called before any body bytes arrive');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestRepeatedExpectHeaderUnsupportedMemberRejectsEarly;
begin
  RunRepeatedExpectHeaderUnsupportedMemberRejectsEarly(False,
    'repeated expect headers unsupported member threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestRepeatedExpectHeaderUnsupportedMemberRejectsEarlyEpollBackend;
begin
  RunRepeatedExpectHeaderUnsupportedMemberRejectsEarly(True,
    'repeated expect headers unsupported member epoll');
end;
{$ENDIF}

procedure RunExpectContinueChunkedBodyReadable(const AUseEpoll: Boolean;
  const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
  LSeenEcho: Boolean;
  LGotBody: string;
const
  REQ_HEADERS =
    'POST /echo HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Expect: 100-continue'#13#10#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '6'#13#10' world'#13#10 +
    '0'#13#10#13#10;
begin
  LSeenEcho := False;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..31] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenEcho := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'echo:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);

  if AUseEpoll then
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort)
  else
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
      LConn.Write(REQ_HEADERS[1], SizeUInt(Length(REQ_HEADERS)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 100 Continue', LResp1) > 0,
        ALabel + ': interim 100 continue returned');
      Check(not LSeenEcho, ALabel + ': handler not called before chunked body send');

      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ_BODY[1], SizeUInt(Length(REQ_BODY)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200 OK', LResp2) > 0,
        ALabel + ': final response 200');
      Check(Pos('echo:hello world', LResp2) > 0,
        ALabel + ': final body preserved');
      Check(LSeenEcho, ALabel + ': handler called after chunked body send');
      CheckEqual('hello world', LGotBody,
        ALabel + ': handler sees full decoded chunked body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestExpectContinueChunkedBodyReadable;
begin
  RunExpectContinueChunkedBodyReadable(False,
    'expect-continue chunked threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueChunkedBodyReadableEpollBackend;
begin
  RunExpectContinueChunkedBodyReadable(True,
    'expect-continue chunked epoll');
end;
{$ENDIF}

procedure RunExpectContinueChunkedMaxBodySizeRejectsAfterInterim(
  const AUseEpoll: Boolean; const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LChunk1: string;
  LChunk2: string;
  LChunkHex1: string;
  LChunkHex2: string;
  LReqBody: string;
  LResp1, LResp2: string;
  LHandlerCalled: Boolean;
  LOpts: THttpServerOptions;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Expect: 100-continue'#13#10#13#10;
begin
  LHandlerCalled := False;
  SetLength(LChunk1, 700);
  FillChar(LChunk1[1], 700, Ord('B'));
  SetLength(LChunk2, 700);
  FillChar(LChunk2[1], 700, Ord('C'));
  LChunkHex1 := IntToHex(Length(LChunk1), 1);
  LChunkHex2 := IntToHex(Length(LChunk2), 1);
  LReqBody := LChunkHex1 + #13#10 +
    LChunk1 + #13#10 +
    LChunkHex2 + #13#10 +
    LChunk2 + #13#10 +
    '0'#13#10#13#10;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LReply: string;
  begin
    LHandlerCalled := True;
    LReply := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);

  LOpts := THttpServerOptions.Default;
  LOpts.MaxBodySize := 1024;
  if AUseEpoll then
    LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
      LConn.Write(REQ_HEADERS[1], SizeUInt(Length(REQ_HEADERS)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 100 Continue', LResp1) > 0,
        ALabel + ': interim 100 continue returned');
      Check(not LHandlerCalled,
        ALabel + ': handler not called before oversize chunked body send');

      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LReqBody[1], SizeUInt(Length(LReqBody)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 413 Payload Too Large', LResp2) > 0,
        ALabel + ': chunked oversize rejected with final 413 after interim 100');
      Check(not LHandlerCalled,
        ALabel + ': handler not called when chunked body crosses max size');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
  const AOpts: THttpServerOptions; const AExtraHeaders, AReqBody,
  AExpectedStatusLine, ALabel: string;
  const AShutdownWriteAfterBody: Boolean = False);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
  LHandlerCalled: Boolean;
  LReqHeaders: string;
begin
  LHandlerCalled := False;
  LReqHeaders :=
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    AExtraHeaders +
    'Expect: 100-continue'#13#10#13#10;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);

  LHandle := StartServerWithOptions(LRouter as IHttpHandler, AOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
      LConn.Write(LReqHeaders[1], SizeUInt(Length(LReqHeaders)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 100 Continue', LResp1) > 0,
        ALabel + ': interim 100 continue returned');
      Check(Pos('HTTP/1.1 200', LResp1) = 0,
        ALabel + ': no final response before malformed chunked body');
      Check(not LHandlerCalled,
        ALabel + ': handler not called before malformed chunked body send');

      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(AReqBody[1], SizeUInt(Length(AReqBody)));
      if AShutdownWriteAfterBody then
        LConn.Shutdown;
      LResp2 := ReadOneResponse(LConn);
      Check(Pos(AExpectedStatusLine, LResp2) > 0,
        ALabel + ': malformed chunked body rejected after interim 100');
      Check(Pos('HTTP/1.1 100 Continue', LResp2) = 0,
        ALabel + ': final response does not repeat interim 100');
      Check(Pos('HTTP/1.1 200', LResp2) = 0,
        ALabel + ': malformed chunked body never reaches success response');
      Check(not LHandlerCalled,
        ALabel + ': handler not called for malformed chunked body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunExpectContinueChunkedMalformedBodyRejectedAfterInterim(
  const AUseEpoll: Boolean; const AReqBody, AExpectedStatusLine,
  ALabel: string);
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  if AUseEpoll then
    LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts, '', AReqBody, AExpectedStatusLine, ALabel, False);
end;

procedure TestExpectContinueChunkedMaxBodySizeRejectsAfterInterim;
begin
  RunExpectContinueChunkedMaxBodySizeRejectsAfterInterim(False,
    'expect-continue chunked max-body threaded');
end;

procedure TestExpectContinueChunkedInvalidChunkSizeRejectsAfterInterim;
const
  REQ_BODY =
    'Z'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterim(False,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked invalid chunk-size threaded');
end;

procedure TestExpectContinueChunkedMalformedChunkExtensionRejectsAfterInterim;
const
  REQ_BODY =
    '5;'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterim(False,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked malformed chunk extension threaded');
end;

procedure TestExpectContinueChunkedMissingChunkDataCrLfRejectsAfterInterim;
const
  REQ_BODY =
    '5'#13#10'hello0'#13#10#13#10;
begin
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterim(False,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked missing chunk-data CRLF threaded');
end;

procedure TestExpectContinueChunkedMalformedTrailerFieldRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Bad'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'Bad Header: value'#13#10#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked malformed trailer field threaded');
end;

procedure TestExpectContinueChunkedTruncatedTrailerFieldNameAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test';
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer field-name eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerSeparatorAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test:';
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer separator eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerEmptyValueCrAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test:'#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer empty-value cr eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerEmptyValueAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test:'#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer empty-value eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerEmptyValueSectionCrAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test:'#13#10#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer empty-value section cr eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerWhitespaceCrAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: '#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer whitespace cr eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerWhitespaceAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: ';
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer whitespace eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerWhitespaceSectionAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: '#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer whitespace section eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerWhitespaceSectionCrAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: '#13#10#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer whitespace section cr eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerFieldLineAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value';
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer field line eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerFieldCrAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer field cr eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerSectionCrAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13#10#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer section cr eof threaded',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerSectionAtEofRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer section eof threaded',
    True);
end;

procedure TestExpectContinueChunkedOversizeTrailerRejectsAfterInterim;
const
  EXTRA_HEADERS = 'Trailer: X-Big'#13#10;
var
  LOpts: THttpServerOptions;
  LTrailerValue: string;
  LReqBody: string;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  SetLength(LTrailerValue, 300);
  FillChar(LTrailerValue[1], 300, Ord('x'));
  LReqBody :=
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Big: ' + LTrailerValue + #13#10#13#10;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    LReqBody,
    'HTTP/1.1 431 Request Header Fields Too Large',
    'expect-continue chunked oversize trailer threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueChunkedMaxBodySizeRejectsAfterInterimEpollBackend;
begin
  RunExpectContinueChunkedMaxBodySizeRejectsAfterInterim(True,
    'expect-continue chunked max-body epoll');
end;

procedure TestExpectContinueChunkedInvalidChunkSizeRejectsAfterInterimEpollBackend;
const
  REQ_BODY =
    'Z'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterim(True,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked invalid chunk-size epoll');
end;

procedure TestExpectContinueChunkedMalformedChunkExtensionRejectsAfterInterimEpollBackend;
const
  REQ_BODY =
    '5;'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterim(True,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked malformed chunk extension epoll');
end;

procedure TestExpectContinueChunkedMissingChunkDataCrLfRejectsAfterInterimEpollBackend;
const
  REQ_BODY =
    '5'#13#10'hello0'#13#10#13#10;
begin
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterim(True,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked missing chunk-data CRLF epoll');
end;

procedure TestExpectContinueChunkedMalformedTrailerFieldRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Bad'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'Bad Header: value'#13#10#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked malformed trailer field epoll');
end;

procedure TestExpectContinueChunkedTruncatedTrailerFieldNameAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test';
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer field-name eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerSeparatorAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test:';
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer separator eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerEmptyValueCrAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test:'#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer empty-value cr eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerEmptyValueAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test:'#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer empty-value eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerEmptyValueSectionCrAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test:'#13#10#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer empty-value section cr eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerWhitespaceCrAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: '#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer whitespace cr eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerWhitespaceAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: ';
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer whitespace eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerWhitespaceSectionAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: '#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer whitespace section eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerWhitespaceSectionCrAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: '#13#10#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer whitespace section cr eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerFieldLineAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value';
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer field line eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerFieldCrAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer field cr eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerSectionCrAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13#10#13;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer section cr eof epoll',
    True);
end;

procedure TestExpectContinueChunkedTruncatedTrailerSectionAtEofRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Test'#13#10;
  REQ_BODY =
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13#10;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    REQ_BODY,
    'HTTP/1.1 400 Bad Request',
    'expect-continue chunked truncated trailer section eof epoll',
    True);
end;

procedure TestExpectContinueChunkedOversizeTrailerRejectsAfterInterimEpollBackend;
const
  EXTRA_HEADERS = 'Trailer: X-Big'#13#10;
var
  LOpts: THttpServerOptions;
  LTrailerValue: string;
  LReqBody: string;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LOpts.MaxHeaderSize := 256;
  SetLength(LTrailerValue, 300);
  FillChar(LTrailerValue[1], 300, Ord('x'));
  LReqBody :=
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Big: ' + LTrailerValue + #13#10#13#10;
  RunExpectContinueChunkedMalformedBodyRejectedAfterInterimWithHeadersAndOptions(
    LOpts,
    EXTRA_HEADERS,
    LReqBody,
    'HTTP/1.1 431 Request Header Fields Too Large',
    'expect-continue chunked oversize trailer epoll');
end;
{$ENDIF}

procedure RunExpectContinueBodyStallIdleTimeoutClosesSafely(
  const AUseEpoll: Boolean; const ALabel, AReqHeaders, APartialBody: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
  LHandlerCalled: Boolean;
  LOpts: THttpServerOptions;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LReply: string;
  begin
    LHandlerCalled := True;
    LReply := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);

  LOpts := THttpServerOptions.Default;
  { PD-1B: post-100 body stall is gated by ReadTimeout (FReadMs), not IdleTimeout.
    Align both so client 5s observation window still sees close. }
  LOpts.ReadTimeout := 200;
  LOpts.IdleTimeout := 200;
  if AUseEpoll then
    LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(1000)));
      LConn.Write(AReqHeaders[1], SizeUInt(Length(AReqHeaders)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 100 Continue', LResp1) > 0,
        ALabel + ': interim 100 continue returned');
      Check(Pos('HTTP/1.1 200', LResp1) = 0,
        ALabel + ': no final success response before body bytes');
      Check(not LHandlerCalled,
        ALabel + ': handler not called before body bytes arrive');

      if APartialBody <> '' then
        LConn.Write(APartialBody[1], SizeUInt(Length(APartialBody)));
      LResp2 := ReadUntilClosedOrDeadline(LConn, 5000, LClosed, LTimedOut);
      Check(LClosed,
        ALabel + ': stalled body closes connection within observation window');
      Check(not LTimedOut,
        ALabel + ': stalled body close does not overrun read deadline');
      Check(Pos('HTTP/1.1 100 Continue', LResp2) = 0,
        ALabel + ': interim 100 is not repeated after stall');
      Check(Pos('HTTP/1.1 200', LResp2) = 0,
        ALabel + ': stalled body never reaches success response');
      Check(Pos('HTTP/1.1 500', LResp2) = 0,
        ALabel + ': stalled body does not append synthetic 500');
      CheckEqual(Int64(0), Int64(CountSubstring(LResp2, 'HTTP/1.1 ')),
        ALabel + ': no final status line is emitted after idle-timeout close');
      Check(not LHandlerCalled,
        ALabel + ': handler is never entered when body stalls after interim 100');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestExpectContinueFixedLengthBodyStallIdleTimeoutClosesSafely;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
  PARTIAL_BODY = 'ab';
begin
  RunExpectContinueBodyStallIdleTimeoutClosesSafely(False,
    'expect-continue fixed-length body stall threaded',
    REQ_HEADERS, PARTIAL_BODY);
end;

procedure TestExpectContinueZeroProgressFixedLengthBodyIdleTimeoutClosesSafely;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueBodyStallIdleTimeoutClosesSafely(False,
    'expect-continue fixed-length zero progress threaded',
    REQ_HEADERS, '');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueFixedLengthBodyStallIdleTimeoutClosesSafelyEpollBackend;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
  PARTIAL_BODY = 'ab';
begin
  RunExpectContinueBodyStallIdleTimeoutClosesSafely(True,
    'expect-continue fixed-length body stall epoll',
    REQ_HEADERS, PARTIAL_BODY);
end;

procedure TestExpectContinueZeroProgressFixedLengthBodyIdleTimeoutClosesSafelyEpollBackend;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueBodyStallIdleTimeoutClosesSafely(True,
    'expect-continue fixed-length zero progress epoll',
    REQ_HEADERS, '');
end;
{$ENDIF}

procedure TestExpectContinueChunkedBodyStallIdleTimeoutClosesSafely;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
  PARTIAL_BODY =
    '3'#13#10 +
    'ab';
begin
  RunExpectContinueBodyStallIdleTimeoutClosesSafely(False,
    'expect-continue chunked body stall threaded',
    REQ_HEADERS, PARTIAL_BODY);
end;

procedure TestExpectContinueZeroProgressChunkedBodyIdleTimeoutClosesSafely;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueBodyStallIdleTimeoutClosesSafely(False,
    'expect-continue chunked zero progress threaded',
    REQ_HEADERS, '');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueChunkedBodyStallIdleTimeoutClosesSafelyEpollBackend;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
  PARTIAL_BODY =
    '3'#13#10 +
    'ab';
begin
  RunExpectContinueBodyStallIdleTimeoutClosesSafely(True,
    'expect-continue chunked body stall epoll',
    REQ_HEADERS, PARTIAL_BODY);
end;

procedure TestExpectContinueZeroProgressChunkedBodyIdleTimeoutClosesSafelyEpollBackend;
const
  REQ_HEADERS =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueBodyStallIdleTimeoutClosesSafely(True,
    'expect-continue chunked zero progress epoll',
    REQ_HEADERS, '');
end;
{$ENDIF}

procedure RunExpectContinueBodylessRequestDoesNotEmitInterim(
  const AUseEpoll: Boolean; const ALabel, AReq, AReason: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LSeenEcho: Boolean;
  LGotBody: string;
begin
  LSeenEcho := False;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenEcho := True;
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LBody := 'echo:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);

  if AUseEpoll then
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort)
  else
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(AReq[1], SizeUInt(Length(AReq)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('HTTP/1.1 200 OK', LResp) > 0,
        ALabel + ': final response 200 without interim 100');
      Check(Pos('HTTP/1.1 100 Continue', LResp) = 0,
        ALabel + ': ' + AReason + ' does not emit interim 100');
      Check(Pos('echo:', LResp) > 0,
        ALabel + ': final body still emitted');
      Check(LSeenEcho, ALabel + ': handler called immediately');
      CheckEqual('', LGotBody, ALabel + ': handler sees empty request body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunExpectContinueZeroContentLengthDoesNotEmitInterim(
  const AUseEpoll: Boolean; const ALabel: string);
const
  REQ =
    'POST /echo HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 0'#13#10 +
    'Expect: 100-continue'#13#10#13#10;
begin
  RunExpectContinueBodylessRequestDoesNotEmitInterim(AUseEpoll, ALabel, REQ,
    'zero content-length');
end;

procedure TestExpectContinueZeroContentLengthDoesNotEmitInterim;
begin
  RunExpectContinueZeroContentLengthDoesNotEmitInterim(False,
    'expect-continue zero-length threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueZeroContentLengthDoesNotEmitInterimEpollBackend;
begin
  RunExpectContinueZeroContentLengthDoesNotEmitInterim(True,
    'expect-continue zero-length epoll');
end;
{$ENDIF}

procedure RunExpectContinueWithoutDeclaredBodyDoesNotEmitInterim(
  const AUseEpoll: Boolean; const ALabel: string);
const
  REQ =
    'POST /echo HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Expect: 100-continue'#13#10#13#10;
begin
  RunExpectContinueBodylessRequestDoesNotEmitInterim(AUseEpoll, ALabel, REQ,
    'missing body declaration');
end;

procedure TestExpectContinueWithoutDeclaredBodyDoesNotEmitInterim;
begin
  RunExpectContinueWithoutDeclaredBodyDoesNotEmitInterim(False,
    'expect-continue no-length threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueWithoutDeclaredBodyDoesNotEmitInterimEpollBackend;
begin
  RunExpectContinueWithoutDeclaredBodyDoesNotEmitInterim(True,
    'expect-continue no-length epoll');
end;
{$ENDIF}

procedure RunHeadExpectWithoutDeclaredBodyDoesNotEmitInterim(
  const AUseEpoll: Boolean; const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
  LBody: string;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmHead, '/head-expect', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);

  if AUseEpoll then
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort)
  else
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'HEAD /head-expect HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Expect: 100-continue'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200 OK', LResp) = 1,
      ALabel + ': final response 200 without interim 100');
    Check(Pos('HTTP/1.1 100 Continue', LResp) = 0,
      ALabel + ': no-length HEAD does not emit interim 100');
    Check(Pos('content-length: 4'#13#10, LResp) > 0,
      ALabel + ': explicit content-length preserved');
    Check(Pos('transfer-encoding: chunked', LResp) = 0,
      ALabel + ': no chunked header');
    Check(Pos('pong', LResp) = 0,
      ALabel + ': HEAD response stays bodyless on wire');
    Check(LHandlerCalled, ALabel + ': handler called immediately');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHeadExpectWithoutDeclaredBodyDoesNotEmitInterim;
begin
  RunHeadExpectWithoutDeclaredBodyDoesNotEmitInterim(False,
    'head expect no-length threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestHeadExpectWithoutDeclaredBodyDoesNotEmitInterimEpollBackend;
begin
  RunHeadExpectWithoutDeclaredBodyDoesNotEmitInterim(True,
    'head expect no-length epoll');
end;
{$ENDIF}

procedure RunExpectContinueMalformedTransferCodingRejectsEarly(
  const AUseEpoll: Boolean; const ALabel, ARequest,
  AExpectedStatusLine: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);

  if AUseEpoll then
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort)
  else
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, ARequest);
    Check(Pos(AExpectedStatusLine, LResp) = 1,
      ALabel + ': final error response returned directly');
    Check(Pos('HTTP/1.1 100 Continue', LResp) = 0,
      ALabel + ': no interim 100 before transfer-coding rejection');
    Check(not LHandlerCalled,
      ALabel + ': handler not called before transfer-coding rejection');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestExpectContinueUnsupportedTransferCodingRejectsEarly;
const
  REQ =
    'POST / HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueMalformedTransferCodingRejectsEarly(False,
    'expect unsupported transfer-coding threaded', REQ,
    'HTTP/1.1 501 Not Implemented');
end;

procedure TestExpectContinueNonChunkedTransferCodingRejectsEarly;
const
  REQ =
    'POST / HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueMalformedTransferCodingRejectsEarly(False,
    'expect non-chunked transfer-coding threaded', REQ,
    'HTTP/1.1 501 Not Implemented');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueUnsupportedTransferCodingRejectsEarlyEpollBackend;
const
  REQ =
    'POST / HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueMalformedTransferCodingRejectsEarly(True,
    'expect unsupported transfer-coding epoll', REQ,
    'HTTP/1.1 501 Not Implemented');
end;
{$ENDIF}

procedure TestExpectContinueChunkedMustBeFinalTransferCodingRejectsEarly;
const
  REQ =
    'POST / HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked, gzip'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueMalformedTransferCodingRejectsEarly(False,
    'expect chunked-not-final threaded', REQ,
    'HTTP/1.1 400 Bad Request');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestExpectContinueChunkedMustBeFinalTransferCodingRejectsEarlyEpollBackend;
const
  REQ =
    'POST / HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: chunked, gzip'#13#10 +
    'Expect: 100-continue'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunExpectContinueMalformedTransferCodingRejectsEarly(True,
    'expect chunked-not-final epoll', REQ,
    'HTTP/1.1 400 Bad Request');
end;
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{ Test 8: Connection: close header stops keep-alive }
{ Test 9: HTTP/1.0 without keep-alive closes connection }
{ Test 10: POST body readable via IReader }
{ Test 11: Large body (131072 bytes) }
{ Test 12: Generic malformed request returns explicit 400 }
{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{ Test 13: Query parameters }
{ Test 14: RemoteAddr contains 127.0.0.1 }
{ Test 15: Concurrent stress — 10 threads x 100 requests }
var
  GStressSuccess: Int32 = 0;
  GStressDone: Int32 = 0;
  GServerPort: UInt16 = 0;

function StressThread(AParam: Pointer): Pointer; cdecl;
var
  LI: Int32;
  LConn: ITcpStream;
  LBuf: array[0..1023] of Byte;
  LRead: SizeUInt;
  LReq: string;
  LHeaderEnd: Int32;
  LResp: string;
begin
  Result := nil;
  try
    LReq := 'GET / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10;
    LConn := TcpConnect('127.0.0.1', GServerPort);
    LConn.SetNoDelay(True);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(10)));
    for LI := 1 to 100 do
    begin
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      { Read until we see end of response (CRLFCRLF + body) }
      LResp := '';
      repeat
        LRead := LConn.Read(LBuf[0], 1024);
        if LRead > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LRead));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LRead) + 1], LRead);
        end;
        LHeaderEnd := Pos(#13#10#13#10, LResp);
      until (LHeaderEnd > 0) or (LRead = 0);
      if Pos('200', LResp) > 0 then
        InterlockedIncrement(GStressSuccess);
    end;
    LConn.Close;
  except
  end;
  InterlockedIncrement(GStressDone);
end;

procedure RunHeaderFieldOverMaxHeaderSizeRejected(const AUseEpoll: Boolean;
  const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LOpts: THttpServerOptions;
  LReq: string;
  LBigHeader: string;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LHandlerCalled := True;
    LBody := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 2);
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  if AUseEpoll then
    LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    SetLength(LBigHeader, 300);
    FillChar(LBigHeader[1], 300, Ord('x'));
    LReq := 'GET / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'X-Big: ' + LBigHeader + #13#10 +
      'Connection: close'#13#10#13#10;
    LResp := SendRawRequest(LPort, LReq);
    Check(Pos('HTTP/1.1 431', LResp) > 0,
      ALabel + ': oversized header field returns explicit 431');
    Check(not LHandlerCalled,
      ALabel + ': handler not called for oversized header field');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

procedure RunRequestTargetOverMaxHeaderSizeRejected(const AUseEpoll: Boolean;
  const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LOpts: THttpServerOptions;
  LReq: string;
  LPath: string;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LHandlerCalled := True;
    LBody := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 2);
  end);

  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  if AUseEpoll then
    LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;

  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    SetLength(LPath, 400);
    FillChar(LPath[1], 400, Ord('a'));
    LReq := 'GET /' + LPath + ' HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10#13#10;
    LResp := SendRawRequest(LPort, LReq);
    Check(Pos('HTTP/1.1 431', LResp) > 0,
      ALabel + ': request-target over MaxHeaderSize returns 431');
    Check(not LHandlerCalled,
      ALabel + ': handler not called for oversized request-target');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

procedure RunFixedLengthMaxBodySizeRejected(const AUseEpoll: Boolean;
  const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LOpts: THttpServerOptions;
  LBody: string;
  LReq: string;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LReply: string;
  begin
    LHandlerCalled := True;
    LReply := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], 2);
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.MaxBodySize := 1024; { 1KB limit }
  if AUseEpoll then
    LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    { Send body > 1KB }
    SetLength(LBody, 2048);
    FillChar(LBody[1], 2048, Ord('A'));
    LReq := 'POST / HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Content-Length: 2048'#13#10 +
      'Connection: close'#13#10#13#10 +
      LBody;
    LResp := SendRawRequest(LPort, LReq);
    Check(Pos('HTTP/1.1 413', LResp) > 0,
      ALabel + ': fixed-length oversize body returns explicit 413');
    Check(not LHandlerCalled,
      ALabel + ': handler not called for fixed-length oversize body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

procedure RunChunkedRequestOversizeTrailerUsesMaxHeaderSize(
  const AUseEpoll: Boolean; const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
  LHandlerCalled: Boolean;
  LOpts: THttpServerOptions;
  LTrailerValue: string;
  LPart1: string;
  LPart2: string;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'ok';
    LHandlerCalled := True;
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 2);
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 256;
  if AUseEpoll then
    LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    SetLength(LTrailerValue, 300);
    FillChar(LTrailerValue[1], 300, Ord('x'));
    LPart1 := 'POST / HTTP/1.1'#13#10 +
              'Host: localhost'#13#10 +
              'Transfer-Encoding: chunked'#13#10 +
              'Trailer: X-Big'#13#10 +
              'Connection: close'#13#10#13#10 +
              '5'#13#10'hello'#13#10;
    LPart2 := '0'#13#10 +
              'X-Big: ' + LTrailerValue + #13#10#13#10;
    LResp := '';
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LPart1[1], SizeUInt(Length(LPart1)));
      platform_thread_sleep_ns(100000000);
      LConn.Write(LPart2[1], SizeUInt(Length(LPart2)));
      LConn.Shutdown;
      repeat
        try
          LN := LConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    finally
      LConn.Close;
    end;
    Check(Pos('HTTP/1.1 431', LResp) > 0,
      ALabel + ': oversize trailer returns explicit 431');
    Check(not LHandlerCalled, ALabel + ': handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{ Test 18: Chunked response — handler writes without Content-Length }
{ Test 18a: 204 response stays bodyless on the wire }
{ Test 18b: 304 response stays bodyless on the wire }
procedure RunInformationalResponseAllowsFinalResponse(const AUseEpoll: Boolean;
  const ALabel: string);
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBody: string;
  LInfoPos: SizeInt;
  LFinalPos: SizeInt;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/early', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('Link', '</style.css>; rel=preload');
    AW.WriteHeader(HTTP_STATUS_EARLY_HINTS);
    AW.WriteHeader(HTTP_STATUS_OK);
    LBody := 'ok';
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  if AUseEpoll then
  begin
    {$IFDEF NEXTPAS_LINUX}
    LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
    {$ELSE}
    Fail(ALabel + ': epoll backend is only available on Linux');
    Exit;
    {$ENDIF}
  end
  else
    LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET /early HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10#13#10);
    LInfoPos := Pos('HTTP/1.1 103 Early Hints'#13#10, LResp);
    LFinalPos := Pos('HTTP/1.1 200 OK'#13#10, LResp);
    Check(LInfoPos = 1, ALabel + ': 103 informational response first');
    Check(LFinalPos > LInfoPos, ALabel + ': final 200 follows 103');
    Check(Pos('transfer-encoding: chunked', LResp) > LFinalPos,
      ALabel + ': final response uses chunked body framing');
    Check(Pos('ok', LResp) > LFinalPos,
      ALabel + ': final response body present');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{ Test 18c: HEAD response stays bodyless on the wire even if handler writes }
{ Test 18d: HEAD response preserves explicit content-length but stays bodyless }
{ Test 19: Chunked response preserves keep-alive }
{ Test 20: Hijack transfers connection ownership away from server loop }
{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{ Q1-4: lock write/backpressure semantics in H1 source (CONTRACT §4.4). }
{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{ Main }

begin
  T := TTestSuite.Create('nextpas.core.http.server.expect');
  T.Test('Expect: 100-continue sends interim response with epoll backend',
    @TestExpectContinueSendsInterimResponseEpollBackend);
  T.Test('Expect: duplicate 100-continue members still send interim response with epoll backend',
    @TestExpectContinueDuplicateMembersStillSendInterimResponseEpollBackend);
  T.Test('Expect: chunked body sends interim response with epoll backend',
    @TestExpectContinueChunkedBodyReadableEpollBackend);
  T.Test('Expect: chunked MaxBodySize rejects after interim response with epoll backend',
    @TestExpectContinueChunkedMaxBodySizeRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked invalid chunk-size rejects after interim response with epoll backend',
    @TestExpectContinueChunkedInvalidChunkSizeRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked malformed chunk extension rejects after interim response with epoll backend',
    @TestExpectContinueChunkedMalformedChunkExtensionRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked missing chunk-data CRLF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedMissingChunkDataCrLfRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked malformed trailer field rejects after interim response with epoll backend',
    @TestExpectContinueChunkedMalformedTrailerFieldRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer field-name EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerFieldNameAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer separator EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerSeparatorAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer empty-value CR EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerEmptyValueCrAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer empty-value EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerEmptyValueAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer empty-value section CR EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerEmptyValueSectionCrAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer whitespace CR EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerWhitespaceCrAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer whitespace EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerWhitespaceAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer whitespace section EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerWhitespaceSectionAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer whitespace section CR EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerWhitespaceSectionCrAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer field line EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerFieldLineAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer field CR EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerFieldCrAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer section CR EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerSectionCrAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked truncated trailer section EOF rejects after interim response with epoll backend',
    @TestExpectContinueChunkedTruncatedTrailerSectionAtEofRejectsAfterInterimEpollBackend);
  T.Test('Expect: chunked oversize trailer rejects after interim response with epoll backend',
    @TestExpectContinueChunkedOversizeTrailerRejectsAfterInterimEpollBackend);
  T.Test('Expect: fixed-length body stall closes safely after interim response with epoll backend',
    @TestExpectContinueFixedLengthBodyStallIdleTimeoutClosesSafelyEpollBackend);
  T.Test('Expect: fixed-length zero body progress idle-timeout closes after interim response with epoll backend',
    @TestExpectContinueZeroProgressFixedLengthBodyIdleTimeoutClosesSafelyEpollBackend);
  T.Test('Expect: chunked body stall closes safely after interim response with epoll backend',
    @TestExpectContinueChunkedBodyStallIdleTimeoutClosesSafelyEpollBackend);
  T.Test('Expect: chunked zero body progress idle-timeout closes after interim response with epoll backend',
    @TestExpectContinueZeroProgressChunkedBodyIdleTimeoutClosesSafelyEpollBackend);
  T.Test('Expect: zero content-length does not emit interim response with epoll backend',
    @TestExpectContinueZeroContentLengthDoesNotEmitInterimEpollBackend);
  T.Test('Expect: no declared body does not emit interim response with epoll backend',
    @TestExpectContinueWithoutDeclaredBodyDoesNotEmitInterimEpollBackend);
  T.Test('HEAD Expect: no declared body does not emit interim response with epoll backend',
    @TestHeadExpectWithoutDeclaredBodyDoesNotEmitInterimEpollBackend);
  T.Test('Expect: unsupported transfer-coding rejects before interim response with epoll backend',
    @TestExpectContinueUnsupportedTransferCodingRejectsEarlyEpollBackend);
  T.Test('Expect: chunked-not-final transfer-coding rejects before interim response with epoll backend',
    @TestExpectContinueChunkedMustBeFinalTransferCodingRejectsEarlyEpollBackend);
  T.Test('Expect: declared oversize content-length rejects early with epoll backend',
    @TestExpectContinueDeclaredOversizeRejectsEarlyEpollBackend);
  T.Test('Unsupported Expect rejects early with epoll backend',
    @TestUnsupportedExpectRejectsEarlyEpollBackend);
  T.Test('Repeated Expect headers with unsupported member reject early with epoll backend',
    @TestRepeatedExpectHeaderUnsupportedMemberRejectsEarlyEpollBackend);
  T.Test('H1 poll-driven session queues follow-up 417 behind active drain',
    @TestH1PollDrivenSessionQueuesFollowUpExpectationFailedBehindActiveDrain);
  T.Test('H1 poll-driven standalone unsupported Expect drains via writable events',
    @TestH1PollDrivenStandaloneUnsupportedExpectDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone unsupported Expect partial-timeout preserves status',
    @TestH1PollDrivenStandaloneUnsupportedExpectPartialTimeoutPreservesStatus);
  T.Test('Direct error response arms write timeout on unsupported Expect request',
    @TestDirectErrorResponseArmsWriteTimeoutOnUnsupportedExpectRequest);
  T.Test('Direct error response partial-timeout on unsupported Expect request preserves status',
    @TestDirectErrorResponsePartialWriteTimeoutOnUnsupportedExpectRequest);
  T.Test('Expect: 100-continue sends interim response',
    @TestExpectContinueSendsInterimResponse);
  T.Test('Expect: duplicate 100-continue members still send interim response',
    @TestExpectContinueDuplicateMembersStillSendInterimResponse);
  T.Test('Expect: chunked body sends interim response',
    @TestExpectContinueChunkedBodyReadable);
  T.Test('Expect: chunked MaxBodySize rejects after interim response',
    @TestExpectContinueChunkedMaxBodySizeRejectsAfterInterim);
  T.Test('Expect: chunked invalid chunk-size rejects after interim response',
    @TestExpectContinueChunkedInvalidChunkSizeRejectsAfterInterim);
  T.Test('Expect: chunked malformed chunk extension rejects after interim response',
    @TestExpectContinueChunkedMalformedChunkExtensionRejectsAfterInterim);
  T.Test('Expect: chunked missing chunk-data CRLF rejects after interim response',
    @TestExpectContinueChunkedMissingChunkDataCrLfRejectsAfterInterim);
  T.Test('Expect: chunked malformed trailer field rejects after interim response',
    @TestExpectContinueChunkedMalformedTrailerFieldRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer field-name EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerFieldNameAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer separator EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerSeparatorAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer empty-value CR EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerEmptyValueCrAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer empty-value EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerEmptyValueAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer empty-value section CR EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerEmptyValueSectionCrAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer whitespace CR EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerWhitespaceCrAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer whitespace EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerWhitespaceAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer whitespace section EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerWhitespaceSectionAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer whitespace section CR EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerWhitespaceSectionCrAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer field line EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerFieldLineAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer field CR EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerFieldCrAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer section CR EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerSectionCrAtEofRejectsAfterInterim);
  T.Test('Expect: chunked truncated trailer section EOF rejects after interim response',
    @TestExpectContinueChunkedTruncatedTrailerSectionAtEofRejectsAfterInterim);
  T.Test('Expect: chunked oversize trailer rejects after interim response',
    @TestExpectContinueChunkedOversizeTrailerRejectsAfterInterim);
  T.Test('Expect: fixed-length body stall closes safely after interim response',
    @TestExpectContinueFixedLengthBodyStallIdleTimeoutClosesSafely);
  T.Test('Expect: fixed-length zero body progress idle-timeout closes after interim response',
    @TestExpectContinueZeroProgressFixedLengthBodyIdleTimeoutClosesSafely);
  T.Test('Expect: chunked body stall closes safely after interim response',
    @TestExpectContinueChunkedBodyStallIdleTimeoutClosesSafely);
  T.Test('Expect: chunked zero body progress idle-timeout closes after interim response',
    @TestExpectContinueZeroProgressChunkedBodyIdleTimeoutClosesSafely);
  T.Test('Expect: zero content-length does not emit interim response',
    @TestExpectContinueZeroContentLengthDoesNotEmitInterim);
  T.Test('Expect: no declared body does not emit interim response',
    @TestExpectContinueWithoutDeclaredBodyDoesNotEmitInterim);
  T.Test('HEAD Expect: no declared body does not emit interim response',
    @TestHeadExpectWithoutDeclaredBodyDoesNotEmitInterim);
  T.Test('Expect: unsupported transfer-coding rejects before interim response',
    @TestExpectContinueUnsupportedTransferCodingRejectsEarly);
  T.Test('Expect: non-chunked transfer-coding rejects before interim response',
    @TestExpectContinueNonChunkedTransferCodingRejectsEarly);
  T.Test('Expect: chunked-not-final transfer-coding rejects before interim response',
    @TestExpectContinueChunkedMustBeFinalTransferCodingRejectsEarly);
  T.Test('Expect: declared oversize content-length rejects early',
    @TestExpectContinueDeclaredOversizeRejectsEarly);
  T.Test('Unsupported Expect rejects early',
    @TestUnsupportedExpectRejectsEarly);
  T.Test('Repeated Expect headers with unsupported member reject early',
    @TestRepeatedExpectHeaderUnsupportedMemberRejectsEarly);
  if not T.Run then Halt(1);
end.
