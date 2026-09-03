unit nextpas.core.window.input.intf;
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.window.input.base;
type IWindowInput=interface['{A1B2C3D4-1003-4F60-9A8B-C0D1E2F3A102}'] procedure HandleEvent(const AEvent:TWindowInputEvent); procedure HandleEventView(const AEvent:TWindowInputEventView); function GetOptions:TWindowInputOptions; procedure SetOptions(const AOptions:TWindowInputOptions); property Options:TWindowInputOptions read GetOptions write SetOptions; end;
TWindowInputHandler=reference to procedure(const AEvent:TWindowInputEvent);
TWindowInputMethod=procedure(const AEvent:TWindowInputEvent) of object;
TWindowInputProc=procedure(const AEvent:TWindowInputEvent);
TWindowInputViewHandler=reference to procedure(const AEvent:TWindowInputEventView);
TWindowInputViewMethod=procedure(const AEvent:TWindowInputEventView) of object;
TWindowInputViewProc=procedure(const AEvent:TWindowInputEventView);
implementation
end.
