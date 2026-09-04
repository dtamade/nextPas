program test_constants;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  nextpas.core.platform.socket,
  {$ENDIF}
  nextpas.core.system.sysutils;

begin
  {$IFDEF UNIX}
  WriteLn('AF_INET: ', PLATFORM_AF_INET);
  WriteLn('SOCK_STREAM: ', PLATFORM_SOCK_STREAM);
  {$ELSE}
  WriteLn('Not Unix');
  {$ENDIF}
end.
