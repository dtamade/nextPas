program test_http_server;

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

procedure TestServerOptionsBuilder;
var
  LOpts: THttpServerOptions;
begin
  LOpts := THttpServerOptions.Default;
  CheckEqual(30000, LOpts.IdleTimeout, 'default idle timeout');
  CheckEqual(8192, LOpts.MaxHeaderSize, 'default max header size');
  CheckEqual(4194304, LOpts.MaxBodySize, 'default max body size');
  CheckEqual(0, LOpts.ShutdownTimeout, 'default shutdown timeout');

  LOpts := LOpts.WithReadTimeout(5000);
  CheckEqual(5000, LOpts.ReadTimeout, 'WithReadTimeout');

  LOpts := LOpts.WithWriteTimeout(10000);
  CheckEqual(10000, LOpts.WriteTimeout, 'WithWriteTimeout');

  LOpts := LOpts.WithIdleTimeout(60000);
  CheckEqual(60000, LOpts.IdleTimeout, 'WithIdleTimeout');

  LOpts := LOpts.WithMaxHeaderSize(16384);
  CheckEqual(16384, LOpts.MaxHeaderSize, 'WithMaxHeaderSize');

  LOpts := LOpts.WithMaxBodySize(8388608);
  CheckEqual(8388608, LOpts.MaxBodySize, 'WithMaxBodySize');

  LOpts := LOpts.WithShutdownTimeout(5000);
  CheckEqual(5000, LOpts.ShutdownTimeout, 'WithShutdownTimeout');

  { S1-1: poll-owned (streaming/SSE) worker handoff — default False keeps
    short-request perf; opt-in routes poll-owned requests to the worker pool }
  Check(not THttpServerOptions.Default.PreferPollWorkerHandoff,
    'default PreferPollWorkerHandoff is False');

  LOpts := LOpts.WithPreferPollWorkerHandoff;
  Check(LOpts.PreferPollWorkerHandoff, 'WithPreferPollWorkerHandoff');

  LOpts := LOpts.WithPreferPollWorkerHandoff(False);
  Check(not LOpts.PreferPollWorkerHandoff, 'WithPreferPollWorkerHandoff(False)');

  { Builder preserves other fields }
  CheckEqual(5000, LOpts.ReadTimeout, 'builder preserves ReadTimeout');
  CheckEqual(10000, LOpts.WriteTimeout, 'builder preserves WriteTimeout');

  { R11: read-abort sink defaults to nil and survives the builder }
  Check(THttpServerOptions.Default.ReadAbortSink = nil,
    'default ReadAbortSink is nil');
end;

procedure TestServerOptionsDefaultAndProductionTimeouts;
var
  LDefault, LProd: THttpServerOptions;
begin
  LDefault := THttpServerOptions.Default;
  CheckEqual(30000, LDefault.ReadTimeout,
    'Default ReadTimeout is 30s (PD-1B)');
  CheckEqual(30000, LDefault.WriteTimeout,
    'Default WriteTimeout is 30s (PD-1B)');
  CheckEqual(30000, LDefault.IdleTimeout, 'Default IdleTimeout');

  LProd := THttpServerOptions.Production;
  CheckEqual(30000, LProd.ReadTimeout, 'Production ReadTimeout is 30s');
  CheckEqual(30000, LProd.WriteTimeout, 'Production WriteTimeout is 30s');
  CheckEqual(30000, LProd.IdleTimeout, 'Production keeps IdleTimeout');
  CheckEqual(8192, LProd.MaxHeaderSize, 'Production keeps MaxHeaderSize');
  CheckEqual(4194304, LProd.MaxBodySize, 'Production keeps MaxBodySize');
  { Production must not mutate Default semantics for subsequent Default calls }
  LDefault := THttpServerOptions.Default;
  CheckEqual(30000, LDefault.ReadTimeout, 'Default still 30000 after Production');
  CheckEqual(30000, LDefault.WriteTimeout, 'Default Write still 30000 after Production');
end;

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

  { R11 mock: reads stall once input is exhausted (WouldBlock, peer alive),
    writes are accepted up to a byte budget and captured in Output. }
  TStall408RuntimeTcpStream = class(TInterfacedObject, IReader, IWriter,
    IStream, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime)
  private
    FInput: string;
    FInputPos: SizeInt;
    FOutput: string;
    FWriteBudget: SizeUInt;
    FWrittenTotal: SizeUInt;
  public
    constructor Create(const AInput: string; const AWriteBudget: SizeUInt);
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
    property WrittenTotal: SizeUInt read FWrittenTotal;
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

constructor TStall408RuntimeTcpStream.Create(const AInput: string;
  const AWriteBudget: SizeUInt);
begin
  inherited Create;
  FInput := AInput;
  FInputPos := 1;
  FOutput := '';
  FWriteBudget := AWriteBudget;
  FWrittenTotal := 0;
end;

function TStall408RuntimeTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
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

function TStall408RuntimeTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOldLen: SizeUInt;
begin
  { Sync write path: record like a socket would accept. }
  LOldLen := SizeUInt(Length(FOutput));
  SetLength(FOutput, LOldLen + ACount);
  if ACount > 0 then
    Move(ABuf, FOutput[LOldLen + 1], ACount);
  Inc(FWrittenTotal, ACount);
  Result := ACount;
end;

function TStall408RuntimeTcpStream.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): Int64;
begin
  Result := -1;
end;

procedure TStall408RuntimeTcpStream.Close;
begin
end;

function TStall408RuntimeTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TStall408RuntimeTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TStall408RuntimeTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TStall408RuntimeTcpStream.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(8080);
end;

function TStall408RuntimeTcpStream.RemoteAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(65000);
end;

procedure TStall408RuntimeTcpStream.Shutdown;
begin
end;

procedure TStall408RuntimeTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TStall408RuntimeTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TStall408RuntimeTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
end;

procedure TStall408RuntimeTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
end;

procedure TStall408RuntimeTcpStream.SetCancelToken(
  const AToken: INetCancelToken);
begin
end;

function TStall408RuntimeTcpStream.NativeSocketHandle: PtrUInt;
begin
  Result := 46;
end;

procedure TStall408RuntimeTcpStream.SetBlocking(const ABlocking: Boolean);
begin
end;

function TStall408RuntimeTcpStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
begin
  ARead := Read(ABuf, ACount);
  if ARead = 0 then
    Exit(tsiorWouldBlock);
  Result := tsiorOk;
end;

function TStall408RuntimeTcpStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LRemaining: SizeUInt;
  LOldLen: SizeUInt;
begin
  if FWrittenTotal >= FWriteBudget then
  begin
    AWritten := 0;
    Exit(tsiorWouldBlock);
  end;
  LRemaining := FWriteBudget - FWrittenTotal;
  AWritten := ACount;
  if AWritten > LRemaining then
    AWritten := LRemaining;
  if AWritten > 0 then
  begin
    LOldLen := SizeUInt(Length(FOutput));
    SetLength(FOutput, LOldLen + AWritten);
    Move(ABuf, FOutput[LOldLen + 1], AWritten);
    Inc(FWrittenTotal, AWritten);
  end;
  Result := tsiorOk;
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

type
  { R11 test double: records read-abort notifications. Scenarios drive one
    aborting connection at a time and read counters only after StopServer
    (thread join), so plain fields suffice. }
  TRecordingReadAbortSink = class(TInterfacedObject, IHttpServerReadAbortSink)
  private
    FCount: Int32;
    FLastAddr: string;
  public
    procedure OnReadAbort(const ARemoteAddr: string);
    property Count: Int32 read FCount;
    property LastAddr: string read FLastAddr;
  end;

procedure TRecordingReadAbortSink.OnReadAbort(const ARemoteAddr: string);
begin
  Inc(FCount);
  FLastAddr := ARemoteAddr;
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

{ True when AText contains an RFC 7231 §7.1.1.1 Date header line:
  "date: Sun, 06 Nov 1994 08:49:37 GMT". Accepts any day/month name,
  day-of-month (1-2 digits), 4-digit year and HH:MM:SS clock. }
function MatchesHttpDateHeader(const AText: string): Boolean;
const
  DAYS: array[1..7] of string = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  MONTHS: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  LPos, LI, LJ: Integer;
  LSeg: string;
  LDD, LYYYY, LHH, LMM, LSS: string;
begin
  Result := False;
  LPos := Pos('date:', AText);
  if LPos <= 0 then
    Exit;
  { Isolate the header value (up to CRLF). }
  LJ := Pos(#13#10, Copy(AText, LPos + 5, MaxInt));
  if LJ <= 0 then
    Exit;
  LSeg := Trim(Copy(AText, LPos + 5, LJ - 1));
  { Expect "Sun, 06 Nov 1994 08:49:37 GMT" }
  LPos := Pos(',', LSeg);
  if LPos <> 4 then
    Exit;
  LI := 1;
  while LI <= 7 do
  begin
    if Copy(LSeg, 1, 3) = DAYS[LI] then
      Break;
    Inc(LI);
  end;
  if LI > 7 then
    Exit;
  { ", DD Mon YYYY HH:MM:SS GMT" }
  LDD := Copy(LSeg, 6, 2);
  if (Length(LDD) < 1) or (Length(LDD) > 2) then
    Exit;
  if not ((LDD[1] in ['0'..'9']) and ((Length(LDD) = 1) or (LDD[2] in ['0'..'9']))) then
    Exit;
  LI := 1;
  while LI <= 12 do
  begin
    if Copy(LSeg, 9, 3) = MONTHS[LI] then
      Break;
    Inc(LI);
  end;
  if LI > 12 then
    Exit;
  LYYYY := Copy(LSeg, 13, 4);
  if (Length(LYYYY) <> 4) or (LYYYY[1] < '1') or (LYYYY[1] > '9') then
    Exit;
  if (LSEG[17] <> ' ') or (LSEG[20] <> ':') or (LSEG[23] <> ':') then
    Exit;
  LHH := Copy(LSeg, 18, 2);
  LMM := Copy(LSeg, 21, 2);
  LSS := Copy(LSeg, 24, 2);
  if (Length(LHH) <> 2) or (Length(LMM) <> 2) or (Length(LSS) <> 2) then
    Exit;
  if not ((LHH[1] in ['0'..'2']) and (LHH[2] in ['0'..'9']) and
          (LMM[1] in ['0'..'5']) and (LMM[2] in ['0'..'9']) and
          (LSS[1] in ['0'..'5']) and (LSS[2] in ['0'..'9'])) then
    Exit;
  if Copy(LSeg, 27, 3) <> 'GMT' then
    Exit;
  Result := True;
end;

{ Test 1: Server responds 200 to simple GET }
procedure TestSimpleGet200;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /ping HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200 in response');
    Check(Pos('pong', LResp) > 0, 'body pong in response');
    { RFC 7231 §7.1.1.2: responses SHOULD carry a Date header. }
    Check(MatchesHttpDateHeader(LResp), 'response carries RFC 7231 Date header');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Q1-1: live SSE path — read until event body appears (keep-alive stream). }
procedure TestLiveSSEEventStream;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LReq: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/events',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LWriter: ISSEEventWriter;
    begin
      LWriter := StartSSE(AW);
      LWriter.WriteEventSimple('message', 'hello-sse', '1');
      LWriter.WriteComment('done');
      LWriter.Close;
    end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LReq := 'GET /events HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10;
    LResp := '';
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      repeat
        try
          LN := LConn.Read(LBuf[0], SizeOf(LBuf));
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
        end;
      until (LN = 0) or (Pos('data: hello-sse', LResp) > 0);
    finally
      LConn.Close;
    end;
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'live SSE status 200');
    Check(Pos('text/event-stream', LResp) > 0, 'live SSE content-type');
    Check(Pos('data: hello-sse', LResp) > 0, 'live SSE event data');
    Check(Pos('id: 1', LResp) > 0, 'live SSE event id');
    { Comment/framing covered by mock suite; chunked keep-alive may interleave
      length prefixes so full ': done' substring is not required here. }
  finally
    StopServer(LServer, LHandle);
  end;
end;

var
  { Shared between the handler (server worker thread) and the client (test
    thread): proves Flush pushed frame-1 to the peer before the handler
    returned. }
  GFlushFrame1Seen: Int32 = 0;
  GFlushHandlerTimedOut: Int32 = 0;

{ Deterministic first-frame timing proof: the handler writes frame-1, then
  spins until the client reports it has read frame-1; frame-2 is only written
  after that handshake. Without a handler-level Flush push, frame-1 only
  reaches the client after the handler returns, so the 5s watchdog trips and
  the test fails. }
procedure TestLiveSSEFlushPushesFrameBeforeHandlerReturns;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LResp: string;
  LReq: string;
  LSpins: Int32;
begin
  InterlockedExchange(GFlushFrame1Seen, 0);
  InterlockedExchange(GFlushHandlerTimedOut, 0);

  LRouter := THttpRouter.Create;
  LRouter.Get('/sse-flush',
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LWriter: ISSEEventWriter;
    begin
      LWriter := StartSSE(AW);
      LWriter.WriteEventSimple('message', 'flush-frame-1', '1');
      { Wait for the client's frame-1 report. If Flush does not push the
        buffered bytes before the handler returns, frame-1 arrives only after
        this handler returns and the watchdog trips. }
      LSpins := 0;
      while (InterlockedExchangeAdd(GFlushFrame1Seen, 0) = 0) and (LSpins < 5000) do
      begin
        platform_thread_sleep_ns(1000000); { 1ms }
        Inc(LSpins);
      end;
      if LSpins >= 5000 then
        InterlockedIncrement(GFlushHandlerTimedOut);
      LWriter.WriteEventSimple('message', 'flush-frame-2', '2');
      LWriter.Close;
    end);

  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LReq := 'GET /sse-flush HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10;
    LResp := '';
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      repeat
        try
          LN := LConn.Read(LBuf[0], SizeOf(LBuf));
        except
          LN := 0;
        end;
        if LN > 0 then
        begin
          SetLength(LResp, Length(LResp) + Int32(LN));
          Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
          if Pos('data: flush-frame-1', LResp) > 0 then
            InterlockedExchange(GFlushFrame1Seen, 1);
        end;
      until (LN = 0) or (Pos('data: flush-frame-2', LResp) > 0);
    finally
      LConn.Close;
    end;

    Check(InterlockedExchangeAdd(GFlushFrame1Seen, 0) = 1,
      'client saw frame-1 while the handler was still executing (Flush pushed it)');
    Check(InterlockedExchangeAdd(GFlushHandlerTimedOut, 0) = 0,
      'handler did not hit the 5s watchdog (Flush pushes before handler returns)');
    Check(Pos('data: flush-frame-2', LResp) > 0,
      'client received frame-2 after the frame-1 handshake');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 2: Server responds with custom body }
procedure TestCustomBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/hello', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'Hello, World!';
    AW.GetHeaders.SetHeader('content-type', 'text/plain');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /hello HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'status 200');
    Check(Pos('Hello, World!', LResp) > 0, 'custom body present');
    Check(Pos('content-type: text/plain', LResp) > 0, 'content-type header');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestEmptyHandlerCommitsDefaultResponse;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/empty', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET /empty HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200 OK'#13#10, LResp) = 1,
      'empty handler commits default 200 response');
    Check(Pos('transfer-encoding: chunked'#13#10, LResp) > 0,
      'empty handler default response is framed');
    Check(Pos('0'#13#10#13#10, LResp) > 0,
      'empty handler default response finalizes empty body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestSimpleGet200EpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LOpts: THttpServerOptions;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET /ping HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'epoll status 200 in response');
    Check(Pos('pong', LResp) > 0, 'epoll body pong in response');
  finally
    StopServer(LServer, LHandle);
  end;
end;
{$ENDIF}

{ Test 3: Server responds 404 for unmatched route }
procedure TestNotFound404;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/exists', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET /nope HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 404', LResp) > 0, 'status 404 for unmatched route');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 4: Handler exception results in 500 }
type
  TCrashHandler = class(TInterfacedObject, IHttpHandler)
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

procedure TCrashHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  raise Exception.Create('intentional crash');
end;

procedure TestHandlerException500;
var
  LHandler: IHttpHandler;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LHandler := TCrashHandler.Create;
  LHandle := StartServer(LHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 500', LResp) > 0, 'status 500 on handler exception');
  finally
    StopServer(LServer, LHandle);
  end;
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

procedure TestCommittedResponseExceptionDoesNotAppend500;
begin
  RunCommittedResponseExceptionDoesNotAppend500(False,
    'threaded committed response exception');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestCommittedResponseExceptionDoesNotAppend500EpollBackend;
begin
  RunCommittedResponseExceptionDoesNotAppend500(True,
    'epoll committed response exception');
end;
{$ENDIF}

procedure TestSessionStopsAfterZeroProgressWriteFailure;
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactory;
  LSession: ITcpServerSession;
  LStreamObj: TZeroProgressTcpStream;
  LStream: ITcpStream;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
  LSeenFirstPath: string;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /two HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10;
begin
  LHttpOpts := THttpServerOptions.Default;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactory, LFactory),
    'h1 transport exposes session factory');

  LStreamObj := TZeroProgressTcpStream.Create(REQ);
  LStream := LStreamObj as ITcpStream;
  LHandlerCalls := 0;
  LSeenFirstPath := '';
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBody: string;
    begin
      Inc(LHandlerCalls);
      if LHandlerCalls = 1 then
        LSeenFirstPath := AReq.Url.Path;
      LBody := 'ok';
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], 2);
    end));

  LOwnership := LSession.Run;

  Check(LOwnership = TCP_SERVER_CONN_OWNERSHIP_SERVER,
    'server keeps ownership on write failure');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'session stops after first zero-progress response write failure');
  CheckEqual('/one', LSeenFirstPath, 'first pipelined request handled before failure');
  CheckEqual(Int64(1), Int64(LStreamObj.ReadCalls),
    'second pipelined request remains unprocessed after write failure');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteCalls),
    'single response write attempt reached inner stream before failure');
end;

procedure TestH1TransportExposesContextSessionFactory;
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactoryWithContext;
  LSession: ITcpServerSession;
  LPollSession: ITcpServerPollDrivenSession;
  LStreamObj: TZeroProgressTcpStream;
  LStream: ITcpStream;
  LContext: ITcpServerSessionContext;
  LHandoff: ITcpServerWorkerHandoff;
begin
  LHttpOpts := THttpServerOptions.Default;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    'h1 transport exposes context-aware session factory');

  LStreamObj := TZeroProgressTcpStream.Create('');
  LStream := LStreamObj as ITcpStream;
  LHandoff := TMockWorkerHandoff.Create;
  LContext := TMockSessionContext.Create(LHandoff);
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end), LContext);
  Check(LSession <> nil, 'context-aware h1 session factory returns session');
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    'context-aware h1 session now exposes poll-driven session seam');
end;

procedure TestH1TransportRejectsNilConnOrHandler;
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactory;
  LContextFactory: IHttpServerSessionFactoryWithContext;
  LStreamObj: TZeroProgressTcpStream;
  LStream: ITcpStream;
  LHandler: IHttpHandler;
  LContext: ITcpServerSessionContext;
  LHandoff: ITcpServerWorkerHandoff;
begin
  LHttpOpts := THttpServerOptions.Default;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);
  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactory, LFactory),
    'h1 transport exposes session factory');
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LContextFactory),
    'h1 transport exposes context-aware session factory');

  LStreamObj := TZeroProgressTcpStream.Create('');
  LStream := LStreamObj as ITcpStream;
  LHandler := HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
  LHandoff := TMockWorkerHandoff.Create;
  LContext := TMockSessionContext.Create(LHandoff);

  CheckRaisesHekArgument('ServeConn nil connection', procedure
    begin
      LTransport.ServeConn(nil, LHandler);
    end);
  CheckRaisesHekArgument('ServeConn nil handler', procedure
    begin
      LTransport.ServeConn(LStream, nil);
    end);
  CheckRaisesHekArgument('NewSession nil connection', procedure
    begin
      LFactory.NewSession(nil, LHandler);
    end);
  CheckRaisesHekArgument('NewSession nil handler', procedure
    begin
      LFactory.NewSession(LStream, nil);
    end);
  CheckRaisesHekArgument('context NewSession nil connection', procedure
    begin
      LContextFactory.NewSession(nil, LHandler, LContext);
    end);
  CheckRaisesHekArgument('context NewSession nil handler', procedure
    begin
      LContextFactory.NewSession(LStream, nil, LContext);
    end);
  Check(LContextFactory.NewSession(LStream, LHandler, nil) <> nil,
    'context NewSession accepts nil context');
end;

procedure TestH1PollDrivenSessionHandsOffPerCompletedRequest;
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactoryWithContext;
  LSession: ITcpServerSession;
  LPollSession: ITcpServerPollDrivenSession;
  LStreamObj: TInlineRuntimeTcpStream;
  LStream: ITcpStream;
  LHandoffObj: TInlineWorkerHandoff;
  LHandoff: ITcpServerWorkerHandoff;
  LContext: ITcpServerSessionContext;
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
  LFirstPath: string;
  LSecondPath: string;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /two HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  LHttpOpts := THttpServerOptions.Default;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    'h1 transport exposes context-aware session factory for poll-driven request handoff test');

  LStreamObj := TInlineRuntimeTcpStream.Create(REQ);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LFirstPath := '';
  LSecondPath := '';
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
      if LHandlerCalls = 1 then
        LFirstPath := AReq.Url.Path
      else if LHandlerCalls = 2 then
        LSecondPath := AReq.Url.Path;
      AW.WriteHeader(HTTP_STATUS_OK);
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    'context-aware h1 session exposes poll-driven seam for per-request handoff test');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'first readable advance stays active while first request work completes');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    'first request is handed off once');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'first advance only handles first parsed request');
  CheckEqual('/one', LFirstPath, 'first advance handles /one');
  Check(LNextEvents = [], 'first request handoff waits on completion wake');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'completion wake with buffered follow-up stays active');
  CheckEqual(Int64(2), Int64(LHandoffObj.SubmitCount),
    'buffered second request is handed off separately');
  CheckEqual(Int64(2), Int64(LHandlerCalls),
    'completion wake handles second parsed request');
  CheckEqual('/two', LSecondPath, 'completion wake handles /two');
  Check(LNextEvents = [], 'second request handoff again waits on completion wake');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    'second completion ends the poll-driven session');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), 'session remains server-owned after second completion');
  Check(Pos('HTTP/1.1 200 OK', LStreamObj.Output) > 0,
    'responses were written to stream output');
end;

procedure TestH1PollDrivenSessionDrainsResponseViaWritableEvents;
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
const
  REQ =
    'GET /drain HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10#13#10;
  BODY = 'ok';
begin
  LHttpOpts := THttpServerOptions.Default;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    'h1 transport exposes context-aware session factory for poll-driven drain test');

  LStreamObj := TWritableDrainRuntimeTcpStream.Create(REQ, 1, 0);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(BODY[1], SizeUInt(Length(BODY)));
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    'context-aware h1 session exposes poll-driven seam for writable-drain test');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'first readable advance stays active while request work completes');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    'request is handed off once');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'handler runs once for the request');
  CheckEqual(Int64(0), Int64(LStreamObj.SyncWriteCalls),
    'worker path only buffers response, does not sync-write socket');
  CheckEqual(Int64(0), Int64(LStreamObj.TryWriteCalls),
    'reactor drain does not start before completion wake');
  Check(LNextEvents = [], 'request handoff waits on completion wake');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'completion wake transitions into reactor-owned drain');
  CheckEqual(Int64(0), Int64(LStreamObj.SyncWriteCalls),
    'completion wake still avoids sync write path');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    'completion wake attempts nonblocking drain');
  Check(LNextEvents = [peWritable],
    'would-block drain subscribes writable wake');
  CheckEqual('', LStreamObj.Output,
    'would-block drain writes no bytes');

  LResult := LPollSession.Advance([peWritable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    'writable wake completes close-after-response session');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), 'session remains server-owned after writable drain');
  CheckEqual(Int64(2), Int64(LStreamObj.TryWriteCalls),
    'writable wake resumes nonblocking drain');
  Check(Pos('HTTP/1.1 200 OK', LStreamObj.Output) > 0,
    'drained output contains response status line');
  Check(Pos(BODY, LStreamObj.Output) > 0,
    'drained output contains response body');
end;

procedure TestH1PollDrivenSessionTimesOutStalledDrainOnDeadlineWake;
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
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /two HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10#13#10;
  BODY = 'ok';
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := 20;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    'h1 transport exposes context-aware session factory for timed drain test');

  LStreamObj := TTimedDrainRuntimeTcpStream.Create(REQ);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(BODY[1], SizeUInt(Length(BODY)));
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    'context-aware h1 session exposes poll-driven seam for timed drain test');
  Check(Supports(LSession, ITcpServerPollDrivenSessionWithDeadline, LDeadlineSession),
    'timed drain session exposes deadline seam');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'first readable advance stays active while timed request work completes');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    'timed request is handed off once');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'timed handler runs once for first request');
  CheckEqual(Int64(0), Int64(LStreamObj.SyncWriteCalls),
    'timed worker path must not sync-write socket');
  Check(LNextEvents = [], 'timed request handoff waits on completion wake');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'completion wake enters timed reactor-owned drain');
  CheckEqual(Int64(0), Int64(LStreamObj.SyncWriteCalls),
    'completion wake still avoids sync write path');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    'completion wake attempts timed nonblocking drain once');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteDeadlineCalls),
    'timed stalled drain arms write deadline once before zero-progress stall');
  Check(LNextEvents = [peWritable],
    'timed would-block drain subscribes writable wake');
  Check(not LDeadlineSession.WakeDeadline.IsInfinite,
    'timed drain exposes finite wake deadline');

  platform_thread_sleep_ns(50000000);
  Check(LDeadlineSession.WakeDeadline.IsExpired,
    'timed drain deadline eventually expires');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    'deadline wake closes stalled timed drain');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), 'timed stalled drain keeps server ownership on close');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'timed stalled drain does not advance to follow-up request');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    'timed stalled drain does not hand off follow-up request');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    'deadline wake closes without extra write retry');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteDeadlineCalls),
    'deadline wake does not rearm timed drain without write progress');
  Check(LDeadlineSession.WakeDeadline.IsInfinite,
    'deadline wake clears stalled timed drain wake deadline after timeout close');
end;

procedure TestH1PollDrivenSessionClearsWakeDeadlineAfterSuccessfulTimedDrain;
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactoryWithContext;
  LSession: ITcpServerSession;
  LPollSession: ITcpServerPollDrivenSession;
  LDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
  LStreamObj: TWritableDrainRuntimeTcpStream;
  LStream: ITcpStream;
  LHandoffObj: TInlineWorkerHandoff;
  LHandoff: ITcpServerWorkerHandoff;
  LContext: ITcpServerSessionContext;
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10#13#10;
  BODY = 'ok';
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := 20;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    'h1 transport exposes context-aware session factory for timed drain reset test');

  LStreamObj := TWritableDrainRuntimeTcpStream.Create(REQ, 1, 0);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(BODY[1], SizeUInt(Length(BODY)));
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    'context-aware h1 session exposes poll-driven seam for timed drain reset test');
  Check(Supports(LSession, ITcpServerPollDrivenSessionWithDeadline, LDeadlineSession),
    'timed drain reset session exposes deadline seam');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'first readable advance stays active while timed reset request work completes');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    'timed reset request is handed off once');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'timed reset handler runs once');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'completion wake enters timed drain reset path');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    'timed reset completion wake attempts first nonblocking write once');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteDeadlineCalls),
    'timed reset path arms write deadline before stalled drain');
  Check(not LDeadlineSession.WakeDeadline.IsInfinite,
    'timed reset path exposes finite wake deadline while stalled');
  Check(LNextEvents = [peWritable],
    'timed reset path waits for writable after would-block');

  LResult := LPollSession.Advance([peWritable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    'writable wake completes timed reset drain for close-after-response request');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), 'timed reset drain keeps server ownership');
  CheckEqual(Int64(2), Int64(LStreamObj.TryWriteCalls),
    'writable wake retries timed reset drain once');
  Check(LDeadlineSession.WakeDeadline.IsInfinite,
    'successful timed drain clears wake deadline');
  Check(Pos('HTTP/1.1 200 OK', LStreamObj.Output) > 0,
    'timed reset drain writes response status line');
  Check(Pos(BODY, LStreamObj.Output) > 0,
    'timed reset drain writes response body');
end;

procedure TestH1PollDrivenSessionTimesOutIdleReadWaitBeforeFirstRequest;
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
  { PD-1B: Default ReadTimeout is 30s; first-request arm uses FReadMs, not FIdleMs.
    Short both so the 50ms sleep can expire the wake deadline. }
  LHttpOpts.ReadTimeout := 20;
  LHttpOpts.IdleTimeout := 20;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    'h1 transport exposes context-aware session factory for idle read timeout test');

  LStreamObj := TIdleReadRuntimeTcpStream.Create;
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
    'context-aware h1 session exposes poll-driven seam for idle read timeout test');
  Check(Supports(LSession, ITcpServerPollDrivenSessionWithDeadline, LDeadlineSession),
    'idle read timeout session exposes deadline seam');
  CheckEqual(Int64(1), Int64(LStreamObj.ReadDeadlineCalls),
    'idle read timeout arms initial read deadline before first poll event');
  Check(not LDeadlineSession.WakeDeadline.IsInfinite,
    'idle read timeout exposes finite wake deadline before first request bytes arrive');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'idle read timeout stays active while deadline has not expired');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    'idle read timeout path does not call handler before request bytes exist');
  CheckEqual(Int64(0), Int64(LHandoffObj.SubmitCount),
    'idle read timeout path does not hand off worker work before request bytes exist');
  Check(LNextEvents = [peReadable],
    'idle read timeout keeps waiting for readable events');
  CheckEqual(Int64(0), Int64(LStreamObj.TryReadCalls),
    'idle read timeout does not force speculative read without readiness');

  platform_thread_sleep_ns(50000000);
  Check(LDeadlineSession.WakeDeadline.IsExpired,
    'idle read timeout wake deadline eventually expires');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    'expired idle read timeout closes poll-driven session safely');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), 'idle read timeout keeps server ownership on close');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    'idle read timeout still does not call handler on timeout close');
  CheckEqual(Int64(0), Int64(LHandoffObj.SubmitCount),
    'idle read timeout still does not submit worker work on timeout close');
  Check(LDeadlineSession.WakeDeadline.IsInfinite,
    'idle read timeout clears wake deadline after timeout close');
end;

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

procedure TestH1PollDrivenSessionTimesOutPartialFixedLengthBodyReadWait;
const
  REQ =
    'POST /body HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Connection: close'#13#10#13#10 +
    'ab';
begin
  RunPollDrivenMidRequestReadTimeout(
    'poll-driven partial fixed-length body timeout', REQ);
end;

procedure TestH1PollDrivenMidRequestTimeoutWritesBestEffort408;
{ R11: mid-request read-deadline expiry queues a best-effort 408 before the
  close (write side accepts bytes), fires the read-abort sink exactly once,
  and keeps server ownership. The sibling RunPollDrivenMidRequestReadTimeout
  tests lock the fallback path where the write side faults (bare close). }
const
  REQ =
    'POST /body HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 5'#13#10 +
    'Connection: close'#13#10#13#10 +
    'ab';
var
  LHttpOpts: THttpServerOptions;
  LH1Opts: TH1ServerTransportOptions;
  LTransport: IHttpServerTransport;
  LFactory: IHttpServerSessionFactoryWithContext;
  LSession: ITcpServerSession;
  LPollSession: ITcpServerPollDrivenSession;
  LDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
  LStreamObj: TStall408RuntimeTcpStream;
  LStream: ITcpStream;
  LHandoffObj: TInlineWorkerHandoff;
  LHandoff: ITcpServerWorkerHandoff;
  LContext: ITcpServerSessionContext;
  LSinkObj: TRecordingReadAbortSink;
  LSink: IHttpServerReadAbortSink;
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LHandlerCalls: Int32;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.ReadTimeout := 20;
  LHttpOpts.IdleTimeout := 20;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);
  LSinkObj := TRecordingReadAbortSink.Create;
  LSink := LSinkObj;
  LH1Opts.ReadAbortSink := LSink;

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    '408 write path: h1 transport exposes context-aware session factory');

  LStreamObj := TStall408RuntimeTcpStream.Create(REQ, 65536);
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
    '408 write path: h1 session exposes poll-driven seam');
  Check(Supports(LSession, ITcpServerPollDrivenSessionWithDeadline, LDeadlineSession),
    '408 write path: session exposes deadline seam');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    '408 write path: partial request bytes keep the session active');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    '408 write path: partial request bytes do not reach the handler');

  platform_thread_sleep_ns(50000000);
  Check(LDeadlineSession.WakeDeadline.IsExpired,
    '408 write path: request-side wake deadline eventually expires');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    '408 write path: accepted-write drain finishes inline with close');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)), '408 write path: timeout close keeps server ownership');
  CheckEqual(Int64(0), Int64(LHandlerCalls),
    '408 write path: handler still not called');
  CheckEqual(Int64(0), Int64(LHandoffObj.SubmitCount),
    '408 write path: no worker work submitted');
  Check(Pos('HTTP/1.1 408', LStreamObj.Output) > 0,
    '408 write path: response bytes carry the 408 status line');
  Check(Pos('close', LStreamObj.Output) > 0,
    '408 write path: response carries connection close token');
  Check(LStreamObj.WrittenTotal > 0,
    '408 write path: response drained through the nonblocking write path');
  Check(LDeadlineSession.WakeDeadline.IsInfinite,
    '408 write path: wake deadline cleared after close');
  CheckEqual(Int64(1), Int64(LSinkObj.Count),
    '408 write path: read-abort sink fired exactly once');
end;

procedure TestH1PollDrivenSessionPartialTimedDrainStopsBufferedFollowUp;
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
  LFirstPath: string;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /two HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10#13#10;
  BODY = 'ok';
  FIRST_WRITE_BYTES = 32;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := 20;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    'h1 transport exposes context-aware session factory for partial timed drain test');

  LStreamObj := TTimedDrainRuntimeTcpStream.Create(REQ, FIRST_WRITE_BYTES);
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
    'context-aware h1 session exposes poll-driven seam for partial timed drain test');
  Check(Supports(LSession, ITcpServerPollDrivenSessionWithDeadline, LDeadlineSession),
    'partial timed drain session exposes deadline seam');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'first readable advance stays active while partial timed request work completes');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    'partial timed request is handed off once');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'partial timed handler runs once for first request');
  CheckEqual('/one', LFirstPath, 'partial timed test handles only first request path');
  Check(LNextEvents = [], 'partial timed request handoff waits on completion wake');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'completion wake begins partial timed reactor-owned drain');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    'completion wake attempts first partial timed drain write');
  CheckEqual(Int64(2), Int64(LStreamObj.WriteDeadlineCalls),
    'partial timed drain rearms write deadline after partial progress');
  CheckEqual(Int64(FIRST_WRITE_BYTES), Int64(Length(LStreamObj.Output)),
    'partial timed drain preserves first already-written bytes');
  CheckEqual(Int64(1), Int64(CountSubstring(LStreamObj.Output, 'HTTP/1.1 ')),
    'partial timed drain emits only the first response status line');
  Check(LNextEvents = [peWritable],
    'partial timed drain still waits on writable after first partial write');
  Check(not LDeadlineSession.WakeDeadline.IsInfinite,
    'partial timed drain exposes finite wake deadline after partial write');

  LResult := LPollSession.Advance([peWritable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'writable wake before deadline keeps partial timed drain waiting');
  CheckEqual(Int64(2), Int64(LStreamObj.TryWriteCalls),
    'writable wake retries partial timed drain exactly once before timeout');
  CheckEqual(Int64(2), Int64(LStreamObj.WriteDeadlineCalls),
    'would-block retry without new bytes keeps prior timed drain deadline');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'partial timed drain does not hand off buffered follow-up request');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    'partial timed drain keeps buffered follow-up unsubmitted');
  Check(Pos('HTTP/1.1 500', LStreamObj.Output) = 0,
    'partial timed drain does not append synthetic 500 while stalled');

  platform_thread_sleep_ns(50000000);
  Check(LDeadlineSession.WakeDeadline.IsExpired,
    'partial timed drain deadline eventually expires after partial write');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_DONE,
    'deadline wake closes partial timed drain with buffered follow-up');
  CheckEqual(Int64(Ord(TCP_SERVER_CONN_OWNERSHIP_SERVER)),
    Int64(Ord(LOwnership)),
    'partial timed drain keeps server ownership on timeout close');
  CheckEqual(Int64(2), Int64(LStreamObj.TryWriteCalls),
    'deadline wake closes partial timed drain without extra write retry');
  CheckEqual(Int64(2), Int64(LStreamObj.WriteDeadlineCalls),
    'timeout close preserves last rearmed deadline without further reset');
  CheckEqual(Int64(1), Int64(CountSubstring(LStreamObj.Output, 'HTTP/1.1 ')),
    'timeout close still leaves only one response status line on wire');
  Check(LDeadlineSession.WakeDeadline.IsInfinite,
    'timeout close clears partial timed drain wake deadline');
end;

procedure TestH1PollDrivenSessionQueuesBoundedResponsesWhileDraining;
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
  LSecondPath: string;
  LThirdPath: string;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /two HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /three HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10#13#10;
  BODY = 'ok';
begin
  LHttpOpts := THttpServerOptions.Default;
  { PD-1B: CanParseBufferedPollRequestWhileDraining requires WriteTimeout<=0.
    Keep WriteTimeout=0 so pipeline-while-draining queue growth is exercised. }
  LHttpOpts.WriteTimeout := 0;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactoryWithContext, LFactory),
    'h1 transport exposes context-aware session factory for response queue test');

  LStreamObj := TWritableDrainRuntimeTcpStream.Create(REQ, 2, 0);
  LStream := LStreamObj as ITcpStream;
  LHandoffObj := TInlineWorkerHandoff.Create;
  LHandoff := LHandoffObj as ITcpServerWorkerHandoff;
  LContext := TMockSessionContext.Create(LHandoff);
  LHandlerCalls := 0;
  LFirstPath := '';
  LSecondPath := '';
  LThirdPath := '';
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(LHandlerCalls);
      case LHandlerCalls of
        1: LFirstPath := AReq.Url.Path;
        2: LSecondPath := AReq.Url.Path;
        3: LThirdPath := AReq.Url.Path;
      end;
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(BODY[1], SizeUInt(Length(BODY)));
    end), LContext);
  Check(Supports(LSession, ITcpServerPollDrivenSession, LPollSession),
    'context-aware h1 session exposes poll-driven seam for response queue test');

  LResult := LPollSession.Advance([peReadable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'first readable advance stays active while first request work completes');
  CheckEqual(Int64(1), Int64(LHandoffObj.SubmitCount),
    'first request is handed off once');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'first advance handles only first request');
  CheckEqual('/one', LFirstPath, 'first request path captured');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'completion wake may queue one extra response while first drain is pending');
  CheckEqual(Int64(2), Int64(LHandoffObj.SubmitCount),
    'second request is handed off while first response is still pending');
  CheckEqual(Int64(2), Int64(LHandlerCalls),
    'second request is handled before first response drain completes');
  CheckEqual('/two', LSecondPath, 'second request path captured');
  CheckEqual(Int64(0), Int64(LStreamObj.TryWriteCalls),
    'queue growth from buffered input does not require an immediate socket write');

  LResult := LPollSession.Advance([peWritable], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'writable wake drains first response and frees one queue slot');
  CheckEqual(Int64(1), Int64(LStreamObj.TryWriteCalls),
    'first writable wake performs the first socket drain attempt');
  Check(Pos('HTTP/1.1 200 OK', LStreamObj.Output) > 0,
    'first response begins draining to the socket');

  LResult := LPollSession.Advance([], LNextEvents, LOwnership);
  Check(LResult = TCP_SERVER_POLL_WAIT,
    'after one slot frees, buffered third request can continue');
  CheckEqual(Int64(3), Int64(LHandoffObj.SubmitCount),
    'third request is handed off only after a queue slot frees');
  CheckEqual(Int64(3), Int64(LHandlerCalls),
    'third request is eventually handled');
  CheckEqual('/three', LThirdPath, 'third request path captured');
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

procedure TestH1PollDrivenSessionQueuesFollowUpBadRequestBehindActiveDrain;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /bad HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 1'#13#10 +
    'Content-Length: 2'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunPollDrivenQueuedFollowUpErrorPreservesWireOrder(
    'queued follow-up 400', REQ, 'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenSessionQueuesFollowUpPayloadTooLargeBehindActiveDrain;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /too-large HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 3'#13#10 +
    'Connection: close'#13#10#13#10 +
    'abc';
begin
  RunPollDrivenQueuedFollowUpErrorPreservesWireOrder(
    'queued follow-up 413', REQ, 'HTTP/1.1 413 Payload Too Large', 0, 2);
end;

procedure TestH1PollDrivenSessionQueuesFollowUpHeaderTooLargeBehindActiveDrain;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /too-many-headers HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'X-Long: 0123456789012345678901234567890123456789'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunPollDrivenQueuedFollowUpErrorPreservesWireOrder(
    'queued follow-up 431', REQ,
    'HTTP/1.1 431 Request Header Fields Too Large', 64, 0);
end;

procedure TestH1PollDrivenSessionQueuesFollowUpNotImplementedBehindActiveDrain;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'POST /unsupported HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunPollDrivenQueuedFollowUpErrorPreservesWireOrder(
    'queued follow-up 501', REQ, 'HTTP/1.1 501 Not Implemented', 0, 0);
end;

procedure TestH1PollDrivenStandaloneBadRequestDrainsViaWritableEvents;
const
  REQ = 'GARBAGE DATA HERE'#13#10#13#10;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll generic bad request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneOversizeTrailerDrainsViaWritableEvents;
const
  TRAILER_VALUE =
    '012345678901234567890123456789012345678901234567890123456789' +
    '012345678901234567890123456789012345678901234567890123456789';
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Big'#13#10 +
        'Connection: close'#13#10#13#10 +
        '1'#13#10'a'#13#10 +
        '0'#13#10 +
        'X-Big: ' + TRAILER_VALUE + #13#10#13#10;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll oversize trailer rejection', REQ,
    'HTTP/1.1 431 Request Header Fields Too Large', 128, 0);
end;

procedure TestH1PollDrivenStandaloneInvalidTrailerFieldDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Bad'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'Bad Header: value'#13#10#13#10;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll invalid trailer field request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13#10;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerFieldNameAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test';
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer field-name eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerSeparatorAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test:';
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer separator eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerEmptyValueCrAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test:'#13;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer empty-value cr eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerEmptyValueAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test:'#13#10;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer empty-value eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerEmptyValueSectionCrAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test:'#13#10#13;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer empty-value section cr eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerWhitespaceAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: ';
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer whitespace eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerWhitespaceCrAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: '#13;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer whitespace cr eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerWhitespaceSectionAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: '#13#10;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer whitespace section eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerWhitespaceSectionCrAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: '#13#10#13;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer whitespace section cr eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerFieldLineAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value';
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer field line eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerFieldCrAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer field cr eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneTruncatedTrailerCrAtEofDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: chunked'#13#10 +
        'Trailer: X-Test'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10 +
        'X-Test: value'#13#10#13;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll truncated trailer cr eof request', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandaloneUnsupportedTransferCodingDrainsViaWritableEvents;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: gzip, chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10#13#10;
begin
  RunPollDrivenStandaloneDirectErrorDrainsViaWritableEvents(
    'standalone poll unsupported transfer-coding rejection', REQ,
    'HTTP/1.1 501 Not Implemented', 0, 0);
end;

procedure TestH1PollDrivenStandaloneBadRequestPartialTimeoutPreservesStatus;
const
  REQ = 'GARBAGE DATA HERE'#13#10#13#10;
begin
  RunPollDrivenStandaloneTimedDirectErrorPartialTimeoutPreservesStatus(
    'standalone poll generic bad request partial-timeout', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestH1PollDrivenStandalonePayloadTooLargePartialTimeoutPreservesStatus;
const
  REQ = 'POST /too-large HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 3'#13#10 +
        'Connection: close'#13#10#13#10 +
        'abc';
begin
  RunPollDrivenStandaloneTimedDirectErrorPartialTimeoutPreservesStatus(
    'standalone poll payload-too-large partial-timeout', REQ,
    'HTTP/1.1 413 Payload Too Large', 0, 2);
end;

procedure TestH1PollDrivenStandaloneHeaderTooLargePartialTimeoutPreservesStatus;
const
  REQ = 'GET /too-many-headers HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'X-Long: 0123456789012345678901234567890123456789'#13#10 +
        'Connection: close'#13#10#13#10;
begin
  RunPollDrivenStandaloneTimedDirectErrorPartialTimeoutPreservesStatus(
    'standalone poll header-too-large partial-timeout', REQ,
    'HTTP/1.1 431 Request Header Fields Too Large', 32, 0);
end;

procedure TestH1PollDrivenStandaloneUnsupportedTransferCodingPartialTimeoutPreservesStatus;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Transfer-Encoding: gzip, chunked'#13#10 +
        'Connection: close'#13#10#13#10 +
        '5'#13#10'hello'#13#10 +
        '0'#13#10#13#10;
begin
  RunPollDrivenStandaloneTimedDirectErrorPartialTimeoutPreservesStatus(
    'standalone poll unsupported transfer-coding partial-timeout', REQ,
    'HTTP/1.1 501 Not Implemented', 0, 0);
end;

procedure TestWriteTimeoutBeforeAnyWireBytesDoesNotAppend500;
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
  LHandlerReturned: Boolean;
const
  REQ =
    'GET /timeout HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := 250;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactory, LFactory),
    'h1 transport exposes session factory for timeout proof');

  LStreamObj := TTimeoutWriteTcpStream.Create(REQ, 0, True);
  LStream := LStreamObj as ITcpStream;
  LHandlerCalls := 0;
  LHandlerReturned := False;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBody: string;
    begin
      Inc(LHandlerCalls);
      LBody := 'ok';
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], 2);
      LHandlerReturned := True;
    end));

  LOwnership := LSession.Run;

  Check(LOwnership = TCP_SERVER_CONN_OWNERSHIP_SERVER,
    'server keeps ownership on timeout before any wire bytes');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'timeout before any wire bytes still handles only first request');
  CheckEqual(Int64(1), Int64(LStreamObj.ReadCalls),
    'timeout before any wire bytes consumes one request read');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteCalls),
    'timeout before any wire bytes performs only the failing response write');
  Check(LHandlerReturned,
    'timeout before any wire bytes happens after the buffered handler returns');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteDeadlineCalls),
    'write timeout config sets a write deadline before response write');
  CheckEqual(Int64(0), Int64(Length(LStreamObj.Output)),
    'timeout before any wire bytes leaves socket without synthetic fallback response');
  Check(Pos('HTTP/1.1 500', LStreamObj.Output) = 0,
    'timeout before any wire bytes does not append synthetic 500');
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

procedure TestDirectErrorResponseArmsWriteTimeoutOnMalformedRequest;
const
  REQ = 'GARBAGE DATA HERE'#13#10#13#10;
begin
  RunDirectErrorResponseArmsWriteTimeoutOnRejectedRequest(
    'malformed request direct 400', REQ, 0, 0);
end;

procedure TestDirectErrorResponseArmsWriteTimeoutOnPayloadTooLargeRequest;
const
  REQ =
    'POST /too-large HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 3'#13#10 +
    'Connection: close'#13#10#13#10 +
    'abc';
begin
  RunDirectErrorResponseArmsWriteTimeoutOnRejectedRequest(
    'payload-too-large direct 413', REQ, 2, 0);
end;

procedure TestDirectErrorResponseArmsWriteTimeoutOnHeaderTooLargeRequest;
const
  REQ =
    'GET /too-many-headers HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'X-Long: 0123456789012345678901234567890123456789'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunDirectErrorResponseArmsWriteTimeoutOnRejectedRequest(
    'header-too-large direct 431', REQ, 0, 32);
end;

procedure TestDirectErrorResponseArmsWriteTimeoutOnUnsupportedTransferCodingRequest;
const
  REQ =
    'POST /unsupported HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunDirectErrorResponseArmsWriteTimeoutOnRejectedRequest(
    'unsupported transfer-coding direct 501', REQ, 0, 0);
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

procedure TestDirectErrorResponsePartialWriteTimeoutOnMalformedRequest;
const
  REQ = 'GARBAGE DATA HERE'#13#10#13#10;
begin
  RunDirectErrorResponsePartialWriteTimeoutOnRejectedRequest(
    'malformed request direct 400 partial-timeout', REQ,
    'HTTP/1.1 400 Bad Request', 0, 0);
end;

procedure TestDirectErrorResponsePartialWriteTimeoutOnPayloadTooLargeRequest;
const
  REQ =
    'POST /too-large HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Content-Length: 3'#13#10 +
    'Connection: close'#13#10#13#10 +
    'abc';
begin
  RunDirectErrorResponsePartialWriteTimeoutOnRejectedRequest(
    'payload-too-large direct 413 partial-timeout', REQ,
    'HTTP/1.1 413 Payload Too Large', 2, 0);
end;

procedure TestDirectErrorResponsePartialWriteTimeoutOnHeaderTooLargeRequest;
const
  REQ =
    'GET /too-many-headers HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'X-Long: 0123456789012345678901234567890123456789'#13#10 +
    'Connection: close'#13#10#13#10;
begin
  RunDirectErrorResponsePartialWriteTimeoutOnRejectedRequest(
    'header-too-large direct 431 partial-timeout', REQ,
    'HTTP/1.1 431 Request Header Fields Too Large', 0, 32);
end;

procedure TestDirectErrorResponsePartialWriteTimeoutOnUnsupportedTransferCodingRequest;
const
  REQ =
    'POST /unsupported HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Transfer-Encoding: gzip, chunked'#13#10 +
    'Connection: close'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10#13#10;
begin
  RunDirectErrorResponsePartialWriteTimeoutOnRejectedRequest(
    'unsupported transfer-coding direct 501 partial-timeout', REQ,
    'HTTP/1.1 501 Not Implemented', 0, 0);
end;

procedure TestWriteTimeoutAfterPartialWireBytesStopsPipelineWithout500;
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
  LSeenFirstPath: string;
  LHandlerReturned: Boolean;
const
  REQ =
    'GET /one HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10 +
    'GET /two HTTP/1.1'#13#10 +
    'Host: localhost'#13#10#13#10;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := 250;
  LH1Opts := DefaultH1ServerTransportOptions(LHttpOpts);

  LTransport := NewH1ServerTransport(LH1Opts);
  Check(Supports(LTransport, IHttpServerSessionFactory, LFactory),
    'h1 transport exposes session factory for partial-timeout proof');

  LStreamObj := TTimeoutWriteTcpStream.Create(REQ, 8, True);
  LStream := LStreamObj as ITcpStream;
  LHandlerCalls := 0;
  LSeenFirstPath := '';
  LHandlerReturned := False;
  LSession := LFactory.NewSession(LStream, HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBody: string;
    begin
      Inc(LHandlerCalls);
      if LHandlerCalls = 1 then
        LSeenFirstPath := AReq.Url.Path;
      LBody := 'ok';
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], 2);
      LHandlerReturned := True;
    end));

  LOwnership := LSession.Run;

  Check(LOwnership = TCP_SERVER_CONN_OWNERSHIP_SERVER,
    'server keeps ownership on partial timeout write failure');
  CheckEqual(Int64(1), Int64(LHandlerCalls),
    'partial timeout stops pipeline after first request');
  CheckEqual('/one', LSeenFirstPath,
    'partial timeout still handled the first request path');
  CheckEqual(Int64(1), Int64(LStreamObj.ReadCalls),
    'partial timeout leaves second pipelined request unread');
  CheckEqual(Int64(2), Int64(LStreamObj.WriteCalls),
    'partial timeout hits one partial write and one timeout write');
  Check(LHandlerReturned,
    'partial timeout on small response happens after the buffered handler returns');
  CheckEqual(Int64(1), Int64(LStreamObj.WriteDeadlineCalls),
    'partial timeout path sets a write deadline');
  CheckEqual(Int64(8), Int64(Length(LStreamObj.Output)),
    'partial timeout preserves only already-written bytes');
  Check(Pos('HTTP/1.1 500', LStreamObj.Output) = 0,
    'partial timeout does not append synthetic 500 after partial response bytes');
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

procedure TestRealSocketWriteTimeoutDoesNotExpireDuringSlowBufferedHandler;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  RunRealSocketWriteTimeoutDoesNotExpireDuringSlowBufferedHandler(
    'threaded', LHttpOpts);
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestRealSocketWriteTimeoutDoesNotExpireDuringSlowBufferedHandlerEpollBackend;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketWriteTimeoutDoesNotExpireDuringSlowBufferedHandler(
    'epoll', LHttpOpts);
end;
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

procedure TestRealSocketWriteTimeoutBackpressureStopsPipeline;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  RunRealSocketWriteTimeoutBackpressureStopsPipeline('threaded', LHttpOpts);
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestRealSocketWriteTimeoutBackpressureStopsPipelineEpollBackend;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketWriteTimeoutBackpressureStopsPipeline('epoll', LHttpOpts);
end;
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

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp400;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp400('threaded', LHttpOpts);
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp400EpollBackend;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp400('epoll', LHttpOpts);
end;

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

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp501;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp501('threaded', LHttpOpts);
end;

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp501EpollBackend;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp501('epoll', LHttpOpts);
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

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp413;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.MaxBodySize := 2;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp413('threaded', LHttpOpts);
end;

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp413EpollBackend;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.MaxBodySize := 2;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp413('epoll', LHttpOpts);
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

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp431;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.MaxHeaderSize := 64;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp431('threaded', LHttpOpts);
end;

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp431EpollBackend;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.MaxHeaderSize := 64;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp431('epoll', LHttpOpts);
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

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp417;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp417('threaded', LHttpOpts);
end;

procedure TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp417EpollBackend;
var
  LHttpOpts: THttpServerOptions;
const
  WRITE_TIMEOUT_MS = 50;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.WriteTimeout := WRITE_TIMEOUT_MS;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp417('epoll', LHttpOpts);
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

procedure TestRealSocketQueuedFollowUp400PreservesWireOrderThreadedBackend;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  RunRealSocketQueuedFollowUp400PreservesWireOrder('threaded', LHttpOpts);
end;

procedure TestRealSocketQueuedFollowUp413PreservesWireOrderThreadedBackend;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.MaxBodySize := 2;
  RunRealSocketQueuedFollowUp413PreservesWireOrder('threaded', LHttpOpts);
end;

procedure TestRealSocketQueuedFollowUp431PreservesWireOrderThreadedBackend;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.MaxHeaderSize := 64;
  RunRealSocketQueuedFollowUp431PreservesWireOrder('threaded', LHttpOpts);
end;

procedure TestRealSocketQueuedFollowUp501PreservesWireOrderThreadedBackend;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  RunRealSocketQueuedFollowUp501PreservesWireOrder('threaded', LHttpOpts);
end;

procedure TestRealSocketQueuedFollowUp417PreservesWireOrderThreadedBackend;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  RunRealSocketQueuedFollowUp417PreservesWireOrder('threaded', LHttpOpts);
end;

procedure TestEpollRealSocketQueuedFollowUp400PreservesWireOrder;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketQueuedFollowUp400PreservesWireOrder('epoll', LHttpOpts);
end;

procedure TestEpollRealSocketQueuedFollowUp413PreservesWireOrder;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHttpOpts.MaxBodySize := 2;
  RunRealSocketQueuedFollowUp413PreservesWireOrder('epoll', LHttpOpts);
end;

procedure TestEpollRealSocketQueuedFollowUp431PreservesWireOrder;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHttpOpts.MaxHeaderSize := 64;
  RunRealSocketQueuedFollowUp431PreservesWireOrder('epoll', LHttpOpts);
end;

procedure TestEpollRealSocketQueuedFollowUp501PreservesWireOrder;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketQueuedFollowUp501PreservesWireOrder('epoll', LHttpOpts);
end;

procedure TestEpollRealSocketQueuedFollowUp417PreservesWireOrder;
var
  LHttpOpts: THttpServerOptions;
begin
  LHttpOpts := THttpServerOptions.Default;
  LHttpOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  RunRealSocketQueuedFollowUp417PreservesWireOrder('epoll', LHttpOpts);
end;
{$ENDIF}

{ Test 5: Shutdown stops accepting }
procedure TestShutdownStopsAccepting;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LConnected: Boolean;
  LConn: ITcpStream;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/x', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  { Shutdown the server }
  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  { Verify server is no longer running }
  Check(not LServer.IsRunning, 'server not running after shutdown');
  { Try to connect — should fail }
  LConnected := True;
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Close;
  except
    LConnected := False;
  end;
  Check(not LConnected, 'connection refused after shutdown');
  LServer.Free;
end;

{ Test 6: POST request with body }
procedure TestPostWithBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'received';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_CREATED);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'POST /echo HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Content-Length: 5'#13#10 +
      'Connection: close'#13#10#13#10 +
      'hello');
    Check(Pos('HTTP/1.1 201', LResp) > 0, 'status 201 for POST');
    Check(Pos('received', LResp) > 0, 'response body present');
  finally
    StopServer(LServer, LHandle);
  end;
end;

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
procedure TestKeepAlive;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
const
  REQ = 'GET /ping HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));

      { First request }
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'keep-alive: first response 200');
      Check(Pos('pong', LResp1) > 0, 'keep-alive: first body');

      { Second request on same connection }
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'keep-alive: second response 200');
      Check(Pos('pong', LResp2) > 0, 'keep-alive: second body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestKeepAliveEpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
const
  REQ = 'GET /ping HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'epoll keep-alive: first response 200');
      Check(Pos('pong', LResp1) > 0, 'epoll keep-alive: first body');

      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'epoll keep-alive: second response 200');
      Check(Pos('pong', LResp2) > 0, 'epoll keep-alive: second body');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;
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

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
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

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

procedure TestPipelinedRequestsInSingleWrite;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LCombinedReq: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Content-Length: 5'#13#10#13#10 +
         'hello';
  REQ2 = 'GET /next HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LCombinedReq := REQ1 + REQ2;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LCombinedReq[1], SizeUInt(Length(LCombinedReq)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'pipeline-single-write: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'pipeline-single-write: first body preserved');
      Check(Pos('200 OK', LResp2) > 0, 'pipeline-single-write: second response 200');
      Check(Pos('next', LResp2) > 0, 'pipeline-single-write: second body preserved');
      Check(LSeenUpload, 'pipeline-single-write: upload handler called');
      Check(LSeenNext, 'pipeline-single-write: next handler called');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestPipelinedRequestsInSingleWriteEpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1, LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LCombinedReq: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Content-Length: 5'#13#10#13#10 +
         'hello';
  REQ2 = 'GET /next HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LCombinedReq := REQ1 + REQ2;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(LCombinedReq[1], SizeUInt(Length(LCombinedReq)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'epoll pipeline-single-write: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'epoll pipeline-single-write: first body preserved');
      Check(Pos('200 OK', LResp2) > 0, 'epoll pipeline-single-write: second response 200');
      Check(Pos('next', LResp2) > 0, 'epoll pipeline-single-write: second body preserved');
      Check(LSeenUpload, 'epoll pipeline-single-write: upload handler called');
      Check(LSeenNext, 'epoll pipeline-single-write: next handler called');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;
{$ENDIF}

{ Test 8: Connection: close header stops keep-alive }
procedure TestConnectionClose;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LBuf: array[0..0] of Byte;
  LN: SizeUInt;
const
  REQ = 'GET /ping HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp) > 0, 'conn-close: got 200');
      Check(Pos('connection: close', LResp) > 0, 'conn-close: header present');
      { Verify server closed the connection }
      try
        LN := LConn.Read(LBuf[0], 1);
      except
        LN := 0;
      end;
      Check(LN = 0, 'conn-close: server closed connection');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 9: HTTP/1.0 without keep-alive closes connection }
procedure TestHttp10NoKeepAlive;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LBuf: array[0..0] of Byte;
  LN: SizeUInt;
const
  REQ = 'GET /ping HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('200', LResp) > 0, 'http10: got 200');
      { Verify server closed the connection }
      try
        LN := LConn.Read(LBuf[0], 1);
      except
        LN := 0;
      end;
      Check(LN = 0, 'http10: server closed connection');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 10: POST body readable via IReader }
procedure TestPostBodyReadable;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt; LBody: string;
  begin
    LBody := '';
    if AReq.Body <> nil then
    begin
      LN := AReq.Body.Read(LBuf[0], 4096);
      if LN > 0 then SetString(LBody, PAnsiChar(@LBuf[0]), LN);
    end;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(LBody) > 0 then
      AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'POST / HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Content-Length: 11'#13#10 +
      'Connection: close'#13#10#13#10 +
      'hello world');
    Check(Pos('hello world', LResp) > 0, 'body echoed back');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 11: Large body (131072 bytes) }
procedure TestLargeBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LReq: string;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt; LTotal: SizeUInt; LReply: string;
  begin
    LTotal := 0;
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], 4096);
        LTotal := LTotal + LN;
      until LN = 0;
    end;
    LReply := IntToStr(Int64(LTotal));
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LReply))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], SizeUInt(Length(LReply)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    SetLength(LBody, 131072);
    FillChar(LBody[1], 131072, Ord('x'));
    LReq := 'POST / HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Content-Length: 131072'#13#10 +
      'Connection: close'#13#10#13#10 +
      LBody;
    LResp := SendRawRequest(LPort, LReq);
    Check(Pos('131072', LResp) > 0, 'large body length echoed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 12: Generic malformed request returns explicit 400 }
procedure TestMalformedRequest;
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
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, 'GARBAGE DATA HERE'#13#10#13#10);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'generic malformed request: status 400');
    Check(not LHandlerCalled, 'generic malformed request: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestDuplicateContentLength;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10 +
        'Content-Length: 10'#13#10 +
        'Connection: close'#13#10#13#10 +
        'hello';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'duplicate content-length: status 400');
    Check(not LHandlerCalled, 'duplicate content-length: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHeaderNullByte;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LReq: array of Byte;
  LHandlerCalled: Boolean;
const
  PREFIX = 'GET / HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'X-Evil: foo';
  SUFFIX = 'bar'#13#10 +
           'Connection: close'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    SetLength(LReq, Length(PREFIX) + 1 + Length(SUFFIX));
    Move(PREFIX[1], LReq[0], Length(PREFIX));
    LReq[Length(PREFIX)] := 0;
    Move(SUFFIX[1], LReq[Length(PREFIX) + 1], Length(SUFFIX));
    LResp := SendRawRequestBytes(LPort, @LReq[0], SizeUInt(Length(LReq)));
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'null byte in header: status 400');
    Check(not LHandlerCalled, 'null byte in header: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestRequestLineTruncatedAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET / HTTP/1.';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'truncated request line: status 400');
    Check(not LHandlerCalled, 'truncated request line: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHeadersTruncatedAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET / HTTP/1.1'#13#10 +
        'Host: local';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'truncated headers: status 400');
    Check(not LHandlerCalled, 'truncated headers: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestMissingHostHeader;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET / HTTP/1.1'#13#10 +
        'Connection: close'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'missing host http11: status 400');
    Check(not LHandlerCalled, 'missing host http11: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttp10WithoutHostStillAllowed;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
const
  REQ = 'GET /ping HTTP/1.0'#13#10#13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ping', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'pong';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'missing host http10: status 200');
    Check(Pos('pong', LResp) > 0, 'missing host http10: body pong');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttp09NoVersionRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET /'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'http09 request: status 400');
    Check(not LHandlerCalled, 'http09 request: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestRequestLineSplittingRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'GET /path'#13#10 +
        'Injected: header HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Connection: close'#13#10#13#10;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/path', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'request-line splitting: status 400');
    Check(not LHandlerCalled, 'request-line splitting: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestNegativeContentLengthRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: -1'#13#10 +
        'Connection: close'#13#10#13#10 +
        'hello';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'negative content-length: status 400');
    Check(not LHandlerCalled, 'negative content-length: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestVeryLongMethodRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
  LMethod: string;
  LReq: string;
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  SetLength(LMethod, 1000);
  FillChar(LMethod[1], 1000, Ord('X'));
  LReq := LMethod + ' / HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Connection: close'#13#10#13#10;
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, LReq);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'very long method: status 400');
    Check(not LHandlerCalled, 'very long method: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthRequestExtraBytesAfterCloseRejected;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10 +
        'Connection: close'#13#10#13#10 +
        'hello_extra_bytes_here';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'content-length extra bytes after close: status 400');
    Check(not LHandlerCalled, 'content-length extra bytes after close: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveGarbageTailBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello_extra_bytes_here';
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'keep-alive tail: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'keep-alive tail: first body preserved');
      Check(LSeenUpload, 'keep-alive tail: first handler called');
      CheckEqual('hello', LGotBody, 'keep-alive tail: handler sees declared body only');
      Check(Pos('HTTP/1.1 400', LResp2) > 0, 'keep-alive tail: malformed follow-up gets 400');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello' +
        'GET /next HTTP/1.1';
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'keep-alive partial follow-up line: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'keep-alive partial follow-up line: first body preserved');
    Check(LSeenUpload, 'keep-alive partial follow-up line: first handler called');
    CheckEqual('hello', LGotBody, 'keep-alive partial follow-up line: handler sees declared body only');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'keep-alive partial follow-up line: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LGotBody: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Content-Length: 5'#13#10#13#10 +
         'hello' +
         'GET /next HTTP/1.1';
  REQ2_REST = #13#10 +
              'Host: localhost'#13#10 +
              'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'keep-alive partial-next-line: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'keep-alive partial-next-line: first body preserved');
      Check(LSeenUpload, 'keep-alive partial-next-line: first handler called');
      CheckEqual('hello', LGotBody, 'keep-alive partial-next-line: handler sees declared body only');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'keep-alive partial-next-line: second response 200');
      Check(Pos('next', LResp2) > 0, 'keep-alive partial-next-line: second body preserved');
      Check(LSeenNext, 'keep-alive partial-next-line: second handler called');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LGotBody: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Content-Length: 5'#13#10#13#10 +
         'hello' +
         'GET /next HTTP/1.1'#13#10 +
         'Host: localhost'#13#10;
  REQ2_REST = 'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'keep-alive partial-next-headers: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'keep-alive partial-next-headers: first body preserved');
      Check(LSeenUpload, 'keep-alive partial-next-headers: first handler called');
      CheckEqual('hello', LGotBody, 'keep-alive partial-next-headers: handler sees declared body only');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'keep-alive partial-next-headers: second response 200');
      Check(Pos('next', LResp2) > 0, 'keep-alive partial-next-headers: second body preserved');
      Check(LSeenNext, 'keep-alive partial-next-headers: second handler called');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello' +
        'GET /next HTTP/1.1'#13#10 +
        'Host: localhost'#13#10;
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'keep-alive partial follow-up headers: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'keep-alive partial follow-up headers: first body preserved');
    Check(LSeenUpload, 'keep-alive partial follow-up headers: first handler called');
    CheckEqual('hello', LGotBody, 'keep-alive partial follow-up headers: handler sees declared body only');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'keep-alive partial follow-up headers: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestContentLengthKeepAliveGarbageTailBecomesFollowUp400EpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello_extra_bytes_here';
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp1 := ReadOneResponse(LConn);
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'epoll keep-alive tail: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'epoll keep-alive tail: first body preserved');
      Check(LSeenUpload, 'epoll keep-alive tail: first handler called');
      CheckEqual('hello', LGotBody, 'epoll keep-alive tail: handler sees declared body only');
      Check(Pos('HTTP/1.1 400', LResp2) > 0, 'epoll keep-alive tail: malformed follow-up gets 400');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400EpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello' +
        'GET /next HTTP/1.1';
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'epoll keep-alive partial follow-up line: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'epoll keep-alive partial follow-up line: first body preserved');
    Check(LSeenUpload, 'epoll keep-alive partial follow-up line: first handler called');
    CheckEqual('hello', LGotBody, 'epoll keep-alive partial follow-up line: handler sees declared body only');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'epoll keep-alive partial follow-up line: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLaterEpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LGotBody: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Content-Length: 5'#13#10#13#10 +
         'hello' +
         'GET /next HTTP/1.1';
  REQ2_REST = #13#10 +
              'Host: localhost'#13#10 +
              'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'epoll keep-alive partial-next-line: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'epoll keep-alive partial-next-line: first body preserved');
      Check(LSeenUpload, 'epoll keep-alive partial-next-line: first handler called');
      CheckEqual('hello', LGotBody, 'epoll keep-alive partial-next-line: handler sees declared body only');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'epoll keep-alive partial-next-line: second response 200');
      Check(Pos('next', LResp2) > 0, 'epoll keep-alive partial-next-line: second body preserved');
      Check(LSeenNext, 'epoll keep-alive partial-next-line: second handler called');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLaterEpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp1: string;
  LResp2: string;
  LSeenUpload: Boolean;
  LSeenNext: Boolean;
  LGotBody: string;
const
  REQ1 = 'POST /upload HTTP/1.1'#13#10 +
         'Host: localhost'#13#10 +
         'Content-Length: 5'#13#10#13#10 +
         'hello' +
         'GET /next HTTP/1.1'#13#10 +
         'Host: localhost'#13#10;
  REQ2_REST = 'Connection: close'#13#10#13#10;
begin
  LSeenUpload := False;
  LSeenNext := False;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LRouter.Get('/next', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LSeenNext := True;
    LBody := 'next';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 4);
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ1[1], SizeUInt(Length(REQ1)));
      LResp1 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp1) > 0, 'epoll keep-alive partial-next-headers: first response 200');
      Check(Pos('upload:hello', LResp1) > 0, 'epoll keep-alive partial-next-headers: first body preserved');
      Check(LSeenUpload, 'epoll keep-alive partial-next-headers: first handler called');
      CheckEqual('hello', LGotBody, 'epoll keep-alive partial-next-headers: handler sees declared body only');

      LConn.Write(REQ2_REST[1], SizeUInt(Length(REQ2_REST)));
      LResp2 := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp2) > 0, 'epoll keep-alive partial-next-headers: second response 200');
      Check(Pos('next', LResp2) > 0, 'epoll keep-alive partial-next-headers: second body preserved');
      Check(LSeenNext, 'epoll keep-alive partial-next-headers: second handler called');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400EpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LSeenUpload: Boolean;
const
  REQ = 'POST /upload HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 5'#13#10#13#10 +
        'hello' +
        'GET /next HTTP/1.1'#13#10 +
        'Host: localhost'#13#10;
begin
  LGotBody := '';
  LSeenUpload := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
  begin
    LSeenUpload := True;
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
    LBody := 'upload:' + LBody;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0, 'epoll keep-alive partial follow-up headers: first response 200');
    Check(Pos('upload:hello', LResp) > 0, 'epoll keep-alive partial follow-up headers: first body preserved');
    Check(LSeenUpload, 'epoll keep-alive partial follow-up headers: first handler called');
    CheckEqual('hello', LGotBody, 'epoll keep-alive partial follow-up headers: handler sees declared body only');
    Check(Pos('HTTP/1.1 400', LResp) > 0, 'epoll keep-alive partial follow-up headers: malformed follow-up gets 400');
  finally
    StopServer(LServer, LHandle);
  end;
end;
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}
{$ENDIF}

{ Test 13: Query parameters }
procedure TestQueryParam;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/search', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := AReq.QueryParam('q') + ':' + AReq.QueryParam('page');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET /search?q=hello&page=2 HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('hello', LResp) > 0, 'query param q=hello');
    Check(Pos('2', LResp) > 0, 'query param page=2');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestRequestTargetUrlMaterialization;
var
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LHandler: IHttpHandler;
  LResp: string;
begin
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LUrl: TUrl;
    LBody: string;
  begin
    LUrl := AReq.Url;
    LBody := LUrl.Scheme + '|' + LUrl.Host + '|' +
      IntToStr(Int64(LUrl.Port)) + '|' + LUrl.Path + '|' + LUrl.RawQuery;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);

  LHandle := StartServer(LHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET http://example.com:8080/proxy?q=1 HTTP/1.1'#13#10 +
      'Host: proxy.local'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('http|example.com|8080|/proxy|q=1', LResp) > 0,
      'absolute-form request-target materialized as URL authority/path/query');

    LResp := SendRawRequest(LPort,
      'OPTIONS * HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('||0|*|', LResp) > 0,
      'asterisk-form request-target preserved as path');

    LResp := SendRawRequest(LPort,
      'CONNECT example.com:443 HTTP/1.1'#13#10 +
      'Host: example.com:443'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('||0|example.com:443|', LResp) > 0,
      'authority-form request-target preserved as path');

    LResp := SendRawRequest(LPort,
      'GET /http://example.com/path?q=1 HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('||0|/http://example.com/path|q=1', LResp) > 0,
      'origin-form scheme-like path is not parsed as authority');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 14: RemoteAddr contains 127.0.0.1 }
procedure TestRemoteAddr;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := AReq.RemoteAddr;
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'GET / HTTP/1.1'#13#10 +
      'Host: x'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('127.0.0.1', LResp) > 0, 'remote addr is 127.0.0.1');
  finally
    StopServer(LServer, LHandle);
  end;
end;

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

procedure TestConcurrentStress;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LThreads: array[0..9] of TPlatformThreadHandle;
  LI, LWait: Int32;
  LRet: Pointer;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    GServerPort := LPort;
    GStressSuccess := 0;
    GStressDone := 0;
    for LI := 0 to 9 do
      platform_thread_create(LThreads[LI], @StressThread, nil);
    { Wait for all threads to finish }
    LWait := 0;
    while (GStressDone < 10) and (LWait < 2000) do
    begin
      platform_thread_sleep_ns(5000000); { 5ms }
      Inc(LWait);
    end;
    for LI := 0 to 9 do
      platform_thread_join(LThreads[LI], LRet);
    Check(GStressSuccess = 1000, 'stress: 1000 successes (got ' + IntToStr(Int64(GStressSuccess)) + ')');
  finally
    StopServer(LServer, LHandle);
  end;
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

procedure TestHeaderFieldOverMaxHeaderSizeRejected;
begin
  RunHeaderFieldOverMaxHeaderSizeRejected(False,
    'header field over max-header threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestHeaderFieldOverMaxHeaderSizeRejectedEpollBackend;
begin
  RunHeaderFieldOverMaxHeaderSizeRejected(True,
    'header field over max-header epoll');
end;
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

procedure TestRequestTargetOverMaxHeaderSizeRejected;
begin
  RunRequestTargetOverMaxHeaderSizeRejected(False,
    'request-target over max-header threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestRequestTargetOverMaxHeaderSizeRejectedEpollBackend;
begin
  RunRequestTargetOverMaxHeaderSizeRejected(True,
    'request-target over max-header epoll');
end;
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

procedure TestMaxBodySize;
begin
  RunFixedLengthMaxBodySizeRejected(False,
    'fixed-length max body size threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestMaxBodySizeEpollBackend;
begin
  RunFixedLengthMaxBodySizeRejected(True,
    'fixed-length max body size epoll');
end;
{$ENDIF}

procedure TestContentLengthRequestTruncatedAtEof;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LHandlerCalled: Boolean;
const
  REQ = 'POST / HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Content-Length: 10'#13#10 +
        'Connection: close'#13#10#13#10 +
        'hello';
begin
  LHandlerCalled := False;
  LRouter := THttpRouter.Create;
  LRouter.Post('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequestAndShutdownWrite(LPort, REQ);
    Check(Pos('HTTP/1.1 400', LResp) > 0,
      'truncated content-length request: status 400');
    Check(not LHandlerCalled, 'truncated content-length request: handler not called');
  finally
    StopServer(LServer, LHandle);
  end;
end;

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

procedure TestInformationalResponseAllowsFinalResponse;
begin
  RunInformationalResponseAllowsFinalResponse(False, 'informational response');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestInformationalResponseAllowsFinalResponseEpollBackend;
begin
  RunInformationalResponseAllowsFinalResponse(True, 'epoll informational response');
end;
{$ENDIF}

{ Test 18c: HEAD response stays bodyless on the wire even if handler writes }
{ Test 18d: HEAD response preserves explicit content-length but stays bodyless }
procedure TestHeadResponsePreservesContentLengthWithoutBodyBytes;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmHead, '/head-content-length', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    LBody := 'hello';
    AW.GetHeaders.SetHeader('content-length', '5');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'HEAD /head-content-length HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Connection: close'#13#10#13#10);
    Check(Pos('HTTP/1.1 200 OK', LResp) = 1,
      'HEAD-CL: status line present');
    Check(Pos('content-length: 5'#13#10, LResp) > 0,
      'HEAD-CL: explicit content-length preserved');
    Check(Pos('transfer-encoding: chunked', LResp) = 0,
      'HEAD-CL: no chunked header');
    Check(Pos('0'#13#10#13#10, LResp) = 0,
      'HEAD-CL: no chunk trailer');
    Check(Pos('hello', LResp) = 0,
      'HEAD-CL: no body bytes on wire');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 19: Chunked response preserves keep-alive }
{ Test 20: Hijack transfers connection ownership away from server loop }
procedure TestHijackLeavesConnectionOpenForHandlerOwner;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LServerSideConn: ITcpStream;
  LHijacker: IHttpHijacker;
  LResp: string;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
  LProbe: string;
const
  REQ = 'GET /hijack HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Connection: keep-alive'#13#10#13#10;
  RAW_RESP = 'HTTP/1.1 200 OK'#13#10 +
             'content-length: 7'#13#10 +
             'connection: keep-alive'#13#10#13#10 +
             'hijack!';
begin
  LServerSideConn := nil;
  LRouter := THttpRouter.Create;
  LRouter.Get('/hijack', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    if not Supports(AW, IHttpHijacker, LHijacker) then
      Fail('response writer does not support IHttpHijacker');
    LServerSideConn := LHijacker.Hijack;
    LServerSideConn.Write(RAW_RESP[1], SizeUInt(Length(RAW_RESP)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('hijack!', LResp) > 0, 'hijack owner wrote raw response');

      platform_thread_sleep_ns(100000000); { let the server loop return }
      Check(LServerSideConn <> nil, 'handler captured hijacked connection');
      LProbe := '!';
      LServerSideConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(1)));
      LConn.Write(LProbe[1], SizeUInt(Length(LProbe)));
      LN := LServerSideConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      CheckEqual(Int64(Length(LProbe)), Int64(LN),
        'handler-owned stream can read after handler returns');
      Check(Chr(LBuf[0]) = LProbe, 'handler-owned stream received probe byte');
    finally
      LConn.Close;
      LServerSideConn := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHijackExceptionDoesNotWrite500OrCloseHandlerConnection;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LServerSideConn: ITcpStream;
  LHijacker: IHttpHijacker;
  LResp: string;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
  LProbe: string;
const
  REQ = 'GET /hijack-crash HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Connection: keep-alive'#13#10#13#10;
  RAW_RESP = 'HTTP/1.1 200 OK'#13#10 +
             'content-length: 7'#13#10 +
             'connection: keep-alive'#13#10#13#10 +
             'hijack!';
begin
  LServerSideConn := nil;
  LRouter := THttpRouter.Create;
  LRouter.Get('/hijack-crash', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    if not Supports(AW, IHttpHijacker, LHijacker) then
      Fail('response writer does not support IHttpHijacker');
    LServerSideConn := LHijacker.Hijack;
    LServerSideConn.Write(RAW_RESP[1], SizeUInt(Length(RAW_RESP)));
    raise Exception.Create('crash after hijack');
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('hijack!', LResp) > 0, 'hijack-crash owner wrote raw response');

      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(200)));
      try
        LN := LConn.Read(LBuf[0], 1);
      except
        LN := 0;
      end;
      CheckEqual(Int64(0), Int64(LN),
        'server does not append 500 after hijack exception');

      platform_thread_sleep_ns(100000000);
      Check(LServerSideConn <> nil, 'handler captured hijacked connection after exception');
      LProbe := '?';
      LServerSideConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(1)));
      LConn.Write(LProbe[1], SizeUInt(Length(LProbe)));
      LN := LServerSideConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      CheckEqual(Int64(Length(LProbe)), Int64(LN),
        'handler-owned stream stays readable after hijack exception');
      Check(Chr(LBuf[0]) = LProbe,
        'handler-owned stream received probe after hijack exception');
    finally
      LConn.Close;
      LServerSideConn := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestHijackLeavesConnectionOpenForHandlerOwnerEpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LServerSideConn: ITcpStream;
  LHijacker: IHttpHijacker;
  LResp: string;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
  LProbe: string;
const
  REQ = 'GET /hijack HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Connection: keep-alive'#13#10#13#10;
  RAW_RESP = 'HTTP/1.1 200 OK'#13#10 +
             'content-length: 7'#13#10 +
             'connection: keep-alive'#13#10#13#10 +
             'hijack!';
begin
  LServerSideConn := nil;
  LRouter := THttpRouter.Create;
  LRouter.Get('/hijack', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    if not Supports(AW, IHttpHijacker, LHijacker) then
      Fail('response writer does not support IHttpHijacker');
    LServerSideConn := LHijacker.Hijack;
    LServerSideConn.Write(RAW_RESP[1], SizeUInt(Length(RAW_RESP)));
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('hijack!', LResp) > 0, 'epoll hijack owner wrote raw response');

      platform_thread_sleep_ns(100000000);
      Check(LServerSideConn <> nil, 'epoll handler captured hijacked connection');
      LProbe := '!';
      LServerSideConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(1)));
      LConn.Write(LProbe[1], SizeUInt(Length(LProbe)));
      LN := LServerSideConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      CheckEqual(Int64(Length(LProbe)), Int64(LN),
        'epoll handler-owned stream can read after handler returns');
      Check(Chr(LBuf[0]) = LProbe, 'epoll handler-owned stream received probe byte');
    finally
      LConn.Close;
      LServerSideConn := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHijackExceptionDoesNotWrite500OrCloseHandlerConnectionEpollBackend;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LServerSideConn: ITcpStream;
  LHijacker: IHttpHijacker;
  LResp: string;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
  LProbe: string;
const
  REQ = 'GET /hijack-crash HTTP/1.1'#13#10 +
        'Host: localhost'#13#10 +
        'Connection: keep-alive'#13#10#13#10;
  RAW_RESP = 'HTTP/1.1 200 OK'#13#10 +
             'content-length: 7'#13#10 +
             'connection: keep-alive'#13#10#13#10 +
             'hijack!';
begin
  LServerSideConn := nil;
  LRouter := THttpRouter.Create;
  LRouter.Get('/hijack-crash', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    if not Supports(AW, IHttpHijacker, LHijacker) then
      Fail('response writer does not support IHttpHijacker');
    LServerSideConn := LHijacker.Hijack;
    LServerSideConn.Write(RAW_RESP[1], SizeUInt(Length(RAW_RESP)));
    raise Exception.Create('crash after hijack');
  end);
  LHandle := StartEpollServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
      LConn.Write(REQ[1], SizeUInt(Length(REQ)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('hijack!', LResp) > 0, 'epoll hijack-crash owner wrote raw response');

      LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(200)));
      try
        LN := LConn.Read(LBuf[0], 1);
      except
        LN := 0;
      end;
      CheckEqual(Int64(0), Int64(LN),
        'epoll server does not append 500 after hijack exception');

      platform_thread_sleep_ns(100000000);
      Check(LServerSideConn <> nil,
        'epoll handler captured hijacked connection after exception');
      LProbe := '?';
      LServerSideConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(1)));
      LConn.Write(LProbe[1], SizeUInt(Length(LProbe)));
      LN := LServerSideConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      CheckEqual(Int64(Length(LProbe)), Int64(LN),
        'epoll handler-owned stream stays readable after hijack exception');
      Check(Chr(LBuf[0]) = LProbe,
        'epoll handler-owned stream received probe after hijack exception');
    finally
      LConn.Close;
      LServerSideConn := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;
{$ENDIF}

procedure TestMaxRequestsPerConnection;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LResp: string;
  LReq: string;
  LOptions: THttpServerOptions;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/test', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('content-type', 'text/plain');
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write('ok', 2);
  end);
  LOptions := THttpServerOptions.Default
    .WithMaxRequestsPerConnection(2);
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOptions, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));

      { First request — should succeed with keep-alive }
      LReq := 'GET /test HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: keep-alive'#13#10#13#10;
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp) > 0, 'first request 200');
      Check(Pos('connection: close', LowerCase(LResp)) = 0,
        'first response has no connection: close');

      { Second request — should succeed but with Connection: close }
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := ReadOneResponse(LConn);
      Check(Pos('200 OK', LResp) > 0, 'second request 200');
      Check(Pos('connection: close', LowerCase(LResp)) > 0,
        'second response has connection: close');
    finally
      LConn.Close;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Q1-4: lock write/backpressure semantics in H1 source (CONTRACT §4.4). }
procedure TestH1WriteBackpressureContractSource;
var
  LConnSrc: string;
  LPollSrc: string;
begin
  LConnSrc := ReadFileText('../../../src/nextpas.core.http.impl.h1.conn.pas');
  LPollSrc := ReadFileText('../../../src/nextpas.core.http.impl.h1.poll.pas');
  Check(Pos('procedure TH1ServerConnectionState.ArmPollWriteDeadline', LConnSrc) > 0,
    'poll write deadline arm exists');
  Check(Pos('tsiorWouldBlock', LPollSrc) > 0, 'would-block drain path present');
  Check(Pos('ANextEvents := [peWritable]', LPollSrc) > 0,
    'would-block subscribes peWritable');
  Check(Pos('FPollWriteDeadline := TDeadline.Infinite', LPollSrc) > 0,
    'successful/timeout drain clears write deadline');
  Check(Pos('PreferPollWorkerHandoff', LConnSrc) > 0,
    'S1-1 handoff flag coexists with drain path');
  Check(Pos('not AState.FOptions.PreferPollWorkerHandoff', LPollSrc) > 0,
    'reactor-inline default does not remove drain/backpressure path');
end;

procedure TestH1OutboundBufferReuseSourceContract;
var
  LConnSrc: string;
  LPollSrc: string;
begin
  LConnSrc := ReadFileText('../../../src/nextpas.core.http.impl.h1.conn.pas');
  LPollSrc := ReadFileText('../../../src/nextpas.core.http.impl.h1.poll.pas');
  Check(Pos('function TH1ServerConnectionState.AcquireOutboundBuffer', LConnSrc) > 0,
    'S2-1 acquire outbound free-list');
  Check(Pos('procedure TH1ServerConnectionState.ReleaseOutboundBuffer', LConnSrc) > 0,
    'S2-1 release outbound free-list');
  Check(Pos('FSpareOutbound0', LConnSrc) > 0, 'S2-1 spare slot 0');
  Check(Pos('FSpareOutbound1', LConnSrc) > 0, 'S2-1 spare slot 1 (pipeline depth)');
  Check(Pos('AcquireOutboundBuffer', LConnSrc) > 0, 'poll/threaded paths use acquire');
  Check(Pos('AState.ReleaseOutboundBuffer(AState.FPollOutbound)', LPollSrc) > 0,
    'drain completion returns buffer to free-list');
end;

procedure TestH1FastPathFixedBodySourceContract;
var
  LSrc: string;
  LFastSrc: string;
begin
  LSrc := ReadFileText('../../../src/nextpas.core.http.impl.h1.conn.pas');
  LFastSrc := ReadFileText('../../../src/nextpas.core.http.impl.h1.fast.pas');
  Check(Pos('FAST_PATH_MAX_BODY = 65536', LSrc) > 0,
    'S2-2 body size cap for snapshot copy');
  Check(Pos('LFast.ContentLength > FAST_PATH_MAX_BODY', LSrc) > 0,
    'S2-2 oversize body falls back to llhttp');
  Check(Pos('TH1FastSnapshotBodyReader', LFastSrc) > 0,
    'S2-2 snapshot body reader lives in h1.fast');
  Check(Pos('NewH1FastRequestSnapshot(LFast, ABuf)', LSrc) > 0,
    'S2-2 server uses fast-unit snapshot factory');
  Check(Pos('function NewH1FastRequestSnapshot', LFastSrc) > 0,
    'S2-2 snapshot factory owned by h1.fast');
  { Still reject expect / TE / connection close }
  Check(Pos('LFast.HasExpect', LSrc) > 0, 'S2-2 still rejects Expect');
  Check(Pos('LFast.HasTransferEncoding', LSrc) > 0, 'S2-2 still rejects TE');
end;

procedure TestReadAbort408OnThreadedMidRequestTimeout;
{ R11: threaded backend — request read deadline expiring mid-request answers
  a best-effort 408 then closes, and fires the read-abort sink once. }
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: THttpServerOptions;
  LSinkObj: TRecordingReadAbortSink;
  LSink: IHttpServerReadAbortSink;
  LConn: ITcpStream;
  LPartial: string;
  LData: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
const
  CRLF = #13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ok', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'OK';
    AW.GetHeaders.SetHeader('content-length',
      IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.ReadTimeout := 300;
  LOpts.IdleTimeout := 300;
  LSinkObj := TRecordingReadAbortSink.Create;
  LSink := LSinkObj;
  LOpts.ReadAbortSink := LSink;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LPartial :=
        'POST /x HTTP/1.1' + CRLF +
        'Host: t' + CRLF +
        'Content-Length: 100' + CRLF +
        CRLF +
        'ab';
      LConn.Write(LPartial[1], SizeUInt(Length(LPartial)));
      LData := ReadUntilClosedOrDeadline(LConn, 5000, LClosed, LTimedOut);
    finally
      LConn.Close;
    end;
    Check(Pos('HTTP/1.1 408', LData) > 0,
      'threaded mid-request timeout answers 408 instead of a bare reset');
    Check(LClosed, 'threaded mid-request timeout closes after the 408');
  finally
    StopServer(LServer, LHandle);
  end;
  CheckEqual(Int64(1), Int64(LSinkObj.Count),
    'threaded read-abort sink fired exactly once');
  Check(Pos('127.0.0.1', LSinkObj.LastAddr) > 0,
    'threaded read-abort sink reports the peer address');
end;

procedure TestIdleKeepAliveTimeoutStaysSilent;
{ R11 counterpart: keep-alive idle expiry (no request bytes for the next
  request) closes silently — no 408, no sink notification. }
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: THttpServerOptions;
  LSinkObj: TRecordingReadAbortSink;
  LSink: IHttpServerReadAbortSink;
  LConn: ITcpStream;
  LRequest: string;
  LData: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
const
  CRLF = #13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ok', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'OK';
    AW.GetHeaders.SetHeader('content-length',
      IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.ReadTimeout := 300;
  LOpts.IdleTimeout := 300;
  LSinkObj := TRecordingReadAbortSink.Create;
  LSink := LSinkObj;
  LOpts.ReadAbortSink := LSink;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LRequest := 'GET /ok HTTP/1.1' + CRLF + 'Host: t' + CRLF + CRLF;
      LConn.Write(LRequest[1], SizeUInt(Length(LRequest)));
      { Response 1 completes, then the client sends nothing: the idle
        keep-alive deadline fires and must end in a bare close. }
      LData := ReadUntilClosedOrDeadline(LConn, 5000, LClosed, LTimedOut);
    finally
      LConn.Close;
    end;
    Check(Pos('HTTP/1.1 200', LData) > 0,
      'idle scenario first request succeeds');
    Check(Pos('HTTP/1.1 408', LData) = 0,
      'idle keep-alive timeout stays silent (no 408)');
    Check(LClosed, 'idle keep-alive timeout closes the connection');
  finally
    StopServer(LServer, LHandle);
  end;
  CheckEqual(Int64(0), Int64(LSinkObj.Count),
    'idle keep-alive timeout does not fire the read-abort sink');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestLivePostFixedBodyOnEpoll;
{ S2-2: fixed-length POST body readable on epoll (fast-path snapshot body). }
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: THttpServerOptions;
  LResp: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBody: TBytes;
    LStr: string;
  begin
    LBody := HttpReadRequestBodyBytes(AReq);
    if Length(LBody) > 0 then
      SetString(LStr, PAnsiChar(@LBody[0]), Length(LBody))
    else
      LStr := '';
    AW.GetHeaders.SetHeader('content-type', 'text/plain');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LStr))));
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(LStr) > 0 then
      AW.Write(LStr[1], SizeUInt(Length(LStr)));
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LResp := SendRawRequest(LPort,
      'POST /echo HTTP/1.1'#13#10 +
      'Host: localhost'#13#10 +
      'Content-Length: 5'#13#10 +
      'Connection: close'#13#10#13#10 +
      'hello');
    Check(Pos('HTTP/1.1 200', LResp) > 0, 'epoll POST fixed body status 200');
    Check(Pos('hello', LResp) > 0, 'epoll POST fixed body echoed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestLiveReadAbort408OnEpollMidRequestTimeout;
{ R11 on the poll backend end to end: mid-request read-deadline expiry
  answers a best-effort 408 then closes, sink fires once. }
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: THttpServerOptions;
  LSinkObj: TRecordingReadAbortSink;
  LSink: IHttpServerReadAbortSink;
  LConn: ITcpStream;
  LPartial: string;
  LData: string;
  LClosed: Boolean;
  LTimedOut: Boolean;
const
  CRLF = #13#10;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/ok', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'OK';
    AW.GetHeaders.SetHeader('content-length',
      IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_EPOLL;
  LOpts.ReadTimeout := 300;
  LOpts.IdleTimeout := 300;
  LSinkObj := TRecordingReadAbortSink.Create;
  LSink := LSinkObj;
  LOpts.ReadAbortSink := LSink;
  LHandle := StartServerWithOptions(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    try
      LPartial :=
        'POST /x HTTP/1.1' + CRLF +
        'Host: t' + CRLF +
        'Content-Length: 100' + CRLF +
        CRLF +
        'ab';
      LConn.Write(LPartial[1], SizeUInt(Length(LPartial)));
      LData := ReadUntilClosedOrDeadline(LConn, 5000, LClosed, LTimedOut);
    finally
      LConn.Close;
    end;
    Check(Pos('HTTP/1.1 408', LData) > 0,
      'epoll mid-request timeout answers 408 instead of a bare reset');
    Check(LClosed, 'epoll mid-request timeout closes after the 408');
  finally
    StopServer(LServer, LHandle);
  end;
  CheckEqual(Int64(1), Int64(LSinkObj.Count),
    'epoll read-abort sink fired exactly once');
end;
{$ENDIF}

{ Main }

begin
  T := TTestSuite.Create('nextpas.core.http.server');
  T.Test('Simple GET 200', @TestSimpleGet200);
  T.Test('Live SSE event stream', @TestLiveSSEEventStream);
  T.Test('Live SSE flush pushes first frame before handler returns',
    @TestLiveSSEFlushPushesFrameBeforeHandlerReturns);
  T.Test('Empty handler commits default response',
    @TestEmptyHandlerCommitsDefaultResponse);
  T.Test('Simple GET 200 with epoll backend', @TestSimpleGet200EpollBackend);
  T.Test('Keep-alive: two requests one connection with epoll backend',
    @TestKeepAliveEpollBackend);
  T.Test('Informational response allows later final response with epoll backend',
    @TestInformationalResponseAllowsFinalResponseEpollBackend);
  T.Test('Request-target over MaxHeaderSize -> 431 with epoll backend',
    @TestRequestTargetOverMaxHeaderSizeRejectedEpollBackend);
  T.Test('Header field over MaxHeaderSize -> explicit 431 with epoll backend',
    @TestHeaderFieldOverMaxHeaderSizeRejectedEpollBackend);
  T.Test('MaxBodySize enforcement -> 413 with epoll backend',
    @TestMaxBodySizeEpollBackend);
  T.Test('Pipelined requests in single write with epoll backend',
    @TestPipelinedRequestsInSingleWriteEpollBackend);
  T.Test('Content-Length keep-alive garbage tail -> follow-up 400 with epoll backend',
    @TestContentLengthKeepAliveGarbageTailBecomesFollowUp400EpollBackend);
  T.Test('Content-Length keep-alive truncated follow-up request line -> follow-up 400 with epoll backend',
    @TestContentLengthKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400EpollBackend);
  T.Test('Content-Length keep-alive partial follow-up request line can complete later with epoll backend',
    @TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLaterEpollBackend);
  T.Test('Content-Length keep-alive partial follow-up headers can complete later with epoll backend',
    @TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLaterEpollBackend);
  T.Test('Content-Length keep-alive truncated follow-up headers -> follow-up 400 with epoll backend',
    @TestContentLengthKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400EpollBackend);
  T.Test('Hijack keeps connection open for handler owner with epoll backend',
    @TestHijackLeavesConnectionOpenForHandlerOwnerEpollBackend);
  T.Test('Hijack exception does not write 500 or close handler connection with epoll backend',
    @TestHijackExceptionDoesNotWrite500OrCloseHandlerConnectionEpollBackend);
  T.Test('Committed response exception does not append 500 with epoll backend',
    @TestCommittedResponseExceptionDoesNotAppend500EpollBackend);
  T.Test('Real socket write timeout backpressure stops pipeline with epoll backend',
    @TestRealSocketWriteTimeoutBackpressureStopsPipelineEpollBackend);
  T.Test('Real socket write timeout backpressure does not emit follow-up 400 with epoll backend',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp400EpollBackend);
  T.Test('Real socket write timeout backpressure does not emit follow-up 413 with epoll backend',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp413EpollBackend);
  T.Test('Real socket write timeout backpressure does not emit follow-up 431 with epoll backend',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp431EpollBackend);
  T.Test('Real socket write timeout backpressure does not emit follow-up 417 with epoll backend',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp417EpollBackend);
  T.Test('Real socket write timeout backpressure does not emit follow-up 501 with epoll backend',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp501EpollBackend);
  T.Test('Real socket write timeout ignores slow buffered handler with epoll backend',
    @TestRealSocketWriteTimeoutDoesNotExpireDuringSlowBufferedHandlerEpollBackend);
  T.Test('Real socket queued follow-up 400 preserves wire order with epoll backend',
    @TestEpollRealSocketQueuedFollowUp400PreservesWireOrder);
  T.Test('Real socket queued follow-up 413 preserves wire order with epoll backend',
    @TestEpollRealSocketQueuedFollowUp413PreservesWireOrder);
  T.Test('Real socket queued follow-up 431 preserves wire order with epoll backend',
    @TestEpollRealSocketQueuedFollowUp431PreservesWireOrder);
  T.Test('Real socket queued follow-up 417 preserves wire order with epoll backend',
    @TestEpollRealSocketQueuedFollowUp417PreservesWireOrder);
  T.Test('Real socket queued follow-up 501 preserves wire order with epoll backend',
    @TestEpollRealSocketQueuedFollowUp501PreservesWireOrder);
  T.Test('Real socket queued follow-up 400 preserves wire order with threaded backend',
    @TestRealSocketQueuedFollowUp400PreservesWireOrderThreadedBackend);
  T.Test('Real socket queued follow-up 413 preserves wire order with threaded backend',
    @TestRealSocketQueuedFollowUp413PreservesWireOrderThreadedBackend);
  T.Test('Real socket queued follow-up 431 preserves wire order with threaded backend',
    @TestRealSocketQueuedFollowUp431PreservesWireOrderThreadedBackend);
  T.Test('Real socket queued follow-up 417 preserves wire order with threaded backend',
    @TestRealSocketQueuedFollowUp417PreservesWireOrderThreadedBackend);
  T.Test('Real socket queued follow-up 501 preserves wire order with threaded backend',
    @TestRealSocketQueuedFollowUp501PreservesWireOrderThreadedBackend);
  T.Test('Custom body response', @TestCustomBody);
  T.Test('404 for unmatched route', @TestNotFound404);
  T.Test('Handler exception -> 500', @TestHandlerException500);
  T.Test('Committed response exception does not append 500',
    @TestCommittedResponseExceptionDoesNotAppend500);
  T.Test('H1 transport exposes context-aware session factory',
    @TestH1TransportExposesContextSessionFactory);
  T.Test('H1 transport rejects nil connection or handler',
    @TestH1TransportRejectsNilConnOrHandler);
  T.Test('H1 poll-driven session hands off per completed request',
    @TestH1PollDrivenSessionHandsOffPerCompletedRequest);
  T.Test('H1 poll-driven session drains response via writable events',
    @TestH1PollDrivenSessionDrainsResponseViaWritableEvents);
  T.Test('H1 poll-driven session times out stalled drain on deadline wake',
    @TestH1PollDrivenSessionTimesOutStalledDrainOnDeadlineWake);
  T.Test('H1 poll-driven session clears wake deadline after successful timed drain',
    @TestH1PollDrivenSessionClearsWakeDeadlineAfterSuccessfulTimedDrain);
  T.Test('H1 poll-driven session times out idle read wait before first request',
    @TestH1PollDrivenSessionTimesOutIdleReadWaitBeforeFirstRequest);
  T.Test('H1 poll-driven session times out partial fixed-length body read wait',
    @TestH1PollDrivenSessionTimesOutPartialFixedLengthBodyReadWait);
  T.Test('H1 poll-driven session partial timed drain stops buffered follow-up',
    @TestH1PollDrivenSessionPartialTimedDrainStopsBufferedFollowUp);
  T.Test('H1 poll-driven session queues bounded responses while draining',
    @TestH1PollDrivenSessionQueuesBoundedResponsesWhileDraining);
  T.Test('H1 poll-driven session queues follow-up 400 behind active drain',
    @TestH1PollDrivenSessionQueuesFollowUpBadRequestBehindActiveDrain);
  T.Test('H1 poll-driven session queues follow-up 413 behind active drain',
    @TestH1PollDrivenSessionQueuesFollowUpPayloadTooLargeBehindActiveDrain);
  T.Test('H1 poll-driven session queues follow-up 431 behind active drain',
    @TestH1PollDrivenSessionQueuesFollowUpHeaderTooLargeBehindActiveDrain);
  T.Test('H1 poll-driven session queues follow-up 501 behind active drain',
    @TestH1PollDrivenSessionQueuesFollowUpNotImplementedBehindActiveDrain);
  T.Test('H1 poll-driven standalone bad request drains via writable events',
    @TestH1PollDrivenStandaloneBadRequestDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone oversize trailer drains via writable events',
    @TestH1PollDrivenStandaloneOversizeTrailerDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone invalid trailer field drains via writable events',
    @TestH1PollDrivenStandaloneInvalidTrailerFieldDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer field-name EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerFieldNameAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer separator EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerSeparatorAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer empty-value CR EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerEmptyValueCrAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer empty-value EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerEmptyValueAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer empty-value section CR EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerEmptyValueSectionCrAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer whitespace EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerWhitespaceAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer whitespace CR EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerWhitespaceCrAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer whitespace section EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerWhitespaceSectionAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer whitespace section CR EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerWhitespaceSectionCrAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer field line EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerFieldLineAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer field CR EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerFieldCrAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone truncated trailer CR EOF drains via writable events',
    @TestH1PollDrivenStandaloneTruncatedTrailerCrAtEofDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone unsupported transfer-coding drains via writable events',
    @TestH1PollDrivenStandaloneUnsupportedTransferCodingDrainsViaWritableEvents);
  T.Test('H1 poll-driven standalone bad request partial-timeout preserves status',
    @TestH1PollDrivenStandaloneBadRequestPartialTimeoutPreservesStatus);
  T.Test('H1 poll-driven standalone payload-too-large partial-timeout preserves status',
    @TestH1PollDrivenStandalonePayloadTooLargePartialTimeoutPreservesStatus);
  T.Test('H1 poll-driven standalone header-too-large partial-timeout preserves status',
    @TestH1PollDrivenStandaloneHeaderTooLargePartialTimeoutPreservesStatus);
  T.Test('H1 poll-driven standalone unsupported transfer-coding partial-timeout preserves status',
    @TestH1PollDrivenStandaloneUnsupportedTransferCodingPartialTimeoutPreservesStatus);
  T.Test('Session stops after zero-progress response write failure',
    @TestSessionStopsAfterZeroProgressWriteFailure);
  T.Test('Direct error response arms write timeout on malformed request',
    @TestDirectErrorResponseArmsWriteTimeoutOnMalformedRequest);
  T.Test('Direct error response arms write timeout on payload-too-large request',
    @TestDirectErrorResponseArmsWriteTimeoutOnPayloadTooLargeRequest);
  T.Test('Direct error response arms write timeout on header-too-large request',
    @TestDirectErrorResponseArmsWriteTimeoutOnHeaderTooLargeRequest);
  T.Test('Direct error response arms write timeout on unsupported transfer-coding request',
    @TestDirectErrorResponseArmsWriteTimeoutOnUnsupportedTransferCodingRequest);
  T.Test('Direct error response partial-timeout on malformed request preserves status',
    @TestDirectErrorResponsePartialWriteTimeoutOnMalformedRequest);
  T.Test('Direct error response partial-timeout on payload-too-large request preserves status',
    @TestDirectErrorResponsePartialWriteTimeoutOnPayloadTooLargeRequest);
  T.Test('Direct error response partial-timeout on header-too-large request preserves status',
    @TestDirectErrorResponsePartialWriteTimeoutOnHeaderTooLargeRequest);
  T.Test('Direct error response partial-timeout on unsupported transfer-coding request preserves status',
    @TestDirectErrorResponsePartialWriteTimeoutOnUnsupportedTransferCodingRequest);
  T.Test('Write timeout before any wire bytes does not append 500',
    @TestWriteTimeoutBeforeAnyWireBytesDoesNotAppend500);
  T.Test('Write timeout after partial wire bytes stops pipeline without 500',
    @TestWriteTimeoutAfterPartialWireBytesStopsPipelineWithout500);
  T.Test('Real socket write timeout ignores slow buffered handler',
    @TestRealSocketWriteTimeoutDoesNotExpireDuringSlowBufferedHandler);
  T.Test('Real socket write timeout backpressure stops pipeline',
    @TestRealSocketWriteTimeoutBackpressureStopsPipeline);
  T.Test('Real socket write timeout backpressure does not emit follow-up 400',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp400);
  T.Test('Real socket write timeout backpressure does not emit follow-up 413',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp413);
  T.Test('Real socket write timeout backpressure does not emit follow-up 431',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp431);
  T.Test('Real socket write timeout backpressure does not emit follow-up 417',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp417);
  T.Test('Real socket write timeout backpressure does not emit follow-up 501',
    @TestRealSocketWriteTimeoutBackpressureDoesNotEmitFollowUp501);
  T.Test('Shutdown stops accepting', @TestShutdownStopsAccepting);
  T.Test('POST with body -> 201', @TestPostWithBody);
  T.Test('Keep-alive: two requests one connection', @TestKeepAlive);
  T.Test('Pipelined requests in single write', @TestPipelinedRequestsInSingleWrite);
  T.Test('Connection: close stops keep-alive', @TestConnectionClose);
  T.Test('HTTP/1.0 no keep-alive', @TestHttp10NoKeepAlive);
  T.Test('POST body readable via IReader', @TestPostBodyReadable);
  T.Test('Large body 131072 bytes', @TestLargeBody);
  T.Test('Generic malformed request -> 400', @TestMalformedRequest);
  T.Test('Duplicate Content-Length -> 400', @TestDuplicateContentLength);
  T.Test('Header with null byte -> 400', @TestHeaderNullByte);
  T.Test('Request line truncated at EOF -> 400', @TestRequestLineTruncatedAtEof);
  T.Test('Headers truncated at EOF -> 400', @TestHeadersTruncatedAtEof);
  T.Test('HTTP/1.1 missing Host -> 400', @TestMissingHostHeader);
  T.Test('HTTP/1.0 missing Host still allowed', @TestHttp10WithoutHostStillAllowed);
  T.Test('HTTP/0.9 no version -> 400', @TestHttp09NoVersionRejected);
  T.Test('Request-line splitting -> 400', @TestRequestLineSplittingRejected);
  T.Test('Negative Content-Length -> 400', @TestNegativeContentLengthRejected);
  T.Test('Very long method -> 400', @TestVeryLongMethodRejected);
  T.Test('Content-Length extra bytes after close -> 400', @TestContentLengthRequestExtraBytesAfterCloseRejected);
  T.Test('Content-Length keep-alive garbage tail -> follow-up 400', @TestContentLengthKeepAliveGarbageTailBecomesFollowUp400);
  T.Test('Content-Length keep-alive truncated follow-up request line -> follow-up 400',
    @TestContentLengthKeepAliveTruncatedFollowUpRequestLineBecomesFollowUp400);
  T.Test('Content-Length keep-alive partial follow-up request line can complete later',
    @TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater);
  T.Test('Content-Length keep-alive partial follow-up headers can complete later',
    @TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater);
  T.Test('Content-Length keep-alive truncated follow-up headers -> follow-up 400',
    @TestContentLengthKeepAliveTruncatedFollowUpHeadersBecomesFollowUp400);
  T.Test('Query parameters', @TestQueryParam);
  T.Test('Request-target URL materialization', @TestRequestTargetUrlMaterialization);
  T.Test('RemoteAddr is 127.0.0.1', @TestRemoteAddr);
  T.Test('Concurrent stress 10x100', @TestConcurrentStress);
  T.Test('Header field over MaxHeaderSize -> explicit 431',
    @TestHeaderFieldOverMaxHeaderSizeRejected);
  T.Test('Request-target over MaxHeaderSize -> 431',
    @TestRequestTargetOverMaxHeaderSizeRejected);
  T.Test('MaxBodySize enforcement -> 413', @TestMaxBodySize);
  T.Test('Content-Length request truncated at EOF -> 400', @TestContentLengthRequestTruncatedAtEof);
  T.Test('Informational response allows later final response',
    @TestInformationalResponseAllowsFinalResponse);
  T.Test('HEAD response preserves explicit content-length without body bytes',
    @TestHeadResponsePreservesContentLengthWithoutBodyBytes);
  T.Test('Hijack keeps connection open for handler owner', @TestHijackLeavesConnectionOpenForHandlerOwner);
  T.Test('Hijack exception does not write 500 or close handler connection',
    @TestHijackExceptionDoesNotWrite500OrCloseHandlerConnection);
  T.Test('Server options builder', @TestServerOptionsBuilder);
  T.Test('Server options Default vs Production timeouts',
    @TestServerOptionsDefaultAndProductionTimeouts);
  T.Test('Max requests per connection', @TestMaxRequestsPerConnection);
  T.Test('H1 write/backpressure contract source locks',
    @TestH1WriteBackpressureContractSource);
  T.Test('H1 outbound buffer reuse source contract',
    @TestH1OutboundBufferReuseSourceContract);
  T.Test('H1 fast path fixed-body source contract',
    @TestH1FastPathFixedBodySourceContract);
  T.Test('Live POST fixed body on epoll (S2-2)',
    @TestLivePostFixedBodyOnEpoll);
  T.Test('H1 poll-driven mid-request timeout queues best-effort 408 (R11)',
    @TestH1PollDrivenMidRequestTimeoutWritesBestEffort408);
  T.Test('Threaded mid-request read timeout answers 408 + sink (R11)',
    @TestReadAbort408OnThreadedMidRequestTimeout);
  T.Test('Idle keep-alive timeout stays silent without sink (R11)',
    @TestIdleKeepAliveTimeoutStaysSilent);
{$IFDEF NEXTPAS_LINUX}
  T.Test('Epoll mid-request read timeout answers 408 + sink (R11)',
    @TestLiveReadAbort408OnEpollMidRequestTimeout);
{$ENDIF}
  if not T.Run then Halt(1);
end.
