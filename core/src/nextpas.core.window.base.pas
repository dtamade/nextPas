unit nextpas.core.window.base;

{** @desc nextpas.core.window L2 家族：公共类型根。
       后端种类、窗口选项、事件 record、原生句柄别名与错误族。
       只依赖 errors owner；禁止 uses 本家族任何后端/fake/factory 单元
       （INV-3，source-contract 门禁冻结）。

       错误类目定值表（逐类测试冻结）：
       - EWindowBackendUnavailable = ecNotFound   （dlopen/探测失败）
       - 其余（NotInitialized/InvalidState/Closed/Unsupported）= ecInternal
       - EWindowError 族基类 = ecInternal *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

type
  { 后端种类。平台原生在前，wkFake 收尾（对齐 TWebviewKind 惯例）。
    S1 仅 wkFake 可用；S2a 新增 wkWasm（wasm canvas attach，枚举在
    wkFake 前一位保证 High 仍为 fake）；其余随波次接入。 }
  TWindowKind = (wkGtk, wkSdl2, wkWin32, wkCocoa, wkAndroid, wkUIKit, wkWasm, wkFake);

  { 平台原生窗口句柄（X11 XID / HWND / NSWindow* / ANativeWindow*；
    Wayland 为 nil——诚实差异见 CONTRACT §2.1）。仅供嵌入场景，本家族
    不解释其内容。 }
  TWindowNativeHandle = type Pointer;

  {** 窗口选项。 *}
  TWindowOptions = record
    Title: string;                      // 默认 ''
    Width: Integer;                     // 默认 1024；<=0 时用引擎默认
    Height: Integer;                    // 默认 768
    MinWidth: Integer;                  // 0 = 不设限制
    MinHeight: Integer;
    MaxWidth: Integer;                  // 0 = 不设限制
    MaxHeight: Integer;
    Resizable: Boolean;                 // 默认 True
    Maximized: Boolean;                 // 默认 False；启动即最大化
    ParentHandle: TWindowNativeHandle;  // 默认 nil；非 nil = embedded attach
  end;

  TWindowEventKind =
    (weCloseRequested, weResized, weMoved, weFocusIn, weFocusOut, weScaleChanged);

  TWindowEvent = record
    Kind: TWindowEventKind;
    Width: Integer;   // weResized：新客户区宽（物理像素）
    Height: Integer;  // weResized：新客户区高（物理像素）
    X: Integer;       // weMoved：屏幕坐标（物理像素；Wayland 不发）
    Y: Integer;
    NewScale: Double; // weScaleChanged：新 scale factor
  end;

  TWindowEventHandler = reference to procedure(const AEvent: TWindowEvent);
  TWindowEventMethod = procedure(const AEvent: TWindowEvent) of object;
  TWindowEventProc = procedure(const AEvent: TWindowEvent);

{ 默认选项：字段缺省值唯一权威（CONTRACT §3.2） }
function DefaultWindowOptions: TWindowOptions;

{ 选项校验：违反不变量抛 EWindowInvalidState。
  规则：
  - 尺寸字段一律 >= 0；<=0 的 Width/Height 表示引擎默认
  - MaxWidth/MaxHeight 与 MinWidth/MinHeight 同时为正时必须满足 max >= min }
procedure CheckWindowOptions(const AOptions: TWindowOptions);

{ EWindowError 族 —— 派生自框架根异常，类目定值见单元头注释表 }
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

function DefaultWindowOptions: TWindowOptions;
begin
  Result.Title := '';
  Result.Width := 1024;
  Result.Height := 768;
  Result.MinWidth := 0;
  Result.MinHeight := 0;
  Result.MaxWidth := 0;
  Result.MaxHeight := 0;
  Result.Resizable := True;
  Result.Maximized := False;
  Result.ParentHandle := nil;
end;

procedure CheckWindowOptions(const AOptions: TWindowOptions);
begin
  if (AOptions.Width < 0) or (AOptions.Height < 0) then
    raise EWindowInvalidState.Create('Width/Height must be >= 0');
  if (AOptions.MinWidth < 0) or (AOptions.MinHeight < 0) then
    raise EWindowInvalidState.Create('MinWidth/MinHeight must be >= 0');
  if (AOptions.MaxWidth < 0) or (AOptions.MaxHeight < 0) then
    raise EWindowInvalidState.Create('MaxWidth/MaxHeight must be >= 0');

  if (AOptions.MinWidth > 0) and (AOptions.MaxWidth > 0)
    and (AOptions.MaxWidth < AOptions.MinWidth) then
    raise EWindowInvalidState.Create('MaxWidth must be >= MinWidth');
  if (AOptions.MinHeight > 0) and (AOptions.MaxHeight > 0)
    and (AOptions.MaxHeight < AOptions.MinHeight) then
    raise EWindowInvalidState.Create('MaxHeight must be >= MinHeight');
end;

{ EWindowError 族 }

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
