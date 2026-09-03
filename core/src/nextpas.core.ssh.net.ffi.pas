unit nextpas.core.ssh.net.ffi;

{** nextpas.core.ssh - 网络 FFI 外壳（唯一拉取 nextpas.core.net 的单元）。
 * 单缝隙极简：interface 仅 uses nextpas.core.net 顶层门面，impl 零复用净空，
 * 与 L0-L3 宪法文字冲突已在设计规范 §3 显式豁免（L2 同层单向经 FFI 单缝隙允许，禁止环）。
 * 同步经 ISshDialer/ISshAgentDialer 抽象隔离；异步经 IAsyncTcpStream/
 * SshAsyncTcp* 单缝隙复用，transport.async 零直连 net.async.tcp/dial。inline
 * 零拷贝（IAsyncTcpStream.AsyncWrite 不拷贝、FWriteBuf 保活至回调，外层
 * Move 单源复用 bytes.ops）；稳定性 try-finally 释放不丢。反哺：net 缺口
 * AsyncTcpStreamAdopt/AsyncTcpConnect 已补至 nextpas.core.net(.async) 单源。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.time.deadline,
  nextpas.core.async.loop,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.ssh.intf;

type
  TSshDefaultDialer = class(TInterfacedObject, ISshDialer, ISshAgentDialer)
    function Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream; inline;
    function DialAgent(const APath: string): IReadWriteCloser; inline;
  end;

  // 异步侧 re-export（唯一 net 拉取点，经 net 顶层门面单缝隙聚合；inline 零拷贝，bytes.ops 单源）
  IAsyncTcpStream = nextpas.core.net.IAsyncTcpStream;
  TAsyncTcpDialOptions = nextpas.core.net.TAsyncTcpDialOptions;
  TAsyncTcpDialCallback = nextpas.core.net.TAsyncTcpDialCallback;
  TAsyncTcpDialAddressFamily = nextpas.core.net.TAsyncTcpDialAddressFamily;
  TNetAddress = nextpas.core.net.TNetAddress;
  TTcpStreamIOResult = nextpas.core.net.TTcpStreamIOResult;
  TTcpAcceptResult = nextpas.core.net.TTcpAcceptResult;
  INetCancelToken = nextpas.core.net.INetCancelToken;

const
  { IOResult 枚举值单缝隙 re-export：type 别名不携带枚举成员，
    proxyjump.async 等经此取值而不直连 net.intf。 }
  tsiorOk = nextpas.core.net.intf.tsiorOk;
  tsiorWouldBlock = nextpas.core.net.intf.tsiorWouldBlock;
  tsiorClosed = nextpas.core.net.intf.tsiorClosed;
  tsiorTimeout = nextpas.core.net.intf.tsiorTimeout;

function SshDefaultDialer: ISshDialer; inline;
function SshDefaultAgentDialer: ISshAgentDialer; inline;

// 异步薄转发（inline 零拷贝：adopt/connect/dial 仅转发句柄/回调，不拷贝缓冲区；稳定性由外层 try-finally 保证）
function SshAsyncTcpStreamAdopt(const ALoop: TAsyncLoop; const AStream: ITcpStream): IAsyncTcpStream; inline;
function SshAsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream; inline;
function SshDefaultAsyncDialOptions: TAsyncTcpDialOptions; inline;
function SshAsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer = nil): Boolean; inline;
function SshAsyncTcpDialAddrs(const ALoop: TAsyncLoop; const AAddrs: array of TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer = nil): Boolean; inline;

// 同步侧缝隙：Deadline 薄转发（IReadWriteCloser→ITcpStream 单缝隙，inline 零拷贝，bytes.ops 单源外层 Move）
function SshSetReadDeadline(const AStream: IReadWriteCloser; const ADeadline: TDeadline): Boolean; inline;

implementation

function TSshDefaultDialer.Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream; inline;
begin
  Result := TcpConnect(AHost, APort, ATimeoutMs);
end;

function TSshDefaultDialer.DialAgent(const APath: string): IReadWriteCloser; inline;
begin
  Result := UnixConnect(APath);
end;

function SshDefaultDialer: ISshDialer; inline;
begin
  Result := TSshDefaultDialer.Create;
end;

function SshDefaultAgentDialer: ISshAgentDialer; inline;
begin
  Result := TSshDefaultDialer.Create;
end;

function SshAsyncTcpStreamAdopt(const ALoop: TAsyncLoop; const AStream: ITcpStream): IAsyncTcpStream; inline;
begin
  Result := nextpas.core.net.AsyncTcpStreamAdopt(ALoop, AStream);
end;

function SshAsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream; inline;
begin
  Result := nextpas.core.net.AsyncTcpConnect(ALoop, AAddr, APort);
end;

function SshDefaultAsyncDialOptions: TAsyncTcpDialOptions; inline;
begin
  Result := nextpas.core.net.DefaultAsyncTcpDialOptions;
end;

function SshAsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer): Boolean; inline;
begin
  Result := nextpas.core.net.AsyncTcpDial(ALoop, AHost, APort, AOptions, ACallback, AContext);
end;

function SshAsyncTcpDialAddrs(const ALoop: TAsyncLoop; const AAddrs: array of TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer): Boolean; inline;
begin
  Result := nextpas.core.net.AsyncTcpDialAddrs(ALoop, AAddrs, APort, AOptions, ACallback, AContext);
end;

function SshSetReadDeadline(const AStream: IReadWriteCloser; const ADeadline: TDeadline): Boolean; inline;
var L: ITcpStream;
begin
  if (AStream <> nil) and (AStream.QueryInterface(ITcpStream, L) = S_OK) then
  begin
    L.SetReadDeadline(ADeadline);
    Exit(True);
  end;
  Result := False;
end;

end.
