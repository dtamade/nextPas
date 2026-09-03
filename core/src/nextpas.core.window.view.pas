unit nextpas.core.window.view;
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.window.view.base,nextpas.core.window.view.intf,nextpas.core.window.view.impl;
type TWindowViewId=nextpas.core.window.view.base.TWindowViewId;TWindowViewOptions=nextpas.core.window.view.base.TWindowViewOptions;EWindowViewError=nextpas.core.window.view.base.EWindowViewError;EWindowViewInvalidOptions=nextpas.core.window.view.base.EWindowViewInvalidOptions;IWindowView=nextpas.core.window.view.intf.IWindowView;IWindowViewHost=nextpas.core.window.view.intf.IWindowViewHost;
function DefaultWindowViewOptions:TWindowViewOptions;inline;
procedure CheckWindowViewOptions(const AOptions:TWindowViewOptions);inline;
function WindowViewGrowCapacity(ACurrent:Integer):Integer;inline;
implementation
function DefaultWindowViewOptions:TWindowViewOptions;inline;begin Result:=nextpas.core.window.view.base.DefaultWindowViewOptions;end;
procedure CheckWindowViewOptions(const AOptions:TWindowViewOptions);inline;begin nextpas.core.window.view.impl.CheckWindowViewOptions(AOptions);end;
function WindowViewGrowCapacity(ACurrent:Integer):Integer;inline;begin Result:=nextpas.core.window.view.impl.WindowViewGrowCapacity(ACurrent);end;
end.
