unit nextpas.core.fs.base;

{$I nextpas.core.settings.inc}

interface

type
  TFileMode = set of (
    fmRead,
    fmWrite,
    fmAppend,
    fmCreate,
    fmTruncate,
    fmExclusive,
    fmSync
  );

  TFilePermission = type UInt32;

  TFileType = (
    ftRegular,
    ftDirectory,
    ftSymlink,
    ftCharDevice,
    ftBlockDevice,
    ftFifo,
    ftSocket,
    ftUnknown
  );

  TFileInfo = record
    Name: string;
    Size: Int64;
    FileType: TFileType;
    Permission: TFilePermission;
    ModTime: Int64;
    AccessTime: Int64;
    CreateTime: Int64;
    IsDir: Boolean;
    IsSymlink: Boolean;
  end;

  TDirEntry = record
    Name: string;
    FileType: TFileType;
    IsDir: Boolean;
  end;

  TDirEntryArray = array of TDirEntry;

const
  PermOwnerRead  = TFilePermission($100);
  PermOwnerWrite = TFilePermission($080);
  PermOwnerExec  = TFilePermission($040);
  PermGroupRead  = TFilePermission($020);
  PermGroupWrite = TFilePermission($010);
  PermGroupExec  = TFilePermission($008);
  PermOtherRead  = TFilePermission($004);
  PermOtherWrite = TFilePermission($002);
  PermOtherExec  = TFilePermission($001);
  PermDefault    = TFilePermission($1A4);
  PermDirDefault = TFilePermission($1ED);

implementation

end.
