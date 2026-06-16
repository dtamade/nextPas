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
  TPlatformFileHandle = record
  {$IFDEF NEXTPAS_WINDOWS}
    Value: HANDLE;
  {$ELSE}
    Value: cint;
  {$ENDIF}
  end;

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

  TPlatformFileStat = record
    Size: Int64;
    FileType: TPlatformFileType;
    Mode: UInt32;
    ModTime: Int64;
    AccessTime: Int64;
    CreateTime: Int64;
    Uid: UInt32;
    Gid: UInt32;
    NLink: UInt32;
    Dev: UInt64;
    Ino: UInt64;
  end;

  TPlatformFileOpenMode = (
    fomReadOnly,
    fomWriteOnly,
    fomReadWrite
  );

  TPlatformFileCreateMode = (
    fcmOpenExisting,
    fcmCreateAlways,
    fcmCreateNew,
    fcmOpenOrCreate,
    fcmTruncateExisting
  );

  TPlatformFileSeekOrigin = (
    fsoBegin,
    fsoCurrent,
    fsoEnd
  );

  TPlatformDirEntry = record
    Name: array[0..255] of AnsiChar;
    NameLen: Int32;
    FileType: TPlatformFileType;
    Ino: UInt64;
  end;

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
  PLATFORM_FILE_INVALID_HANDLE: TPlatformFileHandle = (
  {$IFDEF NEXTPAS_WINDOWS}
    Value: HANDLE(PtrInt(-1))
  {$ELSE}
    Value: -1
  {$ENDIF}
  );

  { POSIX d_type constants for directory entries }
  PLATFORM_DT_FIFO = 1;
  PLATFORM_DT_CHR  = 2;
  PLATFORM_DT_DIR  = 4;
  PLATFORM_DT_BLK  = 6;
  PLATFORM_DT_REG  = 8;
  PLATFORM_DT_LNK  = 10;
  PLATFORM_DT_SOCK = 12;

implementation

end.
