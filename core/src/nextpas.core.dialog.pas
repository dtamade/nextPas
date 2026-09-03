unit nextpas.core.dialog;
{$I nextpas.core.settings.inc}
{ Owner-faithful canonical facade — dialog L3 shim single source (physical nextpas.core.dialog.*):
  四件套 base←intf←impl←门面 per dialog Owner, 不经 window 门面, 守 L0-L3/INV-3 零后端,
  单源 bytes.ops WindowDialogGrowCapacity 0→32→2× direct L2→L1 inline 零拷贝 O(1)均摊不经 window.impl, heaptrc 0,
  资源托管释放不丢, 业务以 core/docs/dialog/CONTRACT.md 为准 缺能力反哺 dialog/bytes.ops owner;
  window.dialog* 四件套别名已迁移移除. }
interface
uses nextpas.core.dialog.base,nextpas.core.dialog.intf,nextpas.core.dialog.impl;
type TWindowDialogKind=nextpas.core.dialog.base.TWindowDialogKind;TWindowDialogOptions=nextpas.core.dialog.base.TWindowDialogOptions;TWindowDialogResult=nextpas.core.dialog.base.TWindowDialogResult;EWindowDialogError=nextpas.core.dialog.base.EWindowDialogError;EWindowDialogInvalidOptions=nextpas.core.dialog.base.EWindowDialogInvalidOptions;IWindowDialog=nextpas.core.dialog.intf.IWindowDialog;IWindowDialogHost=nextpas.core.dialog.intf.IWindowDialogHost;TWindowDialogHandler=nextpas.core.dialog.intf.TWindowDialogHandler;
function DefaultWindowDialogOptions:TWindowDialogOptions;inline;
procedure CheckWindowDialogOptions(const AOptions:TWindowDialogOptions);inline;
function WindowDialogGrowCapacity(ACurrent:Integer):Integer;inline;
implementation
function DefaultWindowDialogOptions:TWindowDialogOptions;inline;begin Result:=nextpas.core.dialog.base.DefaultWindowDialogOptions;end;
procedure CheckWindowDialogOptions(const AOptions:TWindowDialogOptions);inline;begin nextpas.core.dialog.impl.CheckWindowDialogOptions(AOptions);end;
function WindowDialogGrowCapacity(ACurrent:Integer):Integer;inline;begin Result:=nextpas.core.dialog.impl.WindowDialogGrowCapacity(ACurrent);end;
end.
