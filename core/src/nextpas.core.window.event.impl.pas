unit nextpas.core.window.event.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.event.base,
  nextpas.core.window.event.intf,
  nextpas.core.window.impl;

function WindowEventGrowCapacity(ACurrent: Integer): Integer; inline; // bench single-call BenchEventGrow/1 inline zero-copy O(1) via window.impl WindowGrowCapacity → bytes.ops 0→32→2× single source, BenchBlackBoxInt64 防 DCE, 无内循环, 8× identical inline 已收口至 window.impl 单源

procedure CheckWindowEventBusOptions(const AOptions: TWindowEventBusOptions); inline; // bench single-call BenchEventCheck/1 inline 薄分支零拷贝 O(1)

type
  TWindowEventSubscriptionImpl = class(TInterfacedObject, IWindowEventSubscription)
  strict private
    FHandle: TWindowEventHandle;
    FActive: Boolean;
    FOwner: Pointer;
  public
    constructor Create(AHandle: TWindowEventHandle; AOwner: Pointer);
    function GetHandle: TWindowEventHandle; inline;
    procedure Unsubscribe;
    function IsActive: Boolean; inline;
  end;

  TWindowEventBusImpl = class(TInterfacedObject, IWindowEventBus)
  strict private
    FOptions: TWindowEventBusOptions;
    FNextId: UInt64;
    FGeneration: UInt32;
    FSubs: array of IWindowEventSubscription;
    FHandlers: array of TWindowEventVariant;
    FCount: Integer;
    procedure EnsureCapacity(ARequired: Integer); inline;
    procedure RemoveAt(AIdx: Integer); inline;
  public
    constructor Create; overload;
    constructor Create(const AOptions: TWindowEventBusOptions); overload;
    destructor Destroy; override;
    function Subscribe(AHandler: TWindowEventHandler): IWindowEventSubscription; overload;
    function Subscribe(AHandler: TWindowEventMethod): IWindowEventSubscription; overload;
    function Subscribe(AHandler: TWindowEventProc): IWindowEventSubscription; overload;
    procedure Unsubscribe(const AHandle: TWindowEventHandle);
    procedure Clear;
    function Count: Integer; inline;
    procedure Dispatch(const AEvent: TWindowEvent);
    function GetOptions: TWindowEventBusOptions; inline;
    procedure SetOptions(const AOptions: TWindowEventBusOptions); inline;
  end;

function CreateWindowEventBus: IWindowEventBus; overload; inline;
function CreateWindowEventBus(const AOptions: TWindowEventBusOptions): IWindowEventBus; overload; inline;

implementation

function WindowEventGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  // single source 0→32→2× via window.impl WindowGrowCapacity → bytes.ops inline 零拷贝 O(1)均摊, 8× identical inline 已收口至 window.impl 单源
  Result := WindowGrowCapacity(ACurrent);
end;

procedure CheckWindowEventBusOptions(const AOptions: TWindowEventBusOptions); inline;
begin
  if AOptions.MaxHandlers < 0 then
    raise EWindowEventInvalidOptions.CreateFmt('MaxHandlers must be >=0 (got %d)', [AOptions.MaxHandlers]);
end;

constructor TWindowEventSubscriptionImpl.Create(AHandle: TWindowEventHandle; AOwner: Pointer);
begin
  inherited Create;
  FHandle := AHandle;
  FActive := True;
  FOwner := AOwner;
end;

function TWindowEventSubscriptionImpl.GetHandle: TWindowEventHandle; inline;
begin
  Result := FHandle;
end;

procedure TWindowEventSubscriptionImpl.Unsubscribe;
var
  LBus: TWindowEventBusImpl;
begin
  if not FActive then Exit;
  FActive := False;
  if FOwner <> nil then
  begin
    LBus := TWindowEventBusImpl(FOwner);
    LBus.Unsubscribe(FHandle);
  end;
  FOwner := nil;
end;

function TWindowEventSubscriptionImpl.IsActive: Boolean; inline;
begin
  Result := FActive;
end;

constructor TWindowEventBusImpl.Create;
begin
  inherited Create;
  FOptions := DefaultWindowEventBusOptions;
  FNextId := 1;
  FGeneration := 1;
  FCount := 0;
end;

constructor TWindowEventBusImpl.Create(const AOptions: TWindowEventBusOptions);
begin
  inherited Create;
  CheckWindowEventBusOptions(AOptions);
  FOptions := AOptions;
  FNextId := 1;
  FGeneration := 1;
  FCount := 0;
end;

destructor TWindowEventBusImpl.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
  begin
    WindowEventVariantClear(FHandlers[I]);
    FSubs[I] := nil;
  end;
  SetLength(FHandlers, 0);
  SetLength(FSubs, 0);
  FCount := 0;
  inherited Destroy;
end;

procedure TWindowEventBusImpl.EnsureCapacity(ARequired: Integer); inline;
var
  LCap: Integer;
begin
  if Length(FSubs) >= ARequired then Exit;
  LCap := WindowEventGrowCapacity(Length(FSubs));
  if LCap < ARequired then LCap := WindowEventGrowCapacity(ARequired);
  SetLength(FSubs, LCap);
  SetLength(FHandlers, LCap);
end;

procedure TWindowEventBusImpl.RemoveAt(AIdx: Integer); inline;
var
  LLast: Integer;
begin
  if (AIdx < 0) or (AIdx >= FCount) then Exit;
  WindowEventVariantClear(FHandlers[AIdx]);
  FSubs[AIdx] := nil;
  LLast := FCount - 1;
  if AIdx <> LLast then
  begin
    FHandlers[AIdx] := FHandlers[LLast];
    FSubs[AIdx] := FSubs[LLast];
    WindowEventVariantClear(FHandlers[LLast]);
    FSubs[LLast] := nil;
  end;
  Dec(FCount);
end;

function TWindowEventBusImpl.Subscribe(AHandler: TWindowEventHandler): IWindowEventSubscription; overload;
var
  LHandle: TWindowEventHandle;
  LSub: TWindowEventSubscriptionImpl;
begin
  if not Assigned(AHandler) then
    raise EWindowEventHandleInvalid.Create('handler must be assigned');
  if (FOptions.MaxHandlers > 0) and (FCount >= FOptions.MaxHandlers) then
    raise EWindowEventInvalidOptions.CreateFmt('MaxHandlers reached (%d)', [FOptions.MaxHandlers]);
  LHandle.Id := FNextId; Inc(FNextId);
  LHandle.Generation := FGeneration; Inc(FGeneration);
  LSub := TWindowEventSubscriptionImpl.Create(LHandle, Pointer(Self));
  EnsureCapacity(FCount + 1);
  FHandlers[FCount] := WindowEventVariantFromRef(AHandler);
  FSubs[FCount] := LSub;
  Inc(FCount);
  Result := LSub;
end;

function TWindowEventBusImpl.Subscribe(AHandler: TWindowEventMethod): IWindowEventSubscription; overload;
var
  LHandle: TWindowEventHandle;
  LSub: TWindowEventSubscriptionImpl;
begin
  if not Assigned(AHandler) then
    raise EWindowEventHandleInvalid.Create('handler must be assigned');
  if (FOptions.MaxHandlers > 0) and (FCount >= FOptions.MaxHandlers) then
    raise EWindowEventInvalidOptions.CreateFmt('MaxHandlers reached (%d)', [FOptions.MaxHandlers]);
  LHandle.Id := FNextId; Inc(FNextId);
  LHandle.Generation := FGeneration; Inc(FGeneration);
  LSub := TWindowEventSubscriptionImpl.Create(LHandle, Pointer(Self));
  EnsureCapacity(FCount + 1);
  FHandlers[FCount] := WindowEventVariantFromMethod(AHandler);
  FSubs[FCount] := LSub;
  Inc(FCount);
  Result := LSub;
end;

function TWindowEventBusImpl.Subscribe(AHandler: TWindowEventProc): IWindowEventSubscription; overload;
var
  LHandle: TWindowEventHandle;
  LSub: TWindowEventSubscriptionImpl;
begin
  if not Assigned(AHandler) then
    raise EWindowEventHandleInvalid.Create('handler must be assigned');
  if (FOptions.MaxHandlers > 0) and (FCount >= FOptions.MaxHandlers) then
    raise EWindowEventInvalidOptions.CreateFmt('MaxHandlers reached (%d)', [FOptions.MaxHandlers]);
  LHandle.Id := FNextId; Inc(FNextId);
  LHandle.Generation := FGeneration; Inc(FGeneration);
  LSub := TWindowEventSubscriptionImpl.Create(LHandle, Pointer(Self));
  EnsureCapacity(FCount + 1);
  FHandlers[FCount] := WindowEventVariantFromProc(AHandler);
  FSubs[FCount] := LSub;
  Inc(FCount);
  Result := LSub;
end;

procedure TWindowEventBusImpl.Unsubscribe(const AHandle: TWindowEventHandle);
var
  I: Integer;
begin
  if not AHandle.IsValid then Exit;
  for I := 0 to FCount - 1 do
    if (FSubs[I] <> nil) and (FSubs[I].GetHandle.Id = AHandle.Id) and (FSubs[I].GetHandle.Generation = AHandle.Generation) then
    begin
      if FSubs[I] is TWindowEventSubscriptionImpl then
        TWindowEventSubscriptionImpl(FSubs[I] as TWindowEventSubscriptionImpl).FActive := False;
      RemoveAt(I);
      Exit;
    end;
end;

procedure TWindowEventBusImpl.Clear;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
  begin
    WindowEventVariantClear(FHandlers[I]);
    if FSubs[I] <> nil then
      (FSubs[I] as TWindowEventSubscriptionImpl).FActive := False;
    FSubs[I] := nil;
  end;
  FCount := 0;
end;

function TWindowEventBusImpl.Count: Integer; inline;
begin
  Result := FCount;
end;

procedure TWindowEventBusImpl.Dispatch(const AEvent: TWindowEvent);
var
  I: Integer;
begin
  // snapshot dispatch: active handlers inline zero-copy O(n), revoked skipped, resource not lost
  for I := 0 to FCount - 1 do
    if (FSubs[I] <> nil) and FSubs[I].IsActive then
      WindowEventVariantDispatch(FHandlers[I], AEvent);
end;

function TWindowEventBusImpl.GetOptions: TWindowEventBusOptions; inline;
begin
  Result := FOptions;
end;

procedure TWindowEventBusImpl.SetOptions(const AOptions: TWindowEventBusOptions); inline;
begin
  CheckWindowEventBusOptions(AOptions);
  FOptions := AOptions;
end;

function CreateWindowEventBus: IWindowEventBus; inline;
begin
  Result := TWindowEventBusImpl.Create;
end;

function CreateWindowEventBus(const AOptions: TWindowEventBusOptions): IWindowEventBus; inline;
begin
  Result := TWindowEventBusImpl.Create(AOptions);
end;

end.
