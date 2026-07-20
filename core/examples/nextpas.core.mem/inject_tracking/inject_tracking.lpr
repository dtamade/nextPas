program inject_tracking;
{ Demo: DefaultAllocator inject + TTrackingAllocator.
  FreeMemOf may skip AAllocator.FreeMem for same-heap sized free — use
  AAllocator.FreeMem when you need tracking counts. }
{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem;

var
  Base: IAllocator;
  Track: TTrackingAllocator;
  Wrap: IAllocator;
  P: Pointer;
begin
  WriteLn('mem-example=inject_tracking');

  Base := DefaultAllocator;
  Track := TTrackingAllocator.Create(Base);
  Wrap := Track;

  P := Wrap.GetMem(64);
  if P = nil then
  begin
    WriteLn('status=fail alloc');
    Halt(1);
  end;
  if Track.ActiveAllocCount <> 1 then
  begin
    WriteLn('status=fail track_alloc');
    Halt(1);
  end;

  { Observe free: must call interface FreeMem, not FreeMemOf. }
  Wrap.FreeMem(P);
  if Track.ActiveAllocCount <> 0 then
  begin
    WriteLn('status=fail track_free');
    Halt(1);
  end;

  WriteLn('status=pass');
end.
