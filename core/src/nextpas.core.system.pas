unit nextpas.core.system;
{**
 * @desc Root RTL facade for the nextPas system module family.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.exception,
  nextpas.core.errors;

const
  NEXTPAS_SYSTEM_NAME = 'nextpas.core.system';
  MAX_SIZE_INT = nextpas.core.base.MAX_SIZE_INT;
  MAX_SIZE_UINT = nextpas.core.base.MAX_SIZE_UINT;
  MIN_SIZE_INT = nextpas.core.base.MIN_SIZE_INT;
  SIZE_PTR = nextpas.core.base.SIZE_PTR;
  SIZE_8 = nextpas.core.base.SIZE_8;
  SIZE_16 = nextpas.core.base.SIZE_16;
  SIZE_32 = nextpas.core.base.SIZE_32;
  SIZE_64 = nextpas.core.base.SIZE_64;

type
  SizeInt = System.SizeInt;
  SizeUInt = System.SizeUInt;
  PtrInt = System.PtrInt;
  PtrUInt = System.PtrUInt;
  NativeInt = System.NativeInt;
  NativeUInt = System.NativeUInt;

  TBytes = nextpas.core.base.TBytes;
  TByteSpan = nextpas.core.base.TByteSpan;
  THashCode = nextpas.core.base.THashCode;

  Exception = nextpas.core.exception.Exception;
  ExceptClass = nextpas.core.exception.ExceptClass;
  EConvertError = nextpas.core.exception.EConvertError;
  EAssertionFailed = nextpas.core.exception.EAssertionFailed;

  TErrorCategory = nextpas.core.exception.TErrorCategory;
  ENextPasError = nextpas.core.exception.ENextPasError;
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

const
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

procedure FreeAndNil(var AObj); inline;
procedure SafeFree(var AObj); inline;
procedure ZeroMem(ADst: Pointer; ASize: SizeUInt); inline;
procedure FillMem(ADst: Pointer; ASize: SizeUInt; AValue: Byte); inline;
procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt); inline;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean; inline;
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean; inline;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean; inline;

implementation

procedure FreeAndNil(var AObj);
begin
  nextpas.core.base.utils.FreeAndNil(AObj);
end;

procedure SafeFree(var AObj);
begin
  nextpas.core.base.utils.SafeFree(AObj);
end;

procedure ZeroMem(ADst: Pointer; ASize: SizeUInt);
begin
  nextpas.core.base.utils.ZeroMem(ADst, ASize);
end;

procedure FillMem(ADst: Pointer; ASize: SizeUInt; AValue: Byte);
begin
  nextpas.core.base.utils.FillMem(ADst, ASize, AValue);
end;

procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt);
begin
  nextpas.core.base.utils.CopyMem(ADst, ASrc, ASize);
end;

function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean;
begin
  Result := nextpas.core.base.utils.CompareMem(A, B, ASize);
end;

function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean;
begin
  Result := nextpas.core.base.utils.Supports(AInstance, AIID, AIntf);
end;

function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean;
begin
  Result := nextpas.core.base.utils.Supports(AInstance, AIID, AIntf);
end;

end.
