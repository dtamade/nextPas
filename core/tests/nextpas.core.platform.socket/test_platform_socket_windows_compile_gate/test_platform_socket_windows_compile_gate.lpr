program test_platform_socket_windows_compile_gate;

{ Windows compile gate: verify all platform.socket APIs compile
  under Win64 target and all symbols resolve correctly. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.socket;

procedure TouchCreate;
var S: TPlatformSocket;
begin platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, PLATFORM_IPPROTO_TCP, S); end;

procedure TouchClose;
var S: TPlatformSocket;
begin platform_socket_close(S); end;

procedure TouchBind;
var S: TPlatformSocket; A: TPlatformSockAddr;
begin platform_socket_bind(S, @A.Storage, A.Len); end;

procedure TouchListen;
var S: TPlatformSocket;
begin platform_socket_listen(S, 1); end;

procedure TouchAccept;
var S, C: TPlatformSocket; A: TPlatformSockAddr; L: Int32;
begin L := SizeOf(A.Storage); platform_socket_accept(S, @A.Storage, @L, C); end;

procedure TouchConnect;
var S: TPlatformSocket; A: TPlatformSockAddr;
begin platform_socket_connect(S, @A.Storage, A.Len); end;

procedure TouchSend;
var S: TPlatformSocket; B: array[0..3] of Byte; L: Int32;
begin platform_socket_send(S, @B, 4, 0, L); end;

procedure TouchRecv;
var S: TPlatformSocket; B: array[0..3] of Byte; L: Int32;
begin platform_socket_recv(S, @B, 4, 0, L); end;

procedure TouchShutdown;
var S: TPlatformSocket;
begin platform_socket_shutdown(S, PLATFORM_SHUT_RD); end;

procedure TouchSetSockOpt;
var S: TPlatformSocket; V: Int32;
begin platform_socket_setsockopt(S, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @V, SizeOf(V)); end;

procedure TouchSendTo;
var S: TPlatformSocket; B: array[0..3] of Byte; L: Int32; A: TPlatformSockAddr;
begin platform_socket_sendto(S, @B, 4, 0, @A.Storage, A.Len, L); end;

procedure TouchRecvFrom;
var S: TPlatformSocket; B: array[0..3] of Byte; L: Int32; A: TPlatformSockAddr; AL: Int32;
begin AL := SizeOf(A.Storage); platform_socket_recvfrom(S, @B, 4, 0, @A.Storage, @AL, L); end;

procedure TouchGetSockName;
var S: TPlatformSocket; A: TPlatformSockAddr; L: Int32;
begin L := SizeOf(A.Storage); platform_socket_getsockname(S, @A.Storage, @L); end;

procedure TouchGetPeerName;
var S: TPlatformSocket; A: TPlatformSockAddr; L: Int32;
begin L := SizeOf(A.Storage); platform_socket_getpeername(S, @A.Storage, @L); end;

procedure TouchResolve;
var A: UInt32;
begin platform_socket_resolve_ipv4('127.0.0.1', A); end;

procedure TouchSetNonBlocking;
var S: TPlatformSocket;
begin platform_socket_set_nonblocking(S, True); end;

procedure TouchSetTimeout;
var S: TPlatformSocket;
begin platform_socket_set_timeout(S, PLATFORM_SO_RCVTIMEO, 100); end;

procedure TouchSockaddrHelpers;
var A: TPlatformSockAddr;
begin platform_sockaddr_ipv4(80, 0, A); platform_sockaddr_loopback4(80, A); end;

procedure TouchByteOrder;
var H: UInt16; L: UInt32;
begin H := platform_htons(256); L := platform_htonl(1); end;

begin
  TouchCreate;
  TouchClose;
  TouchBind;
  TouchListen;
  TouchAccept;
  TouchConnect;
  TouchSend;
  TouchRecv;
  TouchShutdown;
  TouchSetSockOpt;
  TouchSendTo;
  TouchRecvFrom;
  TouchGetSockName;
  TouchGetPeerName;
  TouchResolve;
  TouchSetNonBlocking;
  TouchSetTimeout;
  TouchSockaddrHelpers;
  TouchByteOrder;
end.
