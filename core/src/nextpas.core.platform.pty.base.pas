unit nextpas.core.platform.pty.base;
{**
 * @desc PTY 基础类型定义。
 *}

{$I nextpas.core.settings.inc}

interface

type
  TPlatformPtySize = record
    FCols: UInt16;
    FRows: UInt16;
    FXPixel: UInt16;
    FYPixel: UInt16;
  end;

  TPlatformPty = record
  {$IFDEF NEXTPAS_UNIX}
    FMasterFd: Int32;
    FSlaveFd: Int32;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
    FConPty: Pointer;
    FPipeIn: PtrUInt;
    FPipeOut: PtrUInt;
  {$ENDIF}
  end;

  TPlatformPtySpawnStage = (
    ptssNone,
    ptssPipe,
    ptssFork,
    ptssSetsid,
    ptssOpenSlave,
    ptssTiocsctty,
    ptssChdir,
    ptssDup,
    ptssExec
  );

implementation

end.
