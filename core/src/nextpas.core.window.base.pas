unit nextpas.core.window.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors;

type
  TWindowKind = (wkGtk2, wkGtk3, wkGtk4, wkQt, wkSdl2, wkWin32, wkCocoa, wkAndroid, wkUIKit, wkWasm, wkFake);

  TWindowNativeHandle = type Pointer;

const
  { wkGtk 聚合别名（deprecated）：gtk 智能回退收口至 wkGtk3 载体，与 registry 注释一致，不单列枚举 }
  wkGtk = wkGtk3;

type
  TWindowEventKind =
    (weResized, weMoved, weCloseRequested, weClosed, weFocusChanged, weScaleChanged);

const
  weFocusIn = weFocusChanged;
  weFocusOut = weFocusChanged;

  { 默认窗口几何：语义化命名常量替代魔法数字 1024/768（XGA 4:3），CONTRACT §3.2 单源；inline 零拷贝。 }
  WINDOW_DEFAULT_WIDTH = 1024;
  WINDOW_DEFAULT_HEIGHT = 768;

type
  { 强类型几何：TWindowSize/TWindowConstraints 封装 6 裸 Integer 扁平约束，防逻辑/物理/约束误混，inline 零拷贝值语义；业务以 CONTRACT 为准。 }
  TWindowSize = record
  public
    Width: Integer;  // 物理像素，0=默认
    Height: Integer; // 物理像素，0=默认
    class function Create(AWidth, AHeight: Integer): TWindowSize; static; inline;
    class function Default: TWindowSize; static; inline;
    function IsEmpty: Boolean; inline;
  end;

  { 约束强类型：4 字段封装 Min/Max，单源于 window.base（constraints.base 薄复用 alias 至此，业务以 CONTRACT 为准），inline 零拷贝值语义；守 L0-L3 window.base 仅依赖 L0-L1，无 L2→L2。 }
  TWindowConstraints = record
  public
    MinWidth: Integer;  // 0 = not limited
    MinHeight: Integer;
    MaxWidth: Integer;  // 0 = not limited
    MaxHeight: Integer;
    class function Create(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer): TWindowConstraints; static; inline;
    class function Default: TWindowConstraints; static; inline;
    function IsEmpty: Boolean; inline;
  end;

  TWindowOptions = record
    Title: string;
    Size: TWindowSize; // 默认 WINDOW_DEFAULT_WIDTH/HEIGHT，0 表示引擎默认
    Constraints: TWindowConstraints; // 默认空（0 不限制），Min/Max 强类型封装防误用
    Resizable: Boolean;
    Maximized: Boolean;
    ParentHandle: TWindowNativeHandle;
  end;

  { 物理像素强类型：distinct 语义，inline 零拷贝，防逻辑/物理混淆；单源于 base。 }
  TWindowPixel = type Integer;

const
  { 尺度容差：CONTRACT §3.3 单源，IsIdentity/= 以 epsilon 近似比较防精确相等抖动；inline 零拷贝，无堆分配。 }
  WINDOW_SCALE_EPSILON = 1e-9;
  WINDOW_SCALE_IDENTITY_FACTOR = 1.0;

type
  { 尺度强类型封装：Double 外覆，显式工厂校验，inline 零拷贝值语义；防裸 Double 误用。
    高频 weScaleChanged 每帧一次：IsIdentity/Equals/=/<> 用无分支区间阈值（[Factor-EPS, Factor+EPS]）
    替代 Abs 分支，降低流水线停顿与抖动误判；零拷贝值语义，业务以 CONTRACT 为准。 }
  TWindowScale = record
  private
    FFactor: Double;
    class function IsFinite(const AValue: Double): Boolean; static; inline;
    class function AlmostEqual(const A, B: Double): Boolean; static; inline;
  public
    class function FromFactor(const AFactor: Double): TWindowScale; static; inline;
    class function Identity: TWindowScale; static; inline;
    class function Invalid: TWindowScale; static; inline;
    function Factor: Double; inline;
    function ToDouble: Double; inline;
    function IsValid: Boolean; inline;
    function IsIdentity: Boolean; inline;
    function Equals(const AOther: TWindowScale): Boolean; inline;
    class operator = (const A, B: TWindowScale): Boolean; inline;
    class operator <> (const A, B: TWindowScale): Boolean; inline;
  end;

  TWindowEvent = record
    Kind: TWindowEventKind;
    Width: TWindowPixel;  // 物理像素
    Height: TWindowPixel; // 物理像素
    X: TWindowPixel;      // 物理像素
    Y: TWindowPixel;      // 物理像素
    NewScale: TWindowScale; // 强类型尺度
  end;

  TWindowEventHandler = reference to procedure(const AEvent: TWindowEvent);
  TWindowEventMethod = procedure(const AEvent: TWindowEvent) of object;
  TWindowEventProc = procedure(const AEvent: TWindowEvent);

  { dispatcher 闭包三形式 — 单源于 base，window.intf/queue.base 均 alias 此处，守 base←intf，inline 零拷贝。 }
  TWindowProcRef    = reference to procedure;
  TWindowProcMethod = procedure of object;
  TWindowProc       = procedure;

  TWindowEventDispatchKind = (wedkNone, wedkRef, wedkMethod, wedkProc);
  TWindowEventVariant = record
    Kind: TWindowEventDispatchKind;
    Ref: TWindowEventHandler;
    Method: TWindowEventMethod;
    Proc: TWindowEventProc;
  end;

function DefaultWindowOptions: TWindowOptions; inline;
function WindowOptionsCreate(const ATitle: string; AWidth, AHeight,
  AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer;
  AResizable, AMaximized: Boolean): TWindowOptions; inline;
procedure CheckWindowOptions(const AOptions: TWindowOptions);

type
  EWindowError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowBackendUnavailable = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowNotInitialized = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowInvalidState = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowClosed = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EWindowUnsupported = class(EWindowError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

implementation

uses
  nextpas.core.math.scalar;

class function TWindowSize.Create(AWidth, AHeight: Integer): TWindowSize; inline;
begin
  Result.Width := AWidth;
  Result.Height := AHeight;
end;

class function TWindowSize.Default: TWindowSize; inline;
begin
  Result.Width := WINDOW_DEFAULT_WIDTH;
  Result.Height := WINDOW_DEFAULT_HEIGHT;
end;

function TWindowSize.IsEmpty: Boolean; inline;
begin
  Result := (Width = 0) and (Height = 0);
end;

class function TWindowConstraints.Create(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer): TWindowConstraints; inline;
begin
  Result.MinWidth := AMinWidth;
  Result.MinHeight := AMinHeight;
  Result.MaxWidth := AMaxWidth;
  Result.MaxHeight := AMaxHeight;
end;

class function TWindowConstraints.Default: TWindowConstraints; inline;
begin
  Result.MinWidth := 0;
  Result.MinHeight := 0;
  Result.MaxWidth := 0;
  Result.MaxHeight := 0;
end;

function TWindowConstraints.IsEmpty: Boolean; inline;
begin
  Result := (MinWidth = 0) and (MinHeight = 0) and (MaxWidth = 0) and (MaxHeight = 0);
end;

function DefaultWindowOptions: TWindowOptions; inline;
begin
  Result.Title := '';
  Result.Size := TWindowSize.Default;
  Result.Constraints := TWindowConstraints.Default;
  Result.Resizable := True;
  Result.Maximized := False;
  Result.ParentHandle := nil;
end;

function WindowOptionsCreate(const ATitle: string; AWidth, AHeight,
  AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer;
  AResizable, AMaximized: Boolean): TWindowOptions; inline;
begin
  // perf: single source inline zero-copy field copy, owner L2 window.base — nested Size/Constraints 强类型封装（lane 收口），同 main 平坦版语义
  Result := DefaultWindowOptions;
  Result.Title := ATitle;
  Result.Size := TWindowSize.Create(AWidth, AHeight);
  Result.Constraints := TWindowConstraints.Create(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight);
  Result.Resizable := AResizable;
  Result.Maximized := AMaximized;
  // ParentHandle stays nil (Default), webview has-a window without embedding
end;

procedure CheckWindowOptions(const AOptions: TWindowOptions);
begin
  // 与 main 平坦版同语义，按嵌套 Size/Constraints 改写
  if (AOptions.Size.Width < 0) or (AOptions.Size.Height < 0) then
    raise EWindowInvalidState.CreateFmt('Width/Height must be >= 0 (got %d, %d)', [AOptions.Size.Width, AOptions.Size.Height]);
  if (AOptions.Constraints.MinWidth < 0) or (AOptions.Constraints.MinHeight < 0) then
    raise EWindowInvalidState.CreateFmt('MinWidth/MinHeight must be >= 0 (got %d, %d)', [AOptions.Constraints.MinWidth, AOptions.Constraints.MinHeight]);
  if (AOptions.Constraints.MaxWidth < 0) or (AOptions.Constraints.MaxHeight < 0) then
    raise EWindowInvalidState.CreateFmt('MaxWidth/MaxHeight must be >= 0 (got %d, %d)', [AOptions.Constraints.MaxWidth, AOptions.Constraints.MaxHeight]);
  if (AOptions.Constraints.MinWidth > 0) and (AOptions.Constraints.MaxWidth > 0)
    and (AOptions.Constraints.MaxWidth < AOptions.Constraints.MinWidth) then
    raise EWindowInvalidState.CreateFmt('MaxWidth (%d) must be >= MinWidth (%d)', [AOptions.Constraints.MaxWidth, AOptions.Constraints.MinWidth]);
  if (AOptions.Constraints.MinHeight > 0) and (AOptions.Constraints.MaxHeight > 0)
    and (AOptions.Constraints.MaxHeight < AOptions.Constraints.MinHeight) then
    raise EWindowInvalidState.CreateFmt('MaxHeight (%d) must be >= MinHeight (%d)', [AOptions.Constraints.MaxHeight, AOptions.Constraints.MinHeight]);
end;

class function TWindowScale.FromFactor(const AFactor: Double): TWindowScale; inline;
begin
  Result.FFactor := AFactor;
end;

class function TWindowScale.Identity: TWindowScale; inline;
begin
  Result.FFactor := WINDOW_SCALE_IDENTITY_FACTOR;
end;

class function TWindowScale.Invalid: TWindowScale; inline;
begin
  Result.FFactor := 0.0;
end;

function TWindowScale.Factor: Double; inline;
begin
  Result := FFactor;
end;

function TWindowScale.ToDouble: Double; inline;
begin
  Result := FFactor;
end;

function TWindowScale.IsValid: Boolean; inline;
begin
  // 有限性防御：Inf/NaN 显式判为无效，零拷贝 inline 位掩码无堆分配
  Result := (FFactor > 0) and IsFinite(FFactor);
end;

class function TWindowScale.IsFinite(const AValue: Double): Boolean; inline;
begin
  // 单源复用 nextpas.core.math.scalar.IsInfinite/IsNaN（L0 导出单源，无 Move 重复，inline 薄转发；有限 == 非 NaN 且非 Inf）
  Result := (not nextpas.core.math.scalar.IsNaN(AValue)) and (not nextpas.core.math.scalar.IsInfinite(AValue));
end;

class function TWindowScale.AlmostEqual(const A, B: Double): Boolean; inline;
begin
  // 单源 epsilon 区间比较：显式有限性防御，NaN/Inf 永不等价防 weScaleChanged 去抖漂移；有限域内无分支 [B-EPS, B+EPS] 替代 Abs，bytes.ops 单源思想，CONTRACT §3.3 单源；inline 零拷贝值语义，无堆分配，weScaleChanged 每帧去抖零流水线停顿
  if not IsFinite(A) or not IsFinite(B) then
    Exit(False);
  Result := (A >= B - WINDOW_SCALE_EPSILON) and (A <= B + WINDOW_SCALE_EPSILON);
end;

function TWindowScale.IsIdentity: Boolean; inline;
begin
  // inline 薄转发单源 AlmostEqual，零拷贝，无堆分配
  Result := AlmostEqual(FFactor, WINDOW_SCALE_IDENTITY_FACTOR);
end;

function TWindowScale.Equals(const AOther: TWindowScale): Boolean; inline;
begin
  // inline 薄转发单源 AlmostEqual，零拷贝，无堆分配
  Result := AlmostEqual(FFactor, AOther.FFactor);
end;

class operator TWindowScale.=(const A, B: TWindowScale): Boolean; inline;
begin
  // inline 薄转发单源 AlmostEqual，零拷贝，业务以 CONTRACT 为准
  Result := AlmostEqual(A.FFactor, B.FFactor);
end;

class operator TWindowScale.<>(const A, B: TWindowScale): Boolean; inline;
begin
  // inline 薄转发单源 AlmostEqual 取反，零拷贝；等价 (A < B-EPS) or (A > B+EPS) 的 De Morgan，无分支阈值复用
  Result := not AlmostEqual(A.FFactor, B.FFactor);
end;

class function EWindowError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowBackendUnavailable.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

class function EWindowNotInitialized.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowInvalidState.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowClosed.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EWindowUnsupported.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
