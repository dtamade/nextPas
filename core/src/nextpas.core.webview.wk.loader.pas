unit nextpas.core.webview.wk.loader;

{** @desc WKWebView 装载探针（Wave 3 桩）。

       - Linux/Windows：恒返回 False（WK 仅 Darwin）
       - Darwin：预留 dlopen 探针（WebKit.framework / libobjc），当前桩仍
         返回 False，待 stage0 ObjC 能力探通后启用真实装载。
       - 幂等缓存，与 gtk/webview2 loader 同纪律。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.wk.ffi;

type
  TWkLoadInfo = WKLoadInfo;

function TryLoadWk(out AInfo: TWkLoadInfo): Boolean;
function WkLoadInfo: TWkLoadInfo; inline;

implementation

var
  GInfo: TWkLoadInfo;
  GProbed: Boolean = False;

function TryLoadWk(out AInfo: TWkLoadInfo): Boolean;
begin
  if GProbed then
  begin
    AInfo := GInfo;
    Exit(GInfo.Loaded);
  end;
  GProbed := True;
  // Darwin 真实现将经 nextpas.core.platform.dl dlopen WebKit.framework / libobjc
  GInfo.Loaded := False;
  GInfo.DllName := '';
  // 桩：当前宿主非 Darwin，一律不可用；Darwin 预留位不主动 dlopen
  // 真实装载待 stage0 对 {$modeswitch objectivec1} 探通后接
  // libobjc / WebKit.framework 的 dlopen + objc_getClass 探针
  AInfo := GInfo;
  Result := False;
end;

function WkLoadInfo: TWkLoadInfo; inline;
begin
  if not GProbed then
    TryLoadWk(Result)
  else
    Result := GInfo;
end;

end.
