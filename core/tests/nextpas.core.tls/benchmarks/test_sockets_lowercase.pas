program test_sockets_lowercase;

{$mode objfpc}{$H+}


begin
  {$IFDEF UNIX}
  WriteLn('Sockets unit found');
  {$ELSE}
  WriteLn('Not Unix');
  {$ENDIF}
end.
