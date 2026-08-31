unit nextpas.core.system;
{**
 * @desc Root RTL facade for the nextPas system module family.
 *
 * This unit provides the compiler kernel contract layer.
 * Under FPC, it re-exports FPC System types via fpc.inc.
 * Under nextPas, it provides the full kernel via kernel.inc.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.system.errors;

{$IFDEF FPC}
{$I nextpas.core.system.fpc.inc}
{$ELSE}
{$I nextpas.core.system.kernel.inc}
{$ENDIF}

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
  { Re-export base types }
  TBytes = nextpas.core.base.TBytes;
  TByteSpan = nextpas.core.base.TByteSpan;
  THashCode = nextpas.core.base.THashCode;

  { Exception taxonomy — forwarded from nextpas.core.system.errors }
  Exception = nextpas.core.system.errors.Exception;
  ExceptClass = nextpas.core.system.errors.ExceptClass;
  EConvertError = nextpas.core.system.errors.EConvertError;
  EAssertionFailed = nextpas.core.system.errors.EAssertionFailed;
  EAbort = nextpas.core.system.errors.EAbort;

  TErrorCategory = nextpas.core.system.errors.TErrorCategory;
  ENextPasError = nextpas.core.system.errors.ENextPasError;
  ECore = nextpas.core.system.errors.ECore;
  EInvariantViolation = nextpas.core.system.errors.EInvariantViolation;
  EArgumentNil = nextpas.core.system.errors.EArgumentNil;
  EEmptyCollection = nextpas.core.system.errors.EEmptyCollection;
  EInvalidArgument = nextpas.core.system.errors.EInvalidArgument;
  EInvalidResult = nextpas.core.system.errors.EInvalidResult;
  EInvalidState = nextpas.core.system.errors.EInvalidState;
  EOutOfRange = nextpas.core.system.errors.EOutOfRange;
  ENotSupported = nextpas.core.system.errors.ENotSupported;
  ENotCompatible = nextpas.core.system.errors.ENotCompatible;
  EInvalidOperation = nextpas.core.system.errors.EInvalidOperation;
  EOverflow = nextpas.core.system.errors.EOverflow;

  EArgumentError = nextpas.core.system.errors.EArgumentError;
  ENullReferenceError = nextpas.core.system.errors.ENullReferenceError;
  EInvalidOperationError = nextpas.core.system.errors.EInvalidOperationError;
  ENotImplementedError = nextpas.core.system.errors.ENotImplementedError;
  ENotSupportedError = nextpas.core.system.errors.ENotSupportedError;
  ETimeoutError = nextpas.core.system.errors.ETimeoutError;
  ECancelledError = nextpas.core.system.errors.ECancelledError;
  EPermissionError = nextpas.core.system.errors.EPermissionError;
  ENotFoundError = nextpas.core.system.errors.ENotFoundError;
  EAlreadyExistsError = nextpas.core.system.errors.EAlreadyExistsError;
  EResourceExhaustedError = nextpas.core.system.errors.EResourceExhaustedError;
  EIOError = nextpas.core.system.errors.EIOError;
  ENetworkError = nextpas.core.system.errors.ENetworkError;
  EParseError = nextpas.core.system.errors.EParseError;
  EIndexOutOfRangeError = nextpas.core.system.errors.EIndexOutOfRangeError;
  EOutOfMemoryError = nextpas.core.system.errors.EOutOfMemoryError;
  EOutOfMemory = nextpas.core.system.errors.EOutOfMemory;
  EInterruptedError = nextpas.core.system.errors.EInterruptedError;
  EWouldBlockError = nextpas.core.system.errors.EWouldBlockError;

const
  { Error category constants — forwarded from nextpas.core.system.errors }
  ecNone = nextpas.core.system.errors.ecNone;
  ecInvalidArgument = nextpas.core.system.errors.ecInvalidArgument;
  ecNullReference = nextpas.core.system.errors.ecNullReference;
  ecInvalidOperation = nextpas.core.system.errors.ecInvalidOperation;
  ecNotImplemented = nextpas.core.system.errors.ecNotImplemented;
  ecNotSupported = nextpas.core.system.errors.ecNotSupported;
  ecTimeout = nextpas.core.system.errors.ecTimeout;
  ecCancelled = nextpas.core.system.errors.ecCancelled;
  ecInterrupted = nextpas.core.system.errors.ecInterrupted;
  ecWouldBlock = nextpas.core.system.errors.ecWouldBlock;
  ecPermission = nextpas.core.system.errors.ecPermission;
  ecNotFound = nextpas.core.system.errors.ecNotFound;
  ecAlreadyExists = nextpas.core.system.errors.ecAlreadyExists;
  ecResourceExhausted = nextpas.core.system.errors.ecResourceExhausted;
  ecIO = nextpas.core.system.errors.ecIO;
  ecNetwork = nextpas.core.system.errors.ecNetwork;
  ecParse = nextpas.core.system.errors.ecParse;
  ecInternal = nextpas.core.system.errors.ecInternal;

procedure FreeAndNil(var AObj); inline;
procedure SafeFree(var AObj); inline;
procedure ZeroMem(ADst: Pointer; ASize: SizeUInt); inline;
procedure FillMem(ADst: Pointer; ASize: SizeUInt; AValue: Byte); inline;
procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt); inline;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean; inline;
function Supports(const AInstance: TObject; const AIID: TGuid; out AIntf): Boolean; inline;
function Supports(const AInstance: IInterface; const AIID: TGuid; out AIntf): Boolean; inline;

function HTonN(AValue: Word): Word; overload; inline;
function HTonN(AValue: LongWord): LongWord; overload; inline;
function NToHs(AValue: Word): Word; overload; inline;
function NToHs(AValue: LongWord): LongWord; overload; inline;

function VarType(const V: Variant): TVarType;
function VarIsNull(const V: Variant): Boolean;
function VarIsEmpty(const V: Variant): Boolean;
function VarIsClear(const V: Variant): Boolean;

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

function HTonN(AValue: Word): Word;
begin
  Result := nextpas.core.base.utils.HTonN(AValue);
end;

function HTonN(AValue: LongWord): LongWord;
begin
  Result := nextpas.core.base.utils.HTonN(AValue);
end;

function NToHs(AValue: Word): Word;
begin
  Result := nextpas.core.base.utils.NToHs(AValue);
end;

function NToHs(AValue: LongWord): LongWord;
begin
  Result := nextpas.core.base.utils.NToHs(AValue);
end;

function VarType(const V: Variant): TVarType;
begin
  Result := TVarData(V).VType;
end;

function VarIsNull(const V: Variant): Boolean;
begin
  Result := TVarData(V).VType = varNull;
end;

function VarIsEmpty(const V: Variant): Boolean;
begin
  Result := TVarData(V).VType = varEmpty;
end;

function VarIsClear(const V: Variant): Boolean;
begin
  Result := TVarData(V).VType in [varEmpty, varNull];
end;

end.
