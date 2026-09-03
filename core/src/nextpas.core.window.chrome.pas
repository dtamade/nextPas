unit nextpas.core.window.chrome;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.window.chrome.base,
  nextpas.core.window.chrome.intf,
  nextpas.core.window.chrome.impl,
  nextpas.core.math.easing;

type
  TWindowChromeOptions = nextpas.core.window.chrome.base.TWindowChromeOptions;
  EWindowChromeError = nextpas.core.window.chrome.base.EWindowChromeError;
  EWindowChromeInvalidOptions = nextpas.core.window.chrome.base.EWindowChromeInvalidOptions;
  IWindowChrome = nextpas.core.window.chrome.intf.IWindowChrome;
  TWindowChromeImpl = nextpas.core.window.chrome.impl.TWindowChromeImpl;
  TEasingFunction = nextpas.core.math.easing.TEasingFunction;

function DefaultWindowChromeOptions: TWindowChromeOptions; inline;
procedure CheckWindowChromeOptions(const AOptions: TWindowChromeOptions); inline;
procedure CheckWindowChromeOpacity(const AOpacity: Double); inline;
function WindowChromeGrowCapacity(ACurrent: Integer): Integer; inline;
function WindowChromeProgress(const AElapsedMs, AAnimationMs: Integer): Double; inline;
function WindowChromeEasedProgress(const AElapsedMs, AAnimationMs: Integer; const AEase: TEasingFunction): Double; inline;
function WindowChromeTickOpacity(const AFromOpacity, AToOpacity: Double; const AElapsedMs, AAnimationMs: Integer; const AEase: TEasingFunction): Double; inline;
function CreateWindowChrome: IWindowChrome; inline; overload;
function CreateWindowChrome(const AOptions: TWindowChromeOptions): IWindowChrome; inline; overload;

implementation

function DefaultWindowChromeOptions: TWindowChromeOptions; inline;
begin
  Result := nextpas.core.window.chrome.base.DefaultWindowChromeOptions;
end;

procedure CheckWindowChromeOptions(const AOptions: TWindowChromeOptions); inline;
begin
  nextpas.core.window.chrome.impl.CheckWindowChromeOptions(AOptions);
end;

procedure CheckWindowChromeOpacity(const AOpacity: Double); inline;
begin
  nextpas.core.window.chrome.impl.CheckWindowChromeOpacity(AOpacity);
end;

function WindowChromeGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  // single source via bytes.ops BytesGrowCapacity inline 零拷贝 O(1)均摊, SizeUInt 重载零调用已剔除
  Result := nextpas.core.window.chrome.impl.WindowChromeGrowCapacity(ACurrent);
end;

function WindowChromeProgress(const AElapsedMs, AAnimationMs: Integer): Double; inline;
begin
  Result := nextpas.core.window.chrome.impl.WindowChromeProgress(AElapsedMs, AAnimationMs);
end;

function WindowChromeEasedProgress(const AElapsedMs, AAnimationMs: Integer; const AEase: TEasingFunction): Double; inline;
begin
  Result := nextpas.core.window.chrome.impl.WindowChromeEasedProgress(AElapsedMs, AAnimationMs, AEase);
end;

function WindowChromeTickOpacity(const AFromOpacity, AToOpacity: Double; const AElapsedMs, AAnimationMs: Integer; const AEase: TEasingFunction): Double; inline;
begin
  Result := nextpas.core.window.chrome.impl.WindowChromeTickOpacity(AFromOpacity, AToOpacity, AElapsedMs, AAnimationMs, AEase);
end;

function CreateWindowChrome: IWindowChrome; inline; overload;
begin
  Result := nextpas.core.window.chrome.impl.CreateWindowChrome;
end;

function CreateWindowChrome(const AOptions: TWindowChromeOptions): IWindowChrome; inline; overload;
begin
  Result := nextpas.core.window.chrome.impl.CreateWindowChrome(AOptions);
end;

end.
