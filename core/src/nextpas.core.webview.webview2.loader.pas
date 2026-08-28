unit nextpas.core.webview.webview2.loader;

{** @desc WebView2 动态装载与符号解析（家族内唯一触碰 WebView2
       Loader 的单元；原语来自 platform.dl）。

       探测目标：WebView2Loader.dll（Windows）/ libWebView2Loader.so
       （wine 下可能）。Linux 原生返回不可用；Windows/wine 下尝试
       dlopen 并绑定 CreateCoreWebView2EnvironmentWithOptions。

       装载状态进程级幂等：TryLoadWebView2 首次成功后缓存，后续
       直接复用；UnloadWebView2 全量释放。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.webview.webview2.ffi;

type
  TWebView2LoadInfo = record
    Loaded: Boolean;
    DllName: string;
  end;

function TryLoadWebView2(out AInfo: TWebView2LoadInfo): Boolean;
procedure UnloadWebView2;
function WebView2LoadInfo: TWebView2LoadInfo; inline;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TWebView2LoadInfo;
  GLib: TPlatformLibrary;

function TryDlOpenWebView2(out AHit: string): Boolean;
const
  Cands: array[0..2] of string = (
    'WebView2Loader.dll',
    'libWebView2Loader.so',
    'WebView2Loader.so'
  );
var
  I: Integer;
  LL: TPlatformLibrary;
begin
  for I := 0 to High(Cands) do
    if platform_dl_load(Cands[I], [dlfLazy], LL) then
    begin
      GLib := LL;
      AHit := Cands[I];
      Exit(True);
    end;
  Result := False;
  AHit := '';
end;

function TryLoadWebView2(out AInfo: TWebView2LoadInfo): Boolean;
var
  LHit: string;
  P: Pointer;
begin
  if GLoaded then
  begin
    AInfo := GInfo;
    Exit(True);
  end;
  if GLoading then
    Exit(False);
  FillChar(AInfo, SizeOf(AInfo), 0);
  GLoading := True;
  try
    if not TryDlOpenWebView2(LHit) then
      Exit(False);
    if GLib.Sym('CreateCoreWebView2EnvironmentWithOptions', P) <> 0 then
    begin
      GLib.Close;
      FillChar(GLib, SizeOf(GLib), 0);
      Exit(False);
    end;
    CreateCoreWebView2EnvironmentWithOptions :=
      TCreateCoreWebView2EnvironmentWithOptions(P);
    GLoaded := True;
    GInfo.Loaded := True;
    GInfo.DllName := LHit;
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadWebView2;
begin
  if not GLoaded then Exit;
  GLib.Close;
  FillChar(GLib, SizeOf(GLib), 0);
  CreateCoreWebView2EnvironmentWithOptions := nil;
  GLoaded := False;
  GInfo := Default(TWebView2LoadInfo);
end;

function WebView2LoadInfo: TWebView2LoadInfo; inline;
begin
  Result := GInfo;
end;

end.
