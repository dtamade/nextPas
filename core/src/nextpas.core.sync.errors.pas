unit nextpas.core.sync.errors;
{**
 * Sync-local helpers: map platform codes to readable failures.
 * Does not expand the public error taxonomy beyond nextpas.core.errors.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.error;

function SyncPlatformErrName(const ACode: Int32): string;
procedure SyncRaiseOpFailed(const AObjectName, AOp: string; const ACode: Int32);
procedure SyncRaiseArg(const AMessage: string);
procedure SyncRaiseInvalidOp(const AMessage: string);

implementation

function SyncPlatformErrName(const ACode: Int32): string;
begin
  case ACode of
    0: Result := 'OK';
    PLATFORM_ERR_PERM: Result := 'PERM';
    PLATFORM_ERR_BUSY: Result := 'BUSY';
    PLATFORM_ERR_INVALID: Result := 'INVALID';
    PLATFORM_ERR_AGAIN: Result := 'AGAIN';
    PLATFORM_ERR_NOMEM: Result := 'NOMEM';
    PLATFORM_ERR_TIMEDOUT: Result := 'TIMEDOUT';
    PLATFORM_ERR_UNSUPPORTED: Result := 'UNSUPPORTED';
    PLATFORM_ERR_INTR: Result := 'INTR';
  else
    Result := 'ERR';
  end;
end;

procedure SyncRaiseOpFailed(const AObjectName, AOp: string; const ACode: Int32);
begin
  raise EInvalidOperationError.Create(
    AObjectName + '.' + AOp + ' failed: ' + SyncPlatformErrName(ACode) +
    ' (' + IntToStr(ACode) + ')');
end;

procedure SyncRaiseArg(const AMessage: string);
begin
  raise EArgumentError.Create(AMessage);
end;

procedure SyncRaiseInvalidOp(const AMessage: string);
begin
  raise EInvalidOperationError.Create(AMessage);
end;

end.
