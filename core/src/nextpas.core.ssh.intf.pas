unit nextpas.core.ssh.intf;

{** nextpas.core.ssh - 连接缝隙接口（IDialer 注入）。
 * 隔离 L2 net 直连，使 session/agent 仅依赖 io.intf + intf，net 经 ffi 注入。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf;

type
  ISshDialer = interface
    ['{A1B2C3D4-E5F6-47A0-9B1C-123456789001}']
    function Dial(const AHost: string; APort: Word; ATimeoutMs: Int64): ITcpStream;
  end;

  ISshAgentDialer = interface
    ['{A1B2C3D4-E5F6-47A0-9B1C-123456789002}']
    function DialAgent(const APath: string): IReadWriteCloser;
  end;

implementation

end.
