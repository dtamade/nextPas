unit nextpas.core.window.fake.loader;
{$I nextpas.core.settings.inc}
interface
// Fake backend requires no dynamic loading; loader is no-op placeholder.
function FakeLoaderIsAvailable: Boolean; inline;
implementation
function FakeLoaderIsAvailable: Boolean; inline; begin Result:=True; end;
end.
