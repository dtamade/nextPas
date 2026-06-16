unit nextpas.core.fs.errors;

{$I nextpas.core.settings.inc}

interface

{ Translates a platform error code (POSIX errno or Windows GetLastError) into a
  typed nextpas exception and raises it. AOp/APath provide context for the
  message. Never returns when ACode <> 0; a no-op when ACode = 0. }
procedure RaiseFsError(const ACode: Int32; const AOp, APath: string);

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.errors
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
  ERR_DIRECTORY       = 267;
  ERR_ALREADY_EXISTS  = 183;
  ERR_DIR_NOT_EMPTY   = Int32(ERROR_DIR_NOT_EMPTY);
{$ELSE}
const
  EPERM_  = 1;
  ENOENT_ = 2;
  EACCES_ = 13;
  EEXIST_ = 17;
  ENOTDIR_ = 20;
  EISDIR_ = 21;
  EINVAL_ = 22;
{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  ENOTEMPTY_ = 66;
{$ELSE}
  ENOTEMPTY_ = 39;
{$ENDIF}
{$ENDIF}

procedure RaiseFsError(const ACode: Int32; const AOp, APath: string);
var
  LMsg: string;
begin
  if ACode = 0 then
    Exit;
  LMsg := AOp + ' failed (' + IntToStr(ACode) + '): ' + APath;
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
  else
    raise EIOError.Create(LMsg);
  end;
{$ENDIF}
end;

end.
