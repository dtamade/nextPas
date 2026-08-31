unit nextpas.core.app.base;

{** @desc nextpas.core.app L3 应用壳：类型根。
       复用 webview 的窗口选项与错误分类，保持与 Tauri 的 "App"
       心智一致：App 拥有窗口生命周期与主循环，窗口承载 webview 内容。

       只依赖 errors + webview.base（类型别名不产生循环）；禁止 uses
       本家族实现/factory 单元。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.webview.base;

type
  { 应用选项 = 窗口选项的语义别名（与 webview 同源，零重复校验）。 }
  TAppOptions = nextpas.core.webview.base.TWebviewOptions;
  TAppKind = nextpas.core.webview.base.TWebviewKind;
  TAppNativeHandle = nextpas.core.webview.base.TWebviewNativeHandle;

  EAppError = class(EWebviewError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EAppBackendUnavailable = class(EAppError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EAppInvalidState = class(EAppError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  EAppClosed = class(EAppError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

function DefaultAppOptions: TAppOptions; inline;
procedure CheckAppOptions(const AOptions: TAppOptions); inline;

implementation

function DefaultAppOptions: TAppOptions;
begin
  Result := nextpas.core.webview.base.DefaultWebviewOptions;
end;

procedure CheckAppOptions(const AOptions: TAppOptions);
begin
  nextpas.core.webview.base.CheckWebviewOptions(AOptions);
end;

class function EAppError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EAppBackendUnavailable.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

class function EAppInvalidState.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EAppClosed.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

end.
