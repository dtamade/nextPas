program heap_default;
{ Demo: DefaultHeap process GetMem / sized FreeMem / TryGetMem / GetMemStats. }
{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem;

var
  P: Pointer;
  S: TMemStats;
begin
  WriteLn('mem-example=heap_default');

  P := GetMem(64);
  if P = nil then
  begin
    WriteLn('status=fail oom_getmem');
    Halt(1);
  end;
  FreeMem(P, 64);

  if not TryGetMem(128, P) then
  begin
    WriteLn('status=fail try_getmem');
    Halt(1);
  end;
  FreeMem(P, 128);

  GetMemStats(S);
  WriteLn(FormatMemStats(S));
  WriteLn('status=pass');
end.
