unit nextpas.core.platform.files.base;

{$I nextpas.core.settings.inc}

interface

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base;
{$ELSE}
uses
  nextpas.core.platform.posix.base;
{$ENDIF}

type
  {** @desc 文件句柄（平台无关封装） *}
  TPlatformFileHandle = record
  {$IFDEF NEXTPAS_WINDOWS}
    Value: HANDLE;
  {$ELSE}
    Value: cint;
  {$ENDIF}
  end;

  {** @desc 文件类型枚举 *}
  TPlatformFileType = (
    ftRegular,
    ftDirectory,
    ftSymlink,
    ftCharDevice,
    ftBlockDevice,
    ftFifo,
    ftSocket,
    ftUnknown
  );

  {** @desc 文件状态信息 *}
  TPlatformFileStat = record
    Size: Int64;
    FileType: TPlatformFileType;
    Mode: UInt32;
    ModTime: Int64;
    AccessTime: Int64;
    { POSIX CreateTime maps st_ctime, which is status-change time. }
    CreateTime: Int64;
    Uid: UInt32;
    Gid: UInt32;
    NLink: UInt32;
    Dev: UInt64;
    Ino: UInt64;
  end;

  {** @desc 文件打开模式 *}
  TPlatformFileOpenMode = (
    fomReadOnly,
    fomWriteOnly,
    fomReadWrite
  );

  {** @desc 文件创建模式 *}
  TPlatformFileCreateMode = (
    fcmOpenExisting,
    fcmCreateAlways,
    fcmCreateNew,
    fcmOpenOrCreate,
    fcmTruncateExisting
  );

  {** @desc 文件定位原点 *}
  TPlatformFileSeekOrigin = (
    fsoBegin,
    fsoCurrent,
    fsoEnd
  );

  {** @desc 目录条目 *}
  TPlatformDirEntry = record
    Name: array[0..255] of AnsiChar;
    NameLen: Int32;
    FileType: TPlatformFileType;
    Ino: UInt64;
  end;

  {** @desc 目录遍历句柄（平台无关封装） *}
  TPlatformDirHandle = record
  {$IFDEF NEXTPAS_WINDOWS}
    FindHandle: HANDLE;
    FindData: WIN32_FIND_DATAW;
    First: Boolean;
    Finished: Boolean;
  {$ELSE}
    Fd: cint;
    Buf: array[0..4095] of Byte;
    Pos: Int32;
    Len: Int32;
  {$ENDIF}
  end;

const
  {** @desc 无效文件句柄 *}
  PLATFORM_FILE_INVALID_HANDLE: TPlatformFileHandle = (
  {$IFDEF NEXTPAS_WINDOWS}
    Value: HANDLE(PtrInt(-1))
  {$ELSE}
    Value: -1
  {$ENDIF}
  );

  { POSIX d_type constants for directory entries }
  {** @desc FIFO 类型 *}
  PLATFORM_DT_FIFO = 1;
  {** @desc 字符设备类型 *}
  PLATFORM_DT_CHR  = 2;
  {** @desc 目录类型 *}
  PLATFORM_DT_DIR  = 4;
  {** @desc 块设备类型 *}
  PLATFORM_DT_BLK  = 6;
  {** @desc 普通文件类型 *}
  PLATFORM_DT_REG  = 8;
  {** @desc 符号链接类型 *}
  PLATFORM_DT_LNK  = 10;
  {** @desc 套接字类型 *}
  PLATFORM_DT_SOCK = 12;

implementation

end.
