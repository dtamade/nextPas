unit nextpas.core.errors;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

type
  { 错误分类码 }
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

  { ENextPasError - framework root exception with category + inner }
  ENextPasError = class(Exception)
  private
    FCategory: TErrorCategory;
    FInner: Exception;
    FOwnsInner: Boolean;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; const ACategory: TErrorCategory); overload;
    constructor Create(const AMessage: string; const AInner: Exception; const AOwnsInner: Boolean = True); overload;
    constructor Create(const AMessage: string; const ACategory: TErrorCategory; const AInner: Exception; const AOwnsInner: Boolean = True); overload;
    destructor Destroy; override;
    property Category: TErrorCategory read FCategory;
    property Inner: Exception read FInner;
  end;

  { Specific exception types }
  EArgumentError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENullReferenceError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  EInvalidOperationError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotImplementedError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotSupportedError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  ETimeoutError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  ECancelledError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  EPermissionError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENotFoundError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  EAlreadyExistsError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  EResourceExhaustedError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  EIOError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  ENetworkError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  EParseError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  EIndexOutOfRangeError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

  EOutOfMemoryError = class(ENextPasError)
  public
    constructor Create(const AMessage: string); overload;
  end;

implementation

{ ENextPasError }

constructor ENextPasError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FCategory := ecNone;
  FInner := nil;
  FOwnsInner := False;
end;

constructor ENextPasError.Create(const AMessage: string; const ACategory: TErrorCategory);
begin
  inherited Create(AMessage);
  FCategory := ACategory;
  FInner := nil;
  FOwnsInner := False;
end;

constructor ENextPasError.Create(const AMessage: string; const AInner: Exception; const AOwnsInner: Boolean);
begin
  inherited Create(AMessage);
  FCategory := ecNone;
  FInner := AInner;
  FOwnsInner := AOwnsInner;
end;

constructor ENextPasError.Create(const AMessage: string; const ACategory: TErrorCategory; const AInner: Exception; const AOwnsInner: Boolean);
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

constructor EArgumentError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecInvalidArgument);
end;

constructor ENullReferenceError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNullReference);
end;

constructor EInvalidOperationError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecInvalidOperation);
end;

constructor ENotImplementedError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNotImplemented);
end;

constructor ENotSupportedError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNotSupported);
end;

constructor ETimeoutError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecTimeout);
end;

constructor ECancelledError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecCancelled);
end;

constructor EPermissionError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecPermission);
end;

constructor ENotFoundError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNotFound);
end;

constructor EAlreadyExistsError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecAlreadyExists);
end;

constructor EResourceExhaustedError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecResourceExhausted);
end;

constructor EIOError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecIO);
end;

constructor ENetworkError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNetwork);
end;

constructor EParseError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecParse);
end;

constructor EIndexOutOfRangeError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecInvalidArgument);
end;

constructor EOutOfMemoryError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecResourceExhausted);
end;

end.
