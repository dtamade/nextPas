unit nextpas.core.window.view.intf;
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.window.view.base;
type IWindowView=interface['{A1B2C3D4-1004-4F60-9A8B-C0D1E2F3A103}'] function GetId:TWindowViewId; function GetOptions:TWindowViewOptions; procedure SetOptions(const AOptions:TWindowViewOptions); property Id:TWindowViewId read GetId; property Options:TWindowViewOptions read GetOptions write SetOptions; end;
IWindowViewHost=interface['{A1B2C3D4-1004-4F60-9A8B-C0D1E2F3A104}'] function CreateView(const AOptions:TWindowViewOptions):IWindowView; procedure DestroyView(AId:TWindowViewId); function FindView(AId:TWindowViewId):IWindowView; end;
implementation
end.
