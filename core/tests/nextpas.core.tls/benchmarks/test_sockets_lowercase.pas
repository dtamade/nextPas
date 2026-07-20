program test_sockets_lowercase;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  sockets,
  {$ENDIF}
  nextpas.core.system.sysutils;

begin
  {$IFDEF UNIX}
  WriteLn('Sockets unit found');
  {$ELSE}
  WriteLn('Not Unix');
  {$ENDIF}
end.
