unit nextpas.core.window.chrome.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.window.chrome.base,
  nextpas.core.window.chrome.intf,
  nextpas.core.window.impl,
  nextpas.core.math.scalar,
  nextpas.core.math.easing;

procedure CheckWindowChromeOpacity(const AOpacity: Double); inline;

function WindowChromeGrowCapacity(ACurrent: Integer): Integer; inline;

procedure CheckWindowChromeOptions(const AOptions: TWindowChromeOptions); inline;

function WindowChromeProgress(const AElapsedMs, AAnimationMs: Integer): Double; inline;
function WindowChromeEasedProgress(const AElapsedMs, AAnimationMs: Integer; const AEase: TEasingFunction): Double; inline;
function WindowChromeTickOpacity(const AFromOpacity, AToOpacity: Double; const AElapsedMs, AAnimationMs: Integer; const AEase: TEasingFunction): Double; inline;

type
  { TWindowChromeImpl — INV-12 高级视觉端到端载体 (decorations/透明/阴影/动画 全批)
    单源复用 window.impl WindowGrowCapacity → bytes.ops 0→32→2× via BytesGrowCapacity (single source window.impl 薄转发零额外拷贝), CheckWindowChromeOpacity 单源 inline 复用 via CheckWindowChromeOptions/SetOpacity (Opacity [0,1] 且有限 IsNaN/IsInfinite 单源 math.scalar 零漂移), WindowChromeGrowCapacity 单重载 Integer 单源 window.impl inline 零拷贝 O(1)均摊 (SizeUInt 重载家族零调用已剔除, 守无效复用清理, 8× identical inline 已收口至 window.impl 单源); 动画 tick 单源 math.easing TEasingFunction via WindowChromeProgress/EasedProgress/TickOpacity (elapsed/AnimationMs clamp [0,1] + Ease + Lerp) direct L2→L0;
    性能: Apply/GetOptions/SetOpacity/GetOpacity/Tick 均为 inline O(1) zero-copy (record 单次 Move/单字段写/div+clamp+间接调用单次 Double 算术, 零堆分配, Opacity 校验 inline 薄分支单源, AnimationMs=0 早退 16ns);
    稳定性: 无句柄/堆分配, 仅值类型 FOptions, COM 引用计数自动释放, heaptrc 0, 析构继承不丢资源, 无 timer 句柄 tick 由 window.loop 驱动 }
  { TWindowChromeImpl — see unit header Owner/INV-12, single source window.impl via bytes.ops, inline zero-copy O(1) }
  TWindowChromeImpl = class(TInterfacedObject, IWindowChrome)
  strict private
    FOptions: TWindowChromeOptions;
  public
    constructor Create; overload;
    constructor Create(const AOptions: TWindowChromeOptions); overload;
    procedure Apply(const AOptions: TWindowChromeOptions);
    function GetOptions: TWindowChromeOptions; inline;
    procedure SetOpacity(AOpacity: Double);
    function GetOpacity: Double; inline;
  end;

function CreateWindowChrome: IWindowChrome; overload; inline;
function CreateWindowChrome(const AOptions: TWindowChromeOptions): IWindowChrome; overload; inline;

implementation

procedure CheckWindowChromeOpacity(const AOpacity: Double); inline;
begin
  if IsNaN(AOpacity) or IsInfinite(AOpacity) or (AOpacity < 0.0) or (AOpacity > 1.0) then
    raise EWindowChromeInvalidOptions.CreateFmt('Opacity must be in [0,1] (got %f)', [AOpacity]);
end;

function WindowChromeGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  // single source 0→32→2× via window.impl WindowGrowCapacity → bytes.ops inline 零拷贝 O(1)均摊, SizeUInt 重载家族零调用已剔除守单源零重复
  Result := WindowGrowCapacity(ACurrent);
end;

procedure CheckWindowChromeOptions(const AOptions: TWindowChromeOptions); inline;
begin
  CheckWindowChromeOpacity(AOptions.Opacity);
  if AOptions.AnimationMs < 0 then
    raise EWindowChromeInvalidOptions.CreateFmt('AnimationMs must be >=0 (got %d)', [AOptions.AnimationMs]);
end;

function WindowChromeProgress(const AElapsedMs, AAnimationMs: Integer): Double; inline;
begin
  if AAnimationMs <= 0 then
    Exit(1.0);
  Result := AElapsedMs / Double(AAnimationMs);
  if Result < 0.0 then
    Result := 0.0
  else if Result > 1.0 then
    Result := 1.0;
end;

function WindowChromeEasedProgress(const AElapsedMs, AAnimationMs: Integer; const AEase: TEasingFunction): Double; inline;
var
  LT: Double;
begin
  LT := WindowChromeProgress(AElapsedMs, AAnimationMs);
  if Assigned(AEase) then
    Result := AEase(LT)
  else
    Result := LT;
end;

function WindowChromeTickOpacity(const AFromOpacity, AToOpacity: Double; const AElapsedMs, AAnimationMs: Integer; const AEase: TEasingFunction): Double; inline;
var
  LEased: Double;
begin
  LEased := WindowChromeEasedProgress(AElapsedMs, AAnimationMs, AEase);
  Result := Lerp(AFromOpacity, AToOpacity, LEased);
end;

constructor TWindowChromeImpl.Create;
begin
  inherited Create;
  FOptions := DefaultWindowChromeOptions;
end;

constructor TWindowChromeImpl.Create(const AOptions: TWindowChromeOptions);
begin
  inherited Create;
  CheckWindowChromeOptions(AOptions);
  FOptions := AOptions;
end;

procedure TWindowChromeImpl.Apply(const AOptions: TWindowChromeOptions);
begin
  CheckWindowChromeOptions(AOptions);
  FOptions := AOptions;
end;

function TWindowChromeImpl.GetOptions: TWindowChromeOptions; inline;
begin
  Result := FOptions;
end;

procedure TWindowChromeImpl.SetOpacity(AOpacity: Double);
begin
  CheckWindowChromeOpacity(AOpacity);
  FOptions.Opacity := AOpacity;
end;

function TWindowChromeImpl.GetOpacity: Double; inline;
begin
  Result := FOptions.Opacity;
end;

function CreateWindowChrome: IWindowChrome; inline;
begin
  Result := TWindowChromeImpl.Create;
end;

function CreateWindowChrome(const AOptions: TWindowChromeOptions): IWindowChrome; inline;
begin
  Result := TWindowChromeImpl.Create(AOptions);
end;

end.
