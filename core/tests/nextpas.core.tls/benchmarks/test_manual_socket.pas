program test_manual_socket;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  ctypes,
  {$ENDIF}
  SysUtils;

{$IFDEF UNIX}
const
  AF_INET = 2;
  SOCK_STREAM = 1;
  IPPROTO_TCP = 6;

type
  tsocklen = cuint;
  psockaddr = ^tsockaddr;
  tsockaddr = record
    sa_family: cushort;
    sa_data: array[0..13] of char;
  end;

  psockaddr_in = ^tsockaddr_in;
  tsockaddr_in = record
    sin_family: cushort;
    sin_port: cushort;
    sin_addr: record s_addr: cuint; end;
    sin_zero: array[0..7] of char;
  end;

function socket(domain, atype, protocol: cint): cint; cdecl; external 'c';
function connect(sockfd: cint; addr: psockaddr; addrlen: tsocklen): cint; cdecl; external 'c';
function close(fd: cint): cint; cdecl; external 'c';
function htons(hostshort: cushort): cushort; cdecl; external 'c';

procedure TestSocket;
var
  S: cint;
begin
  S := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if S < 0 then
    WriteLn('Failed to create socket')
  else
  begin
    WriteLn('Socket created successfully: ', S);
    close(S);
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
