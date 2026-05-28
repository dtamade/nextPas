program test_platform_socket_types_abi;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestInAddrSize;
begin
  CheckEqual(4, SizeOf(in_addr), 'SizeOf(in_addr) = 4');
end;

procedure TestIn6AddrSize;
begin
  CheckEqual(16, SizeOf(in6_addr), 'SizeOf(in6_addr) = 16');
end;

procedure TestSockAddrInSize;
begin
  CheckEqual(16, SizeOf(sockaddr_in), 'SizeOf(sockaddr_in) = 16');
end;

procedure TestSockAddrIn6Size;
begin
  CheckEqual(28, SizeOf(sockaddr_in6), 'SizeOf(sockaddr_in6) = 28');
end;

procedure TestSockAddrUnSize;
begin
  CheckEqual(110, SizeOf(sockaddr_un), 'SizeOf(sockaddr_un) = 110');
end;

procedure TestSockAddrStorageSize;
begin
  CheckEqual(128, SizeOf(sockaddr_storage), 'SizeOf(sockaddr_storage) = 128');
end;

procedure TestLingerSize;
begin
  CheckEqual(8, SizeOf(linger), 'SizeOf(linger) = 8');
end;

procedure TestUcredSize;
begin
  CheckEqual(12, SizeOf(ucred), 'SizeOf(ucred) = 12');
end;

procedure TestAFConstants;
begin
  CheckEqual(0, AF_UNSPEC, 'AF_UNSPEC = 0');
  CheckEqual(1, AF_UNIX, 'AF_UNIX = 1');
  CheckEqual(2, AF_INET, 'AF_INET = 2');
  CheckEqual(10, AF_INET6, 'AF_INET6 = 10');
  CheckEqual(16, AF_NETLINK, 'AF_NETLINK = 16');
  CheckEqual(17, AF_PACKET, 'AF_PACKET = 17');
end;

procedure TestSOCKConstants;
begin
  CheckEqual(1, SOCK_STREAM, 'SOCK_STREAM = 1');
  CheckEqual(2, SOCK_DGRAM, 'SOCK_DGRAM = 2');
  CheckEqual(3, SOCK_RAW, 'SOCK_RAW = 3');
end;

procedure TestIPPROTOConstants;
begin
  CheckEqual(6, IPPROTO_TCP, 'IPPROTO_TCP = 6');
  CheckEqual(17, IPPROTO_UDP, 'IPPROTO_UDP = 17');
end;

procedure TestMSGConstants;
begin
  CheckEqual($00000001, MSG_OOB, 'MSG_OOB');
  CheckEqual($00000002, MSG_PEEK, 'MSG_PEEK');
  CheckEqual($00004000, MSG_NOSIGNAL, 'MSG_NOSIGNAL');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.socket_types_abi');
  T.Run('in_addr size', @TestInAddrSize);
  T.Run('in6_addr size', @TestIn6AddrSize);
  T.Run('sockaddr_in size', @TestSockAddrInSize);
  T.Run('sockaddr_in6 size', @TestSockAddrIn6Size);
  T.Run('sockaddr_un size', @TestSockAddrUnSize);
  T.Run('sockaddr_storage size', @TestSockAddrStorageSize);
  T.Run('linger size', @TestLingerSize);
  T.Run('ucred size', @TestUcredSize);
  T.Run('AF_* constants', @TestAFConstants);
  T.Run('SOCK_* constants', @TestSOCKConstants);
  T.Run('IPPROTO_* constants', @TestIPPROTOConstants);
  T.Run('MSG_* constants', @TestMSGConstants);
  T.Summary;
end.
