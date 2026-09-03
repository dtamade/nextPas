unit nextpas.core.dialog.base;
{$I nextpas.core.settings.inc}
{ Owner-faithful physical base — dialog L3 shim canonical single source:
  base 仅纯数据类型，零后端，守四件套 base←intf←impl←门面 与 L0-L3/INV-3，
  性能 inline 零拷贝，业务以 core/docs/dialog/CONTRACT.md 为准，缺能力反哺 dialog/bytes.ops owner. }
interface
uses nextpas.core.base,nextpas.core.errors;
type TWindowDialogKind=(wdkAlert,wdkConfirm,wdkPrompt,wdkModal);
TWindowDialogOptions=record Kind:TWindowDialogKind;Title:string;Message:string;DefaultText:string;ParentId:UInt32;Modal:Boolean;end;
TWindowDialogResult=(wdrNone,wdrOk,wdrCancel,wdrYes,wdrNo);
function DefaultWindowDialogOptions:TWindowDialogOptions;inline;
type EWindowDialogError=class(ENextPasError) protected class function DefaultCategory:TErrorCategory;override;end;
EWindowDialogInvalidOptions=class(EWindowDialogError) protected class function DefaultCategory:TErrorCategory;override;end;
implementation
function DefaultWindowDialogOptions:TWindowDialogOptions;inline;begin Result.Kind:=wdkAlert;Result.Title:='';Result.Message:='';Result.DefaultText:='';Result.ParentId:=0;Result.Modal:=True;end;
class function EWindowDialogError.DefaultCategory:TErrorCategory;begin Result:=ecInternal;end;
class function EWindowDialogInvalidOptions.DefaultCategory:TErrorCategory;begin Result:=ecInternal;end;
end.
