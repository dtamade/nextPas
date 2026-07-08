unit nextpas.core.platform.pty.base;
{**
 * @desc PTY 基础类型定义。
 *}

{$I nextpas.core.settings.inc}

interface

type
  {** @desc PTY 窗口大小 *}
  TPlatformPtySize = record
    FCols: UInt16;
    FRows: UInt16;
    FXPixel: UInt16;
    FYPixel: UInt16;
  end;

  {** @desc PTY 句柄（平台无关封装） *}
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

  {** @desc PTY 启动失败阶段枚举 *}
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
