program test_minimal_socket;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.socket,
  nextpas.core.system.sysutils;

procedure TestSocket;
var
  S: TPlatformSocket;
  LErr: Int32;
begin
  LErr := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, S);
  if LErr <> 0 then
    WriteLn('Failed to create socket: ', LErr)
  else
  begin
    WriteLn('Socket created successfully: ', S.Value);
    platform_socket_close(S);
  end;
end;

begin
  TestSocket;
end.
