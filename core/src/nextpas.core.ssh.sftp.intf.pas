unit nextpas.core.ssh.sftp.intf;

{** nextpas.core.ssh.sftp.intf - SFTP 缝隙接口（四件套 intf）。
 *
 * 拥有 ISftpWire（单包收发）与 ISshFileSystem（文件操作面）接口契约；
 * 生产实现由 wire/conn/fs 子模块提供，测试可注入脚本化假线材。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.sftp.base;

type
  { SFTP 线材缝隙：一个完整 SFTP 包（不含长度前缀）的收发 }
  ISftpWire = interface
    ['{9C1E6E10-4A11-4F72-9D30-5B0000000001}']
    procedure Send(const APacket: TBytes);
    function Recv(ATimeoutMs: Integer): TBytes;
  end;

  { 文件系统门面 }
  ISshFileSystem = interface
    ['{9C1E6E10-4A11-4F72-9D30-5B0000000002}']
    function RealPath(const APath: string): string;
    function Stat(const APath: string): TSftpAttrs;
    function Lstat(const APath: string): TSftpAttrs;
    function ListDir(const APath: string): TSftpDirEntryArray;
    function ReadFile(const APath: string): TBytes;
    procedure WriteFile(const APath: string; const AData: TBytes);
    procedure Remove(const APath: string);
    procedure Mkdir(const APath: string);
    procedure Rmdir(const APath: string);
    procedure Rename(const AOldPath, ANewPath: string);
  end;

implementation

end.
