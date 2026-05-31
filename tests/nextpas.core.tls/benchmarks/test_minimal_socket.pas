program test_minimal_socket;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  BaseUnix, Unix,
  {$ENDIF}
  SysUtils;

{$IFDEF UNIX}
procedure TestSocket;
var
  S: cint;
begin
  S := fpSocket(AF_INET, SOCK_STREAM, 0);
  if S < 0 then
    WriteLn('Failed to create socket: ', fpGetErrno)
  else
  begin
    WriteLn('Socket created successfully: ', S);
    fpClose(S);
  end;
end;
{$ENDIF}

begin
  {$IFDEF UNIX}
  TestSocket;
  {$ELSE}
  WriteLn('Not Unix');
  {$ENDIF}
end.
