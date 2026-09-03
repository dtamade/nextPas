unit nextpas.core.platform.sendfile.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.socket.base,
  nextpas.core.platform.files.base;

const
  { 零拷贝块与 `io.base:IO_COPY_BUF_SIZE` 单源对齐 (32K=8*4K)；`Move` 单源 `bytes.ops` }
  PLATFORM_SENDFILE_CHUNK = 32768;
  { sendfile 不可用时的哨兵 }
  PLATFORM_SENDFILE_UNSUPPORTED = -1;

type
  ISendfileFileHandle = interface
    ['{7A8E9F3C-5B4A-4E2D-9C1F-3D2E1F0A9B8C}']
    function GetFileHandle: TPlatformFileHandle;
  end;

  ISendfileSocketHandle = interface
    ['{8B9F2A1D-4C3E-4F7A-9E1D-2A3B4C5D6E7F}']
    function GetSocketHandle: TPlatformSocket;
  end;

implementation

end.
