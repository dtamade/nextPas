unit nextpas.core.net.errors;
{**
 * Go-like net error classification for async dial/IO result codes.
 * Codes may be negative (callback convention) or positive PLATFORM_ERR_*/errno.
 * Does not allocate; safe for hot paths.
 *}

{$I nextpas.core.settings.inc}

interface

type
  TNetErrorKind = (
    nekOK,
    nekCanceled,
    nekTimeout,
    nekRefused,
    nekReset,
    nekUnreachable,
    nekDNS,
    nekTemporary,
    nekInvalid,
    nekUnknown
  );

  TNetErrorClass = record
    Kind: TNetErrorKind;
    Code: Int32; { absolute value of input }
    Timeout: Boolean;
    Temporary: Boolean;
    Canceled: Boolean;
    function IsOK: Boolean;
  end;

{ Linux ECANCELED / async dial cancel convention (positive). }
const
  NET_ERR_CANCELED = 125;

function ClassifyNetError(ACode: Int32): TNetErrorClass;
function NetErrorKindName(AKind: TNetErrorKind): string;

implementation

uses
  nextpas.core.exception,
  nextpas.core.platform.error;

function TNetErrorClass.IsOK: Boolean;
begin
  Result := Kind = nekOK;
end;

function NetErrorKindName(AKind: TNetErrorKind): string;
begin
  case AKind of
    nekOK: Result := 'ok';
    nekCanceled: Result := 'canceled';
    nekTimeout: Result := 'timeout';
    nekRefused: Result := 'refused';
    nekReset: Result := 'reset';
    nekUnreachable: Result := 'unreachable';
    nekDNS: Result := 'dns';
    nekTemporary: Result := 'temporary';
    nekInvalid: Result := 'invalid';
  else
    Result := 'unknown';
  end;
end;

function ClassifyNetError(ACode: Int32): TNetErrorClass;
var
  LCode: Int32;
  LCat: TErrorCategory;
begin
  if ACode < 0 then
    LCode := -ACode
  else
    LCode := ACode;

  Result.Kind := nekUnknown;
  Result.Code := LCode;
  Result.Timeout := False;
  Result.Temporary := False;
  Result.Canceled := False;

  if LCode = 0 then
  begin
    Result.Kind := nekOK;
    Exit;
  end;

  { Async dial / loop cancel convention (Linux ECANCELED). }
  if LCode = NET_ERR_CANCELED then
  begin
    Result.Kind := nekCanceled;
    Result.Canceled := True;
    Exit;
  end;

  { Portable PLATFORM_ERR_* (Linux errno numbers). }
  case LCode of
    PLATFORM_ERR_TIMEDOUT:
      begin
        Result.Kind := nekTimeout;
        Result.Timeout := True;
        Exit;
      end;
    PLATFORM_ERR_CONNREFUSED:
      begin
        Result.Kind := nekRefused;
        Exit;
      end;
    PLATFORM_ERR_CONNRESET:
      begin
        Result.Kind := nekReset;
        Exit;
      end;
    PLATFORM_ERR_AGAIN, PLATFORM_ERR_BUSY:
      begin
        Result.Kind := nekTemporary;
        Result.Temporary := True;
        Exit;
      end;
    PLATFORM_ERR_INVALID:
      begin
        Result.Kind := nekInvalid;
        Exit;
      end;
    PLATFORM_ERR_INTR:
      begin
        Result.Kind := nekTemporary;
        Result.Temporary := True;
        Exit;
      end;
  end;

  { Darwin / other raw errno values commonly seen on sockets. }
  case LCode of
    60: { ETIMEDOUT on Darwin }
      begin
        Result.Kind := nekTimeout;
        Result.Timeout := True;
        Exit;
      end;
    61: { ECONNREFUSED on Darwin }
      begin
        Result.Kind := nekRefused;
        Exit;
      end;
    54: { ECONNRESET on Darwin }
      begin
        Result.Kind := nekReset;
        Exit;
      end;
    35: { EAGAIN/EWOULDBLOCK on Darwin }
      begin
        Result.Kind := nekTemporary;
        Result.Temporary := True;
        Exit;
      end;
    51, 65: { ENETUNREACH / EHOSTUNREACH Darwin-ish }
      begin
        Result.Kind := nekUnreachable;
        Exit;
      end;
  end;

  LCat := platform_error_category(LCode);
  case LCat of
    ecNone:
      Result.Kind := nekOK;
    ecTimeout:
      begin
        Result.Kind := nekTimeout;
        Result.Timeout := True;
      end;
    ecWouldBlock, ecInterrupted:
      begin
        Result.Kind := nekTemporary;
        Result.Temporary := True;
      end;
    ecNetwork:
      Result.Kind := nekUnreachable;
    ecInvalidArgument:
      Result.Kind := nekInvalid;
    ecNotFound:
      Result.Kind := nekDNS; { host not found often surfaces here }
  else
    Result.Kind := nekUnknown;
  end;
end;

end.
