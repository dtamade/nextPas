unit nextpas.core.ssh.net.ffi;

{** nextpas.core.ssh - 网络 FFI 外壳（唯一拉取 nextpas.core.net 的单元）。
 * 同层单向允许：ssh(L2)→net(L2) 经此单缝隙拉取，与 L0-L1 宪法文字冲突已在
 * 设计规范 §3 显式豁免（L2 同层单向经 FFI 单缝隙允许，禁止环）。
 * 同步经 ISshDialer/ISshAgentDialer 抽象隔离，零直连 net.base/async；async
 * 侧由 transport.async/session.async 按需直连 net.async 能力，peer 隔离经
 * ISshDialer 缝隙，零多 peer 直连 ffi。inline 零拷贝，bytes.ops 单源由外层
 * Move 保证；稳定性 try-finally 释放不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.ssh.intf;

type
  TSshDefaultDialer = class(TInterfacedObject, ISshDialer, ISshAgentDialer)
    function Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream; inline;
    function DialAgent(const APath: string): IReadWriteCloser; inline;
  end;

function SshDefaultDialer: ISshDialer; inline;
function SshDefaultAgentDialer: ISshAgentDialer; inline;

implementation

uses
  nextpas.core.net;

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

end.
