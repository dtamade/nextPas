unit nextpas.core.ssh.net.ffi;

{** nextpas.core.ssh - 网络 FFI 外壳（唯一拉取 nextpas.core.net 的单元）。
 * 同层单向允许：ssh(L2)→net(L2) 经此单缝隙拉取，与 L0-L1 宪法文字冲突已在
 * 设计规范 §3 显式豁免（L2 同层单向经 FFI 单缝隙允许，禁止环）。
 * 同步经 ISshDialer/ISshAgentDialer 抽象隔离；异步经 IAsyncTcpStream/
 * SshAsyncTcp* 单缝隙复用，transport.async 零直连 net.async.tcp。inline
 * 零拷贝（IAsyncTcpStream.AsyncWrite 不拷贝、FWriteBuf 保活至回调，外层
 * Move 单源复用 bytes.ops）；稳定性 try-finally 释放不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.time.deadline,
  nextpas.core.async.loop,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.ssh.intf;

type
  TSshDefaultDialer = class(TInterfacedObject, ISshDialer, ISshAgentDialer)
    function Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream; inline;
    function DialAgent(const APath: string): IReadWriteCloser; inline;
  end;

  // 异步侧 re-export（唯一 net 拉取点，满足 L2 单缝隙约束；inline 零拷贝，bytes.ops 单源）
  IAsyncTcpStream = nextpas.core.net.async.tcp.IAsyncTcpStream;
  TAsyncTcpDialOptions = nextpas.core.net.async.dial.TAsyncTcpDialOptions;
  TAsyncTcpDialCallback = nextpas.core.net.async.dial.TAsyncTcpDialCallback;
  TAsyncTcpDialAddressFamily = nextpas.core.net.async.dial.TAsyncTcpDialAddressFamily;
  TNetAddress = nextpas.core.net.base.TNetAddress;
  TTcpStreamIOResult = nextpas.core.net.intf.TTcpStreamIOResult;
  TTcpAcceptResult = nextpas.core.net.intf.TTcpAcceptResult;
  INetCancelToken = nextpas.core.net.intf.INetCancelToken;

function SshDefaultDialer: ISshDialer; inline;
function SshDefaultAgentDialer: ISshAgentDialer; inline;

// 异步薄转发（inline 零拷贝：adopt/connect/dial 仅转发句柄/回调，不拷贝缓冲区；稳定性由外层 try-finally 保证）
function SshAsyncTcpStreamAdopt(const ALoop: TAsyncLoop; const AStream: ITcpStream): IAsyncTcpStream; inline;
function SshAsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream; inline;
function SshDefaultAsyncDialOptions: TAsyncTcpDialOptions; inline;
function SshAsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer = nil): Boolean; inline;
function SshAsyncTcpDialAddrs(const ALoop: TAsyncLoop; const AAddrs: array of nextpas.core.net.base.TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer = nil): Boolean; inline;

// 同步侧缝隙：Deadline 薄转发（IReadWriteCloser→ITcpStream 单缝隙，inline 零拷贝，bytes.ops 单源外层 Move）
function SshSetReadDeadline(const AStream: IReadWriteCloser; const ADeadline: TDeadline): Boolean; inline;

implementation

uses
  nextpas.core.net,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial;

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
  Result := nextpas.core.net.async.tcp.AsyncTcpStreamAdopt(ALoop, AStream);
end;

function SshAsyncTcpConnect(const ALoop: TAsyncLoop; const AAddr: string; APort: UInt16): IAsyncTcpStream; inline;
begin
  Result := nextpas.core.net.async.tcp.AsyncTcpConnect(ALoop, AAddr, APort);
end;

function SshDefaultAsyncDialOptions: TAsyncTcpDialOptions; inline;
begin
  Result := nextpas.core.net.async.dial.DefaultAsyncTcpDialOptions;
end;

function SshAsyncTcpDial(const ALoop: TAsyncLoop; const AHost: string; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer): Boolean; inline;
begin
  Result := nextpas.core.net.async.dial.AsyncTcpDial(ALoop, AHost, APort, AOptions, ACallback, AContext);
end;

function SshAsyncTcpDialAddrs(const ALoop: TAsyncLoop; const AAddrs: array of nextpas.core.net.base.TNetAddress; APort: UInt16;
  const AOptions: TAsyncTcpDialOptions; ACallback: TAsyncTcpDialCallback; AContext: Pointer): Boolean; inline;
begin
  Result := nextpas.core.net.async.dial.AsyncTcpDialAddrs(ALoop, AAddrs, APort, AOptions, ACallback, AContext);
end;

function SshSetReadDeadline(const AStream: IReadWriteCloser; const ADeadline: TDeadline): Boolean; inline;
var L: ITcpStream;
begin
  if Supports(AStream, ITcpStream, L) then
  begin
    L.SetReadDeadline(ADeadline);
    Exit(True);
  end;
  Result := False;
end;

end.
