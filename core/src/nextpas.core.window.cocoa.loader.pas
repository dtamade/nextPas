unit nextpas.core.window.cocoa.loader;

{** @desc Cocoa 动态装载（家族内唯一触 platform.dl 的单元）。
       原语一律来自 nextpas.core.platform.dl，禁用 FPC DynLibs。

       macOS 上探测 libobjc + libdispatch + AppKit；其他宿主诚实失败
       （Loaded=False）。stage0 的 objcclass 能力 probe 结果亦在此收敛：
       当前以纯 C 的 objc_msgSend 形态工作，无需 objectivec1 modeswitch。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.dl,
  nextpas.core.window.cocoa.ffi;

type
  TWindowCocoaLoadInfo = record
    Loaded: Boolean;
    HasDispatch: Boolean;
  end;

function TryLoadWindowCocoa(out AInfo: TWindowCocoaLoadInfo): Boolean;
procedure UnloadWindowCocoa;
function WindowCocoaLoadInfo: TWindowCocoaLoadInfo;
function WindowCocoaIsLoaded: Boolean;

implementation

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TWindowCocoaLoadInfo;
  GObjCLib, GDispatchLib, GAppKitLib: TPlatformLibrary;

function TryDlOpen(var ALib: TPlatformLibrary; const ASonames: array of string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ASonames) do
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
      Exit(True);
  Result := False;
end;

function BindReq(AVarAddr: Pointer; const AName: string): Boolean;
var
  LAddr: Pointer;
begin
  if GObjCLib.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  if GDispatchLib.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  if GAppKitLib.Sym(PAnsiChar(AName), LAddr) = 0 then
  begin
    PPointer(AVarAddr)^ := LAddr;
    Exit(True);
  end;
  Result := False;
end;

procedure ReleaseAll;
begin
  platform_dl_release(GObjCLib);
  platform_dl_release(GDispatchLib);
  platform_dl_release(GAppKitLib);
end;

function TryLoadWindowCocoa(out AInfo: TWindowCocoaLoadInfo): Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      BindReq(@objc_getClass, 'objc_getClass') and
      BindReq(@sel_registerName, 'sel_registerName') and
      BindReq(@objc_msgSend, 'objc_msgSend') and
      BindReq(@dispatch_get_main_queue, 'dispatch_get_main_queue') and
      BindReq(@dispatch_async, 'dispatch_async');
    // dispatch_async_f optional
    BindReq(@dispatch_async_f, 'dispatch_async_f');
  end;

begin
  if GLoaded then
  begin
    AInfo := GInfo;
    Exit(True);
  end;
  if GLoading then Exit(False);
  FillChar(AInfo, SizeOf(AInfo), 0);
  GLoading := True;
  try
    // On Linux, these won't exist → honest unavailable
    if not (TryDlOpen(GObjCLib, ['libobjc.so.4', 'libobjc.so']) and
            TryDlOpen(GDispatchLib, ['libdispatch.so.0', 'libdispatch.so'])) then
    begin
      ReleaseAll;
      Exit(False);
    end;
    // AppKit is macOS only; on Linux we don't require it for probe,
    // but cocoa backend will still be considered unavailable without it.
    // For load truth, we require AppKit presence on macOS host only.
    // On Linux we treat as unavailable (since cocoa can't run).
    TryDlOpen(GAppKitLib, ['/System/Library/Frameworks/AppKit.framework/AppKit']);
    if not BindAll then
    begin
      ReleaseAll;
      Exit(False);
    end;
    // On Linux, AppKit missing → mark not loaded to keep honest
    if not GAppKitLib.IsValid then
    begin
      ReleaseAll;
      Exit(False);
    end;
    GLoaded := True;
    GInfo.Loaded := True;
    GInfo.HasDispatch := Assigned(dispatch_get_main_queue);
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadWindowCocoa;
begin
  if not GLoaded then Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TWindowCocoaLoadInfo);
end;

function WindowCocoaLoadInfo: TWindowCocoaLoadInfo;
begin
  Result := GInfo;
end;

function WindowCocoaIsLoaded: Boolean;
begin
  Result := GLoaded;
end;

end.
