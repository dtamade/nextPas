unit nextpas.core.tui.experimental;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui,
  nextpas.core.tui.image_cap,
  nextpas.core.tui.sixel,
  nextpas.core.tui.image_mgr,
  nextpas.core.tui.clipboard;

type
  TImageProtocol = nextpas.core.tui.image_cap.TImageProtocol;
  TClipboardMethod = nextpas.core.tui.clipboard.TClipboardMethod;
  TClipboard = nextpas.core.tui.clipboard.TClipboard;

const
  ipAuto = nextpas.core.tui.image_cap.ipAuto;
  ipKitty = nextpas.core.tui.image_cap.ipKitty;
  ipSixel = nextpas.core.tui.image_cap.ipSixel;
  ipHalfBlock = nextpas.core.tui.image_cap.ipHalfBlock;

  cmOSC52 = nextpas.core.tui.clipboard.cmOSC52;
  cmExternal = nextpas.core.tui.clipboard.cmExternal;
  cmNone = nextpas.core.tui.clipboard.cmNone;

function DetectImageProtocol: TImageProtocol; inline;

implementation

function DetectImageProtocol: TImageProtocol;
begin
  Result := nextpas.core.tui.image_cap.DetectImageProtocol;
end;

end.
