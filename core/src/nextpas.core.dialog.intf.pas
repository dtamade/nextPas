unit nextpas.core.dialog.intf;
{$I nextpas.core.settings.inc}
{ Owner-faithful physical intf — dialog L3 shim canonical single source:
  守四件套 base←intf←impl←门面 与 L0-L3/INV-3 零后端，inline 零拷贝. }
interface
uses nextpas.core.dialog.base;
type IWindowDialog=interface['{A1B2C3D4-1005-4F60-9A8B-C0D1E2F3A105}'] function GetOptions:TWindowDialogOptions; function GetResult:TWindowDialogResult; procedure Show; procedure Close(AResult:TWindowDialogResult); property Options:TWindowDialogOptions read GetOptions; property DialogResult:TWindowDialogResult read GetResult; end;
IWindowDialogHost=interface['{A1B2C3D4-1005-4F60-9A8B-C0D1E2F3A106}'] function CreateDialog(const AOptions:TWindowDialogOptions):IWindowDialog; end;
TWindowDialogHandler=reference to procedure(const ADialog:IWindowDialog);
implementation
end.
