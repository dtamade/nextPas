unit nextpas.core.exception;
{**
 * @desc Canonical framework exception root and common taxonomy.
 *}

{$I nextpas.core.settings.inc}

interface

{$IFDEF FPC}
uses
  SysUtils;  { Exception, ExceptClass — FPC runtime, routed through here }

type
  Exception = SysUtils.Exception;
  ExceptClass = SysUtils.ExceptClass;
  EConvertError = SysUtils.EConvertError;
  ERangeError = SysUtils.ERangeError;
  EAssertionFailed = SysUtils.EAssertionFailed;
  EAbort = SysUtils.EAbort;
  EArgumentException = SysUtils.EArgumentException;
{$ELSE}
type
  { Base Exception class — nextPas native implementation.
    Field layout is FPC-compatible (fmessage/fhelpcontext) for ABI safety. }
  Exception = class(TObject)
  private
    fmessage: string;
    fhelpcontext: longint;
  public
    constructor Create(const msg: string);
    constructor CreateFmt(const msg: string; const args: array of const);
    property HelpContext: longint read fhelpcontext write fhelpcontext;
    property Message: string read fmessage write fmessage;
  end;

  ExceptClass = class of Exception;

  EConvertError = class(Exception);
  ERangeError = class(Exception);
  EAssertionFailed = class(Exception);
  EAbort = class(Exception);
  EArgumentException = class(Exception);
{$ENDIF}

  TErrorCategory = (
    ecNone,
    ecInvalidArgument,
    ecNullReference,
    ecInvalidOperation,
    ecNotImplemented,
    ecNotSupported,
    ecTimeout,
    ecCancelled,
    ecInterrupted,
    ecWouldBlock,
    ecPermission,
    ecNotFound,
    ecAlreadyExists,
    ecResourceExhausted,
    ecIO,
    ecNetwork,
    ecParse,
    ecInternal
  );

  { ENextPasError - the official framework root exception. }
  ENextPasError = class(Exception)
  private
    FCategory: TErrorCategory;
    FInner: Exception;
    FOwnsInner: Boolean;
    function ResolveCategory(const ACategory: TErrorCategory): TErrorCategory;
  protected
    class function DefaultCategory: TErrorCategory; virtual;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; const ACategory: TErrorCategory); overload;
    constructor CreateFmt(const AMessage: string; const AArgs: array of const); overload;
    constructor CreateFmt(const AMessage: string; const ACategory: TErrorCategory;
      const AArgs: array of const); overload;
    constructor CreateFmt(const AMessage: string; const ACategory: TErrorCategory;
      const AArgs: array of const; const AInner: Exception;
      const AOwnsInner: Boolean = True); overload;
    constructor Create(const AMessage: string; const AInner: Exception;
      const AOwnsInner: Boolean = True); overload;
    constructor Create(const AMessage: string; const ACategory: TErrorCategory;
      const AInner: Exception; const AOwnsInner: Boolean = True); overload;
    destructor Destroy; override;
    property Category: TErrorCategory read FCategory;
    property Inner: Exception read FInner;
  end;

  EArgumentError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENullReferenceError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EInvalidOperationError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotImplementedError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotSupportedError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ETimeoutError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ECancelledError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EInterruptedError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EWouldBlockError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EPermissionError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotFoundError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EAlreadyExistsError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EResourceExhaustedError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
    constructor CreateFmt(const AMessage: string; const AArgs: array of const); overload;
  end;

  EIOError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENetworkError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EParseError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EIndexOutOfRangeError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EOutOfMemoryError = class(EResourceExhaustedError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  { Compatibility short name. New public APIs should prefer EOutOfMemoryError. }
  EOutOfMemory = class(EOutOfMemoryError);

function ErrorCategoryToString(const ACategory: TErrorCategory): string;

{ Exception backtrace — centralized here so L0 facades don't use SysUtils directly.
  Single-source over FPC RTL raiseframe chain; inline zero-copy forward. }
function ExceptAddr: Pointer; inline;
function ExceptFrameCount: LongInt; inline;
function ExceptFrameAt(const AIndex: LongInt): CodePointer; inline;
{ Current exception helpers —反哺FPC RTL直引，git等L2仅经此owner取当前异常 }
function CurrentException: Exception; inline;
function CurrentExceptionMessage: string; inline;
function CurrentExceptionIs(AClass: ExceptClass): Boolean; inline;

implementation

{ Internal format helper — used by ENextPasError constructors under both compilers.
  Supports %s (string), %d (integer), %% (literal percent).
  Uses Result := Result + Ch/S pattern (no nested procedures, no SetString). }
function FormatStr(const AFmt: string; const AArgs: array of const): string;
var
  LI, LArgIdx: Integer;
  LIntBuf: string;
  LVal: Int64;
  LTmpStr: string;
begin
  Result := '';
  LArgIdx := 0;
  LI := 1;
  while LI <= Length(AFmt) do
  begin
    if (AFmt[LI] = '%') and (LI < Length(AFmt)) then
    begin
      Inc(LI);
      case AFmt[LI] of
        's': begin
          if LArgIdx > High(AArgs) then
            raise EConvertError.Create('FormatStr: not enough arguments for %s');
          case AArgs[LArgIdx].VType of
            vtAnsiString: begin
              LTmpStr := string(AArgs[LArgIdx].VAnsiString);
              Result := Result + LTmpStr;
            end;
            vtUnicodeString: begin
              LTmpStr := string(AArgs[LArgIdx].VUnicodeString);
              Result := Result + LTmpStr;
            end;
            vtString: Result := Result + AArgs[LArgIdx].VString^;
            vtChar: Result := Result + AArgs[LArgIdx].VChar;
            vtPChar: begin
              LTmpStr := string(AArgs[LArgIdx].VPChar);
              Result := Result + LTmpStr;
            end;
            vtWideChar: Result := Result + Char(AArgs[LArgIdx].VWideChar);
          else
            Result := Result + '???';
          end;
          Inc(LArgIdx);
        end;
        'd': begin
          if LArgIdx > High(AArgs) then
            raise EConvertError.Create('FormatStr: not enough arguments for %d');
          case AArgs[LArgIdx].VType of
            vtInteger: LVal := AArgs[LArgIdx].VInteger;
            vtInt64: LVal := AArgs[LArgIdx].VInt64^;
            vtBoolean: LVal := Ord(AArgs[LArgIdx].VBoolean);
          else
            LVal := 0;
          end;
          Str(LVal, LIntBuf);
          Result := Result + LIntBuf;
          Inc(LArgIdx);
        end;
        '%': Result := Result + '%';
      else
        Result := Result + '%' + AFmt[LI];
      end;
    end
    else
      Result := Result + AFmt[LI];
    Inc(LI);
  end;
end;

{$IFNDEF FPC}
constructor Exception.Create(const msg: string);
begin
  inherited Create;
  fmessage := msg;
  fhelpcontext := 0;
end;

constructor Exception.CreateFmt(const msg: string; const args: array of const);
begin
  Create(FormatStr(msg, args));
end;
{$ENDIF}

function ErrorCategoryToString(const ACategory: TErrorCategory): string;
begin
  Result := 'internal';
  case ACategory of
    ecNone: Result := 'none';
    ecInvalidArgument: Result := 'invalid_argument';
    ecNullReference: Result := 'null_reference';
    ecInvalidOperation: Result := 'invalid_operation';
    ecNotImplemented: Result := 'not_implemented';
    ecNotSupported: Result := 'not_supported';
    ecTimeout: Result := 'timeout';
    ecCancelled: Result := 'cancelled';
    ecInterrupted: Result := 'interrupted';
    ecWouldBlock: Result := 'would_block';
    ecPermission: Result := 'permission';
    ecNotFound: Result := 'not_found';
    ecAlreadyExists: Result := 'already_exists';
    ecResourceExhausted: Result := 'resource_exhausted';
    ecIO: Result := 'io';
    ecNetwork: Result := 'network';
    ecParse: Result := 'parse';
    ecInternal: Result := 'internal';
  end;
end;

{ ENextPasError }

class function ENextPasError.DefaultCategory: TErrorCategory;
begin
  Result := ecNone;
end;

function ENextPasError.ResolveCategory(const ACategory: TErrorCategory): TErrorCategory;
begin
  Result := DefaultCategory;
  if Result <> ecNone then
    Exit;

  if (Ord(ACategory) < Ord(Low(TErrorCategory))) or
     (Ord(ACategory) > Ord(High(TErrorCategory))) then
    Result := ecInternal
  else
    Result := ACategory;
end;

constructor ENextPasError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FCategory := DefaultCategory;
  FInner := nil;
  FOwnsInner := False;
end;

constructor ENextPasError.Create(const AMessage: string;
  const ACategory: TErrorCategory);
begin
  inherited Create(AMessage);
  FCategory := ResolveCategory(ACategory);
  FInner := nil;
  FOwnsInner := False;
end;

constructor ENextPasError.CreateFmt(const AMessage: string;
  const AArgs: array of const);
var
  LMsg: string;
begin
  LMsg := FormatStr(AMessage, AArgs);
  Create(LMsg);
end;

constructor ENextPasError.CreateFmt(const AMessage: string;
  const ACategory: TErrorCategory; const AArgs: array of const);
var
  LMsg: string;
begin
  LMsg := FormatStr(AMessage, AArgs);
  Create(LMsg, ACategory);
end;

constructor ENextPasError.CreateFmt(const AMessage: string;
  const ACategory: TErrorCategory; const AArgs: array of const;
  const AInner: Exception; const AOwnsInner: Boolean);
var
  LMessage: string;
begin
  try
    LMessage := FormatStr(AMessage, AArgs);
  except
    if AOwnsInner and (AInner <> nil) then
      AInner.Free;
    raise;
  end;
  Create(LMessage, ACategory, AInner, AOwnsInner);
end;

constructor ENextPasError.Create(const AMessage: string; const AInner: Exception;
  const AOwnsInner: Boolean);
begin
  inherited Create(AMessage);
  FCategory := DefaultCategory;
  FInner := AInner;
  FOwnsInner := AOwnsInner;
end;

constructor ENextPasError.Create(const AMessage: string;
  const ACategory: TErrorCategory; const AInner: Exception;
  const AOwnsInner: Boolean);
begin
  inherited Create(AMessage);
  FCategory := ResolveCategory(ACategory);
  FInner := AInner;
  FOwnsInner := AOwnsInner;
end;

destructor ENextPasError.Destroy;
begin
  if FOwnsInner and (FInner <> nil) then
    FInner.Free;
  inherited Destroy;
end;

{ Specific exceptions }

class function EArgumentError.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidArgument;
end;

constructor EArgumentError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function ENullReferenceError.DefaultCategory: TErrorCategory;
begin
  Result := ecNullReference;
end;

constructor ENullReferenceError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function EInvalidOperationError.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidOperation;
end;

constructor EInvalidOperationError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function ENotImplementedError.DefaultCategory: TErrorCategory;
begin
  Result := ecNotImplemented;
end;

constructor ENotImplementedError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function ENotSupportedError.DefaultCategory: TErrorCategory;
begin
  Result := ecNotSupported;
end;

constructor ENotSupportedError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function ETimeoutError.DefaultCategory: TErrorCategory;
begin
  Result := ecTimeout;
end;

constructor ETimeoutError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function ECancelledError.DefaultCategory: TErrorCategory;
begin
  Result := ecCancelled;
end;

constructor ECancelledError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function EInterruptedError.DefaultCategory: TErrorCategory;
begin
  Result := ecInterrupted;
end;

constructor EInterruptedError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function EWouldBlockError.DefaultCategory: TErrorCategory;
begin
  Result := ecWouldBlock;
end;

constructor EWouldBlockError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function EPermissionError.DefaultCategory: TErrorCategory;
begin
  Result := ecPermission;
end;

constructor EPermissionError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function ENotFoundError.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

constructor ENotFoundError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function EAlreadyExistsError.DefaultCategory: TErrorCategory;
begin
  Result := ecAlreadyExists;
end;

constructor EAlreadyExistsError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function EResourceExhaustedError.DefaultCategory: TErrorCategory;
begin
  Result := ecResourceExhausted;
end;

constructor EResourceExhaustedError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

constructor EResourceExhaustedError.CreateFmt(const AMessage: string;
  const AArgs: array of const);
var
  LMsg: string;
begin
  LMsg := FormatStr(AMessage, AArgs);
  inherited Create(LMsg);
end;

class function EIOError.DefaultCategory: TErrorCategory;
begin
  Result := ecIO;
end;

constructor EIOError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function ENetworkError.DefaultCategory: TErrorCategory;
begin
  Result := ecNetwork;
end;

constructor ENetworkError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function EParseError.DefaultCategory: TErrorCategory;
begin
  Result := ecParse;
end;

constructor EParseError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

class function EIndexOutOfRangeError.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidArgument;
end;

constructor EIndexOutOfRangeError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

constructor EOutOfMemoryError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

{ Exception backtrace — inline single-source delegation to FPC RTL }
{$IFDEF FPC}
function ExceptAddr: Pointer; inline;
begin
  Result := SysUtils.ExceptAddr;
end;

function ExceptFrameCount: LongInt; inline;
begin
  Result := SysUtils.ExceptFrameCount;
end;

function ExceptFrameAt(const AIndex: LongInt): CodePointer; inline;
begin
  if (AIndex < 0) or (AIndex >= SysUtils.ExceptFrameCount) then
    Result := nil
  else
    Result := SysUtils.ExceptFrames[AIndex];
end;

function CurrentException: Exception; inline;
begin
  Result := Exception(SysUtils.ExceptObject);
end;

function CurrentExceptionMessage: string; inline;
begin
  if SysUtils.ExceptObject is Exception then
    Result := Exception(SysUtils.ExceptObject).Message
  else if SysUtils.ExceptObject <> nil then
    Result := SysUtils.ExceptObject.ClassName
  else
    Result := '';
end;

function CurrentExceptionIs(AClass: ExceptClass): Boolean; inline;
begin
  Result := (SysUtils.ExceptObject <> nil) and (SysUtils.ExceptObject is AClass);
end;
{$ELSE}
function ExceptAddr: Pointer; inline;
begin
  Result := nil;
end;

function ExceptFrameCount: LongInt; inline;
begin
  Result := 0;
end;

function ExceptFrameAt(const AIndex: LongInt): CodePointer; inline;
begin
  Result := nil;
end;

function CurrentException: Exception; inline;
begin
  Result := nil;
end;

function CurrentExceptionMessage: string; inline;
begin
  Result := '';
end;

function CurrentExceptionIs(AClass: ExceptClass): Boolean; inline;
begin
  Result := False;
end;
{$ENDIF}

end.
