unit nextpas.core.fs.errors;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

{ Translates a platform error code (POSIX errno or Windows GetLastError) into a
  typed nextpas exception and raises it. AOp/APath provide context for the
  message. Never returns when ACode <> 0; a no-op when ACode = 0. }
procedure RaiseFsError(const ACode: Int32; const AOp, APath: string);

{ True when a non-blocking lock attempt failed because the lock is held. }
function FsIsLockBusy(const ACode: Int32): Boolean;

{ Warn on close failure; single source for close-failure observability via log.intf (NullLogger zero-alloc inline), never raises. }
procedure FsWarnCloseFailed(const APath: string; const E: Exception); inline; overload;
procedure FsWarnCloseFailed(const AOp, APath: string; const E: Exception); inline; overload;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.log.intf,
  nextpas.core.platform.error
{$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base
{$ENDIF}
  ;

{$IFDEF NEXTPAS_WINDOWS}
const
  ERR_FILE_NOT_FOUND  = 2;
  ERR_PATH_NOT_FOUND  = 3;
  ERR_ACCESS_DENIED   = 5;
  ERR_NOT_READY       = 21;
  ERR_FILE_EXISTS     = 80;
  ERR_DISK_FULL       = 112;
  ERR_DIRECTORY       = 267;
  ERR_ALREADY_EXISTS  = 183;
  ERR_DIR_NOT_EMPTY   = Int32(ERROR_DIR_NOT_EMPTY);
  ERR_NOT_ENOUGH_MEMORY = 8;
{$ELSE}
const
  EPERM_  = 1;
  ENOENT_ = 2;
  ENOMEM_ = 12;
  EACCES_ = 13;
  EEXIST_ = 17;
  ENOTDIR_ = 20;
  EISDIR_ = 21;
  EINVAL_ = 22;
  ENOSPC_ = 28;
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  ENOTEMPTY_ = 66;
{$ELSE}
  ENOTEMPTY_ = 39;
{$ENDIF}
{$ENDIF}

function FsIsLockBusy(const ACode: Int32): Boolean;
begin
  if ACode = 0 then
    Exit(False);
  { POSIX: flock LOCK_NB → EAGAIN/EWOULDBLOCK; some paths EBUSY. }
  if (ACode = PLATFORM_ERR_AGAIN) or (ACode = PLATFORM_ERR_BUSY) then
    Exit(True);
{$IFDEF NEXTPAS_WINDOWS}
  { ERROR_LOCK_VIOLATION=33, ERROR_BUSY=170, ERROR_LOCK_FAILED=167 }
  if (ACode = 33) or (ACode = 170) or (ACode = 167) then
    Exit(True);
{$ENDIF}
  Result := False;
end;

procedure RaiseFsError(const ACode: Int32; const AOp, APath: string);
var
  LMsg: string;
  LBuf: array[0..255] of AnsiChar;
begin
  if ACode = 0 then
    Exit;
  LMsg := AOp + ' failed (' + IntToStr(ACode) + '): ' + APath;
  if platform_error_message(ACode, @LBuf[0], SizeOf(LBuf)) > 0 then
    LMsg := LMsg + ' — ' + string(PAnsiChar(@LBuf[0]));
{$IFDEF NEXTPAS_WINDOWS}
  case ACode of
    ERR_FILE_NOT_FOUND, ERR_PATH_NOT_FOUND:
      raise ENotFoundError.Create(LMsg);
    ERR_ACCESS_DENIED:
      raise EPermissionError.Create(LMsg);
    ERR_FILE_EXISTS, ERR_ALREADY_EXISTS:
      raise EAlreadyExistsError.Create(LMsg);
    ERR_DIRECTORY, ERR_DIR_NOT_EMPTY:
      raise EInvalidOperationError.Create(LMsg);
    ERR_DISK_FULL, ERR_NOT_ENOUGH_MEMORY:
      raise EResourceExhaustedError.Create(LMsg);
  else
    raise EIOError.Create(LMsg);
  end;
{$ELSE}
  case ACode of
    ENOENT_:
      raise ENotFoundError.Create(LMsg);
    EACCES_, EPERM_:
      raise EPermissionError.Create(LMsg);
    EEXIST_:
      raise EAlreadyExistsError.Create(LMsg);
    EINVAL_, EISDIR_, ENOTDIR_, ENOTEMPTY_:
      raise EInvalidOperationError.Create(LMsg);
    ENOSPC_, ENOMEM_:
      raise EResourceExhaustedError.Create(LMsg);
  else
    raise EIOError.Create(LMsg);
  end;
{$ENDIF}
end;

procedure FsWarnCloseFailed(const APath: string; const E: Exception); inline;
begin
  // single source close Warn via log.intf NullLogger zero-alloc inline, never raises
  NullLogger.Warn('close failed for ' + APath + ': ' + E.Message);
end;

procedure FsWarnCloseFailed(const AOp, APath: string; const E: Exception); inline;
begin
  // single source close Warn via log.intf AOp prefix, inline thin-forward, never raises
  if AOp <> '' then
    NullLogger.Warn(AOp + ': close failed for ' + APath + ': ' + E.Message)
  else
    FsWarnCloseFailed(APath, E);
end;

end.
