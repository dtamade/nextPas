unit nextpas.core.window.input.impl;
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.base,nextpas.core.window.input.base,nextpas.core.window.input.intf,nextpas.core.bytes.ops;
function WindowInputGrowCapacity(ACurrent:Integer):Integer;inline; // single source bytes.ops direct L2→L1 inline 零拷贝 O(1) 0→32→2× via BytesGrowCapacity, no window.impl cross-Owner
procedure CheckWindowInputOptions(const AOptions:TWindowInputOptions);inline;
// view/managed bridge — inline O(1) zero-copy view via base WindowInputEventToView/FromView (TStringView.FromStr/ToSpan single source bytes.ops), no alloc for view, managed copy single Move
function WindowInputEventToView(const AEvent:TWindowInputEvent):TWindowInputEventView;inline;
function WindowInputEventFromView(const AView:TWindowInputEventView):TWindowInputEvent;inline;
implementation
function WindowInputGrowCapacity(ACurrent:Integer):Integer;inline;begin // single source bytes.ops direct L2→L1 inline 零拷贝 O(1) 0→32→2× via BytesGrowCapacity, no window.impl cross-Owner
Result:=BytesGrowCapacity(ACurrent);end;
procedure CheckWindowInputOptions(const AOptions:TWindowInputOptions);inline;begin end;
function WindowInputEventToView(const AEvent:TWindowInputEvent):TWindowInputEventView;inline;begin Result:=nextpas.core.window.input.base.WindowInputEventToView(AEvent);end;
function WindowInputEventFromView(const AView:TWindowInputEventView):TWindowInputEvent;inline;begin Result:=nextpas.core.window.input.base.WindowInputEventFromView(AView);end;
end.
