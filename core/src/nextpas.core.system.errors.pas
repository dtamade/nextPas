unit nextpas.core.system.errors;
{**
 * @desc Exception type alias facade for nextpas.core.system.
 *
 * This unit re-exports all exception/error type aliases and error-category
 * constants that the root system facade exposes. It allows consumers to
 * import exception taxonomy without pulling the full root facade.
 *
 * Ownership boundary:
 * - Exception/ExceptClass/EConvertError/EAssertionFailed/EAbort → nextpas.core.exception
 * - ECore/EInvariantViolation/.../EOverflow → nextpas.core.base
 * - EArgumentError/.../EWouldBlockError + ecNone/ecInvalidArgument/.../ecInternal → nextpas.core.errors
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.errors;

type
  { FPC-compatible root exceptions }
  Exception = nextpas.core.exception.Exception;
  ExceptClass = nextpas.core.exception.ExceptClass;
  EConvertError = nextpas.core.exception.EConvertError;
  EAssertionFailed = nextpas.core.exception.EAssertionFailed;
  EAbort = nextpas.core.exception.EAbort;

  { Framework exception root }
  TErrorCategory = nextpas.core.exception.TErrorCategory;
  ENextPasError = nextpas.core.exception.ENextPasError;

  { Base compile-truth exceptions }
  ECore = nextpas.core.base.ECore;
  EInvariantViolation = nextpas.core.base.EInvariantViolation;
  EArgumentNil = nextpas.core.base.EArgumentNil;
  EEmptyCollection = nextpas.core.base.EEmptyCollection;
  EInvalidArgument = nextpas.core.base.EInvalidArgument;
  EInvalidResult = nextpas.core.base.EInvalidResult;
  EInvalidState = nextpas.core.base.EInvalidState;
  EOutOfRange = nextpas.core.base.EOutOfRange;
  ENotSupported = nextpas.core.base.ENotSupported;
  ENotCompatible = nextpas.core.base.ENotCompatible;
  EInvalidOperation = nextpas.core.base.EInvalidOperation;
  EOverflow = nextpas.core.base.EOverflow;

  { Taxonomy exceptions }
  EArgumentError = nextpas.core.errors.EArgumentError;
  ENullReferenceError = nextpas.core.errors.ENullReferenceError;
  EInvalidOperationError = nextpas.core.errors.EInvalidOperationError;
  ENotImplementedError = nextpas.core.errors.ENotImplementedError;
  ENotSupportedError = nextpas.core.errors.ENotSupportedError;
  ETimeoutError = nextpas.core.errors.ETimeoutError;
  ECancelledError = nextpas.core.errors.ECancelledError;
  EPermissionError = nextpas.core.errors.EPermissionError;
  ENotFoundError = nextpas.core.errors.ENotFoundError;
  EAlreadyExistsError = nextpas.core.errors.EAlreadyExistsError;
  EResourceExhaustedError = nextpas.core.errors.EResourceExhaustedError;
  EIOError = nextpas.core.errors.EIOError;
  ENetworkError = nextpas.core.errors.ENetworkError;
  EParseError = nextpas.core.errors.EParseError;
  EIndexOutOfRangeError = nextpas.core.errors.EIndexOutOfRangeError;
  EOutOfMemoryError = nextpas.core.errors.EOutOfMemoryError;
  EOutOfMemory = nextpas.core.errors.EOutOfMemory;
  EInterruptedError = nextpas.core.errors.EInterruptedError;
  EWouldBlockError = nextpas.core.errors.EWouldBlockError;

const
  { Error category constants }
  ecNone = nextpas.core.errors.ecNone;
  ecInvalidArgument = nextpas.core.errors.ecInvalidArgument;
  ecNullReference = nextpas.core.errors.ecNullReference;
  ecInvalidOperation = nextpas.core.errors.ecInvalidOperation;
  ecNotImplemented = nextpas.core.errors.ecNotImplemented;
  ecNotSupported = nextpas.core.errors.ecNotSupported;
  ecTimeout = nextpas.core.errors.ecTimeout;
  ecCancelled = nextpas.core.errors.ecCancelled;
  ecInterrupted = nextpas.core.errors.ecInterrupted;
  ecWouldBlock = nextpas.core.errors.ecWouldBlock;
  ecPermission = nextpas.core.errors.ecPermission;
  ecNotFound = nextpas.core.errors.ecNotFound;
  ecAlreadyExists = nextpas.core.errors.ecAlreadyExists;
  ecResourceExhausted = nextpas.core.errors.ecResourceExhausted;
  ecIO = nextpas.core.errors.ecIO;
  ecNetwork = nextpas.core.errors.ecNetwork;
  ecParse = nextpas.core.errors.ecParse;
  ecInternal = nextpas.core.errors.ecInternal;

implementation

end.
