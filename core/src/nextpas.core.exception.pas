unit nextpas.core.exception;
{**
 * @desc Canonical framework exception root and common taxonomy.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

type
  { Re-export base Exception from RTL so consumers do not need SysUtils. }
  Exception = SysUtils.Exception;
  ExceptClass = SysUtils.ExceptClass;
  EConvertError = SysUtils.EConvertError;
  EAssertionFailed = SysUtils.EAssertionFailed;

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

implementation

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
  LMsg := Format(AMessage, AArgs);
  Create(LMsg);
end;

constructor ENextPasError.CreateFmt(const AMessage: string;
  const ACategory: TErrorCategory; const AArgs: array of const);
var
  LMsg: string;
begin
  LMsg := Format(AMessage, AArgs);
  Create(LMsg, ACategory);
end;

constructor ENextPasError.CreateFmt(const AMessage: string;
  const ACategory: TErrorCategory; const AArgs: array of const;
  const AInner: Exception; const AOwnsInner: Boolean);
var
  LMessage: string;
begin
  try
    LMessage := Format(AMessage, AArgs);
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
  inherited;
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
  LMsg := Format(AMessage, AArgs);
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

end.
