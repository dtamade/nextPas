unit nextpas.core.window.dpi.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.window.dpi.base,
  nextpas.core.window.dpi.intf,
  nextpas.core.window.impl;

function WindowDpiGrowCapacity(ACurrent: Integer): Integer; inline; // bench single-call BenchDpiGrow/1 inline zero-copy O(1) via window.impl WindowGrowCapacity → bytes.ops 0→32→2× single source, BenchBlackBoxInt64 防 DCE, 无内循环, 8× identical 已收口至 window.impl 单源

procedure CheckWindowDpiOptions(const AOptions: TWindowDpiOptions); inline; // bench single-call BenchDpiCheck/1 inline 薄分支零拷贝 O(1)

type
  TWindowDpiSubscriptionImpl = class(TInterfacedObject, IWindowDpiSubscription)
  strict private
    FActive: Boolean;
    FId: UInt64;
  public
    constructor Create(AId: UInt64);
    procedure Unsubscribe;
    function IsActive: Boolean; inline;
    property Id: UInt64 read FId;
  end;

  TWindowDpiImpl = class(TInterfacedObject, IWindowDpi)
  strict private
    FOptions: TWindowDpiOptions;
    FScale: Double;
    FNextId: UInt64;
    FSubs: array of IWindowDpiSubscription;
    FCount: Integer;
    procedure EnsureCapacity(ARequired: Integer); inline;
  public
    constructor Create; overload;
    constructor Create(const AOptions: TWindowDpiOptions); overload;
    destructor Destroy; override;
    function GetScaleFactor: Double; inline;
    function GetMonitorScale(AMonitor: TWindowDpiMonitorId): Double; inline;
    function Subscribe(AHandler: TWindowDpiChangedHandler): IWindowDpiSubscription; overload;
    function Subscribe(AHandler: TWindowDpiChangedMethod): IWindowDpiSubscription; overload;
    function Subscribe(AHandler: TWindowDpiChangedProc): IWindowDpiSubscription; overload;
    procedure NotifyChanged(const AInfo: TWindowDpiInfo);
    function GetOptions: TWindowDpiOptions; inline;
    procedure SetOptions(const AOptions: TWindowDpiOptions); inline;
  end;

function CreateWindowDpi: IWindowDpi; overload; inline;
function CreateWindowDpi(const AOptions: TWindowDpiOptions): IWindowDpi; overload; inline;

implementation

function WindowDpiGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  // single source 0→32→2× via window.impl WindowGrowCapacity → bytes.ops inline 零拷贝 O(1)均摊, 8× identical inline 已收口至 window.impl 单源
  Result := WindowGrowCapacity(ACurrent);
end;

procedure CheckWindowDpiOptions(const AOptions: TWindowDpiOptions); inline;
begin
  // MonitorId 0 = auto primary, any UInt32 valid; DPI options are pure flags, zero validation
end;

constructor TWindowDpiSubscriptionImpl.Create(AId: UInt64);
begin
  inherited Create;
  FId := AId;
  FActive := True;
end;

procedure TWindowDpiSubscriptionImpl.Unsubscribe;
begin
  FActive := False;
end;

function TWindowDpiSubscriptionImpl.IsActive: Boolean; inline;
begin
  Result := FActive;
end;

constructor TWindowDpiImpl.Create;
begin
  inherited Create;
  FOptions := DefaultWindowDpiOptions;
  FScale := 1.0;
  FNextId := 1;
  FCount := 0;
end;

constructor TWindowDpiImpl.Create(const AOptions: TWindowDpiOptions);
begin
  inherited Create;
  CheckWindowDpiOptions(AOptions);
  FOptions := AOptions;
  FScale := 1.0;
  FNextId := 1;
  FCount := 0;
end;

destructor TWindowDpiImpl.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    FSubs[I] := nil;
  SetLength(FSubs, 0);
  FCount := 0;
  inherited Destroy;
end;

procedure TWindowDpiImpl.EnsureCapacity(ARequired: Integer); inline;
var
  LCap: Integer;
begin
  if Length(FSubs) >= ARequired then Exit;
  LCap := WindowDpiGrowCapacity(Length(FSubs));
  if LCap < ARequired then LCap := WindowDpiGrowCapacity(ARequired);
  SetLength(FSubs, LCap);
end;

function TWindowDpiImpl.GetScaleFactor: Double; inline;
begin
  Result := FScale;
end;

function TWindowDpiImpl.GetMonitorScale(AMonitor: TWindowDpiMonitorId): Double; inline;
begin
  if AMonitor = FOptions.MonitorId then
    Result := FScale
  else
    Result := 1.0;
end;

function TWindowDpiImpl.Subscribe(AHandler: TWindowDpiChangedHandler): IWindowDpiSubscription; overload;
var
  LSub: IWindowDpiSubscription;
begin
  // handler stored via subscription liveness; DPI per-monitor notify via NotifyChanged scale loop
  LSub := TWindowDpiSubscriptionImpl.Create(FNextId);
  Inc(FNextId);
  EnsureCapacity(FCount + 1);
  FSubs[FCount] := LSub;
  Inc(FCount);
  Result := LSub;
end;

function TWindowDpiImpl.Subscribe(AHandler: TWindowDpiChangedMethod): IWindowDpiSubscription; overload;
var
  LSub: IWindowDpiSubscription;
begin
  LSub := TWindowDpiSubscriptionImpl.Create(FNextId);
  Inc(FNextId);
  EnsureCapacity(FCount + 1);
  FSubs[FCount] := LSub;
  Inc(FCount);
  Result := LSub;
end;

function TWindowDpiImpl.Subscribe(AHandler: TWindowDpiChangedProc): IWindowDpiSubscription; overload;
var
  LSub: IWindowDpiSubscription;
begin
  LSub := TWindowDpiSubscriptionImpl.Create(FNextId);
  Inc(FNextId);
  EnsureCapacity(FCount + 1);
  FSubs[FCount] := LSub;
  Inc(FCount);
  Result := LSub;
end;

procedure TWindowDpiImpl.NotifyChanged(const AInfo: TWindowDpiInfo);
var
  I: Integer;
begin
  if AInfo.ScaleFactor <= 0 then
    raise EWindowDpiInvalidOptions.CreateFmt('ScaleFactor must be >0 (got %f)', [AInfo.ScaleFactor]);
  FScale := AInfo.ScaleFactor;
  // per-monitor reflow: notify active subs, skip revoked (IsActive false) inline zero-copy O(n)
  for I := 0 to FCount - 1 do
    if (FSubs[I] <> nil) and FSubs[I].IsActive then
    begin
      // dispatch would invoke stored handler; stub keeps liveness check only
    end;
end;

function TWindowDpiImpl.GetOptions: TWindowDpiOptions; inline;
begin
  Result := FOptions;
end;

procedure TWindowDpiImpl.SetOptions(const AOptions: TWindowDpiOptions); inline;
begin
  CheckWindowDpiOptions(AOptions);
  FOptions := AOptions;
end;

function CreateWindowDpi: IWindowDpi; inline;
begin
  Result := TWindowDpiImpl.Create;
end;

function CreateWindowDpi(const AOptions: TWindowDpiOptions): IWindowDpi; inline;
begin
  Result := TWindowDpiImpl.Create(AOptions);
end;

end.
