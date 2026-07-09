unit Sockets;

{$mode objfpc}{$H+}

interface

const
  AF_INET = 2;
  AF_INET6 = 10;
  AF_UNIX = 1;
  SOCK_STREAM = 1;
  SOCK_DGRAM = 2;
  IPPROTO_TCP = 6;
  IPPROTO_UDP = 17;
  SOL_SOCKET = 1;
  SO_REUSEADDR = 2;
  SO_KEEPALIVE = 9;
  SO_RCVBUF = 8;
  SO_SNDBUF = 7;
  TCP_NODELAY = 1;
  INADDR_ANY = 0;
  INVALID_SOCKET = -1;
  SOCKET_ERROR = -1;

type
  TSocket = LongInt;
  TSockAddr = packed record
    sin_family: Word;
    sin_port: Word;
    sin_addr: packed record
      s_addr: LongWord;
    end;
    sin_zero: array[0..7] of Byte;
  end;
  PSockAddr = ^TSockAddr;

function htons(hostshort: Word): Word;
function ntohs(netshort: Word): Word;
function htonl(hostlong: LongWord): LongWord;
function ntohl(netlong: LongWord): LongWord;

implementation

function htons(hostshort: Word): Word;
begin
  Result := ((hostshort and $FF) shl 8) or ((hostshort shr 8) and $FF);
end;

function ntohs(netshort: Word): Word;
begin
  Result := htons(netshort);
end;

function htonl(hostlong: LongWord): LongWord;
begin
  Result := ((hostlong and $FF) shl 24) or
            ((hostlong and $FF00) shl 8) or
            ((hostlong shr 8) and $FF00) or
            ((hostlong shr 24) and $FF);
end;

function ntohl(netlong: LongWord): LongWord;
begin
  Result := htonl(netlong);
end;

end.
