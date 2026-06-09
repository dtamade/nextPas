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
  protected
    function DefaultCategory: TErrorCategory; virtual;
  public
    constructor Create(const AMessage: string); overload;
    constructor CreateFmt(const AMessage: string; const AArgs: array of const); overload;
    constructor CreateFmt(const AMessage: string; const ACategory: TErrorCategory;
      const AArgs: array of const); overload;
    constructor CreateFmt(const AMessage: string; const ACategory: TErrorCategory;
      const AArgs: array of const; const AInner: Exception;
      const AOwnsInner: Boolean = True); overload;
    constructor Create(const AMessage: string; const ACategory: TErrorCategory); overload;
    constructor Create(const AMessage: string; const AInner: Exception;
      const AOwnsInner: Boolean = True); overload;
    constructor Create(const AMessage: string; const ACategory: TErrorCategory;
      const AInner: Exception; const AOwnsInner: Boolean = True); overload;
    destructor Destroy; override;
    property Category: TErrorCategory read FCategory;
    property Inner: Exception read FInner;
    property OwnsInner: Boolean read FOwnsInner;
  end;

  EArgumentError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENullReferenceError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EInvalidOperationError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotImplementedError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotSupportedError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ETimeoutError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ECancelledError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EPermissionError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotFoundError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EAlreadyExistsError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EResourceExhaustedError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
    constructor CreateFmt(const AMessage: string; const AArgs: array of const); overload;
  end;

  EIOError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENetworkError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EParseError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EIndexOutOfRangeError = class(ENextPasError)
  protected
    function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMessage: string); overload;
  end;

  EOutOfMemoryError = class(EResourceExhaustedError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  { Compatibility short name. New public APIs should prefer EOutOfMemoryError. }
  EOutOfMemory = class(EOutOfMemoryError);

implementation

{ ENextPasError }

function ENextPasError.DefaultCategory: TErrorCategory;
begin
  Result := ecNone;
end;

constructor ENextPasError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FCategory := DefaultCategory;
  FInner := nil;
  FOwnsInner := False;
end;

constructor ENextPasError.CreateFmt(const AMessage: string;
  const AArgs: array of const);
begin
  inherited Create(Format(AMessage, AArgs));
  FCategory := DefaultCategory;
  FInner := nil;
  FOwnsInner := False;
end;

constructor ENextPasError.CreateFmt(const AMessage: string;
  const ACategory: TErrorCategory; const AArgs: array of const);
begin
  inherited Create(Format(AMessage, AArgs));
  FCategory := ACategory;
  FInner := nil;
  FOwnsInner := False;
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
  inherited Create(LMessage);
  FCategory := ACategory;
  FInner := AInner;
  FOwnsInner := AOwnsInner;
end;

constructor ENextPasError.Create(const AMessage: string;
  const ACategory: TErrorCategory);
begin
  inherited Create(AMessage);
  FCategory := ACategory;
  FInner := nil;
  FOwnsInner := False;
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
  FCategory := ACategory;
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

function EArgumentError.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidArgument;
end;

constructor EArgumentError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecInvalidArgument);
end;

function ENullReferenceError.DefaultCategory: TErrorCategory;
begin
  Result := ecNullReference;
end;

constructor ENullReferenceError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNullReference);
end;

function EInvalidOperationError.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidOperation;
end;

constructor EInvalidOperationError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecInvalidOperation);
end;

function ENotImplementedError.DefaultCategory: TErrorCategory;
begin
  Result := ecNotImplemented;
end;

constructor ENotImplementedError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNotImplemented);
end;

function ENotSupportedError.DefaultCategory: TErrorCategory;
begin
  Result := ecNotSupported;
end;

constructor ENotSupportedError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNotSupported);
end;

function ETimeoutError.DefaultCategory: TErrorCategory;
begin
  Result := ecTimeout;
end;

constructor ETimeoutError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecTimeout);
end;

function ECancelledError.DefaultCategory: TErrorCategory;
begin
  Result := ecCancelled;
end;

constructor ECancelledError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecCancelled);
end;

function EPermissionError.DefaultCategory: TErrorCategory;
begin
  Result := ecPermission;
end;

constructor EPermissionError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecPermission);
end;

function ENotFoundError.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

constructor ENotFoundError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNotFound);
end;

function EAlreadyExistsError.DefaultCategory: TErrorCategory;
begin
  Result := ecAlreadyExists;
end;

constructor EAlreadyExistsError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecAlreadyExists);
end;

function EResourceExhaustedError.DefaultCategory: TErrorCategory;
begin
  Result := ecResourceExhausted;
end;

constructor EResourceExhaustedError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecResourceExhausted);
end;

constructor EResourceExhaustedError.CreateFmt(const AMessage: string;
  const AArgs: array of const);
begin
  inherited Create(Format(AMessage, AArgs), ecResourceExhausted);
end;

function EIOError.DefaultCategory: TErrorCategory;
begin
  Result := ecIO;
end;

constructor EIOError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecIO);
end;

function ENetworkError.DefaultCategory: TErrorCategory;
begin
  Result := ecNetwork;
end;

constructor ENetworkError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNetwork);
end;

function EParseError.DefaultCategory: TErrorCategory;
begin
  Result := ecParse;
end;

constructor EParseError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecParse);
end;

function EIndexOutOfRangeError.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidArgument;
end;

constructor EIndexOutOfRangeError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecInvalidArgument);
end;

constructor EOutOfMemoryError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

end.
