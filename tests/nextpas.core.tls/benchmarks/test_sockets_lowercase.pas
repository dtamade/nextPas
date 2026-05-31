program test_sockets_lowercase;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  sockets,
  {$ENDIF}
  SysUtils;

begin
  {$IFDEF UNIX}
  WriteLn('Sockets unit found');
  {$ELSE}
  WriteLn('Not Unix');
  {$ENDIF}
end.
