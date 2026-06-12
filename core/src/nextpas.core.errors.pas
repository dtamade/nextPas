unit nextpas.core.errors;
{**
 * @desc Public exception taxonomy facade.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.exception;

type
  { Re-export base Exception from RTL so consumers do not need SysUtils. }
  Exception = nextpas.core.exception.Exception;
  ExceptClass = nextpas.core.exception.ExceptClass;
  EConvertError = nextpas.core.exception.EConvertError;
  EAssertionFailed = nextpas.core.exception.EAssertionFailed;

  TErrorCategory = nextpas.core.exception.TErrorCategory;
  ENextPasError = nextpas.core.exception.ENextPasError;

  EArgumentError = nextpas.core.exception.EArgumentError;
  ENullReferenceError = nextpas.core.exception.ENullReferenceError;
  EInvalidOperationError = nextpas.core.exception.EInvalidOperationError;
  ENotImplementedError = nextpas.core.exception.ENotImplementedError;
  ENotSupportedError = nextpas.core.exception.ENotSupportedError;
  ETimeoutError = nextpas.core.exception.ETimeoutError;
  ECancelledError = nextpas.core.exception.ECancelledError;
  EInterruptedError = nextpas.core.exception.EInterruptedError;
  EWouldBlockError = nextpas.core.exception.EWouldBlockError;
  EPermissionError = nextpas.core.exception.EPermissionError;
  ENotFoundError = nextpas.core.exception.ENotFoundError;
  EAlreadyExistsError = nextpas.core.exception.EAlreadyExistsError;
  EResourceExhaustedError = nextpas.core.exception.EResourceExhaustedError;
  EIOError = nextpas.core.exception.EIOError;
  ENetworkError = nextpas.core.exception.ENetworkError;
  EParseError = nextpas.core.exception.EParseError;
  EIndexOutOfRangeError = nextpas.core.exception.EIndexOutOfRangeError;
  EOutOfMemoryError = nextpas.core.exception.EOutOfMemoryError;
  EOutOfMemory = nextpas.core.exception.EOutOfMemory;

const
  ecNone = nextpas.core.exception.ecNone;
  ecInvalidArgument = nextpas.core.exception.ecInvalidArgument;
  ecNullReference = nextpas.core.exception.ecNullReference;
  ecInvalidOperation = nextpas.core.exception.ecInvalidOperation;
  ecNotImplemented = nextpas.core.exception.ecNotImplemented;
  ecNotSupported = nextpas.core.exception.ecNotSupported;
  ecTimeout = nextpas.core.exception.ecTimeout;
  ecCancelled = nextpas.core.exception.ecCancelled;
  ecInterrupted = nextpas.core.exception.ecInterrupted;
  ecWouldBlock = nextpas.core.exception.ecWouldBlock;
  ecPermission = nextpas.core.exception.ecPermission;
  ecNotFound = nextpas.core.exception.ecNotFound;
  ecAlreadyExists = nextpas.core.exception.ecAlreadyExists;
  ecResourceExhausted = nextpas.core.exception.ecResourceExhausted;
  ecIO = nextpas.core.exception.ecIO;
  ecNetwork = nextpas.core.exception.ecNetwork;
  ecParse = nextpas.core.exception.ecParse;
  ecInternal = nextpas.core.exception.ecInternal;

function ErrorCategoryToString(const ACategory: TErrorCategory): string; inline;

implementation

function ErrorCategoryToString(const ACategory: TErrorCategory): string;
begin
  Result := nextpas.core.exception.ErrorCategoryToString(ACategory);
end;

end.
