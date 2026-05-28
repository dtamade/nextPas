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

const
  PLATFORM_FILE_INVALID_HANDLE: TPlatformFileHandle = (
  {$IFDEF NEXTPAS_WINDOWS}
    Value: HANDLE(PtrInt(-1))
  {$ELSE}
    Value: -1
  {$ENDIF}
  );

implementation

end.
