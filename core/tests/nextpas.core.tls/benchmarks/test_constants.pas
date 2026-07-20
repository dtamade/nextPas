program test_constants;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  BaseUnix, Unix,
  {$ENDIF}
  nextpas.core.system.sysutils;

begin
  {$IFDEF UNIX}
  WriteLn('AF_INET: ', AF_INET);
  WriteLn('SOCK_STREAM: ', SOCK_STREAM);
  {$ELSE}
  WriteLn('Not Unix');
  {$ENDIF}
end.
