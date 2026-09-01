unit nextpas.core.ssh.sftp.base;

{** nextpas.core.ssh.sftp.base - SFTP 共享基座（单源 STATUS 命名）。
 *
 * 同步 sftp.pas 与异步 sftp.async.pas 曾各持一份 SftpStatusName，命名漂移风险。
 * 本单元为单源，复用 bytes 语义仅文本映射，无堆分配热路径。 *}

{$I nextpas.core.settings.inc}

interface

function SftpStatusName(ACode: UInt32): string; inline;

implementation

uses
  nextpas.core.text.conv;

function SftpStatusName(ACode: UInt32): string; inline;
begin
  case ACode of
    0: Result := 'ok';
    1: Result := 'eof';
    2: Result := 'no-such-file';
    3: Result := 'permission-denied';
    4: Result := 'failure';
    5: Result := 'bad-message';
    8: Result := 'op-unsupported';
  else
    Result := 'status-' + IntToStr(ACode);
  end;
end;

end.
