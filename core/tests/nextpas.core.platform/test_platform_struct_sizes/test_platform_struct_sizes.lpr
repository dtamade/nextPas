program test_platform_struct_sizes;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestLinuxStat;
begin
  Check(SizeOf(TPlatformLinuxStat) = 144, 'TPlatformLinuxStat = 144');
end;

procedure TestEpollEvent;
begin
  Check(SizeOf(epoll_event) = 12, 'epoll_event = 12');
end;

procedure TestInotifyEvent;
begin
  Check(SizeOf(inotify_event) = 16, 'inotify_event = 16');
end;

procedure TestSockaddrIn;
begin
  Check(SizeOf(sockaddr_in) = 16, 'sockaddr_in = 16');
end;

procedure TestSockaddrIn6;
begin
  Check(SizeOf(sockaddr_in6) = 28, 'sockaddr_in6 = 28');
end;

procedure TestSockaddrStorage;
begin
  Check(SizeOf(sockaddr_storage) = 128, 'sockaddr_storage = 128');
end;

procedure TestAddrInfo;
begin
  Check(SizeOf(TAddrInfo) = 48, 'TAddrInfo = 48');
end;

procedure TestIovec;
begin
  Check(SizeOf(iovec) = 16, 'iovec = 16');
end;

procedure TestPollfd;
begin
  Check(SizeOf(pollfd) = 8, 'pollfd = 8');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.struct_sizes');
  T.Run('TPlatformLinuxStat = 144', @TestLinuxStat);
  T.Run('epoll_event = 12', @TestEpollEvent);
  T.Run('inotify_event = 16', @TestInotifyEvent);
  T.Run('sockaddr_in = 16', @TestSockaddrIn);
  T.Run('sockaddr_in6 = 28', @TestSockaddrIn6);
  T.Run('sockaddr_storage = 128', @TestSockaddrStorage);
  T.Run('TAddrInfo = 48', @TestAddrInfo);
  T.Run('iovec = 16', @TestIovec);
  T.Run('pollfd = 8', @TestPollfd);
  T.Summary;
end.
