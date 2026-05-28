unit nextpas.core.platform.files;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.files.base;

function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
function platform_file_close(var AHandle: TPlatformFileHandle): Int32;
function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesRead: PtrUInt): Int32;
function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesWritten: PtrUInt): Int32;
function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64;
  AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32;
function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;
function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_UNIX}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
var
  LFlags: Int32;
begin
  case AMode of
    fomReadOnly:  LFlags := 0;
    fomWriteOnly: LFlags := 1;
    fomReadWrite: LFlags := 2;
  end;
  case ACreate of
    fcmOpenExisting:    ;
    fcmCreateAlways:    LFlags := LFlags or $40 or $200;
    fcmCreateNew:       LFlags := LFlags or $40 or $80;
    fcmOpenOrCreate:    LFlags := LFlags or $40;
    fcmTruncateExisting: LFlags := LFlags or $200;
  end;
  AHandle.Value := open(APath, LFlags, 438);
  if AHandle.Value < 0 then
    Result := -1
  else
    Result := 0;
end;

function platform_file_close(var AHandle: TPlatformFileHandle): Int32;
begin
  if AHandle.Value < 0 then
    Exit(-1);
  if close(AHandle.Value) = 0 then
    Result := 0
  else
    Result := -1;
  AHandle.Value := -1;
end;

function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesRead: PtrUInt): Int32;
var
  LResult: PtrInt;
begin
  LResult := read(AHandle.Value, ABuf, ACount);
  if LResult < 0 then
  begin
    ABytesRead := 0;
    Result := -1;
  end
  else
  begin
    ABytesRead := PtrUInt(LResult);
    Result := 0;
  end;
end;

function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesWritten: PtrUInt): Int32;
var
  LResult: PtrInt;
begin
  LResult := write(AHandle.Value, ABuf, ACount);
  if LResult < 0 then
  begin
    ABytesWritten := 0;
    Result := -1;
  end
  else
  begin
    ABytesWritten := PtrUInt(LResult);
    Result := 0;
  end;
end;

function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64;
  AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32;
var
  LWhence: Int32;
  LResult: Int64;
begin
  case AOrigin of
    fsoBegin:   LWhence := 0;
    fsoCurrent: LWhence := 1;
    fsoEnd:     LWhence := 2;
  end;
  LResult := lseek(AHandle.Value, AOffset, LWhence);
  if LResult < 0 then
  begin
    ANewPos := -1;
    Result := -1;
  end
  else
  begin
    ANewPos := LResult;
    Result := 0;
  end;
end;

function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;
begin
  if fsync(AHandle.Value) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32;
begin
  if ftruncate(AHandle.Value, ASize) = 0 then
    Result := 0
  else
    Result := -1;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
var
  LAccess, LDisposition: DWORD;
begin
  case AMode of
    fomReadOnly:  LAccess := GENERIC_READ;
    fomWriteOnly: LAccess := GENERIC_WRITE;
    fomReadWrite: LAccess := GENERIC_READ or GENERIC_WRITE;
  end;
  case ACreate of
    fcmOpenExisting:     LDisposition := OPEN_EXISTING;
    fcmCreateAlways:     LDisposition := CREATE_ALWAYS;
    fcmCreateNew:        LDisposition := DWORD(1);
    fcmOpenOrCreate:     LDisposition := OPEN_ALWAYS;
    fcmTruncateExisting: LDisposition := TRUNCATE_EXISTING;
  end;
  AHandle.Value := CreateFileA(APath, LAccess, FILE_SHARE_READ, nil, LDisposition, $80, nil);
  if AHandle.Value = HANDLE(PtrInt(-1)) then
    Result := -1
  else
    Result := 0;
end;

function platform_file_close(var AHandle: TPlatformFileHandle): Int32;
begin
  if AHandle.Value = HANDLE(PtrInt(-1)) then
    Exit(-1);
  if CloseHandle(AHandle.Value) then
    Result := 0
  else
    Result := -1;
  AHandle.Value := HANDLE(PtrInt(-1));
end;

function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesRead: PtrUInt): Int32;
var
  LRead: DWORD;
begin
  LRead := 0;
  if ReadFile(AHandle.Value, ABuf, DWORD(ACount), @LRead, nil) then
  begin
    ABytesRead := LRead;
    Result := 0;
  end
  else
  begin
    ABytesRead := 0;
    Result := -1;
  end;
end;

function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ACount: PtrUInt; out ABytesWritten: PtrUInt): Int32;
var
  LWritten: DWORD;
begin
  LWritten := 0;
  if WriteFile(AHandle.Value, ABuf, DWORD(ACount), @LWritten, nil) then
  begin
    ABytesWritten := LWritten;
    Result := 0;
  end
  else
  begin
    ABytesWritten := 0;
    Result := -1;
  end;
end;

function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64;
  AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32;
var
  LMethod: DWORD;
begin
  case AOrigin of
    fsoBegin:   LMethod := FILE_BEGIN;
    fsoCurrent: LMethod := FILE_CURRENT;
    fsoEnd:     LMethod := FILE_END;
  end;
  if SetFilePointerEx(AHandle.Value, AOffset, @ANewPos, LMethod) then
    Result := 0
  else
  begin
    ANewPos := -1;
    Result := -1;
  end;
end;

function platform_file_sync(const AHandle: TPlatformFileHandle): Int32;
begin
  if FlushFileBuffers(AHandle.Value) then
    Result := 0
  else
    Result := -1;
end;

function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32;
var
  LNewPos: Int64;
begin
  if not SetFilePointerEx(AHandle.Value, ASize, @LNewPos, FILE_BEGIN) then
    Exit(-1);
  if SetEndOfFile(AHandle.Value) then
    Result := 0
  else
    Result := -1;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode; ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32; begin Result := -1; end;
function platform_file_close(var AHandle: TPlatformFileHandle): Int32; begin Result := -1; end;
function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer; ACount: PtrUInt; out ABytesRead: PtrUInt): Int32; begin ABytesRead := 0; Result := -1; end;
function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer; ACount: PtrUInt; out ABytesWritten: PtrUInt): Int32; begin ABytesWritten := 0; Result := -1; end;
function platform_file_seek(const AHandle: TPlatformFileHandle; AOffset: Int64; AOrigin: TPlatformFileSeekOrigin; out ANewPos: Int64): Int32; begin ANewPos := -1; Result := -1; end;
function platform_file_sync(const AHandle: TPlatformFileHandle): Int32; begin Result := -1; end;
function platform_file_truncate(const AHandle: TPlatformFileHandle; ASize: Int64): Int32; begin Result := -1; end;
{$ENDIF}

end.
