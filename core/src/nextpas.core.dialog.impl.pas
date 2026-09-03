unit nextpas.core.dialog.impl;
{$I nextpas.core.settings.inc}
{ Owner-faithful physical impl — dialog L3 shim canonical single source:
  单源 bytes.ops WindowDialogGrowCapacity 0→32→2× direct L2→L1 inline 零拷贝 O(1)均摊不经 window.impl,
  CheckWindowDialogOptions inline 薄分支，守四件套与 L0-L3/INV-3 零后端，heaptrc 0，资源托管释放不丢，
  业务以 core/docs/dialog/CONTRACT.md 为准 缺能力反哺 dialog/bytes.ops owner. }
interface
uses nextpas.core.base,nextpas.core.dialog.base,nextpas.core.dialog.intf,nextpas.core.bytes.ops;
function WindowDialogGrowCapacity(ACurrent:Integer):Integer;inline;
procedure CheckWindowDialogOptions(const AOptions:TWindowDialogOptions);inline;
implementation
function WindowDialogGrowCapacity(ACurrent:Integer):Integer;inline;begin // single source bytes.ops direct L2→L1 inline 零拷贝 O(1) 0→32→2× via BytesGrowCapacity
Result:=BytesGrowCapacity(ACurrent);end;
procedure CheckWindowDialogOptions(const AOptions:TWindowDialogOptions);inline;begin if (AOptions.Title='') and (AOptions.Message='') then raise EWindowDialogInvalidOptions.Create('Title or Message required');end;
end.
