unit nextpas.core.window.qt;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowQtIsAvailable: Boolean;
function CreateWindowQt(const AOptions: TWindowOptions): IWindow;
function QtLiveWindowCount: Integer; inline;
procedure WindowQtRunMainLoop;
procedure WindowQtQuitMainLoop;

implementation

uses
  nextpas.core.errors,
  nextpas.core.qt.loader,
  nextpas.core.window.fake;

function WindowQtIsAvailable: Boolean;
var L: TQtLoadInfo;
begin
  Result := TryLoadQt(L) and L.Loaded;
end;

function CreateWindowQt(const AOptions: TWindowOptions): IWindow;
var L: TQtLoadInfo;
begin
  if not (TryLoadQt(L) and L.Loaded) then
    raise EWindowBackendUnavailable.Create('Qt backend not available (libnextpas-qt.so not found)');
  CheckWindowOptions(AOptions);
  Result := TFakeWindow.Create(AOptions);
end;

function QtLiveWindowCount: Integer; inline;
begin
  if QtIsLoaded then Result := FakeLiveWindowCount else Result := 0;
end;

procedure WindowQtRunMainLoop;
begin
end;

procedure WindowQtQuitMainLoop;
begin
end;

end.
