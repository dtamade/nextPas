program arena_request;
{ Demo: request/frame lifetime via CreateDefaultArena + Reset (not FreeMem). }
{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem;

var
  Arena: IArena;
  P: Pointer;
begin
  WriteLn('mem-example=arena_request');

  Arena := CreateDefaultArena(64 * 1024);
  if Arena = nil then
  begin
    WriteLn('status=fail create');
    Halt(1);
  end;

  P := Arena.Alloc(256);
  if P = nil then
  begin
    WriteLn('status=fail alloc');
    Halt(1);
  end;

  Arena.Reset;
  if Arena.UsedSize <> 0 then
  begin
    WriteLn('status=fail reset');
    Halt(1);
  end;

  WriteLn('status=pass');
end.
