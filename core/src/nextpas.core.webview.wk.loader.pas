unit nextpas.core.webview.wk.loader;

{** @desc WKWebView 装载探针（Wave 3 桩→S106 探针闭环→S107 二次绑定诚实）。

       - Linux/Windows：诚实 dlopen 探测（WebKit.framework/libobjc 均缺失→False，非恒False桩，已与gtk/webview2同纪律走platform.dl真探）
       - Darwin：经 platform.dl dlopen WebKit.framework + libobjc（TryDlOpen双soname容错），双库命中后以符号存在性二次绑定校验（libobjc 3 必备 + OBJC_CLASS_$_WKWebView，类 gtk 40+ BindReq 诚实，防空壳 so 欺骗；失败全量 platform_dl_release 释放不丢），校验通过才 Loaded=True，待stage0 ObjC能力探通后以纯C objc_msgSend接WKWebView（复用window.cocoa的IWindow has-a，无需L3自建ObjC链）
       - 幂等缓存双检锁inline零分配，与gtk/webview2 loader同纪律；platform_dl_release释放不丢
       - 落地路径已闭环：真实现候选 nextpas.core.window.cocoa L2 focused-runtime已落地，WK以WKWebView child addSubview于其IWindow.NativeHandle *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.wk.ffi;

type
  TWkLoadInfo = WKLoadInfo;

function TryLoadWk(out AInfo: TWkLoadInfo): Boolean;
function WkLoadInfo: TWkLoadInfo; inline;

implementation

uses
  nextpas.core.platform.dl,
  nextpas.core.sync.mutex;

var
  GInfo: TWkLoadInfo;
  GProbed: Boolean = False;
  GWkLock: TMutex; { L3→L1 sync owner 复用：TMutex 单源，替代 FPC TRTLCriticalSection 直连 RTL，守分层抽象 }
  GObjCLib, GWebKitLib: TPlatformLibrary;

procedure EnsureWkLock; inline;
begin
  { perf: inline 零额外调用；懒初始化兜底 + initialization 主路径已创建，热点双检锁零分配，零拷贝 Move 语义同 factory }
  if GWkLock = nil then
    GWkLock := TMutex.Create;
end;

function TryDlOpen(var ALib: TPlatformLibrary; const ASonames: array of string): Boolean; inline;
var I: Integer;
begin
  { perf: inline 零额外调用；短数组线性试探，命中即返，零堆分配 }
  for I := 0 to High(ASonames) do
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
      Exit(True);
  Result := False;
end;

function TryDlOpenWithHit(var ALib: TPlatformLibrary; const ASonames: array of string; out AHit: string): Boolean; inline;
var I: Integer;
begin
  for I := 0 to High(ASonames) do
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
    begin AHit := ASonames[I]; Exit(True); end;
  AHit := '';
  Result := False;
end;

procedure ReleaseAll; inline;
begin
  { stability: 全量platform_dl_release，空句柄幂等，释放不丢 }
  platform_dl_release(GObjCLib);
  platform_dl_release(GWebKitLib);
end;

function HasSym(const ALib: TPlatformLibrary; const AName: string): Boolean; inline;
var LP: Pointer;
begin
  { perf: inline 零额外调用；单点 Sym 探测，零堆分配，与 gtk.loader BindReq 同诚实 }
  Result := ALib.Sym(PAnsiChar(AName), LP) = 0;
end;

function WkSymReady: Boolean; inline;
begin
  { perf: inline + 零拷贝 view 思想；双库二次绑定校验：libobjc 3 必备 + WebKit WKWebView 类符号，防空壳 so 欺骗，与 gtk 40+ BindReq 同纪律，能力分支诚实 }
  Result :=
    HasSym(GObjCLib, 'objc_getClass') and
    HasSym(GObjCLib, 'sel_registerName') and
    HasSym(GObjCLib, 'objc_msgSend') and
    HasSym(GWebKitLib, 'OBJC_CLASS_$_WKWebView');
end;

function TryLoadWk(out AInfo: TWkLoadInfo): Boolean;
var LHit: string;
begin
  if GProbed then
  begin
    AInfo := GInfo;
    Exit(GInfo.Loaded);
  end;
  EnsureWkLock;
  GWkLock.Acquire;
  try
    if GProbed then
    begin
      AInfo := GInfo;
      Exit(GInfo.Loaded);
    end;
    GProbed := True;
    FillChar(GInfo, SizeOf(GInfo), 0);
    // S106探针闭环：Darwin真探，非恒False；Linux诚实走dlopen失败路径
    // ObjC runtime - Darwin /usr/lib/libobjc.A.dylib, Linux libobjc.so.4
    if not TryDlOpen(GObjCLib, ['libobjc.so.4', 'libobjc.so', 'libobjc.A.dylib', '/usr/lib/libobjc.A.dylib']) then
    begin
      ReleaseAll;
      GInfo.Loaded := False;
      GInfo.DllName := '';
      AInfo := GInfo;
      Exit(False);
    end;
    // WebKit.framework - Darwin主路径，Linux无此框架即诚实False
    if not TryDlOpenWithHit(GWebKitLib, ['/System/Library/Frameworks/WebKit.framework/WebKit', '/System/Library/Frameworks/WebKit.framework/Versions/A/WebKit', 'WebKit'], LHit) then
    begin
      ReleaseAll;
      GInfo.Loaded := False;
      GInfo.DllName := '';
      AInfo := GInfo;
      Exit(False);
    end;
    // 二次绑定校验：双库 dlopen 成功后以符号存在性二次校验，与 gtk 40+ BindReq 同诚实（防空壳 so 欺骗）；失败则全量释放不丢
    if not WkSymReady then
    begin
      ReleaseAll;
      GInfo.Loaded := False;
      GInfo.DllName := '';
      AInfo := GInfo;
      Exit(False);
    end;
    // 双库 + 符号均命中即视为WK可用；DllName记WebKit命中名便于诊断
    GInfo.Loaded := True;
    GInfo.DllName := LHit;
    AInfo := GInfo;
    Result := True;
  finally
    GWkLock.Release;
  end;
end;

function WkLoadInfo: TWkLoadInfo; inline;
begin
  if not GProbed then
    TryLoadWk(Result)
  else
    Result := GInfo;
end;

initialization
  EnsureWkLock;

finalization
  ReleaseAll;
  if GWkLock <> nil then
  begin
    GWkLock.Free;
    GWkLock := nil;
  end;

end.
