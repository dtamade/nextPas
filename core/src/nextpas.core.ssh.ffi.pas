unit nextpas.core.ssh.ffi;

{** nextpas.core.ssh - 网络 FFI 外壳兼容别名（已收敛至 ssh.net.ffi 单源）。
 *  历史遗留单元，现仅为 re-export shim；新代码应直接 uses
 *  nextpas.core.ssh.net.ffi。单源约束：唯一拉取 nextpas.core.net 的单元
 *  为 ssh.net.ffi，本单元不再直连 net。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.ssh.intf,
  nextpas.core.ssh.net.ffi;

type
  TSshDefaultDialer = nextpas.core.ssh.net.ffi.TSshDefaultDialer;

function SshDefaultDialer: ISshDialer; inline;
function SshDefaultAgentDialer: ISshAgentDialer; inline;

implementation

function SshDefaultDialer: ISshDialer; inline;
begin
  Result := nextpas.core.ssh.net.ffi.SshDefaultDialer;
end;

function SshDefaultAgentDialer: ISshAgentDialer; inline;
begin
  Result := nextpas.core.ssh.net.ffi.SshDefaultAgentDialer;
end;

end.
