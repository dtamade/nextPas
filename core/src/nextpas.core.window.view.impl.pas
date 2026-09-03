unit nextpas.core.window.view.impl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.window.view.base,
  nextpas.core.window.view.intf,
  nextpas.core.bytes.ops;

function WindowViewGrowCapacity(ACurrent: Integer): Integer; inline;

procedure CheckWindowViewOptions(const AOptions: TWindowViewOptions); inline;

implementation

function WindowViewGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  // single source 0→32→2× via bytes.ops BytesGrowCapacity inline 零拷贝 O(1)均摊 L2→L1 direct, 调用点复制约 16 bytes
  Result := BytesGrowCapacity(ACurrent);
end;

procedure CheckWindowViewOptions(const AOptions: TWindowViewOptions); inline;
begin
  if (AOptions.Width < 0) or (AOptions.Height < 0) then
    raise EWindowViewInvalidOptions.CreateFmt('Width/Height must be >=0 (got %d,%d)', [AOptions.Width, AOptions.Height]);
end;

end.
